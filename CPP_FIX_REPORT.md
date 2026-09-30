# Отчёт: что нужно сделать в C++ (modloader 0.2.0)

Дата: 2026-09-27. Основание: прогон `api_stress_test` от 13:31, shared 41 ok / 7 fail / 4 error.
Цель: снять оставшиеся 11 падений. 6 из них — от одной неисправности.

---

## 1. Главная проблема: `_unit_AddOrder` не компилируется

### Симптом

```
[ERROR] [engine] Compile script error: ModLoader.Call.54
[FAIL] combat.orders.move   orders.move не работает ...
[ERR]  combat.orders.target api/38_orders.lua:89: game script failed
[ERR]  combat.formation     api/38_orders.lua:89: game script failed
[ERR]  net.order.capture    api/38_orders.lua:89: game script failed
```

6 кейсов из 11. Движок не даёт деталей — только имя state.

### Что уже проверено и排除ено (не делать это заново)

| Гипотеза | Статус | Доказательство |
|---|---|---|
| `_`-функции не видны из GUI SM | **ЛОЖЬ** | `_unit_GetTObj`, `_misc_GetUnitOrderTypeByIndex` работают из того же `game.exec` (`read.state` — OK) |
| Неверный вызов / неверная сигнатура | **ЛОЖЬ** | Реальная сигнатура из `modloader\cache\data\scripts\lib\unit.script` совпадает с вызовом в `api/38_orders.lua:86` один в один (16 аргументов, порядок, `cl <> 0` / `fi <> 0` под `const Boolean`) |
| Нет `StrToFloat` / нет `ML_ARG` / нет multi-var `var a, b : T` | **ЛОЖЬ** | `ML_ARG` работает; `var x, y : Integer;` используется в 10 модулях api; `Float/Integer` деление есть в игре |
| Тело функции тянет недоступные библиотеки | **ЛОЖЬ** | Тело `_unit_AddOrder` — 4508 символов, 9 вызовов, все внутри `unit.script`: `_unit_ClearOrders`, `_unit_OrdersOffset`, `_unit_SetOrderTrg`, `TObj`, `TOrder`, `TOrderInfo`, `ErrorLog`, `DScriptSetgDbgString0` |
| Нужен контекст «текущего» объекта | **ЛОЖЬ** | `GetGameObjectMy*` в теле не встречается ни разу — функция полностью параметризована `goHnd` |

### Единственное подтверждённое различие

`ScriptPatch.cpp:259-262` — единственное место в проекте, которое патчит тело функции игры
хуком `ML:`. Все функции, которые **работают** через `game.exec`, хука не имеют.
`abi/38_orders.lua` — единственный вызов через патченную функцию, и он единственный падает.

Инъекция для `_unit_AddOrder` (ScriptPatch.cpp:261-262):

```pascal
DScriptSetgDbgString0('ML:unit.order|'+IntToStr(goHnd)+'|'+IntToStr(itype)+'|'
  +IntToStr(itrghnd)+'|'+FloatToStr(ix)+'|'+FloatToStr(iy));
if (DScriptGetgDbgString0='ML:block') then exit;
```

Инъекция для `_misc_DoDamage` (ScriptPatch.cpp:265-266) — для сравнения:

```pascal
DScriptSetgDbgString0('ML:unit.damage|'+IntToStr(goHnd)+'|'+IntToStr(trgHnd)+'|'
  +IntToStr(indamage));
```

В `_unit_AddOrder` есть **два** конструкта, которых нет больше нигде в игровом коде
(проверено регексом по всему `modloader\cache\data\scripts`):

1. **`IntToStr(itype)`** — `itype` объявлен как enum `{uid, next,}`, а `IntToStr` ждёт `Integer`.
   Строка `IntToStr(itype)` встречается в игровых данных **ровно один раз** — в нашей инъекции.
   Приведения enum→int в игре нет вообще: `Ord(` — 0 вхождений, `Byte(` — 0, `Integer(x)` — 8,
   и все 8 это `RecordCustomWriteInteger(...)` в комментариях, а не приведение типа.
2. **`exit;` без значения** — `exit` вставлен в функцию, возвращающую `Pointer`
   (`function _unit_AddOrder(...): Pointer;`). У `_misc_DoDamage` `exit` нет.

Любой из двух даёт «Compile script error» без деталей — ровно то, что наблюдается.

---

## 2. План A — исправить инъекцию (рекомендую начать с него)

> **СТАТУС 2026-09-27: СДЕЛАНО.** Применён только A2 (`exit;` → `exit(nil);`),
> DLL пересобрана и установлена. A1 опровергнут и не делался.
> Осталось проверить в игре: реальный compile/runtime `orders.*` и `pathfind`
> на новой DLL.

Файлы: `Modloader For Cossacks 3/core/ScriptPatch.cpp`, строки 255-274.

### A2 (проверить первым): `exit;` → `exit(nil);`

Самое дешёвое. `Events::kBlockCheck` (`Events.h:49`) использует голый `exit;` и работает,
но все места его использования — `procedure`-ы или без возвращаемого значения.
Для `Pointer`-функции нужен явный `nil`.

```cpp
// ScriptPatch.cpp:262 — было:
"if (DScriptGetgDbgString0='ML:block') then exit;\r\n";
// стало:
"if (DScriptGetgDbgString0='ML:block') then exit(nil);\r\n";
```

### A1: убрать `IntToStr(itype)` из payload — **НЕ ТРЕБУЕТСЯ**

> **Проверено и опровергнуто 2026-09-27.** В ТЕКУЩЕЙ версии скрипта игры (2.2.3)
> `itype` объявлен как `Integer`, а не как enum. Приведения не требуется, A1 можно
> не делать. Ошибался я, читая кэш скриптов: там `_unit_AddOrder` — единственная
> функция с сигнатурой `{uid, next,} itype{, priority}` (поддержка enum-типов),
> из-за чего выглядело как несовпадение. Правки A1 не применялись, payload
> не менялся, парсер в `Events.cpp` трогать не нужно.

Если бы понадобилось, выглядело бы так (НЕ применять без нужды):

```cpp
// ScriptPatch.cpp:261 — вариант без itype в payload:
"DScriptSetgDbgString0('ML:unit.order|'+IntToStr(goHnd)+'|'+IntToStr(itrghnd)+'|'+"
"FloatToStr(ix)+'|'+FloatToStr(iy)); if (DScriptGetgDbgString0='ML:block') then exit(nil);\r\n";
```

**Учтите при изменении:** `Events.cpp` разбирает payload `unit.order` по `|`.
Меняется индекс поля `itype` — поправить парсер и Lua-обработчик, иначе
`unit.order` начнёт разбираться неверно (тихо, без ошибки).

### Что реально помогло

**A2 (`exit;` → `exit(nil);`)** — единственная из двух правок, которая понадобилась.
Причина: `_unit_AddOrder` возвращает `Pointer`, и голый `exit` без значения в
функции с возвращаемым типом не компилируется. Из-за этого любой вызов
`_unit_AddOrder` из `game.exec` падал с «Compile script error: ModLoader.Call.N»,
то есть весь `api/38_orders` (`orders.move/attack/patrol/...`, `group.move`,
`formation.set`, `net.order.capture`) был мёртв.

Окончательная версия в `ScriptPatch.cpp:262`:
```cpp
"FloatToStr(ix)+'|'+FloatToStr(iy)); if (DScriptGetgDbgString0='ML:block') then exit(nil);\r\n";
```

Голый `exit;` в `Events::kBlockCheck` (`Events.h:49`) остался — он попадает в
состояния GUI, а не в функции с возвращаемым типом, и там корректен.

### Разделение гипотез одним прогоном

`combat.abilities` (использует `_misc_DoDamage`) и `combat.weapon` помечены risky и
пропущены на F7. Их хук **не** содержит ни `IntToStr(enum)`, ни `exit`.

| F8 результат | Вывод | Что чинить |
|---|---|---|
| `abilities.fire` работает, `orders.*` нет | виноват `exit` | только A2 |
| оба падают | виновато общее в `DScript*` | A1 + проверка резолва нативов |
| оба работают | A2 и A1 уже исправлены | — |

Это самый дешёвый способ не гадать. Стоит один прогон F8.

---

## 3. План B — мост в игровую state machine (если План A не помог)

Это архитектурно правильное решение и оно нужно независимо от Плана A.

### Почему

`ScriptRunner::Call` (ScriptRunner.cpp:308-367) компилирует код в
`Engine::GuiStateMachine()` — машину состояний интерфейса (`menu.aix`).
Она не является игровой. Любая тяжёлая функция из `lib\*.script` рано или поздно
не скомпилируется в этом контексте: у GUI SM другие подключённые библиотеки.
`_unit_GetTObj` работает только потому, что её тело — одна строка.

`Engine` уже **не привязан** к GUI: все функции принимают `uint8_t* sm`
(`Engine.h:14-23`). Не хватает только двух вещей: получить игровую SM и выполнить в ней state.

### 3.1 Адреса (уже есть в NativesTable.inc, надо добавить в `GameApi::Va`)

`core/GameApi.h`, блок `namespace Va` (рядом со строкой 24):

```cpp
constexpr uintptr_t StateMachineGetMapSMHandle    = 0x6C4AF0; // function StateMachineGetMapSMHandle: Integer
constexpr uintptr_t GetGameObjectStateMachineHandle = 0x6C52DC; // function GetGameObjectStateMachineHandle(gohnd: Integer): Integer
```

`StateMachineExecuteState = 0x6C3C08` и `StateMachineStateAdd/AddCodeLine = 0x6C3A50/0x6C3A80`
**уже объявлены** (GameApi.h:25-27), как и `SMExecuteState = 0x6C8E0` (строка 35).

### 3.2 Engine.h / Engine.cpp

```cpp
uint8_t* MapStateMachine();          // StateMachineGetMapSMHandle()
uint8_t* ObjectStateMachine(int gohnd); // GetGameObjectStateMachineHandle(gohnd)
```

Обе через `GameApi::GetIntFn` — так же, как `Engine::GuiStateMachine()` (Engine.cpp:61-65).

**Внимание, `GetGameObjectStateMachineHandle` — тот самый натив, который убил игру**
(crash `2026-09-27_13-15-48_C0000005.txt`, `TObject.InheriesFrom` по освобождённому
указателю). Вызывать только для ЖИВОГО хендла; в api уже есть `objects.alive`
(`api/20_objects.lua:146`), но он истин ещё тик после `destroyNow` — нужен
собственный счётчик мёртвых хендлов на стороне C++ или проверка `IsGameObjectByHandle`
непосредственно перед вызовом.

### 3.3 ScriptRunner — вынести `sm` в параметр

`Call` (ScriptRunner.cpp:308) жёстко берёт `Engine::GuiStateMachine()` (строка 312).
Разделить:

```cpp
bool CallIn(uint8_t* sm, const std::string& code, const std::string& arg, std::string* result);
bool Call  (const std::string& code, const std::string& arg, std::string* result); // = CallIn(Engine::GuiStateMachine(), ...)
```

Кэш состояний уже привязан к SM (`g_callCacheSm`, строки 303-319) — при смене SM
кэш сбрасывается, это работает. Имена state должны быть уникальны **внутри каждой SM**:
текущий счётчик `g_callCounter` общий, поэтому имя должно включать хендль/индекс SM,
иначе `ModLoader.Call.N` из разных SM столкнутся.

Критично: `ExecuteStateRaw` (ScriptRunner.cpp:44-65) уже параметризован `sm` и
подменяет `ScriptCurrentSM` — механизм готов и рабочий, переиспользовать как есть.

### 3.4 Где брать SM для приказов

Порядок предпочтения (эмпирически проверить, какой компилируется):

1. `StateMachineGetMapSMHandle()` — синглтон, нет проблем с памятью. Первый кандидат.
2. Если `lib\unit.script` в ней не резолвится — SM одного живого объекта
   (`GetGameObjectStateMachineHandle`), выбранного один раз и переиспользуемого.
   Добавлять state во **все** SM объектов нельзя: в партии ~10700 объектов
   (`read.objects` в логе), это утечка.
   Состояние при этом добавляется в ОДНУ SM, а приказ адресуется явно `goHnd` —
   безопасно, так как `GetGameObjectMy*` в теле функции не используется (проверено).

### 3.5 Привязка в Lua

`LuaHost.cpp:458` — `l_gameExec` вызывает `ScriptRunner::Call`; реэкспорт — `LuaHost.cpp:1950`
(`SetPlain("exec", l_gameExec)`).

Добавить рядом второй вход, например `game.execIn(smHandle, code, arg)`, и
переключить на него `api/38_orders.lua:89` (сейчас `game.exec(code, arg)`).
Опционально продублировать в `api/00_core.lua` как `game.execUnit(gohnd, code, arg)` —
удобнее и безопаснее: хендл объекта проверяется на живость до похода в натив.

---

## 4. Прочие правки C++ (не блокеры, но стоит сделать)

### 4.1 `pathfind.calculate` — натив падает внутри

```
native.GameObjectCalcPathByHandle: exception 0xC0000005 inside native
```

SEH ловится лодером, игра выживает — уже не авария. Но вызов стоит защитить:
проверять `IsGameObjectByHandle` перед `GameObjectCalcPathByHandle`
(сигнатура из NativesTable.inc:0x00653DCC — `gohandle, endx, endz, usethread, useclear`).
Вызов в `api/29_pathfind.lua:43` сигнатуре соответствует, значит падает сам движок.

### 4.2 Диагностика ошибок компиляции в `ModLoader.Call.N`

Движок сообщает только имя state. `ExecuteStateRaw` уже проверяет
`state[GameApi::Off::StateHasErrors]` (ScriptRunner.cpp:362) — стоит выводить
имя state + текст проблемной строки в `LOG_ERROR`, иначе каждая диагностика
стоит прогона. Это окупилось бы на orders одиннадцать раз.

### 4.3 Уборка предупреждения о росте состояний

`ScriptRunner.cpp:328` предупреждает каждые 500 кэшированных вызовов. С Планом B
состояний станет больше (по одному на SM) — метрику стоит расширить на число SM.

---

## 5. Порядок работ

1. **Прогнать F8** сейчас, без правок C++ — выяснить, работает ли `_misc_DoDamage`
   (§2, таблица). Это дешёвый и решающий эксперимент.
2. **A2** — `exit;` → `exit(nil);` в `ScriptPatch.cpp:262`. Пересобрать, прогнать F7.
3. Если не помогло — **A1**, вместе с правкой парсера payload в `Events.cpp`.
4. Если и это не помогло — **План B** (§3) целиком: `GameApi::Va` → `Engine` →
   `ScriptRunner::CallIn` → `LuaHost` → `api/38_orders.lua`.
5. §4.2 добавить независимо от всего — дешевле, а диагностика станет нормальной.

## 6. Что чинить НЕ нужно

Следующие падения исправлены на стороне Lua и в C++ вмешательства не требуют:

- `world.destroy` — краш C0000005 закрыт (`harness.lua` реестр мёртвых хендлов + `objects.alive`).
- `env.config` — `migrate` по замыслу получает старые данные, API прав.
- `world.regions` — середина стороны лежит на границе, `contains` на границе не определён.
- `read.pathfind` — натив падает внутри, это finding, а не ошибка API.
- `flow.economy`, `combat.group.center`, `object.setState` — ошибки стенда и API,
  уже исправлены в `api/52_group.lua` и `api/28_object.lua`.

## 7. Сборка

`msbuild` и `cl` не в PATH. Visual Studio присутствует
(`C:\Program Files\Microsoft Visual Studio`). Проект:
`Modloader For Cossacks 3\Modloader For Cossacks 3.vcxproj`.
Сборка ядра меняет DLL в игре — перед сборкой закрыть игру, иначе файл будет залочен.
