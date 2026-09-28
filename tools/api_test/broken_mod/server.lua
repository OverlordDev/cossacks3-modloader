events.on("game.start", function()
    -- GetCurrentMouseWorldCoord отдаёт три значения (x, высота, z), а не два:
    -- ошибка возвратов, её ловит check_returns.py.
    local x, z = native.GetCurrentMouseWorldCoord()
    log.info(tostring(x) .. " " .. tostring(z))
end)
