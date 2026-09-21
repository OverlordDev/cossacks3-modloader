-- balance — параметры типов юнитов и зданий: читать и менять посреди партии.
--
-- Где это у игры (data/scripts/lib/classes.script, unit.script):
--   gObjProp[нация][тип]                     TObjProp — общее для всех игроков: обзор, радиусы,
--                                            роль, флаги (bartillery, bofficer...), оружие (статика)
--   gPlayer[игрок].objbase[нация][тип]       TObjBase — своё у каждого игрока (его меняют улучшения):
--                                            maxhp, shield, price[0..6], buildtime, speed,
--                                            protection[0..9], weapon[0..3].damage/radiusmax/pause...
-- Игра заполняет их в начале партии (_unit_InitBase), поэтому менять — в game.start или позже.
--
--   balance.types()                          --> { {sid="rus_strelets", country=4, id=12}, ... }
--   balance.find("rus_strelets")             --> 4, 12        (нация, номер типа)
--   balance.get("rus_strelets")              --> { base = {maxhp=..., weapon={[0]={damage=...}}...}, prop = {...} }
--   balance.get("rus_strelets", 2)           --  base игрока 2
--   balance.set("rus_strelets", "maxhp", 300)             -- всем игрокам
--   balance.set("rus_strelets", "weapon[0].damage", 40, 1) -- только игроку 1
--   balance.set("rus_strelets", "price[3]", 50)            -- цена: 0 еда 1 дерево 2 камень 3 золото 4 железо 5 уголь
--   balance.setProp("rus_strelets", "vision", 900)         -- общее свойство типа
--   balance.dump("rus_strelets")             --  всё в лог — чтобы посмотреть имена полей
--
-- Поля и типы — GAME_STATE.md (TObjBase, TObjWeapon, TObjProp, TObjWeaponStatic).
--
-- МУЛЬТИПЛЕЕР: статы юнитов считаются на каждой машине. Меняйте их одинаково у всех игроков:
-- мод со стороной shared (server.lua выполняется на всех машинах) и изменение в game.start.
-- Иначе партии разойдутся (рассинхрон).

balance = {}

local PLAYERS = 12
local cache -- sid (нижний регистр) -> { {country, id, sid}, ... } — одно имя бывает у нескольких наций

-- Все непустые типы одним вызовом скрипта: цикл по gObjProp собирает строку "нация,тип,sid;".
local function scan()
    local list = {}
    local text
    if game.exec then
        text = game.exec([[
var s : String;
var c, u : Integer;
for c := 0 to gc_MaxCountryCount-1 do
for u := 0 to gc_country_maxmembers-1 do
if gObjProp[c][u].sid <> '' then
s := s + IntToStr(c) + ',' + IntToStr(u) + ',' + gObjProp[c][u].sid + ';';
ML_RET(s);]])
    else
        -- Клиенту исполнять код нельзя — читаем по одному (медленнее, но только один раз).
        local parts = {}
        for c = 0, 23 do
            for u = 0, 79 do
                local sid = game.eval("gObjProp[" .. c .. "][" .. u .. "].sid")
                if sid ~= "" then parts[#parts + 1] = c .. "," .. u .. "," .. sid end
            end
        end
        text = table.concat(parts, ";")
    end
    for c, u, sid in text:gmatch("(%d+),(%d+),([^;]+)") do
        list[#list + 1] = { sid = sid, country = tonumber(c), id = tonumber(u) }
    end
    return list
end

local function index()
    if cache then return cache end
    cache = {}
    for _, t in ipairs(scan()) do
        local key = t.sid:lower()
        cache[key] = cache[key] or {}
        table.insert(cache[key], t)
    end
    return cache
end

function balance.types()
    local out = {}
    for _, list in pairs(index()) do
        for _, t in ipairs(list) do out[#out + 1] = t end
    end
    table.sort(out, function(a, b) return a.sid < b.sid or (a.sid == b.sid and a.country < b.country) end)
    return out
end

-- Список типов строится при первом обращении; после смены набора наций в новой партии — сбросить.
function balance.refresh() cache = nil end

-- Все места, где живёт тип: { {country, id}, ... }.
local function places(sid, level)
    local list = index()[tostring(sid):lower()]
    if not list then
        error("balance: unknown unit type '" .. tostring(sid) .. "' (balance.types() lists all)", (level or 1) + 2)
    end
    return list
end

-- Первое совпадение: нация и номер типа. Остальные нации с тем же именем — balance.places(sid).
function balance.find(sid)
    local t = places(sid, 1)[1]
    return t.country, t.id
end

function balance.places(sid) return places(sid, 1) end

local function basePath(t, player)
    return string.format("gPlayer[%d].objbase[%d][%d]", player, t.country, t.id)
end

local function propPath(t)
    return string.format("gObjProp[%d][%d]", t.country, t.id)
end

function balance.get(sid, player)
    local t = places(sid, 1)[1]
    return {
        base = state.read(basePath(t, player or 0), 2),
        prop = state.read(propPath(t), 2),
    }
end

-- field: путь внутри TObjBase: "maxhp", "speed", "price[3]", "weapon[0].damage", "protection[2]".
function balance.set(sid, field, value, player)
    if not game.exec then
        error("balance.set: only server/shared scripts can change the game", 2)
    end
    local first, last = 0, PLAYERS - 1
    if player then first, last = player, player end
    local sep = field:sub(1, 1) == "[" and "" or "."
    for _, t in ipairs(places(sid, 1)) do -- у всех наций с этим типом
        for p = first, last do
            state.set(basePath(t, p) .. sep .. field, value)
        end
    end
end

function balance.setProp(sid, field, value)
    if not game.exec then
        error("balance.setProp: only server/shared scripts can change the game", 2)
    end
    local sep = field:sub(1, 1) == "[" and "" or "."
    for _, t in ipairs(places(sid, 1)) do
        state.set(propPath(t) .. sep .. field, value)
    end
end

local function flatten(t, prefix, out)
    local keys = {}
    for k in pairs(t) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    for _, k in ipairs(keys) do
        local v = t[k]
        local name = prefix == "" and tostring(k) or (prefix .. "." .. tostring(k))
        if type(v) == "table" then flatten(v, name, out) else out[#out + 1] = name .. " = " .. tostring(v) end
    end
end

function balance.dump(sid, player)
    local data = balance.get(sid, player)
    local lines = {}
    flatten(data, "", lines)
    local text = sid .. ":\n  " .. table.concat(lines, "\n  ")
    if log and log.info then log.info(text) end
    return text
end

-- ---------- как улучшения игры: тип + все живые юниты ----------
--
-- balance.set меняет только тип: игра копирует здоровье и скорость в юнита при его появлении,
-- поэтому уже живые юниты изменения не увидят. Эти функции делают то же, что улучшения самой
-- игры (data/scripts/lib/player.script): меняют тип и пересчитывают всех живых.
--
--   balance.setHP("musketeer18", 500)          -- макс. здоровье; текущее у живых — пропорционально
--   balance.setDamage("musketeer18", 60)       -- урон всех видов оружия (с учётом улучшений игрока)
--   balance.setDamage("musketeer18", 60, 1)    -- только оружие 1 (у мушкетёра 0 — штык, 1 — выстрел)
--   balance.setSpeed("musketeer18", 2)         -- в 2 раза быстрее обычного (1 — как в игре)
-- Последний аргумент у всех — номер игрока (без него — все игроки).

local function needExec(name)
    if not game.exec then error("balance." .. name .. ": only server/shared scripts can change the game", 3) end
end

-- Код для каждой нации с этим типом и каждого игрока; body видит c, u, p, plHnd.
local function forEach(sid, player, body)
    local out = {}
    for _, t in ipairs(places(sid, 2)) do
        local first, last = player or 0, player or (PLAYERS - 1)
        out[#out + 1] = string.format([[
for p := %d to %d do
begin
c := %d; u := %d;
plHnd := GetPlayerHandleByIndex(p);
%s
end;]], first, last, t.country, t.id, body)
    end
    return "var c, u, p, i, k, plHnd, h : Integer;\nvar pobj : Pointer;\nvar old, ratio : Float;\n" ..
        table.concat(out, "\n")
end

-- Цикл по живым объектам этого типа у игрока p: тело видит pobj (TObj) и h (хендл).
local EACH_UNIT = [[
if plHnd <> 0 then
for i := 0 to GetPlayerGameObjectsCountByHandle(plHnd)-1 do
begin
h := GetGameObjectHandleByIndex(i, plHnd);
pobj := _unit_GetTObj(h);
if (pobj <> nil) and (TObj(pobj).cid = c) and (TObj(pobj).id = u) then
begin
%s
end;
end;]]

function balance.setHP(sid, maxhp, player)
    needExec("setHP")
    maxhp = math.floor(tonumber(maxhp) or 0)
    game.exec(forEach(sid, player, [[
old := gPlayer[p].objbase[c][u].maxhp;
gPlayer[p].objbase[c][u].maxhp := ]] .. maxhp .. [[;
if old > 0 then
]] .. EACH_UNIT:format("TObj(pobj).hp := Round(TObj(pobj).hp / old * " .. maxhp .. ");")))
end

function balance.setDamage(sid, damage, weapon, player)
    needExec("setDamage")
    damage = math.floor(tonumber(damage) or 0)
    local first, last = weapon or 0, weapon or 3
    game.exec(forEach(sid, player, string.format([[
for k := %d to %d do
if gObjProp[c][u].weapon[k].enabled then
begin
gPlayer[p].objbase[c][u].weapon[k].damageinit := %d;
gPlayer[p].objbase[c][u].weapon[k].damage := Floor((gPlayer[p].objbase[c][u].weapon[k].damageinit + gPlayer[p].objbase[c][u].weapon[k].damagestatic) * (1 + gPlayer[p].objbase[c][u].weapon[k].damagepercent / 100));
end;]], first, last, damage)))
end

-- Скорость у игры — множитель интервала шага (меньше — быстрее); здесь — понятный множитель скорости.
function balance.setSpeed(sid, multiplier, player)
    needExec("setSpeed")
    local interval = 1 / (tonumber(multiplier) or 1)
    game.exec(forEach(sid, player, string.format([[
old := gPlayer[p].objbase[c][u].speed;
if old <= 0 then old := 1;
ratio := StrToInt('%d') / 1000000 / old;
gPlayer[p].objbase[c][u].speed := StrToInt('%d') / 1000000;
]], math.floor(interval * 1000000 + 0.5), math.floor(interval * 1000000 + 0.5)) .. EACH_UNIT:format([[
SetGameObjectTrackPointMoveStepIntervalByHandle(h, Floor(GetGameObjectTrackPointMoveStepIntervalByHandle(h) * ratio));
SetGameObjectTrackPointTurnStepIntervalByHandle(h, Floor(GetGameObjectTrackPointTurnStepIntervalByHandle(h) * ratio));]])))
end
