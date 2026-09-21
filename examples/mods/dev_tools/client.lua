-- ЛКМ в партии — в консоль мировые координаты точки под курсором: их можно сразу подставлять
-- в buildings.build("auscen", x, z) и другие функции.
-- Кнопки мыши в input.bind: "LMB", "RMB", "MMB" (и с модификаторами: "Ctrl+LMB").

input.bind("LMB", function()
    if not game.isInGame() then return end
    local x, y, z = native.GetCurrentMouseWorldCoord()
    log.info(string.format("клик: x = %.2f, z = %.2f  (высота %.2f)   buildings.build(\"...\", %.2f, %.2f)", x, z, y, x, z))
end)
