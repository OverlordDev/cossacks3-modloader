-- Клиентская сторона: у каждого игрока. Читает состояние, изменения просит у сервера.
local utils = require("utils")

events.on("game.start", function()
    log.info("I am " .. game.mode() .. ", my resources: " .. utils.formatResources(player()))
end)

-- F6 — попросить у сервера золото.
input.bind("F6", function()
    if not game.isInGame() then return end
    net.send("request_gold", {})
end)

-- Сервер сообщил всем, кому выдано золото.
net.on("gold_granted", function(data)
    log.info(("player %d received %d gold"):format(data.player, data.amount))
end)
