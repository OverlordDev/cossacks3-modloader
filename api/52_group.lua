-- group — отряды игры: создание, состав, центр, движение строем.
--
-- Группы — родная сущность движка (колонны маршируют сами). Состав и движение
-- меняют мир: только server/shared. Чтение состава/центра — везде.
-- Честно: GroupSetVisible в движке НЕТ — прячьте через model.show по юнитам.
--
--   local g = group.create(0, "cavalry")      -- player-индекс + имя
--   group.add(g, { h1, h2, h3 })              -- group.remove(g, h), group.clear(g)
--   group.members(g)                          --> { h, ... }
--   local x, y, z = group.center(g)
--   group.move(g, x, z)                       -- всем участникам (через orders)
--   group.formation(g, "wedge", { spacing = 3 })
--   group.stretch(g, 1.5)                     -- растянуть строй (server/shared)
--   group.rebuild(g)                          -- пересчитать сетку после потерь
--   group.destroy(g)                          -- расформировать (юниты живут)

group = {}

local function checkGr(g, where)
    g = math.tointeger(tonumber(g))
    if not g or g == 0 then error("group." .. where .. ": group handle must be non-zero", 3) end
    return g
end

local function checkHandle(h)
    h = math.tointeger(tonumber(h))
    if not h or h == 0 then error("group: unit handle must be non-zero", 3) end
    return h
end

local function needServer(where)
    if not game.exec then
        error("group." .. where .. ": only server/shared scripts can change groups", 3)
    end
    if not game.isInGame() then
        error("group." .. where .. ": no active game (check game.isInGame())", 3)
    end
end

-- Создать группу игрока. Парам: player — индекс или хендл; name — непустая строка.
-- Возвращает хендл группы. Сторона: только server/shared (нужен game.exec и активная игра).
-- Ошибки: пустое имя; плохой player; движок отказал; вызов с client; нет игры.
function group.create(player, name)
    needServer("create")
    if type(name) ~= "string" or name == "" then
        error("group.create: name must be a non-empty string", 2)
    end
    local ph
    if type(player) == "number" and player < 0x10000 then
        ph = native.GetPlayerHandleByIndex(math.tointeger(player)
            or error("group.create: bad player index", 2))
    else
        ph = checkHandle(player)
    end
    local g = native.CreateGroupByPlHandle(ph, name)
    if not g or g == 0 then error("group.create: engine refused (bad player/name?)", 2) end
    return g
end

-- Добавить юнитов в группу. Парам: g — хендл группы; units — хендл или список хендлов.
-- Ничего не возвращает. Сторона: только server/shared. Ошибки: нулевой хендл; вызов с client; нет игры.
function group.add(g, units)
    needServer("add")
    g = checkGr(g, "add")
    if type(units) ~= "table" then units = { units } end
    for _, h in ipairs(units) do
        native.GroupAddGameObjectByHandle(g, checkHandle(h))
    end
end

-- Убрать юнита из группы. Парам: g — хендл группы; h — хендл юнита.
-- Ничего не возвращает. Сторона: только server/shared. Ошибки: нулевой хендл; вызов с client; нет игры.
function group.remove(g, h)
    needServer("remove")
    native.GroupRemoveGameObjectByHandle(checkGr(g, "remove"), checkHandle(h))
end

-- Убрать всех юнитов из группы (группа остаётся). Парам: g — хендл группы.
-- Ничего не возвращает. Сторона: только server/shared. Ошибки: нулевой хендл; вызов с client; нет игры.
function group.clear(g)
    needServer("clear")
    native.GroupClearGameObjectsByHandle(checkGr(g, "clear"))
end

-- Участники группы. Парам: g — хендл группы. Возвращает { h, ... }.
-- Сторона: везде (только чтение, но нужна активная игра). Ошибки: нулевой хендл; нет игры.
function group.members(g)
    if not game.isInGame() then error("group.members: no active game", 2) end
    g = checkGr(g, "members")
    local out = {}
    for i = 0, native.GetGroupCountGameObjectsByHandle(g) - 1 do
        local h = native.GetGroupGOHandleByGOIndexByHandle(g, i)
        if h and h ~= 0 then out[#out + 1] = h end
    end
    return out
end

-- Число участников группы. Парам: g — хендл группы. Возвращает число.
-- Сторона: везде (только чтение, но нужна активная игра). Ошибки: нулевой хендл; нет игры.
function group.count(g)
    if not game.isInGame() then error("group.count: no active game", 2) end
    return native.GetGroupCountGameObjectsByHandle(checkGr(g, "count"))
end

-- Центр группы. Парам: g — хендл группы. Возвращает x, y, z.
-- Сторона: везде (только чтение, но нужна активная игра). Ошибки: нулевой хендл; нет игры.
function group.center(g)
    if not game.isInGame() then error("group.center: no active game", 2) end
    g = checkGr(g, "center")
    return native.GroupGetCentralPositionXByHandle(g),
           native.GroupGetCentralPositionYByHandle(g),
           native.GroupGetCentralPositionZByHandle(g)
end

-- Двинуть всех участников в точку (через orders — с событиями и сетью).
-- Парам: g — хендл группы; x, z — точка; opts — как в orders.move. Сторона: только server/shared.
-- Ошибки: вызов с client; нет игры. Пустая группа — молча ничего не делает.
function group.move(g, x, z, opts)
    needServer("move")
    local m = group.members(g)
    if #m == 0 then return end
    orders.move(m, x, z, opts)
end

-- Перестроить участников фигурой (через formation). Парам: g; shape — имя строя; opts — отступы.
-- Возвращает результат formation.set (пустая группа — {}). Сторона: только server/shared.
-- Ошибки: вызов с client; нет игры.
function group.formation(g, shape, opts)
    needServer("formation")
    local m = group.members(g)
    if #m == 0 then return {} end
    return formation.set(m, shape, opts)
end

-- Растянуть/сжать строй (множитель). Парам: g; factor — число > 0. После потерь — group.rebuild(g).
-- Ничего не возвращает. Сторона: только server/shared. Ошибки: factor <= 0; нулевой хендл; вызов с client; нет игры.
function group.stretch(g, factor)
    needServer("stretch")
    factor = tonumber(factor)
    if not factor or factor <= 0 then error("group.stretch: factor must be > 0", 2) end
    native.SetGroupStretchFactorByHandle(checkGr(g, "stretch"), factor)
end

-- Пересчитать сетку строя после потерь. Парам: g — хендл группы.
-- Ничего не возвращает. Сторона: только server/shared. Ошибки: нулевой хендл; вызов с client; нет игры.
function group.rebuild(g)
    needServer("rebuild")
    native.GroupGameObjectsGridRebuildByHandle(checkGr(g, "rebuild"))
end

-- Прямой путь без обхода коллизий (марш по прямой) / обратно. Парам: g; on — true/false (nil = true).
-- Ничего не возвращает. Сторона: только server/shared. Ошибки: нулевой хендл; вызов с client; нет игры.
function group.direct(g, on)
    needServer("direct")
    if on == nil then on = true end
    native.GroupSetDirectPathColPointCancel(checkGr(g, "direct"), on and true or false)
end

-- Расформировать группу (юниты остаются на карте). Парам: g — хендл группы.
-- Ничего не возвращает. Сторона: только server/shared. Ошибки: нулевой хендл; вызов с client; нет игры.
function group.destroy(g)
    needServer("destroy")
    native.RemoveGroupByHandle(checkGr(g, "destroy"))
end

-- Путь группы досчитан (см. pathfind.groupReady). Парам: g — хендл группы. Возвращает флаг движка.
-- Сторона: везде (только чтение, но нужна активная игра). Ошибки: нулевой хендл; нет игры.
function group.ready(g)
    if not game.isInGame() then error("group.ready: no active game", 2) end
    return native.GroupGetFindPathByHandle(checkGr(g, "ready"))
end
