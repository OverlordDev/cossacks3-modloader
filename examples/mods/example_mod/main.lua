-- Точка входа мода (entry в manifest.lua).
local utils = require("utils")

log.info("hello from " .. mod.name .. " " .. mod.version)
log.info("game build: " .. native.GetBuildVersion())

-- События: встраиваемся в состояния интерфейса игры (menu.aix) и подписываемся.
events.hook("DoNewGame")
events.hook("DoCreate")

events.on("gui.DoNewGame", function()
    log.info("new game is being prepared")
end)

events.on("gui.DoCreate", function()
    -- DoCreate срабатывает и в главном меню — там игрока ещё нет
    if not game.isInGame() then return end
    local me = player()
    log.info("interface created, my player index = " .. me.index)
    log.info("my resources: " .. utils.formatResources(me))
end)
