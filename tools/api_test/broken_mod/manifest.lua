-- Нарочно сломанный мод: на нём проверяется сам modcheck.py.
-- Каждая ошибка здесь должна быть найдена — список ждёт modcheck_test.py.
-- Это НЕ пример для подражания и не рабочий мод.
return {
    id = "broken_mod",
    name = "Сломанный мод",
    version = "0.1.0",
    client = "client.lua",
    server = "server.lua",
    multiplayer = "optional",       -- ошибка: мод меняет мир (см. server.lua)
    files = { "lib/helper.lua", "lib/missing.lua" },  -- ошибка: missing.lua нет
}
