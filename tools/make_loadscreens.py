# Родной экран загрузки партии — картинками из папки LoadScreen мода.
#
#   python tools/make_loadscreens.py "C:/.../Cossacks 3/modloader/mods/menu_mod" "C:/.../Cossacks 3"
#   python tools/make_materials.py  "C:/.../Cossacks 3" "C:/.../Cossacks 3/modloader/mods/menu_mod"
#
# Пока карта догружается, игра показывает свой экран загрузки: его рисует движок, не скрипты
# (data/hud/progressbar/bar.load.game.*.cfg), и страница браузера поверх него не видна.
# Картинок у движка восемь — материалы progressbar1..8 (1920x1024), он берёт случайную.
# Подменяем их своими: override.progressbarN.tga -> make_materials.py перепишет материалы.
import os
import sys

from PIL import Image

W, H = 1920, 1024


def main():
    mod = sys.argv[1].rstrip("/\\")
    src = os.path.join(mod, "LoadScreen")
    dst = os.path.join(mod, "assets", "data", "hud", "textures", "mods", os.path.basename(mod))
    os.makedirs(dst, exist_ok=True)
    names = sorted(n for n in os.listdir(src) if n.lower().endswith((".png", ".jpg", ".jpeg", ".webp")))
    if not names:
        sys.exit("no images in " + src)
    for i in range(8):  # картинок меньше восьми — повторяем по кругу
        img = Image.open(os.path.join(src, names[i % len(names)])).convert("RGB")
        scale = max(W / img.width, H / img.height)  # заполнить кадр, лишнее обрезать по центру
        img = img.resize((round(img.width * scale), round(img.height * scale)), Image.LANCZOS)
        x, y = (img.width - W) // 2, (img.height - H) // 2
        img.crop((x, y, x + W, y + H)).save(os.path.join(dst, "override.progressbar%d.tga" % (i + 1)))
        print("progressbar%d <- %s" % (i + 1, names[i % len(names)]))


if __name__ == "__main__":
    main()


# Плашку с цитатой поверх картинки (paper_background) прячем: цитаты уже на самих картинках.
# Конфиги экрана загрузки кладём в assets мода — модлоадер подменит ими файлы игры.
def hide_quotes(game, mod):
    import glob
    hud = os.path.join(game, "data", "hud")
    files = [os.path.join(hud, "bar.load.game.cfg")] + glob.glob(os.path.join(hud, "progressbar", "bar.load.game.*.cfg"))
    for path in files:
        with open(path, encoding="latin-1", newline="") as f:
            text = f.read()
        at = text.find("name = paper_background")
        vis = text.find("Visible = True", at) if at >= 0 else -1
        if vis < 0:
            continue
        text = text[:vis] + "Visible = False" + text[vis + len("Visible = True"):]
        out = os.path.join(mod, "assets", os.path.relpath(path, game))
        os.makedirs(os.path.dirname(out), exist_ok=True)
        with open(out, "w", encoding="latin-1", newline="") as f:
            f.write(text)
    print("quote panel hidden in %d config(s)" % len(files))


if __name__ == "__main__" and len(sys.argv) > 2:
    hide_quotes(sys.argv[2], sys.argv[1].rstrip("/\\"))
