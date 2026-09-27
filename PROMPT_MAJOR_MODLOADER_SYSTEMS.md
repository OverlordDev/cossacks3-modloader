# Промт для ИИ: дипломатия, способности, компоненты, транзакции, локализация, UI RPC и Inspector для Cossacks 3 Modloader

## Контекст проекта

Ты работаешь над существующим Cossacks 3 Modloader, а не над отдельным пользовательским модом.

Репозиторий:

`C:\Users\illa\Desktop\Cossacks 3 Modloader\Modloader For Cossacks 3`

Папка игры:

`C:\Program Files (x86)\Steam\steamapps\common\Cossacks 3`

Игра 32-битная, рабочий билд — 2.2.3. В проекте уже есть C++ DLL, LuaHost, native catalog, events, savedata, objects API, web/CEF overlay, content system, server/client/shared-контексты и множество Lua API-модулей.

## Главная задача

Добавь в сам modloader базовые системные подсистемы, которыми смогут пользоваться разные моды. Не делай решение в виде одного жёстко зашитого демонстрационного мода. API должен быть переиспользуемым, документированным, проверять контексты client/server/shared, работать с lockstep-мультиплеером и не создавать скрытых рассинхронизаций.

Нужно реализовать следующие системы:

1. `diplomacy` — дипломатия, союзы и перемирия с AI и игроками;
2. `abilities` — система способностей юнитов и игроков;
3. `objects.on` — подписки на жизненный цикл и изменения объектов;
4. `components` — компонентная система для модов;
5. `world.transaction` — безопасные транзакции игрового состояния;
6. `locale` — локализация модов из JSON, включая `UI.ATTACK.TITLE`;
7. `ui.rpc` — нормальный двусторонний Lua ↔ CEF RPC;
8. `inspector` — подробный встроенный отладочный inspector объектов, юнитов, событий и native-состояния.

Не ограничивайся описанием. Изучи архитектуру проекта, внеси изменения, добавь тесты, собери 32-битную DLL, установи DLL и Lua API в папку игры, обнови документацию и выдай отчёт.

## Общие правила безопасности

- Не ломай существующие API и моды.
- Не меняй стандартные глобалы Lua без крайней необходимости.
- Все операции, меняющие мир, должны быть `server` или `shared`.
- Клиент не должен самостоятельно решать результат атаки, способности, урона, дипломатии или транзакции.
- Сетевые команды должны иметь стабильный порядок, tick/sequence ID и попадать в Desync Watchdog.
- Не использовать локальное время, адреса памяти, случайные client-only значения или порядок обхода хеш-таблиц для shared-логики.
- Любой callback должен быть изолирован от ошибок: ошибка одного мода не должна ломать весь игровой цикл.
- Все подписки, таймеры, RPC, компоненты и временные состояния должны очищаться на `game.end`, переходе в меню, `.reload` и выгрузке мода.
- Нельзя вызывать тяжёлые native-функции по одному разу на каждый объект в каждом тике без явного разрешения.
- Добавь защиту от рекурсивных callback, бесконечных цепочек событий и повторного вызова после удаления объекта.
- Не добавляй внешние DLL и сторонние зависимости.
- Не изменяй `tools/modsync.py`, `tools/blender_osm_addon.py`, `tools/__pycache__` и `tools/3ds`.
- Не коммить и не отправляй изменения в GitHub без явного разрешения пользователя.

---

## 1. Система дипломатии `diplomacy`

Нужна возможность создавать отношения между игроками и AI. Важно отличать игровую команду от дипломатического отношения: физически пересаживать игроков в другую `team` опасно, потому что это может сломать победу, статистику и распределение игроков. Сначала найди в native catalog реальные функции отношений/альянсов. Если их недостаточно, добавь минимальный безопасный bridge.

### Предлагаемый Lua API

```lua
diplomacy.set(playerA, playerB, "ally")
diplomacy.set(playerA, playerB, "neutral")
diplomacy.set(playerA, playerB, "war")

local relation = diplomacy.get(playerA, playerB)
local allowed = diplomacy.canAttack(playerA, playerB)

diplomacy.truce(playerA, playerB, {
    duration = 300,
    shareVision = true,
    showAsAlly = true,
    cancelQueuedAttacks = true
})

diplomacy.endTruce(playerA, playerB)
diplomacy.shareVision(playerA, playerB, true)
diplomacy.shareControl(playerA, playerB, true)
diplomacy.onChange(function(event) end)
```

### Поведение

При `ally` или активном перемирии:

- игроки не могут атаковать друг друга;
- обычные attack orders между ними отменяются;
- AI не выбирает союзника целью;
- прямой урон между сторонами блокируется на уровне damage guard;
- юниты и здания отображаются как союзные;
- по запросу включается общий туман войны;
- можно включить общий контроль или оставить только союз;
- завершение перемирия возвращает прежние отношения или заданный режим.

Защита должна стоять минимум в двух местах: при создании приказа и непосредственно перед применением урона. Нельзя полагаться только на блокировку клика игрока, потому что AI и native-код могут атаковать иначе.

### Multiplayer

Изменение дипломатии должно выполняться server/shared-кодом. Команда должна иметь:

```text
source player
target players
relation
effective tick
sequence id
duration
```

Проверь симметричность отношений, загрузку сейва, reconnect, AI, завершение времени перемирия и десинхронизацию. Изменения записывай в сетевой журнал и Desync Watchdog.

---

## 2. Система способностей `abilities`

Создай универсальную систему для авиаударов, артиллерии, дронов, дыма, телепортации, национальных бонусов, инженерных действий и уникальных атак.

### Регистрация способности

```lua
abilities.register("airstrike", {
    title = "UI.ABILITIES.AIRSTRIKE.TITLE",
    description = "UI.ABILITIES.AIRSTRIKE.DESCRIPTION",
    side = "shared",
    target = "point",
    range = 80,
    cooldown = 30,
    cost = { gold = 300 },
    charges = 1,
    requires = function(ctx)
        return ctx.player ~= nil
    end,
    execute = function(ctx)
        effects.explosion(ctx.x, ctx.z, {
            damage = 500,
            radius = 12
        })
    end
})
```

### Использование

```lua
local result = abilities.use(player, "airstrike", {
    x = 100,
    z = 50
})
```

Добавь:

- cooldown;
- стоимость ресурсов;
- заряды;
- дальность;
- тип цели: `unit`, `building`, `point`, `area`, `self`, `direction`;
- проверку видимости и доступности;
- server-authoritative execute;
- отмену и отказ с причиной;
- queued/casting/finished/cancelled states;
- callback `onStart`, `onExecute`, `onFinish`, `onCancel`;
- визуальные эффекты, звук, projectile и animation hooks;
- блокировку повторного применения;
- поддержку AI;
- журналирование команды и результата.

### Сетевой контракт

Клиент может отправить запрос на применение способности, но не может сам решить урон, cooldown или результат. Сервер проверяет игрока, ресурс, target, дальность, видимость и состояние матча.

Результат должен быть структурированным:

```lua
{
    ok = false,
    reason = "out_of_range",
    ability = "airstrike",
    tick = 18220
}
```

Добавь защиту от подделанных client RPC, повторной отправки одной команды и использования способности после смерти юнита.

---

## 3. Подписки на объекты `objects.on`

Вместо постоянного полного сканирования `objects.list()` добавь подписки на жизненный цикл и изменения объектов.

### API

```lua
local sub = objects.onSpawn("peasant", function(object, context)
end)

objects.onDestroy(function(object, context)
end)

objects.onDeath(function(unit, context)
end)

objects.onMove(function(unit, oldPosition, newPosition, context)
end)

objects.onStateChange(function(object, oldState, newState, context)
end)

objects.watch(object, { "health", "position", "state" }, callback)
objects.off(sub)
objects.offOwner("my_mod")
```

### Требования

- фильтры по SID/type/player/kind;
- `once`, `owner`, `priority` и `group`;
- callback должен получать стабильный snapshot, а не опасную ссылку на уже удалённый объект;
- после callback обязательно проверять, что объект всё ещё жив;
- подписка не должна держать уничтоженный handle;
- не вызывать Lua callback прямо из произвольного engine worker thread;
- события из native и Lua складывать в безопасную очередь игрового потока;
- одинаковый порядок событий в shared/server;
- ограничение частоты для `onMove` и field watchers;
- очистка всех подписок при reload.

Добавь высокоуровневые события `unit.spawn`, `unit.death`, `unit.destroy`, `building.spawn`, `building.death`, `object.state`, `object.position` с единым форматом данных.

---

## 4. Компонентная система `components`

Сделай Lua-компоненты, привязанные к объектам, но не изменяющие напрямую структуру памяти игры.

### API

```lua
components.register("veteran", {
    schema = {
        kills = "integer",
        level = "integer",
        experience = "number"
    },
    defaults = {
        kills = 0,
        level = 1,
        experience = 0
    },
    side = "shared"
})

components.add(unit, "veteran", {
    kills = 0,
    level = 1,
    experience = 0
})

local veteran = components.get(unit, "veteran")
components.has(unit, "veteran")
components.remove(unit, "veteran")
components.list(unit)
components.query("veteran", { player = 0 })
components.onAdd("veteran", callback)
components.onRemove("veteran", callback)
components.onChange("veteran", callback)
```

### Требования

- компоненты должны быть привязаны к устойчивому object identity, а не только к сырому handle;
- stale handle не должен получить компонент другого объекта после переиспользования памяти;
- schema validation для полей;
- defaults и version;
- миграции компонента;
- сериализация в savegame;
- shared-компоненты сериализуются детерминированно;
- client-only компоненты не попадают в игровую сетевую логику;
- ограничение размера и глубины таблиц;
- удаление компонента при уничтожении объекта;
- владелец компонента и очистка при выгрузке мода;
- запрет на случайное изменение таблицы из другого мода без API.

Добавь системные callback-группы `onTick`, `onSpawn`, `onDeath`, `onDamage`, `onOrder` только с явным включением, чтобы не создавать огромную нагрузку.

---

## 5. Транзакции игрового состояния `world.transaction`

Нужен безопасный способ выполнить последовательность связанных игровых действий. Например, снять золото, создать ракету, применить эффект и записать компонент. Если проверка или действие не прошло, операция должна завершиться предсказуемо.

### API

```lua
local result = world.transaction(function(tx)
    tx.requireResource(player, "gold", 500)
    tx.removeResource(player, "gold", 500)
    local rocket = tx.spawn{
        race = "rocket",
        base = "projectile",
        x = 100,
        z = 50
    }
    tx.addComponent(rocket, "guided", { owner = player })
    tx.applyDamage(target, 300)
    return rocket
end, {
    side = "server",
    label = "airstrike"
})
```

### Реализация

Сначала раздели операции на reversible и irreversible. Для обратимых действий реализуй rollback. Для необратимых действий используй двухфазную модель:

1. validate/prepare;
2. commit;
3. post-commit callbacks.

Транзакция должна иметь ID, source mod, source player, tick и label. Нельзя откатывать уже отправленное сетевое событие без журналирования. Если полный rollback технически невозможен, не притворяйся, что он есть: возвращай `partial_failure` и подробный отчёт.

Защити транзакции от вложенных конфликтов, повторного commit, callback после rollback и вызова с клиентской стороны.

---

## 6. Локализация из JSON `locale`

Сделай встроенную систему локализации модов. Основной сценарий:

```lua
local title = locale.get("UI.ATTACK.TITLE")
local text = locale.get("UI.ATTACK.DAMAGE", { damage = 500 })
```

Мод хранит языковые файлы, например:

```text
mods/my_mod/locale/ru.json
mods/my_mod/locale/uk.json
mods/my_mod/locale/en.json
```

Пример `ua.json` или `uk.json`:

```json
{
  "UI": {
    "ATTACK": {
      "TITLE": "Авіаудар",
      "DAMAGE": "Завдає {damage} шкоди"
    }
  }
}
```

### API

```lua
locale.loadMod(modId)
locale.get("UI.ATTACK.TITLE")
locale.get("UI.ATTACK.DAMAGE", { damage = 500 })
locale.has("UI.ATTACK.TITLE")
locale.language()
locale.setFallback("en")
locale.reload(modId)
locale.list(modId)
```

Поддержи:

- выбор языка из языка игры;
- fallback: текущий язык → fallback языка → key;
- вложенные ключи через точку;
- placeholder `{name}`;
- экранирование и безопасную подстановку;
- plural forms, если это не ломает простой JSON API;
- UTF-8 и кириллицу;
- кэширование JSON после загрузки;
- ошибку с точным путём и номером проблемного JSON;
- namespace мода, чтобы два мода не перезаписывали `UI.ATTACK.TITLE`;
- предупреждение о duplicate key;
- загрузку локализации до открытия CEF-страницы;
- передачу локализованных строк в UI RPC.

Предусмотри вариант:

```lua
locale.get("my_mod.UI.ATTACK.TITLE")
```

и краткий вариант внутри текущего мода:

```lua
locale.get("UI.ATTACK.TITLE")
```

Не выполняй содержимое JSON как Lua-код.

---

## 7. Нормальный Lua ↔ CEF UI RPC `ui.rpc`

Сделай единый двусторонний канал между Lua-модом и страницей CEF. Он должен заменить хаотичные одиночные вызовы `web.open`/ручные JS-строки.

### Lua API

```lua
local channel = ui.rpc.open("my_mod.hud", {
    page = "web/hud.html",
    owner = "my_mod",
    visible = true
})

channel:on("attack_clicked", function(data, reply)
    reply({ ok = true })
end)

channel:emit("state", {
    gold = 500,
    selected = 12
})

local response = channel:request("get_state", {}, {
    timeout = 2
})

channel:close()
```

### JavaScript API

```javascript
Modloader.on("state", data => {
    renderState(data);
});

Modloader.emit("attack_clicked", {
    x: 100,
    z: 50
});

Modloader.request("get_state", {}).then(result => {
    console.log(result);
});
```

### Обязательные свойства

- channel ID и owner mod;
- event names с namespace;
- request/response correlation ID;
- timeout;
- schema validation payload;
- лимит размера сообщения;
- очередь сообщений, если страница ещё не загружена;
- `ready`, `load`, `close`, `error` events;
- безопасная очистка при закрытии браузера;
- отсутствие вызовов CEF из чужого потока;
- отсутствие выполнения произвольного Lua-кода из страницы;
- client-only по умолчанию;
- явный server request через проверенный сетевой command, если это требуется;
- throttling для частых HUD updates;
- batch updates;
- логирование ошибки с mod/channel/event/request ID.

Нельзя позволять CEF-странице напрямую вызывать dangerous native. Страница может только отправить зарегистрированное событие, а Lua-мод сам решает, что с ним делать.

---

## 8. Встроенный Inspector — обязательная система

Создай встроенный отладочный inspector в самом modloader. Он должен открываться через overlay, например клавишей `Insert`, либо отдельной горячей клавишей. Это не простой HUD и не статичный debug text, а интерактивное окно для изучения игры и модов.

### Основные режимы

1. **Cursor Inspector** — объект под курсором.
2. **Selected Inspector** — выбранный юнит/здание.
3. **Object Browser** — список объектов на карте.
4. **Unit/Building Inspector** — подробные данные конкретного объекта.
5. **Event Monitor** — живой поток событий.
6. **Native Inspector** — зарегистрированные native-функции и вызовы.
7. **Mod Inspector** — загруженные моды и их ресурсы.
8. **Network Inspector** — tick, commands, hashes, desync state.
9. **Memory/Object Fields** — безопасное чтение известных полей через schema.
10. **Performance Inspector** — стоимость callback, query, Lua и CEF.

### Object Browser

Покажи:

- тип объекта;
- SID/type name;
- handle и стабильный object ID;
- owner/player;
- позицию X/Y/Z;
- alive/dead/destroyed;
- текущий state;
- actor/model/material;
- здоровье и максимальное здоровье, если доступны;
- текущий приказ;
- цель;
- building stage;
- active components;
- active abilities/effects;
- object subscriptions;
- время появления;
- мод, который добавил компонент или регистрацию.

Добавь фильтры:

```text
type: peasant
player: 0
alive: true
around cursor: 20
has component: veteran
has effect: burning
```

Поддержи сортировку по расстоянию, handle, owner, type и времени появления. Не сканируй десятки тысяч объектов каждый кадр: обновляй список по таймеру, по событию или по запросу пользователя.

### Inspector выбранного объекта

Панель должна иметь вкладки:

#### Summary

- красивое имя;
- тип;
- handle;
- object ID;
- owner;
- alive;
- position;
- native pointer в безопасном read-only виде;
- время жизни.

#### Memory / Schema

Покажи только поля из известной схемы:

- имя поля;
- тип (`i32`, `u32`, `u16`, `byte`, `float`, `pointer`, `string`);
- offset;
- прочитанное значение;
- статус чтения;
- источник schema;
- кнопка copy value.

Добавь отдельный режим `expert`, где можно прочитать адрес+offset только при включённом debug permission. В обычном режиме запрети произвольную запись памяти.

#### State

- текущий engine state;
- переходы state;
- время нахождения в state;
- последние state changes;
- доступные state callbacks.

#### Orders

- текущий приказ;
- очередь приказов;
- target;
- координаты;
- источник приказа: игрок, AI, мод или native;
- tick и sequence ID;
- кнопка копирования Lua-примера, но не автоматическое выполнение.

#### Components

- список компонентов;
- значения полей;
- schema/version;
- владелец компонента;
- время добавления;
- события изменения;
- read-only по умолчанию.

#### Effects / Abilities

- активные эффекты;
- оставшееся время;
- stacks;
- cooldown;
- источник эффекта;
- последние способности;
- причина отказа способности.

#### Network

- owner/player;
- последний синхронный tick;
- последний command ID;
- object hash;
- состояние локального/удалённого объекта;
- подозрение на stale handle;
- отметка в desync report.

### Event Monitor

Сделай фильтры по:

- mod;
- event name;
- object ID;
- player;
- severity;
- tick range.

Показывай время, thread/context, duration, callback, результат и ошибку. Для high-frequency событий добавь sampling и rate limit, чтобы inspector сам не создавал лаги.

### Native Inspector

Для каждой whitelisted native-функции показывай:

- имя;
- адрес;
- сигнатуру;
- разрешённую сторону;
- effect: read/write/world/network;
- deterministic или нет;
- число вызовов;
- последнюю длительность;
- последнюю ошибку;
- caller mod;
- кнопку «копировать Lua-вызов».

Опасные функции должны быть read-only в списке. Не добавляй кнопку вызова native по умолчанию. Для опасных действий нужна отдельная debug permission и явное подтверждение.

### Mod Inspector

Покажи:

- ID/version/name;
- сторона;
- dependencies;
- priority;
- manifest status;
- loaded API modules;
- registered events;
- registered abilities;
- components;
- object subscriptions;
- timers;
- RPC channels;
- content definitions;
- asset count;
- errors/warnings;
- approximate memory and callback time.

Кнопки:

- reload mod — только безопасно и с подтверждением;
- clear subscriptions;
- show files;
- show errors;
- copy diagnostic report.

### Network Inspector

Интегрируй его с Desync Watchdog:

- текущий tick;
- local state hash;
- remote hashes;
- последние команды;
- последние network events;
- RNG streams;
- first mismatch tick;
- отчёт по подозрительным модулям;
- экспорт `desync_report.json` рядом с логом.

### Inspector API для модов

```lua
inspector.registerPanel("my_mod", {
    title = "My Mod",
    icon = "icons/my_mod.png",
    render = function(ctx)
    end
})

inspector.addField(object, "my_value", function(object)
    return components.get(object, "my_component").value
end)

inspector.log("my_mod", "message", data)
inspector.snapshot("airstrike_before")
```

Панели модов должны быть изолированы и не иметь доступа к произвольной памяти.

### Производительность Inspector

- Inspector выключен полностью, пока окно закрыто.
- Никаких полных scans каждый render frame.
- Кэшируй данные и обновляй только изменившиеся поля.
- Ограничь журнал и число объектов.
- Не вызывай CEF API из hook/thread, который не является CEF thread.
- При закрытии уничтожай page/channel/timers/listeners.
- Добавь `low`, `normal`, `high` detail mode.

---

## Архитектурные требования

Для всех систем используй единый lifecycle:

```text
mod load
  → register schemas
  → register handlers
  → game.prepare
  → game.start
  → game.tick
  → game.end
  → menu/reload/unload cleanup
```

Добавь owner token каждого мода. Все timers, subscriptions, components, ability registrations, locale namespaces и RPC channels должны быть удаляемы по owner token.

Добавь проверки:

```lua
context.isClient()
context.isServer()
context.isShared()
context.requireServer()
context.requireShared()
```

Если API вызвано с неправильной стороны, возвращай понятную ошибку, а не случайный native crash.

---

## Тесты

Расширь `tools/api_test` и добавь C++/Lua tests для:

- симметричных и асимметричных дипломатических отношений;
- окончания перемирия по времени;
- блокировки атаки приказом и блокировки урона;
- abilities cooldown, cost, range, target и повторной команды;
- подписки spawn/destroy/death/move/state;
- очистки подписок после reload;
- stale handle и уничтоженного объекта;
- add/get/remove компонентов;
- component schema, migration и save/load;
- transaction commit, validation failure, rollback и partial failure;
- JSON locale, fallback, nested keys и `{placeholder}`;
- duplicate locale keys и UTF-8;
- RPC request/response, timeout, invalid payload, close и reconnect;
- inspector без открытой страницы и при закрытии игры;
- ограничение Inspector по производительности;
- отсутствие вызова server-only API с клиента;
- одинаковый результат shared-команд на двух симулированных сторонах.

Добавь smoke test, который запускает модloader без открытой партии, в offline-партии и после `.reload`. Опасные world-changing операции не должны вызываться автоматически на настоящей карте без явного debug режима.

Отчёт тестов должен содержать:

```text
major systems: 8
tests: <passed>/<total>
failed: 0
```

---

## Документация

Обнови:

```text
api/README.md
DOCUMENTATION.md
AI_MODDING_REFERENCE.md
```

Создай отдельный раздел `Major Modloader Systems` с:

- таблицей API;
- сторонами выполнения;
- примерами Lua;
- схемой lifecycle;
- правилами multiplayer;
- правилами desync safety;
- описанием Inspector;
- описанием JSON-локализации;
- описанием UI RPC;
- лимитами и производительностью;
- примерами ошибок;
- миграцией старых модов.

Обязательно приведи рабочие примеры:

1. перемирие между игроком и AI;
2. авиаудар через `abilities`;
3. ветеранский компонент;
4. транзакция покупки способности;
5. `locale.get("UI.ATTACK.TITLE")` из `ua.json`;
6. CEF HUD через `ui.rpc`;
7. собственная вкладка Inspector.

---

## Сборка и установка

После реализации:

1. Собери 32-битную DLL в существующей конфигурации проекта.
2. Запусти все доступные тесты.
3. Установи DLL в `C:\Program Files (x86)\Steam\steamapps\common\Cossacks 3\modloader`.
4. Скопируй новые Lua API-файлы в `...\Cossacks 3\modloader\api`.
5. Проверь запуск игры, меню, offline-партию, переход в меню и `.reload`.
6. Проверь существующие моды и API `00–58`.
7. Проверь, что Inspector открывается и закрывается без зависания CEF.
8. Не отправляй изменения в GitHub без отдельного разрешения.

Если копирование в папку игры требует прав администратора, сообщи результат и точный путь, не подменяй DLL молча.

## Финальный отчёт

В финальном ответе укажи:

- изменённые C++ файлы;
- новые Lua API-модули;
- новые native bridges и whitelist;
- реализованные системы;
- результаты тестов `passed/total`;
- результат сборки;
- установленные пути DLL/API;
- ручные проверки;
- ограничения и известные проблемы;
- какие функции требуют отдельной проверки в настоящем multiplayer.

Главный критерий готовности: моддер должен суметь сделать дипломатическое перемирие с AI, способность авиаудара, кастомное состояние юнита, локализованный UI и Inspector-панель без ручного патчинга десятков игровых скриптов. При этом клиент не должен иметь возможность самостоятельно сфальсифицировать игровой результат, а shared/server-код не должен создавать скрытый источник рассинхронизации.
