-- Пример API abilities: F6 наносит area damage вокруг выбранного юнита.
return {
    id = "ability_example",
    name = "Ability Example",
    version = "0.1.0",
    author = "Illia",
    description = "Пример синхронной способности с area damage",
    enabled = false,
    server = "server.lua",
    client = "client.lua",
    multiplayer = "required",
}
