-- Прогон api/*.lua на подставной игре.
--
--   lua tools/api_test/run.lua
--
-- Грузит fake_game.lua, затем все api/*.lua по порядку имён — так же, как модлоадер, —
-- и проверяет, что библиотека читает и пишет правильно. Новый модуль api — новые проверки ниже.

local here = arg[0]:match("^(.*)[/\\]") or "."
local root = here .. "/../.."

dofile(here .. "/fake_game.lua")

-- Список api/*.lua без модулей файловой системы: имена задаём по шаблону и пробуем открыть.
local loaded = {}
for _, name in ipairs({ "00_schema", "01_state", "02_screens_data", "10_profile", "11_options", "12_saves",
                        "13_players", "14_map", "15_screens", "17_balance", "18_buildings", "22_camera",
                        "23_minimap", "24_animation", "25_effects", "26_decals", "27_world",
                        "28_object", "29_pathfind", "30_terrain", "31_fow", "32_markers",
                        "33_cutscene", "34_dbg", "35_netrec", "36_time", "37_sound", "38_orders",
                        "39_formation", "40_weapon", "41_status", "42_targeting", "43_ai",
                        "44_scenario", "45_economy", "46_panel", "47_attachments", "48_vision",
                        "49_replay", "50_profiler", "51_content", "52_group", "53_behaviour",
                        "54_regions", "55_tracks", "56_gui", "57_native_catalog", "58_steam",
                        "60_mathx", "61_vec", "62_tablex", "63_stringx",
                        "64_geometry", "65_scheduler", "66_rng", "67_query",
                        "68_validate", "69_config", "70_color", "71_water", "90_call" }) do
    local path = root .. "/api/" .. name .. ".lua"
    local chunk, err = loadfile(path, "t", _ENV)
    assert(chunk, err)
    chunk()
    loaded[#loaded + 1] = name
end

-- abilities — проверяем Lua-часть и форму сгенерированного area-damage кода.
native.GetGameTime = function() return 10 end
dofile(root .. "/api/21_abilities.lua")
loaded[#loaded + 1] = "21_abilities"

local passed, failed = 0, 0
local function check(title, got, want)
    local ok = got == want
    if type(want) == "number" and type(got) == "number" then ok = math.abs(got - want) < 1e-6 end
    if ok then passed = passed + 1 else
        failed = failed + 1
        print(("FAIL %s: got %s, want %s"):format(title, tostring(got), tostring(want)))
    end
end

-- state: типы из схемы
check("type of gMap.settings.gen", state.type("gMap.settings.gen"), "TMapSettingsGen")
check("type of sndmaster", state.type("gProfile.sndmaster"), "float")
check("type of players", state.type("gMap.players"), "array")

-- state.get: каждая ветка чтения
check("get float", state.get("gProfile.sndmaster"), 0.75)
check("get string", state.get("gMap.players[2].name"), "p2")
check("get bool", state.get("gMap.players[0].bhuman"), true)
check("get int", state.get("gMap.settings.gen.mapsize"), 1)

-- state.read: запись одним вызовом, в т.ч. дробное с запятой
local p1 = state.read("gMap.players[1]")
check("read name", p1.name, "p1")
check("read team", p1.team, 1)
check("read float with comma", p1.startx, 1.5)
check("read bool", p1.bai, true)

local st = state.read("gMap.settings", 2)
check("read nested", st.gen.season, 0)
check("read nested 2", st.additional.peacetime, 10)

-- state.list
check("list size", #state.list("gMap.players"), 12)

-- state.globals / state.fields: обход состояния, не зная заранее, что там лежит.
-- Игру не трогают вовсе — отвечают по схеме, поэтому и проверяются без неё.
local globals = state.globals()
check("globals не пуст", #globals > 0, true)
check("globals по алфавиту", globals[1].name < globals[#globals].name, true)
local hasPlayers = false
for _, g in ipairs(globals) do if g.name == "gMap" then hasPlayers = true end end
check("globals содержит gMap", hasPlayers, true)

local arr = state.fields("gMap.players")
check("fields массива: это массив", arr.array, true)
check("fields массива: нижняя граница", arr.from, 0)
check("fields массива: тип элемента", arr.of, "TMapPlayer")

local rec = state.fields("gMap.players[0]")
check("fields записи: есть поля", #rec > 0, true)
local byName = {}
for _, f in ipairs(rec) do byName[f.name] = f.type end
check("fields записи: тип name", byName.name, "string")
check("fields записи: тип team", byName.team, "int")

check("fields простого поля", state.fields("gMap.players[0].name").simple, true)
check("fields простого поля: тип", state.fields("gMap.players[0].name").type, "string")

-- state.set: все типы и что код постоянный (значение идёт аргументом)
EXEC_LOG, EXEC_ARG = {}, {}          -- EXEC_LOG[1] ниже — про ЭТУ запись
state.set("gProfile.sndmaster", 0.3)
check("set float", FAKE.gProfile.sndmaster, 0.3)
state.set("gProfile.igamespeed", 4)
check("set int", FAKE.gProfile.igamespeed, 4)
state.set("gProfile.bclipmouse", false)
check("set bool", FAKE.gProfile.bclipmouse, false)
state.set("gProfile.lang", "en")
check("set string", FAKE.gProfile.lang, "en")
check("set code has no value", EXEC_LOG[1], "gProfile.sndmaster := StrToInt(ML_ARG) / 1000000;")

-- РЕГРЕССИЯ: движок кэширует код по ТЕКСТУ, каждый новый текст — это новое
-- состояние ModLoader.Call.N, живущее до конца партии и не освобождаемое
-- (ScriptRunner.cpp, g_callCache). Значит ИНДЕКСЫ ПУТИ обязаны ехать в аргументе:
-- иначе balance.set по ростеру плодит состояния пачками. В логе 2026-09-28 было
-- "500 cached script calls" сразу после "баланс применён: 17 типов" — 17 типов x
-- 4 поля x 8 игроков = 544 текста.
--
-- Такая же проверка есть у orders ниже; здесь она про state/balance.
do
    -- Проверка ПИШЕТ в подставное состояние, поэтому сначала снимок, в конце —
    -- возврат: ниже balance-тесты сверяют те же поля, и мусор от нас их ронял.
    local FIELDS = { "maxhp", "price[0]", "weapon[0].damage" }
    local saved = {}
    for player = 0, 7 do
        saved[player] = {}
        for _, field in ipairs(FIELDS) do
            saved[player][field] = state.get("gPlayer[" .. player .. "].objbase[4][12]." .. field)
        end
    end

    local seen = {}
    for player = 0, 7 do
        for _, field in ipairs(FIELDS) do
            EXEC_LOG = {}
            state.set("gPlayer[" .. player .. "].objbase[4][12]." .. field, 100 + player)
            for _, code in ipairs(EXEC_LOG) do seen[code] = true end
        end
    end
    local n = 0
    for _ in pairs(seen) do n = n + 1 end
    check("state.set: один текст на ФОРМУ пути, а не на путь (3 поля x 8 игроков = 3)", n, 3)

    EXEC_LOG, EXEC_ARG = {}, {}
    state.set("gPlayer[6].objbase[4][12].maxhp", 777)
    local code, arg = EXEC_LOG[1], EXEC_ARG[1]
    check("state.set: индексы пути не вшиты в код", code:find("%[6%]") == nil, true)
    check("state.set: номер типа не вшит в код", code:find("%[12%]") == nil, true)
    check("state.set: значение не вшито в код", code:find("777") == nil, true)
    check("state.set: индексы и значение в аргументе", arg, "6|4|12|777")
    check("state.set: запись всё равно дошла", FAKE.gPlayer[6].objbase[4][12].maxhp, 777)

    -- Чтение — та же история: game.evalInt(path) тоже кэшируется по тексту.
    seen = {}
    for player = 0, 7 do
        EXEC_LOG = {}
        local hp = state.get("gPlayer[" .. player .. "].objbase[4][12].maxhp")
        check("state.get: значение читается (игрок " .. player .. ")", type(hp), "number")
        for _, code in ipairs(EXEC_LOG) do seen[code] = true end
    end
    n = 0
    for _ in pairs(seen) do n = n + 1 end
    check("state.get: один текст на ФОРМУ пути (8 игроков = 1)", n, 1)

    for player = 0, 7 do
        for _, field in ipairs(FIELDS) do
            state.set("gPlayer[" .. player .. "].objbase[4][12]." .. field, saved[player][field])
        end
    end
end

-- G
check("G read", G.gMap.players[2].team, 0)
G.gProfile.sndmusic = 0.9
check("G write", FAKE.gProfile.sndmusic, 0.9)
check("G record", G.gMap.players[1]().name, "p1")

-- ошибки понятные, а не падения
local ok, err = pcall(state.get, "gProfile.nosuchfield")
check("unknown field errors", ok, false)
check("error names the field", tostring(err):find("nosuchfield") ~= nil, true)

-- модули
check("profile.get", profile.get("name"), "Illia")
check("saves.list", saves.list()[2].name, "megacool")
saves.load("autosave")
check("saves.load", LOADED, "autosave")
check("players.list", #players.list(), 3)
check("players.list index", players.list()[3].index, 2)
check("map.settings", map.settings().gen.randkey1, 22)
check("options.get", options.get("ShadowMap"), "sm4096")

-- api_call — то, что зовут страницы
check("api_call", api_call("profile.get", "name"), "Illia")
check("api_call nested", api_call("saves.list")[1].date, "20.09.26 12:40")

abilities.define("test_strike", { cooldown = 20, damage = 800, radius = 10, target = "all" })
check("abilities.define", abilities.get("test_strike").damage, 800)
local abilityOk, abilityHits = abilities.fire("test_strike", 12.5, -4.25, { owner = 1 })
check("abilities.fire", abilityOk, true)
check("abilities.fire generated damage", EXEC_LOG[#EXEC_LOG]:find("_misc_DoDamage") ~= nil, true)

-- camera/minimap/animation/effects/decals: wrappers call the right natives
do
    local x, y, z = camera.pos()
    check("camera.pos", x, 1)
    check("camera.target", select(1, camera.target()), 7)
    camera.position(10, 20)
    check("camera.position", NATIVE_LOG[#NATIVE_LOG].name, "SetMainCameraPositionXZ")
    camera.rotate(0, 1, 0)
    camera.moveTo(5, 6, 2.0)
    camera.follow(777)
    check("camera.follow", NATIVE_LOG[#NATIVE_LOG].args[1], 777)
    check("camera.followed", camera.followed(), 777)
    camera.limits({ left = 0, top = 1, right = 100, bottom = 101 })
    check("camera.limits", camera.getLimits().right, 100)
    check("camera.height", camera.height(1, 2), 12.5)
    camera.trackClear()
    check("camera.trackAdd", camera.trackAdd(), 5)
    camera.trackPoint("t", 0, 0, 0, 1, 2, 3)
    camera.trackPlay(1)
    check("camera.trackCurrent", camera.trackCurrent(), 1)

    minimap.show(true)
    check("minimap.visible", minimap.isVisible(), true)
    check("minimap.zoom", minimap.getZoom(), 1.5)
    minimap.zoom(2.0)
    local mi = minimap.icon("target")
    check("minimap.icon", mi, 3)
    minimap.setPos(mi, 1, 2)
    minimap.setDir(mi, 0, 1)
    minimap.setBlink(mi, 0.5, 2)
    minimap.setVisible(mi, true)
    check("minimap.count", minimap.count(), 1)
    minimap.clear()

    animation.play(100, "attack")
    animation.cycle(100, "work")
    check("animation.frame", animation.frame(100), 12)
    animation.frame(100, 5)
    check("animation.info", animation.info(100).cycle, "idle")
    check("animation.cycleFrames", animation.cycleFrames(100, "work"), 30)
    model.actor(100, "a")
    model.material(100, "m")
    model.scale(100, 1.2, 1.2, 1.2)
    model.show(100, false)
    model.rotate(100, 0, 1, 0)
    model.pointTo(100, 1, 2, 3)

    check("effects.create", effects.create(100, "PUEXP", "b"), 12)
    effects.clear(100)
    effects.pfx(100, "mgr", "k")
    check("effects.isPfx", effects.isPfx(100, "mgr", "k"), true)
    effects.setLifetime(100, "mgr", "k", 5)
    effects.setScale(100, "mgr", "k", 2, 2, 2)
    effects.burst(12, 1.0, 10)
    effects.fire(12, 1, 5, 1, 10)
    check("effects.highlight", effects.highlight(100, "t", true, ""), 21)
    effects.unhighlight(100, "t")

    check("decals.put", decals.put("scorch", 1, 2), 31)
    decals.move(31, 3, 4)
    check("decals.pos", select(1, decals.pos(31)), 5)
    decals.rotate(31, 1.0)
    check("decals.angle", decals.angle(31), 0.5)
    check("decals.count", decals.count(), 2)
    check("decals.inCircle", decals.isInCircle(0, 0, 10, "m"), true)
    decals.remove(31)

    local ok1 = pcall(camera.position, "bad", 1)
    check("camera validation", ok1, false)
    local ok2 = pcall(decals.put, "", 1, 2)
    check("decals validation", ok2, false)
end

-- screens: имена кнопок и перехват через ui мода
local SENT, HOOKS = nil, {}
ui = { sendTag = function(state, tag) SENT = state .. ":" .. tag end, exec = function() end }
check("screens.tags", screens.tags("MainMenu").Settings, 104)
check("screens.button", screens.button("MainMenu", 109), "Exit")
check("screens.of", screens.of("EventSettings"), "Settings")
screens.press("MainMenu", "Settings")
check("screens.press", SENT, "EventMainMenu:104")
local own = screens.bind({ hookState = function(state, fn) HOOKS[state] = fn end })
local got
own.onAnyButton(function(screen, button) got = screen .. "." .. button; return true end)
check("onAnyButton block", HOOKS.EventMainMenu(1, "c", 101), true)
check("onAnyButton name", got, "MainMenu.Campaign")

-- Ветка БЕЗ ui (страница game.api и server/shared зовут игру напрямую) раньше не
-- проверялась вообще: тест шёл через ui мода. А именно там имя состояния и тэг
-- пеклись в текст кода, то есть каждая нажатая кнопка съедала своё состояние
-- движка навсегда (см. ScriptRunner g_callCache).
do
    local saved = ui
    ui = nil
    EXEC_LOG, EXEC_ARG = {}, {}
    screens.press("MainMenu", "Settings")
    screens.press("MainMenu", "Exit")
    screens.open("Settings")
    local seen = {}
    for _, code in ipairs(EXEC_LOG) do seen[code] = true end
    local n = 0
    for _ in pairs(seen) do n = n + 1 end
    check("screens без ui: один текст на press и один на open", n, 2)
    check("screens.press: тэг не вшит в код", EXEC_LOG[1]:find("104") == nil, true)
    check("screens.press: имя состояния не вшито в код",
          EXEC_LOG[1]:find("EventMainMenu") == nil, true)
    check("screens.press: тэг и имя в аргументе", EXEC_ARG[1], "104|EventMainMenu")
    check("screens.open: имя в аргументе", EXEC_ARG[3], "ShowSettings")
    ui = saved
end
check("onButton hover skipped", HOOKS.EventMainMenu(1, "m", 101), nil)
check("modOnly", pcall(screens.onButton, "MainMenu", print), false)

-- balance: поиск типа, чтение с массивами, запись всем и одному игроку
check("balance.find", select(2, balance.find("RUS_Strelets")), 12)
local st = balance.get("rus_strelets")
check("balance.get maxhp", st.base.maxhp, 100)
check("balance.get price[3]", st.base.price[3], 5)
check("balance.get weapon[0].damage", st.base.weapon[0].damage, 10)
check("balance.get prop", st.prop.vision, 800)
balance.set("rus_strelets", "maxhp", 300)
check("balance.set all p0", FAKE.gPlayer[0].objbase[4][12].maxhp, 300)
check("balance.set all p11", FAKE.gPlayer[11].objbase[4][12].maxhp, 300)
balance.set("rus_strelets", "weapon[0].damage", 40, 1)
check("balance.set one", FAKE.gPlayer[1].objbase[4][12].weapon[0].damage, 40)
check("balance.set one untouched", FAKE.gPlayer[2].objbase[4][12].weapon[0].damage, 10)
balance.set("rus_strelets", "price[3]", 50)
check("balance.set price", FAKE.gPlayer[5].objbase[4][12].price[3], 50)
check("balance.unknown", pcall(balance.find, "nope"), false)

-- РЕГРЕССИЯ (то же правило, что у state.set и orders): setHP/setDamage/setSpeed
-- строят большой кусок Pascal, и раньше в него запекались и номер типа, и сами
-- значения. Каждое новое значение = новое состояние движка навсегда, поэтому
-- "разгон здоровья на 100 шагов" незаметно съедал 100 состояний.
do
    local seen = {}
    for hp = 100, 120 do
        EXEC_LOG = {}
        balance.setHP("rus_strelets", hp)
        balance.setDamage("rus_strelets", hp // 2)
        balance.setSpeed("rus_strelets", 1 + hp / 1000)
        for _, code in ipairs(EXEC_LOG) do seen[code] = true end
    end
    local n = 0
    for _ in pairs(seen) do n = n + 1 end
    check("balance: один текст на операцию, а не на значение (3 операции = 3)", n, 3)

    EXEC_LOG, EXEC_ARG = {}, {}
    balance.setHP("rus_strelets", 777)
    local code, arg = EXEC_LOG[1], EXEC_ARG[1]
    check("balance.setHP: значение не вшито в код", code:find("777") == nil, true)
    check("balance.setHP: номер типа не вшит в код", code:find("c := 12") == nil, true)
    check("balance.setHP: значение в аргументе", arg:find("777") ~= nil, true)
    -- Аргумент: pfirst|plast|страна|тип|значение|
    check("balance.setHP: порядок аргумента", arg, "0|11|4|12|777|")
end

-- buildings: разбор ответа скрипта (сам скрипт исполняет игра)
do
    local realExec = game.exec
    game.exec = function(code)
        if code:find("_country_GetFixedProduceIndexBySID%(cid") then
            return "420barracks189001000True1" ..
                "musketeer1812010,20,0,5,0,03000" ..
                "pikeman181115,5,0,0,0,02010" ..
                "upg_bayonet70True1415100,0,0,50,0,060" ..
                "4musketeer1830,25"
        end
        return "True"
    end
    local b = buildings.info(777)
    check("buildings.info sid", b.sid, "barracks18")
    check("buildings.info built", b.built, true)
    check("buildings.info produce", #b.produce, 2)
    check("buildings.info available", b.produce[1].available, true)
    check("buildings.info blocked", b.produce[2].available, false)
    -- Цена по ИМЕНАМ ресурсов. В подставном ответе у musketeer18 цена
    -- "10,20,0,5,0,0" — это еда, дерево, камень, золото, железо, уголь
    -- (индексы 1..6 игрового массива price; нулевой слот — gc_resource_type_none).
    check("buildings.info price food", b.produce[1].price.food, 10)
    check("buildings.info price wood", b.produce[1].price.wood, 20)
    check("buildings.info price gold", b.produce[1].price.gold, 5)
    check("buildings.info price coal", b.produce[1].price.coal, 0)
    -- Уголь раньше терялся: читались индексы 0..5, шестой не доезжал.
    check("buildings.info: уголь в цене есть", b.upgrades[1].price.coal ~= nil, true)
    check("buildings.info upgrade", b.upgrades[1].sid, "upg_bayonet")
    check("buildings.info queue", b.queue[1].kind, "unit")
    check("buildings.info progress", b.queue[1].progress, 0.25)
    check("buildings.produce", buildings.produce(777, "musketeer18", 5), true)
    game.exec = realExec
end

-- world/object/pathfind/terrain/fow/markers/cutscene/dbg/netrec/time/sound
do
    local h = world.spawn({ race = "ukr", base = "tree", x = 10, z = 20 })
    check("world.spawn", h, 501)
    world.move(h, 30, 40)
    check("world.pos", select(3, world.pos(h)), 3)
    world.destroy(h)
    check("world.destroy invalidates handle", objects.alive(h), false)
    world.destroyNow(h)
    check("pathfind rejects invalidated handle", pcall(pathfind.calculate, h, 5, 6), false)
    check("world validation", pcall(world.spawn, { race = "", base = "x", x = 0, z = 0 }), false)

    check("object.state", object.state(100), "idle")
    -- object.states: имена берём у машины состояний, а не угадываем.
    local stList = object.states(100)
    check("object.states count", #stList, 3)
    check("object.states[1]", stList[1], "idle")
    check("object.states has burning", (function()
        for _, s in ipairs(stList) do if s == "burning" then return true end end
        return false
    end)(), true)
    -- Несуществующее состояние обязано отклоняться (иначе объект ломается).
    check("setState unknown rejected", pcall(object.setState, 100, "no_such_state_zzz"), false)
    -- ...и хендл без машины состояний не должен ломать перечисление.
    check("object.states no sm", #object.states(555), 0)
    object.setState(100, "burning")
    object.destroyIn(100, "destroyed")
    check("object.progress", object.progress(100, "s.aix", "burning"), 61)

    check("pathfind.calculate", pathfind.calculate(100, 5, 6), 0)
    check("pathfind.distance", pathfind.distance(0, 0, 9, 9), 42.5)
    check("pathfind.group", pathfind.groupReady(50), true)

    terrain.raise(10, 20, { delta = 2 })
    terrain.lower(10, 20, { delta = 1 })
    terrain.smooth(10, 20)
    terrain.update()
    check("terrain.height", terrain.height(1, 2), 7.5)

    check("fow.enabled", fow.isEnabled(), true)
    fow.enable(false)
    fow.lerp(0.7)
    fow.revealObject(100)
    fow.rebuild()

    local mid = markers.add({ x = 5, z = 6, icon = "attack", duration = 100 })
    check("markers.add", mid ~= nil, true)
    markers.remove(mid)

    cutscene.play({ { x = 1, z = 2, time = 0.01 } })
    check("cutscene.playing", cutscene.playing(), true)
    cutscene.stop()
    check("cutscene.stopped", cutscene.playing(), false)

    dbg.text("t1", 1, 2, 3, "hello")
    check("dbg.count", dbg.count(), 1)
    check("dbg.ray", select(1, dbg.ray(0, 10, 0, 0, 0, 10)), true)
    check("dbg.unit", dbg.unit(100):find("musketeer18") ~= nil, true)

    netrec.start({ hashEvery = 1 })
    fireEvt("net.sync")
    fireEvt("unit.order", "ev", 5, "move", 0, 1, 2)
    fireEvt("net.sync")
    check("netrec.step", netrec.step(), 2)
    check("netrec.report", netrec.report():find("order@") ~= nil, true)
    netrec.stop()

    check("time.factor", time.factor(), 1)
    time.speed(2)
    check("time.speed", time.factor(), 2)
    time.pause()
    time.resume()
    check("time.resume", time.factor(), 2)

    check("sound.get", sound.get(100, "explosion"), 71)
    sound.play(71)
    check("sound.volume", sound.volume(71), 0.8)
    sound.volume(71, 0.5)
    check("sound.playAt", sound.playAt(100, "boom"), 71)
    sound.remove(100)
end

-- orders/formation/weapon/status/targeting/ai/scenario/economy/panel/attach/vision/replay/profiler/content
do
    EXEC_LOG = {}
    orders.move(5, 10, 20)
    check("orders.move", EXEC_LOG[#EXEC_LOG]:find("_unit_AddOrder") ~= nil, true)
    check("orders.move type", EXEC_LOG[#EXEC_LOG]:find("gc_obj_order_type_move") ~= nil, true)
    orders.attackMove({ 5, 6 }, 1, 2)
    orders.attack(5, 6, { lock = true })
    orders.patrol(5, 0, 0, 9, 9)
    orders.guard(5, 6)
    orders.queue(5, { { move = { 1, 2 } }, { attackpoint = { 3, 4 } } })
    orders.cancel(5)
    orders.cancel(5, true)
    check("orders validation", pcall(orders.move, 0, 1, 2), false)

    -- РЕГРЕССИЯ: game.exec кэшируется по ТЕКСТУ кода (ScriptRunner g_callCache),
    -- новый текст = новое скомпилированное состояние ModLoader.Call.N на всю партию.
    -- Значит orders обязан давать ОДИН текст на вид приказа, а хендлы/координаты
    -- передавать через аргумент. Иначе 100 юнитов = 100 состояний, и модлоадер
    -- начнёт ругаться "pass changing values via arg, not in the code text".
    do
        local seen = {}
        for i = 1, 20 do
            EXEC_LOG, EXEC_ARG = {}, {}
            orders.move(1000 + i, i * 1.5, i * 2.5)          -- другие хендл и координаты
            orders.attackMove(2000 + i, i * 3, i * 4)
            for _, code in ipairs(EXEC_LOG) do seen[code] = true end
        end
        local n = 0
        for _ in pairs(seen) do n = n + 1 end
        check("orders: один текст состояния на вид приказа (move+attackMove = 2)", n, 2)

        -- Координаты и хендл обязаны ехать в АРГУМЕНТЕ, а не в текст кода.
        EXEC_LOG, EXEC_ARG = {}, {}
        orders.move(4242, 111.5, 222.5)
        local code, arg = EXEC_LOG[1], EXEC_ARG[1]
        check("orders: хендл не вшит в код", code:find("4242") == nil, true)
        check("orders: координаты не вшиты в код", code:find("111") == nil, true)
        check("orders: значения в аргументе", arg ~= nil and arg:find("4242") ~= nil, true)
        -- Последние два поля аргумента — clear|first.
        check("orders: clear/first в аргументе", arg:sub(-3) == "1|0", true)
        -- А для move координаты идут в f1/f2 ( тысячные).
        check("orders: координаты в аргументе тысячными",
              arg:find("|111500|222500|") ~= nil, true)
    end

    local slots = formation.slots("wedge", 4, 3, 0, 0, 0)
    check("formation.slots", #slots, 4)
    check("formation.square", #formation.slots("square", 12, 3, 0, 0, 0), 12)
    check("formation.shape", pcall(formation.slots, "nope", 4, 3, 0, 0, 0), false)
    formation.set({ 5, 6 }, "line", { x = 0, z = 0 })

    abilities.define("wtest", { damage = 100, radius = 5 })
    weapon.fire({ ability = "wtest", target = { x = 10, z = 20 } })
    weapon.fire({ ability = "wtest", target = { x = 10, z = 20 }, shots = 2, interval = 0.1, spread = 3 })
    check("weapon validation", pcall(weapon.fire, { target = { x = 1, z = 2 } }), false)

    status.installBlocker(events.on)
    status.add(100, "burning", { duration = 5, damage = 10 })
    check("status.has", status.has(100, "burning"), true)
    status.remove(100, "burning")
    check("status.gone", status.has(100, "burning"), false)

    check("targeting.circle", #targeting.inCircle(11, 22, 5), 3)
    check("targeting.nearest", targeting.nearest({ x = 11, z = 22 }) ~= nil, true)
    check("targeting.los", targeting.los(0, 0, 5, 5), false)

    ai.attach(100, { initial = "guard", states = { guard = {}, attack = {} } })
    check("ai.state", ai.state(100), "guard")
    ai.set(100, "attack")
    check("ai.set", ai.state(100), "attack")
    ai.detach(100)

    scenario.objective("t1", { type = "destroy", target = 999 })
    check("scenario.destroy", scenario.check("t1"), false)
    scenario.cancelObjective("t1")
    check("scenario.nolink", pcall(scenario.dialog, "d", { text = "x" }), false)
    scenario.link({ broadcast = net.broadcast, on = net.on })
    scenario.dialog("d1", { speaker = "s", text = "hi" })
    scenario.present()
    local okw = scenario.wave({ delay = 100, units = { "peauk" }, race = "ukr", x = 1, z = 2 })
    check("scenario.wave", okw ~= nil, true)

    check("economy.nolink", pcall(economy.set, 0, "fuel", 1), false)
    check("economy.badlink", pcall(economy.link, {}), false)
    economy.link(savedata)
    economy.set(0, "fuel", 100)
    check("economy.get", economy.get(0, "fuel"), 100)
    savedata.set("eco:0:legacy", "17")
    check("economy normalizes saved string", economy.get(0, "legacy"), 17)
    check("economy.consume", economy.consume(0, "fuel", 20), true)
    check("economy.poor", economy.consume(0, "fuel", 1000), false)
    local okp = economy.produce(777, "musketeer18", { player = 0, time = 100, cost = { fuel = 10 } })
    check("economy.produce", okp, true)

    ui = { container = function() return 91 end, text = function() return 93 end,
           remove = function() end, setVisible = function() end }
    local pnew = panel.new({ name = "t" })
    check("panel.new", pnew ~= nil, true)
    check("panel.nolink-btn", pcall(pnew.button, pnew, "x", function() end), false)
    ui.button = function() return 92 end
    ui.onClick = function() end
    panel.link(ui)
    check("panel.link-btn", pnew:button("x", function() end), 92)
    panel.clear()

    attach.effect(100, "mgr", "key", { pos = { 0, 1, 0 }, scale = 2 })
    attach.follow(100, 101)
    attach.unfollow(100)
    attach.free(100)

    vision.radius("rus_strelets", 900)
    vision.reveal(100)
    vision.hide(100)

    replay.mark("test")
    check("replay.marks", #replay.marks(), 1)
    replay.camera(false)

    profiler.start()
    game.exec("ML_RET('1');")
    profiler.stop()
    check("profiler.exec", profiler.report():find("game.exec") ~= nil, true)
    profiler.reset()

    local okc, rep = content.check({ mods = { my_pack = "1.2.0" } })
    check("content.ok", okc, true)
    local okc2 = content.check({ mods = { nope = "1.0" } })
    check("content.missing", okc2, false)
    check("content.perms", content.permissions("my_pack").world_spawn, true)
end

-- group/behaviour/regions/tracks/gui/catalog + scenario.trigger/snapshot + dbg.draw
do
    local g = group.create(0, "cav")
    check("group.create", g, 801)
    group.add(g, { 101, 102 })
    check("group.members", #group.members(g), 2)
    -- group.center обязан ПЕРЕСЧИТЫВАТЬ кэш перед чтением: в игре без этого
    -- он отдавал (0, 0, 0), потому что GroupGetCentralPosition*ByHandle только
    -- читает, а заполняет его GroupCalcCentralPositionByHandle.
    FAKE_GROUP_CENTER_CALCS = 0
    check("group.center", select(1, group.center(g)), 55)
    check("group.center recalcs", FAKE_GROUP_CENTER_CALCS, 1)
    group.move(g, 5, 6)
    group.formation(g, "line", { x = 0, z = 0 })
    group.stretch(g, 1.5)
    FAKE_GROUP_CENTER_CALCS = 0
    group.rebuild(g)
    check("group.rebuild recalcs center", FAKE_GROUP_CENTER_CALCS, 1)
    group.direct(g, true)
    check("group.ready", group.ready(g), true)
    group.destroy(g)

    check("beh.create", behaviour.create(100, "cls"), 901)
    check("beh.inertia", behaviour.inertia(100), 903)
    behaviour.force(903, 1, 2, 3)
    behaviour.torque(903, 1, 2, 3)
    behaviour.push(903, 0, -9, 0)
    behaviour.bounce(903, 0, 1, 0, 0.5)
    behaviour.mirror(903)
    behaviour.destroy(901)

    regions.create("base", { { x = 0, z = 0 }, { x = 100, z = 0 }, { x = 100, z = 100 }, { x = 0, z = 100 } })
    check("regions.contains", regions.contains("base", 10, 10), true)
    check("regions.boundary", regions.contains("base", 50, 0), true)
    check("regions.outside", regions.contains("base", 500, 500), false)
    check("regions.units", #regions.units("base"), 3)
    regions.block("base", true)
    regions.block("base", false)
    regions.remove("base")

    check("tracks.add", tracks.add("road", 0, 0, 0), 701)
    tracks.connect(701, 702)
    check("tracks.exists", tracks.exists(701, 702), true)
    check("tracks.length", tracks.lastLength(), 55.5)
    check("tracks.neighbours", #tracks.neighbours(701), 1)
    tracks.use(100, true)
    tracks.clear("road")

    scenario.trigger("t9", { on = "unit.death", action = function() end })
    check("scenario.snapshot", scenario.snapshot("s.bmp", 800, 600), "s.bmp")

    dbg.line("l1", 0, 0, 0, 1, 1, 1, "red")
    dbg.box("b1", 0, 0, 0, 5, "blue")
    dbg.sphere("s1", 0, 0, 0, 10, "green")
    dbg.axis("a1", 0, 0, 0, 0, 1, 0, "yellow")
    dbg.clean("l1")

    ui = { container = function() return 91 end, button = function() return 92 end,
           text = function() return 93 end, image = function() return 94 end,
           onClick = function() end, setPosition = function() end, getPosition = function() return 1, 2 end,
           setText = function() end, getText = function() return "t" end,
           setVisible = function() end, remove = function() end, find = function() return nil end }
    check("gui.nolink-btn", pcall(gui.create, "button", { text = "x" }), false)
    gui.link(ui)
    check("gui.create", gui.create("panel", { name = "p" }), 91)
    check("gui.button", gui.create("button", { parent = 91, text = "x" }), 92)
    gui.text(93, "hi")
    gui.show(91, false)
    gui.remove(91)

    local st = native.catalogStats()
    check("catalog.total", st.total, 4856)
    check("catalog.client", st.client > 2000, true)
    local ci = native.info("SetMainCameraPositionXZ")
    check("catalog.side", ci.side, "client")
    local fi = native.info("CreateFunction")
    check("catalog.forbidden", fi.risk, "forbidden")
    check("catalog.server", fi.side, "server")
    local gi = native.info("GetGameObjectBaseNameByHandle")
    check("catalog.read", gi.side, "client")
    check("catalog.wrap", native.info("PutDecalByName").wrappedBy, "decals.put")
    check("catalog.missing", native.info("Nope_Nope"), nil)
end

-- steam presence helpers
do
    STEAM_CALLS = {}
    local ok, why = steam.setMatch({ status = "В партии", map = "Полтава",
                                     mode = "2v2", opponents = { "Иван", "Пётр" } })
    check("steam.setMatch", ok, true)
    check("steam.keys", #STEAM_CALLS, 4)
    local ok2, why2 = steam.setMatch({ status = "В партии", map = "Полтава",
                                       mode = "2v2", opponents = { "Иван", "Пётр" } })
    check("steam.dedup", why2, "unchanged")
    check("steam.dedupCalls", #STEAM_CALLS, 4)
    local ok3, why3 = steam.setMatch({ status = "Другое" })
    check("steam.throttle", why3, "throttled")
    local t0 = os.clock()
    while os.clock() - t0 < 3.1 do end
    local ok4 = steam.setMatch({ status = "Другое", map = ("я"):rep(300) })
    check("steam.afterWait", ok4, true)
    local mapVal = nil
    for _, c in ipairs(STEAM_CALLS) do if c[1] == "map" then mapVal = c[2] end end
    check("steam.trunc", mapVal and #mapVal <= 200, true)
    check("steam.utf8", mapVal and mapVal:sub(-1):byte() < 0x80 or mapVal:sub(-1):byte() >= 0xC0, true)
    check("steam.oppErr", pcall(steam.setOpponent, ""), false)
    check("steam.playedWith", steam.playedWith("76561198000000001"), true)
    check("steam.myId", steam.myId(), "76561198000000001")
end


-- ---------- рельеф и вода: правка карты на ходу ----------
-- Стороны здесь настоящие: правка требует game.exec (server/shared), чтение — нет.
NATIVE_LOG = {}

-- Тайлы: имя блока и индекс — одно и то же, наружу принимаем оба.
check("tileIndex по имени", terrain.tileIndex("sand"), 1)
check("tileIndex по числу", terrain.tileIndex(2), 2)
check("tileIndex неизвестного", terrain.tileIndex("нетакого"), nil)
check("tileName", terrain.tileName(2), "rock")
check("tileName неизвестного", terrain.tileName(99), nil)

terrain.setTile(10, 20, "rock")
local ti, tn = terrain.tile(10, 20)
check("setTile+tile: индекс", ti, 2)
check("setTile+tile: имя", tn, "rock")
check("setTile по имени -> индекс", NATIVE_LOG[#NATIVE_LOG].args[3], 2)
check("setTile неизвестного падает",
      select(1, pcall(terrain.setTile, 1, 1, "нетакого")), false)

terrain.setTile(11, 20, "sand")
check("replaceTiles считает клетки", terrain.replaceTiles("sand", "grass"), 1)

-- paint: порядок аргументов натива важнее всего — перепутанные кисти молча
-- нарисуют не то. Проверяем каждую позицию.
NATIVE_LOG = {}
terrain.paint(100.5, 80.25, { tile = "sand", cliff = 3, water = 2, ramp = true,
                              apply = 1, level = 4, size = 5, round = false, reproduce = true })
local a = NATIVE_LOG[#NATIVE_LOG].args
check("paint: натив", NATIVE_LOG[#NATIVE_LOG].name, "PaintTerrain")
check("paint: x", a[1], 100.5)
check("paint: z отрицается", a[2], -80.25)
check("paint: tile индексом", a[3], 1)
check("paint: cliff", a[4], 3)
check("paint: water", a[5], 2)
check("paint: ramp", a[6], true)
check("paint: apply", a[7], 1)
check("paint: level", a[8], 4)
check("paint: size", a[9], 5)
check("paint: round", a[10], false)
check("paint: reproduce", a[11], true)

-- Умолчания: ничего не сказали — ничего и не трогаем. «Не трогать» у движка
-- это -1; ноль — настоящий номер тайла, им игра красит карту.
NATIVE_LOG = {}
terrain.paint(0, 0, {})
local d = NATIVE_LOG[#NATIVE_LOG].args
check("paint по умолчанию: тайл не трогаем", d[3], -1)
check("paint по умолчанию: скалы не трогаем", d[4], -1)
check("paint по умолчанию: вода не трогаем", d[5], -1)
check("paint по умолчанию: круглая", d[10], true)

check("color отдаёт четыре значения", select("#", terrain.color(1, 1)), 4)

-- Водоёмы.
check("вначале воды нет", water.count(), 0)
local lake = water.add{ name = "lake", x1 = 40, z1 = -40, x2 = -40, z2 = 40, level = -1 }
check("add вернул индекс", lake, 0)
local f = water.get(lake)
check("углы нормализованы: x1", f.x1, -40)
check("углы нормализованы: x2", f.x2, 40)
check("имя", f.name, "lake")
check("уровень", f.level, -1)

water.move(lake, { x1 = -50, z1 = -50, x2 = 50, z2 = 50 })
check("move не сбросил уровень", water.get(lake).level, -1)
water.level(lake, -2.5)
check("level", water.get(lake).level, -2.5)
water.rename(lake, "озеро")
check("find по имени", water.find("озеро"), 0)
check("find неизвестного", water.find("нетакого"), nil)
check("list", #water.list(), 1)
check("get за границей", water.get(5), nil)

water.add{ name = "второе", x1 = 0, z1 = 0, x2 = 10, z2 = 10 }
check("два водоёма", water.count(), 2)
water.remove(0)
check("после remove остался один", water.count(), 1)
check("остался именно второй", water.get(0).name, "второе")
water.clear()
check("clear", water.count(), 0)

-- Чтение: доступно и без game.exec.
check("at отдаёт два значения", select("#", water.at(-10, 0)), 2)
check("at: вода слева", (water.at(-10, 0)), true)
check("cell", water.cell(1, 1), true)
check("depth отдаёт два значения", select("#", water.depth(100)), 2)

-- Правка мира без game.exec — ошибка, а не тихое ничего.
local realExec = game.exec
game.exec = nil
check("setTile без exec падает", select(1, pcall(terrain.setTile, 1, 1, 0)), false)
check("paint без exec падает", select(1, pcall(terrain.paint, 0, 0, {})), false)
check("water.add без exec падает", select(1, pcall(water.add, { x1 = 0, z1 = 0, x2 = 1, z2 = 1 })), false)
check("water.at без exec работает", select(1, pcall(water.at, 0, 0)), true)
game.exec = realExec

-- Кисти рельефа: мировые координаты, вторая отрицается, mb — это радиус.
-- Всё три проверены по коду самой игры:
--   PaintTerrain(px, -py, 86, -1, -1, False, -1, -1, cRadius, False, True)
--       data/scripts/lib/misc.script, _misc_CreateBorders
--   PlateauTerrain(0, 0, False, (GetMapHeight div 2)-1, True)
--       data/scripts/common.inc/dogenerate.inc, очистка карты
-- В первой версии всё три были неверны, и мазок уходил в никуда.
NATIVE_LOG = {}
terrain.raise(100, 80, { delta = 2, radius = 5 })
local r = NATIVE_LOG[#NATIVE_LOG]
check("raise: натив", r.name, "RaiseTerrain")
check("raise: x как есть", r.args[1], 100)
check("raise: z отрицается", r.args[2], -80)
check("raise: radius в mb", r.args[4], 5)
check("raise: delta", r.args[5], 2)

terrain.lower(-40.7, 25.2, {})
local lo = NATIVE_LOG[#NATIVE_LOG]
check("lower: дробное вниз", lo.args[1], -41)
check("lower: отрицание до округления", lo.args[2], -26)
check("lower: радиус по умолчанию", lo.args[4], 3)

terrain.plateau(0, 0, { radius = 159, reproduce = true })
local pl = NATIVE_LOG[#NATIVE_LOG]
check("plateau: как чистит карту игра", pl.args[4], 159)
check("plateau: reproduce", pl.args[5], true)

-- mb оставлен как старое имя того же радиуса.
terrain.smooth(10, 10, { mb = 7 })
check("smooth: mb — то же, что radius", NATIVE_LOG[#NATIVE_LOG].args[4], 7)

-- paint: пропущенное поле — -1 («не трогать»), а не 0 («кисть номер ноль»).
NATIVE_LOG = {}
terrain.paint(50, 60, { water = 1, radius = 4 })
local w = NATIVE_LOG[#NATIVE_LOG].args
check("paint: z отрицается", w[2], -60)
check("paint: тайл не трогаем", w[3], -1)
check("paint: скалы не трогаем", w[4], -1)
check("paint: вода задана", w[5], 1)
check("paint: apply не трогаем", w[7], -1)
check("paint: level не трогаем", w[8], -1)
check("paint: радиус", w[9], 4)

terrain.paint(0, 0, { tile = "grass" })
local tp = NATIVE_LOG[#NATIVE_LOG].args
check("paint: тайл индексом", tp[3], 0)
check("paint: при тайле скалы не трогаем", tp[4], -1)

-- Проходимость: именно она решает, где вода для портов и кораблей.
-- Теги — из data/scripts/dmscript.global игры.
check("тег воды", COLLISION_TAG.water, 87)
check("тег ничего", COLLISION_TAG.none, 0)
check("тег моста", COLLISION_TAG.bridge, 10)

NATIVE_LOG = {}
terrain.setCollision(10, -20, "water", { radius = 5 })
local col = NATIVE_LOG[#NATIVE_LOG]
check("setCollision: натив", col.name, "MapDrawCollision")
check("setCollision: x", col.args[1], 10)
check("setCollision: z БЕЗ отрицания", col.args[2], -20)
check("setCollision: тег по имени", col.args[3], 87)
check("setCollision: радиус", col.args[4], 5)
check("collision читает обратно", terrain.collision(10, -20), 87)
check("collision: где не красили — ноль", terrain.collision(999, 999), 0)
check("setCollision: неизвестное имя падает",
      select(1, pcall(terrain.setCollision, 0, 0, "нетакого")), false)

-- terrain.water — все три части сразу: яма, проходимость, зеркало.
FAKE_WATER, NATIVE_LOG = {}, {}
local idx = terrain.water(30, -40, { radius = 6, depth = 3, level = -2, name = "река" })
local names = {}
for _, e in ipairs(NATIVE_LOG) do names[e.name] = (names[e.name] or 0) + 1 end
check("water: вырыл яму", names.LowerTerrain, 1)
check("water: закрасил проходимость", names.MapDrawCollision, 1)
check("water: одним мазком, а не по точкам", names.MapDrawCollision, 1)
check("water: пересчитал рельеф", names["terr.update"], 1)
check("water: завёл водоём", water.count(), 1)
check("water: вернул индекс", idx, 0)
local made = water.get(0)
check("water: имя", made.name, "река")
check("water: уровень", made.level, -2)
check("water: прямоугольник по радиусу", made.x1, 24)
check("water: тег воды на месте", terrain.collision(30, -40), 87)

-- Клетки и мировые координаты: карта 320 идёт от -160 до +160.
local ci, cj = terrain.cell(-160, 160)
check("cell: левый край -> 0", ci, 0)
check("cell: правый край -> 320", cj, 320)
check("cell: центр", select(1, terrain.cell(0, 0)), 160)
local wx, wz = terrain.world(160, 160)
check("world: центр клетки по x", wx, 0.5)
check("world: центр клетки по z", wz, 0.5)

-- Точка под курсором: три значения, не два (на этом сгорел iron_frontier).
check("cursor: три значения", select("#", world.cursor()), 3)
local cx, cy, cz = world.cursor()
check("cursor: x", cx, 12.5)
check("cursor: высота вторым", cy, 3.25)
check("cursor: z третьим", cz, -40.75)

-- utility libraries 60-70: отдельные файлы, свой счёт
local utilPassed, utilFailed = 0, 0
for _, f in ipairs({ "util_pure", "util_sim", "util_world" }) do
    dofile(here .. "/" .. f .. ".lua")
end
for _, fn in ipairs({ run_util_pure, run_util_sim, run_util_world }) do
    local p, fl = fn()
    utilPassed, utilFailed = utilPassed + p, utilFailed + fl
end
passed, failed = passed + utilPassed, failed + utilFailed
print(("utility modules: 11, tests %d/%d"):format(utilPassed, utilPassed + utilFailed))
-- Итог печатается ПОСЛЕДНИМ: tools/run_tests.py показывает рядом с названием
-- набора его последнюю строку, и раньше там оказывалось "failed: 0" из отчёта
-- утилит — даже когда падали проверки api.
print(("api: %d module(s), %d passed, %d failed"):format(#loaded, passed, failed))
os.exit(failed == 0 and 0 or 1)
