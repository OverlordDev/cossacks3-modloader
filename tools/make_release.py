# Архив для раздачи тестерам: всё, что кладётся в папку игры, одной распаковкой.
#
#   python tools/make_release.py [версия] [--game "C:/.../Cossacks 3"]
#
# Берёт собранный Release (x86), CEF из папки игры (ставится tools/install_cef.py), api/, builtin/,
# примеры модов. Примеры кладутся ВЫКЛЮЧЕННЫМИ (modstate.txt): многие из них меняют партию, и с ними
# хост выгонял бы из комнаты игроков без модлоадера. Включаются в меню Insert.
import argparse
import datetime
import os
import sys
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_GAME = r"C:\Program Files (x86)\Steam\steamapps\common\Cossacks 3"

BINARIES = [
    "Cossacks3Launcher.exe",
    "Cossacks3Loader.dll",
    "Modloader For Cossacks 3.dll",
    "Modloader For Cossacks 3.pdb",  # имена функций в отчётах о сбоях
    "Cossacks3Cef.exe",
]
# Тестовые и отладочные моды для разработки модлоадера — игрокам не нужны.
SKIP_EXAMPLES = {"event_test", "format_probe", "new_unit_test"}
DOCS = ["MODDING.md", "AI_MODDING_REFERENCE.md", "DOCUMENTATION.md", "MODEL_FORMATS.md"]

README = """Cossacks 3 Modloader {version}

УСТАНОВКА
1. Распакуйте архив в папку игры (там, где cossacks.exe), с заменой.
   Steam: ПКМ по игре -> Управление -> Просмотреть локальные файлы.
2. Запускайте игру через Cossacks3Launcher.exe (не через Steam и не cossacks.exe).
   Steam при этом должен быть запущен.

ЧТО ВНУТРИ
- В игре клавиша Insert — меню модлоадера: список модов, включение/выключение.
  Изменения модов с файлами/нациями/патчами вступают в силу после перезапуска игры.
- Примеры модов лежат в modloader/mods и по умолчанию ВЫКЛЮЧЕНЫ.
- Встроенный детектор рассинхронов: в сетевой игре, если у хоста тоже стоит модлоадер,
  каждые 5 с игрового времени сверяет мир у всех. При расхождении в консоли будет
  красное сообщение "РАССИНХРОН" — пришлите его разработчику.

СЕТЕВАЯ ИГРА
- Без включённых модов, меняющих партию, можно играть с игроками без модлоадера.
- Если у хоста включены такие моды, игроков без них (или без модлоадера) в комнату не пустит.

ЕСЛИ ЧТО-ТО СЛОМАЛОСЬ
Пришлите разработчику:
- modloader/modloader.log
- содержимое modloader/crashes (если игра вылетела)
- что делали перед ошибкой.

УДАЛЕНИЕ
Удалите Cossacks3Launcher.exe, Cossacks3Loader.dll, "Modloader For Cossacks 3.dll/.pdb",
Cossacks3Cef.exe, папки cef и modloader. Файлы игры модлоадер не меняет.
"""


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("version", nargs="?", default=datetime.date.today().strftime("%Y.%m.%d"))
    ap.add_argument("--game", default=DEFAULT_GAME, help="папка игры, откуда взять cef/")
    args = ap.parse_args()

    release = os.path.join(ROOT, "Release")
    cef = os.path.join(args.game, "cef")
    missing = [b for b in BINARIES if not os.path.isfile(os.path.join(release, b))]
    if missing:
        sys.exit("нет собранных файлов (Release, x86): " + ", ".join(missing))
    if not os.path.isfile(os.path.join(cef, "libcef.dll")):
        sys.exit("нет CEF в " + cef + " — сначала tools/install_cef.py")

    os.makedirs(os.path.join(ROOT, "dist"), exist_ok=True)
    out = os.path.join(ROOT, "dist", "Cossacks3Modloader-%s.zip" % args.version)
    count = 0

    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        def add(src, dst):
            nonlocal count
            z.write(src, dst)
            count += 1

        def add_tree(src, dst, skip_dirs=()):
            for base, dirs, files in os.walk(src):
                dirs[:] = [d for d in dirs if d not in skip_dirs and d != "__pycache__"]
                for f in files:
                    p = os.path.join(base, f)
                    add(p, os.path.join(dst, os.path.relpath(p, src)))

        for b in BINARIES:
            add(os.path.join(release, b), b)
        add_tree(cef, "cef")
        add_tree(os.path.join(ROOT, "api"), "modloader/api")
        add_tree(os.path.join(ROOT, "builtin"), "modloader/builtin")

        examples = os.path.join(ROOT, "examples", "mods")
        shipped = []
        for name in sorted(os.listdir(examples)):
            if name in SKIP_EXAMPLES or not os.path.isdir(os.path.join(examples, name)):
                continue
            add_tree(os.path.join(examples, name), "modloader/mods/" + name)
            shipped.append(name)
        state = "# Cossacks 3 Modloader: mod on/off overrides (id=1 / id=0). Managed by the in-game menu.\n"
        state += "".join("%s=0\n" % n for n in shipped)
        z.writestr("modloader/modstate.txt", state)

        for d in DOCS:
            if os.path.isfile(os.path.join(ROOT, d)):
                add(os.path.join(ROOT, d), "modloader/docs/" + d)
        z.writestr("README_MODLOADER.txt", README.format(version=args.version).replace("\n", "\r\n"))

    print("%s: %d файлов, %.1f МБ" % (out, count + 2, os.path.getsize(out) / 1e6))
    print("примеры (выключены):", ", ".join(shipped))


if __name__ == "__main__":
    main()
