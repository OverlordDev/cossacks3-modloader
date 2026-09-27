-- Тесты util-модулей query/validate/config/color на подставной игре.
-- Запуск (из корня репозитория):
--   .\tools\api_test\lua.exe -e "dofile('tools/api_test/fake_game.lua'); dofile('api/68_validate.lua'); dofile('api/67_query.lua'); dofile('api/69_config.lua'); dofile('api/70_color.lua'); dofile('tools/api_test/util_world.lua'); local p,f=run_util_world(); print(p,f); assert(f==0)"

-- Глобальный прогон: возвращает passed, failed.
function run_util_world()
    local passed, failed = 0, 0
    local function check(title, got, want)
        local ok = got == want
        if not ok and type(want) == "number" and type(got) == "number" then
            ok = math.abs(got - want) < 1e-6
        end
        if ok then passed = passed + 1
        else
            failed = failed + 1
            print(("FAIL %s: got %s, want %s"):format(title, tostring(got), tostring(want)))
        end
    end
    local function checkTrue(title, v) check(title, v, true) end
    local function checkErr(title, fn)
        local ok = pcall(fn)
        if not ok then passed = passed + 1
        else
            failed = failed + 1
            print("FAIL " .. title .. ": expected error, got ok")
        end
    end
    local function checkOk(title, fn)
        local ok, err = pcall(fn)
        if ok then passed = passed + 1
        else
            failed = failed + 1
            print("FAIL " .. title .. ": unexpected error: " .. tostring(err))
        end
    end

    -- ---------- validate ----------
    do
        checkOk("v.num ok", function() validate.number(5, "x", { min = 0, max = 10 }) end)
        check("v.num boundary min", validate.number(0, "x", { min = 0, max = 10 }), 0)
        check("v.num boundary max", validate.number(10, "x", { min = 0, max = 10 }), 10)
        checkErr("v.num nil", function() validate.number(nil, "x") end)
        checkErr("v.num str", function() validate.number("5", "x") end)
        checkErr("v.num nan", function() validate.number(0 / 0, "x") end)
        checkErr("v.num inf default", function() validate.number(math.huge, "x") end)
        check("v.num inf allowed", validate.number(math.huge, "x", { finite = false }), math.huge)
        checkErr("v.num below min", function() validate.number(-1, "x", { min = 0 }) end)
        checkErr("v.num above max", function() validate.number(11, "x", { max = 10 }) end)
        check("v.int ok", validate.integer(5, "i"), 5)
        check("v.int float-int", validate.integer(5.0, "i"), 5)
        checkErr("v.int frac", function() validate.integer(1.5, "i") end)
        checkErr("v.int str", function() validate.integer("5", "i") end)
        checkErr("v.int nil", function() validate.integer(nil, "i") end)
        checkErr("v.int nan", function() validate.integer(0 / 0, "i") end)
        checkErr("v.int inf", function() validate.integer(math.huge, "i") end)
        checkOk("v.int range ok", function() validate.integer(3, "i", { min = 1, max = 5 }) end)
        checkErr("v.int range low", function() validate.integer(0, "i", { min = 1 }) end)
        checkErr("v.int range high", function() validate.integer(6, "i", { max = 5 }) end)
        checkOk("v.bool true", function() validate.boolean(true, "b") end)
        checkOk("v.bool false", function() validate.boolean(false, "b") end)
        checkErr("v.bool nil", function() validate.boolean(nil, "b") end)
        checkErr("v.bool 0", function() validate.boolean(0, "b") end)
        checkErr("v.bool str", function() validate.boolean("true", "b") end)
        checkOk("v.str ok", function() validate.string("hi", "s") end)
        checkErr("v.str nil", function() validate.string(nil, "s") end)
        checkErr("v.str num", function() validate.string(5, "s") end)
        checkErr("v.str empty", function() validate.string("", "s", { nonEmpty = true }) end)
        checkErr("v.str minLen", function() validate.string("ab", "s", { minLen = 3 }) end)
        checkErr("v.str maxLen", function() validate.string("abcd", "s", { maxLen = 3 }) end)
        checkOk("v.str pattern ok", function() validate.string("123", "s", { pattern = "^%d+$" }) end)
        checkErr("v.str pattern fail", function() validate.string("abc", "s", { pattern = "^%d+$" }) end)
        check("v.handle pos", validate.handle(5, "h"), 5)
        check("v.handle neg allowed", validate.handle(-7, "h"), -7)
        checkErr("v.handle zero", function() validate.handle(0, "h") end)
        checkErr("v.handle nil", function() validate.handle(nil, "h") end)
        checkErr("v.handle str", function() validate.handle("x", "h") end)
        checkErr("v.handle frac", function() validate.handle(1.5, "h") end)
        checkOk("v.pos ok", function() validate.position({ x = 1, z = 2 }, "p") end)
        checkErr("v.pos nil", function() validate.position(nil, "p") end)
        checkErr("v.pos num", function() validate.position(5, "p") end)
        checkErr("v.pos missing z", function() validate.position({ x = 1 }, "p") end)
        checkErr("v.pos nan", function() validate.position({ x = 0 / 0, z = 1 }, "p") end)
        checkErr("v.pos inf", function() validate.position({ x = math.huge, z = 1 }, "p") end)
        checkErr("v.pos garbage tbl", function() validate.position({ a = 1 }, "p") end)
        checkOk("v.enum ok", function() validate.enum("a", { "a", "b" }, "e") end)
        checkErr("v.enum bad", function() validate.enum("c", { "a", "b" }, "e") end)
        checkErr("v.enum nil", function() validate.enum(nil, { "a" }, "e") end)
        checkOk("v.list ok", function() validate.list({ 1, 2 }, "l") end)
        checkOk("v.list empty", function() validate.list({}, "l") end)
        checkErr("v.list nil", function() validate.list(nil, "l") end)
        checkErr("v.list dict", function() validate.list({ a = 1 }, "l") end)
        checkErr("v.list hole", function() validate.list({ 1, nil, 3 }, "l") end)
        checkErr("v.list minLen", function() validate.list({ 1 }, "l", { minLen = 2 }) end)
        checkErr("v.list of fail", function()
            validate.list({ 1, "x" }, "l", { of = function(v) validate.number(v, "it") end })
        end)
        checkOk("v.table ok", function() validate.table({}, "t") end)
        checkErr("v.table nil", function() validate.table(nil, "t") end)
        checkErr("v.table num", function() validate.table(5, "t") end)
        -- контекст
        checkOk("v.activeGame ok", function() validate.activeGame("t") end)
        do
            local f = game.isInGame
            game.isInGame = function() return false end
            checkErr("v.activeGame no game", function() validate.activeGame("t") end)
            game.isInGame = f
        end
        checkOk("v.server ok", function() validate.server("t") end)
        do
            local e = game.exec
            game.exec = nil
            checkErr("v.server no exec", function() validate.server("t") end)
            game.exec = e
        end
        checkErr("v.client no side", function() validate.client("t") end)
        do
            game.side = "client"
            checkOk("v.client ok", function() validate.client("t") end)
            game.side = "server"
            checkErr("v.client wrong side", function() validate.client("t") end)
            game.side = nil
        end
        -- ошибки называют функцию
        do
            local ok, err = pcall(validate.number, nil, "myx")
            check("v.err names fn", (tostring(err):find("validate.number") ~= nil), true)
            local ok2, err2 = pcall(validate.handle, 0, "myh")
            check("v.err handle fn", (tostring(err2):find("validate.handle") ~= nil), true)
        end
    end

    -- ---------- query ----------
    do
        local origRead, origPos = objects.read, objects.pos
        local origSid = native.GetGameObjectBaseNameByHandle
        local origExec = game.exec
        -- базовый скан: 3 fake-объекта
        do
            local recs = query.scan({})
            check("q.scan count", #recs, 3)
            check("q.rec handle", recs[1].handle ~= nil, true)
            check("q.rec x", recs[1].x, 11)
            check("q.rec z", recs[1].z, 22)
            check("q.rec hp", recs[1].hp, 80)
            check("q.rec player", recs[1].player, 0)
            check("q.rec sid", recs[1].sid, "musketeer18")
            check("q.count", query.count({}), 3)
            check("q.first", query.first({}) ~= nil, true)
            check("q.limit", #query.scan({ limit = 2 }), 2)
            check("q.predicate", #query.scan({ predicate = function(r) return r.handle > 1 end }), 2)
            check("q.byPlayer 0", #query.byPlayer(0, {}), 3)
            check("q.byPlayer 1", #query.byPlayer(1, {}), 0)
            check("q.enemies none", #query.enemies(0, {}), 0)
            check("q.allies all", #query.allies(0, {}), 3)
            check("q.inArea all", #query.inArea(11, 22, 1, {}), 3)
            check("q.inArea none", #query.inArea(0, 0, 1, {}), 0)
            local n = query.nearest(0, 0, {})
            check("q.nearest", n ~= nil, true)
        end
        -- разные pl
        objects.read = function(h) return { pl = (h == 2 and 1 or 0), hp = 80 } end
        check("q.filter player", #query.scan({ player = 1 }), 1)
        check("q.enemies of 0", #query.enemies(0, {}), 1)
        check("q.allies of 0", #query.allies(0, {}), 2)
        objects.read = origRead
        -- sid-фильтр
        native.GetGameObjectBaseNameByHandle = function(h)
            if h == 3 then return "mill18" end
            return "musketeer18"
        end
        check("q.filter sid", #query.scan({ sid = "mill18" }), 1)
        check("q.byType units", #query.byType("units", "musketeer18", {}), 2)
        checkErr("q.byType bad kind", function() query.byType("nope", "x", {}) end)
        native.GetGameObjectBaseNameByHandle = origSid
        -- alive: по умолчанию только живые
        objects.read = function(h)
            if h == 1 then return { pl = 0, hp = 0, bdead = true } end
            return { pl = 0, hp = 80 }
        end
        check("q.alive default", #query.scan({}), 2)
        check("q.alive false all", #query.scan({ alive = false }), 3)
        objects.read = origRead
        -- геометрия и сортировка
        objects.pos = function(h)
            if h == 1 then return 0, 0 end
            if h == 2 then return 10, 0 end
            return 100, 100
        end
        check("q.around", #query.scan({ around = { x = 0, z = 0, radius = 15 } }), 2)
        check("q.around+radius", #query.scan({ around = { x = 0, z = 0 }, radius = 15 }), 2)
        check("q.rect", #query.scan({ rect = { x1 = -5, z1 = -5, x2 = 15, z2 = 5 } }), 2)
        do
            local s = query.scan({ sortByDistanceFrom = { x = 0, z = 0 } })
            check("q.sort 1st", s[1].handle, 1)
            check("q.sort 2nd", s[2].handle, 2)
            check("q.sort 3rd", s[3].handle, 3)
        end
        check("q.limit+sort", #query.scan({ sortByDistanceFrom = { x = 0, z = 0 }, limit = 1 }), 1)
        do
            local s = query.scan({ sortByDistanceFrom = { x = 0, z = 0 }, limit = 1 })
            check("q.limit+sort first", s[1].handle, 1)
        end
        check("q.nearest sorted", query.nearest(0, 0, {}).handle, 1)
        check("q.inArea sorted", #query.inArea(0, 0, 15, {}), 2)
        objects.pos = origPos
        -- building: один batched exec c gObjProp
        objects.read = function(h)
            if h == 3 then return { pl = 0, hp = 80, cid = 2, id = 2 } end
            return { pl = 0, hp = 80, cid = 1, id = 1 }
        end
        do
            EXEC_LOG = {}
            local nB = #query.buildings({})
            check("q.build exec once", #EXEC_LOG, 1)
            check("q.build gObjProp", (EXEC_LOG[1]:find("gObjProp") ~= nil), true)
            check("q.build bbuilding", (EXEC_LOG[1]:find("bbuilding") ~= nil), true)
            check("q.build fake empty", nB, 0)
            EXEC_LOG = {}
            check("q.units all", #query.units({}), 3)
            check("q.units exec once", #EXEC_LOG, 1)
        end
        do
            local calls, codes = 0, {}
            game.exec = function(code)
                calls = calls + 1
                codes[#codes + 1] = code
                return "1;0;"
            end
            local b = query.buildings({})
            check("q.build stub once", calls, 1)
            check("q.build stub gObjProp", (codes[1]:find("gObjProp") ~= nil), true)
            check("q.build stub count", #b, 2)
            local u = query.units({})
            check("q.units stub count", #u, 1)
            check("q.units stub handle", u[1].handle, 3)
            game.exec = origExec
        end
        do
            game.exec = nil
            checkErr("q.build no exec", function() query.scan({ building = true }) end)
            checkOk("q.scan no build no exec", function() query.scan({}) end)
            game.exec = origExec
        end
        objects.read = origRead
        -- ошибки опций
        checkErr("q.bad limit", function() query.scan({ limit = 0 }) end)
        checkErr("q.bad around", function() query.scan({ around = { x = 0, z = 0 } }) end)
        checkErr("q.bad rect", function() query.scan({ rect = { x1 = 0 } }) end)
        checkErr("q.bad predicate", function() query.scan({ predicate = 5 }) end)
    end

    -- ---------- config ----------
    do
        checkErr("c.bad link", function() config.link({}) end)
        checkErr("c.nolink load", function() config.load("ut_nolink_x", {}) end)
        config.link(savedata)
        -- get/set/dirty/save
        do
            savedata._d["cfg:ut_basic"] = nil
            local cfg = config.load("ut_basic", { a = 1, b = "x" })
            check("c.get", cfg:get("a"), 1)
            check("c.get fb", cfg:get("missing", "fb"), "fb")
            check("c.clean", cfg:isDirty(), false)
            cfg:set("a", 2)
            check("c.set", cfg:get("a"), 2)
            check("c.dirty", cfg:isDirty(), true)
            check("c.save true", cfg:save(), true)
            check("c.saved", savedata.get("cfg:ut_basic").a, 2)
            check("c.clean2", cfg:isDirty(), false)
            check("c.save false", cfg:save(), false)
            cfg:set("b", "y")
            cfg:reset("b")
            check("c.reset key", cfg:get("b"), "x")
            cfg:set("a", 9)
            cfg:reset()
            check("c.reset all", cfg:get("a"), 1)
        end
        -- migrate
        do
            savedata.set("cfg:ut_mig", { _version = 1, a = 5, old = 9 })
            local cfg = config.load("ut_mig", { _version = 2, a = 1 },
                { migrate = function(old) return { _version = 2, a = old.a } end })
            check("c.migrate", cfg:get("a"), 5)
            check("c.migrate dirty", cfg:isDirty(), true)
            savedata.set("cfg:ut_mig2", { _version = 1, a = 5 })
            local cfg2 = config.load("ut_mig2", { _version = 2, a = 1 })
            check("c.migrate reset", cfg2:get("a"), 1)
        end
        -- corrupt: не таблица → defaults
        do
            savedata.set("cfg:ut_bad", "garbage")
            local cfg = config.load("ut_bad", { a = 7 })
            check("c.corrupt", cfg:get("a"), 7)
        end
        -- лимиты
        do
            savedata._d["cfg:ut_lim"] = nil
            local cfg = config.load("ut_lim", { a = 1 })
            checkErr("c.limit depth", function()
                cfg:set("deep", { l1 = { l2 = { l3 = { l4 = { l5 = { l6 = 1 } } } } } })
            end)
            checkErr("c.limit keys", function()
                local big = {}
                for i = 1, 1001 do big["k" .. i] = i end
                cfg:set("big", big)
            end)
        end
        -- один ключ на таблицу
        do
            savedata._d["cfg:ut_one"] = nil
            local cfg = config.load("ut_one", { a = 1, b = 2 })
            cfg:set("a", 3)
            cfg:save()
            local stored = savedata.get("cfg:ut_one")
            check("c.onekey tbl", type(stored), "table")
            check("c.onekey val", stored.a, 3)
        end
        -- автосейв game.end
        do
            savedata._d["cfg:ut_auto"] = nil
            local cfg = config.load("ut_auto", { a = 1 })
            cfg:set("a", 42)
            check("c.auto dirty", cfg:isDirty(), true)
            fireEvt("game.end")
            check("c.auto saved", savedata.get("cfg:ut_auto").a, 42)
            check("c.auto clean", cfg:isDirty(), false)
        end
    end

    -- ---------- color ----------
    do
        do
            local c = color.rgb(300, -5, 128)
            check("col.rgb r", c.r, 255)
            check("col.rgb g", c.g, 0)
            check("col.rgb b", c.b, 128)
            check("col.rgb a", c.a, 255)
        end
        do
            local c = color.rgba(10, 20, 30, 300)
            check("col.rgba a clamp", c.a, 255)
            local c2 = color.rgba(10, 20, 30, -5)
            check("col.rgba a low", c2.a, 0)
        end
        checkErr("col.rgb nan", function() color.rgb(0 / 0, 0, 0) end)
        do
            local c = color.hex("#FF0000")
            check("col.hex r", c.r, 255)
            check("col.hex g", c.g, 0)
            local c2 = color.hex("ff0000")
            check("col.hex nohash lower", c2.r, 255)
            local c3 = color.hex("#F00")
            check("col.hex short", c3.g, 0)
            local c4 = color.hex("#FF000080")
            check("col.hex alpha", c4.a, 128)
            checkErr("col.hex garbage", function() color.hex("zzz") end)
            checkErr("col.hex bad len", function() color.hex("#12345") end)
        end
        do
            local c = color.withAlpha(color.red, 128)
            check("col.alpha", c.a, 128)
            check("col.alpha keep r", c.r, 255)
            check("col.alpha clamp", color.withAlpha(color.red, 300).a, 255)
            check("col.alpha low", color.withAlpha(color.red, -5).a, 0)
        end
        do
            local m = color.lerp(color.red, color.blue, 0)
            check("col.lerp t0 r", m.r, 255)
            local m1 = color.lerp(color.red, color.blue, 1)
            check("col.lerp t1 b", m1.b, 255)
            local mh = color.lerp(color.red, color.blue, 0.5)
            check("col.lerp mid r", mh.r, 128)
            check("col.lerp mid b", mh.b, 128)
            check("col.lerp clamp low", color.lerp(color.red, color.blue, -1).r, 255)
            check("col.lerp clamp high", color.lerp(color.red, color.blue, 2).b, 255)
        end
        check("col.toHex", color.toHex(color.red), "#FF0000")
        check("col.toHex alpha", color.toHex(color.red, true), "#FF0000FF")
        check("col.const red", color.red.r, 255)
        check("col.const transparent", color.transparent.a, 0)
        check("col.const yellow", color.yellow.g, 255)
        check("col.const black", color.black.r, 0)
        check("col.const white", color.white.r, 255)
        check("col.const green", color.green.g, 255)
        check("col.const blue", color.blue.b, 255)
    end

    return passed, failed
end
