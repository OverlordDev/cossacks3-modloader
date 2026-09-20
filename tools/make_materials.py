# Свои картинки интерфейса отдельными файлами, без правки атласов игры.
#
#   python tools/make_materials.py "C:/.../Cossacks 3" modloader/mods/menu_mod
#
# Как это работает. Игра знает картинки по именам материалов ('btn.large'), а что такое материал —
# написано в data/hud/hud.mat. Почти все материалы там вырезают прямоугольник из большого атласа,
# но часть (misc.blank, loaddummy) ссылается на отдельный файл целиком — и так тоже можно.
#
# Скрипт берёт hud.mat игры, дописывает в конец по секции на каждую картинку мода и кладёт результат
# в assets/ мода. Атласы игры остаются нетронутыми, а размер своей картинки — любой.
#
# Куда класть картинки:
#   <мод>/assets/data/hud/textures/mods/<id мода>/btn.tga  ->  материал '<id мода>.btn'
#   .../btn.normal.tga, btn.hover.tga, btn.pressed.tga     ->  набор состояний для кнопки
#
# Имя файла = имя материала. Кнопке достаточно одного материала: если '<имя>.normal' не найден,
# игра берёт '<имя>' на все состояния (см. _gui_CreateButton в data/scripts/lib/gui.script).
import os
import sys

BS = chr(92)
IMAGE_TYPES = (".tga", ".bmp", ".dds", ".jpg", ".png")
MARKER = "// mod materials added by tools/make_materials.py"

SECTION = "\n".join([
    "",
    "section.begin {refurl=.@data@hud@ref@refmat.mat}".replace("@", BS),
    "   Material.Name = %s",
    "   Material.Texture.image = %s",
    "   Material.Texture.magfilter = maLinear",
    "   Material.Texture.minfilter = miLinear",
    "section.end",
])


def collect(mod_dir, mod_id):
    """Картинки мода -> [(имя материала, путь для игры)].

    Обычные картинки дают свои материалы '<id мода>.<имя файла>'. Файлы из подпапки override/
    называются именем УЖЕ СУЩЕСТВУЮЩЕГО материала игры ('btn.medium.normal.tga') и переопределяют
    его: секция мода идёт в hud.mat последней.
    """
    root = os.path.join(mod_dir, "assets", "data", "hud", "textures", "mods", mod_id)
    prefix = BS.join([".", "data", "hud", "textures", "mods", mod_id, ""])
    found = []
    for dirpath, _, names in os.walk(root):
        for name in sorted(names):
            if os.path.splitext(name)[1].lower() not in IMAGE_TYPES:
                continue
            rel = os.path.relpath(os.path.join(dirpath, name), root)
            stem = os.path.splitext(rel)[0].replace(os.sep, ".")
            override = stem.startswith("override.")
            material = stem[len("override."):] if override else mod_id + "." + stem
            found.append((material, prefix + rel.replace(os.sep, BS)))
    return found, root


def main():
    if len(sys.argv) < 3:
        sys.exit("использование: make_materials.py <папка игры> <папка мода>")
    sys.stdout.reconfigure(encoding="utf-8")
    game, mod_dir = sys.argv[1], sys.argv[2].rstrip("/" + BS)
    mod_id = os.path.basename(mod_dir)

    materials, root = collect(mod_dir, mod_id)
    if not materials:
        sys.exit("картинок не найдено: положите их в %s" % root)

    source = os.path.join(game, "data", "hud", "hud.mat")
    with open(source, encoding="latin-1") as f:
        base = f.read()
    # Берём именно оригинал игры: иначе секции копятся от запуска к запуску.
    if MARKER in base:
        sys.exit("%s уже содержит секции мода — укажите папку с оригинальной игрой" % source)

    out = [base.rstrip("\r\n"), "", MARKER]
    for material, image in materials:
        out.append(SECTION % (material, image))

    target = os.path.join(mod_dir, "assets", "data", "hud", "hud.mat")
    os.makedirs(os.path.dirname(target), exist_ok=True)
    with open(target, "w", encoding="latin-1", newline="\r\n") as f:
        f.write("\n".join(out) + "\n")

    print("%s: %d материал(ов) мода" % (target, len(materials)))
    for material, image in materials:
        print("   %-32s %s" % (material, image))


if __name__ == "__main__":
    main()
