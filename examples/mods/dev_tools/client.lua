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

-- F10 в партии — замер: чтение всех юнитов из памяти (objects) против старого пути через Pascal.
input.bind("F10", function()
    if not game.isInGame() then return end
    local list = objects.list()
    local t0 = os.clock()
    local alive = 0
    for _, h in ipairs(list) do
        local o = objects.read(h)
        if o and not o.bdead then alive = alive + 1 end
    end
    local fast = os.clock() - t0
    local mode = objects.status()
    local n = math.min(#list, 20)
    t0 = os.clock()
    for i = 1, n do state.get(string.format("obj(%d).hp", list[i])) end
    local slow = (os.clock() - t0) / math.max(n, 1)
    log.info(string.format("objects [%s]: %d объектов (%d живых) прочитаны целиком за %.1f мс; " ..
        "через Pascal одно поле — %.2f мс (всё бы заняло ~%.0f мс)", mode, #list, alive, fast * 1000, slow * 1000,
        slow * 1000 * #list * 60))
end)
