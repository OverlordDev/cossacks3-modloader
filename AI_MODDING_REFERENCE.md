# Cossacks 3 Modloader — справочник API для генерации модов

Этот файл — контекст для нейросети (или человека), которая пишет моды. Здесь всё, что существует:
если функции нет в этом файле, её нет. Не придумывай функции, поля и события.
Если нужного нет — используй `native.<Имя>` (список: `GAME_API.md`) или `game.exec` с кодом
Pascal игры (переменные и типы: `GAME_STATE.md`).

---

## 0. Главные правила (читать первыми)

1. **Мод = папка** `modloader/mods/<id>/` с `manifest.lua`. Язык модов — **Lua 5.4**. Строки — UTF-8.
2. **Три стороны.** Код в `client` работает у каждого игрока, в `server` — только у хоста/в одиночке,
   в `shared` — у всех одинаково. От стороны зависит, какие функции доступны (таблица в §3).
3. **На client нет `game.exec`.** Поэтому на клиенте НЕ работают: `state.set`, `units.info/selected/orders`,
   `buildings.*`, `balance.*` (кроме чтения через `state`), `player():add`, `world{...}`.
   На клиенте работают: `state.get/read`, `objects.*`, `game.eval*`, `native.Get*/Is*...`, `ui`, `web`, `input`, `gfx`.
   Страница CEF (`game.api` в JS) может всё — через неё клиентский HUD получает данные зданий.
4. **Мультиплеер.** Всё, что меняет мир (статы, юнитов, логику, отмену приказов), — в `shared` и
   одинаково на всех машинах, иначе рассинхрон. Ресурсы и решения хоста — в `server`.
   Клиент просит хоста через `net.send`, хост отвечает `net.broadcast`.
5. **Скорость.** `game.exec`, `game.eval`, `state.*`, `units.*`, `buildings.*` компилируют Pascal —
   ~1 мс на вызов. Не вызывай их на каждом такте для каждого юнита. Для обхода многих объектов —
   `objects.list()` + `objects.read(h)` / `objects.get(h, поле)` (микросекунды).
6. **Когда что менять.** Статы типов игра заполняет в начале партии — менять в `events.on("game.start")`.
   Настройки карты — в `events.on("game.prepare")`. Вне партии многие нативы падают — проверяй `game.isInGame()`.
7. **Ошибки** в обработчике не роняют игру: пишутся в лог с именем мода. Используй `log.info/warn/error`.
8. **Не трогай файлы игры.** Замена — через `assets/`, правка скриптов — через `patches/*.patch`.

---

## 1. Структура мода

```
modloader/mods/<id>/
  manifest.lua          обязательно
  client.lua            сторона client (по желанию)
  server.lua | shared.lua   сторона server или shared (по желанию, не обе)
  <модуль>.lua          общие модули, перечислить в files, подключать require("модуль")
  web/<страница>.html   страницы CEF
  assets/<путь в игре>  замена файла игры целиком
  patches/<путь в игре>.patch   правка текстового файла игры
```

Нужна хотя бы одна из: `client`, `server`/`shared`, папка `assets/`, папка `patches/`.

## 2. manifest.lua

Выполняется в пустом окружении — только данные, без вызовов функций.

```lua
return {
    id = "my_mod",            -- обязательно: [A-Za-z0-9_]
    name = "My Mod",
    version = "1.0.0",
    author = "",
    description = "",
    enabled = true,           -- по умолчанию true
    client = "client.lua",
    server = "server.lua",    -- ИЛИ shared = "shared.lua"
    files = { "utils.lua" },  -- модули для require; только .lua внутри папки мода
    multiplayer = "required", -- "required" (по умолчанию) | "optional" (только интерфейс)
    priority = 0,             -- целое; больше — грузится позже, его assets/patches главнее
    requires = { "other_id" },-- строка или список id; без них мод не загрузится
}
```

`multiplayer = "optional"` — только если мод ничего не меняет в игре (интерфейс, графика, клавиши).

## 3. Что доступно на какой стороне

| таблица / функция | client | server | shared | страница (game.api) |
|---|---|---|---|---|
| `log`, `print`, `require`, `mod`, `show` | да | да | да | — |
| `events.on/off/hook` | да | да (только у хоста) | да (у всех) | — |
| `game.eval/evalInt/evalFloat/evalBool`, `game.mode`, `game.isAuthority`, `game.isInGame` | да | да | да | да |
| `game.exec`, `game.run`, `game.command` | **нет** | да | да | да |
| `native.<Имя>` | только читающие (`Get*`, `Is*`, `Has*`, `Can*`, `Calc*`, `Check*`, `Find*`, `Count*`, GUI) | все | все | все |
| `mem.*`, `objects.*` | да | да | да | да |
| `state.get/read/list/type`, `G.x` (чтение) | да | да | да | да |
| `state.set`, `G.x = v` | нет | да | да | да |
| `units.*`, `buildings.*`, `balance.*`, `player():add`, `world{}` | нет | да | да | да |
| `profile.*`, `options.*`, `saves.*`, `players.*`, `map.*`, `screens.list/tags/open/press` | чтение (`get`); `set` — нет | да | да | да |
| `net.send` | да | нет | нет | — |
| `net.broadcast` | нет | да | да | — |
| `net.on` | да | да | да | — |
| `input.bind`, `web.*`, `ui.*`, `gfx.*`, `screens.onButton/onAnyButton/replace` | да | нет | нет | — |
| `mathx.*`, `vec.*`, `tablex.*`, `stringx.*`, `geometry.*`, `validate.*`, `color.*` | да (pure: везде, в т.ч. shared) | да | да | да |
| `scheduler.*`, `query.*` | да (чтение/таймеры) | да | да | да |
| `rng.*` | да (только детерминированные вызовы!) | да | да (shared!) | да |
| `config.*` | да (нужен link) | да (нужен link) | нет | нет |
| `camera.*`, `minimap.*`, `animation.*`, `model.*`, `effects.*`, `decals.*` | да (только картинка) | да | да | да |
| `pathfind.*`, `markers.*`, `cutscene.*`, `dbg.*`, `sound.*` | да | да | да | да |
| `world.spawn/destroy/move`, `object.setState/destroyIn/progress`, `terrain.raise/lower/smooth/update`, `fow` (запись), `time.*` | **нет** | да | да | да |
| `orders.*`, `formation.set`, `weapon.*`, `status.*`, `ai.*`, `scenario.*` (логика), `economy.*` (запись), `attach.follow/unfollow`, `vision.*` (запись), `time.*` | **нет** | да | да | да |
| `targeting.*`, `scenario.present`, `panel.*`, `attach.effect/free`, `replay.*`, `profiler.*`, `content.*`, `mods.list` | да | да | да | да |
| manifest `permissions = {...}` | — | — | — | — |
| `steam.*` (presence локального игрока) | да | нет | нет | нет |
| `group.*` (чтение), `tracks.*` (чтение — нет, всё server), `scenario.snapshot`, `dbg.*`, `gui.*`, `native.info` | да | нет/да (см.) | — | да |
| `group.create/add/move/...`, `behaviour.*`, `tracks.*`, `regions.block`, `scenario.begin` | **нет** | да | да | да |

`server`-обработчики событий и `net.on` работают только там, где решается игра (одиночка/хост).
`shared` — на всех машинах.

## 4. Lua API

### 4.1. log, mod, require, show

```lua
log.info(...)  log.warn(...)  log.error(...)   -- в консоль и modloader.log с именем мода; print = log.info
local u = require("utils")                      -- модуль из manifest.files (без .lua)
mod.id  mod.name  mod.version  mod.side         -- "client" | "server"
mod.files("web/img")                            --> { "a.png", ... } имена файлов в папке мода
show(value, depth)                              --> текст таблицы (для консоли и логов)
```

### 4.2. events

```lua
local id = events.on(name, function(event, ...) ... end)   -- вернуть true — отменить (где сказано)
events.off(id)
events.hook("ShowHud", atEnd)   -- создать событие gui.ShowHud в начале (или в конце) состояния GUI
```

| событие | аргументы после `event` | когда | отмена |
|---|---|---|---|
| `game.menu` | — | вошли в главное меню | — |
| `game.prepare` | — | начало создания партии (менять `world{}`) | — |
| `game.start` | — | партия загружена | — |
| `game.tick` | — | каждый такт партии (часто! лёгкий код) | — |
| `game.end` | — | выход из партии | — |
| `unit.spawn` | handle, basename | появился юнит | — |
| `unit.death` | handle, basename | юнит погиб | — |
| `unit.destroy` | handle, basename | юнит исчез с карты | — |
| `building.spawn` / `building.death` / `building.destroy` | handle, basename | то же для зданий | — |
| `unit.damage` | attacker, target, damage | любой урон (ближний, выстрел, взрыв, площадь); attacker может быть 0 | — |
| `unit.order` | handle, type, target, x, z | любой приказ любому юниту (игрок, ИИ, сеть). type — строка ниже | `return true` (в сети только в shared) |
| `player.order` | order | игрок этого компьютера отдал приказ мышью | `return true` |
| `net.connect` / `net.disconnect` | payload | игрок вошёл/вышел из комнаты | — |
| `net.sync` | — | сетевая партия: шаг синхронизации (~10 раз в секунду), выполняется у ВСЕХ на одном и том же шаге симуляции — место для сверки/детерминированной логики. Внутри только читать; тяжёлое и `net.send` — на `game.tick` | — |
| `save.loaded` | — | загружен сейв, `savedata` уже с его данными | — |
| `gui.<Состояние>` | payload | после `events.hook(...)` | — |
| `*` | как у события | все события (отладка) | — |

`basename` — внутреннее имя типа (sid), например `"musketeer18"`, `"auscen"`.
`unit.order` type: `none, move, attackobj, gainres, produce, patrol, attackpoint, continueattackpoint,
performupgrade, fishing, creategates, buildwallcontinue, buildwall, gotomine, gototransport,
leavetransport, leavebuilding, build, guard, repair, exitunits`.
`player.order` order = `{ kind, target, x, z, group }`, kind: `move | attack | attackpoint | guard |
build | enter | gather | patrol`; target — хендл цели, x/z — точка, group — группа (move — событие на каждую группу).

### 4.3. game

```lua
game.eval("GetBuildVersion")          --> строка результата выражения Pascal
game.evalInt("gMap.gamestage")        --> integer
game.evalFloat("gProfile.sndmaster")  --> number
game.evalBool("gbool_peacemode")      --> boolean
game.exec(code, arg)                  --> строка из ML_RET(...) или "" ; ML_ARG в коде = arg (строка). server/shared
game.run(code)                        -- асинхронно, без результата. server/shared
game.command("res all 5000")          -- команда чата игры. server/shared
game.mode()                           --> "offline" | "host" | "client"
game.isAuthority()                    --> true, если эта машина решает игру (одиночка или хост)
game.isInGame()                       --> идёт партия
game.playerIndexOf(from)              --> индекс игрока по отправителю из net.on
game.side                             --> "client" | "server"
game.readFile("data/gen/x.tga")      --> байты файла из папки игры (только чтение, путь внутри папки) или nil
```

Pascal в `game.exec`: переменные объявляются по месту (`var h : Integer = 5;`), результат —
`ML_RET(IntToStr(x))`, строки в одинарных кавычках. Объект по хендлу: `TObj(_unit_GetTObj(h)).hp`.
Ресурсы в памяти инвертированы: читать `not gPlayer[i].res[t]` (или через `player(i).gold`).
Константы игры `gc_*` доступны в коде Pascal. Типы и поля — `GAME_STATE.md`.

### 4.4. player, world

```lua
local p = player()      -- игрок этого компьютера (только в партии); player(i) — по индексу
p.index
p.food  p.wood  p.stone  p.gold  p.iron  p.coal     -- чтение
p.gold = 1000                                       -- запись (server/shared)
p:add("gold", 500)                                  -- (server/shared)

world()                          --> { size, season, terrain, relief, mines, resources, seed0, seed1 }
world{ size = 2, mines = 3 }     -- server/shared, в game.prepare
-- size: 0=320 1=480 2=640 3=256; season: 0 лето 2 зима 3 пустыня (<0 случайно); terrain 0..5; relief 0..4;
-- resources: 0=1000 1=4000 2=5000 иначе 1000000
```

### 4.5. state и G — любые переменные игры

```lua
state.get("gProfile.sndmaster")          --> значение (тип по схеме)
state.read("gMap.players[2]", depth)     --> запись таблицей
state.list("gMap.players", depth)        --> массив записей
state.type("gMap.settings.gen")          --> имя типа
state.set("gProfile.sndmaster", 0.5)     -- server/shared
state.get("obj(" .. h .. ").hp")         -- объект по хендлу (TObj)
G.gProfile.sndmaster                     -- то же через точку; G.x = v — запись; G.gMap.players[2]() — запись таблицей
```

### 4.6. objects и mem — быстрое чтение (любая сторона)

```lua
objects.list(playerIndex)   --> { handle, ... } объекты игрока; nil — всех игроков (включая ресурсы/снаряды не отфильтрованы)
objects.each(fn, playerIndex)
objects.read(h)             --> все простые поля TObj: { hp, pl, cid, id, uid, bdead, bbuilt, kill, ... } или nil (не юнит/здание)
objects.get(h, "hp")        --> одно поле; путь как в TObj: "orders[0].itype", "orders[0].info.x"
objects.pos(h)              --> x, z (мировые координаты)
objects.ptr(h)              --> адрес TObj или nil
objects.status()            --> "fast" | "slow" | "not calibrated", параметры
mem.i32(addr, off) mem.u32 mem.i16 mem.u16 mem.u8 mem.f32 mem.f64 mem.str mem.bytes(addr, off, n)  -- nil при ошибке
```

`objects.read` возвращает `nil` для объектов, которые не юнит/здание. Здания отличаются по
`balance`/`gObjProp[cid][id].bbuilding`; тип объекта — `native.GetGameObjectBaseNameByHandle(h)`.
Только чтение: менять — через `state.set("obj(h).поле", v)` (server/shared) или функции api.

### 4.7. units (server/shared/страницы)

```lua
units.selected()    --> { handle, ... } выделенное игроком
units.info(h)       --> { handle, sid, player, hp, maxhp, x, z, dead } или nil
units.orders(h)     --> { { type, target, x, z }, ... } очередь приказов, [1] — текущий
```

### 4.8. buildings (server/shared/страницы)

```lua
buildings.list(player)            --> { { handle, sid, built, hp, maxhp, x, z, queue }, ... } (player — индекс, по умолчанию свой)
buildings.selected()              --> хендл выделенного здания или nil
buildings.info(h)                 --> { handle, sid, country, id, player, hp, maxhp, built, buildprogress,
                                  --     produce = { {sid, id, available, price = {еда,дерево,камень,золото,железо,уголь}, buildtime, x, y} },
                                  --     upgrades = { {sid, index, available, enabled, level, kind, value, price, time} },
                                  --     queue = { {kind = "unit"|"upgrade", sid, amount (-1 бесконечно), progress} } }
buildings.produce(h, unitSid, amount)     -- заказать (как кнопка игрока); amount -1 — бесконечно
buildings.cancel(h, unitSid, amount)
buildings.upgrade(h, upgSid)      buildings.cancelUpgrade(h, upgSid)
buildings.produceList(bsid)               --> { unitSid, ... } что строит тип здания
buildings.setProduceList(bsid, list)      buildings.addProduce(bsid, sid)    buildings.removeProduce(bsid, sid)
buildings.setUpgrade(upgSid, field, value)          -- поля TCountryUpgrade: time, value, enabled, price[3] ...
buildings.canPlace(sid, x, z, player)     --> boolean
buildings.build(sid, x, z, opts)          --> хендл стройки; ошибка строкой при неудаче
    -- opts = { workers = "selected" | {h1, h2}, instant = true, player = i, check = false }
buildings.finish(h)                       -- достроить мгновенно (в сети только shared)
```

Правка логики зданий (`setProduceList`, `setUpgrade`) — в `shared`, в `game.start`.

### 4.9. abilities (server/shared) — способности и area damage

`abilities` — безопасная заготовка для авиаударов, баллистики и миномётов. Она вызывает
штатный `_misc_DoDamage`, поэтому проходят обычные события `unit.damage` и `unit.death`.
Вызов меняет мир и разрешён только на server/shared-стороне; клиент должен передать запрос
через `net.send`, а сервер обязан проверить координаты, право игрока и стоимость.

```lua
abilities.define("airstrike", {
    cooldown = 20,
    damage = 100000,
    radius = 10,
    target = "all",                 -- "all", "units" или "buildings"
    effect = "cannon",              -- "cannon", "howitzer", "grenade" или "none"
    ignorePeace = true,              -- разрешить урон во время мирного периода
})

net.on("airstrike.request", function(data, from)
    local p = game.playerIndexOf(from)
    local ok, hit, wait = abilities.fire("airstrike", data.x, data.z, { owner = p })
    net.broadcast("airstrike.result", { player = p, ok = ok, hit = hit, wait = wait })
end)
```

Методы: `abilities.define(id, spec)`, `abilities.get(id)`, `abilities.list()`,
`abilities.ready(id, owner)`, `abilities.fire(id, x, z, opts)`. `opts` поддерживает
`damage`, `radius`, `target`, `effect`, `ignorePeace`, `weaponKind`, `source` и `owner`. `fire` возвращает
`true, hitCount` или `false, "cooldown", seconds`.

Пример `ability_example` выключен по умолчанию: наведи курсор на карту и нажми F6 —
выбор юнита не нужен. Клиент получает мировые координаты через
`native.GetCurrentMouseWorldCoord()`, сервер вызывает `abilities.fire()`.
`hitCount` — число объектов в области, а не число смертей.

### 4.10. balance (server/shared) — статы типов

```lua
balance.types()                          --> { {sid, country, id}, ... }
balance.find(sid)                        --> country, id
balance.get(sid, player)                 --> { base = TObjBase, prop = TObjProp }
balance.set(sid, field, value, player)   -- поле TObjBase: "maxhp", "speed", "buildtime", "price[3]",
                                         --   "shield", "protection[0]", "weapon[0].damage", "weapon[1].radiusmax" ...
balance.setProp(sid, field, value)       -- поле TObjProp (общее): "vision", ...
balance.setHP(sid, maxhp, player)        -- и живым юнитам этого типа
balance.setDamage(sid, damage, weapon, player)   -- weapon — индекс 0..3 (у мушкетёра 0 штык, 1 выстрел); nil — все
balance.setSpeed(sid, multiplier, player)        -- и живым
balance.dump(sid, player)                -- все поля в лог
```

player — индекс игрока, `nil` — всем. Цены: `price[0]` еда, `[1]` дерево, `[2]` камень, `[3]` золото,
`[4]` железо, `[5]` уголь. Менять в `game.start` в `shared`-моде.

### 4.10. Прочие данные

```lua
profile.get(field)  profile.set(field, v)  profile.all()  profile.save()   -- gProfile (TProfile)
options.get(name)   options.set(name, v)                                    -- опции движка ("SSAOEnable", "ShadowMap")
saves.list() --> { {name, date} }   saves.load(name)   saves.delete(name)   saves.replays.list()   saves.replays.load(name)
players.list() --> { {index, name, team, color, bai, bhuman, ...} }   players.me()   players.resources(i)
map.info()     map.settings() --> { gen = {...}, additional = {...} }
```

### 4.11. net

```lua
-- client
net.send("event", data)                      -- хосту (в одиночке — своему server-скрипту)
net.on("event", function(data, from) end)    -- от хоста
-- server/shared
net.broadcast("event", data)                 -- всем клиентам (и клиентской стороне хоста)
net.on("event", function(data, from)         -- от клиента
    local who = game.playerIndexOf(from)     -- определять игрока ТАК, не доверять данным
end)
```

data — nil, число, строка, boolean или таблица из них. Имена событий — свои у каждого мода.

### 4.12. input (client)

```lua
input.bind("F6", function(key) end)
-- клавиши: A-Z, 0-9, F1-F12, Num0-Num9, Space, Enter, Tab, Escape, Backspace, Delete, Home,
-- PageUp, PageDown, Up, Down, Left, Right, LMB, RMB, MMB; модификаторы: "Ctrl+", "Shift+", "Alt+"
```

Не занимай Insert (меню). С dev.txt модлоадер ещё берёт F9 (ресурсы, только одиночка), End (выгрузка), F12 (DevTools).

### 4.13. web — страницы CEF (client)

```lua
web.open("hud.html")        -- <мод>/web/hud.html (или полный URL)
web.close()   web.reload()   web.isOpen()   web.url()
web.eval("js-код")          -- выполнить в странице
web.passthrough(true)       -- режим HUD: прозрачное (alpha < 16) пропускает мышь в игру
```

Одна страница на экране одновременно (последний `web.open` заменяет).

**JS в странице** (объект `window.game` появляется после загрузки — ждать его):

```js
const v = await game.api('buildings.info', handle);   // любая функция api: 'модуль.функция', аргументы — как в Lua
await game.api('state.set', 'gProfile.sndmaster', 0.5);
await game.tag('EventMainMenu', 104);                  // нажать родную кнопку (состояние, тэг)
await game.exec('ShowSettings');                       // запустить состояние интерфейса
const r = JSON.parse(await game.lua('1 + 1'));        // код Lua: выражение или оператор, ответ — JSON-строка
game.log('text');   game.close();   await game.files('img');
```

Ошибка в `game.api` — исключение (Promise reject) с текстом ошибки Lua.
Код страницы (`game.api`, `game.lua`) выполняется в окружении консоли модлоадера (сторона server),
а не в окружении мода: глобальные переменные и функции мода со страницы не видны. Мод и страница
обмениваются данными через api-функции, `web.eval(...)` (Lua → страница) и глобальные таблицы игры.
`game.lua` доступен только локальным страницам (из папки мода).

### 4.14. ui — родной интерфейс игры (client)

```lua
ui.window{ name=, parent=0, x=, y=, w=, h= }                                 --> элемент (число)
ui.text{ name=, parent=, text=, x=, y=, w=0, h=0, font="gc_font_serif_15", color={r,g,b,a} }
ui.image{ name=, parent=, material="mainmenu_art", x=, y=, w=0, h=0, align= }
ui.container{ name=, parent=, x=, y=, w=, h=, align= }
ui.button{ name=, parent=, text=, x=, y=, w=0, h=0, material="btn.large", hint="", tag=0, align=, onClick=function(el) end }
ui.onClick(el, fn)
ui.find(name, parent)  ui.name(h)  ui.getText(h)  ui.setText(h, s)  ui.isVisible(h)  ui.setVisible(h, b)
ui.getPosition(h)  ui.setPosition(h, x, y)  ui.setHint(h, s)  ui.setBlend(h, a)  ui.remove(h)
ui.size() --> w, h   ui.imageSize(material)   ui.locale(table, key)   ui.dump(h)   ui.children(h)
ui.exec("ShowSettings")          ui.sendTag("EventMainMenu", 103)
ui.hookState("EventMenu", function(element, press, tag) return true --[[игра не обработает]] end)
ui.screen("MainMenu", function() ... return false --[[оставить и родной]] end)   -- строить экран самому
```

### 4.15. screens — экраны по именам

```lua
screens.list()                      --> { "MainMenu", "Settings", ... }
screens.tags("MainMenu")            --> { Campaign = 101, Settings = 104, ... }
screens.button("MainMenu", 104)     --> "Settings"
screens.open("Settings")            screens.press("MainMenu", "Settings")
-- client:
screens.onButton("MainMenu", function(button, tag, element) return true --[[заменить своим]] end)
screens.onAnyButton(function(screen, button, tag, element) end)
screens.replace("Settings", function() web.open("settings.html") end)
```

Имена экранов и кнопок — `GAME_SCREENS.md`.

### 4.16. gfx — графика (client, видна только этому компьютеру)

```lua
gfx.<группа>{ ключ = значение }   -- записать;  gfx.<группа>() — прочитать
-- группы и ключи:
-- post: preset, preset2, dof, ssao        render: antialiasing, culling, objectCulling, fxaa
-- camera: dof, depth, focal, angle, distance, rotateSpeed, zoomSpeed, height, freeMode, ...
-- fog: enabled, density, power, start, finish, offset, depth      clouds: visible, active, height, horizon, fog, speed
-- sky: visible, active, flareAngle, flareZ, flare                 shadows: enabled, size, scaleHeight, addHeight, lightDepth
-- light: pattern, index, blendTo, blendTime                       time: game, speed, season, dayNight, fogOfWarDay
-- water: name, index, offset     wind: vector, target, random, interval     terrain: visible, borders, colorMode
gfx.preset{ bloom = 0.1, saturation = 1.2, hdr = 1.8, contrast = 1.05, vignetteInner = 0.7, vignetteOuter = 1.5 }
gfx.presets()   gfx.presetNames()   gfx.usePreset("name")
gfx.apply{ fog = {...}, shadows = {...} }     local s = gfx.snapshot()    gfx.apply(s)
gfx.option("ShadowMapEnabled", true)          gfx.vsync(false)   gfx.highlight{...}
gfx.<НативГрафики>(...)                       -- любой натив графики напрямую
```

Точный список ключей группы — прочитать `gfx.<группа>()` в консоли.

### 4.16а. savedata — данные мода внутри сейва (любая сторона)

```lua
savedata.set("veterans", { [123] = 5 })   -- любое значение: nil (удалить), число, строка, bool, таблица
savedata.get("veterans")                  --> значение или nil
savedata.keys()                           --> { "veterans", ... } ключи этого мода
events.on("save.loaded", function() ... end)  -- сейв загружен: savedata уже содержит его данные
```

Данные лежат внутри файла сохранения игры (автосейвы тоже), у каждого мода — своё пространство ключей.
При выходе из партии очищаются. Хендлы объектов после загрузки сейва могут быть другими — храни
`uid` (`objects.get(h, "uid")`), а не хендлы.

### 4.17. native

```lua
native.GetCurrentMouseWorldCoord()          --> x, y, z  (var-параметры возвращаются значениями)
native.GetGameObjectBaseNameByHandle(h)     --> "musketeer18"
native.GetPlayerIndexInterfaceIO()          --> индекс своего игрока
```

Все 4856 — `GAME_API.md` (VA, объявление). Вызов с неправильным числом аргументов — ошибка Lua.
Float — одинарной точности. Многие нативы падают вне партии.

### 4.18. camera — свободная камера (client, только картинка)

```lua
local x, y, z = camera.pos()              -- где камера; camera.target() — куда смотрит
camera.position(x, z)                     -- поставить; camera.rotate(x, y, z)
camera.moveTo(x, z, speed)                -- плавный переезд; camera.stop()
camera.follow(handle)                     -- следить; camera.follow(nil) — отпустить
camera.limits{ left=, top=, right=, bottom= }   -- ограничение; camera.getLimits()
camera.height(x, z)                       -- высота над точкой
camera.trackClear()                       -- стереть треки
local i = camera.trackAdd()
camera.trackPoint("name", tx,ty,tz, ex,ey,ez)
camera.trackPlay(i)
```
Вне партии нативы падают — проверяй `game.isInGame()`.

### 4.19. minimap — родная миникарта (client)

```lua
minimap.show(true)                        -- minimap.isVisible()
minimap.zoom(1.5)                         -- minimap.getZoom()
minimap.frustum(true)                     -- конус камеры
local i = minimap.icon("target")          -- новый примитив -> индекс
minimap.setPos(i, x, y)                   -- координаты миникарты (не мировые x,z)
minimap.setDir(i, dx, dy)                 -- направление
minimap.setBlink(i, 0.5, 5)               -- мигание
minimap.setVisible(i, true)               -- minimap.remove(i), minimap.clear()
```

### 4.20. animation + model — внешность (shared/client, только картинка)

```lua
animation.play(h, "attack")               -- разовая; animation.cycle(h, "work") — цикл
animation.frame(h, 12)                    -- поставить кадр; animation.frame(h) — прочитать
animation.info(h)                         --> { frameName=, cycle=, frame= }
model.actor(h, "actor")                   -- model.material(h, "mat")
model.scale(h, 1.2, 1.2, 1.2)             -- model.show(h, false)
model.rotate(h, 0, 1.57, 0)               -- model.pointTo(h, x, y, z)
```
В сети — в `shared`, иначе визуальный рассинхрон. Имена анимаций — из .oss актёра.

### 4.21. effects — дым/огонь/взрывы (shared/client, только картинка)

```lua
local id = effects.create(h, "PUEXP", "boom")   -- класс из data/pfx; effects.clear(h)
effects.pfx(h, "manager", "key")                -- частицы; effects.deletePfx/clearPfx/isPfx
effects.setLifetime(h, "manager", "key", 5.0)
effects.setScale(h, "manager", "key", 2, 2, 2)
effects.burst(id, 1.0, 30)                      -- effects.ring(id, ...) / effects.fire(id, ...)
effects.highlight(h, "target", true, "")        -- effects.unhighlight(h, "target")
```
Урон — только через `abilities.fire`; эффекты урона не наносят.

### 4.22. decals — следы на земле (shared, только картинка)

```lua
local d = decals.put("scorch", x, z)      -- имя из data/decals
decals.move(d, x, z)                      -- decals.pos(d)
decals.rotate(d, 1.2)                     -- decals.angle(d)
decals.show(d, false)                     -- decals.remove(d), decals.clear()
decals.count()                            -- decals.isInCircle(x, z, r, material)
```

### 4.23. world — спавн объектов (server/shared, меняет мир)

```lua
local h = world.spawn{ race = "ukr", base = "tree", x = 100, z = 50 }
world.move(h, 120, 60)                    -- world.move(h, x, y, z) — явно
local x, y, z = world.pos(h)              -- чтение — с любой стороны
world.destroy(h)                          -- мягко; world.destroyNow(h) — сразу
```
В сети — в `shared`. Неверные race/base могут уронить игру.

### 4.24. object — состояния (чтение везде, смена — server/shared)

```lua
object.state(h)                           --> "idle" / "burning" / ...
object.setState(h, "burning")
object.destroyIn(h, "destroyed")          -- уничтожить при входе в состояние
object.waitFor(h, "destroyed", function(h) ... end)   -- разовый колбэк
```

### 4.25. pathfind — пути (запросы, везде)

```lua
pathfind.calculate(h, x, z)               -- 0 — путь найден
pathfind.distance(x1, z1, x2, z2)         -- длина по проходимости, не прямая
pathfind.groupReady(grHandle)             --> boolean
```

### 4.26. terrain — рельеф (server/shared; x, y — КЛЕТКИ)

```lua
terrain.raise(100, 80, { delta = 2 })     -- terrain.lower / terrain.smooth
terrain.update()                          -- пересчитать после правок
terrain.height(x, z)                      -- высота в мировой точке (везде)
```

### 4.27. fow — туман (чтение везде, запись — server/shared)

```lua
fow.enable(false)                         -- fow.isEnabled()
fow.revealObject(h)                       -- прожектор; fow.hideObject(h), fow.clearObjects()
fow.rebuild()                             -- пересчитать целиком
```

### 4.28. markers — маркеры (client, только картинка)

```lua
local id = markers.add{ x = 100, z = 50, icon = "attack", decal = "scorch", duration = 10 }
markers.remove(id)                        -- markers.clear()
```

### 4.29. cutscene — катсцены (client)

```lua
cutscene.play{ { x = 10, z = 20, time = 2 }, { follow = h, time = 3 } }
cutscene.stop()                           -- cutscene.playing()
```

### 4.30. dbg — оверлей разработчика (client)

```lua
dbg.text("tgt", x, y, z, "HP: 100")       -- dbg.clear("tgt"), dbg.count()
dbg.unit(h)                               --> "h=123 musketeer18 pl=0 hp=80/100 ..."
local hit, x, y, z = dbg.ray(x1,y1,z1, x2,y2,z2)
```

### 4.31. netrec — журнал к рассинхрону (shared)

```lua
netrec.start()                            -- в game.start; netrec.stop()
log.info(netrec.report())                 -- шаги, хеши, последние приказы
```
Дополняет desync_watchdog: логи с двух машин рядом показывают первый разошедшийся шаг.

### 4.32. time — скорость (server/shared)

```lua
time.speed(0.5)                           -- time.factor(); time.pause() / time.resume()
```

### 4.33. sound — звуки (client, экспериментально)

```lua
local s = sound.get(h, "explosion")       -- излучатель h, библиотека из data/sounds
sound.play(s)                             -- sound.stop/volume/loop/source/remove
sound.playAt(h, "boom", { volume = 0.5 })
```

### 4.34. orders — приказы (server/shared)

```lua
orders.move(h, x, z)                          -- orders.move({h1,h2}, x, z, { clear = false })
orders.attackMove(units, x, z)                -- с боем; orders.attack(units, target, { lock = true })
orders.patrol(h, x1, z1, x2, z2)              -- orders.follow(h, target) = guard
orders.queue(h, { { move = {10, 20} }, { attackpoint = {30, 40} } })
orders.cancel(h)                              -- orders.cancel(h, true) — жёстко
```
Через `_unit_AddOrder` игры: события `unit.order` проходят. ~1 мс на приказ.

### 4.35. formation — построения (set: server/shared; slots: везде)

```lua
formation.set(units, "wedge", { x = 100, z = 50, spacing = 3, angle = 0 })
-- формы: line/column/wedge/square/circle; order="attackpoint" — идти с боем
```

### 4.36. weapon — снаряды (server/shared)

```lua
abilities.define("how", { cooldown = 5, damage = 800, radius = 12 })
weapon.fire{ ability = "how", target = { x = 100, z = 50 }, weapon = "PUEXPHOWITZER",
             speed = 80, shots = 3, interval = 0.5, spread = 4,
             sub = { count = 5, radius = 3, damage = 100 } }
```
Снаряд летит движком, урон — через abilities (события проходят). Разброс детерминирован.

### 4.37. status — эффекты (server/shared)

```lua
status.add(h, "burning", { duration = 10, damage = 20 })
status.add(h, "stunned", { duration = 3 })    -- резка приказов: status.installBlocker(events.on)
                                            -- один раз в shared-моде (в api-окружении нет events)
status.has(h, "burning")                      -- status.remove/list; status.define("rage", {...})
```

### 4.38. targeting — цели (везде, только чтение)

```lua
targeting.inCircle(x, z, 30, { enemy = true })   -- фильтры: enemy/player/sid/alive/maxR
targeting.nearest({ x = x, z = z }, { enemy = true })
targeting.inCone(x, z, dir, 0.4, 60, { enemy = true })
targeting.los(ax, az, bx, bz)                 -- чист ли рельеф (юниты не учитываются)
```

### 4.39. ai — автоматы (server/shared)

```lua
ai.attach(h, { initial = "guard", states = {
    guard = { onTick = function(h, api)
        local foe = targeting.nearest(h, { enemy = true, maxR = 60 })
        if foe then api.gotoState("attack", { target = foe }) end end },
    attack = { onEnter = function(h, api, p) orders.attack(h, p.target) end },
}})
ai.set(h, "attack", { target = foe })         -- ai.detach(h), ai.state(h)
```

### 4.40. scenario — миссии (логика server/shared + present на client)

```lua
scenario.objective("mill", { type = "capture", x = 100, z = 50, radius = 20, player = 0,
    onDone = function(id) ... end })          -- capture/destroy/survive/gather
scenario.wave({ delay = 60, units = { "peauk" }, race = "tat", x = 200, z = 100, player = 1 })
scenario.dialog("intro", { speaker = "Гетьман", text = "..." })
-- привязки (api не видит net/savedata/ui мода — один раз в записях):
--   scenario.link({ broadcast = net.broadcast, on = net.on })  -- server/shared+client
--   economy.link(savedata)                                     -- server/shared
--   panel.link(ui); gui.link(ui)                               -- client
-- в client.lua: scenario.present()
```

### 4.41. economy — ресурсы модов (запись server/shared, хранится в сейве)

```lua
economy.link(savedata)                       -- сначала! иначе ошибка link
economy.set(0, "fuel", 100)                   -- economy.get/add/consume (false — не хватает)
economy.produce(h, "musketeer18", { time = 30, cost = { fuel = 10 }, amount = 5 })
```

### 4.42. panel — панели без CEF (client)

```lua
local p = panel.new{ name = "air", title = "Авиаудар", x = 100, y = 100 }
p:label("...")                                -- p:button("Удар", function() ... end); p:close()
```

### 4.43. attach — составные объекты

```lua
attach.effect(h, "smoke_mgr", "chimney", { pos = {0, 3, 0}, scale = 1.5 })  -- везде
attach.follow(flagH, poleH)                   -- server/shared; attach.unfollow/free
```

### 4.44. vision — разведка (дальность/раскрытие: server/shared)

```lua
vision.radius("cossack", 1200)                -- в game.start, в shared
vision.reveal(towerH)                         -- vision.hide(towerH); vision.night(true)
```
Общего зрения (share) и детекторов air/stealth в движке нет — их нет и здесь.

### 4.45. replay — метки и камера (везде)

```lua
replay.mark("airstrike")                      -- replay.camera(true); replay.export()
```
Отката симуляции (playFrom) движок не умеет.

### 4.46. profiler — замеры (своя сторона)

```lua
profiler.start()                              -- ... игра ...; log.info(profiler.report())
profiler.stop()                               -- profiler.time("ai", fn) — свои колбэки
```

### 4.47. content + permissions + mods

```lua
content.require({ mods = { my_pack = "1.2.0" } })  -- ошибка с понятным текстом
mods.list()                                   --> { { id=, version=, permissions=} }
```
```lua
-- manifest.lua
return { id = "m", permissions = { world_spawn = true, terrain_edit = false } }
```

### 4.48. group — отряды (чтение везде, изменения — server/shared)

```lua
local g = group.create(0, "cavalry")      -- group.add(g, {h1, h2}), group.members(g)
group.move(g, x, z)                       -- group.formation(g, "wedge", { spacing = 3 })
group.stretch(g, 1.5)                     -- group.rebuild(g), group.destroy(g)
```
GroupSetVisible в движке нет — прячьте через model.show.

### 4.49. behaviour — физика (server/shared)

```lua
local b = behaviour.create(h, "cannon_recoil")  -- behaviour.destroy(b)
behaviour.force(behaviour.inertia(h), 500, 200, 0)  -- torque/push/bounce/mirror
behaviour.blast(h, x, z, power, up)       -- взрывная волна от точки
```

### 4.50. regions — зоны (блок — только shared)

```lua
regions.create("base", { {x=0,z=0}, {x=100,z=0}, {x=100,z=100}, {x=0,z=100} })
regions.units("base", { enemy = true })   -- regions.contains/onEnter/onLeave
regions.block("base", true)               -- резать приказы внутрь (shared!)
```
Нативов AIRegion в движке нет — это Lua-полигоны.

### 4.51. tracks — маршруты (server/shared)

```lua
local a, b = tracks.add("road", x1, y1, z1), tracks.add("road", x2, y2, z2)
tracks.connect(a, b)                      -- tracks.exists(a, b) + tracks.lastLength()
```

### 4.52. gui — интерфейс без CEF (client)

```lua
local b = gui.create("button", { parent = gui.find("CityPanel"), text = "Авиаудар" })
gui.onClick(b, function() ... end)        -- panel/button/label/image; gui.remove
```

### 4.53. dbg.draw + scenario.snapshot/trigger

```lua
dbg.line("p", x1,y1,z1, x2,y2,z2, "red")  -- box/sphere/axis/clean; цвета 0..1 или имена
scenario.snapshot("brief.bmp", 800, 600)  -- КАДР экрана, не сейв! restore() нет
scenario.trigger("fb", { on = "unit.death", action = function(...) ... end })
```

### 4.54. native.info — каталог всех 4856 нативов

```lua
native.info("PutDecalByName")
--> { addr=, decl=, side="client", risk="visual", category="decal", wrappedBy="decals.put" }
-- risk: read | visual | world (только server/shared) | forbidden (никогда на client)
-- Генератор: tools/gen_native_catalog.py. Сводка: NATIVE_CATALOG.md.
```

### 4.55. steam — Rich Presence (client, только свой статус)

```lua
steam.setMatch{ status = "В партии", map = "Полтава", mode = "2v2",
                opponents = { "Иван" } }   -- лимиты, троттлинг 3с, дедуп внутри
steam.setOpponent("Иван")                 -- steam.clearOpponent()
steam.playedWith("76561198000000000")     -- вручную; SteamID соперников узнать нельзя
steam.myId()                              --> свой SteamID64 или nil
steam.available()                         -- steam.status() -> "ok" | "no_dll" | ...
steam.clear()                             -- снять статус
```
Автостатусы (меню/лобби/партия) ставит builtin-мод сам. Текст у друзей зависит
от настройки Rich Presence Cossacks 3 в Steamworks (без неё видно лишь "В игре").

### 4.56. Utility Libraries — стандартный слой (api/60–70)

Чистые функции — везде включая shared (lockstep-безопасны): `mathx` (clamp/lerp/
wrap/углы; NaN→ошибка), `vec` (v2/v3; для карты z идёт ВТОРЫМ компонентом v2;
normalize(0)→0), `tablex` (map/filter/deepcopy/merge/shuffle — входы не мутируют,
кроме `clear`), `stringx` (split/trim/plain-замены; `utf8Length`/`truncateUtf8`
по символам, кириллица ок; `capitalize/lower/upper` — только ASCII!),
`geometry` (круг/сектор/сегменты/полигоны; углы — РАДИАНЫ; граница = внутри),
`validate` (проверки аргументов; хендлы бывают отрицательными!),
`color` (диапазон 0..255 целые, как ui; hex `#RRGGBB[AA]`).

С состоянием игры: `scheduler` (after/every/at/debounce/throttle на game.tick;
время — `native.GetGameTime()`, fallback os.clock НЕдетерминирован; автоочистка
на game.end/меню), `query` (сканы `O(n)` записями `{handle,x,z,hp,player,sid}`;
building-фильтр — один batched exec; НЕ каждый тик без интервала),
`rng` (splitmix64: `new/nextInt/nextFloat/range/pick/chance/shuffle/state`;
`seedFromGame()` из зерна карты; `sharedSeed(name)` без времени/адресов —
РАЗНОЕ ЧИСЛО ВЫЗОВОВ В ВЕТВЯХ = ДЕСИНХРОН), `config` (сначала
`config.link(savedata)`! один ключ `cfg:<имя>`; dirty+`save()`; `_version`+
migrate; client-конфиг — НЕ источник логики).

Пример (только shared/server; вызовы RNG одинаковы у всех!):

```lua
local r = rng.new(12345)
local center = vec.v3(100, 0, 50)

scheduler.after(5, function()
    local targets = query.units{
        around = { x = center.x, z = center.z, radius = 20 },
        alive = true
    }

    for _, unit in ipairs(targets) do
        local damage = mathx.round(r:range(100, 200))
        status.add(unit.handle, "burning", { damage = damage, duration = 5 })
    end
end)
```

## 5. Замена файлов — assets/

`assets/<путь как в игре>` заменяет файл игры: `assets/data/shaders/tone/tone.frag`.
Любые файлы, которые читает движок. Нужен перезапуск игры. Конфликт — побеждает больший `priority`.

## 6. Патчи скриптов игры — patches/

Файл `patches/<путь в игре>.patch`, например `patches/data/scripts/lib/unit.script.patch`.
Скрипты игры: `data/scripts/lib/*.script` (библиотеки функций), `data/scripts/**/*.inc` и `*.aix`
(состояния), `data/gui/menu.inc/*.inc` (интерфейс). В библиотеках каждая функция оформлена так:
объявление с начала строки, `begin` с начала строки, последний `end;` с начала строки.

```
@@ комментарий
@replace <Имя>      -- заменить функцию целиком (текст ниже — полное новое объявление и тело)
@begin <Имя>        -- строки ниже вставить сразу после begin функции
@end <Имя>          -- перед последним end; функции
@before <Имя>       -- перед функцией (сюда — новые функции, которые она или другие вызывают)
@after <Имя>        -- после функции
@append             -- в конец файла
@find               -- точный текст (с отступами, можно несколько строк)
@with               -- на что заменить (все вхождения)
```

Правила: в Pascal игры функцию надо объявить выше места вызова; `const`-параметры менять нельзя
(заведи локальную переменную); итог смотреть в `modloader/cache/<путь>`; ошибка компиляции видна в
логе как `[engine] Compile script error`. Патч меняет правила игры → `multiplayer = "required"`.

## 6а. Новые нации и юниты — content.lua (данные, не код)

Файл `content.lua` в папке мода. Только вызовы `nation{...}` и `unit{...}` с данными; `load`, `require`,
файлы недоступны. Выполняется при запуске игры, до Lua-модов.

```lua
nation { sid = "zap", from = "ukr", name = { ru = "...", en = "..." },   -- sid: 3 буквы, from: нация игры со зданиями (не tat, lit, mis)
         remove = { "jannisary" }, resources = { gold = 500 } }         -- убрать юниты шаблона; прибавка к стартовым ресурсам
unit {
    sid = "serdiukvet", from = "serdiuk",       -- from: существующий юнит (data/objects/units/<from>.prop)
    nations = { "ukr", "zap" },                  -- обязательно
    cell = { 1, 1 },                             -- клетка панели найма; по умолчанию клетка родителя
    base = { maxhp = 150, speed = 1.2, ["price[3]"] = 20, ["weapon[1].damage"] = 20 },   -- TObjBase
    prop = { vision = 900 },                     -- TObjProp
    name = { ru = "...", en = "..." }, description = { ru = "...", en = "..." },
    actor = nil, mesh = nil, material = nil, animations = nil, icon = nil,   -- свои ресурсы (имена из .lib/.mat)
}
```

Историческое сражение (своя карта в меню «Исторические сражения»):

```lua
battle {
    sid = "poltava", from = "battle1",        -- from: battle1..battle8 — позиции и число игроков берутся у него
    map = "maps/poltava.map",                 -- файл .map внутри папки мода (сделанный в редакторе игры)
    maxplayers = 4,                           -- по желанию
    name = { ru = "...", en = "..." }, description = { ru = "...", en = "..." },
}
```

Своя статичная модель (здание, декор) из Blender — **только .glb** (File → Export → glTF 2.0, формат glTF Binary):

```lua
model {
    file = "models/house.glb",                               -- внутри мода; все меши сцены с их трансформациями
    osm = "data/actors/buildings/ukr/ukrcen.osm",            -- какую модель игры заменить (путь из .actor)
    texture = nil,     -- по желанию: какую текстуру игры заменить; без него — текстура материала с именем модели (ukrcen)
    image = nil,                                             -- по желанию: своя PNG/JPEG в моде вместо картинки из .glb
    playercolor = false,                                     -- true: альфа картинки = где красить цветом игрока
}
```

В Blender: Z вверх, лицом к −Y, 1 единица ≈ 1 м; модификаторы применять при экспорте.
Несколько материалов со своими картинками — можно: модлоадер склеит картинки в одну текстуру-атлас (сетку)
и пересчитает UV. В атласе картинка не может повторяться, поэтому UV за пределами 0..1 (тайлинг)
зажимаются — для повторяющихся текстур сделайте развёртку в пределах картинки. Модлоадер сам
переводит оси, UV и обход треугольников. Путь `osm` — в `.actor` модели (`MeshObjects.LoadFromFile`),
`texture` — в `.mat` (`Material.Texture.image`). Анимированные модели (.oss) — пока нет.

Стадии стройки и руины здания — в том же .glb: верхние объекты сцены (или пустышки-родители) с именами
`stage1`…`stage4` (стадии стройки) и `death1`, `death2` (руины); остальные объекты — готовое здание.
Из `osm = ".../ukrcen.osm"` получаются `ukrcen1.osm`…`ukrcen4.osm`, `ukrcen_death1.osm`, `ukrcen_death2.osm` —
те же имена, что в `.actor` здания (игра переключает их сама, `building.inc/ontagstates.inc`).
Леса, лестница и обломки — отдельный дочерний объект здания (`autochildrenproperty` в `.prop`, модели
в `attach/`, материалы игры `scaffold` и `debris`): объекты `attach`, `stage1a`…`stage4a`, `death1a`, `death2a`
-> `attach/ukrcena.osm`, `attach/ukrcen1a.osm`…, `attach/ukrcen_death1a.osm`. Их текстура — общая для всех
строек игры, `texture` модели на них не действует. Нет объекта — остаётся модель игры.

Нации игры: aus fra eng spa rus ukr pol swe pru ven tur alg net den por pie sax bav hun swi sco tat lit
(mis — служебная). Новая нация = копия шаблона. Новый юнит = копия родителя + `base`/`prop`;
нанимается там же, где родитель. Характеристики можно менять и позже в партии через `balance`.

## 7. Шаблоны

### 7.1. Клиентский мод: клавиша и чтение

```lua
-- manifest.lua
return { id = "hp_report", name = "HP Report", version = "1.0.0", client = "client.lua", multiplayer = "optional" }

-- client.lua
input.bind("F7", function()
    if not game.isInGame() then return end
    local me = native.GetPlayerIndexInterfaceIO()
    local total, n = 0, 0
    for _, h in ipairs(objects.list(me)) do
        local o = objects.read(h)
        if o and not o.bdead then total, n = total + o.hp, n + 1 end
    end
    log.info(string.format("юнитов и зданий: %d, HP всего: %d", n, total))
end)
```

### 7.2. Баланс для всех (shared)

```lua
-- manifest.lua
return { id = "strong_musketeers", name = "Strong Musketeers", version = "1.0.0",
         shared = "shared.lua", multiplayer = "required" }

-- shared.lua
events.on("game.start", function()
    balance.setHP("musketeer18", 200)
    balance.setDamage("musketeer18", 40, 1)       -- оружие 1 — выстрел
    balance.set("musketeer18", "price[3]", 30)    -- золото
end)
```

### 7.3. Клиент просит — хост решает

```lua
-- manifest: client = "client.lua", server = "server.lua", multiplayer = "required"
-- client.lua
input.bind("F6", function() net.send("give_gold", { amount = 500 }) end)
net.on("gold_given", function(data) log.info("игроку " .. data.player .. " выдано " .. data.amount) end)

-- server.lua
net.on("give_gold", function(data, from)
    local who = game.playerIndexOf(from)
    local amount = math.min(tonumber(data and data.amount) or 0, 1000)   -- проверять данные клиента
    player(who):add("gold", amount)
    net.broadcast("gold_given", { player = who, amount = amount })
end)
```

### 7.4. События юнитов

```lua
-- shared.lua (или server.lua)
local kills = {}
events.on("unit.death", function(_, handle, basename)
    kills[basename] = (kills[basename] or 0) + 1
end)
events.on("unit.damage", function(_, attacker, target, damage)
    if damage > 100 then log.info("сильный удар", attacker, "->", target, damage) end
end)
events.on("unit.order", function(_, handle, kind, target, x, z)
    if kind == "attackobj" and target == 0 then return true end   -- отменить (shared — на всех машинах)
end)
events.on("game.end", function() log.info(show(kills)) end)
```

### 7.5. HUD на странице

```lua
-- client.lua
events.on("game.start", function() web.open("hud.html"); web.passthrough(true) end)
events.on("game.end", function() web.close() end)
```

```html
<!-- web/hud.html: фон прозрачный, иначе клики не дойдут до игры -->
<html><body style="margin:0;background:transparent">
<div id="box" style="position:absolute;right:16px;bottom:16px;background:rgba(0,0,0,.7);color:#fc6;padding:8px"></div>
<script>
const wait = setInterval(() => {
  if (typeof window.game !== 'object') return;
  clearInterval(wait);
  setInterval(async () => {
    const h = await game.api('buildings.selected');
    document.getElementById('box').textContent = h ? JSON.stringify(await game.api('buildings.info', h)).slice(0, 200) : '';
  }, 500);
}, 50);
</script></body></html>
```

### 7.6. Своя кнопка вместо родной

```lua
-- client.lua
screens.onButton("MainMenu", function(button)
    if button == "Settings" then web.open("settings.html"); return true end
end)
```

### 7.7. Патч функции игры

```
@@ patches/data/scripts/lib/miscext2.script.patch — урон x2
@before _misc_DoDamage
function ML_DamageMultiplier : Integer;
begin
   Result := 2;
end;

@find
            var damage : Integer = indamage;
@with
            var damage : Integer = indamage * ML_DamageMultiplier;
```

## 8. Частые ошибки

| ошибка | причина | как надо |
|---|---|---|
| `only server/shared scripts and pages can do this` | вызов `units/buildings/balance/state.set` в client | перенести в server/shared или в страницу (`game.api`) |
| `native.X can change the game — call it from server scripts` | меняющий натив на клиенте | server/shared |
| `player(): no local player outside of a game` | вызов вне партии | проверить `game.isInGame()` |
| статы «не меняются» | поменяли до `game.start` или только у одного игрока | `game.start`, `shared`, `balance.setHP/setDamage/setSpeed` для живых |
| рассинхрон в сети | логика в `server`/`client` меняет мир | `shared`, одинаково у всех |
| страница перехватывает все клики | непрозрачный фон | `background: transparent` + `web.passthrough(true)` |
| `window.game` undefined | страница ещё не получила мост | ждать `typeof window.game === 'object'` |
| тормоза | `game.exec`/`state`/`units` в цикле по юнитам на каждом такте | `objects.*`, реже (раз в N тактов) |
| патч `block skipped` | `@find` не совпал точно / нет функции | скопировать текст из файла игры с отступами |
