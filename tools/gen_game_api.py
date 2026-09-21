# Схема состояния игры для Lua-API модлоадера.
#
#   python tools/gen_game_api.py "C:/.../Cossacks 3"
#
# Скрипты игры сами описывают все свои структуры и глобальные переменные в
# data/scripts/lib/classes.script:
#
#   type TMapPlayer = class
#      name : String;
#      team : Integer;
#      ...
#   end;
#   global gMap : TMap;
#
# Вторая часть типов — в data/scripts/dmscript.global, в формате движка:
#
#   TCountry : struct.begin
#      sid = String
#      fixedproduce = TCountryFixedProduce[gc_country_maxfixedproduce]
#   struct.end
#   gCountry = TCountry[gc_MaxCountryCount]
#
# Оттуда — страны (что строят здания, улучшения), объект на карте (TObj), заказы (TOrder).
#
# Отсюда генерируются:
#   api/00_schema.lua   — таблица GAME_SCHEMA: типы, их поля, глобальные переменные
#   GAME_STATE.md       — справочник по тому же, чтобы не открывать скрипты игры
#
# Руками эти файлы не править: после патча игры просто перезапустить скрипт.
import os
import re
import sys

SCALARS = {"Integer": "int", "Float": "float", "String": "string", "Boolean": "bool"}

RE_CLASS = re.compile(r"^type\s+(\w+)\s*=\s*class\b")
RE_FIELD = re.compile(r"^\s*([A-Za-z_]\w*(?:\s*,\s*[A-Za-z_]\w*)*)\s*:\s*([^;]+);")
RE_METHOD = re.compile(r"^(\s*)(?:class\s+)?(function|procedure|constructor|destructor)\b", re.I)
RE_GLOBAL = re.compile(r"^global\s+(\w+)\s*:\s*([^;]+);")
RE_CONST = re.compile(r"^\s*(gc_\w+)\s*=\s*(-?\d+)\s*;")
RE_ARRAY = re.compile(r"^array\s*\[\s*([^\]]+?)\s*\.\.\s*([^\]]+?)\s*\]\s*of\s+(.+)$", re.I)


def strip_comment(line):
    return line.split("//", 1)[0].rstrip()


def read_consts(scripts_dir):
    consts = {}
    for root, _, names in os.walk(scripts_dir):
        for name in names:
            if not name.endswith((".script", ".global", ".inc")):
                continue
            with open(os.path.join(root, name), encoding="latin-1") as f:
                for line in f:
                    m = RE_CONST.match(line)
                    if m:
                        consts.setdefault(m.group(1), int(m.group(2)))
    return consts


def evaluate(bound, consts):
    """'gc_MaxPlayerCount-1' -> 11. None, если выражение не разобрать."""
    expr = bound.strip()
    expr = re.sub(r"\b(gc_\w+)\b", lambda m: str(consts[m.group(1)]) if m.group(1) in consts else m.group(0), expr)
    if not re.fullmatch(r"[\d\s+\-*()]+", expr):
        return None
    try:
        return int(eval(expr, {"__builtins__": {}}))
    except Exception:
        return None


def parse_type(text, consts):
    """Тип поля -> описание: {'type': 'int'} / {'type': 'TMap'} / {'array': [lo, hi], 'of': {...}}."""
    text = text.strip()
    m = RE_ARRAY.match(text)
    if m:
        return {"array": [evaluate(m.group(1), consts), evaluate(m.group(2), consts)],
                "of": parse_type(m.group(3), consts)}
    return {"type": SCALARS.get(text, text)}


def parse_classes(path, consts):
    classes, globals_ = {}, {}
    with open(path, encoding="latin-1") as f:
        lines = f.read().split("\n")

    i = 0
    while i < len(lines):
        line = strip_comment(lines[i])
        g = RE_GLOBAL.match(line)
        if g:
            globals_[g.group(1)] = parse_type(g.group(2), consts)
            i += 1
            continue

        c = RE_CLASS.match(line)
        if not c:
            i += 1
            continue

        name = c.group(1)
        fields = []
        i += 1
        while i < len(lines):
            raw = lines[i]
            line = strip_comment(raw)
            if line == "end;":  # конец класса — строго с первой колонки
                break

            m = RE_METHOD.match(line)
            if m:
                # Реализация метода прямо в классе: пропускаем до его end; на том же отступе.
                indent = m.group(1)
                j = i + 1
                while j < len(lines) and not strip_comment(lines[j]).strip():
                    j += 1
                nxt = strip_comment(lines[j]) if j < len(lines) else ""
                if nxt.startswith(indent) and nxt.strip() in ("begin", "var", "const") or nxt.strip().startswith("var "):
                    j2 = j
                    while j2 < len(lines) and strip_comment(lines[j2]) != indent + "end;":
                        j2 += 1
                    i = j2 + 1
                else:
                    i += 1
                continue

            stripped = line.strip()
            if (not stripped or stripped.startswith(("{", "const ", "private", "protected", "public",
                                                     "published", "property "))):
                i += 1
                continue

            f = RE_FIELD.match(line)
            if f:
                t = parse_type(f.group(2), consts)
                for field in (x.strip() for x in f.group(1).split(",")):
                    fields.append({"name": field, **t})
            i += 1

        classes[name] = fields
        i += 1
    return classes, globals_


RE_STRUCT = re.compile(r"^\s*(\w+)\s*:\s*struct\.begin")
RE_STRUCT_FIELD = re.compile(r"^\s*(\w+)\s*=\s*(\w+)((?:\[[^\]]+\])*)\s*$")
DMS_SCALARS = {"Integer": "int", "Float": "float", "String": "string", "Boolean": "bool",
               "Pointer": "int", "SmallInt": "int", "Word": "int", "Byte": "int"}


def dms_type(base, dims, consts):
    """'TCountry', '[gc_A][gc_B]' -> вложенные массивы с нуля до N-1."""
    node = {"type": DMS_SCALARS.get(base, base)}
    for dim in reversed(re.findall(r"\[([^\]]+)\]", dims)):
        n = evaluate(dim, consts)
        node = {"array": [0, n - 1 if n is not None else None], "of": node}
    return node


def parse_dmscript(path, consts):
    """Структуры и глобальные переменные из dmscript.global."""
    classes, globals_ = {}, {}
    current = None
    with open(path, encoding="latin-1") as f:
        for raw in f:
            line = strip_comment(raw)
            if not line.strip():
                continue
            m = RE_STRUCT.match(line)
            if m:
                current = m.group(1)
                classes[current] = []
                continue
            if line.strip() == "struct.end":
                current = None
                continue
            m = RE_STRUCT_FIELD.match(line)
            # Тип — имя типа (TCountry) или простой; "gc_x = 12" — константа, не переменная.
            if not m or not (m.group(2) in DMS_SCALARS or m.group(2).startswith("T")):
                continue
            node = dms_type(m.group(2), m.group(3), consts)
            if current:
                classes[current].append({"name": m.group(1), **node})
            elif m.group(1).startswith("g"):
                globals_[m.group(1)] = node
    return classes, globals_


# ---------- вывод ----------

def lua_value(v, indent=""):
    if v is None:
        return "nil"
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, int):
        return str(v)
    if isinstance(v, str):
        return '"' + v.replace("\\", "\\\\").replace('"', '\\"') + '"'
    if isinstance(v, list):
        return "{ " + ", ".join(lua_value(x) for x in v) + " }"
    if isinstance(v, dict):
        return "{ " + ", ".join("%s = %s" % (k, lua_value(x)) for k, x in v.items()) + " }"
    raise TypeError(v)


def type_text(t):
    if "array" in t:
        lo, hi = t["array"]
        return "array[%s..%s] of %s" % (lo if lo is not None else "?", hi if hi is not None else "?", type_text(t["of"]))
    return t["type"]


def write_schema(path, classes, globals_):
    out = ["-- Сгенерировано tools/gen_game_api.py из data/scripts/lib/classes.script. Не править руками.",
           "GAME_SCHEMA = {", "  types = {"]
    for name in sorted(classes):
        out.append("    %s = {" % name)
        for f in classes[name]:
            out.append("      " + lua_value(f) + ",")
        out.append("    },")
    out.append("  },")
    out.append("  globals = {")
    for name in sorted(globals_):
        out.append("    %s = %s," % (name, lua_value(globals_[name])))
    out.append("  },")
    out.append("}")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(out) + "\n")


def write_doc(path, classes, globals_):
    # Справочник: глобальные переменные с простыми типами полей — то, что реально нужно модам.
    out = ["# Состояние игры", "",
           "Сгенерировано `tools/gen_game_api.py` из `data/scripts/lib/classes.script`. Не править руками.", "",
           "Любое поле читается одинаково из Lua и из страниц:", "",
           "```lua", "state.get('gProfile.sndmaster')       -- 0.75",
           "state.read('gMap.players[0]')          -- вся запись таблицей",
           "state.set('gProfile.sndmaster', 0.5)   -- только сервер/консоль",
           "G.gMap.settings.gen.mapsize            -- то же, через точку", "```", "",
           "## Глобальные переменные", ""]
    for name in sorted(globals_):
        out.append("- `%s` — %s" % (name, type_text(globals_[name])))
    out += ["", "## Типы", ""]
    for name in sorted(classes):
        fields = classes[name]
        if not fields:
            continue
        out.append("### %s" % name)
        out.append("")
        out.append("| поле | тип |")
        out.append("|---|---|")
        for f in fields:
            out.append("| `%s` | %s |" % (f["name"], type_text(f)))
        out.append("")
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(out) + "\n")


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    game = sys.argv[1] if len(sys.argv) > 1 else "."
    scripts = os.path.join(game, "data", "scripts")
    here = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

    consts = read_consts(scripts)
    classes, globals_ = parse_classes(os.path.join(scripts, "lib", "classes.script"), consts)
    dms_classes, dms_globals = parse_dmscript(os.path.join(scripts, "dmscript.global"), consts)
    for name, fields in dms_classes.items():
        classes.setdefault(name, fields)  # classes.script главнее: там свежее описание
    for name, node in dms_globals.items():
        globals_.setdefault(name, node)

    write_schema(os.path.join(here, "api", "00_schema.lua"), classes, globals_)
    write_doc(os.path.join(here, "GAME_STATE.md"), classes, globals_)

    fields = sum(len(v) for v in classes.values())
    print("типов: %d, полей: %d, глобальных: %d, констант: %d" % (len(classes), fields, len(globals_), len(consts)))


if __name__ == "__main__":
    main()
