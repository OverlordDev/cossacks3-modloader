#pragma once

#include <string>
#include <vector>

// Подмена файлов игры файлами из модов.
//
// Мод кладёт свои файлы в папку assets, повторяя расположение в игре:
//   modloader/mods/<мод>/assets/data/shaders/tone/tone.frag
// заменяет
//   <игра>/data/shaders/tone/tone.frag
//
// Работает через перехват файловых функций движка (TOSWApplicationFileIO): мы подменяем имя файла
// перед открытием, сами файлы игры не трогаются. Ставить нужно как можно раньше — шейдеры, текстуры
// и конфиги читаются один раз при старте, поэтому смысл в этом есть только с автозагрузкой
// (Cossacks3Launcher.exe), а при инжекте в идущую игру большая часть файлов уже прочитана.
namespace Assets
{
    bool Install();

    struct Override
    {
        std::string mod;  // папка мода
        std::string game; // путь внутри игры, например data\shaders\tone\tone.frag
        std::string file; // полный путь к файлу мода
    };

    const std::vector<Override>& List();

    void Print(); // в консоль: что и каким модом подменено
}
