events.on("game.start", function()
    -- GetCurrentMouseWorldCoord отдаёт три значения (x, высота, z), а не два:
    -- ошибка возвратов, её ловит check_returns.py.
    local x, z = native.GetCurrentMouseWorldCoord()
    log.info(tostring(x) .. " " .. tostring(z))
    -- ошибка: правка мира в моде, объявленном optional
    world.spawn{ race = "ukr", base = "tree", x = 0, z = 0 }
end)
