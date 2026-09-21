-- Тестовый мод: пишет в консоль каждую нажатую кнопку любого экрана игры.
return {
    id = "button_log",
    name = "Button Log",
    version = "1.0.0",
    author = "Illia",
    description = "Лог всех кнопок интерфейса: экран, имя кнопки, тэг. Игра обрабатывает нажатия как обычно.",
    enabled = false,
    client = "client.lua",
    multiplayer = "optional",
}
