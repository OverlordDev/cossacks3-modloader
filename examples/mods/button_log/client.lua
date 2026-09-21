-- Каждое нажатие любой кнопки любого экрана — в консоль. Игра после этого делает своё как обычно.
--
-- Это шаблон для замены экранов. Все экраны и имена кнопок — GAME_SCREENS.md.
--
-- Перехватить одну кнопку и сделать своё вместо игры:
--   screens.onButton("MainMenu", function(button)
--       if button == "Credits" then log.info("свои титры"); return true end  -- true = игра не обрабатывает
--   end)
--
-- Заменить весь экран своей страницей (CEF):
--   screens.replace("Campaign", function() web.open("campaign") end)
--
-- Нажать кнопку экрана из кода (как игрок):  screens.press("MainMenu", "Settings")
-- Открыть экран:                               screens.open("Settings")

screens.onAnyButton(function(screen, button, tag)
    log.info(string.format("кнопка: %s.%s (тэг %d)", screen, button, tag))
end)

log.info("button_log: слушаю кнопки " .. #screens.list() .. " экранов")
