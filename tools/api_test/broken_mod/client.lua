local helper = require("lib/helper")

events.on("unit.spwan", function(event, h, base)   -- ошибка: опечатка в имени события
    log.info("появился " .. base)
end)

events.on("weather.rain", function() end)          -- ошибка: такого события нет вовсе

events.on("game.start", function()
    local n = units.selceted()                     -- ошибка: в api нет units.selceted
    native.ParserCreateGameObject(0)                -- ошибка: серверный натив в клиентском файле
    native.NoSuchNativeAtAll()                     -- ошибка: натива нет в игре
    log.info("выделено: " .. tostring(n) .. " " .. tostring(helper.value))
end)
