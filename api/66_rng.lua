-- rng — детерминированный ГСЧ (Lua 5.4 integers, БЕЗ math.random).
--
-- Алгоритм: splitmix64 (два независимых потока _a/_b, выход = сумма скремблов).
-- Сид через splitmix-раскрутку; состояние { a=, b= } — два int64, сериализуемо.
-- ВНИМАНИЕ (десинхрон): разное число вызовов next* в ветвях if/random ветках —
-- расхождение последовательностей между машинами. В shared вызывайте строго
-- одинаковое число раз на всех машинах (не прячьте next* за локальными if).
-- pick({}) возвращает nil (без ошибки и без расхода ГСЧ).
-- chance(p) всегда расходует один nextFloat (даже при p=0/1) — число вызовов стабильно.
-- shuffle(list) возвращает НОВУЮ таблицу, вход не мутирует.
-- seedFromGame/sharedSeed — только shared (одинаково на всех машинах), БЕЗ времени/адресов.
--
--   local r = rng.new(12345)
--   r:nextInt(1, 6) --> кубик включительно; r:nextFloat() --> [0,1); r:range(10, 20)
--   r:pick({ "a", "b" }); r:chance(0.25); r:shuffle({ 1, 2, 3 }) --> новая таблица
--   local s = r:state(); r:setState(s) -- откат
--   local g = rng.new(rng.seedFromGame())       -- сид матча
--   local b = rng.new(rng.sharedSeed("loot"))   -- сид на имя (FNV-1a xor сид матча)

rng = {}

local INC = 0x9E3779B97F4A7C15
local M1 = 0xBF58476D1CE4E5B9
local M2 = 0x94D049BB133111EB
local FNV_OFFSET = 0xCBF29CE484222325
local FNV_PRIME = 0x100000001B3
local DEN53 = 9007199254740992.0

-- Логический сдвиг вправо (>> в Lua арифметический для отрицательных — гасим маской).
local function lshr(x, n)
    if n <= 0 then return x end
    if n >= 64 then return 0 end
    if x >= 0 then return x >> n end
    return (x >> n) & ((1 << (64 - n)) - 1)
end

-- Один скрембл splitmix64 (чистая функция от 64-битного входа).
local function scramble(z)
    z = (z ~ lshr(z, 30)) * M1
    z = (z ~ lshr(z, 27)) * M2
    return z ~ lshr(z, 31)
end

-- Вывести (a,b) сида из seed: число или { a=, b= }. Возвращает два int64 (a ~= b).
local function deriveSeed(seed, where)
    local a, b
    if type(seed) == "table" then
        a = math.tointeger(seed.a)
        b = math.tointeger(seed.b)
        if not a or not b then
            error("rng." .. where .. ": seed table must be {a=,b=} integers", 3)
        end
    else
        local s = math.tointeger(seed)
        if not s then
            error("rng." .. where .. ": seed must be an integer or {a=,b=}", 3)
        end
        a = s
        b = s ~ INC
        -- Прогнать по одному шагу чтобы нулевой сид не давал нулевое состояние.
        a = a + INC
        b = b + INC
    end
    if a == b then b = b + INC end
    return a, b
end

-- Проверить целое для nextInt.
local function checkInt(v, where, pname)
    local n = math.tointeger(v)
    if not n then
        error("rng." .. where .. ": " .. pname .. " must be an integer", 3)
    end
    return n
end

-- Проверить число для range/chance.
local function checkFloat(v, where, pname)
    local n = tonumber(v)
    if not n or n ~= n then
        error("rng." .. where .. ": " .. pname .. " must be a number", 3)
    end
    return n
end

-- Конструктор: rng.new(seed) — seed целое или { a=, b= }. Возвращает объект ГСЧ.
function rng.new(seed)
    local a, b = deriveSeed(seed, "new")
    local o = {}
    -- Сырой следующий uint64 (знаковый int64-паттерн). Расходует оба потока.
    local function nextUInt()
        a = a + INC
        b = b + INC
        return scramble(a) + scramble(b)
    end
    -- Сырой next: возвращает 64-битный паттерн (может быть отрицательным как signed).
    function o.next(self)
        return nextUInt()
    end
    -- Целое в [min, max] включительно. min == max возвращает min без расхода ГСЧ.
    function o.nextInt(self, min, max)
        local imin = checkInt(min, "nextInt", "min")
        local imax = checkInt(max, "nextInt", "max")
        if imin > imax then
            error("rng.nextInt: min > max", 2)
        end
        if imin == imax then return imin end
        if imin == math.mininteger and imax == math.maxinteger then
            return nextUInt()
        end
        local size = imax - imin + 1
        if size <= 0 then
            error("rng.nextInt: range too large", 2)
        end
        return imin + (nextUInt() % size)
    end
    -- Дробное в [0, 1) (старшие 53 бита / 2^53).
    function o.nextFloat(self)
        return lshr(nextUInt(), 11) / DEN53
    end
    -- Дробное в [min, max): min == max возвращает min без расхода ГСЧ.
    function o.range(self, min, max)
        local fmin = checkFloat(min, "range", "min")
        local fmax = checkFloat(max, "range", "max")
        if fmin > fmax then
            error("rng.range: min > max", 2)
        end
        if fmin == fmax then return fmin end
        return fmin + (lshr(nextUInt(), 11) / DEN53) * (fmax - fmin)
    end
    -- Случайный элемент списка; пустой список даёт nil (без ошибки, без расхода ГСЧ).
    function o.pick(self, list)
        if type(list) ~= "table" then
            error("rng.pick: list must be a table", 2)
        end
        local n = #list
        if n == 0 then return nil end
        return list[o.nextInt(o, 1, n)]
    end
    -- true с вероятностью p в [0, 1] (всегда расходует один nextFloat).
    function o.chance(self, p)
        local fp = checkFloat(p, "chance", "p")
        if fp < 0 or fp > 1 then
            error("rng.chance: p must be in [0,1]", 2)
        end
        return (lshr(nextUInt(), 11) / DEN53) < fp
    end
    -- Перемешанная КОПИЯ списка (вход не мутирует). Возвращает новую таблицу.
    function o.shuffle(self, list)
        if type(list) ~= "table" then
            error("rng.shuffle: list must be a table", 2)
        end
        local n = #list
        local out = {}
        for i = 1, n do out[i] = list[i] end
        for i = n, 2, -1 do
            local j = o.nextInt(o, 1, i)
            out[i], out[j] = out[j], out[i]
        end
        return out
    end
    -- Снимок состояния { a=, b= } (копия, сериализуема).
    function o.state(self)
        return { a = a, b = b }
    end
    -- Восстановить состояние из state(). Возвращает nil. Ошибки: bad state.
    function o.setState(self, s)
        if type(s) ~= "table" then
            error("rng.setState: state must be {a=,b=}", 2)
        end
        local na = math.tointeger(s.a)
        local nb = math.tointeger(s.b)
        if not na or not nb then
            error("rng.setState: state must be {a=,b=} integers", 2)
        end
        a, b = na, nb
    end
    return o
end

-- Сид матча из gMap.settings.gen.randkey0/1 через game.evalInt под pcall.
-- Вне игры (нет game/isInGame/evalInt) — ошибка. Возвращает int64.
function rng.seedFromGame()
    local g = rawget(_ENV, "game")
    if type(g) ~= "table" then
        error("rng.seedFromGame: no game (check game.isInGame())", 2)
    end
    local okIn, inGame = pcall(g.isInGame)
    if not okIn or not inGame then
        error("rng.seedFromGame: no active game", 2)
    end
    local ok0, k0 = pcall(g.evalInt, "gMap.settings.gen.randkey0")
    local ok1, k1 = pcall(g.evalInt, "gMap.settings.gen.randkey1")
    if not ok0 or not ok1 then
        error("rng.seedFromGame: cannot read gen.randkey (need active match)", 2)
    end
    k0 = math.tointeger(k0)
    k1 = math.tointeger(k1)
    if not k0 or not k1 then
        error("rng.seedFromGame: bad gen.randkey (need active match)", 2)
    end
    local lo = k0 & 0xFFFFFFFF
    local hi = k1 & 0xFFFFFFFF
    local seed = (hi << 32) | lo
    if seed == 0 then seed = 0x9E3779B97F4A7C15 end
    return seed
end

-- Сид под имя: FNV-1a(name) xor сид матча. БЕЗ времени/адресов — одинаков на всех машинах.
-- name — непустая строка. Возвращает int64 (использовать как rng.new(rng.sharedSeed(name))).
function rng.sharedSeed(name)
    if type(name) ~= "string" or name == "" then
        error("rng.sharedSeed: name must be a non-empty string", 2)
    end
    local h = FNV_OFFSET
    for i = 1, #name do
        h = (h ~ string.byte(name, i)) * FNV_PRIME
    end
    return h ~ rng.seedFromGame()
end
