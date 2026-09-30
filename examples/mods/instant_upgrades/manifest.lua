-- Порт мода «Instant Upgrades» (автор оригинала — PaFiK): все улучшения в игре мгновенные, цена не меняется.
-- Оригинал — копия целого data/scripts/lib/country.script (4283 строки, ~350 КБ) с временем 1 кадр
-- в сотнях вызовов _country_AddUpgrade. Здесь — то же поведение в одном небольшом скрипте.
-- Меняет правила игры: в сети должен стоять у всех (multiplayer = "required").
return {
    id = "instant_upgrades",
    name = "Instant Upgrades",
    version = "0.1.0",
    author = "port of PaFiK's mod",
    description = "Все улучшения мгновенные (цена прежняя). Порт мода Instant Upgrades на Modloader.",
    enabled = false,
    shared = "shared.lua",
    multiplayer = "required",
}
