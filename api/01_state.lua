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
-- Объект на карте (юнит, здание) — корень obj(<хендл>), его данные TObj:
--   state.read("obj(39878848)")                    --> { hp = 120, pl = 0, cid = 4, id = 12, bbuilt = true, ... }
--   state.get("obj(39878848).orders[0].itype")      --  первый заказ в очереди
--   state.set("obj(39878848).hp", 50)
--
-- Какие переменные и поля есть — GAME_STATE.md, он сгенерирован вместе со схемой.
--
-- Типы берутся из схемы (00_schema.lua), поэтому нужная функция чтения выбирается сама:
-- не надо помнить, где evalInt, где evalFloat, а где строка.
--
-- Сторона: чтение (get/read/list/type, G.x) — shared (везде); запись (set, G.x = v) —
-- server/shared/страница (на client нет game.exec — ошибка "only server scripts", проси через net.send).
-- Ошибки чтения/записи: bad path, unknown global, no field, not an array, unknown bounds,
-- not a simple value — текстом из describe/list/set (см. функции).

local SCHEMA = GAME_SCHEMA or error("state: GAME_SCHEMA is missing (api/00_schema.lua)")

state = {}

-- ---------- путь -> описание типа ----------

-- tokens(path): разбить путь на токены. Парам: path — "gMap.players[2].name".
-- Возврат: { "gMap", ".players", "[2]", ".name" }. Ошибки: "state: bad path" при пустом/битом пути.
-- "gMap.players[2].name" -> { "gMap", ".players", "[2]", ".name" }
local function tokens(path)
    local out = {}
    local head, rest = path:match("^(obj%(%-?%d+%))(.*)$")
    if not head then head, rest = path:match("^([%a_][%w_]*)(.*)$") end
    if not head then error("state: bad path '" .. tostring(path) .. "'", 3) end
    out[1] = head
    for token in rest:gmatch("[%.%[][^%.%[]*") do
        out[#out + 1] = token
    end
    return out
end

-- fieldOf(typeName, field): описание поля записи из схемы (регистр не важен).
-- Возврат: описание поля или nil (нет типа/поля). Ошибок не кидает.
local function fieldOf(typeName, field)
    local fields = SCHEMA.types[typeName]
    if not fields then return nil end
    for _, f in ipairs(fields) do
        if f.name:lower() == field:lower() then return f end
    end
end

-- expr(path): путь -> выражение скрипта игры. Парам: path — путь state.
-- Возврат: Pascal-выражение (obj(123) — это TObj(_unit_GetTObj(123))). Ошибок не кидает.
-- Описание значения по пути: { type = "int" | "float" | "string" | "bool" | "<TRecord>" } или массив.
-- Путь -> выражение скрипта игры: obj(123) — это TObj(_unit_GetTObj(123)).
local function expr(path)
    return (path:gsub("^obj%((%-?%d+)%)", "TObj(_unit_GetTObj(%1))"))
end

-- describe(path): описание значения по пути из схемы. Парам: path — путь state.
-- Возврат: узел схемы { type, array, of }. Ошибки: "unknown global", "not an array before ...",
-- "no field ..." (см. GAME_STATE.md для верных имён).
local function describe(path)
    local parts = tokens(path)
    local node = SCHEMA.globals[parts[1]]
    if parts[1]:sub(1, 4) == "obj(" then node = { type = "TObj" } end
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

-- ---------- индексы пути -> аргумент ----------

-- ЗАЧЕМ. game.exec кэшируется по ТЕКСТУ кода: каждый новый текст — это новое
-- скомпилированное состояние ModLoader.Call.N в GUI state machine движка, и оно
-- живёт до конца партии (ScriptRunner.cpp, g_callCache). Освобождать состояния
-- движок не даёт.
--
-- Если числа пути запекать в текст, число состояний растёт как число путей.
-- balance.set(sid, "maxhp", v) без указания игрока пишет ВСЕМ игрокам, то есть
-- gPlayer[0..7].objbase[cid][id].maxhp — восемь текстов на одно поле одного типа.
-- На ростере из 17 типов и четырёх полей это 544 состояния за один game.start:
-- в логе 2026-09-28 модлоадер ругался "500 cached script calls" сразу после
-- "баланс применён: 17 типов".
--
-- Поэтому числа из пути уезжают в ML_ARG, а в тексте остаётся форма пути. Тогда
-- состояний столько, сколько РАЗНЫХ ФОРМ, а не сколько вызовов: для примера выше
-- их становится четыре (по одному на поле).
--
-- Тот же приём и по той же причине уже применён в api/38_orders.lua.

-- paramise(pathExpr): заменить числовые индексы на k1..kN. Парам: pathExpr — путь
-- после expr(). Возврат: путь с kN, список чисел в порядке появления.
-- Ошибок не кидает. Нечисловые индексы (константы движка) не трогаются.
local function paramise(pathExpr)
    local args = {}
    local function grab(num)
        args[#args + 1] = num
        return "k" .. #args
    end
    -- Индексы массивов: [12], [-3]. Имена и константы ([gc_...]) не подходят под шаблон.
    local out = pathExpr:gsub("%[(%-?%d+)%]", function(num) return "[" .. grab(num) .. "]" end)
    -- Хендл объекта: obj(-5) превратился в _unit_GetTObj(-5).
    out = out:gsub("(_unit_GetTObj%()(%-?%d+)%)", function(head, num) return head .. grab(num) .. ")" end)
    return out, args
end

-- preamble(n): объявления и разбор n индексов из ML_ARG. Парам: n — сколько.
-- Возврат: код на Pascal (пустая строка при n = 0). Ошибок не кидает.
--
-- Строки режем функциями движка: Pos/Copy/Delete в этом диалекте Pascal нет,
-- есть StrPos/SubStr/StrLength (см. tools/check_pascal.py).
local function preamble(n)
    if n == 0 then return "" end
    local names = {}
    for i = 1, n do names[i] = "k" .. i end
    local lines = { "var s : String = ML_ARG;", "var p : Integer;",
                    "var " .. table.concat(names, ", ") .. " : Integer;" }
    for i = 1, n do
        lines[#lines + 1] = string.format(
            "p := StrPos('|', s); k%d := StrToInt(SubStr(s, 1, p-1)); s := SubStr(s, p+1, StrLength(s)-p);", i)
    end
    return table.concat(lines, "\n") .. "\n"
end

-- Хвост аргумента после индексов — само значение (его не режем: в строковом
-- значении может быть '|').
local function argOf(args, value)
    local out = {}
    for i, v in ipairs(args) do out[i] = v end
    if value ~= nil then out[#out + 1] = value end
    return table.concat(out, "|")
end

-- state.type(path): имя типа значения. Парам: path — путь. Возврат: "int"/"float"/"string"/"bool"/"array"/имя записи.
-- Сторона: shared (везде). Ошибки: unknown global/no field/not an array (из describe).
function state.type(path)
    local node = describe(path)
    if node.array then return "array" end
    return node.type
end

-- ---------- чтение ----------

-- toNumber(text): строка FloatToStr в число с учётом русской локали (запятая -> точка).
-- Парам: text — ответ игры. Возврат: number (0 при мусоре). Ошибок не кидает.
local function toNumber(text)
    -- FloatToStr зависит от локали Windows: в русской раскладке разделитель — запятая.
    return tonumber((tostring(text):gsub(",", "."))) or 0
end

-- Как превратить значение в строку на стороне игры (нужен и чтению одного
-- значения, и чтению записи целиком).
local CONVERT = {
    int    = function(p) return "IntToStr(" .. p .. ")" end,
    float  = function(p) return "FloatToStr(" .. p .. ")" end,
    bool   = function(p) return "BoolToStr(" .. p .. ")" end,
    string = function(p) return p end,
}

-- readScalar(path, kind): одно простое значение нужным нативом. Парам: path, kind (int/float/bool/string).
-- Возврат: number/string/boolean. Сторона: shared (game.eval* везде). Ошибок своих не кидает.
local function readScalar(path, kind)
    local target, args = paramise(expr(path))
    -- Без индексов — обычный game.eval*: текст и так постоянный, а eval короче.
    if #args == 0 then
        if kind == "int" then return game.evalInt(target) end
        if kind == "float" then return game.evalFloat(target) end
        if kind == "bool" then return game.evalBool(target) end
        return game.eval(target)
    end
    -- С индексами — через exec: game.eval* не принимают аргумент (LuaHost.cpp,
    -- EvalAs берёт только код), поэтому ML_RET и разбор индексов из ML_ARG.
    local conv = CONVERT[kind] or CONVERT.string
    local text = game.exec(preamble(#args) .. "ML_RET(" .. conv(target) .. ");", argOf(args))
    if kind == "int" then return math.tointeger(tonumber(text)) or 0 end
    if kind == "float" then return toNumber(text) end
    if kind == "bool" then return text == "True" or text == "1" end
    return text
end

-- state.get(path): любое значение по пути (простое, запись или массив).
-- Парам: path — путь. Возврат: значение / таблица (запись — через read, массив — через list).
-- Сторона: shared (везде). Ошибки: unknown global/no field (из describe).
function state.get(path)
    local node = describe(path)
    if node.array then return state.list(path) end
    if SCALAR[node.type] then return readScalar(path, node.type) end
    return state.read(path)
end

-- Все простые поля записи (и вложенных записей до depth) одним вызовом скрипта:
-- поля склеиваются в одну строку через символ #1 и режутся обратно здесь.
local SEP = "\1"

local collectValue

-- collect(path, typeName, depth, out, prefix): собрать описания простых полей записи (и вложенных до depth).
-- Парам: путь, имя типа, глубина, буфер out, префикс ключей. Ошибок не кидает.
local function collect(path, typeName, depth, out, prefix)
    for _, f in ipairs(SCHEMA.types[typeName] or {}) do
        collectValue(path .. "." .. f.name, f, depth, out, prefix .. f.name)
    end
end

-- collectValue(path, node, depth, out, key): одно описание в буфер: простое — лист; запись — внутрь;
-- массив — поэлементно (ключи — числа). Массивы без границ и шире 64 — пропускаются (через state.list).
-- Ошибок не кидает.
-- Одно значение: простое — лист; запись — внутрь (если хватает глубины); массив — поэлементно
-- (ключи элементов — числа: t.price[3], t.weapon[0].damage). Массивы с неизвестными границами
-- пропускаются.
function collectValue(path, node, depth, out, key)
    if node.array then
        local lo, hi = node.array[1], node.array[2]
        if not lo or not hi or hi - lo > 64 then return end -- огромные массивы — через state.list
        if not SCALAR[node.of.type] and depth <= 1 then return end
        for i = lo, hi do
            collectValue(path .. "[" .. i .. "]", node.of, depth, out, key .. "." .. i)
        end
    elseif SCALAR[node.type] then
        out[#out + 1] = { key = key, path = path, type = node.type }
    elseif depth > 1 and SCHEMA.types[node.type] then
        collect(path, node.type, depth - 1, out, key .. ".")
    end
end


-- place(result, key, value): положить значение в таблицу по ключу "a.0.b" (числа — индексами).
-- Ошибок не кидает.
local function place(result, key, value)
    local t = result
    for part in key:gmatch("([^%.]+)%.") do
        part = tonumber(part) or part -- элементы массивов — числовые ключи
        t[part] = t[part] or {}
        t = t[part]
    end
    local last = key:match("([^%.]+)$")
    t[tonumber(last) or last] = value
end

-- state.read(path, depth): запись таблицей одним вызовом скрипта (поля клеятся через #1).
-- Парам: path — путь к записи/obj(); depth — вложенность (по умолч. 1).
-- Возврат: таблица (простое/массив — через state.get). Сторона: shared (везде).
-- Ошибки: unknown global/no field (из describe).
function state.read(path, depth)
    local node = describe(path)
    if node.array or SCALAR[node.type] then return state.get(path) end

    local leaves = {}
    collect(path, node.type, depth or 1, leaves, "")
    if #leaves == 0 then return {} end

    -- Параметризуем ТОЛЬКО префикс записи (gPlayer[0].objbase[4][12]), а индексы
    -- полей внутри (price[3], weapon[0].damage) оставляем в тексте: они часть
    -- ФОРМЫ запроса, а не меняющиеся данные. Тогда текстов столько, сколько
    -- (тип, глубина), а не сколько объектов — раньше каждый объект давал новое
    -- состояние движка.
    local base = expr(path)
    local target, args = paramise(base)
    local parts = {}
    for i, leaf in ipairs(leaves) do
        -- leaf.path всегда начинается с path: подменяем префикс на параметризованный.
        local suffix = expr(leaf.path):sub(#base + 1)
        parts[i] = CONVERT[leaf.type](target .. suffix)
    end
    local joined = table.concat(parts, "+#1+")
    local text
    if #args == 0 then
        text = game.eval(joined)
    else
        text = game.exec(preamble(#args) .. "ML_RET(" .. joined .. ");", argOf(args))
    end

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

-- state.list(path, depth): все элементы массива списком. Парам: path — путь; depth — вложенность записей.
-- Возврат: список значений/записей. Сторона: shared. Ошибки: "is not an array", "has unknown bounds".
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

-- state.set(path, value): записать простое поле. Парам: path — путь; value — новое значение.
-- Сторона: server/shared/страница (на client — ошибка "only server scripts"). Ошибки: "is not a simple value".
-- Код держим постоянным, а значение передаём аргументом: так игра компилирует его один раз.
function state.set(path, value)
    if not game.exec then
        error("state.set: only server scripts can change the game (client: ask the server via net.send)", 2)
    end
    local node = describe(path)
    local kind = node.type
    if node.array or not SCALAR[kind] then error("state.set: '" .. path .. "' is not a simple value", 2) end
    -- И индексы пути, и значение уезжают в аргумент: в тексте остаётся форма.
    local target, args = paramise(expr(path))
    local head = preamble(#args)
    -- Без индексов значение читается прямо из ML_ARG (текст и так постоянный),
    -- с индексами — из остатка строки после них.
    local v = #args == 0 and "ML_ARG" or "s"

    if kind == "int" then
        game.exec(head .. target .. " := StrToInt(" .. v .. ");",
                  argOf(args, tostring(math.floor(tonumber(value) or 0))))
    elseif kind == "float" then
        -- Дробное передаём целым в миллионных: StrToFloat зависит от локали, StrToInt — нет.
        local scaled = math.floor((tonumber(value) or 0) * 1000000 + 0.5)
        game.exec(head .. target .. " := StrToInt(" .. v .. ") / 1000000;",
                  argOf(args, tostring(scaled)))
    elseif kind == "bool" then
        game.exec(head .. target .. " := (" .. v .. " = '1');", argOf(args, value and "1" or "0"))
    else
        game.exec(head .. target .. " := " .. v .. ";", argOf(args, tostring(value)))
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
