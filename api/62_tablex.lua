-- tablex — чистые табличные утилиты (без вызовов игры, везде: shared/lockstep-safe).
--
-- Только вычисления: никаких game/native/objects/events. Входы НЕ мутируются,
-- все функции возвращают новые таблицы — КРОМЕ tablex.clear (мутирует и возвращает t).
-- Библиотеки math/table/string/os НЕ изменяются, только читаются.
-- math.random используется ТОЛЬКО как default в tablex.shuffle:
-- ВНИМАНИЕ (десинхрон): math.random рассинхронизирует lockstep/shared — в сетевой
-- симуляции передавайте детерминированный random fn → [0, 1) или используйте rng.new().
-- Массивы обходятся по 1..#t (ipairs-семантика): дыры nil дают неопределённую длину #t,
-- map передаёт дыру в fn как nil, filter/reverse/shuffle дыры не сохраняют осмысленно —
-- не используйте дырявые массивы. keys/values идут через pairs (порядок НЕ определён).
--
--   local adults = tablex.filter(units, function(u) return u.hp > 0 end)
--   local total = tablex.reduce(prices, function(a, p) return a + p end, 0)
--   local cfg = tablex.mergeDeep(defaults, userCfg)
--
-- Сторона: везде (pure Lua). Десинка нет, кроме shuffle-default (см. выше).

tablex = {}

-- Проверить таблицу (ошибка "tablex.<fn>: <param> must be a table"). Возвращает t.
local function checkTable(t, fname, pname)
    if type(t) ~= "table" then
        error("tablex." .. fname .. ": " .. pname .. " must be a table", 3)
    end
    return t
end

-- Проверить функцию (ошибка "tablex.<fn>: <param> must be a function"). Возвращает fn.
local function checkFn(fn, fname, pname)
    if type(fn) ~= "function" then
        error("tablex." .. fname .. ": " .. pname .. " must be a function", 3)
    end
    return fn
end

-- tablex.contains(t, value): есть ли value в массиве (сравнение ==, обход 1..#t).
-- Возврат: boolean. Сторона: везде (pure). Ошибки: tablex.contains: t must be a table.
function tablex.contains(t, value)
    checkTable(t, "contains", "t")
    for i = 1, #t do
        if t[i] == value then return true end
    end
    return false
end

-- tablex.indexOf(t, value): первый индекс value в массиве (==, обход 1..#t) или nil.
-- Возврат: integer/nil. Сторона: везде (pure). Ошибки: tablex.indexOf: t must be a table.
function tablex.indexOf(t, value)
    checkTable(t, "indexOf", "t")
    for i = 1, #t do
        if t[i] == value then return i end
    end
    return nil
end

-- tablex.find(t, predicate): первый элемент, где predicate(value, index) true (обход 1..#t).
-- Возврат: value, index (или nil). Вход не мутируется. Сторона: везде (pure).
-- Ошибки: tablex.find: t must be a table; predicate must be a function.
function tablex.find(t, predicate)
    checkTable(t, "find", "t")
    checkFn(predicate, "find", "predicate")
    for i = 1, #t do
        if predicate(t[i], i) then return t[i], i end
    end
    return nil
end

-- tablex.map(t, fn): новый массив fn(value, index) для i = 1..#t (дыры — fn(nil, i)).
-- Вход не мутируется. Возврат: новая таблица. Сторона: везде (pure).
-- Ошибки: tablex.map: t must be a table; fn must be a function.
function tablex.map(t, fn)
    checkTable(t, "map", "t")
    checkFn(fn, "map", "fn")
    local out = {}
    for i = 1, #t do
        out[i] = fn(t[i], i)
    end
    return out
end

-- tablex.filter(t, predicate): новый плотный массив элементов, где predicate true.
-- Дыры осмысленно не фильтруются (не используйте дырявые массивы). Вход не мутируется.
-- Возврат: новая таблица. Сторона: везде (pure).
-- Ошибки: tablex.filter: t must be a table; predicate must be a function.
function tablex.filter(t, predicate)
    checkTable(t, "filter", "t")
    checkFn(predicate, "filter", "predicate")
    local out = {}
    for i = 1, #t do
        if predicate(t[i], i) then
            out[#out + 1] = t[i]
        end
    end
    return out
end

-- tablex.reduce(t, fn, initial): свёртка acc = fn(acc, value, index) по 1..#t.
-- initial ОБЯЗАТЕЛЕН (nil запрещён — ошибка). Возврат: аккумулятор.
-- Сторона: везде (pure).
-- Ошибки: tablex.reduce: t must be a table; fn must be a function; initial is required.
function tablex.reduce(t, fn, initial)
    checkTable(t, "reduce", "t")
    checkFn(fn, "reduce", "fn")
    if initial == nil then
        error("tablex.reduce: initial is required", 2)
    end
    local acc = initial
    for i = 1, #t do
        acc = fn(acc, t[i], i)
    end
    return acc
end

-- tablex.keys(t): все ключи через pairs (порядок НЕ определён). Возврат: новый массив.
-- Сторона: везде (pure). Ошибки: tablex.keys: t must be a table.
function tablex.keys(t)
    checkTable(t, "keys", "t")
    local out = {}
    for k in pairs(t) do
        out[#out + 1] = k
    end
    return out
end

-- tablex.values(t): все значения через pairs (порядок НЕ определён). Возврат: новый массив.
-- Сторона: везде (pure). Ошибки: tablex.values: t must be a table.
function tablex.values(t)
    checkTable(t, "values", "t")
    local out = {}
    for _, v in pairs(t) do
        out[#out + 1] = v
    end
    return out
end

-- tablex.count(t, predicate): число ключей (pairs); с predicate — число совпадений
-- predicate(value, key). Возврат: integer. Сторона: везде (pure).
-- Ошибки: tablex.count: t must be a table; predicate must be a function.
function tablex.count(t, predicate)
    checkTable(t, "count", "t")
    if predicate == nil then
        local n = 0
        for _ in pairs(t) do n = n + 1 end
        return n
    end
    checkFn(predicate, "count", "predicate")
    local n = 0
    for k, v in pairs(t) do
        if predicate(v, k) then n = n + 1 end
    end
    return n
end

-- tablex.isEmpty(t): нет ли ключей (next(t) == nil; работает и для словарей).
-- Возврат: boolean. Сторона: везде (pure). Ошибки: tablex.isEmpty: t must be a table.
function tablex.isEmpty(t)
    checkTable(t, "isEmpty", "t")
    return next(t) == nil
end

-- tablex.first(t): t[1] (nil на пустом). Возврат: value/nil. Сторона: везде (pure).
-- Ошибки: tablex.first: t must be a table.
function tablex.first(t)
    checkTable(t, "first", "t")
    return t[1]
end

-- tablex.last(t): t[#t] (nil на пустом). Возврат: value/nil. Сторона: везде (pure).
-- Ошибки: tablex.last: t must be a table.
function tablex.last(t)
    checkTable(t, "last", "t")
    if #t == 0 then return nil end
    return t[#t]
end

-- tablex.copy(t): поверхностная копия через pairs (вложенные таблицы — общие ссылки).
-- Возврат: новая таблица. Сторона: везде (pure). Ошибки: tablex.copy: t must be a table.
function tablex.copy(t)
    checkTable(t, "copy", "t")
    local out = {}
    for k, v in pairs(t) do
        out[k] = v
    end
    return out
end

-- tablex.deepcopy(value, maxDepth): глубокая копия (ключи и значения рекурсивно).
-- maxDepth default 10 (целое >= 0). Циклы — ошибка "tablex.deepcopy: cycle detected".
-- Превышение глубины — ошибка "tablex.deepcopy: max depth exceeded".
-- Не-таблицы возвращаются как есть. Метатаблицы НЕ копируются. Вход не мутируется.
-- Возврат: копия. Сторона: везде (pure).
-- Ошибки: tablex.deepcopy: maxDepth must be a non-negative integer; cycle detected; ...
function tablex.deepcopy(value, maxDepth)
    if maxDepth == nil then maxDepth = 10 end
    local md = math.tointeger(maxDepth)
    if not md or md < 0 then
        error("tablex.deepcopy: maxDepth must be a non-negative integer", 2)
    end
    local seen = {}
    local function rec(v, depth)
        if type(v) ~= "table" then return v end
        if seen[v] then
            error("tablex.deepcopy: cycle detected", 2)
        end
        if depth > md then
            error("tablex.deepcopy: max depth exceeded", 2)
        end
        seen[v] = true
        local out = {}
        for k, val in pairs(v) do
            out[rec(k, depth + 1)] = rec(val, depth + 1)
        end
        seen[v] = nil
        return out
    end
    return rec(value, 0)
end

-- tablex.merge(a, b): поверхностное слияние в НОВУЮ таблицу (ключи b побеждают).
-- Входы не мутируются. Возврат: новая таблица. Сторона: везде (pure).
-- Ошибки: tablex.merge: a/b must be a table.
function tablex.merge(a, b)
    checkTable(a, "merge", "a")
    checkTable(b, "merge", "b")
    local out = {}
    for k, v in pairs(a) do out[k] = v end
    for k, v in pairs(b) do out[k] = v end
    return out
end

-- tablex.mergeDeep(a, b): глубокое слияние в НОВУЮ таблицу (ключи b побеждают;
-- если оба значения — таблицы, сливаются рекурсивно, иначе берётся копия значения b).
-- Входы не мутируются и не делят вложенные таблицы с результатом.
-- Возврат: новая таблица. Сторона: везде (pure).
-- Ошибки: tablex.mergeDeep: a/b must be a table (+ ошибки deepcopy).
function tablex.mergeDeep(a, b)
    checkTable(a, "mergeDeep", "a")
    checkTable(b, "mergeDeep", "b")
    local out = {}
    for k, v in pairs(a) do
        local bv = b[k]
        if bv ~= nil and type(v) == "table" and type(bv) == "table" then
            out[k] = tablex.mergeDeep(v, bv)
        elseif bv ~= nil then
            out[k] = tablex.deepcopy(bv)
        else
            out[k] = tablex.deepcopy(v)
        end
    end
    for k, v in pairs(b) do
        if a[k] == nil then
            out[k] = tablex.deepcopy(v)
        end
    end
    return out
end

-- tablex.reverse(t): перевёрнутая КОПИЯ массива (вход не мутируется).
-- Возврат: новая таблица. Сторона: везде (pure). Ошибки: tablex.reverse: t must be a table.
function tablex.reverse(t)
    checkTable(t, "reverse", "t")
    local n = #t
    local out = {}
    for i = 1, n do
        out[i] = t[n - i + 1]
    end
    return out
end

-- tablex.shuffle(list, random): перемешанная КОПИЯ (Фишер–Йетс, вход не мутируется).
-- random — fn → [0, 1); default math.random.
-- ВНИМАНИЕ (десинхрон): default math.random НЕдетерминирован между машинами —
-- в shared/lockstep всегда передавайте детерминированный random (или используйте rng.new()).
-- Чужой выход вне [0,1) — ошибка. Возврат: новая таблица. Сторона: везде (pure),
-- но с default-random — НЕ shared-safe.
-- Ошибки: tablex.shuffle: list must be a table; random must be a function ...;
-- random must return [0,1).
function tablex.shuffle(list, random)
    checkTable(list, "shuffle", "list")
    local rfn = random
    if rfn == nil then
        rfn = math.random
    elseif type(rfn) ~= "function" then
        error("tablex.shuffle: random must be a function returning [0,1)", 2)
    end
    local n = #list
    local out = {}
    for i = 1, n do out[i] = list[i] end
    for i = n, 2, -1 do
        local r = rfn()
        if type(r) ~= "number" or r ~= r or r < 0 or r >= 1 then
            error("tablex.shuffle: random must return [0,1)", 2)
        end
        local j = math.floor(r * i) + 1
        out[i], out[j] = out[j], out[i]
    end
    return out
end

-- tablex.clear(t): удалить ВСЕ ключи (ЕДИНСТВЕННАЯ мутирующая функция модуля).
-- Возврат: та же таблица t. Сторона: везде (pure). Ошибки: tablex.clear: t must be a table.
function tablex.clear(t)
    checkTable(t, "clear", "t")
    for k in pairs(t) do
        t[k] = nil
    end
    return t
end
