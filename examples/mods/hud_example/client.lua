-- Интерфейс партии на CEF. Страница web/hud.html во весь экран, прозрачная; web.passthrough(true)
-- включает режим HUD: где страница ничего не нарисовала, мышь и клавиатура идут в игру.
--
-- Открываем, когда партия реально пошла (gamestage >= 2): до этого на экране — загрузка.

local opened = false

events.on("game.tick", function()
    if opened or state.get("gMap.gamestage") < 2 then return end
    opened = true
    web.open("hud")
    web.passthrough(true)
    log.info("HUD: страница открыта")
end)

events.on("game.end", function()
    opened = false
    web.passthrough(false)
end)

-- .lua reload посреди партии — открыть заново.
if game.isInGame() then opened = false end
