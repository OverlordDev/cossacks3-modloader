#pragma once

#include <string>
#include <vector>

// Модели модов в стандартном формате -> форматы игры. Мододел экспортирует .glb из Blender (встроенный
// экспорт glTF), модлоадер при запуске делает из него то, что понимает движок. Формат игры — MODEL_FORMATS.md.
namespace ModelConvert
{
    struct Stats { int verts = 0, tris = 0, meshes = 0; };

    // .glb (все меши сцены с их трансформациями, в одну модель) -> статичная .osm.
    // Оси: glTF Y вверх и лицом к +Z -> игра Z вверх и лицом к -Y (как было в Blender); UV v переворачивается,
    // обход треугольников — по часовой стрелке, как в игре. image — первая картинка материала (PNG/JPEG), если есть.
    // part — какую часть взять: "" — готовое здание (все верхние объекты, кроме частей ниже),
    // "stage1".."stage4" — стадии стройки, "stage1a".."stage4a" — леса, "death1"/"death2" — руины.
    // Часть = верхний объект сцены с таким именем (в Blender — объект или пустышка-родитель).
    bool GlbToOsm(const std::string& glb, const std::string& part, std::string* osm, std::string* image, Stats* stats,
                  std::string* error);

    // Какие части есть в .glb ("" — готовое здание).
    std::vector<std::string> GlbParts(const std::string& glb);

    // PNG/JPEG/BMP (декодирует Windows) -> DDS DXT5 с мип-уровнями, как текстуры игры.
    // Альфа текстуры в игре — маска цвета игрока (1 — красить). playerColor = false: альфа 0 везде;
    // true: альфа картинки как есть (нет альфы — 0).
    bool ImageToDds(const std::string& image, bool playerColor, std::string* dds, std::string* error);
}
