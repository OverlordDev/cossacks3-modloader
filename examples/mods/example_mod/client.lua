-- Клиентская сторона: у каждого игрока. Читает состояние, меняет только свой интерфейс,
-- изменения в игре просит у сервера.
local utils = require("utils")

local goldText -- элемент интерфейса с золотом (пересоздаётся на каждый game.start)

-- Панель в интерфейсе игры: создаётся штатными функциями, выглядит как родная.
local function buildPanel()
    local panel = ui.window{ name = "mlExamplePanel", x = 20, y = 140, w = 240, h = 120 }
    goldText = ui.text{ name = "mlExampleGold", parent = panel, text = "Gold: ...", x = 24, y = 20,
                        color = { 255, 230, 160, 255 } }
    ui.button{ name = "mlExampleBtn", parent = panel, text = "+500 gold", x = 24, y = 55,
               hint = "Example mod: ask the server for gold",
               onClick = function() net.send("request_gold", {}) end }
end

events.on("game.start", function()
    log.info("I am " .. game.mode() .. ", my resources: " .. utils.formatResources(player()))
    buildPanel()
end)

-- Раз в секунду обновляем текст на панели.
local lastUpdate = 0
events.on("game.tick", function()
    local now = os.clock()
    if goldText and now - lastUpdate >= 1 then
        lastUpdate = now
        ui.setText(goldText, "Gold: " .. player().gold)
    end
end)

events.on("game.end", function() goldText = nil end)

-- F6 — то же, что кнопка на панели.
input.bind("F6", function()
    if not game.isInGame() then return end
    net.send("request_gold", {})
end)

-- Сервер сообщил всем, кому выдано золото.
net.on("gold_granted", function(data)
    log.info(("player %d received %d gold"):format(data.player, data.amount))
end)

-- Перехват кнопок самой игры: меню по Esc (состояние EventMenu, см. data/gui/menu.inc/eventmenu.inc).
-- Вернуть true — игра это нажатие не обработает. Для примера блокируем «Сдаться» (tag 107).
ui.hookState("EventMenu", function(element, press, tag)
    if press ~= "c" then return end
    log.info(("game menu button pressed: element=%d tag=%d"):format(element, tag))
    if tag == 107 then
        log.warn("Surrender is blocked by example_mod (see client.lua)")
        return true
    end
end)
