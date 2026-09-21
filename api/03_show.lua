-- show — таблица в читаемый текст (консоль печатает таблицы как "table: 22FC0CF8").
--
--   =show(buildings.info(buildings.selected()))
--   =show(balance.get("musketeer18"), 2)      -- только 2 уровня вложенности
--   log.info(show(t))

local function key(k)
    if type(k) == "string" and k:match("^[%a_][%w_]*$") then return k end
    return "[" .. (type(k) == "string" and string.format("%q", k) or tostring(k)) .. "]"
end

local function value(v)
    if type(v) == "string" then return string.format("%q", v) end
    return tostring(v)
end

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

function show(v, maxDepth)
    if type(v) ~= "table" then return value(v) end
    local out = {}
    render(v, 0, 0, maxDepth or 8, {}, out)
    return table.concat(out)
end
