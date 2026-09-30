# Проверка самого modcheck.py на нарочно сломанном моде.
#
#   python tools/modcheck_test.py
#
# ЗАЧЕМ. Проверка, которая ничего не находит, выглядит ровно как проверка,
# которая работает. Единственный способ отличить — держать мод, где каждая
# ошибка заложена намеренно (tools/api_test/broken_mod), и требовать, чтобы
# каждая была названа. Заодно ловится обратное: лишние находки на ровном месте.
import os
import re
import subprocess
import sys

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BROKEN = os.path.join("tools", "api_test", "broken_mod")

# Что обязано найтись: где (файл:строка или раздел) и кусок текста находки.
EXPECTED = [
    ("client.lua:3",  "unit.spwan"),
    ("client.lua:3",  "unit.spawn"),          # и подсказка про настоящее имя
    ("client.lua:7",  "weather.rain"),
    ("client.lua:10", "units.selceted"),
    ("client.lua:10", "units.selected"),      # подсказка
    ("client.lua:11", "серверный"),           # серверный натив в клиентском файле
    ("client.lua:12", "NoSuchNativeAtAll"),
    ("lib/orphan.lua", "manifest"),           # файл мимо манифеста
        ("manifest.lua",  "lib/missing.lua"),
    ("возвраты",      "GetCurrentMouseWorldCoord"),
    ("web/page.html", "query.scan"),          # страница зовёт api по строке
    ("server.lua:7",  "optional"),            # обещал optional, а меняет мир
    ("server.lua:7",  "world.spawn"),         # и вызов виден даже с фигурной скобкой
]

# Сколько всего находок должно быть: чтобы заметить и лишние срабатывания.
EXPECTED_ERRORS, EXPECTED_WARNINGS = 10, 1


def main():
    r = subprocess.run([sys.executable, os.path.join(ROOT, "tools", "modcheck.py"), BROKEN],
                       cwd=ROOT, capture_output=True, text=True, encoding="utf-8", errors="replace")
    out = r.stdout + r.stderr
    bad = 0

    if r.returncode == 0:
        print("ПРОВАЛ: modcheck вернул 0 на заведомо сломанном моде")
        bad += 1

    for where, text in EXPECTED:
        if not any(where in line and text in line for line in out.splitlines()):
            print("ПРОВАЛ: не найдено — %s: %s" % (where, text))
            bad += 1

    m = re.search(r"(\d+) ошибок, (\d+) предупреждений", out)
    if not m:
        print("ПРОВАЛ: modcheck не напечатал итог")
        bad += 1
    elif (int(m.group(1)), int(m.group(2))) != (EXPECTED_ERRORS, EXPECTED_WARNINGS):
        print("ПРОВАЛ: ждали %d ошибок и %d предупреждений, получили %s и %s. "
              "Если находка настоящая — поправьте числа в modcheck_test.py"
              % (EXPECTED_ERRORS, EXPECTED_WARNINGS, m.group(1), m.group(2)))
        bad += 1

    if bad:
        print("\n--- что напечатал modcheck ---")
        print(out.strip())
        return 1
    print("modcheck: все %d заложенных ошибок найдены" % len(EXPECTED))
    return 0


if __name__ == "__main__":
    sys.exit(main())
