-- manifest.lua — паспорт мода. Модлоадер читает его первым и грузит ТОЛЬКО перечисленные здесь файлы.
return {
    id = "menu_mod",

    name = "Custom Main Menu",
    version = "1.0.0",
    author = "Illia",
    description = "Своё главное меню: родное игра не строит, весь экран рисует Lua.",

    enabled = true,

    -- Только клиент: интерфейс — дело каждого компьютера и на ход партии не влияет.
    client = "client.lua",

    -- "optional" — другим игрокам этот мод не нужен, контрольная сумма лобби не меняется.
    multiplayer = "optional",

    -- Папка assets повторяет расположение файлов в игре и подменяет их:
    --   assets/data/hud/textures/ui/mainmenu_art.bmp — фон главного меню (из backround.jpg)
    --   assets/data/hud/textures/ui/logo_small.bmp   — логотип (из Cossacks4.png)
    -- Текстуры игра читает один раз при запуске, поэтому нужен запуск через Cossacks3Launcher.exe.
    -- Пересобрать BMP из своей картинки: tools/make_menu_art.py
}
