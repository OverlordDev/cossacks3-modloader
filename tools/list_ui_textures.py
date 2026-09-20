# Опись картинок интерфейса Cossacks 3: какой материал из какого BMP и каким куском берётся.
#
#   python tools/list_ui_textures.py "C:\...\Cossacks 3" > UI_ASSETS.md
#
# Связь такая: скрипт просит материал по имени ('btn.large'), data/hud/hud.mat говорит, из какой
# текстуры его брать и какой прямоугольник вырезать, data/hud/hud.tex — где лежит сам файл.
# Чтобы заменить картинку, нужен файл ровно того же размера: прямоугольники зашиты в .mat.
import os
import re
import struct
import sys
from collections import defaultdict


def sections(path):
    """Файлы движка — плоские 'ключ = значение' внутри section.begin/section.end."""
    current = {}
    with open(path, encoding="latin-1") as f:
        for line in f:
            line = line.strip()
            if line.startswith("section.begin"):
                current = {}
            elif line.startswith("section.end"):
                yield current
            elif "=" in line:
                key, _, value = line.partition("=")
                current.setdefault(key.strip(), value.strip())


def bmp_info(path):
    try:
        with open(path, "rb") as f:
            d = f.read(32)
        if d[:2] != b"BM":
            return None
        w, h = struct.unpack_from("<ii", d, 18)
        bpp = struct.unpack_from("<H", d, 28)[0]
        return w, h, bpp, os.path.getsize(path)
    except OSError:
        return None


def main():
    sys.stdout.reconfigure(encoding="utf-8")  # чтобы markdown не уехал в кодировку консоли
    game = sys.argv[1] if len(sys.argv) > 1 else "."
    hud = os.path.join(game, "data", "hud")

    # Текстура -> файл на диске.
    files = {}
    for s in sections(os.path.join(hud, "hud.tex")):
        name, image = s.get("LibTextureName"), s.get("image")
        if name and image:
            files[name] = os.path.normpath(os.path.join(game, image.lstrip(". \\/")))

    # Материал -> текстура + вырезаемый прямоугольник.
    by_texture = defaultdict(list)
    for s in sections(os.path.join(hud, "hud.mat")):
        name = s.get("Material.Name") or s.get("name")
        texture = s.get("Material.LibTextureName") or s.get("LibTextureName")
        if not name:
            continue
        if not texture:
            # Часть материалов ссылается на файл напрямую, минуя hud.tex.
            image = s.get("Material.Texture.image") or s.get("image")
            if not image:
                continue
            texture = os.path.splitext(os.path.basename(image))[0]
            files.setdefault(texture, os.path.normpath(os.path.join(game, image.lstrip(". " + chr(92) + "/"))))
        rect = tuple(int(s.get("Material.TextureCoord.Coord" + k, 0)) for k in "XYWH")
        by_texture[texture].append((name, rect))

    print("# Картинки интерфейса Cossacks 3\n")
    print("Сгенерировано `tools/list_ui_textures.py` из `data/hud/hud.tex` и `data/hud/hud.mat`.\n")
    print("Чтобы заменить картинку, положите свой BMP **того же размера и той же разрядности** в")
    print("`modloader/mods/<мод>/assets/data/hud/textures/ui/`. Прямоугольники, которые движок вырезает")
    print("из текстуры, зашиты в `hud.mat` — рисунок должен попадать в них.\n")
    print("Собрать BMP нужного формата из своей картинки: `tools/make_menu_art.py`.\n")
    print("С чего обычно начинают:\n")
    print("| хочу поменять | текстура | размер |")
    print("|---|---|---|")
    print("| фон главного меню | `mainmenu_art.bmp` | 2048x1024, 24 бита |")
    print("| логотип | `logo_small.bmp` | 512x256, 32 бита |")
    print("| экраны загрузки, 8 штук | `progressbar1.bmp` … `progressbar8.bmp` | 2048x1024, 24 бита |")
    print("| кнопки, рамки, свитки | `tex05.bmp` | 2048x2048, 32 бита |")
    print("| окна и диалоги | `dialogs01.bmp` | 2048x2048, 32 бита |")
    print("| иконки команд | `icons.bmp` | 1024x512, 32 бита |")
    print("| иконки юнитов | `iconsunits.bmp` | 1024x512, 24 бита |")
    print()
    print("Атласы (`tex*`, `dialogs*`, `icons*`) держат сотни картинок в одном файле — менять их надо")
    print("целиком, оставляя каждую вещь на своём месте. Списки ниже говорят, что где лежит.\n")

    for texture in sorted(by_texture, key=lambda t: (files.get(t, ""), t)):
        path = files.get(texture)
        info = bmp_info(path) if path else None
        items = sorted(by_texture[texture])
        print("## %s — %d материал(ов)\n" % (texture, len(items)))
        if info:
            w, h, bpp, size = info
            print("`%s` — %dx%d, %d бит, %.1f МБ\n" % (
                os.path.relpath(path, game).replace(os.sep, "/"), w, h, bpp, size / 1048576))
        elif path:
            print("`%s` — файла нет на диске\n" % os.path.relpath(path, game).replace(os.sep, "/"))
        else:
            print("_текстура не описана в hud.tex_\n")

        print("| материал | кусок текстуры (x, y, ширина, высота) |")
        print("|---|---|")
        for name, (x, y, cw, ch) in items:
            print("| `%s` | %d, %d, %d, %d |" % (name, x, y, cw, ch))
        print()


if __name__ == "__main__":
    main()
