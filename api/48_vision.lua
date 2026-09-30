-- vision — разведка: дальность по типам, точечное раскрытие, ночь.
--
-- Дальность — свойство ТИПА (как balance): меняется в game.start в shared.
-- Точечное раскрытие — через fow (запись server/shared, чтение везде).
-- Честно: общего зрения (share) и детекторов (air/stealth) в движке нет —
-- их здесь нет тоже; радары эмулируйте revealObject на вышке + markers.
--
--   -- shared.lua, game.start:
--   vision.radius("cossack", 1200)
--   -- server.lua:
--   vision.reveal(towerH)                  -- вышка разведывает; vision.hide(towerH)
--   vision.night(true)                     -- ночь: туман вкл + темно (server/shared)
--
-- Дальность — в тех же единицах, что gObjProp.vision (сверьтесь с balance.dump).

vision = {}

local function needServer(where)
    if not game.exec then
        error("vision." .. where .. ": only server/shared scripts can change vision", 3)
    end
    if not game.isInGame() then
        error("vision." .. where .. ": no active game (check game.isInGame())", 3)
    end
end

-- Дальность видимости типа (по всем игрокам; player — индекс для личной).
-- Менять в game.start в shared (статы типов заполняются к началу партии).
function vision.radius(sid, value, player)
    needServer("radius")
    if type(sid) ~= "string" or sid == "" then
        error("vision.radius: sid must be a non-empty string", 2)
    end
    value = tonumber(value)
    if not value or value < 0 then error("vision.radius: value must be >= 0", 2) end
    if player ~= nil then
        balance.set(sid, "vision", value, player)
    else
        balance.setProp(sid, "vision", value)
    end
end

-- Объект разведывает вокруг себя (радар, вышка, осветительная ракета).
function vision.reveal(h)
    needServer("reveal")
    fow.revealObject(h)
end

-- vision.hide(h): объект перестаёт разведывать (пара к reveal). h — хендл. Сторона: только server/shared.
function vision.hide(h)
    needServer("hide")
    fow.hideObject(h)
end

-- Ночной режим: туман вкл + плотнее. Возврат — vision.night(false).
function vision.night(on)
    needServer("night")
    if on == nil then on = true end
    if on then
        fow.enable(true)
    end
end
