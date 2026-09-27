-- orders — отдача приказов юнитам из мода: движение, атака, патруль, очередь.
--
-- МЕНЯЕТ МИР: только server/shared (приказы уходят в симуляцию и в сеть).
-- Вызовы идут через _unit_AddOrder игры (сигнатура из data/scripts/lib/unit.script),
-- поэтому проходят обычные события unit.order и логика ИИ.
--
--   orders.move(h, x, z)                       -- один юнит; orders.move({h1, h2}, x, z)
--   orders.move(units, x, z, { clear = false }) -- не сбрасывать очередь (добавить в конец)
--   orders.attackMove(units, x, z)             -- идти и атаковать по пути
--   orders.attack(units, target)               -- бить объект; { lock = true } — держать цель
--   orders.patrol(h, x1, z1, x2, z2)           -- патруль между точками (старт — текущая поз.)
--   orders.follow(h, target)                   -- сопровождение (guard); orders.guard(h, target)
--   orders.queue(h, { { move = {x, z} }, { patrol = {x1,z1,x2,z2} } })
--   orders.cancel(h)                           -- сбросить очередь; orders.cancel(h, true) — жёстко
--
-- Каждый приказ — один вызов Pascal (~1 мс): сотню юнитов за тик не двигайте,
-- растягивайте построение на несколько тиков.

orders = {}

local function needServer(where)
    if not game.exec then
        error("orders." .. where .. ": only server/shared scripts can order units", 3)
    end
    if not game.isInGame() then
        error("orders." .. where .. ": no active game (check game.isInGame())", 3)
    end
end

local function checkHandle(h)
    h = math.tointeger(tonumber(h))
    if not h or h == 0 then error("orders: handle must be a non-zero number", 3) end
    return h
end

local function num(v, name)
    local n = tonumber(v)
    if not n or n ~= n then error("orders: " .. name .. " must be a number", 3) end
    return n
end

local function each(units)
    if type(units) == "table" then return units end
    return { units }
end

-- Один приказ одному юниту через игру. kind — gc_obj_order_type_*, args — строка
-- остальных параметров _unit_AddOrder. clear — сбросить очередь, first — в начало.
local function issue(h, typeName, args, clear, first)
    h = checkHandle(h)
    local code = string.format(
        "_unit_AddOrder(%d, %s, %s, %s, %s);",
        h, typeName, args,
        clear == false and "False" or "True",
        first == true and "True" or "False")
    game.exec(code)
end

local function fmt(n) return string.format("%.3f", n) end

-- Идти в точку. opts = { clear = true, first = false, angle = 0 }.
function orders.move(units, x, z, opts)
    needServer("move")
    x, z = num(x, "x"), num(z, "z")
    opts = opts or {}
    for _, h in ipairs(each(units)) do
        issue(h, "gc_obj_order_type_move",
            string.format("0, %s, %s, 0, 0, %s, 0, 0, 0, 0, 0, 0",
                fmt(x), fmt(z), fmt(num(opts.angle or 0, "angle"))),
            opts.clear, opts.first)
    end
end

-- Идти в точку, атакуя всё по пути.
function orders.attackMove(units, x, z, opts)
    needServer("attackMove")
    x, z = num(x, "x"), num(z, "z")
    opts = opts or {}
    for _, h in ipairs(each(units)) do
        issue(h, "gc_obj_order_type_attackpoint",
            string.format("0, 0, 0, %s, %s, 0, 0, 0, 0, 0, 0, 0, 0", fmt(x), fmt(z)),
            opts.clear, opts.first)
    end
end

-- Атаковать объект. opts = { clear, first, lock } (lock — держать цель).
function orders.attack(units, target, opts)
    needServer("attack")
    target = checkHandle(target)
    opts = opts or {}
    for _, h in ipairs(each(units)) do
        issue(h, "gc_obj_order_type_attackobj",
            string.format("%d, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, %d",
                target, opts.lock and 1 or 0),
            opts.clear, opts.first)
    end
end

-- Патруль между (x1, z1) и (x2, z2). Стартовая точка — текущая позиция юнита.
function orders.patrol(units, x1, z1, x2, z2, opts)
    needServer("patrol")
    x1, z1, x2, z2 = num(x1, "x1"), num(z1, "z1"), num(x2, "x2"), num(z2, "z2")
    opts = opts or {}
    for _, h in ipairs(each(units)) do
        local px, pz = objects.pos(checkHandle(h))
        issue(h, "gc_obj_order_type_patrol",
            string.format("0, %s, %s, %s, %s, 0, 0, 0, 0, 0, 0, 0, 0",
                fmt(px or x1), fmt(pz or z1), fmt(x2), fmt(z2)),
            opts.clear, opts.first)
    end
end

-- Охранять/сопровождать объект (конвой — follow за лидером).
function orders.guard(units, target, opts)
    needServer("guard")
    target = checkHandle(target)
    opts = opts or {}
    for _, h in ipairs(each(units)) do
        issue(h, "gc_obj_order_type_guard",
            string.format("%d, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0", target),
            opts.clear, opts.first)
    end
end
orders.follow = orders.guard

-- Цепочка приказов одному юниту (первый с clear, остальные в очередь).
--   orders.queue(h, { { move = {10, 20} }, { attackpoint = {30, 40} }, { guard = tgt } })
function orders.queue(h, list)
    needServer("queue")
    h = checkHandle(h)
    if type(list) ~= "table" or #list == 0 then error("orders.queue: non-empty list required", 2) end
    for i, step in ipairs(list) do
        local clear = (i == 1)
        if step.move then
            orders.move(h, step.move[1], step.move[2], { clear = clear, first = false })
        elseif step.attackpoint then
            orders.attackMove(h, step.attackpoint[1], step.attackpoint[2], { clear = clear })
        elseif step.attack then
            orders.attack(h, step.attack, { clear = clear })
        elseif step.guard then
            orders.guard(h, step.guard, { clear = clear })
        elseif step.patrol then
            local p = step.patrol
            orders.patrol(h, p[1], p[2], p[3], p[4], { clear = clear })
        else
            error("orders.queue: step " .. i .. " needs move/attackpoint/attack/guard/patrol", 2)
        end
    end
end

-- Сбросить очередь приказов. full=true — _unit_FullClearOrders (и текущее действие).
function orders.cancel(units, full)
    needServer("cancel")
    for _, h in ipairs(each(units)) do
        h = checkHandle(h)
        game.exec(string.format(full and "_unit_FullClearOrders(%d);" or "_unit_ClearOrders(%d);", h))
    end
end
