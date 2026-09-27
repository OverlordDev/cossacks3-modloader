-- show — таблица в читаемый текст (консоль печатает таблицы как "table: 22FC0CF8").
-- Модуль без состояния: одна функция show + локальные помощники форматирования.
--
--   =show(buildings.info(buildings.selected()))
--   =show(balance.get("musketeer18"), 2)      -- только 2 уровня вложенности
--   log.info(show(t))
--   show("abc")  --> '"abc"'; show(5) --> '5'; show({}) --> '{}'
--
-- Сторона: shared (везде: client/server/shared/страница) — чистый Lua, игры не касается.
-- Ошибок не кидает; циклы печатает как <цикл>, глубокую вложенность режет как {...}.

-- key(k): ключ таблицы в текст; идентификаторы — как есть, остальное — в скобках.
-- Парам: k — ключ. Возврат: строка. Сторона: shared. Ошибок не кидает.
local function key(k)
    if type(k) == "string" and k:match("^[%a_][%w_]*$") then return k end
    return "[" .. (type(k) == "string" and string.format("%q", k) or tostring(k)) .. "]"
end

-- value(v): скаляр в текст; строки — в кавычках (%q). Возврат: строка. Ошибок не кидает.
local function value(v)
    if type(v) == "string" then return string.format("%q", v) end
    return tostring(v)
end

-- render(t, indent, depth, maxDepth, seen, out): рекурсивная печать таблицы в буфер out.
-- Парам: t — таблица; indent/depth — текущий отступ/глубина; maxDepth — предел; seen — защита от циклов.
-- Сторона: shared. Ошибок не кидает (пустая таблица — "{}", цикл — "<цикл>", глубже предела — "{...}").
local function render(t, indent, depth, maxDepth, seen, out)
    if seen[t] then out[#out + 1] = "<цикл>"; return end
    if depth >= maxDepth then out[#out + 1] = "{...}"; return end
    seen[t] = true

    local keys = {}
    for k in pairs(t) do keys[#keys + 1] = k end
    if #keys == 0 then out[#out + 1] = "{}"; seen[t] = nil; return end
    table.sort(keys, function(a, b)
        if type(a) == type(b) and (type(a) == "number" or type(a) == "string") then return a < b end
        return type(a) == "number"
    end)

    out[#out + 1] = "{\n"
    local pad = string.rep("  ", indent + 1)
    for _, k in ipairs(keys) do
        local v = t[k]
        out[#out + 1] = pad .. key(k) .. " = "
        if type(v) == "table" then render(v, indent + 1, depth + 1, maxDepth, seen, out)
        else out[#out + 1] = value(v) end
        out[#out + 1] = ",\n"
    end
    out[#out + 1] = string.rep("  ", indent) .. "}"
    seen[t] = nil
end

-- show(v, maxDepth): любое значение в читаемый текст.
-- Парам: v — что печатать; maxDepth — предел вложенности (по умолч. 8).
-- Возврат: строка. Сторона: shared (везде). Ошибок не кидает.
function show(v, maxDepth)
    if type(v) ~= "table" then return value(v) end
    local out = {}
    render(v, 0, 0, maxDepth or 8, {}, out)
    return table.concat(out)
end
