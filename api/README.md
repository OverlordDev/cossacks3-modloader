# api — библиотека модлоадера поверх игры

> Руководство для мододелов (манифест, события, assets, патчи): `../MODDING.md`.

Lua-модули, которые модлоадер грузит в окружение каждого мода и в консоль. Лежат отдельными
файлами, чтобы их можно было дописывать без пересборки: поправил файл — `.lua reload` в консоли.

В игре папка лежит в `<игра>/modloader/api/`, в репозитории — здесь. Файлы грузятся по порядку имён.

| файл | что даёт |
|---|---|
| `00_schema.lua` | **генерируется**, не править. Все типы и глобальные переменные скриптов игры |
| `02_screens_data.lua` | **генерируется** (`tools/gen_screens.py`). Экраны игры и имена тэгов кнопок |
| `01_state.lua` | `state`, `G` — чтение/запись любой переменной игры по пути |
| `10_profile.lua` | `profile` — профиль игрока (звук, управление, язык) |
| `11_options.lua` | `options` — опции движка (графика) |
| `12_saves.lua` | `saves` — сохранения и повторы |
| `13_players.lua` | `players` — участники партии |
| `14_map.lua` | `map` — карта и настройки партии |
| `15_screens.lua` | `screens` — экраны по именам: открыть, нажать кнопку, перехватить кнопку, заменить экран |
| `17_balance.lua` | `balance` — параметры типов юнитов/зданий: читать и менять посреди партии |
| `18_buildings.lua` | `buildings` — здания: что строят, улучшения, очередь, команды игрока, правка логики |
| `19_units.lua` | `units` — выделение, состояние и приказы юнитов; события `unit.order` / `player.order` |
| `20_objects.lua` | `objects` — быстрое чтение юнитов и зданий из памяти (без Pascal), обход всех объектов |
| `22_camera.lua` | `camera` — свободная камера, слежение, лимиты и кинематографические треки (client) |
| `23_minimap.lua` | `minimap` — родная миникарта: зум, позиция, свои иконки/стрелки (client) |
| `24_animation.lua` | `animation` + `model` — анимации, актёры, материалы, масштаб/поворот (shared/client) |
| `25_effects.lua` | `effects` — дым/огонь/взрывы/пыль/подсветка, только картинка (shared/client) |
| `26_decals.lua` | `decals` — воронки/гарь/следы на земле (shared) |
| `27_world.lua` | `world.spawn/destroy/move/pos` — runtime-создание объектов (server/shared) |
| `28_object.lua` | `object` — состояния объектов, destroyIn, waitFor, progress (set: server) |
| `29_pathfind.lua` | `pathfind` — поиск пути, длина по топологии, готовность группы |
| `30_terrain.lua` | `terrain` — raise/lower/smooth/update (server/shared), height везде |
| `31_fow.lua` | `fow` — туман войны, точечная разведка (запись: server/shared) |
| `32_markers.lua` | `markers` — маркеры: миникарта + декаль + подсветка, expiry (client) |
| `33_cutscene.lua` | `cutscene` — катсцены по шагам на камере (client) |
| `34_dbg.lua` | `dbg` — текст в мире, инспектор юнита, луч в рельеф (client) |
| `35_netrec.lua` | `netrec` — локальный журнал шагов/приказов/хешей к рассинхрону (shared) |
| `36_time.lua` | `time` — скорость игры, пауза (server/shared) |
| `37_sound.lua` | `sound` — звуки излучателей, громкость/луп (client, экспериментально) |
| `38_orders.lua` | `orders` — приказы через _unit_AddOrder: move/attack/patrol/guard/queue/cancel (server) |
| `39_formation.lua` | `formation` — построения line/column/wedge/square/circle + приказы |
| `40_weapon.lua` | `weapon` — снаряды движка + урон abilities, залпы, кассеты (детерминировано) |
| `41_status.lua` | `status` — burning/poison/regen/stunned/invisible + свои эффекты |
| `42_targeting.lua` | `targeting` — inCircle/nearest/inCone/los по рельефу (везде) |
| `43_ai.lua` | `ai` — автоматы поведения поверх orders/targeting |
| `44_scenario.lua` | `scenario` — цели/волны/диалоги для кампаний |
| `45_economy.lua` | `economy` — абстрактные ресурсы в savedata + производство |
| `46_panel.lua` | `panel` — панели поверх ui.* без CEF (client) |
| `47_attachments.lua` | `attach` — PFX со смещением, следование, автоуборка |
| `48_vision.lua` | `vision` — дальность типов, раскрытие, ночь (share/детекторов нет в движке) |
| `49_replay.lua` | `replay` — метки + трек камеры поверх netrec (playFrom невозможен) |
| `50_profiler.lua` | `profiler` — счётчики exec/get, время, память Lua |
| `51_content.lua` | `content` — проверка модов/версий + permissions из манифеста |
| `52_group.lua` | `group` — отряды движка: состав, центр, движение, строй, stretch |
| `53_behaviour.lua` | `behaviour` — физика: импульсы, отдача, подброс, blast (server) |
| `54_regions.lua` | `regions` — Lua-полигоны: вход/выход, block приказов (нативов AIRegion нет) |
| `55_tracks.lua` | `tracks` — сеть TrackNode: узлы, связи, длина пути |
| `56_gui.lua` | `gui` — родные элементы без CEF поверх ui.* (client) |
| `57_native_catalog.lua` | `NATIVE_CATALOG` + `native.info()` — все 4856 (генератор) |
| `58_steam.lua` | `steam.setMatch/setOpponent/playedWith/myId` — Rich Presence (client) |

| `60_mathx.lua` | `mathx` — clamp/lerp/wrap/углы (pure) |
| `61_vec.lua` | `vec` — v2/v3, карта: z вторым компонентом (pure) |
| `62_tablex.lua` | `tablex` — map/filter/deepcopy/merge/shuffle (pure) |
| `63_stringx.lua` | `stringx` — split/trim/UTF-8 incl. кириллица (pure) |
| `64_geometry.lua` | `geometry` — круг/сектор/сегменты/полигоны, радианы (pure) |
| `65_scheduler.lua` | `scheduler` — after/every/debounce на game.tick (везде) |
| `66_rng.lua` | `rng` — детерминированный ГСЧ для lockstep (shared) |
| `67_query.lua` | `query` — сканы объектов записями, O(n) (везде, чтение) |
| `68_validate.lua` | `validate` — проверки аргументов (pure) |
| `69_config.lua` | `config` — конфиг на savedata, нужен link(savedata) |
| `70_color.lua` | `color` — цвета 0..255, hex (pure) |
| `21_abilities.lua` | `abilities` — server/shared способности с cooldown и area damage через штатный `_misc_DoDamage` |
| `90_call.lua` | `api_call` — вход для страниц (`game.api` в JS) |

Справочник по всем переменным и полям игры — `GAME_STATE.md`, по экранам и кнопкам — `GAME_SCREENS.md`.

## Как пользоваться

Из Lua мода:

```lua
local volume = profile.get("sndmaster")
for _, p in ipairs(players.list()) do log.info(p.name, p.team) end
local gen = map.settings().gen
```

Из страницы (HTML в папке мода):

```js
const list = await game.api('saves.list');          // [{ name, date }, ...]
await game.api('profile.set', 'sndmaster', 0.5);    // любые аргументы, ответ — объект
const slot = await game.api('state.read', 'gMap.players[0]');
```

`game.api('a.b', x, y)` вызывает в игре функцию `a.b(x, y)` и возвращает результат через JSON.

## Способности и взрывы (`abilities`)

`abilities` работает только на `server`/`shared` и создаёт area damage через штатную систему
урона игры. Поддерживаются визуальные эффекты `cannon`, `howitzer`, `grenade` и `none`.

```lua
-- server.lua / shared.lua
abilities.define("airstrike", {
    cooldown = 20,
    damage = 100000,
    radius = 10,
    target = "all",       -- "all", "units" или "buildings"
    effect = "cannon",    -- "cannon", "howitzer", "grenade" или "none"
    ignorePeace = true,    -- урон во время мирного периода
})

net.on("airstrike.request", function(data, from)
    local player = game.playerIndexOf(from)
    local ok, hit, wait = abilities.fire("airstrike", data.x, data.z, { owner = player })
    net.broadcast("airstrike.result", { ok = ok, hit = hit, wait = wait })
end)
```

Клиент может вызвать удар по точке под курсором без выбора юнита:

```lua
-- client.lua
input.bind("F6", function()
    if not game.isInGame() then return end
    local x, _, z = native.GetCurrentMouseWorldCoord()
    if x then net.send("airstrike.request", { x = x, z = z }) end
end)
```

`abilities.fire(id, x, z, opts)` возвращает `true, hitCount`; `hitCount` — число объектов,
попавших в область, а не гарантированное число смертей. `opts` может переопределить
`damage`, `radius`, `target`, `effect`, `ignorePeace`, `weaponKind`, `source` и `owner`.

## Чтение и запись переменных игры

`state` знает тип каждого поля из схемы и сам выбирает, как его читать:

```lua
state.get("gProfile.sndmaster")        -- 0.75 (дробное)
state.get("gMap.players[2].name")      -- "Cossack" (строка)
state.read("gMap.players[2]")          -- вся запись таблицей, ОДНИМ вызовом скрипта
state.read("gMap.settings", 2)         -- с вложенными записями на 2 уровня
state.list("gMap.players")             -- все элементы массива
state.set("gProfile.sndmaster", 0.5)   -- запись

G.gMap.players[2].team                 -- то же через точку
G.gProfile.sndmaster = 0.5
```

Правила, которые важно знать:

- **Читать можно отовсюду, писать — только серверу.** На клиенте `state.set` бросит понятную
  ошибку. Страницы работают с правами консоли, им писать можно.
- **Для записей используйте `state.read`, а не много `state.get`.** Каждый `get` — отдельный вызов
  скрипта игры; `read` собирает всю запись в одну строку за один вызов.
- **Ошибки называют, что не так.** Опечатка в поле — `state: 'gProfile.x': no field 'x'`, а не падение.

## Как добавить модуль

1. Найти, как это делает сама игра: экраны — `data/gui/menu.inc/*.inc`, библиотека —
   `data/scripts/lib/*.script`, нативы — `GAME_API.md`.
2. Если данные лежат в глобальной переменной — брать их через `state` (типы уже известны).
   Если через натив — через `native.<Имя>`. Проверить, что натив существует:
   `grep "function <Имя>(" "Modloader For Cossacks 3/core/NativesTable.inc"`.
3. Создать `api/NN_имя.lua` с глобальной таблицей и шапкой-комментарием с примерами.
   На верхнем уровне файла — НИКАКИХ `events/net/savedata/log/ui.button`: их нет
   в базовом окружении (ошибка загрузки в игре). Таймеры — через базовые
   `events.on/off` (есть везде), сеть/хранилище/кнопки — только через `link()`,
   лог — через `rawget(_ENV, "log")`. Проверка: `lua tools/api_test/strict.lua`.
4. Дописать проверки в `tools/api_test/run.lua` и, если нужно, подставные данные в
   `tools/api_test/fake_game.lua`.
5. Прогнать тесты, скопировать папку в игру, `.lua reload`.

Образец модуля — `12_saves.lua`: он короткий и показывает оба приёма.

## Проверка без игры

```bash
lua tools/api_test/run.lua
```

Подставная игра (`fake_game.lua`) понимает те же вызовы, что модлоадер (`game.eval*`, `game.exec`,
нужные нативы), и держит состояние в обычной таблице. Интерпретатор Lua собирается скриптом
`tools/api_test/build_lua.ps1` из исходников в `external/lua`.

## Когда игру обновили

```bash
python tools/gen_game_api.py "C:/Program Files (x86)/Steam/steamapps/common/Cossacks 3"
```

Пересоздаёт `00_schema.lua` и `GAME_STATE.md` из скриптов игры.

## Чего пока нет

- **Кампании** — список и описания живут в отдельных файлах кампаний, не в глобальных
  переменных; нужен разбор `data/gui/menu.inc/showcampaign.inc`.
- **Лобби и комнаты** — сетевые данные, обновляются по событиям; нужен разбор `showinternetshell.inc`
  и событий `OnLanEvent`.
- **Юниты** — статы типов есть (`balance`), события жизни — `unit.spawn/death/destroy`, `building.*`. Нет: урона, приказов, данных конкретного юнита (TObj).
