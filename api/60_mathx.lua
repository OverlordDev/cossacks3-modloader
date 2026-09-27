-- mathx — чистая скалярная математика (без вызовов игры, везде: shared/lockstep-safe).
--
-- Только вычисления: никаких game/native/objects/events. Числа в Lua immutable,
-- входы не мутируются. Библиотеки math/table/string/os НЕ изменяются, только читаются.
-- math.random НЕ используется в этом файле.
-- NaN и не-числа везде — ошибка вида "mathx.<fn>: <param> must be a number".
-- Углы везде в РАДИАНАХ.
--
--   local hp = mathx.clamp(hp - dmg, 0, maxHp)
--   local t = mathx.inverseLerp(0, 10, dist)         -- 0..1 без clamp
--   cur = mathx.approach(cur, target, speed * dt)    -- не перескакивает цель
--   local a = mathx.wrap(angle + turn, -math.pi, math.pi)
--
-- Сторона: везде (pure Lua). Десинка нет (детерминированные вычисления).

mathx = {}

local TAU = math.pi * 2

-- Проверить число (NaN/не-число/не-числовая строка — ошибка с именем вызывателя).
local function checkNum(v, fname, pname)
    local n = tonumber(v)
    if n == nil or n ~= n then
        error("mathx." .. fname .. ": " .. pname .. " must be a number", 3)
    end
    return n
end

-- mathx.clamp(x, min, max): ограничить x диапазоном [min, max] включительно.
-- min > max — ошибка. Возврат: число. Сторона: везде (pure).
-- Ошибки: mathx.clamp: x/min/max must be a number; mathx.clamp: min > max.
function mathx.clamp(x, min, max)
    x = checkNum(x, "clamp", "x")
    min = checkNum(min, "clamp", "min")
    max = checkNum(max, "clamp", "max")
    if min > max then
        error("mathx.clamp: min > max", 2)
    end
    if x < min then return min end
    if x > max then return max end
    return x
end

-- mathx.lerp(a, b, t): линейная интерполяция a + (b - a) * t.
-- t НЕ ограничивается [0,1] (значения вне — экстраполяция). Возврат: число.
-- Сторона: везде (pure). Ошибки: mathx.lerp: a/b/t must be a number.
function mathx.lerp(a, b, t)
    a = checkNum(a, "lerp", "a")
    b = checkNum(b, "lerp", "b")
    t = checkNum(t, "lerp", "t")
    return a + (b - a) * t
end

-- mathx.inverseLerp(a, b, x): обратная интерполяция (x - a) / (b - a).
-- a == b — ошибка (деление на ноль). t НЕ ограничивается [0,1]. Возврат: число.
-- Сторона: везде (pure). Ошибки: mathx.inverseLerp: ...; a and b must differ.
function mathx.inverseLerp(a, b, x)
    a = checkNum(a, "inverseLerp", "a")
    b = checkNum(b, "inverseLerp", "b")
    x = checkNum(x, "inverseLerp", "x")
    if a == b then
        error("mathx.inverseLerp: a and b must differ", 2)
    end
    return (x - a) / (b - a)
end

-- mathx.remap(x, inMin, inMax, outMin, outMax): переложить x из диапазона в диапазон.
-- inMin == inMax — ошибка. t НЕ ограничивается (экстраполяция). Возврат: число.
-- Сторона: везде (pure). Ошибки: mathx.remap: ...; inMin and inMax must differ.
function mathx.remap(x, inMin, inMax, outMin, outMax)
    x = checkNum(x, "remap", "x")
    inMin = checkNum(inMin, "remap", "inMin")
    inMax = checkNum(inMax, "remap", "inMax")
    outMin = checkNum(outMin, "remap", "outMin")
    outMax = checkNum(outMax, "remap", "outMax")
    if inMin == inMax then
        error("mathx.remap: inMin and inMax must differ", 2)
    end
    local t = (x - inMin) / (inMax - inMin)
    return outMin + (outMax - outMin) * t
end

-- mathx.round(x, decimals): округление до decimals знаков (default 0, half-up:
-- 0.5 вверх; round(-1.5) = -1). decimals — целое >= 0, иначе ошибка.
-- Возврат: число. Сторона: везде (pure).
-- Ошибки: mathx.round: x must be a number; decimals must be a non-negative integer.
function mathx.round(x, decimals)
    x = checkNum(x, "round", "x")
    if decimals == nil then decimals = 0 end
    local d = math.tointeger(decimals)
    if not d or d < 0 then
        error("mathx.round: decimals must be a non-negative integer", 2)
    end
    local m = 10 ^ d
    return math.floor(x * m + 0.5) / m
end

-- mathx.floor(x): округление вниз (math.floor с проверкой числа). Возврат: integer/число.
-- Сторона: везде (pure). Ошибки: mathx.floor: x must be a number.
function mathx.floor(x)
    x = checkNum(x, "floor", "x")
    return math.floor(x)
end

-- mathx.ceil(x): округление вверх (math.ceil с проверкой числа). Возврат: integer/число.
-- Сторона: везде (pure). Ошибки: mathx.ceil: x must be a number.
function mathx.ceil(x)
    x = checkNum(x, "ceil", "x")
    return math.ceil(x)
end

-- mathx.sign(x): знак числа (1 / -1 / 0; sign(0) = 0). NaN — ошибка. Возврат: число.
-- Сторона: везде (pure). Ошибки: mathx.sign: x must be a number.
function mathx.sign(x)
    x = checkNum(x, "sign", "x")
    if x > 0 then return 1 end
    if x < 0 then return -1 end
    return 0
end

-- mathx.abs(x): модуль числа. NaN — ошибка. Возврат: число. Сторона: везде (pure).
-- Ошибки: mathx.abs: x must be a number.
function mathx.abs(x)
    x = checkNum(x, "abs", "x")
    return math.abs(x)
end

-- mathx.approach(current, target, delta): сдвинуть current к target на delta, но
-- НЕ перескакивать цель (если до цели ближе delta — вернуть target).
-- delta < 0 — ошибка. delta = 0 возвращает current. Возврат: число.
-- Сторона: везде (pure).
-- Ошибки: mathx.approach: ...; delta must be non-negative.
function mathx.approach(current, target, delta)
    current = checkNum(current, "approach", "current")
    target = checkNum(target, "approach", "target")
    delta = checkNum(delta, "approach", "delta")
    if delta < 0 then
        error("mathx.approach: delta must be non-negative", 2)
    end
    if current < target then
        local v = current + delta
        if v > target then return target end
        return v
    elseif current > target then
        local v = current - delta
        if v < target then return target end
        return v
    end
    return target
end

-- mathx.moveTowards(current, target, delta): алиас approach (то же поведение,
-- цель не перескакивается). Возврат: число. Сторона: везде (pure).
function mathx.moveTowards(current, target, delta)
    return mathx.approach(current, target, delta)
end

-- mathx.smoothstep(edge0, edge1, x): плавный переход 0..1 (t*t*(3-2*t)).
-- edge0 < edge1 обязательно, иначе ошибка. x вне диапазона даёт 0/1. Возврат: число.
-- Сторона: везде (pure). Ошибки: mathx.smoothstep: ...; edge0 must be < edge1.
function mathx.smoothstep(edge0, edge1, x)
    edge0 = checkNum(edge0, "smoothstep", "edge0")
    edge1 = checkNum(edge1, "smoothstep", "edge1")
    x = checkNum(x, "smoothstep", "x")
    if edge0 >= edge1 then
        error("mathx.smoothstep: edge0 must be < edge1", 2)
    end
    local t = (x - edge0) / (edge1 - edge0)
    if t < 0 then t = 0 end
    if t > 1 then t = 1 end
    return t * t * (3 - 2 * t)
end

-- mathx.smootherstep(edge0, edge1, x): более плавный переход 0..1 (t^3*(t*(t*6-15)+10)).
-- edge0 < edge1 обязательно, иначе ошибка. Возврат: число. Сторона: везде (pure).
-- Ошибки: mathx.smootherstep: ...; edge0 must be < edge1.
function mathx.smootherstep(edge0, edge1, x)
    edge0 = checkNum(edge0, "smootherstep", "edge0")
    edge1 = checkNum(edge1, "smootherstep", "edge1")
    x = checkNum(x, "smootherstep", "x")
    if edge0 >= edge1 then
        error("mathx.smootherstep: edge0 must be < edge1", 2)
    end
    local t = (x - edge0) / (edge1 - edge0)
    if t < 0 then t = 0 end
    if t > 1 then t = 1 end
    return t * t * t * (t * (t * 6 - 15) + 10)
end

-- mathx.pingPong(t, length): треугольная волна 0..length..0 (период 2*length).
-- Отрицательные t корректны. length > 0 обязательно. Возврат: число.
-- Сторона: везде (pure). Ошибки: mathx.pingPong: ...; length must be positive.
function mathx.pingPong(t, length)
    t = checkNum(t, "pingPong", "t")
    length = checkNum(length, "pingPong", "length")
    if length <= 0 then
        error("mathx.pingPong: length must be positive", 2)
    end
    local m = t % (2 * length)
    return length - math.abs(m - length)
end

-- mathx.wrap(value, min, max): завернуть value в полуинтервал [min, max).
-- Корректен для отрицательных (wrap(-1, 0, 3) = 2). min < max обязательно.
-- Возврат: число. Сторона: везде (pure).
-- Ошибки: mathx.wrap: ...; min must be < max.
function mathx.wrap(value, min, max)
    value = checkNum(value, "wrap", "value")
    min = checkNum(min, "wrap", "min")
    max = checkNum(max, "wrap", "max")
    if min >= max then
        error("mathx.wrap: min must be < max", 2)
    end
    return min + ((value - min) % (max - min))
end

-- mathx.degToRad(degrees): градусы в радианы. Возврат: число. Сторона: везде (pure).
-- Ошибки: mathx.degToRad: degrees must be a number.
function mathx.degToRad(degrees)
    degrees = checkNum(degrees, "degToRad", "degrees")
    return degrees * math.pi / 180
end

-- mathx.radToDeg(radians): радианы в градусы. Возврат: число. Сторона: везде (pure).
-- Ошибки: mathx.radToDeg: radians must be a number.
function mathx.radToDeg(radians)
    radians = checkNum(radians, "radToDeg", "radians")
    return radians * 180 / math.pi
end

-- mathx.normalizeAngle(a): привести угол (радианы) к [-pi, pi].
-- -pi и pi — один угол; pi возвращается как -pi. Возврат: число.
-- Сторона: везде (pure). Ошибки: mathx.normalizeAngle: a must be a number.
function mathx.normalizeAngle(a)
    a = checkNum(a, "normalizeAngle", "a")
    return ((a + math.pi) % TAU) - math.pi
end

-- mathx.angleDiff(a, b): знаковая кратчайшая разность (b - a) в [-pi, pi] (радианы).
-- Плюс — против часовой от a к b. Возврат: число. Сторона: везде (pure).
-- Ошибки: mathx.angleDiff: a/b must be a number.
function mathx.angleDiff(a, b)
    a = checkNum(a, "angleDiff", "a")
    b = checkNum(b, "angleDiff", "b")
    return mathx.normalizeAngle(b - a)
end

-- mathx.isNearlyEqual(a, b, epsilon): |a - b| <= epsilon (epsilon default 1e-6).
-- epsilon < 0 — ошибка. Возврат: boolean. Сторона: везде (pure).
-- Ошибки: mathx.isNearlyEqual: ...; epsilon must be a non-negative number.
function mathx.isNearlyEqual(a, b, epsilon)
    a = checkNum(a, "isNearlyEqual", "a")
    b = checkNum(b, "isNearlyEqual", "b")
    if epsilon == nil then epsilon = 1e-6 end
    epsilon = checkNum(epsilon, "isNearlyEqual", "epsilon")
    if epsilon < 0 then
        error("mathx.isNearlyEqual: epsilon must be a non-negative number", 2)
    end
    return math.abs(a - b) <= epsilon
end
