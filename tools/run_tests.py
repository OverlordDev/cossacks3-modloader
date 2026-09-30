# Шлюз: всё, что обязано быть зелёным перед коммитом.
#
#   python tools/run_tests.py                     # проверки модлоадера
#   python tools/run_tests.py --mod examples/mods/iron_frontier
#                                                 # плюс стенды этого мода, если они есть
#
# Игра не нужна: всё гоняется на подставном движке (tools/api_test/fake_game.lua)
# и на lua.exe из tools/api_test.
#
# ЭТОТ ФАЙЛ — ЧАСТЬ ПРАВИЛ, А НЕ ЧАСТЬ ЗАДАЧИ. Кто выполняет задачу, тот не
# правит ни его, ни проверяльщики, которые он зовёт: иначе «зелёный шлюз»
# перестаёт что-либо значить. Именно так вышло с модом iron_frontier — стенд к
# нему писал тот же, кто писал код, заглушки подогнали под код, и всё было
# зелёным при полностью нерабочем моде.
import argparse
import os
import subprocess
import sys

# Вывод не должен зависеть от кодовой страницы консоли: в русской Windows это
# cp1251, и строка с тире или "ё" роняла бы скрипт на print.
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
T = os.path.join(ROOT, "tools", "api_test")
LUA = os.path.join(T, "lua.exe")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--mod", action="append", default=[],
                    help="папка мода: добавить его стенды, если они есть")
    args = ap.parse_args()

    if not os.path.isfile(LUA):
        sys.exit("нет " + LUA)

    # (заголовок, команда, рабочая папка)
    suites = [
        ("Pascal: функции существуют в диалекте игры",
         [sys.executable, os.path.join(ROOT, "tools", "check_pascal.py")], ROOT),
        # Сначала проверяем сам разбор Lua, потом уже то, что на нём построено:
        # если парсер врёт, проверка возвратов зелёная и бессмысленная.
        ("разбор Lua: арность на выверенных примерах",
         [sys.executable, os.path.join(ROOT, "tools", "luareturns.py")], ROOT),
        ("возвраты: берут столько значений, сколько отдают",
         [sys.executable, os.path.join(ROOT, "tools", "check_returns.py")], ROOT),
        # Каталог событий проверяется до стендов: если он разошёлся с core/,
        # модлоадер будет ругаться на настоящие имена событий в чужих модах.
        ("события: каталог совпадает с core/*.cpp",
         [sys.executable, os.path.join(ROOT, "tools", "check_events.py")], ROOT),
        ("api/59_events.lua: опечатки в именах событий",
         [LUA, "events_test.lua", ROOT], T),
        # Сначала modcheck на заведомо сломанном моде, потом уже на настоящих:
        # проверка, которая разучилась находить, тоже печатает "чисто".
        ("modcheck находит заложенные ошибки",
         [sys.executable, os.path.join(ROOT, "tools", "modcheck_test.py")], ROOT),
        ("modcheck: builtin-моды чистые",
         [sys.executable, os.path.join(ROOT, "tools", "modcheck.py"), "builtin/*"], ROOT),
        ("заготовка мода проходит modcheck",
         [sys.executable, os.path.join(ROOT, "tools", "newmod_test.py")], ROOT),
        ("стенд страницы инспектора: заглушки на месте",
         [sys.executable, os.path.join(ROOT, "tools", "api_test", "page_stand", "run.py"), "--check"], ROOT),
        ("мост страница->Lua компилируется",
         [sys.executable, os.path.join(ROOT, "tools", "bridge_test.py")], ROOT),
        ("api/*.lua на подставном движке", [LUA, "run.lua"], T),
        ("api/20_objects.lua: раскладка TObj",
         [LUA, "objects_test.lua", ROOT, "4", "1", "4", "0"], T),
        ("обвязка стенда api_stress_test",
         [LUA, "smoke_ast.lua", os.path.join(ROOT, "api"),
          os.path.join(ROOT, "examples", "mods", "api_stress_test")], T),
    ]

    # Стенды мода подключаются, только если лежат рядом: они не часть модлоадера.
    for mod in args.mod:
        mod = os.path.abspath(os.path.join(ROOT, mod))
        name = os.path.basename(mod.rstrip("\\/"))
        for stand, extra in (("if_smoke.lua", mod),
                             ("artillery_test.lua", os.path.join(mod, "lib")),
                             ("morale_test.lua", os.path.join(mod, "lib"))):
            if os.path.isfile(os.path.join(T, stand)) and os.path.isdir(mod):
                suites.append(("%s: %s" % (name, stand), [LUA, stand, extra], T))

    bad = []
    for title, cmd, cwd in suites:
        r = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True,
                           encoding="utf-8", errors="replace")
        lines = [l for l in (r.stdout or "").strip().splitlines() if l.strip()]
        last = lines[-1] if lines else ((r.stderr or "").strip().splitlines() or [""])[-1]
        print("%-46s %s" % (title, last))
        if r.returncode != 0:
            bad.append((title, r.stdout, r.stderr))

    if not bad:
        print("\nвсе проверки пройдены")
        return 0
    for title, out, err in bad:
        print("\n===== %s =====" % title)
        print(out or "")
        print(err or "")
    print("провалов: %d" % len(bad))
    return 1


if __name__ == "__main__":
    sys.exit(main())
