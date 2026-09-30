-- query — удобные запросы к объектам поверх objects.* (только ЧТЕНИЕ, везде).
--
-- Ядро — query.scan(opts) → массив ЗАПИСЕЙ { handle, x, z, hp, player, sid }:
-- sid берётся через native.GetGameObjectBaseNameByHandle под pcall (нет sid — nil).
--
--   local recs = query.scan({ player = 0, alive = true, limit = 10 })
--   local cav = query.byType("units", "cav18", { around = { x = 0, z = 0, radius = 50 } })
--   local n = query.count({ sid = "mill18" })
--
-- Опции scan: player (индекс), sid (basename), alive (default true: только живые;
-- false — все включая мёртвых; только мёртвых — через predicate),
-- building (nil — все; true — только здания; false — только не-здания),
-- around ({ x, z, radius } или { x, z } + radius), radius (к around без radius),
-- rect ({ x1, z1, x2, z2 }, включительно), predicate (fn(rec) → bool),
-- limit (сколько вернуть, после сортировки), sortByDistanceFrom ({ x, z }).
-- players-модуль НЕ используется (обходимся objects-only): enemies/allies — по pl.
-- enemies(player): pl ~= player. ВНИМАНИЕ про команды: это НЕ дипломатия — союзник
-- по команде (тот же team, другой индекс) попадёт в enemies; team смотрите через
-- players.list (team) отдельно. allies(player): только тот же индекс pl == player
-- (тиммейты с другим индексом НЕ входят). Всё чтение — десинка нет, но команды
-- юнитам (orders/buildings) — только server/shared.
--
-- building-фильтр: при наличии game.exec — ОДИН batched game.exec на всех кандидатов
-- (флаги gObjProp[cid][id].bbuilding по cid/id из objects.read); без game.exec (client)
-- и building ~= nil — понятная ошибка. Без cid/id кандидат считается не-зданием;
-- если ни у кого нет cid/id — exec не вызывается (нечего спрашивать).
--
-- СТОИМОСТЬ: каждый scan — O(n) обход всех объектов (objects.list + read + pos).
-- НЕ вызывать каждый game.tick без интервала/троттлинга — кэшируйте или зовите
-- по событию/таймеру (см. scheduler). Тяжёлые сканы в hot loop — лаг.
-- Сторона: везде (только чтение; building=true/false на client без exec — ошибка).

query = {}

-- Копия опций (входные таблицы не мутируем).
local function copyOpts(opts)
    local c = {}
    if type(opts) == "table" then
        for k, v in pairs(opts) do c[k] = v end
    end
    return c
end

-- Свой игрок за этим компьютером (objects-only, без players). Возвращает индекс или nil.
local function me()
    local g = rawget(_ENV, "game")
    local nat = rawget(_ENV, "native")
    if g == nil or nat == nil then return nil end
    if type(g.isInGame) == "function" and not g.isInGame() then return nil end
    if type(nat.GetPlayerIndexInterfaceIO) ~= "function" then return nil end
    local ok, v = pcall(nat.GetPlayerIndexInterfaceIO)
    if ok then return v end
    return nil
end

-- Разобрать around/radius в x, z, r (или nil, если гео-фильтра нет). Ошибки с именем query.scan.
local function parseAround(opts)
    local a = opts.around
    if a == nil then return nil end
    if type(a) ~= "table" then error("query.scan: around must be a { x, z, radius } table", 2) end
    local x, z = a.x, a.z
    local r = a.radius
    if r == nil then r = a.r end
    if r == nil then r = opts.radius end
    if type(x) ~= "number" or x ~= x or type(z) ~= "number" or z ~= z then
        error("query.scan: around.x/z must be numbers", 2)
    end
    if type(r) ~= "number" or r ~= r or r < 0 then
        error("query.scan: around.radius must be a number >= 0", 2)
    end
    return x, z, r
end

-- Разобрать rect в нормализованные x1, z1, x2, z2 (или nil). Ошибки с именем query.scan.
local function parseRect(opts)
    local rc = opts.rect
    if rc == nil then return nil end
    if type(rc) ~= "table" then error("query.scan: rect must be a { x1, z1, x2, z2 } table", 2) end
    local x1, z1, x2, z2 = rc.x1, rc.z1, rc.x2, rc.z2
    for _, v in ipairs({ x1, z1, x2, z2 }) do
        if type(v) ~= "number" or v ~= v then
            error("query.scan: rect x1/z1/x2/z2 must be numbers", 2)
        end
    end
    if x1 > x2 then x1, x2 = x2, x1 end
    if z1 > z2 then z1, z2 = z2, z1 end
    return x1, z1, x2, z2
end

-- Один batched game.exec: флаги bbuilding для уникальных пар cid/id.
-- Возвращает map ["cid:id"] = true/false. Вызовов game.exec — ровно один (или ноль, если пар нет).
local function buildingFlags(cands)
    local uniq, order = {}, {}
    for _, c in ipairs(cands) do
        if type(c.cid) == "number" and type(c.id) == "number" then
            local k = c.cid .. ":" .. c.id
            if uniq[k] == nil then
                uniq[k] = { cid = c.cid, id = c.id }
                order[#order + 1] = k
            end
        end
    end
    local flags = {}
    if #order == 0 then return flags end
    local parts = { "var s : String;" }
    for _, k in ipairs(order) do
        local u = uniq[k]
        parts[#parts + 1] = string.format(
            "if gObjProp[%d][%d].bbuilding then s := s + '1;' else s := s + '0;';",
            u.cid, u.id)
    end
    parts[#parts + 1] = "ML_RET(s);"
    local text = game.exec(table.concat(parts, "\n")) or ""
    local i = 1
    for tok in (text .. ";"):gmatch("(.-);") do
        local k = order[i]
        if k == nil then break end
        flags[k] = (tok == "1" or tok == "True")
        i = i + 1
    end
    return flags
end

-- query.scan(opts): ядро — все записи под фильтры. Возврат: { { handle, x, z, hp, player, sid }, ... }.
-- Сторона: везде (чтение). Ошибки: no active game; bad around/rect/limit/predicate; building без game.exec.
function query.scan(opts)
    local g = rawget(_ENV, "game")
    if g == nil or type(g.isInGame) ~= "function" or not g.isInGame() then
        error("query.scan: no active game (check game.isInGame())", 2)
    end
    opts = opts or {}
    if type(opts) ~= "table" then error("query.scan: opts must be a table", 2) end
    if opts.predicate ~= nil and type(opts.predicate) ~= "function" then
        error("query.scan: predicate must be a function", 2)
    end
    if opts.limit ~= nil then
        local lim = math.tointeger(opts.limit)
        if lim == nil or lim < 1 then error("query.scan: limit must be an integer >= 1", 2) end
    end
    local sortPt = opts.sortByDistanceFrom
    if sortPt ~= nil then
        if type(sortPt) ~= "table" or type(sortPt.x) ~= "number" or type(sortPt.z) ~= "number" then
            error("query.scan: sortByDistanceFrom must be a { x, z } table", 2)
        end
    end
    local ax, az, ar = parseAround(opts)
    local rx1, rz1, rx2, rz2 = parseRect(opts)
    local wantBuilding = opts.building
    if wantBuilding ~= nil and wantBuilding ~= true and wantBuilding ~= false then
        error("query.scan: building must be true/false/nil", 2)
    end
    if wantBuilding ~= nil and (g.exec == nil) then
        error("query.scan: building filter needs server/shared (no game.exec on client)", 2)
    end
    local list = objects.list()
    local cands = {}
    for _, h in ipairs(list) do
        local ok, o = pcall(objects.read, h)
        if ok and type(o) == "table" then
            if not (opts.alive ~= false and o.bdead) then
                if not (opts.player ~= nil and o.pl ~= opts.player) then
                    local sid = nil
                    local sidOk = true
                    if opts.sid ~= nil or true then
                        local okS, s = pcall(native.GetGameObjectBaseNameByHandle, h)
                        if okS then sid = s end
                        if opts.sid ~= nil and sid ~= opts.sid then sidOk = false end
                    end
                    if sidOk then
                        local okP, px, pz = pcall(objects.pos, h)
                        if not okP then px, pz = nil, nil end
                        local inGeo = true
                        if ax ~= nil and (px == nil or pz == nil) then
                            inGeo = false
                        elseif ax ~= nil then
                            local dx, dz = px - ax, pz - az
                            if dx * dx + dz * dz > ar * ar then inGeo = false end
                        end
                        if inGeo and rx1 ~= nil then
                            if px == nil or pz == nil or px < rx1 or px > rx2 or pz < rz1 or pz > rz2 then
                                inGeo = false
                            end
                        end
                        if inGeo then
                            local rec = { handle = h, x = px, z = pz, hp = o.hp, player = o.pl, sid = sid }
                            if opts.predicate == nil or opts.predicate(rec) then
                                cands[#cands + 1] = { rec = rec, cid = o.cid, id = o.id }
                            end
                        end
                    end
                end
            end
        end
    end
    local out = {}
    if wantBuilding == nil then
        for _, c in ipairs(cands) do out[#out + 1] = c.rec end
    else
        local flags = buildingFlags(cands)
        for _, c in ipairs(cands) do
            local isB = false
            if type(c.cid) == "number" and type(c.id) == "number" then
                isB = flags[c.cid .. ":" .. c.id] == true
            end
            if wantBuilding == true and isB then out[#out + 1] = c.rec end
            if wantBuilding == false and not isB then out[#out + 1] = c.rec end
        end
    end
    if sortPt ~= nil then
        local sx, sz = sortPt.x, sortPt.z
        table.sort(out, function(a, b)
            local da, db
            if a.x == nil or a.z == nil then da = math.huge else
                local dx, dz = a.x - sx, a.z - sz
                da = dx * dx + dz * dz
            end
            if b.x == nil or b.z == nil then db = math.huge else
                local dx, dz = b.x - sx, b.z - sz
                db = dx * dx + dz * dz
            end
            if da == db then return (a.handle or 0) < (b.handle or 0) end
            return da < db
        end)
    end
    if opts.limit ~= nil and #out > opts.limit then
        local cut = {}
        for i = 1, opts.limit do cut[i] = out[i] end
        out = cut
    end
    return out
end

-- query.units(opts): только не-здания (building=false). Возврат: записи. Сторона: везде (нужен exec для флага).
-- Ошибки: как в scan (building без exec — ошибка).
function query.units(opts)
    local c = copyOpts(opts)
    c.building = false
    return query.scan(c)
end

-- query.buildings(opts): только здания (building=true). Возврат: записи. Сторона: везде (нужен exec).
-- Ошибки: как в scan (без exec — ошибка).
function query.buildings(opts)
    local c = copyOpts(opts)
    c.building = true
    return query.scan(c)
end

-- query.objects(opts): все без building-фильтра (алиас scan). Возврат: записи. Сторона: везде.
-- Ошибки: как в scan.
function query.objects(opts)
    return query.scan(opts)
end

-- query.byType(kind, typeName, opts): по sid с видом (kind units|buildings|objects).
-- Парам: kind — "units"/"buildings"/"objects"; typeName — sid; opts — доп. фильтры.
-- Возврат: записи. Сторона: везде. Ошибки: bad kind/typeName; как в scan.
function query.byType(kind, typeName, opts)
    if kind ~= "units" and kind ~= "buildings" and kind ~= "objects" then
        error("query.byType: kind must be 'units'/'buildings'/'objects'", 2)
    end
    if type(typeName) ~= "string" or typeName == "" then
        error("query.byType: typeName must be a non-empty string", 2)
    end
    local c = copyOpts(opts)
    c.sid = typeName
    if kind == "units" then c.building = false
    elseif kind == "buildings" then c.building = true end
    return query.scan(c)
end

-- query.byPlayer(player, opts): объекты игрока (nil — свой). Возврат: записи. Сторона: везде.
-- Ошибки: bad player; как в scan.
function query.byPlayer(player, opts)
    if player == nil then player = me() end
    if type(player) ~= "number" or player ~= math.floor(player) then
        error("query.byPlayer: player must be a player index", 2)
    end
    local c = copyOpts(opts)
    c.player = player
    return query.scan(c)
end

-- query.enemies(player, opts): чужие (pl ~= player; nil — свой). Team НЕ проверяется (см. шапку).
-- Возврат: записи. Сторона: везде (чтение). Ошибки: bad player; как в scan.
function query.enemies(player, opts)
    if player == nil then player = me() end
    if type(player) ~= "number" or player ~= math.floor(player) then
        error("query.enemies: player must be a player index", 2)
    end
    local c = copyOpts(opts)
    c.player = nil
    local out = {}
    for _, r in ipairs(query.scan(c)) do
        if r.player ~= nil and r.player ~= player then out[#out + 1] = r end
    end
    return out
end

-- query.allies(player, opts): свои (pl == player; nil — свой). Тммйты с другим индексом НЕ входят.
-- Возврат: записи. Сторона: везде (чтение). Ошибки: bad player; как в scan.
function query.allies(player, opts)
    if player == nil then player = me() end
    if type(player) ~= "number" or player ~= math.floor(player) then
        error("query.allies: player must be a player index", 2)
    end
    local c = copyOpts(opts)
    c.player = player
    return query.scan(c)
end

-- query.first(opts): первая запись или nil (limit 1, сортировка из opts учитывается).
-- Возврат: запись или nil. Сторона: везде. Ошибки: как в scan.
function query.first(opts)
    local c = copyOpts(opts)
    if c.limit == nil then c.limit = 1 end
    local r = query.scan(c)
    return r[1]
end

-- query.nearest(x, z, opts) или query.nearest({ x, z }, opts): ближайшая запись к точке.
-- Реализация: scan c sortByDistanceFrom + limit 1 (учитывает around/rect из opts).
-- Возврат: запись или nil. Сторона: везде. Ошибки: bad x/z; как в scan.
function query.nearest(x, z, opts)
    local px, pz, o
    if type(x) == "table" and x.x ~= nil then
        px, pz, o = x.x, x.z, z
    else
        px, pz, o = x, z, opts
    end
    if type(px) ~= "number" or px ~= px or type(pz) ~= "number" or pz ~= pz then
        error("query.nearest: x/z must be numbers", 2)
    end
    local c = copyOpts(o)
    c.sortByDistanceFrom = { x = px, z = pz }
    c.limit = 1
    local r = query.scan(c)
    return r[1]
end

-- query.inArea(x, z, radius, opts) или query.inArea(opts с around/rect): записи в круге.
-- Возврат: записи. Сторона: везде. Ошибки: bad x/z/radius; как в scan.
function query.inArea(x, z, radius, opts)
    if type(x) == "table" and z == nil and radius == nil then
        if x.around ~= nil or x.rect ~= nil then return query.scan(x) end
        if x.x ~= nil and x.z ~= nil and x.radius ~= nil then
            return query.scan({ around = x })
        end
        return query.scan(x)
    end
    if type(x) ~= "number" or x ~= x or type(z) ~= "number" or z ~= z then
        error("query.inArea: x/z must be numbers", 2)
    end
    if type(radius) ~= "number" or radius ~= radius or radius < 0 then
        error("query.inArea: radius must be a number >= 0", 2)
    end
    local c = copyOpts(opts)
    c.around = { x = x, z = z, radius = radius }
    return query.scan(c)
end

-- query.count(opts): число записей под фильтры (длина scan). Возврат: число. Сторона: везде.
-- Ошибки: как в scan. Стоимость O(n) — не каждый тик.
function query.count(opts)
    return #query.scan(opts)
end
