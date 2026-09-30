# Сколько значений возвращает каждая функция Lua — разбор с учётом блоков.
#
#   from luareturns import functions
#   for f in functions("api/27_world.lua"): print(f.name, f.arities)
#
# ЗАЧЕМ ОТДЕЛЬНЫЙ МОДУЛЬ, А НЕ РЕГУЛЯРКА. Считать `return` регуляркой нельзя:
# она не знает, где кончается функция, и путает вложенные if/for/function. Слабая
# модель, которой это поручили 2026-09-28, именно так и ошиблась — по её данным
# world.pos не возвращает ничего (а он отдаёт три значения), а abilities.fire не
# имеет return вовсе (а у него их два). Поэтому здесь настоящий проход по
# токенам, а внизу — самопроверка на функциях, чьё поведение выверено по коду.
#
# Что считается: только функции вида `function <модуль>.<имя>(...)`, то есть
# публичная поверхность API. Локальные не нужны.
import re
import sys


class Func:
    def __init__(self, name, line):
        self.name = name
        self.line = line
        self.returns = []      # список: int (столько значений), "tail", 0
        self.doc = ""          # строка документации над функцией

    @property
    def arities(self):
        """Набор разных арностей; "tail" означает «столько же, сколько у вызова»."""
        out = []
        for r in self.returns:
            if r not in out:
                out.append(r)
        return out

    @property
    def fixed(self):
        """Точная арность, если она одна и известна; иначе None."""
        a = self.arities
        if len(a) == 1 and isinstance(a[0], int):
            return a[0]
        return None


# Ключевые слова, открывающие блок, который закрывается end.
#
# `for`/`while` НЕ считаем: у них всегда есть своё `do`, и оно уже посчитано.
# `elseif` тоже не считаем — он не открывает нового блока.
OPEN = {"function", "if", "do"}
CLOSE = {"end"}
STOP = {"end", "else", "elseif", "until", ";"}

TOKEN = re.compile(r"""
      (?P<long>\[(?P<eq>=*)\[)                 # длинная строка [[ ]] или [==[ ]==]
    | (?P<comment>--)
    | (?P<name>[A-Za-z_]\w*)
    | (?P<num>\d[\w.]*)
    | (?P<str>"|')
    | (?P<op>\S)
""", re.X)


def tokens(src):
    """Поток (текст, номер строки) без комментариев; строка — один токен '"'."""
    i, line = 0, 1
    n = len(src)
    while i < n:
        ch = src[i]
        if ch == "\n":
            line += 1
            i += 1
            continue
        if ch.isspace():
            i += 1
            continue
        m = TOKEN.match(src, i)
        if not m:
            i += 1
            continue
        if m.group("comment"):
            # Длинный комментарий --[[ ... ]] или до конца строки.
            lm = re.match(r"--\[(=*)\[", src[i:])
            if lm:
                close = "]" + lm.group(1) + "]"
                end = src.find(close, i)
                end = n if end < 0 else end + len(close)
            else:
                end = src.find("\n", i)
                end = n if end < 0 else end
            line += src.count("\n", i, end)
            i = end
            continue
        if m.group("long"):
            close = "]" + m.group("eq") + "]"
            end = src.find(close, m.end())
            end = n if end < 0 else end + len(close)
            line += src.count("\n", i, end)
            i = end
            yield ('"', line)
            continue
        if m.group("str"):
            q = m.group("str")
            j = m.end()
            while j < n and src[j] != q:
                j += 2 if src[j] == "\\" else 1
            i = j + 1
            yield ('"', line)
            continue
        i = m.end()
        yield (m.group(0), line)


def _arity(expr):
    """Арность по токенам выражения после return: int или "tail"."""
    if not expr:
        return 0
    # Делим по запятым верхнего уровня.
    groups, depth, cur = [], 0, []
    for t in expr:
        if t in "([{":
            depth += 1
        elif t in ")]}":
            depth -= 1
        if t == "," and depth == 0:
            groups.append(cur)
            cur = []
        else:
            cur.append(t)
    groups.append(cur)
    if len(groups) > 1:
        return len(groups)
    g = groups[0]
    # `return (f())` — скобки обрезают до одного значения.
    if g and g[0] == "(":
        return 1
    # Одиночный вызов отдаёт столько же, сколько вызванная функция: заранее не знаем.
    if len(g) > 1 and g[-1] == ")" and "(" in g:
        return "tail"
    return 1


def functions(path):
    src = open(path, encoding="utf-8", errors="replace").read()
    doc_of = _docs(src)
    toks = list(tokens(src))
    out = []
    i = 0
    while i < len(toks):
        t, line = toks[i]
        # function <модуль>.<имя>(
        if t == "function" and i + 4 < len(toks) and toks[i + 2][0] == "." \
                and re.match(r"^[A-Za-z_]\w*$", toks[i + 1][0]) \
                and re.match(r"^[A-Za-z_]\w*$", toks[i + 3][0]):
            f = Func("%s.%s" % (toks[i + 1][0], toks[i + 3][0]), line)
            f.doc = doc_of.get(line, "")
            depth = 1                      # само function
            j = i + 4
            while j < len(toks) and depth > 0:
                w = toks[j][0]
                if w in OPEN:
                    depth += 1
                elif w == "repeat":
                    depth += 1
                elif w in CLOSE or w == "until":
                    depth -= 1
                elif w == "return":
                    expr, k, d2 = [], j + 1, 0
                    while k < len(toks):
                        v = toks[k][0]
                        if v in "([{":
                            d2 += 1
                        elif v in ")]}":
                            d2 -= 1
                        if d2 <= 0 and v in STOP:
                            break
                        expr.append(v)
                        k += 1
                    f.returns.append(_arity(expr))
                    j = k - 1              # STOP-токен обработает внешний цикл
                j += 1
            out.append(f)
            i = j
            continue
        i += 1
    return out


def _docs(src):
    """Номер строки функции -> строка документации над ней.

    В репозитории про возврат пишут двумя способами — "Возврат:" и "Возвращает",
    поэтому ищем оба. Требовать один вариант было ошибкой: так получилось
    завышенное «67% функций без описания».
    """
    lines = src.splitlines()
    out = {}
    for n, line in enumerate(lines, 1):
        if not line.startswith("function "):
            continue
        # Комментарий может занимать несколько строк подряд перед функцией.
        block, k = [], n - 2
        while k >= 0 and lines[k].lstrip().startswith("--"):
            block.insert(0, lines[k].lstrip()[2:].strip())
            k -= 1
        out[n] = " ".join(block)
    return out


def documents_return(doc):
    """Сказано ли в описании, что функция возвращает.

    БЕЗ УЧЁТА РЕГИСТРА: пишут и "Возврат:", и "возвращает x, y, z" со строчной
    (api/23_minimap.lua:71). С учётом регистра проверка врала — у minimap.pos
    возврат описан, а считалось, что нет.
    """
    # Общий корень "возвра": слово "возврат" НЕ является частью слова
    # "возвращает" (после "возвра" идёт "щ", а не "т"), поэтому искать надо
    # именно корень. На этом проверка сначала врала в обе стороны.
    low = doc.lower()
    return ("возвра" in low) or ("returns" in low)


# ─── Самопроверка ────────────────────────────────────────────────────────────
# Ожидания выверены по самому коду (а не по памяти): см. соответствующие файлы.
SELF_TEST = [
    ("api/27_world.lua",    "world.pos",      [3]),        # return x, y, z
    ("api/20_objects.lua",  "objects.pos",    [None, 2]),  # return nil,nil и x,z
    ("api/38_orders.lua",   "orders.move",    []),         # не возвращает ничего
    ("api/21_abilities.lua", "abilities.fire", [3, 2]),    # cooldown-отказ и true,hit
    ("api/34_dbg.lua",      "dbg.ray",        [4]),        # return hit, x, y, z
    ("api/01_state.lua",    "state.get",      ["tail"]),   # три хвостовых вызова
]


def self_test(root):
    import os
    bad = 0
    for rel, name, want in SELF_TEST:
        found = [f for f in functions(os.path.join(root, rel)) if f.name == name]
        if not found:
            print("ПРОВАЛ %s: функция не найдена в %s" % (name, rel))
            bad += 1
            continue
        got = found[0].arities
        expect = [w for w in want if w is not None]
        if sorted(map(str, got)) != sorted(map(str, expect)):
            print("ПРОВАЛ %s: разобрано %s, ожидалось %s" % (name, got, expect))
            bad += 1
        else:
            print("ok     %-16s %s" % (name, got))
    return bad


if __name__ == "__main__":
    import os
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    sys.exit(1 if self_test(root) else 0)
