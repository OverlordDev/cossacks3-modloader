-- state — чтение и запись любой переменной скриптов игры по пути.
--
--   state.get("gProfile.sndmaster")          --> 0.75
--   state.get("gMap.players[2].name")        --> "Cossack"
--   state.read("gMap.players[2]")            --> { id = 2, name = "Cossack", team = 1, ... }
--   state.list("gMap.players")               --> все 12 записей массива
--   state.set("gProfile.sndmaster", 0.5)     --  только сервер и консоль (и страницы через game.api)
--   state.type("gMap.settings.gen")          --> "TMapSettingsGen"
--
-- То же через точку — G отражает глобальные переменные игры:
--   G.gProfile.sndmaster                     --> 0.75
--   G.gMap.players[2].team                   --> 1
--   G.gProfile.sndmaster = 0.5               --  запись
--   G.gMap.players[2]()                      --> вся запись таблицей
--
-- Какие переменные и поля есть — GAME_STATE.md, он сгенерирован вместе со схемой.
--
-- Типы берутся из схемы (00_schema.lua), поэтому нужная функция чтения выбирается сама:
-- не надо помнить, где evalInt, где evalFloat, а где строка.

local SCHEMA = GAME_SCHEMA or error("state: GAME_SCHEMA is missing (api/00_schema.lua)")

state = {}

-- ---------- путь -> описание типа ----------

-- "gMap.players[2].name" -> { "gMap", ".players", "[2]", ".name" }
local function tokens(path)
    local out = {}
    local head, rest = path:match("^([%a_][%w_]*)(.*)$")
    if not head then error("state: bad path '" .. tostring(path) .. "'", 3) end
    out[1] = head
    for token in rest:gmatch("[%.%[][^%.%[]*") do
        out[#out + 1] = token
    end
    return out
end

local function fieldOf(typeName, field)
    local fields = SCHEMA.types[typeName]
    if not fields then return nil end
    for _, f in ipairs(fields) do
        if f.name:lower() == field:lower() then return f end
    end
end

-- Описание значения по пути: { type = "int" | "float" | "string" | "bool" | "<TRecord>" } или массив.
local function describe(path)
    local parts = tokens(path)
    local node = SCHEMA.globals[parts[1]]
    if not node then error("state: unknown global '" .. parts[1] .. "' (see GAME_STATE.md)", 3) end
    for i = 2, #parts do
        local token = parts[i]
        if token:sub(1, 1) == "[" then
            if not node.array then error("state: '" .. path .. "': not an array before " .. token, 3) end
            node = node.of
        else
            local name = token:sub(2)
            local f = node.type and fieldOf(node.type, name)
            if not f then error("state: '" .. path .. "': no field '" .. name .. "'", 3) end
            node = f
        end
    end
    return node
end

local SCALAR = { int = true, float = true, string = true, bool = true }

function state.type(path)
    local node = describe(path)
    if node.array then return "array" end
    return node.type
end

-- ---------- чтение ----------

local function toNumber(text)
    -- FloatToStr зависит от локали Windows: в русской раскладке разделитель — запятая.
    return tonumber((tostring(text):gsub(",", "."))) or 0
end

local function readScalar(path, kind)
    if kind == "int" then return game.evalInt(path) end
    if kind == "float" then return game.evalFloat(path) end
    if kind == "bool" then return game.evalBool(path) end
    return game.eval(path)
end

function state.get(path)
    local node = describe(path)
    if node.array then return state.list(path) end
    if SCALAR[node.type] then return readScalar(path, node.type) end
    return state.read(path)
end

-- Все простые поля записи (и вложенных записей до depth) одним вызовом скрипта:
-- поля склеиваются в одну строку через символ #1 и режутся обратно здесь.
local SEP = "\1"

local function collect(path, typeName, depth, out, prefix)
    for _, f in ipairs(SCHEMA.types[typeName] or {}) do
        local sub = path .. "." .. f.name
        if not f.array then
            if SCALAR[f.type] then
                out[#out + 1] = { key = prefix .. f.name, path = sub, type = f.type }
            elseif depth > 1 and SCHEMA.types[f.type] then
                collect(sub, f.type, depth - 1, out, prefix .. f.name .. ".")
            end
        end
    end
end

local CONVERT = {
    int    = function(p) return "IntToStr(" .. p .. ")" end,
    float  = function(p) return "FloatToStr(" .. p .. ")" end,
    bool   = function(p) return "BoolToStr(" .. p .. ")" end,
    string = function(p) return p end,
}

local function place(result, key, value)
    local t = result
    for part in key:gmatch("([^%.]+)%.") do
        t[part] = t[part] or {}
        t = t[part]
    end
    t[key:match("([^%.]+)$")] = value
end

function state.read(path, depth)
    local node = describe(path)
    if node.array or SCALAR[node.type] then return state.get(path) end

    local leaves = {}
    collect(path, node.type, depth or 1, leaves, "")
    if #leaves == 0 then return {} end

    local parts = {}
    for i, leaf in ipairs(leaves) do
        parts[i] = CONVERT[leaf.type](leaf.path)
    end
    local text = game.eval(table.concat(parts, "+#1+"))

    local result, i = {}, 0
    for piece in (text .. SEP):gmatch("(.-)" .. SEP) do
        i = i + 1
        local leaf = leaves[i]
        if not leaf then break end
        local value = piece
        if leaf.type == "int" then value = math.tointeger(tonumber(piece)) or 0
        elseif leaf.type == "float" then value = toNumber(piece)
        elseif leaf.type == "bool" then value = piece == "True" or piece == "1"
        end
        place(result, leaf.key, value)
    end
    return result
end

-- Все элементы массива: state.list("gMap.players") — список записей (или значений).
function state.list(path, depth)
    local node = describe(path)
    if not node.array then error("state.list: '" .. path .. "' is not an array", 2) end
    local lo, hi = node.array[1], node.array[2]
    if not lo or not hi then error("state.list: '" .. path .. "' has unknown bounds", 2) end
    local out = {}
    for i = lo, hi do
        local item = path .. "[" .. i .. "]"
        out[#out + 1] = SCALAR[node.of.type] and readScalar(item, node.of.type) or state.read(item, depth)
    end
    return out
end

-- ---------- запись ----------

-- Код держим постоянным, а значение передаём аргументом: так игра компилирует его один раз.
function state.set(path, value)
    if not game.exec then
        error("state.set: only server scripts can change the game (client: ask the server via net.send)", 2)
    end
    local node = describe(path)
    local kind = node.type
    if node.array or not SCALAR[kind] then error("state.set: '" .. path .. "' is not a simple value", 2) end

    if kind == "int" then
        game.exec(path .. " := StrToInt(ML_ARG);", tostring(math.floor(tonumber(value) or 0)))
    elseif kind == "float" then
        -- Дробное передаём целым в миллионных: StrToFloat зависит от локали, StrToInt — нет.
        local scaled = math.floor((tonumber(value) or 0) * 1000000 + 0.5)
        game.exec(path .. " := StrToInt(ML_ARG) / 1000000;", tostring(scaled))
    elseif kind == "bool" then
        game.exec(path .. " := (ML_ARG = '1');", value and "1" or "0")
    else
        game.exec(path .. " := ML_ARG;", tostring(value))
    end
end

-- ---------- G: то же через точку ----------

local function proxy(path)
    return setmetatable({}, {
        __index = function(_, key)
            local sub = type(key) == "number" and (path .. "[" .. key .. "]") or (path .. "." .. key)
            local node = describe(sub)
            if not node.array and SCALAR[node.type] then return readScalar(sub, node.type) end
            return proxy(sub)
        end,
        __newindex = function(_, key, value)
            local sub = type(key) == "number" and (path .. "[" .. key .. "]") or (path .. "." .. key)
            state.set(sub, value)
        end,
        __call = function(_, depth) return state.read(path, depth) end,
        __tostring = function() return "state<" .. path .. ">" end,
    })
end

G = setmetatable({}, {
    __index = function(_, name)
        if not SCHEMA.globals[name] then error("G." .. tostring(name) .. ": unknown game global", 2) end
        return proxy(name)
    end,
    __newindex = function() error("G: assign fields, not globals (G.gProfile.x = 1)", 2) end,
})
