-- tracks — сеть маршрутов: дороги, караваны, патрульные пути, снабжение.
--
-- Узлы и связи движка (TrackNode): караваны и патрули ходят по графу, а не по прямой.
-- Меняет навигацию: только server/shared. После GetTrackNodePathByHandle длина
-- последнего пути читается через tracks.lastLength().
--
--   local a = tracks.add("road", x1, y1, z1)     -- y — высота (обычно RayCastHeight)
--   local b = tracks.add("road", x2, y2, z2)
--   tracks.connect(a, b)                         -- двусторонняя; oneSide — односторонняя
--   tracks.exists(a, b)                          --> true/false (+ длина через lastLength)
--   tracks.neighbours(a)                         --> { h, ... }
--   tracks.pos(a)                                --> x, y, z
--   tracks.use(h, true)                          -- юниту ходить по узлам (server/shared)
--   tracks.clear("road")                         -- снести всю группу узлов
--
-- layer — слой сети (0 — земля). group — имя сети ("road", "rail"...).

tracks = {}

local function needServer(where)
    if not game.exec then
        error("tracks." .. where .. ": only server/shared scripts can edit routes", 3)
    end
    if not game.isInGame() then
        error("tracks." .. where .. ": no active game (check game.isInGame())", 3)
    end
end

local function checkNode(h, where)
    h = math.tointeger(tonumber(h))
    if not h or h == 0 then error("tracks." .. where .. ": node handle must be non-zero", 3) end
    return h
end

local function num(v, name)
    local n = tonumber(v)
    if not n or n ~= n then error("tracks: " .. name .. " must be a number", 3) end
    return n
end

-- tracks.add(groupName, x, y, z, layer): добавить узел в сеть group (натив AddTrackNode). Парам: имя сети; координаты; layer — слой (0).
-- Возвращает хендл узла. Сторона: только server/shared. Ошибки: пустое group; нечисловые координаты; нет игры.
function tracks.add(groupName, x, y, z, layer)
    needServer("add")
    if type(groupName) ~= "string" or groupName == "" then
        error("tracks.add: group must be a non-empty string", 2)
    end
    return native.AddTrackNode(groupName, num(x, "x"), num(y, "y"), num(z, "z"),
        math.tointeger(tonumber(layer or 0)) or 0)
end

-- tracks.connect(a, b): двусторонняя связь узлов (натив ConnectTrackNodesByHandle). Парам: хендлы узлов.
-- Ничего не возвращает. Сторона: только server/shared. Ошибки: нулевой хендл; нет игры.
function tracks.connect(a, b)
    needServer("connect")
    native.ConnectTrackNodesByHandle(checkNode(a, "connect"), checkNode(b, "connect"))
end

-- tracks.oneSide(a, b): односторонняя связь a -> b (натив OneSideConnectTrackNodesByHandle). Парам: хендлы узлов.
-- Ничего не возвращает. Сторона: только server/shared. Ошибки: нулевой хендл; нет игры.
function tracks.oneSide(a, b)
    needServer("oneSide")
    native.OneSideConnectTrackNodesByHandle(checkNode(a, "oneSide"), checkNode(b, "oneSide"))
end

-- tracks.exists(a, b): есть ли путь между узлами (натив GetTrackNodePathByHandle, считает движок). Парам: хендлы узлов.
-- Возвращает true/false (длина пути — через tracks.lastLength). Сторона: только server/shared. Ошибки: нулевой хендл; нет игры.
function tracks.exists(a, b)
    needServer("exists")
    return native.GetTrackNodePathByHandle(checkNode(a, "exists"), checkNode(b, "exists"))
end

-- tracks.lastLength(): длина последнего посчитанного пути (натив GetTrackNodePathLength, сразу после tracks.exists).
-- Возвращает число. Сторона: только server/shared. Ошибки: нет игры.
function tracks.lastLength()
    needServer("lastLength")
    return native.GetTrackNodePathLength()
end

-- tracks.neighbours(h): соседи узла по связям. Парам: h — хендл узла. Возвращает { h, ... }.
-- Сторона: только server/shared. Ошибки: нулевой хендл; нет игры.
function tracks.neighbours(h)
    needServer("neighbours")
    h = checkNode(h, "neighbours")
    local out = {}
    for i = 0, native.GetTrackNodeNeighboursCountByHandle(h) - 1 do
        out[#out + 1] = native.GetTrackNodeNeighbourHandleByHandleByIndex(h, i)
    end
    return out
end

-- tracks.pos(h): позиция узла (натив GetTrackNodePositionByHandle). Парам: h — хендл узла. Возвращает x, y, z.
-- Сторона: только server/shared. Ошибки: нулевой хендл; нет игры.
function tracks.pos(h)
    needServer("pos")
    return native.GetTrackNodePositionByHandle(checkNode(h, "pos"))
end

-- tracks.count(): всего узлов во всех сетях (натив GetTrackNodeCount). Возвращает число. Сторона: только server/shared.
function tracks.count()
    needServer("count")
    return native.GetTrackNodeCount()
end

-- tracks.clear(groupName): снести всю сеть group (натив ClearTrackNodeList). Парам: имя сети — строка.
-- Ничего не возвращает. Сторона: только server/shared. Ошибки: group не строка; нет игры.
function tracks.clear(groupName)
    needServer("clear")
    if type(groupName) ~= "string" then error("tracks.clear: group must be a string", 2) end
    native.ClearTrackNodeList(groupName)
end

-- tracks.breakFar(dist): разорвать все связи длиннее dist (натив BreakConnectionsByTrackNodes, расчистка завалов).
-- Парам: dist — число. Ничего не возвращает. Сторона: только server/shared. Ошибки: dist не число; нет игры.
function tracks.breakFar(dist)
    needServer("breakFar")
    native.BreakConnectionsByTrackNodes(num(dist, "dist"))
end

-- tracks.use(h, on): юниту ходить по узлам при поиске пути. Парам: h — хендл юнита; on — true/false (nil = true).
-- Ничего не возвращает. Сторона: только server/shared. Ошибки: нулевой хендл; нет игры.
function tracks.use(h, on)
    needServer("use")
    if on == nil then on = true end
    native.SetGameObjectBVUseTrackNodeByHandle(checkNode(h, "use"), on and true or false)
end
