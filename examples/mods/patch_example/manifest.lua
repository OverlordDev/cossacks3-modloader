-- Пример патча библиотеки скриптов игры: урон x2 и своя функция. Меняет игру — в мультиплеере
-- должен стоять у всех (multiplayer = "required"). Выключен по умолчанию.
return {
    id = "patch_example",
    name = "Patch Example",
    version = "0.1.0",
    author = "Illia",
    description = "Патч lib/miscext2.script: весь урон x2. Пример формата .patch.",
    enabled = false,
    multiplayer = "required",
}
