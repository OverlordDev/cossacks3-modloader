# Заготовка мода одной командой.
#
#   python tools/newmod.py my_mod                    # рядом, в ./my_mod
#   python tools/newmod.py my_mod "C:\\...\\Cossacks 3\\modloader\\mods"
#
# ЗАЧЕМ. Первый мод не пишется с чистого листа: надо знать, какие поля бывают в
# manifest.lua, чем client отличается от server, где брать события и почему
# мир нельзя менять с клиента. Заготовка отвечает на это сразу и рабочим кодом —
# её можно запустить, а потом резать под себя.
#
# Заготовка проходит tools/modcheck.py без замечаний: это проверяется в
# tools/newmod_test.py, чтобы пример не расходился с собственными правилами.
import argparse
import os
import re
import sys

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

MANIFEST = '''-- Паспорт мода: модлоадер читает его первым и по нему решает, что грузить.
return {{
    -- id — латиница, цифры и _. По нему мод видно в списке и в логе.
    id = "{id}",
    name = "{name}",
    version = "0.1.0",
    author = "",
    description = "",

    -- Две половины мода, и разница между ними важнее всего остального.
    --
    -- client.lua — то, что видит и слышит ИМЕННО ЭТОТ игрок: интерфейс, камера,
    --   подсветка, звук, страницы CEF. Мир менять нельзя: у соседа этого не
    --   произойдёт, и партия разойдётся.
    -- server.lua — то, что решает игру: спавн, урон, ресурсы, приказы. Работает
    --   только там, где игра считается (у хоста или в одиночной), и потому
    --   одинаково у всех.
    --
    -- Нужна одна логика на обеих сторонах — вместо server пишут shared = "...".
    client = "client.lua",
    server = "server.lua",

    -- Файлы, которые мод подключает через require. Чего здесь нет — require не найдёт.
    files = {{}},

    -- "required"  — без мода у всех игра не начнётся (мод меняет правила);
    -- "optional"  — у кого нет, тот просто не увидит (мод только показывает).
    multiplayer = "optional",
}}
'''

CLIENT = '''-- {name} — клиентская половина: видит и показывает, мир не трогает.
--
-- Что здесь можно: интерфейс, камера, подсветка, звук, страницы, чтение мира.
-- Чего нельзя: спавн, урон, ресурсы, приказы — это server.lua. Правило простое:
-- если от действия у соседа по сети картина станет другой, ему здесь не место.

-- Список событий и что приходит в обработчик — api/59_events.lua.
-- Имя с опечаткой модлоадер назовёт в логе при загрузке.
events.on("game.start", function()
    log.info("[{id}] партия началась, сторона: " .. game.side)
end)

-- Юнит появился: handle — его хендл, base — тип ("musketeer18", "peasant").
events.on("unit.spawn", function(event, handle, base)
    log.info("[{id}] появился " .. base .. " (хендл " .. handle .. ")")
end)

-- Клавиша. Горячие клавиши модлоадера: Insert — меню, F9/End/F12 в dev-режиме,
-- Ctrl+I — инспектор; их лучше не занимать.
input.bind("Ctrl+M", function()
    local selected = units.selected()
    log.info("[{id}] выделено объектов: " .. #selected)
end)
'''

SERVER = '''-- {name} — серверная половина: решает игру.
--
-- Работает там, где партия считается: у хоста сетевой игры или в одиночной.
-- На клиенте этот файл не исполняется, поэтому всё, что меняет мир, пишут сюда —
-- тогда у всех игроков случится одно и то же.
--
-- ВАЖНО ПРО КООРДИНАТЫ: мир меряется в КЛЕТКАХ карты. Карта 320 — это от -160
-- до +160 по каждой оси, а не от 0 до 320. Размер даёт native.GetMapWidth().

events.on("game.start", function()
    log.info("[{id}] сервер готов, карта " .. native.GetMapWidth() .. " клеток")
end)

-- Приказ любому юниту — от игрока, ИИ или по сети. Вернуть true — приказ отменён.
events.on("unit.order", function(event, handle, kind, target, x, z)
    if kind == "attackpoint" then
        log.info(string.format("[{id}] атака точки %.1f, %.1f", x, z))
    end
    return false
end)
'''

README = '''# {name}

Заготовка мода для Cossacks 3 Modloader.

## Куда положить

    <Cossacks 3>/modloader/mods/{id}/

## Как проверить до запуска игры

    python tools/modcheck.py путь/к/{id}

Проверяются manifest.lua, синтаксис, имена событий, имена функций api и нативов,
сторона натива и число возвращаемых значений.

## Как перезагрузить, не выходя из игры

В консоли модлоадера:

    .lua reload

## Где что искать

- события и что приходит в обработчик — `api/59_events.lua`
- функции api — файлы `api/*.lua`, там же примеры в комментариях
- нативы игры и их стороны — `api/57_native_catalog.lua`
- общее описание — `MODDING.md`
- живой осмотр игры — инспектор, Ctrl+I (нужен `modloader/dev.txt`)
'''


def main():
    ap = argparse.ArgumentParser(description="создать заготовку мода")
    ap.add_argument("id", help="идентификатор мода: латиница, цифры и _")
    ap.add_argument("where", nargs="?", default=".", help="куда класть (по умолчанию — сюда)")
    ap.add_argument("--name", default=None, help="человеческое название")
    args = ap.parse_args()

    if not re.fullmatch(r"\w+", args.id, re.A):
        print("id '%s' не годится: только латиница, цифры и _" % args.id)
        return 1

    target = os.path.join(args.where, args.id)
    if os.path.exists(target):
        print("папка %s уже есть — не трогаю её" % target)
        return 1

    fields = {"id": args.id, "name": args.name or args.id}
    os.makedirs(target)
    for filename, template in (("manifest.lua", MANIFEST), ("client.lua", CLIENT),
                               ("server.lua", SERVER), ("README.md", README)):
        with open(os.path.join(target, filename), "w", encoding="utf-8", newline="\n") as f:
            f.write(template.format(**fields))

    print("мод создан: %s" % os.path.abspath(target))
    print("проверить:  python tools/modcheck.py %s" % target)
    return 0


if __name__ == "__main__":
    sys.exit(main())
