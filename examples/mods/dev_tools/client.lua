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

-- F10 в партии — замер: чтение юнитов из памяти (objects) против Pascal (state.get) на тех же юнитах.
input.bind("F10", function()
    if not game.isInGame() then return end
    local list = objects.list()
    local units = {}
    local t0 = os.clock()
    for _, h in ipairs(list) do
        local o = objects.read(h)            -- nil для деревьев, камней, ресурсов
        if o and not o.bdead then units[#units + 1] = h end
    end
    local fastAll = os.clock() - t0
    local n = math.min(#units, 20)
    t0 = os.clock()
    for i = 1, n do objects.get(units[i], "hp") end
    local fastOne = (os.clock() - t0) / math.max(n, 1)
    t0 = os.clock()
    for i = 1, n do state.get(string.format("obj(%d).hp", units[i])) end
    local slowOne = (os.clock() - t0) / math.max(n, 1)
    log.info(string.format("objects [%s]: %d объектов на карте, %d живых юнитов/зданий, обход всех — %.1f мс. " ..
        "Одно поле юнита: память %.4f мс, Pascal %.3f мс (в %.0f раз медленнее)", objects.status(), #list, #units,
        fastAll * 1000, fastOne * 1000, slowOne * 1000, slowOne / math.max(fastOne, 1e-9)))
end)
