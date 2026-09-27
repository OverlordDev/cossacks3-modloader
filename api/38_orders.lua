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
-- ВАЖНО (ScriptRunner): вызов game.exec(code) кэшируется ПО ТЕКСТУ code — новый
-- текст = новое скомпилированное состояние ModLoader.Call.N, и оно живёт до конца
-- партии (модлоадер сам ругается на 500: "pass changing values via arg, not in
-- the code text"). Поэтому здесь ровно ОДИН текст состояния на вид приказа, а все
-- значения (хендл, координаты, цель, флаги) едут через ML_ARG. Если вшить их в
-- код, то orders.move на 100 юнитов создаст 100 состояний, а за партию их
-- наберутся тысячи — и каждое это отдельный скомпилированный кусок в GUI-машине.
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

-- Разбор аргументов ML_ARG. Один и тот же текст на ВСЕ вызовы данного вида приказа.
-- Строки — функциями движка (StrPos/SubStr/StrLength, как в скриптах игры): Pos/Copy/Delete
-- в этом диалекте Pascal нет, с ними состояние не компилировалось (Compile script error: ModLoader.Call.N).
-- Формат: h|trg|f1..f6|i1..i5|clear|first  (вещественные — тысячные).
local PARSE = [[
var s : String = ML_ARG;
var p, h, trg : Integer;
var f1, f2, f3, f4, f5, f6 : Integer;
var i1, i2, i3, i4, i5, cl, fi : Integer;
p := StrPos('|', s); h := StrToInt(SubStr(s, 1, p-1)); s := SubStr(s, p+1, StrLength(s)-p);
p := StrPos('|', s); trg := StrToInt(SubStr(s, 1, p-1)); s := SubStr(s, p+1, StrLength(s)-p);
p := StrPos('|', s); f1 := StrToInt(SubStr(s, 1, p-1)); s := SubStr(s, p+1, StrLength(s)-p);
p := StrPos('|', s); f2 := StrToInt(SubStr(s, 1, p-1)); s := SubStr(s, p+1, StrLength(s)-p);
p := StrPos('|', s); f3 := StrToInt(SubStr(s, 1, p-1)); s := SubStr(s, p+1, StrLength(s)-p);
p := StrPos('|', s); f4 := StrToInt(SubStr(s, 1, p-1)); s := SubStr(s, p+1, StrLength(s)-p);
p := StrPos('|', s); f5 := StrToInt(SubStr(s, 1, p-1)); s := SubStr(s, p+1, StrLength(s)-p);
p := StrPos('|', s); f6 := StrToInt(SubStr(s, 1, p-1)); s := SubStr(s, p+1, StrLength(s)-p);
p := StrPos('|', s); i1 := StrToInt(SubStr(s, 1, p-1)); s := SubStr(s, p+1, StrLength(s)-p);
p := StrPos('|', s); i2 := StrToInt(SubStr(s, 1, p-1)); s := SubStr(s, p+1, StrLength(s)-p);
p := StrPos('|', s); i3 := StrToInt(SubStr(s, 1, p-1)); s := SubStr(s, p+1, StrLength(s)-p);
p := StrPos('|', s); i4 := StrToInt(SubStr(s, 1, p-1)); s := SubStr(s, p+1, StrLength(s)-p);
p := StrPos('|', s); i5 := StrToInt(SubStr(s, 1, p-1)); s := SubStr(s, p+1, StrLength(s)-p);
p := StrPos('|', s); cl := StrToInt(SubStr(s, 1, p-1)); s := SubStr(s, p+1, StrLength(s)-p);
fi := StrToInt(s);]]

-- Один приказ одному юниту. f — шесть вещественных (тысячные), ints — пять целых.
-- clear/first кладутся в ML_ARG и передаются как `cl <> 0` / `fi <> 0`: параметры
-- _unit_AddOrder объявлены const Boolean, поэтому присваивание в списке
-- аргументов (cl = 1) не компилируется, а Integer вместо Boolean — тоже.
local function issue(h, typeName, trg, f, ints, clear, first)
    h = checkHandle(h)
    local function scaled(n) return tostring(math.floor(n * 1000 + (n >= 0 and 0.5 or -0.5))) end
    local code = PARSE .. string.format(
        "_unit_AddOrder(h, %s, trg, f1/1000, f2/1000, f3/1000, f4/1000, f5/1000, f6/1000, " ..
        "i1, i2, i3, i4, i5, cl <> 0, fi <> 0);",
        typeName)
    game.exec(code, table.concat({ h, trg,
        scaled(f[1]), scaled(f[2]), scaled(f[3]), scaled(f[4]), scaled(f[5]), scaled(f[6]),
        ints[1], ints[2], ints[3], ints[4], ints[5],
        clear == false and 0 or 1, first == true and 1 or 0 }, "|"))
end

-- Идти в точку. opts = { clear = true, first = false, angle = 0 }.
function orders.move(units, x, z, opts)
    needServer("move")
    x, z = num(x, "x"), num(z, "z")
    opts = opts or {}
    local angle = num(opts.angle or 0, "angle")
    for _, h in ipairs(each(units)) do
        issue(h, "gc_obj_order_type_move", 0,
            { x, z, 0, 0, angle, 0 }, { 0, 0, 0, 0, 0 },
            opts.clear, opts.first)
    end
end

-- Идти в точку, атакуя всё по пути.
function orders.attackMove(units, x, z, opts)
    needServer("attackMove")
    x, z = num(x, "x"), num(z, "z")
    opts = opts or {}
    for _, h in ipairs(each(units)) do
        issue(h, "gc_obj_order_type_attackpoint", 0,
            { 0, 0, x, z, 0, 0 }, { 0, 0, 0, 0, 0 },
            opts.clear, opts.first)
    end
end

-- Атаковать объект. opts = { clear, first, lock } (lock — держать цель).
function orders.attack(units, target, opts)
    needServer("attack")
    target = checkHandle(target)
    opts = opts or {}
    local lock = opts.lock and 1 or 0
    for _, h in ipairs(each(units)) do
        issue(h, "gc_obj_order_type_attackobj", target,
            { 0, 0, 0, 0, 0, 0 }, { 0, 0, 0, 0, lock },
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
        issue(h, "gc_obj_order_type_patrol", 0,
            { px or x1, pz or z1, x2, z2, 0, 0 }, { 0, 0, 0, 0, 0 },
            opts.clear, opts.first)
    end
end

-- Охранять/сопровождать объект (конвой — follow за лидером).
function orders.guard(units, target, opts)
    needServer("guard")
    target = checkHandle(target)
    opts = opts or {}
    for _, h in ipairs(each(units)) do
        issue(h, "gc_obj_order_type_guard", target,
            { 0, 0, 0, 0, 0, 0 }, { 0, 0, 0, 0, 0 },
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
-- Два текста кода на весь мод — это не раздувание состояний, в отличие от
-- варианта с координатами в коде.
function orders.cancel(units, full)
    needServer("cancel")
    local code = full and "var s : String = ML_ARG; _unit_FullClearOrders(StrToInt(s));"
                     or "var s : String = ML_ARG; _unit_ClearOrders(StrToInt(s));"
    for _, h in ipairs(each(units)) do
        game.exec(code, tostring(checkHandle(h)))
    end
end
