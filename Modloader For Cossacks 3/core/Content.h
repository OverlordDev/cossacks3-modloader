#pragma once

#include <filesystem>
#include <functional>
#include <string>
#include <vector>

// Новые нации и типы юнитов одним описанием: mods/<мод>/content.lua.
//
//   nation { sid = "kaz", from = "ukr", name = { ru = "Казахстан", en = "Kazakhstan" } }
//   unit   { sid = "mlserdiuk", from = "serdiuk", nations = { "ukr", "kaz" }, cell = { 1, 1 },
//            base = { maxhp = 500 }, prop = { vision = 900 }, name = { ru = "Сердюк+", en = "Serdiuk+" } }
//   battle { sid = "poltava", from = "battle1", map = "maps/poltava.map", name = { ru = "Полтава" } }
//
// Из описания модлоадер сам строит всё, что нужно игре: патчи скриптов (country.script, unit.script,
// map.script, dmscript.global), списки объектов, .prop, иконки — и подставляет названия в локализацию.
// Файлы игры не меняются. Формат и ограничения — MODDING.md / AI_MODDING_REFERENCE.md.
namespace Content
{
    struct ModDir
    {
        std::string folder;
        std::filesystem::path dir;
    };

    struct Patch { std::string key, mod, text; };   // key — путь в игре ("data\scripts\lib\unit.script")
    struct File  { std::string key, mod, text; };   // сгенерированный файл, которого нет в игре
    struct Link  { std::string key, mod, source; }; // файл мода, отдаваемый движку по пути в игре (карты)

    struct Result
    {
        std::vector<Patch> patches;
        std::vector<File> files;
        std::vector<Link> links;
    };

    // readBase(key) — текущий текст файла игры (с учётом замен из assets и Workshop), "" если нет.
    // listGameDir(key папки) — имена файлов в папке игры.
    Result Generate(const std::vector<ModDir>& mods, const std::function<std::string(const std::string&)>& readBase,
                    const std::function<std::vector<std::string>(const std::string&)>& listGameDir);

    // Перехват локализации: названия из content.lua и названия-по-родителю для новых типов.
    bool InstallLocale();

    void Print(); // .content — что описано модами
}
