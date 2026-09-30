# Мост «страница -> Lua»: то, что построил toLua, должно компилироваться Lua.
#
#   python tools/bridge_test.py
#
# ЗАЧЕМ. game.api('terrain.paint', x, z, { size = 3 }) со страницы превращается
# в текст Lua функцией toLua — она живёт JS-строкой внутри core/WebUi.cpp. Ни
# один тест туда не заглядывал, и там годами лежала ошибка: строки пишутся
# длинными скобками ([[текст]]), а ключ таблицы оборачивался ещё одной парой
# скобок — получалось [[[ключ]]], и Lua читал это как длинную строку, спотыкаясь
# о лишнюю ']'. То есть ЛЮБАЯ таблица со строковыми ключами, отправленная
# страницей, не компилировалась. Нашлось это только когда вкладка «Мир» первой
# начала такие таблицы слать, и выглядело как поломка вкладки.
#
# Проверка сквозная и без заглушек: настоящий toLua вынимается из WebUi.cpp,
# исполняется node, а его вывод скармливается настоящему lua.exe.
import json
import os
import re
import subprocess
import sys

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WEBUI = os.path.join(ROOT, "Modloader For Cossacks 3", "core", "WebUi.cpp")
LUA = os.path.join(ROOT, "tools", "api_test", "lua.exe")

# Что отправляют страницы. Ключи здесь не выдуманные: так зовёт api вкладка
# «Мир» (builtin/devtools), так же выглядят вызовы из любого мода.
CASES = [
    ("число", 42),
    ("дробное", -113.82987976074),
    ("строка", "grass"),
    ("правда", True),
    ("ничего", None),
    ("список", [1, 2, 3]),
    ("кисть рельефа", {"delta": 1, "mb": 3}),
    ("кисть воды", {"water": 1, "size": 3}),
    ("кисть текстуры", {"tile": "grass", "size": 3}),
    ("вложенная таблица", {"opts": {"level": 2}, "name": "озеро"}),
    ("ключ не-имя", {"1a": 5, "с пробелом": 6, "русский": 7}),
    ("строка с квадратными скобками", "a]]b"),
    ("пустая таблица", {}),
    ("пустой список", []),
]


def to_lua_source():
    """Настоящая функция toLua из WebUi.cpp — не копия."""
    text = open(WEBUI, encoding="utf-8", errors="replace").read()
    start = text.index("function toLua(v)")
    end = text.index("\n}", start) + 2
    return text[start:end]


def main():
    if not os.path.isfile(LUA):
        print("нет tools/api_test/lua.exe — проверять нечем")
        return 1
    # node нужен, чтобы исполнить настоящий toLua. Его может не быть на чужой
    # машине — тогда честнее пропустить проверку, чем красить гейт в красный
    # из-за отсутствующего инструмента.
    try:
        subprocess.run(["node", "--version"], capture_output=True, check=True)
    except (OSError, subprocess.CalledProcessError):
        print("node не найден — проверка моста пропущена (установите Node.js)")
        return 0

    # Значения вшиваем в сам скрипт: у node -e аргументы командной строки
    # нумеруются иначе, чем у обычного файла, и это уже съело один заход.
    js = (to_lua_source()
          + "\nconst cases = " + json.dumps([v for _, v in CASES]) + ";\n"
          + "console.log(JSON.stringify(cases.map(toLua)));\n")
    node = subprocess.run(["node", "-e", js],
                          capture_output=True, text=True, encoding="utf-8", errors="replace")
    if node.returncode != 0:
        print("node не смог исполнить toLua из WebUi.cpp:\n" + node.stderr.strip())
        return 1
    produced = json.loads(node.stdout)

    bad = 0
    for (title, value), lua_text in zip(CASES, produced):
        # Так этот текст и попадает в игру: api_call(имя, аргументы...),
        # и LuaHost::EvalJson компилирует его как "return <код>".
        code = "return api_call([[test]], %s)" % lua_text
        check = subprocess.run([LUA, "-e", "assert(load(%s))" % lua_repr(code)],
                               capture_output=True, text=True, encoding="utf-8", errors="replace")
        if check.returncode != 0:
            print("ПРОВАЛ: %s -> %s" % (title, lua_text.replace("\n", "\\n")))
            print("        " + (check.stderr or check.stdout).strip().splitlines()[-1])
            bad += 1

    if bad:
        print("\nне компилируется: %d из %d" % (bad, len(CASES)))
        return 1
    print("мост страница->Lua: все %d видов значений компилируются" % len(CASES))
    return 0


def lua_repr(text):
    """Строка Lua в длинных скобках — внутри нашего текста кавычки не экранируются."""
    eq = ""
    while "]" + eq + "]" in text:
        eq += "="
    return "[" + eq + "[\n" + text + "]" + eq + "]"


if __name__ == "__main__":
    sys.exit(main())
