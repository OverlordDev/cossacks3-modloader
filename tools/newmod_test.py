# Заготовка мода (tools/newmod.py) должна проходить tools/modcheck.py.
#
#   python tools/newmod_test.py
#
# ЗАЧЕМ. Заготовка — это первое, что человек увидит и скопирует. Если api
# переименует функцию или событие сменит имя, заготовка станет учить неправде
# молча. Здесь она создаётся во временной папке и проверяется теми же правилами,
# что и любой другой мод.
import os
import shutil
import subprocess
import sys
import tempfile

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def run(script, *args):
    return subprocess.run([sys.executable, os.path.join(ROOT, "tools", script), *args],
                          cwd=ROOT, capture_output=True, text=True, encoding="utf-8", errors="replace")


def main():
    tmp = tempfile.mkdtemp(prefix="newmod_")
    try:
        made = run("newmod.py", "check_template", tmp)
        if made.returncode != 0:
            print("ПРОВАЛ: заготовка не создалась\n" + made.stdout + made.stderr)
            return 1

        mod = os.path.join(tmp, "check_template")
        for name in ("manifest.lua", "client.lua", "server.lua", "README.md"):
            if not os.path.isfile(os.path.join(mod, name)):
                print("ПРОВАЛ: в заготовке нет %s" % name)
                return 1

        checked = run("modcheck.py", mod)
        if checked.returncode != 0 or "чисто" not in checked.stdout:
            print("ПРОВАЛ: заготовка не проходит modcheck — значит, она учит неправде\n"
                  + checked.stdout + checked.stderr)
            return 1

        # Повторный вызов в ту же папку не должен затирать чужую работу.
        again = run("newmod.py", "check_template", tmp)
        if again.returncode == 0:
            print("ПРОВАЛ: newmod согласился перезаписать существующую папку")
            return 1
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    print("заготовка мода: создаётся и проходит modcheck")
    return 0


if __name__ == "__main__":
    sys.exit(main())
