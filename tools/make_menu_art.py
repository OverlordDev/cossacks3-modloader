# Своя картинка -> текстура интерфейса Cossacks 3.
#
# Движок берёт картинки меню из BMP в data/hud/textures/ui/, а data/hud/hud.mat задаёт, какой кусок
# текстуры показывать. Размер файла и куска зашиты в .mat, поэтому свой файл должен быть ровно такого
# же размера, а картинка — лежать в левом верхнем углу в границах куска.
#
#   python tools/make_menu_art.py photo.jpg .../mainmenu_art.bmp
#   python tools/make_menu_art.py logo.png .../logo_small.bmp --preset logo_small
#   python tools/make_menu_art.py art.jpg  .../progressbar1.bmp --preset progressbar
#
# Пресет по имени файла определяется сам, --preset нужен только если имя другое.
import argparse
import os
import struct

from PIL import Image


class Preset:
    def __init__(self, canvas, region, bits, fit):
        self.canvas = canvas  # размер файла
        self.region = region  # видимая область из hud.mat
        self.bits = bits      # 24 или 32 (32 — с альфой)
        self.fit = fit        # "cover" — заполнить с обрезкой, "contain" — вписать целиком


PRESETS = {
    # Фон главного меню: заполняем целиком, лишнее по краям режем.
    "mainmenu_art": Preset((2048, 1024), (1674, 1024), 24, "cover"),
    # Экраны загрузки progressbar1..8.
    "progressbar":  Preset((2048, 1024), (2048, 1024), 24, "cover"),
    # Логотип: вписываем целиком, поля прозрачные.
    "logo_small":   Preset((512, 256), (468, 193), 32, "contain"),
    # Картинка блока новостей.
    "news":         Preset((512, 256), (512, 256), 32, "contain"),
}


def guess_preset(target):
    name = os.path.splitext(os.path.basename(target))[0].lower()
    if name in PRESETS:
        return name
    if name.startswith("progressbar"):
        return "progressbar"
    return None


def resize_rgba(src, size):
    """Масштабирование с premultiplied alpha: иначе по краям вылезает цвет из прозрачных пикселей."""
    if src.mode != "RGBA":
        return src.resize(size, Image.LANCZOS)
    r, g, b, a = src.split()
    premul = Image.merge("RGBA", (
        Image.composite(r, Image.new("L", src.size, 0), a),
        Image.composite(g, Image.new("L", src.size, 0), a),
        Image.composite(b, Image.new("L", src.size, 0), a),
        a,
    )).resize(size, Image.LANCZOS)
    pr, pg, pb, pa = premul.split()
    px, ax = premul.load(), pa.load()
    out = Image.new("RGBA", size)
    op = out.load()
    for y in range(size[1]):
        for x in range(size[0]):
            cr, cg, cb, ca = px[x, y]
            if ca == 0:
                op[x, y] = (0, 0, 0, 0)
            else:
                op[x, y] = (min(255, cr * 255 // ca), min(255, cg * 255 // ca), min(255, cb * 255 // ca), ca)
    return out


def place(src, region, fit):
    """Картинка размера region: cover — обрезать по центру, contain — вписать с прозрачными полями."""
    want = region[0] / region[1]
    have = src.width / src.height
    if fit == "cover":
        if have > want:
            side = int(src.height * want)
            src = src.crop(((src.width - side) // 2, 0, (src.width - side) // 2 + side, src.height))
        elif have < want:
            side = int(src.width / want)
            src = src.crop((0, (src.height - side) // 2, src.width, (src.height - side) // 2 + side))
        return resize_rgba(src, region)

    # Вписываем: сначала отрезаем прозрачные поля исходника, иначе картинка окажется крошечной.
    if src.mode == "RGBA":
        box = src.getbbox()
        if box:
            src = src.crop(box)
    scale = min(region[0] / src.width, region[1] / src.height)
    inner = resize_rgba(src, (max(1, round(src.width * scale)), max(1, round(src.height * scale))))
    out = Image.new("RGBA", region, (0, 0, 0, 0))
    out.paste(inner, ((region[0] - inner.width) // 2, (region[1] - inner.height) // 2))
    return out


def save_bmp32(image, path):
    """BMP 32 бита BGRA, снизу вверх — ровно то, что игра держит в logo_small.bmp."""
    w, h = image.size
    rows = []
    px = image.load()
    for y in range(h - 1, -1, -1):
        row = bytearray()
        for x in range(w):
            r, g, b, a = px[x, y]
            row += bytes((b, g, r, a))
        rows.append(bytes(row))
    data = b"".join(rows)
    header = struct.pack("<2sIHHI", b"BM", 54 + len(data), 0, 0, 54)
    header += struct.pack("<IiiHHIIiiII", 40, w, h, 1, 32, 0, len(data), 2834, 2834, 0, 0)
    with open(path, "wb") as f:
        f.write(header + data)


def main():
    p = argparse.ArgumentParser()
    p.add_argument("source")
    p.add_argument("target")
    p.add_argument("--preset", choices=sorted(PRESETS), help="по умолчанию — по имени целевого файла")
    args = p.parse_args()

    name = args.preset or guess_preset(args.target)
    if not name:
        p.error("не понял, какой это материал — укажите --preset (%s)" % ", ".join(sorted(PRESETS)))
    preset = PRESETS[name]

    src = Image.open(args.source)
    src = src.convert("RGBA" if preset.bits == 32 else "RGB")
    inner = place(src, preset.region, preset.fit)

    os.makedirs(os.path.dirname(os.path.abspath(args.target)), exist_ok=True)
    if preset.bits == 32:
        out = Image.new("RGBA", preset.canvas, (0, 0, 0, 0))
        out.paste(inner, (0, 0))
        save_bmp32(out, args.target)
    else:
        out = Image.new("RGB", preset.canvas, (0, 0, 0))
        out.paste(inner, (0, 0))
        out.save(args.target, "BMP")

    print("%s -> %s (%s): файл %dx%d, %d бит, картинка в области %dx%d" %
          (args.source, args.target, name, preset.canvas[0], preset.canvas[1], preset.bits,
           preset.region[0], preset.region[1]))


if __name__ == "__main__":
    main()
