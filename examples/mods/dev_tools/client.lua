-- ЛКМ в партии — в консоль мировые координаты точки под курсором: их можно сразу подставлять
-- в buildings.build("auscen", x, z) и другие функции.
-- Кнопки мыши в input.bind: "LMB", "RMB", "MMB" (и с модификаторами: "Ctrl+LMB").

input.bind("LMB", function()
    if not game.isInGame() then return end
    local x, y, z = native.GetCurrentMouseWorldCoord()
    log.info(string.format("клик: x = %.2f, z = %.2f  (высота %.2f)   buildings.build(\"...\", %.2f, %.2f)", x, z, y, x, z))
end)

-- Приказы игрока (ПКМ, атака точки, патруль...). Вернуть true — приказ отменится; для проверки:
-- DEV_BLOCK_ORDERS = true в консоли, и юниты перестанут слушаться.
DEV_BLOCK_ORDERS = DEV_BLOCK_ORDERS or false
events.on("player.order", function(_, order)
    log.info(string.format("приказ: %s  цель=%d  x=%.1f z=%.1f  группа=%d%s", order.kind, order.target,
        order.x, order.z, order.group, DEV_BLOCK_ORDERS and "  -> ОТМЕНЁН" or ""))
    return DEV_BLOCK_ORDERS
end)
