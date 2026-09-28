# Проверка того, СКОЛЬКО значений берут у нативов движка и у функций api/*.lua.
#
#   python tools/check_returns.py            # проверить всё
#   python tools/check_returns.py файл.lua   # только указанные файлы
#
# ЗАЧЕМ. Нативы возвращают в Lua сначала результат функции, потом значения
# var-параметров по порядку объявления (LuaHost.cpp: сперва result, затем outs).
# Поэтому `procedure GetCurrentMouseWorldCoord(var arayx, arayy, arayz: Float)`
# отдаёт ТРИ значения: x, высоту, z.
#
# Если взять из них два, Lua не скажет ни слова, а во вторую переменную попадёт
# не то, что ожидалось. Именно так в моде iron_frontier писалось
#
#     local ok, wx, wz = pcall(native.GetCurrentMouseWorldCoord)
#
# и в wz оказывалась ВЫСОТА РЕЛЬЕФА: все снаряды падали на линию z ~ 0. Ни один
# стенд этого не видел, потому что с точки зрения Lua код безупречен.
#
# Арность берётся из api/57_native_catalog.lua — это выгрузка настоящих подписей
# из exe, то есть источник тот же, из которого работает сам вызов.
import glob
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from luareturns import functions as lua_functions

# Вывод не должен зависеть от кодовой страницы консоли: в русской Windows это
# cp1251, и строка с тире или "ё" роняла бы скрипт на print.
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CATALOG = os.path.join(ROOT, "api", "57_native_catalog.lua")

# Где ищем вызовы. Стенды тоже: там заглушки натравливают на код, и разойтись
# они не должны.
SCAN = ["api/*.lua", "builtin/*/*.lua", "examples/mods/*/*.lua",
        "examples/mods/*/*/*.lua", "tools/api_test/*.lua"]


def arities():
    """name -> сколько значений отдаёт native.name, и его подпись."""
    out = {}
    text = open(CATALOG, encoding="utf-8").read()
    # ["Имя"] = { "0x...", "подпись", ... }
    for m in re.finditer(r'\["(\w+)"\]\s*=\s*\{\s*"[^"]*",\s*"([^"]*)"', text):
        name, sig = m.group(1), m.group(2)
        n = 1 if sig.lstrip().startswith("function") else 0
        params = sig[sig.find("(") + 1:sig.rfind(")")] if "(" in sig else ""
        for group in params.split(";"):
            group = group.strip()
            if not re.match(r"(var|out)\s", group):
                continue
            # "var x, y, z: Float" — три значения, не одно.
            names = group.split(":", 1)[0]
            names = re.sub(r"^(var|out)\s+", "", names)
            n += len([p for p in names.split(",") if p.strip()])
        out[name] = (n, sig)
    return out


def api_arities():
    """<модуль>.<имя> -> сколько значений отдаёт, если это известно точно и их 2+.

    Проверять есть смысл только такие: если функция отдаёт одно значение или
    сколько-то неизвестное (хвостовой вызов), ошибиться в приёме нечем.
    """
    out = {}
    for path in sorted(glob.glob(os.path.join(ROOT, "api", "*.lua"))):
        for f in lua_functions(path):
            n = f.fixed
            if n is not None and n >= 2:
                out[f.name] = (n, "api/" + os.path.basename(path) + ":" + str(f.line))
    return out


# Приёмник значений: `local a, b = native.X(` или `local ok, a, b = pcall(native.X`
CALL = re.compile(
    r"""(?P<decl>local\s+)?(?P<vars>[A-Za-z_]\w*(?:\s*,\s*[A-Za-z_]\w*)*)\s*=\s*"""
    r"""(?P<rhs>(?P<pcall>pcall\s*\(\s*)?(?P<mod>native|[a-z]\w*)\.(?P<name>\w+).*)$""")


def single_expression(rhs):
    """Справа ровно ОДНО выражение?

    `mapW, mapH = native.GetMapWidth(), native.GetMapHeight()` — два вызова, и
    каждый отдаёт в свою переменную по одному значению; про арность тут говорить
    нечего. Считать такую строку ошибкой было бы ложной тревогой (и было).
    """
    depth = 0
    quote = None
    for ch in rhs:
        if quote:
            if ch == quote:
                quote = None
            continue
        if ch in "\"'":
            quote = ch
        elif ch in "([{":
            depth += 1
        elif ch in ")]}":
            depth -= 1
        elif ch == "," and depth == 0:
            return False
    return True


def check(paths, arity, api):
    findings = []
    for path in paths:
        rel = os.path.relpath(path, ROOT).replace("\\", "/")
        for i, line in enumerate(open(path, encoding="utf-8", errors="replace"), 1):
            code = line.split("--", 1)[0]
            for m in CALL.finditer(code):
                mod, name = m.group("mod"), m.group("name")
                if mod == "native":
                    if name not in arity:
                        continue                  # неизвестный натив — не наше дело
                    n, sig = arity[name]
                    what = "native." + name
                else:
                    full = mod + "." + name
                    if full not in api:
                        continue                  # не функция api с арностью 2+
                    n, where = api[full]
                    sig = "объявлена в " + where
                    what = full
                if not single_expression(m.group("rhs")):
                    continue                      # справа несколько выражений
                names = [v.strip() for v in m.group("vars").split(",") if v.strip()]
                got = len(names)
                # У pcall первое значение — «не бросило ли», оно не от натива.
                if m.group("pcall"):
                    got -= 1
                if got == n:
                    continue
                if got > n:
                    findings.append((rel, i, what, got, n, sig,
                                     "лишние переменные всегда получат nil"))
                elif got >= 2 and "_" not in names:
                    # Берут несколько значений, но не все: вторая и дальше уедут
                    # не туда. Ровно баги с курсором мыши и с world.pos.
                    #
                    # `_` среди переменных — признак того, что автор знает про
                    # позиции и пропускает значение намеренно: `local _, y =
                    # world.pos(h)` берёт именно высоту и это правильный код
                    # (примеры в api_stress_test). Такое не трогаем.
                    findings.append((rel, i, what, got, n, sig,
                                     "взяты не все значения — во вторую и дальше попадёт не то"))
                # got == 1 при n > 1 — законно: осознанно берут первое.
    return findings


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("-")]
    arity = arities()
    api = api_arities()
    if args:
        paths = [os.path.abspath(a) for a in args]
    else:
        paths = []
        for pattern in SCAN:
            paths += glob.glob(os.path.join(ROOT, pattern))
    paths = [p for p in sorted(set(paths)) if os.path.isfile(p)]

    findings = check(paths, arity, api)
    if not findings:
        print("ok: значения читаются правильно (%d натива, %d функций api с арностью 2+, %d файлов)"
              % (len(arity), len(api), len(paths)))
        return 0

    for rel, line, what, got, n, sig, why in findings:
        print("%s:%d: %s отдаёт %d значени(я), взято %d — %s" % (rel, line, what, n, got, why))
        print("    %s" % sig)
    print("\nнайдено расхождений: %d" % len(findings))
    return 1


if __name__ == "__main__":
    sys.exit(main())
