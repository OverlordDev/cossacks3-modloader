-- formation — построения: геометрия слотов + раздача приказов.
--
-- Чистая геометрия работает везде; set() отдаёт приказы — только server/shared.
--
--   formation.set(units, "wedge", { x = 100, z = 50, spacing = 3, angle = 0 })
--   local slots = formation.slots("square", 12, 3, 0, 100, 50)  --> { {x,z}, ... }
--
-- Формы: "line" (шеренга), "column" (колонна), "wedge" (клин), "square" (каре),
-- "circle" (кольцо). angle — facing строя в радианах (0 — на север, +z).
-- Центр по умолчанию — центроид отряда. Порядок слотов — по порядку юнитов.

formation = {}

local SHAPES = { line = true, column = true, wedge = true, square = true, circle = true }

local function num(v, name)
    local n = tonumber(v)
    if not n or n ~= n then error("formation: " .. name .. " must be a number", 3) end
    return n
end

-- Позиции слотов: shape, count, spacing, angle, cx, cz → { {x, z} }.
function formation.slots(shape, count, spacing, angle, cx, cz)
    if not SHAPES[shape] then
        error("formation: unknown shape '" .. tostring(shape) .. "' (line/column/wedge/square/circle)", 2)
    end
    count = math.tointeger(tonumber(count))
    if not count or count < 1 then error("formation: count must be >= 1", 2) end
    spacing, angle = num(spacing or 3, "spacing"), num(angle or 0, "angle")
    cx, cz = num(cx or 0, "cx"), num(cz or 0, "cz")
    local dx, dz = math.sin(angle), math.cos(angle)     -- вперёд
    local px, pz = dz, -dx                              -- вправо
    local out = {}
    if shape == "line" then
        for i = 1, count do
            local off = (i - (count + 1) / 2) * spacing
            out[i] = { x = cx + px * off, z = cz + pz * off }
        end
    elseif shape == "column" then
        for i = 1, count do
            local off = -(i - 1) * spacing
            out[i] = { x = cx + dx * off, z = cz + dz * off }
        end
    elseif shape == "wedge" then
        out[1] = { x = cx, z = cz }
        local rank = 1
        local i = 2
        while i <= count do
            for _, side in ipairs({ -1, 1 }) do
                if i > count then break end
                out[i] = { x = cx + px * side * rank * spacing - dx * rank * spacing,
                           z = cz + pz * side * rank * spacing - dz * rank * spacing }
                i = i + 1
            end
            rank = rank + 1
        end
    elseif shape == "square" then
        local side = math.ceil(math.sqrt(count))
        for i = 1, count do
            local r, c = math.floor((i - 1) / side), (i - 1) % side
            local offr, offc = (r - (side - 1) / 2) * spacing, (c - (side - 1) / 2) * spacing
            out[i] = { x = cx + px * offc - dx * offr, z = cz + pz * offc - dz * offr }
        end
    elseif shape == "circle" then
        local r = math.max(spacing, count * spacing / (2 * math.pi))
        for i = 1, count do
            local a = angle + (i - 1) / count * 2 * math.pi
            out[i] = { x = cx + math.sin(a) * r, z = cz + math.cos(a) * r }
        end
    end
    return out
end

-- Построить отряд строем и отдать приказы (move или attackpoint).
-- opts = { x=, z= (центр; по умолчанию центроид), spacing=3, angle=0,
--          order="move", clear=true }.
function formation.set(units, shape, opts)
    if not game.exec then
        error("formation.set: only server/shared scripts can order units", 2)
    end
    if type(units) ~= "table" or #units == 0 then
        error("formation.set: non-empty unit list required", 2)
    end
    opts = opts or {}
    local cx, cz = opts.x, opts.z
    if cx == nil or cz == nil then
        local sx, sz, n = 0, 0, 0
        for _, h in ipairs(units) do
            local x, z = objects.pos(h)
            if x then sx, sz, n = sx + x, sz + z, n + 1 end
        end
        if n == 0 then error("formation.set: no positioned units", 2) end
        cx, cz = opts.x or sx / n, opts.z or sz / n
    end
    local slots = formation.slots(shape, #units, opts.spacing or 3, opts.angle or 0, cx, cz)
    local order = opts.order or "move"
    for i, h in ipairs(units) do
        if order == "attackpoint" then
            orders.attackMove(h, slots[i].x, slots[i].z, { clear = opts.clear })
        else
            orders.move(h, slots[i].x, slots[i].z, { clear = opts.clear })
        end
    end
    return slots
end
