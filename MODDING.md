# Как делать моды для Cossacks 3 Modloader

Короткое руководство для команды. Подробности по функциям — `api/README.md` и комментарии в начале
каждого `api/*.lua`; переменные и типы игры — `GAME_STATE.md`; экраны и кнопки — `GAME_SCREENS.md`;
нативные функции движка — `GAME_API.md`.

## 1. Где лежит мод

```
<игра>/modloader/mods/<папка мода>/
    manifest.lua      обязательно — паспорт мода
    client.lua        скрипт интерфейса (по желанию)
    server.lua        скрипт правил (по желанию) — или shared.lua
    web/              HTML-страницы (CEF): меню, HUD
    assets/           замена файлов игры (текстуры, шейдеры, конфиги, скрипты целиком)
    patches/          правки скриптов игры по кусочкам (*.patch)
```

Мод может быть только из данных — без Lua, с одними `assets/` или `patches/`.

## 2. manifest.lua

```lua
return {
    id = "my_mod",               -- латиница, цифры, _
    name = "My Mod",
    version = "1.0.0",
    author = "...",
    description = "...",
    enabled = true,              -- false — лежит, но не грузится (переключается и в меню Insert)

    client = "client.lua",       -- у каждого игрока: интерфейс, клавиши, чтение состояния
    server = "server.lua",       -- только там, где решается игра (одиночка, хост)
    -- shared = "shared.lua",    -- вместо server: выполняется у ВСЕХ одинаково (для правок мира)

    files = { "utils.lua" },     -- модули для require("utils")

    multiplayer = "required",    -- "required" — в сети должен быть у всех, "optional" — только интерфейс
    priority = 0,                -- порядок: больше — грузится позже и перекрывает других (файлы, патчи)
    requires = { "base_mod" },   -- без этих модов не загрузится (и грузится после них)
}
```

**Какую сторону выбрать.** Интерфейс и клавиши — `client`. Решения, которые принимает хост (дать
ресурсы, наказать) — `server`. Всё, что меняет мир одинаково на всех машинах (баланс, статы, логика
зданий) — `shared`: иначе в сети партия разойдётся.

## 3. События

```lua
events.on("unit.death", function(event, handle, basename) ... end)
```

| событие | аргументы после имени | когда |
|---|---|---|
| `game.menu` | — | главное меню |
| `game.prepare` | — | начало создания партии (настройки карты ещё можно менять) |
| `game.start` | — | партия загрузилась |
| `game.tick` | — | каждый такт партии |
| `game.end` | — | выход из партии |
| `unit.spawn` / `unit.death` / `unit.destroy` | handle, basename | юнит появился / погиб / исчез |
| `building.spawn` / `.death` / `.destroy` | handle, basename | то же для зданий |
| `unit.damage` | attacker, target, damage | любой урон (ближний бой, выстрел, взрыв, по площади) |
| `unit.order` | handle, type, target, x, z | любой приказ любому юниту (игрок, ИИ, сеть). `return true` — отменить |
| `player.order` | order = {kind, target, x, z, group} | игрок кликнул приказ. `return true` — отменить |
| `net.connect` / `net.disconnect` | payload | игрок в комнате |
| `*` | имя события, ... | все события подряд (отладка) |

Отмена `unit.order` в сети — только в `shared`-моде одинаково на всех машинах.
Проверить, что события работают, — мод `event_test` (F8 — отчёт).

## 4. Главные функции

| что | как |
|---|---|
| лог | `log.info(...)`, `log.warn`, `log.error` |
| клавиши | `input.bind("F6", fn)`, `"Ctrl+LMB"` |
| код игры | `game.exec("pascal-код")` (server/shared), `game.eval("выражение")` |
| переменные игры | `state.read("gMap.players[0]")`, `state.set(путь, значение)` |
| юниты | `units.selected()`, `units.info(h)`, `units.orders(h)` |
| быстро, тысячи объектов | `objects.list()`, `objects.read(h)`, `objects.get(h, "orders[0].info.x")` — прямо из памяти |
| здания | `buildings.info(h)`, `buildings.produce(h, sid, n)`, `buildings.build(sid, x, z)` |
| баланс | `balance.setHP("musketeer18", 200)`, `balance.setDamage(sid, урон)`, `balance.set(sid, поле, значение)` |
| экраны | `screens.open(имя)`, `screens.press(имя, кнопка)`, `ui.screen("MainMenu", fn)` |
| страницы | `web.open("web/menu.html")`, `web.passthrough(true)` (HUD), в JS — `game.api("buildings.info", h)` |
| сеть | `net.send("имя", данные)`, `net.on("имя", fn)`, `net.broadcast(...)` |
| натив движка | `native.GetCurrentMouseWorldCoord()` (список — `GAME_API.md`) |
| удобный вывод | `show(таблица)` в консоли |

## 5. Замена файлов — assets/

Файл кладётся по тому же пути, что в игре:

```
mods/my_mod/assets/data/shaders/tone/tone.frag   ->  вместо  <игра>/data/shaders/tone/tone.frag
```

Работает для всего, что движок читает с диска: скрипты, текстуры, модели, шейдеры, конфиги.
Файлы читаются на старте игры — после правки перезапусти игру (через Launcher).
Если два мода заменяют один файл, побеждает мод с большим `priority` (при равном — позже по имени папки).
Новые файлы, которых нет в игре, класть можно, но если игра сама перебирает папку (списки карт и т.п.),
она их пока не увидит.

## 6. Патчи скриптов — patches/

Замена файла целиком ломается при обновлении игры и конфликтует с другими модами. Патч правит только
нужное место:

```
mods/my_mod/patches/data/scripts/lib/unit.script.patch
```

```
@@ строки с @@ — комментарии

@replace _unit_OrderMove          заменить функцию целиком (объявление ... end;)
function _unit_OrderMove(...) : Pointer;
begin
   ...
end;

@begin _unit_AddOrder             вставить в начало функции (сразу после begin)
@end _unit_AddOrder               вставить в конец (перед end;)
@before _unit_AddOrder            вставить перед функцией — так добавляют новые функции
@after _unit_AddOrder             вставить после функции
@append                           в конец файла

@find                             найти текст (точно, с отступами)...
            var damage : Integer = indamage;
@with                             ...и заменить (все вхождения)
            var damage : Integer = indamage * 2;
```

- Патчей к одному файлу может быть много (от разных модов) — накладываются по порядку модов.
- Если блок не нашёл место — в лог `[patch] ... block skipped`, остальные блоки работают.
- Готовый файл лежит в `modloader/cache/<путь>` — смотри его, если что-то не компилируется.
- Кодировка патча — UTF-8 или ANSI, русские комментарии можно.
- Пример — `examples/mods/patch_example` (урон ×2).
- Патч меняет правила — ставь `multiplayer = "required"`.

## 7. Сеть

- Хост с модлоадером проверяет у входящих игроков моды `multiplayer = "required"` (у которых есть
  server/shared часть, assets или patches) и кикает тех, у кого их нет или они другие.
- Клиентские моды (`optional`) не проверяются.
- Встроенные правки модлоадера не должны менять контрольную сумму лобби (для правок библиотек ещё
  проверяется командой `.checksum`) — с модлоадером можно играть онлайн.
  Моды с патчами и заменой скриптов — меняют: играть можно только с теми, у кого они тоже стоят.

## 8. Отладка

- `modloader/dev.txt` (пустой файл) — подробный лог и инструменты разработчика.
- Лог всегда пишется в `modloader/modloader.log`; падения — `modloader/crashes/`.
- F12 — DevTools страницы, страницы перезагружаются сами при сохранении файла (dev).
- Консоль модлоадера (окно рядом с игрой) — строка Lua, или команды:
  `.help`, `.mods`, `.events`, `.assets` (замены и патчи), `.checksum`, `.modcheck`, `.find слово`,
  `.lua reload` — перезагрузить Lua-моды без перезапуска игры.
- Мод `dev_tools`: ЛКМ — координаты точки, лог приказов.
