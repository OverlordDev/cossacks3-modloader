# Проверка мода до запуска игры.
#
#   python tools/modcheck.py examples/mods/my_mod
#   python tools/modcheck.py examples/mods/*            # сразу все
#
# ЗАЧЕМ. Мод, написанный по документации, обычно запускается и молчит: Lua не
# ругается на units.spwan (это просто nil), events.on принимает любую строку, а
# native.CreateFileStream на клиенте падает только в тот момент, когда до него
# дойдёт дело. Мод iron_frontier был написан целиком и не работал ни в одной
# своей части — и ни одна проверка этого не показывала, потому что проверок не
# было. Здесь они.
#
# Что проверяется:
#   manifest.lua   — читается настоящим Lua и сверяется с правилами загрузчика
#                    (core/LuaHost.cpp, ReadManifest): id, точки входа, файлы
#   синтаксис      — каждый .lua мода грузится Lua, а не разбирается регулярками
#   события        — имена в events.on сверяются с api/59_events.lua
#   api            — units.spwan: модуль знакомый, функции нет
#   нативы         — имени нет в каталоге, либо это серверный натив в клиентском файле
#   возвраты       — сколько значений берут (tools/check_returns.py)
#   Pascal         — вставки для game.exec (tools/check_pascal.py)
#
# Чего НЕ проверяется (чтобы не создавать ложного спокойствия): что мод делает
# осмысленные вещи, что координаты в клетках, что здание умеет то, что от него
# хотят. Это ловится только запуском.
import argparse
import glob
import os
import re
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from luareturns import functions as lua_functions

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LUA = os.path.join(ROOT, "tools", "api_test", "lua.exe")
HELPER = os.path.join(ROOT, "tools", "modcheck_helper.lua")
CATALOG = os.path.join(ROOT, "api", "57_native_catalog.lua")

ERROR, WARN = "ошибка", "внимание"


class Finding:
    def __init__(self, level, where, text):
        self.level, self.where, self.text = level, where, text

    def __str__(self):
        return "  %-9s %s  %s" % (self.level, self.where, self.text)


# ─── строки и комментарии ───────────────────────────────────────────────────
# Имена функций и событий ищутся по тексту, поэтому закомментированный пример из
# документации не должен считаться вызовом. Вырезаем комментарии, сохраняя длину
# строк: так номера строк остаются настоящими.
def strip_comments(text, keep_strings=True):
    """keep_strings=False гасит и содержимое строк.

    Имена событий живут в строках, поэтому по умолчанию строки сохраняются. А вот
    вызовы искать в строках нельзя: в тексте "onTick запустится в game.tick (...)"
    нет никакого вызова game.tick, и ругаться на него — ложная тревога.
    """
    out = []
    i, n = 0, len(text)
    while i < n:
        if text.startswith("--[[", i):
            end = text.find("]]", i)
            end = n if end < 0 else end + 2
            out.append(re.sub(r"[^\n]", " ", text[i:end]))
            i = end
        elif text.startswith("--", i):
            end = text.find("\n", i)
            end = n if end < 0 else end
            out.append(" " * (end - i))
            i = end
        elif text[i] in "\"'":
            quote, j = text[i], i + 1
            while j < n and text[j] != quote:
                j += 2 if text[j] == "\\" else 1
            piece = text[i:min(j + 1, n)]
            out.append(piece if keep_strings else re.sub(r"[^\n]", " ", piece))
            i = min(j + 1, n)
        else:
            out.append(text[i])
            i += 1
    return "".join(out)


def line_of(text, pos):
    return text.count("\n", 0, pos) + 1


def nearest(name, known, limit=None):
    """Ближайшее по написанию имя — или None, если ничего похожего нет."""
    def dist(a, b):
        prev = list(range(len(b) + 1))
        for i, ca in enumerate(a, 1):
            cur = [i]
            for j, cb in enumerate(b, 1):
                cur.append(min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (ca != cb)))
            prev = cur
        return prev[-1]

    # Две правки — это ещё опечатка: перестановка букв (cuont вместо count)
    # стоит ровно две. Дальше подсказка чаще уводит, чем помогает.
    limit = limit if limit is not None else max(2, len(name) // 4)
    best, cost = None, limit + 1
    for k in sorted(known):        # сортировка — чтобы подсказка не зависела от порядка обхода
        d = dist(name, k)
        if d < cost:
            best, cost = k, d
    return best


# ─── что вообще есть в api ──────────────────────────────────────────────────
def api_surface():
    """модуль -> множество его функций, по файлам api/*.lua."""
    surface = {}
    for path in sorted(glob.glob(os.path.join(ROOT, "api", "*.lua"))):
        text = open(path, encoding="utf-8").read()
        names = [f.name for f in lua_functions(path)]
        # function m.f() ловит парсер; присваивания — нет. Их бывает несколько в
        # строке: screens.onButton, screens.onAnyButton, screens.replace = ...
        for m in re.finditer(r"^\s*(\w+\.\w+(?:\s*,\s*\w+\.\w+)*)\s*=[^=]", strip_comments(text), re.M):
            names += [n.strip() for n in m.group(1).split(",")]
        for name in names:
            if "." not in name:
                continue
            mod, fn = name.split(".", 1)
            if "." in fn:                 # m.sub.f — вложенное, в таблицу модуля не кладём
                continue
            surface.setdefault(mod, set()).add(fn)
    return surface


def engine_surface():
    """Таблицы, которые делает не api/*.lua, а сам модлоадер: game, log, events...

    Разбор идёт по тому, как их собирает core/LuaHost.cpp: lua_newtable, потом
    SetFunc/SetPlain на каждое имя, потом lua_setfield с именем таблицы. Без
    этого game.isInGame выглядел бы "отсутствующим в api" — а он есть, просто
    живёт в C++.
    """
    text = open(os.path.join(ROOT, "Modloader For Cossacks 3", "core", "LuaHost.cpp"),
                encoding="utf-8", errors="replace").read()
    surface, pending, opened, prev, stack = {}, [], [], "", []
    for line in text.splitlines():
        if "lua_newtable(" in line:
            # Вложенная таблица (например метатаблица для __index) не должна
            # съедать имена внешней: откладываем их и забираем обратно.
            stack.append(pending)
            pending, opened = [], []
            prev = line
            continue
        if "lua_setmetatable(" in line and stack:
            pending, opened = stack.pop(), []
            prev = line
            continue
        m = re.search(r'(?:SetFunc|SetPlain)\(\s*"(\w+)"', line)
        if m:
            pending.append(m.group(1))
            prev = line
            continue
        m = re.search(r'lua_getfield\(L, -1, "(\w+)"\)', line)
        if m:                                   # дописываем в уже готовую таблицу
            opened.append(m.group(1))
            prev = line
            continue
        m = re.search(r'lua_setfield\(L, -2, "(\w+)"\)', line)
        if m and pending:
            # Отличаем game.dev (обычное поле: перед ним lua_push*) от закрытия
            # таблицы (lua_setfield(L, -2, "game") сразу после набора функций).
            # Без этого game теряется целиком: её закрывают поля side и dev.
            if re.search(r"lua_push(?!cclosure)", prev):
                pending.append(m.group(1))
            else:
                surface.setdefault(m.group(1), set()).update(pending)
                pending, opened = (stack.pop() if stack else []), []
            prev = line
            continue
        if "lua_pop(" in line and pending and opened:
            surface.setdefault(opened[-1], set()).update(pending)
            pending, opened = [], []
        if line.strip():
            prev = line

    # Вторая половина api живёт прямо в LuaHost.cpp: kPrelude — это кусок Lua,
    # вшитый в C++ строкой (game.isInGame, game.playerIndexOf, player...).
    # В C++ строка не начинается с "function x.y(", так что спутать не с чем.
    for m in re.finditer(r"^function (\w+)\.(\w+)\s*\(", text, re.M):
        surface.setdefault(m.group(1), set()).add(m.group(2))

    # Таблица, у которой нашлась одна запись, скорее всего разобрана неверно:
    # судить по ней о чужих опечатках нельзя.
    return {k: v for k, v in surface.items() if len(v) > 1}


def natives():
    """имя натива -> сторона ("client"/"server")."""
    text = open(CATALOG, encoding="utf-8").read()
    return {m.group(1): m.group(2)
            for m in re.finditer(r'\["(\w+)"\]\s*=\s*\{\s*"[^"]*",\s*"[^"]*",\s*"(\w+)"', text)}


# ─── Lua-помощник ───────────────────────────────────────────────────────────
def lua(mode, *args):
    r = subprocess.run([LUA, HELPER, ROOT, mode, *args], capture_output=True,
                       text=True, encoding="utf-8", errors="replace")
    rows = []
    for line in r.stdout.splitlines():
        if "\t" in line:
            k, v = line.split("\t", 1)
            rows.append((k, v))
    if r.returncode != 0 and not rows:
        rows.append(("error", (r.stderr or "lua.exe не запустился").strip()))
    return rows


# ─── манифест ───────────────────────────────────────────────────────────────
def check_manifest(mod, found):
    path = os.path.join(mod, "manifest.lua")
    where = "manifest.lua"
    if not os.path.isfile(path):
        found.append(Finding(ERROR, where, "файла нет — без него мод не загрузится"))
        return {}, []

    fields, files, requires = {}, [], []
    for key, value in lua("manifest", path):
        if key == "error":
            found.append(Finding(ERROR, where, "не читается: " + value))
            return {}, []
        if key == "badtype":
            found.append(Finding(ERROR, where, value))
        elif key == "file":
            files.append(value)
        elif key == "requires":
            requires.append(value)
        elif key != "permission":
            fields[key] = value

    mod_id = fields.get("id", "")
    if not mod_id:
        found.append(Finding(ERROR, where, "нет id — загрузчик откажется от мода"))
    elif not re.fullmatch(r"\w+", mod_id, re.A):
        found.append(Finding(ERROR, where, "id '%s': только латиница, цифры и _" % mod_id))
    elif mod_id != os.path.basename(mod.rstrip("\\/")):
        found.append(Finding(WARN, where, "id '%s' не совпадает с именем папки '%s' — "
                             "по папке мод искать сложнее" % (mod_id, os.path.basename(mod.rstrip("\\/")))))

    if "entry" in fields:
        found.append(Finding(ERROR, where, "поле entry убрано: пишите client = \"client.lua\" "
                                           "и/или server = \"server.lua\""))
    if "shared" in fields and "server" in fields:
        found.append(Finding(ERROR, where, "или server = \"...\", или shared = \"...\", но не оба"))

    mp = fields.get("multiplayer", "required")
    if mp not in ("required", "optional"):
        found.append(Finding(ERROR, where, "multiplayer = \"%s\": допустимы только "
                                           "\"required\" и \"optional\"" % mp))

    entries = [fields[k] for k in ("client", "server", "shared") if k in fields]
    data = (os.path.isdir(os.path.join(mod, "assets")) or os.path.isdir(os.path.join(mod, "patches"))
            or os.path.isfile(os.path.join(mod, "content.lua")))
    if not entries and not data:
        found.append(Finding(ERROR, where, "нет ни client/server/shared, ни assets/, patches/ "
                                           "или content.lua — загружать нечего"))

    for f in entries + files:
        if not os.path.isfile(os.path.join(mod, f)):
            found.append(Finding(ERROR, where, "файл '%s' указан в манифесте, но его нет" % f))
    for dep in requires:
        found.append(Finding(WARN, where, "нужен мод '%s' — проверьте, что он стоит рядом" % dep))

    return fields, files


# ─── сторона файла ──────────────────────────────────────────────────────────
def sides_of_files(mod, fields, files):
    """файл -> множество сторон, с которых он попадает в игру.

    Нужно для натива: серверный натив в клиентском файле — ошибка времени
    выполнения, и увидеть её заранее можно только зная, откуда файл грузится.
    Связи строятся по require(): что не достижимо ни от одной точки входа,
    считаем общим и про сторону молчим.
    """
    graph = {}
    for f in set(files + [fields[k] for k in ("client", "server", "shared") if k in fields]):
        path = os.path.join(mod, f)
        if not os.path.isfile(path):
            continue
        text = strip_comments(open(path, encoding="utf-8", errors="replace").read())
        graph[f] = [m.group(1) for m in re.finditer(r'require\s*\(?\s*["\']([\w./\\-]+)["\']', text)]

    def key(name):
        name = name.replace("\\", "/")
        for cand in (name, name + ".lua"):
            if cand in graph:
                return cand
        return None

    sides = {}

    def walk(start, side, seen):
        f = key(start)
        if f is None or (f, side) in seen:
            return
        seen.add((f, side))
        sides.setdefault(f, set()).add(side)
        for dep in graph[f]:
            walk(dep, side, seen)

    if "client" in fields:
        walk(fields["client"], "client", set())
    for k in ("server", "shared"):
        if k in fields:
            walk(fields[k], "server", set())
    for f in graph:
        sides.setdefault(f, {"client", "server"})   # ни от кого не достижим — не судим
    return sides


# ─── содержимое файлов ──────────────────────────────────────────────────────
def check_file(mod, rel, side, surface, native_side, found, events):
    path = os.path.join(mod, rel)
    raw = open(path, encoding="utf-8", errors="replace").read()
    text = strip_comments(raw)

    for key, value in lua("syntax", path):
        if key == "error":
            found.append(Finding(ERROR, rel, "не компилируется: " + value))
            return                      # дальше разбирать сломанный файл незачем

    # events.on("...") — имена собираем, проверяем одним запуском на весь мод.
    for m in re.finditer(r'events\.(?:on|off)\s*\(\s*["\']([^"\']+)["\']', text):
        events.append((rel, line_of(text, m.start()), m.group(1)))

    code = strip_comments(raw, keep_strings=False)
    for m in re.finditer(r"(\w+)\.(\w+)\s*\(", code):
        mod_name, fn = m.group(1), m.group(2)
        where = "%s:%d" % (rel, line_of(code, m.start()))

        if mod_name == "native":
            # На таблицу native api кладёт и своё: native.info, native.catalogStats.
            if fn in surface.get("native", ()):
                continue
            if fn not in native_side:
                hint = nearest(fn, native_side)
                found.append(Finding(ERROR, where, "натива native.%s нет в игре%s"
                                     % (fn, "; ближайший — native.%s" % hint if hint else "")))
            elif native_side[fn] == "server" and side == {"client"}:
                found.append(Finding(ERROR, where, "native.%s — серверный, а файл грузится только "
                                     "на клиенте: вызов упадёт" % fn))
            continue

        if mod_name in surface and fn not in surface[mod_name]:
            hint = nearest(fn, surface[mod_name])
            found.append(Finding(ERROR, where, "в api нет %s.%s%s"
                                 % (mod_name, fn, "; ближайшее — %s.%s" % (mod_name, hint) if hint else "")))


def check_pages(mod, surface, found):
    """Страницы CEF зовут api по имени-строке: game.api('query.scan', ...).

    Такой вызов — обычный текст, и переименование функции в api ломает страницу
    молча: кнопка просто перестаёт работать. Проверяем те же имена тем же
    списком, что и вызовы из Lua.
    """
    for path in sorted(glob.glob(os.path.join(mod, "web", "**", "*.html"), recursive=True)):
        rel = os.path.relpath(path, mod).replace("\\", "/")
        text = open(path, encoding="utf-8", errors="replace").read()
        for m in re.finditer(r"""\bapi\(\s*['"]([\w.]+)['"]""", text):
            name = m.group(1)
            if "." not in name:
                continue
            mod_name, fn = name.split(".", 1)
            if fn == "":
                # api('buildings.' + fn, ...) — имя собирается на ходу. Саму
                # функцию проверить нечем, но модуль проверить можно.
                if mod_name not in surface:
                    hint = nearest(mod_name, surface)
                    found.append(Finding(ERROR, "%s:%d" % (rel, text.count("\n", 0, m.start()) + 1),
                                         "страница зовёт api модуля '%s', которого нет%s"
                                         % (mod_name, "; ближайший — " + hint if hint else "")))
                continue
            if mod_name in surface and fn not in surface[mod_name]:
                hint = nearest(fn, surface[mod_name])
                found.append(Finding(ERROR, "%s:%d" % (rel, text.count("\n", 0, m.start()) + 1),
                                     "страница зовёт api '%s', которого нет%s"
                                     % (name, "; ближайшее — %s.%s" % (mod_name, hint) if hint else "")))


def check_events(events, found):
    if not events:
        return
    names = sorted({e[2] for e in events})
    verdict = {}
    for key, value in lua("event", *names):
        if key == "error":
            continue
        name, _, hint = value.partition("\t")
        verdict[name] = (key == "known", hint)
    for rel, line, name in events:
        known, hint = verdict.get(name, (True, ""))
        if not known:
            found.append(Finding(ERROR, "%s:%d" % (rel, line),
                                 "события '%s' не бывает — обработчик никогда не вызовется%s"
                                 % (name, ". " + hint if hint else "")))


# ─── соседние проверки ──────────────────────────────────────────────────────
def run_tool(script, paths, found, title):
    r = subprocess.run([sys.executable, os.path.join(ROOT, "tools", script)] + paths,
                       cwd=ROOT, capture_output=True, text=True, encoding="utf-8", errors="replace")
    if r.returncode == 0:
        return
    for line in (r.stdout + r.stderr).strip().splitlines():
        line = line.strip()
        # Итоговая строка чужой проверки ("найдено расхождений: 1") здесь лишняя:
        # свой итог modcheck печатает сам, а две разные цифры рядом путают.
        if line and not re.match(r"^(найдено|всего|итого)\b", line):
            found.append(Finding(ERROR, title, line))


def check_mod(mod):
    found = []
    fields, files = check_manifest(mod, found)
    surface, native_side = api_surface(), natives()
    for name, members in engine_surface().items():
        surface.setdefault(name, set()).update(members)

    sides = sides_of_files(mod, fields, files) if fields else {}
    lua_files = sorted(f for f in sides if os.path.isfile(os.path.join(mod, f)))
    # Файлы, которых нет в манифесте: загрузчик их не увидит, но написаны они не зря.
    on_disk = sorted(os.path.relpath(p, mod).replace("\\", "/")
                     for p in glob.glob(os.path.join(mod, "**", "*.lua"), recursive=True))
    for f in on_disk:
        if f not in sides and f not in ("manifest.lua", "content.lua"):
            found.append(Finding(WARN, f, "файла нет в manifest.lua files — require его не найдёт"))

    events = []
    for rel in lua_files:
        check_file(mod, rel, sides[rel], surface, native_side, found, events)
    check_events(events, found)
    check_pages(mod, surface, found)

    paths = [os.path.join(mod, f) for f in lua_files]
    if paths:
        run_tool("check_returns.py", paths, found, "возвраты")
        run_tool("check_pascal.py", paths, found, "Pascal")
    return found


def main():
    ap = argparse.ArgumentParser(description="проверка мода до запуска игры")
    ap.add_argument("mods", nargs="+", help="папки модов")
    args = ap.parse_args()

    total = 0
    for pattern in args.mods:
        for mod in sorted(glob.glob(pattern)) or [pattern]:
            if not os.path.isdir(mod):
                continue
            found = check_mod(mod)
            errors = sum(1 for f in found if f.level == ERROR)
            total += errors
            head = os.path.basename(mod.rstrip("\\/"))
            if not found:
                print("%s: чисто" % head)
                continue
            print("%s: %d ошибок, %d предупреждений" % (head, errors, len(found) - errors))
            # По файлу и номеру строки: читать находки удобно в том же порядке,
            # в каком их правят, а не в том, в каком их нашли проверки.
            def order(f):
                m = re.match(r"(.*?):(\d+)$", f.where)
                return (m.group(1) if m else f.where, int(m.group(2)) if m else 0)
            for f in sorted(found, key=order):
                print(f)
            print()
    return 1 if total else 0


if __name__ == "__main__":
    sys.exit(main())
