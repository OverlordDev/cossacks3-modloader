-- world.spawn/destroy/move — runtime-создание объектов (мины, декор, ловушки, маркеры).
--
-- МЕНЯЕТ МИР: только server/shared, одинаково на всех машинах, иначе рассинхрон.
-- На client — ошибка. Вне партии нативы падают.
--
--   local h = world.spawn{ race = "ukr", base = "tree", x = 100, z = 50 }
--   local h2 = world.spawn{ player = 1, race = "rus", base = "musketeer18", x = 0, z = 0, name = "мина" }
--   world.move(h, 120, 60)            -- y подберётся по рельефу; world.move(h, x, y, z) — явно
--   local x, y, z = world.pos(h)
--   world.destroy(h)                  -- мягко (через механику смерти); world.destroyNow(h) — сразу
--
-- race — нация (sid из content.lua/игры), base — тип объекта (basename юнита/здания/декора).
-- Своя внешность после спавна — через model.actor/model.material (в shared — тоже синхронно).
-- Неверные race/base могут уронить игру — проверяйте на копии сейва.

world = world or {}

-- Проверка записи: только server/shared (нужен game.exec) и только в партии. Ошибки: на client; вне партии.
local function needServer(where)
    if not game.exec then
        error("world." .. where .. ": only server/shared scripts can change the game (client: net.send)", 3)
    end
    if not game.isInGame() then
        error("world." .. where .. ": no active game (check game.isInGame())", 3)
    end
end

-- Число для spawn (координата). Ошибки: не число, NaN или inf.
local function num(v, name)
    local n = tonumber(v)
    if not n or n ~= n or n == math.huge or n == -math.huge then
        error("world.spawn: " .. name .. " must be a number", 3)
    end
    return n
end

-- Непустая строка для spawn (race/base). Ошибки: не строка или пустая.
local function str(v, name)
    if type(v) ~= "string" or v == "" then
        error("world.spawn: " .. name .. " must be a non-empty string", 3)
    end
    return v
end

-- Ненулевой хендл объекта. Возвращает integer. Ошибки: не число или 0.
local function checkHandle(h, where)
    h = math.tointeger(tonumber(h))
    if not h or h == 0 then error("world." .. where .. ": handle must be a non-zero number", 3) end
    return h
end

local function isLive(h)
    return not (objects and objects.alive and not objects.alive(h))
end

-- Хендл игрока по индексу или готовому хендлу. Параметры: player — индекс (<0x10000), хендл или nil (свой игрок). Возвращает хендл игрока. Ошибки: нет игрока с таким индексом; player не число.
-- Хендл игрока по индексу (для CreatePlayerGameObjectHandleByHandle).
local function playerHandle(player)
    if player == nil then player = native.GetPlayerIndexInterfaceIO() end
    if type(player) == "number" and player < 0x10000 then
        local h = native.GetPlayerHandleByIndex(math.tointeger(player)
            or error("world.spawn: player must be an index or handle", 3))
        if not h or h == 0 then error("world.spawn: no player with index " .. tostring(player), 3) end
        return h
    end
    return math.tointeger(tonumber(player))
        or error("world.spawn: player must be an index or handle", 3)
end

-- Создать объект. Параметры: t = { race=, base=, x=, z=, y= (иначе по рельефу), player= (индекс/хендл, иначе свой), name=, actor=, material=, scale= }. Возвращает handle или nil (игра отказала). Сторона: только server/shared. Ошибки: на client; вне партии; t не таблица; race/base пустые; x/z/y не числа; player/material/actor/scale неверные. Неверные race/base могут уронить игру.
-- Создать объект. Возвращает handle или nil (игра отказала).
function world.spawn(t)
    needServer("spawn")
    if type(t) ~= "table" then error("world.spawn: pass { race=, base=, x=, z= }", 2) end
    local race, base = str(t.race, "race"), str(t.base, "base")
    local x, z = num(t.x, "x"), num(t.z, "z")
    local y = t.y ~= nil and num(t.y, "y") or native.RayCastHeight(x, z)
    local h = native.CreatePlayerGameObjectHandleByHandle(playerHandle(t.player), race, base, x, y, z)
    if not h or h == 0 then return nil end
    if objects and objects._markAlive then objects._markAlive(h) end
    if t.name ~= nil then
        if type(t.name) ~= "string" then error("world.spawn: name must be a string", 2) end
        if t.name ~= "" then native.SetGameObjectCustomNameByHandle(h, t.name) end
    end
    if t.actor ~= nil or t.material ~= nil then
        if t.actor then model.actor(h, t.actor) end
        if t.material then model.material(h, t.material) end
    end
    if t.scale ~= nil then model.scale(h, t.scale) end
    return h
end

-- Мягкое удаление через механику смерти (идут события unit.death). Параметры: h — хендл. Возвращает nil. Сторона: только server/shared. Ошибки: на client; вне партии; h нулевой.
-- Мягкое удаление (идёт через механику игры: смерть, события unit.death).
function world.destroy(h)
    needServer("destroy")
    h = checkHandle(h, "destroy")
    if not isLive(h) then return end
    if objects and objects._markDead then objects._markDead(h) end
    native.GameObjectRequestToDestroyByHandle(h)
end

-- Жёсткое удаление без событий смерти. Параметры: h — хендл. Возвращает nil. Сторона: только server/shared. Ошибки: на client; вне партии; h нулевой.
-- Жёсткое удаление (без событий смерти). Для эффектов исчезновения — сначала effects.*.
function world.destroyNow(h)
    needServer("destroyNow")
    h = checkHandle(h, "destroyNow")
    if not isLive(h) then return end
    if objects and objects._markDead then objects._markDead(h) end
    native.GameObjectDestroyByHandle(h)
end

-- Переместить объект. Параметры: h — хендл; world.move(h, x, z) (y по рельефу) или world.move(h, x, y, z) явно. Возвращает nil. Сторона: только server/shared. Ошибки: на client; вне партии; h нулевой; координаты не числа.
-- Переместить: world.move(h, x, z) или world.move(h, x, y, z).
function world.move(h, x, y, z)
    needServer("move")
    h = checkHandle(h, "move")
    if not isLive(h) then return end
    x = num(x, "x")
    if z == nil then z, y = num(y, "z"), native.RayCastHeight(x, num(y, "z")) end
    native.SetGameObjectPositionByHandle(h, x, num(y, "y"), num(z, "z"))
end

-- Полная позиция объекта. Параметры: h — хендл. Возвращает x, y, z. Сторона: любая (только чтение). Ошибки: вне партии; h нулевой.
-- Полная позиция объекта: x, y, z. Только чтение — можно с любой стороны.
function world.pos(h)
    if not game.isInGame() then error("world.pos: no active game", 2) end
    h = checkHandle(h, "pos")
    if objects and objects.alive and not objects.alive(h) then return nil, nil, nil end
    return native.GetGameObjectPositionXByHandle(h),
           native.GetGameObjectPositionYByHandle(h),
           native.GetGameObjectPositionZByHandle(h)
end

-- world.cursor(): мировая точка под курсором мыши.
--
-- Возвращает ТРИ значения: x, y (высота рельефа), z. Не два.
--
--   local x, y, z = world.cursor()          -- правильно
--   local x, z = world.cursor()             -- в z попадёт ВЫСОТА
--
-- Ровно на этом сгорел мод iron_frontier: снаряды летели в точку с z ≈ 0,
-- потому что вторым значением приходит высота, а не вторая координата.
-- Сторона: везде (только чтение). Ошибки: вне партии.
function world.cursor()
    if not game.isInGame() then error("world.cursor: no active game", 2) end
    return native.GetCurrentMouseWorldCoord()
end
