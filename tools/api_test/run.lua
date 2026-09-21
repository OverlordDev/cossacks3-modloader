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
                        "13_players", "14_map", "15_screens", "16_mirror", "17_balance", "18_buildings", "90_call" }) do
    local path = root .. "/api/" .. name .. ".lua"
    local chunk, err = loadfile(path, "t", _ENV)
    assert(chunk, err)
    chunk()
    loaded[#loaded + 1] = name
end

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

-- state.set: все типы и что код постоянный (значение идёт аргументом)
state.set("gProfile.sndmaster", 0.3)
check("set float", FAKE.gProfile.sndmaster, 0.3)
state.set("gProfile.igamespeed", 4)
check("set int", FAKE.gProfile.igamespeed, 4)
state.set("gProfile.bclipmouse", false)
check("set bool", FAKE.gProfile.bclipmouse, false)
state.set("gProfile.lang", "en")
check("set string", FAKE.gProfile.lang, "en")
check("set code has no value", EXEC_LOG[1], "gProfile.sndmaster := StrToInt(ML_ARG) / 1000000;")

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
    check("buildings.info price", b.produce[1].price[4], 5)
    check("buildings.info upgrade", b.upgrades[1].sid, "upg_bayonet")
    check("buildings.info queue", b.queue[1].kind, "unit")
    check("buildings.info progress", b.queue[1].progress, 0.25)
    check("buildings.produce", buildings.produce(777, "musketeer18", 5), true)
    game.exec = realExec
end

print(("api: %d module(s), %d passed, %d failed"):format(#loaded, passed, failed))
os.exit(failed == 0 and 0 or 1)
