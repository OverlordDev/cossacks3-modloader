# Сверка каталога событий (api/59_events.lua) с местами, где события рождаются.
#
#   python tools/check_events.py
#
# ЗАЧЕМ. Каталог нужен, чтобы модлоадер ловил опечатку в events.on. Но каталог,
# который отстал от кода, хуже отсутствующего: он будет ругаться на настоящее имя
# события и молчать о выдуманном. Поэтому имена берутся из C++ и сравниваются в
# обе стороны — лишнее в каталоге такая же ошибка, как пропущенное.
#
# Откуда берутся имена в C++:
#   Events::Emit("game.start")            — прямая отправка
#   'ML:unit.damage|'                     — маркер, который движок пишет в gDbgString
#   objectHooks[] = { ..., "unit", ..., "spawn" }  — имя собирается как kind + "." + event
#
# Имена с переменной частью (gui.<State>, guiscreen.<State>, guistate.<State>)
# в каталоге не перечисляются — они описаны образцами EVENT_PATTERNS.
import os
import re
import sys

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CORE = os.path.join(ROOT, "Modloader For Cossacks 3", "core")
CATALOG = os.path.join(ROOT, "api", "59_events.lua")

# Динамическая часть имени: такие события в каталог не попадают.
DYNAMIC = ("gui.", "guiscreen.", "guistate.")
# Служебные маркеры того же канала gDbgString — это не события.
NOT_EVENTS = {"block", "orig", "ret", ""}


def catalog_names():
    text = open(CATALOG, encoding="utf-8").read()
    body = text[text.index("EVENT_CATALOG = {"):]
    body = body[:body.index("\nEVENT_PATTERNS")]
    return set(re.findall(r'^\s*\["([^"]+)"\]\s*=', body, re.M))


def source_names():
    found = {}

    def add(name, where):
        if name and not name.startswith(DYNAMIC) and name not in NOT_EVENTS:
            found.setdefault(name, where)

    for entry in sorted(os.listdir(CORE)):
        if not entry.endswith((".cpp", ".h")):
            continue
        path = os.path.join(CORE, entry)
        text = open(path, encoding="utf-8", errors="replace").read()
        # Комментарии выкидываем: там имена событий упоминаются в пояснениях.
        code = re.sub(r"//[^\n]*", "", text)
        code = re.sub(r"/\*.*?\*/", "", code, flags=re.S)

        for m in re.finditer(r'Events::Emit\(\s*"([a-z][\w.]*)"', code):
            add(m.group(1), entry)
        for m in re.finditer(r"ML:([a-z][\w.]*)", code):
            add(m.group(1), entry)
        # Таблицы вида { "units\\unit.aix", "unit", "Initial", "spawn" }.
        for m in re.finditer(r"ObjectHook\s+\w+\[\]\s*=\s*\{(.*?)\n\s*\};", code, re.S):
            for row in re.finditer(r'\{\s*"[^"]*"\s*,\s*"(\w+)"\s*,\s*"[^"]*"\s*,\s*"(\w+)"\s*\}', m.group(1)):
                add(row.group(1) + "." + row.group(2), entry)
    return found


def main():
    catalog = catalog_names()
    source = source_names()
    bad = 0

    for name in sorted(set(source) - catalog):
        print("НЕТ В КАТАЛОГЕ: '%s' отправляется из %s, а api/59_events.lua о нём не знает"
              % (name, source[name]))
        bad += 1
    for name in sorted(catalog - set(source)):
        print("ЛИШНЕЕ В КАТАЛОГЕ: '%s' описано в api/59_events.lua, но ничто его не отправляет" % name)
        bad += 1

    if bad:
        print("\nсобытий расходится: %d" % bad)
        return 1
    print("события: %d в каталоге, все найдены в core/ — расхождений нет" % len(catalog))
    return 0


if __name__ == "__main__":
    sys.exit(main())
