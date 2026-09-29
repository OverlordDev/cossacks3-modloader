---@meta
-- Cossacks 3 Modloader: глобальные объекты, которые создаёт сама DLL (C++).
-- Модули из <игра>/modloader/api/*.lua (state, units, buildings, balance, objects, ...) расширение
-- подключает прямо из игры, здесь их нет — они всегда совпадают с установленным модлоадером.
--
-- Источник: AI_MODDING_REFERENCE.md. Файл нужен только редактору, в игру не попадает.

-- ===================================================================================================
-- Общие функции
-- ===================================================================================================

---@class Cs3Log
---@field info fun(...: any) Сообщение в консоль и modloader.log с именем мода
---@field warn fun(...: any)
---@field error fun(...: any)
log = {}

--- То же, что `log.info`.
---@param ... any
function print(...) end

---@class Cs3Mod
---@field id string Идентификатор мода из manifest.lua
---@field name string
---@field version string
---@field side "client"|"server" В какой среде выполняется этот скрипт
---@field files fun(dir: string): string[] Имена файлов в папке мода (`mod.files("web/img")`)
mod = {}

--- Таблица в читаемый текст (для логов и консоли).
---@param value any
---@param depth? integer Сколько уровней вложенности показывать
---@return string
function show(value, depth) end

-- ===================================================================================================
-- events
-- ===================================================================================================

---@alias Cs3EventName
---| "game.menu" # вошли в главное меню
---| "game.prepare" # начало создания партии (можно менять world{})
---| "game.start" # партия загружена
---| "game.tick" # каждый такт партии (часто! лёгкий код)
---| "game.end" # выход из партии
---| "unit.spawn" # (handle, basename)
---| "unit.death" # (handle, basename)
---| "unit.destroy" # (handle, basename)
---| "building.spawn" # (handle, basename)
---| "building.death" # (handle, basename)
---| "building.destroy" # (handle, basename)
---| "unit.damage" # (attacker, target, damage)
---| "unit.order" # (handle, type, target, x, z); return true — отменить (в сети только в shared)
---| "player.order" # (order); return true — отменить
---| "net.connect" # (payload)
---| "net.disconnect" # (payload)
---| "save.loaded" # загружен сейв, savedata уже содержит его данные
---| "*" # все события подряд (отладка)

---@alias Cs3OrderType
---| "none" | "move" | "attackobj" | "gainres" | "produce" | "patrol" | "attackpoint"
---| "continueattackpoint" | "performupgrade" | "fishing" | "creategates" | "buildwallcontinue"
---| "buildwall" | "gotomine" | "gototransport" | "leavetransport" | "leavebuilding" | "build"
---| "guard" | "repair" | "exitunits"

---@class Cs3PlayerOrder
---@field kind "move"|"attack"|"attackpoint"|"guard"|"build"|"enter"|"gather"|"patrol"
---@field target integer Хендл цели (attack, guard, build, enter, gather)
---@field x number Точка (move, attackpoint, patrol)
---@field z number
---@field group integer Хендл группы (move: событие на каждую выделенную группу)

---@class Cs3Events
events = {}

--- Подписаться на событие. Вернуть `true` из обработчика — отменить (там, где событие это допускает).
--- Первый аргумент обработчика — имя события, дальше аргументы события.
---@overload fun(name: "game.menu"|"game.prepare"|"game.start"|"game.tick"|"game.end"|"save.loaded", fn: fun(event: string))
---@overload fun(name: "unit.spawn"|"unit.death"|"unit.destroy"|"building.spawn"|"building.death"|"building.destroy", fn: fun(event: string, handle: integer, basename: string))
---@overload fun(name: "unit.damage", fn: fun(event: string, attacker: integer, target: integer, damage: number))
---@overload fun(name: "unit.order", fn: fun(event: string, handle: integer, type: Cs3OrderType, target: integer, x: number, z: number): boolean?)
---@overload fun(name: "player.order", fn: fun(event: string, order: Cs3PlayerOrder): boolean?)
---@overload fun(name: "net.connect"|"net.disconnect", fn: fun(event: string, payload: any))
---@param name Cs3EventName|string
---@param fn fun(event: string, ...: any): boolean?
---@return integer id Для `events.off`
function events.on(name, fn) end

---@param id integer
function events.off(id) end

--- Создать событие `gui.<Состояние>` в начале (или в конце) состояния GUI.
---@param state string Например "ShowHud"
---@param atEnd? boolean
function events.hook(state, atEnd) end

-- ===================================================================================================
-- game
-- ===================================================================================================

---@class Cs3Game
---@field side "client"|"server"
game = {}

--- Значение выражения Pascal игры строкой.
---@param expr string
---@return string
function game.eval(expr) end
---@param expr string
---@return integer
function game.evalInt(expr) end
---@param expr string
---@return number
function game.evalFloat(expr) end
---@param expr string
---@return boolean
function game.evalBool(expr) end

--- Выполнить код Pascal игры (только server/shared). Результат — строка из `ML_RET(...)`.
--- ML_ARG в коде равен `arg`. ~1 мс на вызов — не вызывай в цикле на каждом такте.
---@param code string
---@param arg? string
---@return string
function game.exec(code, arg) end

--- Асинхронно выполнить код Pascal без результата (server/shared).
---@param code string
function game.run(code) end

--- Команда чата игры, например `"res all 5000"` (server/shared).
---@param cmd string
function game.command(cmd) end

---@return "offline"|"host"|"client"
function game.mode() end
--- true — эта машина решает игру (одиночка или хост).
---@return boolean
function game.isAuthority() end
---@return boolean
function game.isInGame() end
--- Индекс игрока по отправителю из `net.on`.
---@param from any
---@return integer
function game.playerIndexOf(from) end

-- ===================================================================================================
-- player, world
-- ===================================================================================================

---@class Cs3Player
---@field index integer
---@field food number
---@field wood number
---@field stone number
---@field gold number
---@field iron number
---@field coal number
local Cs3Player = {}
--- Прибавить ресурс (server/shared).
---@param resource "food"|"wood"|"stone"|"gold"|"iron"|"coal"
---@param amount number
function Cs3Player:add(resource, amount) end

--- Игрок этого компьютера (только в партии) или игрок по индексу.
---@param index? integer
---@return Cs3Player
function player(index) end

---@class Cs3World
---@field size integer 0=320 1=480 2=640 3=256
---@field season integer 0 лето, 2 зима, 3 пустыня (<0 случайно)
---@field terrain integer 0..5
---@field relief integer 0..4
---@field mines integer
---@field resources integer 0=1000 1=4000 2=5000 иначе 1000000
---@field seed0 integer
---@field seed1 integer

--- Без аргументов — прочитать настройки карты; с таблицей — записать (server/shared, в `game.prepare`).
---@overload fun(): Cs3World
---@param settings Cs3World|table
function world(settings) end

-- ===================================================================================================
-- native, mem
-- ===================================================================================================

--- Нативные функции движка (список — GAME_API.md). Var-параметры возвращаются значениями.
--- На клиенте доступны только читающие (Get*, Is*, Has*, Can*, Calc*, Check*, Find*, Count*).
---@type table<string, fun(...: any): any>
native = {}

---@class Cs3Mem
mem = {}
---@param addr integer
---@param off? integer
---@return integer?
function mem.i32(addr, off) end
---@return integer?
function mem.u32(addr, off) end
---@return integer?
function mem.i16(addr, off) end
---@return integer?
function mem.u16(addr, off) end
---@return integer?
function mem.u8(addr, off) end
---@return number?
function mem.f32(addr, off) end
---@return number?
function mem.f64(addr, off) end
---@return string?
function mem.str(addr, off) end
---@param n integer
---@return string?
function mem.bytes(addr, off, n) end

-- ===================================================================================================
-- net
-- ===================================================================================================

---@class Cs3Net
net = {}
--- Клиент → хосту (в одиночке — своему server-скрипту). Данные: nil, число, строка, boolean или таблица из них.
---@param event string
---@param data? any
function net.send(event, data) end
--- Хост → всем клиентам (server/shared).
---@param event string
---@param data? any
function net.broadcast(event, data) end
--- Получить сообщение. На хосте `from` — отправитель (`game.playerIndexOf(from)`), данным клиента не доверять.
---@param event string
---@param fn fun(data: any, from: any)
function net.on(event, fn) end

-- ===================================================================================================
-- input (client)
-- ===================================================================================================

---@class Cs3Input
input = {}
--- Клавиши: A-Z, 0-9, F1-F12, Num0-Num9, Space, Enter, Tab, Escape, Backspace, Delete, Home, PageUp,
--- PageDown, Up, Down, Left, Right, LMB, RMB, MMB; модификаторы "Ctrl+", "Shift+", "Alt+". Insert занят меню.
---@param key string Например "F6" или "Ctrl+LMB"
---@param fn fun(key: string)
function input.bind(key, fn) end

-- ===================================================================================================
-- web (client) — страницы CEF
-- ===================================================================================================

---@class Cs3Web
web = {}
--- Открыть `<мод>/web/<page>` или полный URL. Одна страница на экране: новая заменяет прежнюю.
---@param page string
function web.open(page) end
function web.close() end
function web.reload() end
---@return boolean
function web.isOpen() end
---@return string
function web.url() end
--- Выполнить JavaScript в открытой странице.
---@param js string
function web.eval(js) end
--- Режим HUD: прозрачные пиксели (alpha < 16) пропускают мышь в игру.
---@param enabled boolean
function web.passthrough(enabled) end

-- ===================================================================================================
-- ui (client) — родной интерфейс игры
-- ===================================================================================================

---@alias Cs3UiElement integer

---@class Cs3UiColor
---@field [1] number r
---@field [2] number g
---@field [3] number b
---@field [4] number a

---@class Cs3UiWindowArgs
---@field name string
---@field parent? Cs3UiElement
---@field x number
---@field y number
---@field w number
---@field h number

---@class Cs3UiTextArgs
---@field name string
---@field parent? Cs3UiElement
---@field text string
---@field x number
---@field y number
---@field w? number
---@field h? number
---@field font? string Например "gc_font_serif_15"
---@field color? Cs3UiColor

---@class Cs3UiImageArgs
---@field name string
---@field parent? Cs3UiElement
---@field material string
---@field x number
---@field y number
---@field w? number
---@field h? number
---@field align? any

---@class Cs3UiContainerArgs
---@field name string
---@field parent? Cs3UiElement
---@field x number
---@field y number
---@field w number
---@field h number
---@field align? any

---@class Cs3UiButtonArgs
---@field name string
---@field parent? Cs3UiElement
---@field text? string
---@field x number
---@field y number
---@field w? number
---@field h? number
---@field material? string Например "btn.large"
---@field hint? string
---@field tag? integer
---@field align? any
---@field onClick? fun(element: Cs3UiElement)

---@class Cs3Ui
ui = {}
---@param args Cs3UiWindowArgs
---@return Cs3UiElement
function ui.window(args) end
---@param args Cs3UiTextArgs
---@return Cs3UiElement
function ui.text(args) end
---@param args Cs3UiImageArgs
---@return Cs3UiElement
function ui.image(args) end
---@param args Cs3UiContainerArgs
---@return Cs3UiElement
function ui.container(args) end
---@param args Cs3UiButtonArgs
---@return Cs3UiElement
function ui.button(args) end
---@param element Cs3UiElement
---@param fn fun(element: Cs3UiElement)
function ui.onClick(element, fn) end
---@param name string
---@param parent? Cs3UiElement
---@return Cs3UiElement?
function ui.find(name, parent) end
---@param element Cs3UiElement
---@return string
function ui.name(element) end
---@param element Cs3UiElement
---@return string
function ui.getText(element) end
---@param element Cs3UiElement
---@param text string
function ui.setText(element, text) end
---@param element Cs3UiElement
---@return boolean
function ui.isVisible(element) end
---@param element Cs3UiElement
---@param visible boolean
function ui.setVisible(element, visible) end
---@param element Cs3UiElement
---@return number x
---@return number y
function ui.getPosition(element) end
---@param element Cs3UiElement
---@param x number
---@param y number
function ui.setPosition(element, x, y) end
---@param element Cs3UiElement
---@param hint string
function ui.setHint(element, hint) end
---@param element Cs3UiElement
---@param alpha number
function ui.setBlend(element, alpha) end
---@param element Cs3UiElement
function ui.remove(element) end
---@return number w
---@return number h
function ui.size() end
---@param material string
---@return number w
---@return number h
function ui.imageSize(material) end
---@param tbl table
---@param key string
function ui.locale(tbl, key) end
---@param element Cs3UiElement
function ui.dump(element) end
---@param element Cs3UiElement
---@return Cs3UiElement[]
function ui.children(element) end
--- Запустить состояние интерфейса игры, например "ShowSettings".
---@param state string
function ui.exec(state) end
--- Нажать родную кнопку (состояние, тэг).
---@param state string
---@param tag integer
function ui.sendTag(state, tag) end
--- Перехватить состояние GUI. `return true` — игра его не обработает.
---@param state string
---@param fn fun(element: Cs3UiElement, press: string, tag: integer): boolean?
function ui.hookState(state, fn) end
--- Построить экран самому. `return false` — оставить и родной.
---@param name string
---@param fn fun(): boolean?
function ui.screen(name, fn) end

-- ===================================================================================================
-- screens (client): перехват кнопок. Остальное (list/tags/open/press) — из api/15_screens.lua.
-- ===================================================================================================

---@class Cs3Screens
screens = {}
--- Перехватить кнопку экрана. `return true` — заменить своим действием.
---@param screen string Например "MainMenu"
---@param fn fun(button: string, tag: integer, element: Cs3UiElement): boolean?
function screens.onButton(screen, fn) end
---@param fn fun(screen: string, button: string, tag: integer, element: Cs3UiElement): boolean?
function screens.onAnyButton(fn) end
--- Подменить экран целиком (например, открыть свою web-страницу вместо родных настроек).
---@param screen string
---@param fn fun()
function screens.replace(screen, fn) end

-- ===================================================================================================
-- gfx (client) — графика, видна только этому компьютеру
-- ===================================================================================================

---@alias Cs3GfxGroup fun(values?: table): table

---@class Cs3Gfx
---@field post Cs3GfxGroup preset, preset2, dof, ssao
---@field render Cs3GfxGroup antialiasing, culling, objectCulling, fxaa
---@field camera Cs3GfxGroup dof, depth, focal, angle, distance, rotateSpeed, zoomSpeed, height, freeMode, ...
---@field fog Cs3GfxGroup enabled, density, power, start, finish, offset, depth
---@field clouds Cs3GfxGroup visible, active, height, horizon, fog, speed
---@field sky Cs3GfxGroup visible, active, flareAngle, flareZ, flare
---@field shadows Cs3GfxGroup enabled, size, scaleHeight, addHeight, lightDepth
---@field light Cs3GfxGroup pattern, index, blendTo, blendTime
---@field time Cs3GfxGroup game, speed, season, dayNight, fogOfWarDay
---@field water Cs3GfxGroup name, index, offset
---@field wind Cs3GfxGroup vector, target, random, interval
---@field terrain Cs3GfxGroup visible, borders, colorMode
---@field [string] fun(...: any): any Любой натив графики напрямую: `gfx.<НативГрафики>(...)`
gfx = {}

---@class Cs3GfxPreset
---@field bloom? number
---@field saturation? number
---@field hdr? number
---@field contrast? number
---@field vignetteInner? number
---@field vignetteOuter? number
---@field [string] any

--- Записать параметры пост-обработки. Полный список ключей — `gfx.preset()` в консоли.
---@overload fun(): Cs3GfxPreset
---@param values Cs3GfxPreset
function gfx.preset(values) end
---@return table
function gfx.presets() end
---@return string[]
function gfx.presetNames() end
---@param name string
function gfx.usePreset(name) end
--- Применить сразу несколько групп: `gfx.apply{ fog = {...}, shadows = {...} }` или снимок.
---@param groups table
function gfx.apply(groups) end
--- Снимок текущих настроек графики (для `gfx.apply`).
---@return table
function gfx.snapshot() end
---@param name string Например "ShadowMapEnabled"
---@param value any
function gfx.option(name, value) end
---@param enabled boolean
function gfx.vsync(enabled) end
---@param values table
function gfx.highlight(values) end

-- ===================================================================================================
-- savedata — данные мода внутри файла сохранения
-- ===================================================================================================

---@class Cs3SaveData
savedata = {}
--- Записать значение (nil — удалить). Хендлы после загрузки сейва могут измениться — храни `uid`.
---@param key string
---@param value any
function savedata.set(key, value) end
---@param key string
---@return any
function savedata.get(key) end
---@return string[]
function savedata.keys() end

-- ===================================================================================================
-- manifest.lua и content.lua
-- ===================================================================================================

---@class Cs3Manifest
---@field id string Латиница, цифры, _
---@field name? string
---@field version? string
---@field author? string
---@field description? string
---@field enabled? boolean false — лежит, но не грузится
---@field client? string Скрипт интерфейса у каждого игрока
---@field server? string Скрипт правил: только у хоста/в одиночке (не вместе с shared)
---@field shared? string Выполняется у ВСЕХ одинаково (не вместе с server)
---@field files? string[] Модули для require
---@field multiplayer? "required"|"optional" required — в сети должен быть у всех
---@field priority? integer Больше — грузится позже и перекрывает других
---@field requires? string|string[] Без этих модов не загрузится

---@class Cs3Text
---@field ru? string
---@field en? string
---@field [string] string

---@class Cs3NationArgs
---@field sid string Три буквы
---@field from string Нация игры со зданиями (не tat, lit, mis)
---@field name? Cs3Text
---@field remove? string[] Убрать юниты шаблона
---@field resources? table<string, number> Прибавка к стартовым ресурсам

---@class Cs3UnitArgs
---@field sid string
---@field from string Существующий юнит
---@field nations string[]
---@field cell? integer[] Клетка панели найма {x, y}
---@field base? table<string, number> Поля TObjBase: maxhp, speed, ["price[3]"], ["weapon[1].damage"], ...
---@field prop? table<string, number> Поля TObjProp: vision, ...
---@field name? Cs3Text
---@field description? Cs3Text
---@field actor? string
---@field mesh? string
---@field material? string
---@field animations? string
---@field icon? string

---@class Cs3BattleArgs
---@field sid string
---@field from string battle1..battle8
---@field map string Файл .map внутри папки мода
---@field maxplayers? integer
---@field name? Cs3Text
---@field description? Cs3Text

--- Только для content.lua.
---@param args Cs3NationArgs
function nation(args) end
--- Только для content.lua.
---@param args Cs3UnitArgs
function unit(args) end
--- Только для content.lua.
---@param args Cs3BattleArgs
function battle(args) end
