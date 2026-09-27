-- stringx — чистые строковые утилиты (без вызовов игры, везде: shared/lockstep-safe).
--
-- Только вычисления: никаких game/native/objects/events. Строки в Lua immutable,
-- входы не мутируются. Библиотеки math/table/string/os НЕ изменяются, только читаются.
-- math.random нет. Разделители/подстроки везде ОБЫЧНЫЕ строки (plain, НЕ pattern).
-- Регистровые функции (capitalize/lower/upper) — ТОЛЬКО ASCII a-z/A-Z:
-- кириллицу НЕ меняют ("ПРИВЕТ" lower → "ПРИВЕТ"). Длина/паддинги/обрезка — по СИМВОЛАМ
-- UTF-8 (кириллица = 1 символ), последовательности никогда не режутся (для корректного
-- UTF-8; битая последовательность считается по байтам). utf8-библиотека НЕ требуется
-- (разбор вручную по старшим битам) — работает и в игре, и в lua.exe.
--
--   local parts = stringx.split("a;b;", ";", true) --> { "a", "b", "" }
--   local s = stringx.truncateUtf8("привет, мир", 6, "...") --> "привет..."
--
-- Сторона: везде (pure Lua). Десинка нет (детерминированные вычисления).

stringx = {}

-- Проверить строку (ошибка "stringx.<fn>: <param> must be a string"). Возвращает s.
local function checkStr(s, fname, pname)
    if type(s) ~= "string" then
        error("stringx." .. fname .. ": " .. pname .. " must be a string", 3)
    end
    return s
end

-- Длина корректного UTF-8 в символах (кириллица = 1 символ; ASCII-байты и старшие
-- байты последовательностей считаются, байты продолжения 0x80..0xBF — нет).
local function utf8Len(s)
    local n = 0
    for i = 1, #s do
        local b = s:byte(i)
        if b < 0x80 or b >= 0xC0 then n = n + 1 end
    end
    return n
end

-- Байт-индексы начал символов корректного UTF-8 (для обрезки/паддингов).
local function utf8Starts(s)
    local starts = {}
    local i = 1
    while i <= #s do
        starts[#starts + 1] = i
        local b = s:byte(i)
        if b < 0x80 then
            i = i + 1
        elseif b < 0xE0 then
            i = i + 2
        elseif b < 0xF0 then
            i = i + 3
        else
            i = i + 4
        end
    end
    return starts
end

-- stringx.trim(s): убрать пробелы/табы/переносы с обоих концов. Возврат: строка.
-- Сторона: везде (pure). Ошибки: stringx.trim: s must be a string.
function stringx.trim(s)
    checkStr(s, "trim", "s")
    return (s:gsub("^%s*(.-)%s*$", "%1"))
end

-- stringx.split(s, sep, keepEmpty): разбить по ОБЫЧНОЙ строке sep (не pattern).
-- keepEmpty nil/false — пустые куски выкидываются; true — сохраняются
-- (ведущие/внутренние/хвостовые, s = "" + keepEmpty → { "" }). sep = "" — ошибка.
-- Возврат: новый массив. Сторона: везде (pure).
-- Ошибки: stringx.split: s must be a string; sep must be a non-empty string;
-- keepEmpty must be a boolean or nil.
function stringx.split(s, sep, keepEmpty)
    checkStr(s, "split", "s")
    if type(sep) ~= "string" or sep == "" then
        error("stringx.split: sep must be a non-empty string", 2)
    end
    if keepEmpty == nil then
        keepEmpty = false
    elseif type(keepEmpty) ~= "boolean" then
        error("stringx.split: keepEmpty must be a boolean or nil", 2)
    end
    local out = {}
    local start = 1
    while true do
        local i, j = s:find(sep, start, true)
        if not i then
            local part = s:sub(start)
            if part ~= "" or keepEmpty then out[#out + 1] = part end
            break
        end
        local part = s:sub(start, i - 1)
        if part ~= "" or keepEmpty then out[#out + 1] = part end
        start = j + 1
    end
    return out
end

-- stringx.join(parts, sep): склеить массив (элементы — строки или числа) через sep.
-- sep nil → "". Возврат: строка. Сторона: везде (pure).
-- Ошибки: stringx.join: parts must be a table; sep must be a string;
-- parts[i] must be a string or number.
function stringx.join(parts, sep)
    if type(parts) ~= "table" then
        error("stringx.join: parts must be a table", 2)
    end
    if sep == nil then sep = "" end
    if type(sep) ~= "string" then
        error("stringx.join: sep must be a string", 2)
    end
    local n = #parts
    local tmp = {}
    for i = 1, n do
        local v = parts[i]
        if type(v) ~= "string" and type(v) ~= "number" then
            error("stringx.join: parts[" .. i .. "] must be a string or number", 2)
        end
        tmp[i] = tostring(v)
    end
    return table.concat(tmp, sep)
end

-- stringx.startsWith(s, prefix): начинается ли s с ОБЫЧНОГО prefix (пустой → true).
-- Возврат: boolean. Сторона: везде (pure).
-- Ошибки: stringx.startsWith: s/prefix must be a string.
function stringx.startsWith(s, prefix)
    checkStr(s, "startsWith", "s")
    checkStr(prefix, "startsWith", "prefix")
    return s:sub(1, #prefix) == prefix
end

-- stringx.endsWith(s, suffix): заканчивается ли s ОБЫЧНЫМ suffix (пустой → true).
-- Возврат: boolean. Сторона: везде (pure).
-- Ошибки: stringx.endsWith: s/suffix must be a string.
function stringx.endsWith(s, suffix)
    checkStr(s, "endsWith", "s")
    checkStr(suffix, "endsWith", "suffix")
    if suffix == "" then return true end
    return s:sub(-#suffix) == suffix
end

-- stringx.contains(s, sub): есть ли ОБЫЧНАЯ подстрока sub в s (не pattern; "" → true).
-- Возврат: boolean. Сторона: везде (pure).
-- Ошибки: stringx.contains: s/sub must be a string.
function stringx.contains(s, sub)
    checkStr(s, "contains", "s")
    checkStr(sub, "contains", "sub")
    return s:find(sub, 1, true) ~= nil
end

-- stringx.replaceAll(s, old, newStr): заменить ВСЕ вхождения ОБЫЧНОЙ строки old
-- (не pattern). old = "" — ошибка. Возврат: новая строка. Сторона: везде (pure).
-- Ошибки: stringx.replaceAll: s must be a string; old must be a non-empty string;
-- newStr must be a string.
function stringx.replaceAll(s, old, newStr)
    checkStr(s, "replaceAll", "s")
    if type(old) ~= "string" or old == "" then
        error("stringx.replaceAll: old must be a non-empty string", 2)
    end
    if type(newStr) ~= "string" then
        error("stringx.replaceAll: newStr must be a string", 2)
    end
    local out = {}
    local start = 1
    while true do
        local i, j = s:find(old, start, true)
        if not i then
            out[#out + 1] = s:sub(start)
            break
        end
        out[#out + 1] = s:sub(start, i - 1)
        out[#out + 1] = newStr
        start = j + 1
    end
    return table.concat(out)
end

-- stringx.capitalize(s): первая буква в верхний регистр, ТОЛЬКО ASCII a-z.
-- Кириллицу НЕ меняет ("привет" → "привет"). Возврат: новая строка.
-- Сторона: везде (pure). Ошибки: stringx.capitalize: s must be a string.
function stringx.capitalize(s)
    checkStr(s, "capitalize", "s")
    return (s:gsub("^%l", string.upper))
end

-- stringx.lower(s): нижний регистр, ТОЛЬКО ASCII A-Z (string.lower).
-- Кириллицу НЕ меняет ("ПРИВЕТ" → "ПРИВЕТ"). Возврат: новая строка.
-- Сторона: везде (pure). Ошибки: stringx.lower: s must be a string.
function stringx.lower(s)
    checkStr(s, "lower", "s")
    return string.lower(s)
end

-- stringx.upper(s): верхний регистр, ТОЛЬКО ASCII a-z (string.upper).
-- Кириллицу НЕ меняет ("привет" → "привет"). Возврат: новая строка.
-- Сторона: везде (pure). Ошибки: stringx.upper: s must be a string.
function stringx.upper(s)
    checkStr(s, "upper", "s")
    return string.upper(s)
end

-- stringx.utf8Length(s): длина в СИМВОЛАХ UTF-8 (кириллица = 1 символ).
-- Для корректного UTF-8; битые последовательности считаются по байтам.
-- Возврат: integer. Сторона: везде (pure). Ошибки: stringx.utf8Length: s must be a string.
function stringx.utf8Length(s)
    checkStr(s, "utf8Length", "s")
    return utf8Len(s)
end

-- stringx.truncateUtf8(s, maxChars, suffix): обрезать до maxChars СИМВОЛОВ UTF-8,
-- последовательность никогда не режется (обрезка по границам символов).
-- Если длина <= maxChars — вернуть s БЕЗ суффикса. suffix nil → "".
-- maxChars — целое >= 0 (0 → только suffix). Возврат: строка. Сторона: везде (pure).
-- Ошибки: stringx.truncateUtf8: s must be a string;
-- maxChars must be a non-negative integer; suffix must be a string.
function stringx.truncateUtf8(s, maxChars, suffix)
    checkStr(s, "truncateUtf8", "s")
    local m = math.tointeger(maxChars)
    if not m or m < 0 then
        error("stringx.truncateUtf8: maxChars must be a non-negative integer", 2)
    end
    if suffix == nil then suffix = "" end
    if type(suffix) ~= "string" then
        error("stringx.truncateUtf8: suffix must be a string", 2)
    end
    local starts = utf8Starts(s)
    if #starts <= m then return s end
    if m == 0 then return suffix end
    return s:sub(1, starts[m + 1] - 1) .. suffix
end

-- stringx.padLeft(s, width, pad): дополнить СЛЕВА до width СИМВОЛОВ строкой pad.
-- pad nil → " "; pad обязан быть ровно 1 символом (иначе ошибка).
-- Если длина уже >= width — вернуть s. Возврат: строка. Сторона: везде (pure).
-- Ошибки: stringx.padLeft: s must be a string; width must be a non-negative integer;
-- pad must be a single character.
function stringx.padLeft(s, width, pad)
    checkStr(s, "padLeft", "s")
    local w = math.tointeger(width)
    if not w or w < 0 then
        error("stringx.padLeft: width must be a non-negative integer", 2)
    end
    if pad == nil then pad = " " end
    if type(pad) ~= "string" or utf8Len(pad) ~= 1 then
        error("stringx.padLeft: pad must be a single character", 2)
    end
    local need = w - utf8Len(s)
    if need <= 0 then return s end
    return pad:rep(need) .. s
end

-- stringx.padRight(s, width, pad): дополнить СПРАВА до width СИМВОЛОВ строкой pad.
-- pad nil → " "; pad обязан быть ровно 1 символом (иначе ошибка).
-- Если длина уже >= width — вернуть s. Возврат: строка. Сторона: везде (pure).
-- Ошибки: stringx.padRight: s must be a string; width must be a non-negative integer;
-- pad must be a single character.
function stringx.padRight(s, width, pad)
    checkStr(s, "padRight", "s")
    local w = math.tointeger(width)
    if not w or w < 0 then
        error("stringx.padRight: width must be a non-negative integer", 2)
    end
    if pad == nil then pad = " " end
    if type(pad) ~= "string" or utf8Len(pad) ~= 1 then
        error("stringx.padRight: pad must be a single character", 2)
    end
    local need = w - utf8Len(s)
    if need <= 0 then return s end
    return s .. pad:rep(need)
end

-- stringx.formatBytes(bytes): "1023 B" / "1.5 KB" / "2.0 MB" / "3.0 GB" (шаг 1024,
-- B — целым, KB/MB/GB — с 1 знаком). bytes >= 0, иначе ошибка. Возврат: строка.
-- Сторона: везде (pure). Ошибки: stringx.formatBytes: bytes must be a number;
-- bytes must be non-negative.
function stringx.formatBytes(bytes)
    local n = tonumber(bytes)
    if n == nil or n ~= n then
        error("stringx.formatBytes: bytes must be a number", 2)
    end
    if n < 0 then
        error("stringx.formatBytes: bytes must be non-negative", 2)
    end
    if n < 1024 then
        return string.format("%d B", math.floor(n))
    end
    if n < 1048576 then
        return string.format("%.1f KB", n / 1024)
    end
    if n < 1073741824 then
        return string.format("%.1f MB", n / 1048576)
    end
    return string.format("%.1f GB", n / 1073741824)
end

-- stringx.escapePattern(s): экранировать магию Lua-паттернов (^$()%.[]*+-?),
-- чтобы строку можно было вставлять в pattern. Возврат: новая строка.
-- Сторона: везде (pure). Ошибки: stringx.escapePattern: s must be a string.
function stringx.escapePattern(s)
    checkStr(s, "escapePattern", "s")
    return (s:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1"))
end
