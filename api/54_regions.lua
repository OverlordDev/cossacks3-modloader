-- regions — зоны ИИ и сценариев: оборона, запретные территории, маршруты.
--
-- Честно: нативов AIRegion в движке НЕТ (проверено по NativesTable.inc) —
-- это Lua-полигоны поверх targeting/objects. Чтение и вход/выход — везде;
-- block (отмена приказов внутрь) — только shared (одинаково на всех машинах).
--
--   regions.create("base", { {x=0,z=0}, {x=100,z=0}, {x=100,z=100}, {x=0,z=100} }, { owner = 0 })
--   regions.contains("base", x, z)               --> true/false
--   regions.units("base", { enemy = true })      --> хендлы внутри
--   regions.onEnter("base", function(h) ... end) -- разовый? нет — каждый вход
--   regions.block("base", true)                  -- резать приказы с точкой внутри (shared)
--   regions.remove("base")

regions = {}

local zones = {}
local watchSub = nil
local inside = {}   -- [zone][h] = true — кто внутри (для onEnter/onLeave)

local function num(v, name)
    local n = tonumber(v)
    if not n or n ~= n then error("regions: " .. name .. " must be a number", 3) end
    return n
end

local function zone(name, where)
    local z = zones[tostring(name)]
    if not z then error("regions." .. where .. ": unknown region '" .. tostring(name) .. "'", 3) end
    return z
end

local function inPoly(poly, x, z)
    local c = false
    local n = #poly
    for i = 1, n do
        local a, b = poly[i], poly[i % n + 1]
        if ((a.z > z) ~= (b.z > z)) and
           (x < (b.x - a.x) * (z - a.z) / (b.z - a.z) + a.x) then
            c = not c
        end
    end
    return c
end

local function bbox(poly)
    local x1, z1, x2, z2 = math.huge, math.huge, -math.huge, -math.huge
    for _, p in ipairs(poly) do
        x1, z1 = math.min(x1, p.x), math.min(z1, p.z)
        x2, z2 = math.max(x2, p.x), math.max(z2, p.z)
    end
    return x1, z1, x2, z2
end

-- Создать зону: polygon — { {x,z}, ... } (минимум 3 точки). Парам: name — строка; opts.owner — опционально.
-- Возвращает name. Чистый Lua-полигон (нативов AIRegion нет). Сторона: везде. Ошибки: пустое имя; точек < 3; нечисловые точки.
function regions.create(name, polygon, opts)
    if type(name) ~= "string" or name == "" then error("regions.create: bad name", 2) end
    if type(polygon) ~= "table" or #polygon < 3 then
        error("regions.create: polygon needs 3+ points", 2)
    end
    local poly = {}
    for i, p in ipairs(polygon) do
        poly[i] = { x = num(p.x or p[1], "point " .. i .. ".x"),
                    z = num(p.z or p[2], "point " .. i .. ".z") }
    end
    opts = opts or {}
    zones[name] = { poly = poly, owner = opts.owner,
                    onEnter = {}, onLeave = {}, blocked = false, subId = nil }
    local x1, z1, x2, z2 = bbox(poly)
    zones[name].box = { x1 = x1, z1 = z1, x2 = x2, z2 = z2 }
    return name
end

-- Удалить зону и её подписки (тихо, если нет). Парам: name — строка.
-- Ничего не возвращает. Сторона: везде. Ошибок не кидает.
function regions.remove(name)
    local z = zones[tostring(name)]
    if z then
        if z.subId then events.off(z.subId) end
        zones[tostring(name)] = nil
        inside[tostring(name)] = nil
    end
end

-- Точка внутри зоны. Парам: name; x, z — числа. Возвращает true/false.
-- Сторона: везде (чистая геометрия). Ошибки: нет зоны; нечисловые x/z.
function regions.contains(name, x, z)
    return inPoly(zone(name, "contains").poly, num(x, "x"), num(z, "z"))
end

-- Юниты внутри зоны. Парам: name; opts — фильтры как в targeting.inCircle. Возвращает { h, ... }.
-- Сторона: везде, но нужна активная игра. Ошибки: нет зоны; нет игры.
function regions.units(name, opts)
    if not game.isInGame() then error("regions.units: no active game", 2) end
    local z = zone(name, "units")
    opts = opts or {}
    local cx, cz = (z.box.x1 + z.box.x2) / 2, (z.box.z1 + z.box.z2) / 2
    local r = math.max(z.box.x2 - z.box.x1, z.box.z2 - z.box.z1) / 2
    local out = {}
    for _, h in ipairs(targeting.inCircle(cx, cz, r, opts)) do
        local px, pz = objects.pos(h)
        if px and inPoly(z.poly, px, pz) then out[#out + 1] = h end
    end
    return out
end

local function ensureWatch(zname)
    local z = zones[zname]
    if z.subId or (#z.onEnter == 0 and #z.onLeave == 0) then return end
    z.subId = events.on("game.tick", function()
        if not game.isInGame() then return end
        local now = {}
        for _, h in ipairs(regions.units(zname, {})) do now[h] = true end
        local was = inside[zname] or {}
        for h in pairs(now) do
            if not was[h] then
                for _, fn in ipairs(z.onEnter) do pcall(fn, h) end
            end
        end
        for h in pairs(was) do
            if not now[h] then
                for _, fn in ipairs(z.onLeave) do pcall(fn, h) end
            end
        end
        inside[zname] = now
    end)
end

-- Подписаться на вход в зону (каждый вход, fn(h), ошибки глушатся pcall). Парам: name; fn — функция.
-- Ничего не возвращает. Сторона: везде (тикет game.tick). Ошибки: нет зоны; fn не функция.
function regions.onEnter(name, fn)
    if type(fn) ~= "function" then error("regions.onEnter: fn must be a function", 2) end
    local z = zone(name, "onEnter")
    z.onEnter[#z.onEnter + 1] = fn
    ensureWatch(name)
end

-- Подписаться на выход из зоны (каждый выход, fn(h), ошибки глушатся pcall). Парам: name; fn — функция.
-- Ничего не возвращает. Сторона: везде (тикет game.tick). Ошибки: нет зоны; fn не функция.
function regions.onLeave(name, fn)
    if type(fn) ~= "function" then error("regions.onLeave: fn must be a function", 2) end
    local z = zone(name, "onLeave")
    z.onLeave[#z.onLeave + 1] = fn
    ensureWatch(name)
end

-- regions.block(name, on): запретная территория — резать приказы с точкой внутри. Парам: name; on — true/false (nil = true).
-- Ничего не возвращает. Сторона: только shared (одинаково на всех машинах). Ошибки: нет зоны; вызов не из shared.
function regions.block(name, on)
    if not game.exec then
        error("regions.block: only shared scripts (same on all machines)", 2)
    end
    local z = zone(name, "block")
    if on == nil then on = true end
    if on and not z.blocked then
        z.blocked = true
        z.blockSub = events.on("unit.order", function(_, _, _, _, x, zz)
            if x and zz and inPoly(z.poly, x, zz) then return true end
        end)
    elseif not on and z.blocked then
        z.blocked = false
        if z.blockSub then events.off(z.blockSub) z.blockSub = nil end
    end
end
