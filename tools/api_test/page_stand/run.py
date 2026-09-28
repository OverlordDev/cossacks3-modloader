# Стенд страницы инспектора: открыть панель в обычном браузере, без игры.
#
#   python tools/api_test/page_stand/run.py
#
# ЗАЧЕМ. Панель (builtin/devtools/web/devtools.html) в игре запускается только
# целиком: не собралась сборка, не началась партия — и посмотреть на неё нельзя.
# Стенд подменяет мост к модлоадеру (fake_game.js отвечает заготовленными
# данными) и поднимает страницу на localhost, где вкладки можно прокликать.
#
# Стенд НЕ заменяет игру: он показывает разметку и поведение вкладок, а не то,
# что api отдаёт на самом деле. Имена функций api, которые зовёт страница,
# сверяются отдельно и автоматически — tools/modcheck.py.
import http.server
import re
import os
import socketserver
import sys
import webbrowser

# Вывод не должен зависеть от кодовой страницы консоли (в русской Windows cp1251).
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

HERE = os.path.dirname(os.path.abspath(__file__))
# page_stand -> api_test -> tools -> корень репозитория
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
PAGE = os.path.join(ROOT, "builtin", "devtools", "web", "devtools.html")
PORT = 8731


def build():
    text = open(PAGE, encoding="utf-8").read()
    if "<body>" not in text:
        raise SystemExit("в %s нет <body> — стенд собрать не из чего" % PAGE)
    text = text.replace("<body>", '<body>\n<script src="fake_game.js"></script>', 1)
    out = os.path.join(HERE, "stand.html")
    with open(out, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    return out


def check():
    """Подставной мост должен отвечать на всё, что страница у него спрашивает.

    Иначе стенд тихо вырождается: добавили вкладке новый вызов api, открыли
    стенд — а там вместо вкладки красная строка «unknown function», и это
    выглядит как поломка страницы, хотя не хватает всего лишь заглушки.
    """

    page = open(PAGE, encoding="utf-8").read()
    # Комментарии выкидываем: в пояснениях api упоминают примерами
    # (game.api('модуль.функция', ...)), и заглушки для них не нужны.
    page = re.sub(r"<!--.*?-->", "", page, flags=re.S)
    page = re.sub(r"^\s*//[^\n]*", "", page, flags=re.M)
    stub = open(os.path.join(HERE, "fake_game.js"), encoding="utf-8").read()
    known = set(re.findall(r"""^\s*'([\w.]+)':""", stub, re.M))

    missing = []
    for m in re.finditer(r"""\bapi\(\s*['"]([\w.]+)['"]""", page):
        name = m.group(1)
        if name.endswith("."):                       # api('buildings.' + fn, ...)
            if not any(k.startswith(name) for k in known):
                missing.append(name + "*")
        elif name not in known:
            missing.append(name)

    missing = sorted(set(missing))
    if missing:
        print("в fake_game.js нет заглушек для: " + ", ".join(missing))
        return 1
    print("стенд страницы: заглушки покрывают все %d вызовов api" % len(known))
    return 0


def main():
    if "--check" in sys.argv:
        build()
        return check()
    build()
    os.chdir(HERE)
    url = "http://127.0.0.1:%d/stand.html" % PORT
    print("стенд: " + url + "   (Ctrl+C — остановить)")
    webbrowser.open(url)
    with socketserver.TCPServer(("127.0.0.1", PORT), http.server.SimpleHTTPRequestHandler) as srv:
        try:
            srv.serve_forever()
        except KeyboardInterrupt:
            print("\nостановлен")
    return 0


if __name__ == "__main__":
    sys.exit(main())
