# Проверка: функции в Pascal-коде, который api/*.lua шлёт в игру, должны существовать в диалекте игры
# (скрипты data/scripts + нативы GAME_API.md). Запуск из корня репозитория: python tools/check_pascal.py
# Ловит то, что офлайн-тесты не видят: api/38_orders падал на Pos/Copy/Delete, которых в диалекте нет.
import re, glob, os

G = r"C:/Program Files (x86)/Steam/steamapps/common/Cossacks 3/data/scripts"
known = set()
for root, _, files in os.walk(G):
    for f in files:
        try:
            t = open(os.path.join(root, f), encoding="latin1").read()
        except OSError:
            continue
        known |= set(re.findall(r"\b([A-Za-z_]\w*)\s*\(", t))
for line in open("GAME_API.md", encoding="utf-8"):
    m = re.search(r"`(?:function|procedure)\s+(\w+)", line)
    if m:
        known.add(m.group(1))
# Сравнение с учётом регистра: нативы и функции игры пишутся всегда одинаково, а "pos(" — это переменная.
keywords = {"if", "while", "for", "not", "and", "or", "then", "begin", "end", "var", "tobj", "torder", "tplayer",
            "tsquad", "tobjbase", "tobjprop", "pointer", "integer", "float", "string", "boolean", "ml_ret", "exit",
            "array", "of", "do", "to", "downto", "case", "else", "result", "ml_arg", "div", "mod", "in"}

found = False
STR = r'"(?:[^"\\]|\\.)*"' + "|" + r"'(?:[^'\\]|\\.)*'"
import sys
for path in sys.argv[1:] or sorted(glob.glob("api/*.lua")):
    src = open(path, encoding="utf-8").read()
    frags = re.findall(r"\[\[(.*?)\]\]", src, re.S)
    frags += re.findall(r"game\.(?:exec|eval\w*|run)\(\s*(" + STR + ")", src)
    frags += re.findall(r"(?:string\.format|format)\(\s*(" + STR + ")", src)
    text = re.sub(r"//[^\n]*", "", " ".join(frags))
    bad = sorted({n for n in re.findall(r"\b([A-Za-z_]\w*)\s*\(", text)
                  if (n[0].isupper() or n[0] == "_") and n.lower() not in keywords and n not in known})
    if bad:
        found = True
        print(path, bad)
if not found:
    print("ok: all functions used by api/*.lua Pascal code exist in the game dialect")
