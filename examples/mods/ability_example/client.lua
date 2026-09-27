-- F6 берёт мировые координаты под курсором и просит сервер ударить туда.
input.bind("F6", function()
    if not game.isInGame() then return end
    local x, _, z = native.GetCurrentMouseWorldCoord()
    if not x then
        log.warn("ability_example: не удалось получить точку под курсором")
        return
    end
    net.send("ability.airstrike", { x = x, z = z })
end)

net.on("ability.result", function(data)
    if type(data) ~= "table" then return end
    if data.ok then
        log.info(("ability_example: удар игрока %d, целей: %d"):format(data.player, data.hit or 0))
    elseif data.wait then
        log.info(("ability_example: перезарядка ещё %.1f с"):format(data.wait))
    end
end)
