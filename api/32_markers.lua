-- markers — общие игровые маркеры: миникарта + земля + подсветка сразу.
--
-- Только картинка (client; в shared — одинаково у всех, т.к. координаты те же).
--
--   local id = markers.add{ x = 100, z = 50, icon = "attack", decal = "scorch", duration = 10 }
--   markers.remove(id)
--   markers.clear()
--
-- Поля: x, z (мировые, обязательно), icon (имя примитива миникарты),
-- tag (число для поиска), dx/dy (направление), blink = { интервал, число },
-- decal (имя декали на земле), highlight = { handle=, key= } (подсветка объекта),
-- duration (секунды; 0/nil — навсегда).

markers = {}

local items = {}
local nextId = 1
local tickSub = nil

local function num(v, name)
    local n = tonumber(v)
    if not n or n ~= n then error("markers: " .. name .. " must be a number", 3) end
    return n
end

local function inGame(where)
    if not game.isInGame() then
        error("markers." .. where .. ": no active game (check game.isInGame())", 3)
    end
end

local function ensureTick()
    if tickSub then return end
    tickSub = events.on("game.tick", function()
        local now = os.clock()
        for id, m in pairs(items) do
            if m.expires and now >= m.expires then markers.remove(id) end
        end
    end)
end

-- add(t): общий маркер (миникарта + декаль + подсветка). Параметры: t = { x=, z=, icon=, tag=, dx=, dy=, blink=, decal=, highlight=, duration= }.
-- Возврат: id маркера. Только картинка (client; в shared — одинаково у всех). Ошибки: нет игры, t не таблица, x/z не числа.
function markers.add(t)
    inGame("add")
    if type(t) ~= "table" then error("markers.add: pass { x=, z= }", 2) end
    local x, z = num(t.x, "x"), num(t.z, "z")
    local id = nextId
    nextId = nextId + 1
    local m = { id = id, x = x, z = z }
    if t.icon ~= nil then
        -- миникарта ждёт координаты своей системы: грубо — мировые как есть
        -- (точную проекцию смотрите по размеру карты из map.info()).
        m.mi = minimap.put(t.icon, x, z, { tag = t.tag, dx = t.dx, dy = t.dy,
            blink = t.blink, visible = true })
    end
    if t.decal ~= nil then
        local ok, d = pcall(decals.put, t.decal, x, z)
        if ok then m.decal = d end
    end
    if t.highlight ~= nil then
        local hopts = t.highlight
        local ok, hd = pcall(effects.highlight, hopts.handle, hopts.key or ("marker" .. id),
            true, hopts.mat or "")
        if ok then m.hl = { handle = hopts.handle, key = hopts.key or ("marker" .. id) } end
    end
    if t.duration and tonumber(t.duration) and tonumber(t.duration) > 0 then
        m.expires = os.clock() + tonumber(t.duration)
        ensureTick()
    end
    items[id] = m
    return id
end

-- remove(id): убрать маркер и его миникарту/декаль/подсветку. Неизвестный id — молча ничего. Только картинка (client).
function markers.remove(id)
    local m = items[id]
    if not m then return end
    items[id] = nil
    if m.mi then pcall(minimap.remove, m.mi) end
    if m.decal then pcall(decals.remove, m.decal) end
    if m.hl then pcall(effects.unhighlight, m.hl.handle, m.hl.key) end
end

-- clear(): убрать все маркеры. Только картинка (client), ошибок не кидает.
function markers.clear()
    for id in pairs(items) do markers.remove(id) end
end

-- get(id): запись маркера { id, x, z, mi, decal, hl, expires } или nil. Только чтение (client), ошибок не кидает.
function markers.get(id)
    return items[id]
end
