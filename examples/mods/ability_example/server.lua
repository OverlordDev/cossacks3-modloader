-- Сервер принимает только координаты от клиента и сам применяет способность.
-- В реальном моде здесь должны быть проверки дальности, стоимости и права игрока.

abilities.define("airstrike", {
    cooldown = 20,
    damage = 100000, -- тестовый гарантированно смертельный удар
    radius = 10,
    target = "all",
    effect = "cannon",
    ignorePeace = true,
})

events.on("game.start", function()
    log.info("ability_example: F6 по выбранному юниту — пробный авиаудар")
end)

net.on("ability.airstrike", function(data, from)
    if type(data) ~= "table" then return end
    local playerIndex = game.playerIndexOf(from)
    local x, z = tonumber(data.x), tonumber(data.z)
    if not x or not z or math.abs(x) > 10000 or math.abs(z) > 10000 then
        log.warn("ability_example: отклонены плохие координаты от игрока " .. tostring(playerIndex))
        return
    end

    local ok, hit, wait = abilities.fire("airstrike", x, z, { owner = playerIndex })
    if not ok then
        net.broadcast("ability.result", { player = playerIndex, ok = false, wait = wait })
        return
    end
    log.info(("ability_example: airstrike player=%d x=%.2f z=%.2f hit=%d"):format(playerIndex, x, z, hit))
    net.broadcast("ability.result", { player = playerIndex, ok = true, hit = hit, x = x, z = z })
end)
