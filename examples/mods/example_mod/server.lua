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
