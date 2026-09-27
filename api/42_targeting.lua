-- targeting — поиск целей: круг, ближайший, конус, проверка рельефа.
--
-- Только чтение (быстрый objects.*): работает везде, включая client.
-- Нужно для способностей, ПВО, турелей и ИИ.
--
--   local foes = targeting.inCircle(x, z, 30, { enemy = true })
--   local h = targeting.nearest({ x = x, z = z }, { enemy = true, maxR = 100 })
--   local inArc = targeting.inCone(x, z, dirAngle, 0.4, 60, { enemy = true })
--   local clear = targeting.los(ax, az, bx, bz)   -- нет ли холма между точками
--
-- enemy=true — чужие для игрока за этим компьютером (pl ~= свой индекс).
-- Фильтры: enemy, player (индекс), sid (basename), alive (по умолчанию true),
-- maxR (для nearest).

targeting = {}

local function num(v, name)
    local n = tonumber(v)
    if not n or n ~= n then error("targeting: " .. name .. " must be a number", 3) end
    return n
end

local function inGame(where)
    if not game.isInGame() then
        error("targeting." .. where .. ": no active game (check game.isInGame())", 3)
    end
end

local function me()
    return native.GetPlayerIndexInterfaceIO()
end

-- Подходит ли объект под фильтры.
local function match(h, o, x, z, r2, f)
    if f.alive ~= false and o.bdead then return false end
    if f.enemy and (o.pl == nil or o.pl == me()) then return false end
    if f.player ~= nil and o.pl ~= f.player then return false end
    if f.sid ~= nil then
        local ok, sid = pcall(native.GetGameObjectBaseNameByHandle, h)
        if not ok or sid ~= f.sid then return false end
    end
    if x ~= nil then
        -- координат в objects.read нет — только через objects.pos
        local px, pz = objects.pos(h)
        if not px then return false end
        local dx, dz = px - x, pz - z
        if dx * dx + dz * dz > r2 then return false end
    end
    return true
end

-- Все подходящие в круге: x, z — мировые, radius — радиус, opts = { enemy, player, sid, alive }.
-- Возвращает { handle, ... }. Сторона: везде, включая client (только чтение, нужна игра).
-- Ошибки: no active game, x/z/radius must be a number.
function targeting.inCircle(x, z, radius, opts)
    inGame("inCircle")
    x, z, radius = num(x, "x"), num(z, "z"), num(radius, "radius")
    opts = opts or {}
    local out = {}
    for _, h in ipairs(objects.list()) do
        local ok, o = pcall(objects.read, h)
        if ok and o and match(h, o, x, z, radius * radius, opts) then
            out[#out + 1] = h
        end
    end
    return out
end

-- Ближайший к точке { x, z } или юниту-точке (handle). opts — как в inCircle + maxR.
-- Возвращает handle или nil (нет точки/нет подходящих — без ошибки).
-- Сторона: везде, включая client (только чтение, нужна игра). Ошибки: no active game, x/z/maxR must be a number.
function targeting.nearest(point, opts)
    inGame("nearest")
    opts = opts or {}
    local x, z
    if type(point) == "table" then x, z = num(point.x, "x"), num(point.z, "z")
    else x, z = objects.pos(point) end
    if not x then return nil end
    local maxR = opts.maxR and num(opts.maxR, "maxR") or math.huge
    local best, bestD = nil, maxR * maxR
    for _, h in ipairs(objects.list()) do
        local ok, o = pcall(objects.read, h)
        if ok and o and match(h, o, nil, nil, 0, opts) then
            local px, pz = objects.pos(h)
            if px then
                local d = (px - x) * (px - x) + (pz - z) * (pz - z)
                if d < bestD then best, bestD = h, d end
            end
        end
    end
    return best
end

-- Кто в конусе: x, z — точка, dir — направление (радианы, 0 — +z), half — полуугол, dist — дальность.
-- opts — как в inCircle. Возвращает { handle, ... }.
-- Сторона: везде, включая client (только чтение, нужна игра). Ошибки: no active game, x/z/dir/half/dist must be a number.
function targeting.inCone(x, z, dir, half, dist, opts)
    inGame("inCone")
    x, z = num(x, "x"), num(z, "z")
    dir, half, dist = num(dir, "dir"), num(half, "half"), num(dist, "dist")
    opts = opts or {}
    local out = {}
    for _, h in ipairs(targeting.inCircle(x, z, dist, opts)) do
        local px, pz = objects.pos(h)
        if px then
            local a = math.atan(px - x, pz - z) - dir
            while a > math.pi do a = a - 2 * math.pi end
            while a < -math.pi do a = a + 2 * math.pi end
            if math.abs(a) <= half then out[#out + 1] = h end
        end
    end
    return out
end

-- Чист ли рельеф между точками: true — видно, false — холм закрывает. Юниты не учитываются.
-- Параметры: ax, az, bx, bz — мировые. Сторона: везде, включая client (нужна игра).
-- Ошибки: no active game, ax/az/bx/bz must be a number.
function targeting.los(ax, az, bx, bz)
    inGame("los")
    ax, az, bx, bz = num(ax, "ax"), num(az, "az"), num(bx, "bx"), num(bz, "bz")
    local ay = native.RayCastHeight(ax, az) or 0
    local by = native.RayCastHeight(bx, bz) or 0
    local hit = native.RayCastTerrain(ax, ay + 2, az, bx, by + 2, bz)
    return not hit
end
