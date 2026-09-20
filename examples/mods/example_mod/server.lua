-- Серверная сторона: решает за игру. Работает в одиночной игре и у хоста.
local utils = require("utils")

local GOLD_BONUS = 500

events.on("game.start", function()
    log.info("game started, mode = " .. game.mode())
end)

-- Клиент просит золото. Сервер сам определяет, кто просит (по from), и сам решает, выдавать ли.
net.on("request_gold", function(data, from)
    local index = game.playerIndexOf(from)
    local p = player(index)
    p:add("gold", GOLD_BONUS)
    log.info("player " .. index .. " got " .. GOLD_BONUS .. " gold, now: " .. utils.formatResources(p))
    net.broadcast("gold_granted", { player = index, amount = GOLD_BONUS })
end)

-- Параметры будущей карты. game.prepare приходит в самом начале создания партии — ровно перед тем,
-- как игра прочитает эти поля (data/gui/menu.inc/donewgame.inc). Позже менять поздно.
-- Раскомментируй, чтобы каждая новая партия шла на большой карте с кучей шахт и богатым стартом:
--
-- events.on("game.prepare", function()
--     world{ size = 2, mines = 3, resources = 2 }
--     log.info("карта: " .. tostring(world().size))
-- end)
