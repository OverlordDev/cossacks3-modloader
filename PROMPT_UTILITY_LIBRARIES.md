# Промт для ИИ: стандартные utility-библиотеки Cossacks 3 Modloader

## Роль и задача

Ты работаешь как senior C++/Lua-разработчик над существующим проектом Cossacks 3 Modloader. Не ограничивайся описанием идеи: изучи репозиторий, реализуй изменения, собери 32-битную DLL, прогони тесты и разверни результат в папку игры.

Репозиторий:

`C:\Users\illa\Desktop\Cossacks 3 Modloader\Modloader For Cossacks 3`

Папка игры:

`C:\Program Files (x86)\Steam\steamapps\common\Cossacks 3`

Игра — 32-битная, проверенный билд 2.2.3. Modloader уже содержит Lua API примерно `api/00–58`, native catalog и C++-мосты. Нужно добавить не очередной отдельный тестовый мод, а набор стандартных библиотек, доступных всем Lua-модам через API загрузчика.

## Главная цель

Сделай удобный стандартный слой utility-функций, чтобы автору мода не приходилось каждый раз писать собственные реализации математики, векторов, геометрии, планировщика, детерминированного RNG, запросов к объектам, валидации, конфигурации и цветов.

Новые библиотеки должны быть чистыми, предсказуемыми, хорошо документированными и безопасными для lockstep-мультиплеера. Чистые Lua-функции не должны вызывать `game.eval`, читать память или делать native-вызовы без необходимости. Нельзя ломать уже существующие глобалы `math`, `table`, `string`, `os` и уже существующие API-модули.

## Обязательные ограничения

1. Не ломай и не меняй поведение API `00–58` без необходимости.
2. Не добавляй внешние DLL и сторонние зависимости.
3. Не переопределяй стандартные глобальные таблицы Lua. Используй отдельные пространства имён:
   `mathx`, `vec`, `tablex`, `stringx`, `geometry`, `scheduler`, `rng`, `query`, `validate`, `config`, `color`.
4. Каждая публичная функция должна проверять аргументы и выдавать понятную ошибку с названием функции.
5. Не мутируй входные таблицы, если это явно не указано в документации.
6. Не используй `math.random` в shared/server-логике. Для игры нужен отдельный детерминированный генератор.
7. Всё, что может менять мир, состояние юнита, террейн, время или сетевую симуляцию, должно оставаться server/shared-only. Клиентские библиотеки — только чтение и визуальные действия.
8. Не создавай бесконечные таймеры, которые переживают `game.end`, `.reload` или выгрузку мода.
9. Не вызывай тяжёлые native/API-операции в цикле по каждому объекту, если можно получить данные одним запросом или использовать `objects.*`.
10. Не коммить и не отправляй изменения в GitHub без отдельного разрешения пользователя.
11. Не изменяй `tools/modsync.py`, `tools/blender_osm_addon.py`, `tools/__pycache__` и `tools/3ds`.

## Структура новых API-модулей

Добавь следующие файлы в каталог `api` и подключи их к существующему загрузчику в правильном порядке:

```text
api/60_mathx.lua
api/61_vec.lua
api/62_tablex.lua
api/63_stringx.lua
api/64_geometry.lua
api/65_scheduler.lua
api/66_rng.lua
api/67_query.lua
api/68_validate.lua
api/69_config.lua
api/70_color.lua
```

Если в проекте уже есть частичная реализация какого-либо имени, сначала проверь её и совмести API без дублирования. Порядок загрузки должен учитывать зависимости: `validate` и `mathx` раньше библиотек, которые их используют; `scheduler`, `query` и `config` должны подключаться только после доступности событий и savedata.

## 1. `mathx` — безопасная игровая математика

Реализуй:

```lua
mathx.clamp(x, min, max)
mathx.lerp(a, b, t)
mathx.inverseLerp(a, b, value)
mathx.remap(value, inMin, inMax, outMin, outMax)
mathx.round(x, decimals)
mathx.floor(x)
mathx.ceil(x)
mathx.sign(x)
mathx.abs(x)
mathx.approach(current, target, delta)
mathx.moveTowards(current, target, delta)
mathx.smoothstep(edge0, edge1, x)
mathx.smootherstep(edge0, edge1, x)
mathx.pingPong(t, length)
mathx.wrap(value, min, max)
mathx.degToRad(degrees)
mathx.radToDeg(radians)
mathx.angleDiff(a, b)
mathx.normalizeAngle(angle)
mathx.isNearlyEqual(a, b, epsilon)
```

Документируй единицы углов, поведение при одинаковых границах, нулевом диапазоне, `NaN` и бесконечности. `wrap` должен быть корректным и для отрицательных значений. Не меняй стандартную `math`.

## 2. `vec` — векторы карты и пространства игры

Поддержи лёгкие таблицы без обязательных тяжёлых метатаблиц:

```lua
vec.v2(x, y)
vec.v3(x, y, z)
vec.new(value)
vec.clone(v)
vec.isValid(v, dimension)
vec.add(a, b)
vec.sub(a, b)
vec.mul(v, scalar)
vec.div(v, scalar)
vec.neg(v)
vec.length(v)
vec.lengthSquared(v)
vec.normalize(v)
vec.distance(a, b)
vec.distanceSquared(a, b)
vec.dot(a, b)
vec.cross(a, b)
vec.lerp(a, b, t)
vec.rotate2(v, angle)
vec.fromAngle(angle, length)
vec.toAngle(v)
vec.round(v, decimals)
vec.floor(v)
vec.toTable(v)
```

Для координат Cossacks явно зафиксируй соглашение `x/z` карты и высоту `y`. Не путай `vec2(x,z)` с экранными координатами. Нормализация нулевого вектора не должна порождать `NaN`; выбери и задокументируй безопасный результат. Все операции по умолчанию возвращают новые таблицы.

## 3. `tablex` — работа со списками и словарями

Реализуй:

```lua
tablex.contains(t, value)
tablex.indexOf(t, value)
tablex.find(t, predicate)
tablex.map(t, fn)
tablex.filter(t, predicate)
tablex.reduce(t, fn, initial)
tablex.keys(t)
tablex.values(t)
tablex.count(t, predicate)
tablex.isEmpty(t)
tablex.first(t)
tablex.last(t)
tablex.copy(t)
tablex.deepcopy(t, maxDepth)
tablex.merge(a, b)
tablex.mergeDeep(a, b, maxDepth)
tablex.reverse(list)
tablex.shuffle(list, random)
tablex.clear(t)
```

Раздели поведение массивов и словарей в документации. Укажи порядок обхода, обработку `nil`, циклических ссылок, глубину копирования и то, что `shuffle` не должен случайно использовать глобальный RNG. `clear` может мутировать исходную таблицу, остальные функции — не должны без явного указания.

## 4. `stringx` — строки, в том числе русские имена

Добавь:

```lua
stringx.trim(s)
stringx.split(s, separator, keepEmpty)
stringx.join(list, separator)
stringx.startsWith(s, prefix)
stringx.endsWith(s, suffix)
stringx.contains(s, part)
stringx.replaceAll(s, old, new)
stringx.capitalize(s)
stringx.lower(s)
stringx.upper(s)
stringx.utf8Length(s)
stringx.truncateUtf8(s, maxCharacters, suffix)
stringx.padLeft(s, length, fill)
stringx.padRight(s, length, fill)
stringx.formatBytes(bytes)
stringx.escapePattern(s)
```

Особенно тщательно протестируй кириллицу и UTF-8 в `utf8Length` и `truncateUtf8`: нельзя резать строку посередине UTF-8 последовательности. Не завязывайся на локаль Windows. Различия между Lua pattern и обычной строкой должны быть описаны.

## 5. `geometry` — геометрия мира, X/Z

Реализуй функции для скриптовых модов:

```lua
geometry.distance(a, b)
geometry.distanceSquared(a, b)
geometry.inCircle(point, center, radius)
geometry.inRect(point, rect)
geometry.inSector(point, origin, direction, angle, radius)
geometry.closestPointOnSegment(point, a, b)
geometry.distanceToSegment(point, a, b)
geometry.lineIntersection(a1, a2, b1, b2)
geometry.polygonContains(point, polygon)
geometry.polygonCenter(polygon)
geometry.polygonBounds(polygon)
geometry.circlePoints(center, radius, count, startAngle)
geometry.rotatePoint(point, center, angle)
geometry.lookAngle(from, to)
```

Принимай позиции как `{x=..., z=...}` либо совместимый `{x=..., y=..., z=...}`. Для игровой карты игнорируй высоту там, где операция 2D. Явно опиши радианы/градусы, границы сектора, касание границы, параллельные отрезки и вырожденные полигоны.

## 6. `scheduler` — игровой планировщик на `game.tick`

Сделай планировщик, привязанный к игровому времени, а не к `os.clock`:

```lua
local id = scheduler.after(seconds, callback, options)
local id = scheduler.every(seconds, callback, options)
local id = scheduler.at(gameTime, callback, options)
scheduler.cancel(id)
scheduler.cancelGroup(group)
scheduler.clear()
scheduler.debounce(key, seconds, callback, options)
scheduler.throttle(key, seconds, callback, options)
local now = scheduler.now()
local count = scheduler.pending(group)
```

Требования:

- обработка только на `game.tick` в безопасном игровом потоке;
- детерминированный порядок выполнения при одинаковом времени;
- callback-ошибка логируется и не ломает остальные таймеры;
- таймеры очищаются на `game.end`, меню, reload и выгрузке мода;
- `every` не должен накапливать бесконечный backlog после паузы;
- поддержи `group`, `owner` и безопасную отмену;
- не разрешай таймеру случайно пережить матч.

## 7. `rng` — детерминированный генератор

Создай независимый генератор, пригодный для lockstep:

```lua
local r = rng.new(seed)
r:nextInt(min, max)
r:nextFloat()
r:range(min, max)
r:pick(list)
r:chance(probability)
r:shuffle(list)
r:state()
r:setState(state)

rng.seedFromGame()
rng.sharedSeed(name)
```

Одинаковый seed и одинаковая последовательность вызовов должны давать одинаковый результат на машинах игроков. Не меняй глобальный `math.random`. Алгоритм, диапазоны и сериализуемое состояние опиши в документации. `rng.sharedSeed` не должен использовать локальное время, адреса памяти или случайный seed клиента. Предупреди в документации, что разные ветви логики, вызывающие RNG в разном количестве, могут вызвать десинхронизацию.

## 8. `query` — удобные запросы к игровым объектам

Добавь высокоуровневый слой поверх существующих `objects.*`, `units.*` и `buildings.*`:

```lua
query.units(options)
query.buildings(options)
query.objects(options)
query.nearest(options)
query.inArea(options)
query.byType(kind, typeName, options)
query.byPlayer(player, options)
query.enemies(player, options)
query.allies(player, options)
query.first(options)
query.count(options)
```

Поддержи фильтры `player`, `type`, `alive`, `building`, `around`, `radius`, `rect`, `predicate`, `limit`, `sortByDistance`. Результат должен быть предсказуемым и документированным. Используй быстрый список объектов и чтение памяти там, где это уже безопасно; не делай `game.eval` на каждый объект. В документации укажи стоимость операции и запрети тяжёлые полные сканы в каждом `game.tick` без интервала.

## 9. `validate` — единые проверки аргументов

Реализуй:

```lua
validate.number(value, name, options)
validate.integer(value, name, options)
validate.boolean(value, name)
validate.string(value, name, options)
validate.handle(value, name)
validate.position(value, name)
validate.enum(value, allowed, name)
validate.list(value, name, options)
validate.table(value, name)
validate.activeGame(name)
validate.server(name)
validate.client(name)
```

Ошибки должны указывать функцию, параметр и ожидаемый тип. Учитывай отрицательные игровые handles, `nil`, `NaN`, диапазоны и доступность game/server/client context. Не скрывай ошибки молча и не превращай ошибочную позицию в `{0,0}`.

## 10. `config` — конфигурация мода

Сделай простую конфигурацию на основе имеющегося savedata/profile API:

```lua
local cfg = config.load("my_mod", defaults)
cfg:get("key", fallback)
cfg:set("key", value)
cfg:reset("key")
cfg:save()
```

Либо предоставь эквивалентный namespace API, если стиль проекта требует этого. Требования:

- не записывать файл или savedata каждый tick;
- сохранять только при изменении или явном `save`;
- обработать повреждённые и устаревшие настройки;
- поддержать версию схемы и миграцию;
- ограничить глубину и размер таблиц;
- отделить client-only настройки интерфейса от shared/server-данных;
- не разрешать использовать локальную клиентскую конфигурацию как источник игровой логики.

## 11. `color` — единый формат цветов

Реализуй:

```lua
color.rgb(r, g, b)
color.hex(value)
color.rgba(r, g, b, a)
color.withAlpha(c, alpha)
color.lerp(a, b, t)
color.toHex(c, includeAlpha)

color.red
color.green
color.blue
color.white
color.black
color.yellow
color.transparent
```

Выбери один основной диапазон компонентов — например `0..1` или `0..255` — и последовательно используй его во всех функциях. Если поддерживаешь оба формата, сделай преобразование явным и документируй его. Проверь значения за границами, альфа-канал и формат `#RRGGBB`/`#RRGGBBAA`.

## Загрузка, контексты и совместимость

Проверь, как именно текущий `LuaHost` загружает файлы `api/*.lua`. Подключи `60–70` автоматически, не требуя от каждого мода ручного `dofile`. Не затри существующие поля глобального API и не создавай конфликтов имён.

Для каждой функции отметь в документации одну из сторон:

- `pure` — чистая Lua-функция;
- `client` — только клиент;
- `server` — только сервер;
- `shared` — разрешено в детерминированной общей логике;
- `data` — доступно только во время генерации контента.

Особенно проверь `scheduler`, `rng`, `query` и `config` на использование в multiplayer. Любое изменение мира, создание/уничтожение объектов, террейн, время, FOW-запись или игровой state не должно становиться доступным клиенту через utility-библиотеку.

## Тесты

Расширь существующий `tools/api_test` и добавь тесты на все публичные функции и граничные случаи:

- нулевые и отрицательные диапазоны;
- пустые списки и словари;
- `nil`, неправильные типы и отрицательные handles;
- нулевой вектор;
- UTF-8/кириллица;
- вырожденные отрезки и полигоны;
- одинаковые timestamps scheduler;
- отмена, reload и game.end;
- одинаковый seed RNG и восстановление state;
- отсутствие случайной зависимости от времени/адресов;
- сериализация и повреждённая config;
- цвета на границах диапазона.

Не вызывай опасные world-changing native-функции из unit-тестов. Финальный тест должен печатать отчёт в стиле:

```text
utility modules: 11
utility tests: <passed>/<total>
failed: 0
```

## Документация

Обнови:

```text
api/README.md
DOCUMENTATION.md
AI_MODDING_REFERENCE.md
```

Добавь отдельный раздел `Utility Libraries`: назначение, таблица модулей, все функции, параметры, возвращаемые значения, ошибки, пример использования, сторона выполнения, риск десинхронизации и оценка стоимости в hot loop.

Обязательно добавь практический пример вроде:

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
        status.add(unit, "burning", { damage = damage, duration = 5 })
    end
end)
```

Рядом укажи, что такой пример должен выполняться в shared/server-контексте, а случайные вызовы должны быть одинаковыми у всех участников партии.

## Сборка и развёртывание

После реализации:

1. Собери проект именно как 32-битную DLL в существующей конфигурации.
2. Запусти все C++/Lua/API-тесты.
3. Скопируй DLL в папку игры `...\Cossacks 3\modloader`.
4. Скопируй новые `60–70.lua` в `...\Cossacks 3\modloader\api`.
5. Проверь запуск без партии, offline-партию и reload.
6. Проверь, что моды, использующие API `00–58`, работают как раньше.
7. Не включай случайные изменения террейна, времени или спавн в автоматическом multiplayer-тесте.

Если для установки нужны права администратора, не обходи ограничение молча: сообщи точные команды и пути.

## Финальный отчёт

В конце выведи:

- список изменённых файлов;
- какие 11 модулей реально реализованы;
- результаты тестов в формате `passed/total`;
- результат сборки DLL;
- путь установленной DLL;
- путь установленных Lua-модулей;
- результаты ручных проверок;
- найденные ограничения и потенциальные multiplayer/desync-риски;
- что осталось сделать вручную.

Если какая-либо функция невозможна без нового native bridge, не имитируй её заглушкой: укажи причину, найди существующий безопасный native, либо добавь минимальный C++ bridge с whitelist, Lua binding, тестом и документацией.

Главный критерий готовности: другой автор мода должен суметь использовать эти библиотеки без чтения внутреннего C++ кода modloader, а shared/server-скрипт не должен получать скрытый источник рассинхронизации.
