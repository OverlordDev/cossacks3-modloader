-- Тест: родная миникарта спрятана, вместо неё — своя на CEF (пока — картинка самой игры).
return {
    id = "minimap_test",
    name = "Minimap Test",
    version = "0.1.0",
    author = "Illia",
    description = "Прячет миникарту игры и показывает её картинку на странице CEF. Ctrl+M — способ скрытия родной.",
    enabled = true,
    client = "client.lua",
    multiplayer = "optional", -- только картинка у этого игрока
}
