-- Проверка событий модлоадера: ловит каждое событие и ставит галочку; отчёт — F8 и в конце партии.
return {
    id = "event_test",
    name = "Event Test",
    version = "0.1.0",
    author = "Illia",
    description = "Тест всех событий: F8 — отчёт, что сработало и что нет.",
    enabled = true,
    client = "client.lua",
    multiplayer = "optional",
}
