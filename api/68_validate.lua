-- validate — единые проверки аргументов для модов.
--
-- Чистые проверки (number/integer/boolean/string/handle/position/enum/list/table)
-- работают везде (pure Lua, игры не касаются). Контекстные (activeGame/server/client)
-- читают game.isInGame/game.exec/game.side и кидают понятную ошибку вне контекста.
--
--   validate.number(x, "x", { min = 0, max = 10 })
--   validate.handle(h, "target")
--   validate.position({ x = 10, z = 20 }, "pos")
--   validate.activeGame("myFn")   -- ошибка, если нет активной партии
--
-- Все ошибки называют функцию и параметр: "validate.number: param 'x' must be ...".
-- Мусорная позиция НЕ превращается в {0,0} — кидается ошибка.
-- pattern в validate.string — обычный Lua-паттерн (string.find), не plain-подстрока.
-- Сторона: pure + контекст (везде, где есть game). Своих game.exec-вызовов нет.

validate = {}

-- Имя параметра для текста ошибки (nil/не строка → "value").
local function pname(name)
    if type(name) == "string" and name ~= "" then return name end
    return "value"
end

-- validate.number(v, name, opts): число (NaN запрещён всегда; inf — только при finite=false).
-- Парам: v — число; name — имя для ошибки; opts — { min, max, finite = true }.
-- Возврат: v. Сторона: везде (pure). Ошибки: validate.number: param 'name' must be ...
function validate.number(v, name, opts)
    local n = pname(name)
    opts = opts or {}
    if type(v) ~= "number" then
        error("validate.number: param '" .. n .. "' must be a number", 2)
    end
    if v ~= v then
        error("validate.number: param '" .. n .. "' must not be NaN", 2)
    end
    if opts.finite ~= false and (v == math.huge or v == -math.huge) then
        error("validate.number: param '" .. n .. "' must be finite", 2)
    end
    if opts.min ~= nil and v < opts.min then
        error("validate.number: param '" .. n .. "' must be >= " .. tostring(opts.min), 2)
    end
    if opts.max ~= nil and v > opts.max then
        error("validate.number: param '" .. n .. "' must be <= " .. tostring(opts.max), 2)
    end
    return v
end

-- validate.integer(v, name, opts): целое (через math.tointeger; 1.5/NaN/inf/строки — ошибка).
-- Парам: v — целое число; name — имя; opts — { min, max } (включительно).
-- Возврат: целое. Сторона: везде (pure). Ошибки: validate.integer: param 'name' must be ...
function validate.integer(v, name, opts)
    local n = pname(name)
    opts = opts or {}
    if type(v) ~= "number" then
        error("validate.integer: param '" .. n .. "' must be an integer", 2)
    end
    local iv = math.tointeger(v)
    if iv == nil then
        error("validate.integer: param '" .. n .. "' must be an integer", 2)
    end
    if opts.min ~= nil and iv < opts.min then
        error("validate.integer: param '" .. n .. "' must be >= " .. tostring(opts.min), 2)
    end
    if opts.max ~= nil and iv > opts.max then
        error("validate.integer: param '" .. n .. "' must be <= " .. tostring(opts.max), 2)
    end
    return iv
end

-- validate.boolean(v, name): строго boolean (0/"true"/nil — ошибка, не truthy-проверка).
-- Парам: v — значение; name — имя. Возврат: v. Сторона: везде (pure).
-- Ошибки: validate.boolean: param 'name' must be a boolean.
function validate.boolean(v, name)
    local n = pname(name)
    if type(v) ~= "boolean" then
        error("validate.boolean: param '" .. n .. "' must be a boolean", 2)
    end
    return v
end

-- validate.string(v, name, opts): строка; pattern — Lua-паттерн для string.find (не plain).
-- Парам: v — строка; name — имя; opts — { minLen, maxLen, nonEmpty, pattern }.
-- Длины — в байтах (#v); для символов UTF-8 нужен stringx.utf8Length.
-- Возврат: v. Сторона: везде (pure). Ошибки: validate.string: param 'name' must be ...
function validate.string(v, name, opts)
    local n = pname(name)
    opts = opts or {}
    if type(v) ~= "string" then
        error("validate.string: param '" .. n .. "' must be a string", 2)
    end
    if opts.nonEmpty and #v == 0 then
        error("validate.string: param '" .. n .. "' must be non-empty", 2)
    end
    if opts.minLen ~= nil and #v < opts.minLen then
        error("validate.string: param '" .. n .. "' must be at least " .. tostring(opts.minLen) .. " chars", 2)
    end
    if opts.maxLen ~= nil and #v > opts.maxLen then
        error("validate.string: param '" .. n .. "' must be at most " .. tostring(opts.maxLen) .. " chars", 2)
    end
    if opts.pattern ~= nil then
        if type(opts.pattern) ~= "string" then
            error("validate.string: param 'pattern' must be a string", 2)
        end
        if string.find(v, opts.pattern) == nil then
            error("validate.string: param '" .. n .. "' must match pattern '" .. opts.pattern .. "'", 2)
        end
    end
    return v
end

-- validate.handle(v, name): хендл объекта (целое ~= 0; ОТРИЦАТЕЛЬНЫЕ разрешены — хендлы такие!).
-- Парам: v — хендл; name — имя. Возврат: целое-хендл. Сторона: везде (pure).
-- Ошибки: validate.handle: param 'name' must be a non-zero handle.
function validate.handle(v, name)
    local n = pname(name)
    if type(v) ~= "number" then
        error("validate.handle: param '" .. n .. "' must be a non-zero handle", 2)
    end
    local iv = math.tointeger(v)
    if iv == nil or iv == 0 then
        error("validate.handle: param '" .. n .. "' must be a non-zero handle", 2)
    end
    return iv
end

-- validate.position(v, name): позиция { x, z } с конечными числами (NaN/inf/отсутствие — ошибка).
-- Мусор НЕ превращается в {0,0}: nil/число/таблица без x,z кидают ошибку.
-- Парам: v — { x, z }; name — имя. Возврат: v. Сторона: везде (pure).
-- Ошибки: validate.position: param 'name' must be ...
function validate.position(v, name)
    local n = pname(name)
    if type(v) ~= "table" then
        error("validate.position: param '" .. n .. "' must be a { x, z } table", 2)
    end
    for _, k in ipairs({ "x", "z" }) do
        local c = v[k]
        if type(c) ~= "number" or c ~= c then
            error("validate.position: param '" .. n .. "." .. k .. "' must be a number", 2)
        end
        if c == math.huge or c == -math.huge then
            error("validate.position: param '" .. n .. "." .. k .. "' must be finite", 2)
        end
    end
    return v
end

-- validate.enum(v, allowed, name): значение из списка (сравнение ==).
-- Парам: v — значение; allowed — массив допустимых; name — имя. Возврат: v.
-- Сторона: везде (pure). Ошибки: validate.enum: param 'name' must be one of ... / allowed must be ...
function validate.enum(v, allowed, name)
    local n = pname(name)
    if type(allowed) ~= "table" or #allowed == 0 then
        error("validate.enum: allowed must be a non-empty list", 2)
    end
    for i = 1, #allowed do
        if v == allowed[i] then return v end
    end
    error("validate.enum: param '" .. n .. "' must be one of the allowed values", 2)
end

-- validate.list(v, name, opts): массив-последовательность без дыр (пустой — можно, если нет minLen).
-- Парам: v — таблица; name — имя; opts — { minLen, of = itemFn } (itemFn(item, itemName), ошибка пробрасывается).
-- Входная таблица не мутируется. Возврат: v. Сторона: везде (pure).
-- Ошибки: validate.list: param 'name' must be ...
function validate.list(v, name, opts)
    local n = pname(name)
    opts = opts or {}
    if type(v) ~= "table" then
        error("validate.list: param '" .. n .. "' must be a list (array table)", 2)
    end
    local len = #v
    local count, max = 0, 0
    for k in pairs(v) do
        if type(k) ~= "number" or math.tointeger(k) ~= k or k < 1 then
            error("validate.list: param '" .. n .. "' must be a list (array table)", 2)
        end
        count = count + 1
        if k > max then max = k end
    end
    if count ~= len or (len > 0 and max ~= len) then
        error("validate.list: param '" .. n .. "' must be a list (array table, no holes)", 2)
    end
    if opts.minLen ~= nil and len < opts.minLen then
        error("validate.list: param '" .. n .. "' must have at least " .. tostring(opts.minLen) .. " item(s)", 2)
    end
    if opts.of ~= nil then
        if type(opts.of) ~= "function" then
            error("validate.list: param 'of' must be a function", 2)
        end
        for i = 1, len do
            opts.of(v[i], n .. "[" .. i .. "]")
        end
    end
    return v
end

-- validate.table(v, name): любая таблица (массив или словарь).
-- Парам: v — таблица; name — имя. Возврат: v. Сторона: везде (pure).
-- Ошибки: validate.table: param 'name' must be a table.
function validate.table(v, name)
    local n = pname(name)
    if type(v) ~= "table" then
        error("validate.table: param '" .. n .. "' must be a table", 2)
    end
    return v
end

-- validate.activeGame(where): требует активной партии (game.isInGame()).
-- Парам: where — опциональный контекст для текста ошибки. Ничего не возвращает.
-- Сторона: везде (чтение game). Ошибки: validate.activeGame: no active game ...
function validate.activeGame(where)
    local g = rawget(_ENV, "game")
    local ok = g ~= nil and type(g.isInGame) == "function" and g.isInGame()
    if not ok then
        local ctx = type(where) == "string" and (" (" .. where .. ")") or ""
        error("validate.activeGame: no active game (check game.isInGame())" .. ctx, 2)
    end
end

-- validate.server(where): требует server/shared (наличие game.exec для записи в мир).
-- Парам: where — опциональный контекст. Ничего не возвращает.
-- Сторона: server/shared. Ошибки: validate.server: only server/shared scripts ... (no game.exec).
function validate.server(where)
    local g = rawget(_ENV, "game")
    if g == nil or g.exec == nil then
        local ctx = type(where) == "string" and (" (" .. where .. ")") or ""
        error("validate.server: only server/shared scripts can do this (no game.exec on client)" .. ctx, 2)
    end
end

-- validate.client(where): требует client (game.side == "client").
-- Парам: where — опциональный контекст. Ничего не возвращает.
-- Сторона: client. Ошибки: validate.client: only client scripts ... (game.side ~= 'client').
function validate.client(where)
    local g = rawget(_ENV, "game")
    if g == nil or g.side ~= "client" then
        local ctx = type(where) == "string" and (" (" .. where .. ")") or ""
        error("validate.client: only client scripts can do this (game.side ~= 'client')" .. ctx, 2)
    end
end
