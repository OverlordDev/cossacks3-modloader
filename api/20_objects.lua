-- objects — быстрое чтение юнитов и зданий прямо из памяти игры, без компиляции Pascal.
--
-- Обычный путь (state.read, units.info) каждый раз собирает и компилирует кусок Pascal — это
-- миллисекунды на вызов. Здесь поле читается из памяти за микросекунды: можно каждый такт
-- обходить тысячи юнитов (HUD, логика, статистика).
--
--   objects.get(h, "hp")                    --> значение поля TObj (путь как в state: "orders[0].info.x")
--   objects.read(h)                         --> все простые поля TObj таблицей {hp=, cid=, pl=, bdead=, ...}
--   objects.list(player)                    --> хендлы объектов игрока (индекс игрока; nil — все игроки)
--   objects.each(function(h) ... end, player)
--   objects.pos(h)                          --> x, z
--   objects.status()                        --> "fast" | "slow" | "not calibrated", и описание раскладки
--
-- Раскладку полей модлоадер считает по схеме игры (GAME_STATE.md, TObj) и при первом обращении в
-- партии сверяет с тем, что отдаёт сама игра. Не совпало — все функции работают через Pascal (медленно,
-- но правильно), а в лог пишется предупреждение. Только чтение: писать — state.set / balance / buildings.

objects = {}

local SCHEMA = GAME_SCHEMA or error("objects: GAME_SCHEMA is missing (api/00_schema.lua)")

local layoutCache = {}   -- [typeName] = {size, fields = {name -> {off, node}}} для текущих параметров
local params             -- {float = 4|8, bool = 1|4, align = 1|4|8, base = 0..12} после калибровки
local mode = "not calibrated"
local warned = false

local function num(v) return tonumber((tostring(v or ""):gsub(",", "."))) end

-- ---------- раскладка ----------

local PRIMITIVE = { int = 4, string = 4, Pointer = 4, Byte = 1, Word = 2 }

local function scalarSize(t, p)
    if t == "float" then return p.float end
    if t == "bool" then return p.bool end
    return PRIMITIVE[t]
end

local layoutOf

local function nodeSize(node, p)
    if node.array then
        local lo, hi = node.array[1], node.array[2]
        return (hi - lo + 1) * nodeSize(node.of, p)
    end
    local s = scalarSize(node.type, p)
    if s then return s end
    if SCHEMA.types[node.type] then return layoutOf(node.type, p).size end
    return 4 -- классы (TIntegerList, TPtrList ...) — ссылка
end

-- Движок кладёт поля подряд без выравнивания, размер записи округляет вверх до align.
layoutOf = function(typeName, p)
    local key = typeName
    local cached = layoutCache[key]
    if cached and cached.p == p then return cached end
    local fields, off = {}, 0
    for _, f in ipairs(SCHEMA.types[typeName] or {}) do
        fields[f.name:lower()] = { off = off, node = f }
        off = off + nodeSize(f, p)
    end
    local size = p.align > 1 and math.ceil(off / p.align) * p.align or off
    local l = { size = size, fields = fields, p = p }
    layoutCache[key] = l
    return l
end

-- "orders[0].info.x" -> смещение от начала TObj и узел схемы. nil, ошибка — если пути нет.
local function resolve(path, p)
    local off, typeName, node = p.base, "TObj", nil
    for token in (path:gsub("%[", ".["):gsub("^%.", "")):gmatch("[^%.]+") do
        local index = token:match("^%[(%-?%d+)%]$")
        if index then
            if not (node and node.array) then return nil, "not an array before [" .. index .. "]" end
            index = tonumber(index)
            if index < node.array[1] or index > node.array[2] then return nil, "index " .. index .. " out of range" end
            off = off + (index - node.array[1]) * nodeSize(node.of, p)
            node = node.of
            typeName = node.type
        else
            if not typeName or not SCHEMA.types[typeName] then return nil, "'" .. token .. "': not a record" end
            local f = layoutOf(typeName, p).fields[token:lower()]
            if not f then return nil, "no field '" .. token .. "' in " .. typeName end
            off = off + f.off
            node = f.node
            typeName = node.type
        end
    end
    return off, node
end

local function readAt(addr, off, node, p)
    local t = node.type
    if node.array or (SCHEMA.types[t] and not PRIMITIVE[t]) then return nil end -- не скаляр
    if t == "int" then return mem.i32(addr, off) end
    if t == "float" then return p.float == 8 and mem.f64(addr, off) or mem.f32(addr, off) end
    if t == "bool" then
        local v = p.bool == 1 and mem.u8(addr, off) or mem.u32(addr, off)
        return v and v ~= 0
    end
    if t == "string" then return mem.str(addr, off) end
    if t == "Byte" then return mem.u8(addr, off) end
    if t == "Word" then return mem.u16(addr, off) end
    return mem.u32(addr, off) -- Pointer и ссылки на классы
end

-- ---------- адрес объекта ----------

-- Как _unit_GetTObj: данные состояния объекта, аргумент gc_argunit_obj (= 0).
function objects.ptr(h)
    h = math.tointeger(tonumber(h))
    if not h or h == 0 then return nil end
    local sm = native.GetGameObjectStateMachineHandle(h)
    if not sm or sm == 0 then return nil end
    local p = native.StateMachineGetArgDataByInd(sm, 0)
    if not p or p == 0 then return nil end
    return p & 0xFFFFFFFF
end

-- ---------- калибровка ----------

local function slowGet(h, path)
    return state.get(string.format("obj(%d).%s", h, path))
end

-- Поля для сверки: все простые поля TObj и несколько вложенных (приказы идут после них в памяти).
local function probeFields()
    local out = {}
    for _, f in ipairs(SCHEMA.types.TObj or {}) do
        if f.type == "int" or f.type == "float" or f.type == "bool" then out[#out + 1] = f end
    end
    for _, extra in ipairs({ "orders[0].itype", "orders[0].info.trg", "orders[0].info.x", "orders[1].itype",
                             "orders[11].itype", "orders[11].info.y" }) do
        out[#out + 1] = { name = extra, type = extra:find("%.[xy]$") and "float" or "int" }
    end
    return out
end

local function toText(f)
    local e = "TObj(_unit_GetTObj(%d))." .. f.name
    if f.type == "float" then return "FloatToStr(" .. e .. ")" end
    if f.type == "bool" then return "BoolToStr(" .. e .. ")" end
    return "IntToStr(" .. e .. ")"
end

local function same(fast, slow, t)
    if fast == nil then return false end
    if t == "bool" then return fast == (slow == "True" or slow == "1") end
    local s = num(slow)
    if s == nil then return false end
    if t == "float" then return math.abs(fast - s) <= 1e-3 * math.max(1, math.abs(s)) end
    return fast == s
end

local BASEID_OBJ = 1 -- gc_baseid_obj: юнит или здание (у ресурсов и снарядов другие данные)

-- Значения полей от самой игры (Pascal) — эталон для сверки.
local function probe(h, fields)
    local parts = {}
    for i, f in ipairs(fields) do parts[i] = string.format(toText(f), h) end
    local ok, text = pcall(game.eval, table.concat(parts, "+#1+"))
    if not ok or type(text) ~= "string" then return nil, "game.eval failed: " .. tostring(text) end
    local slow = {}
    for v in (text .. "\1"):gmatch("(.-)\1") do slow[#slow + 1] = v end
    if #slow ~= #fields then return nil, "unexpected answer" end
    return slow
end

-- Сверка на нескольких объектах: раскладка должна совпасть на всех, иначе по нулям в полях
-- можно принять неверную.
function objects.calibrate(h)
    h = math.tointeger(tonumber(h))
    local fields = probeFields()
    local samples = {}
    local function add(handle)
        if #samples >= 3 then return end
        for _, s in ipairs(samples) do if s.h == handle then return end end
        local addr = objects.ptr(handle)
        if not addr or mem.i32(addr, 0) ~= BASEID_OBJ and mem.i32(addr, 4) ~= BASEID_OBJ
           and mem.i32(addr, 8) ~= BASEID_OBJ and mem.i32(addr, 12) ~= BASEID_OBJ then return end
        local slow = probe(handle, fields)
        if slow and slow[1] == tostring(BASEID_OBJ) then samples[#samples + 1] = { h = handle, addr = addr, slow = slow } end
    end
    if h then add(h) end
    for _, other in ipairs(objects.list()) do
        if #samples >= 3 then break end
        add(other)
    end
    if #samples == 0 then return false, "no unit or building to check against" end

    for _, align in ipairs({ 4, 1, 8 }) do
        for _, fsize in ipairs({ 4, 8 }) do
            for _, bsize in ipairs({ 1, 4 }) do
                for base = 0, 12, 4 do
                    local p = { float = fsize, bool = bsize, align = align, base = base }
                    layoutCache = {}
                    local good = true
                    for _, sample in ipairs(samples) do
                        for i, f in ipairs(fields) do
                            local off, node = resolve(f.name, p)
                            if not off or not same(readAt(sample.addr, off, node, p), sample.slow[i], f.type) then
                                good = false
                                break
                            end
                        end
                        if not good then break end
                    end
                    if good then
                        params, mode = p, "fast"
                        log.info(string.format("objects: fast access on (TObj %d bytes; float %d, bool %d, align %d, base %d; checked on %d object(s))",
                            layoutOf("TObj", p).size, fsize, bsize, align, base, #samples))
                        return true
                    end
                end
            end
        end
    end
    layoutCache = {}
    mode = "slow"
    log.warn("objects: memory layout of TObj does not match the schema — falling back to Pascal (slow)")
    return false, "layout mismatch"
end

-- Калибруем на первом живом объекте, который попросили.
local function ensure(h)
    if mode == "not calibrated" then
        local ok, why = objects.calibrate(h)
        if not ok and why ~= "layout mismatch" and not warned then
            warned = true
            log.warn("objects: calibration postponed (" .. tostring(why) .. ")")
        end
    end
    return mode == "fast"
end

function objects.status()
    return mode, params
end

-- ---------- чтение ----------

function objects.get(h, path)
    h = math.tointeger(tonumber(h))
    if not h then error("objects.get: handle must be a number", 2) end
    if ensure(h) then
        local addr = objects.ptr(h)
        if not addr or mem.i32(addr, params.base) ~= BASEID_OBJ then return nil end
        local off, node = resolve(path, params)
        if not off then error("objects.get: " .. node, 2) end
        return readAt(addr, off, node, params)
    end
    return slowGet(h, path)
end

function objects.read(h)
    h = math.tointeger(tonumber(h))
    if not h then error("objects.read: handle must be a number", 2) end
    local out = {}
    if ensure(h) then
        local addr = objects.ptr(h)
        if not addr or mem.i32(addr, params.base) ~= BASEID_OBJ then return nil end
        local l = layoutOf("TObj", params)
        for _, f in ipairs(SCHEMA.types.TObj) do
            local v = readAt(addr, params.base + l.fields[f.name:lower()].off, f, params)
            if v ~= nil then out[f.name] = v end
        end
        return out
    end
    for _, f in ipairs(SCHEMA.types.TObj) do
        if f.type == "int" or f.type == "float" or f.type == "bool" or f.type == "string" then
            out[f.name] = slowGet(h, f.name)
        end
    end
    return out
end

function objects.pos(h)
    return native.GetGameObjectPositionXByHandle(h), native.GetGameObjectPositionZByHandle(h)
end

-- ---------- обход ----------

function objects.list(player)
    local out = {}
    local first, last = 0, 15
    if player then first, last = player, player end
    for i = first, last do
        local pl = native.GetPlayerHandleByIndex(i)
        if pl and pl ~= 0 then
            for k = 0, native.GetPlayerGameObjectsCountByHandle(pl) - 1 do
                local h = native.GetGameObjectHandleByIndex(k, pl)
                if h and h ~= 0 then out[#out + 1] = h end
            end
        end
    end
    return out
end

function objects.each(fn, player)
    for _, h in ipairs(objects.list(player)) do fn(h) end
end

-- Новая партия — объекты другие, но раскладка та же: калибровку не сбрасываем.
