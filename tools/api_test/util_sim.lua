-- util_sim — тесты api/64_geometry.lua, api/65_scheduler.lua, api/66_rng.lua.
--
-- Запуск (корень репозитория):
--   .\tools\api_test\lua.exe -e "dofile('tools/api_test/fake_game.lua'); dofile('api/64_geometry.lua'); dofile('api/65_scheduler.lua'); dofile('api/66_rng.lua'); dofile('tools/api_test/util_sim.lua'); local p,f=run_util_sim(); print(p,f); assert(f==0)"
--
-- В fake нет native.GetGameTime — задаём его ЗДЕСЬ с управляемым clock:
-- scheduler берёт время через pcall(native.GetGameTime), так тесты контролируют время.

UTIL_CLOCK = UTIL_CLOCK or { t = 1000 }
native.GetGameTime = function() return UTIL_CLOCK.t end

-- Фейковый events.off в fake_game.lua — no-op, из-за чего ленивая подписка
-- scheduler дублировала бы хендлеры в тестах. Чиним шину: уникальные id + рабочий off.
do
    local seq = 0
    local byId = {}
    local origEvt = EVT or {}
    EVT = origEvt
    events.on = function(name, fn)
        seq = seq + 1
        local id = seq
        EVT[name] = EVT[name] or {}
        EVT[name][#EVT[name] + 1] = { __uid = id, __fn = fn }
        byId[id] = { name = name }
        return id
    end
    events.off = function(id)
        local rec = byId[id]
        if not rec then return end
        byId[id] = nil
        local list = EVT[rec.name] or {}
        for i = #list, 1, -1 do
            local e = list[i]
            if type(e) == "table" and e.__uid == id then
                table.remove(list, i)
            end
        end
    end
    fireEvt = function(name, ...)
        local list = EVT[name] or {}
        local snap = {}
        for i = 1, #list do snap[i] = list[i] end
        for _, e in ipairs(snap) do
            local fn = nil
            if type(e) == "table" then fn = e.__fn else fn = e end
            if type(fn) == "function" then fn(...) end
        end
    end
end

-- Прогон всех util-тестов. Возвращает passed, failed.
function run_util_sim()
    local passed, failed = 0, 0
    local function check(title, got, want)
        local ok = got == want
        if type(want) == "number" and type(got) == "number" then
            ok = math.abs(got - want) < 1e-6
        end
        if ok then
            passed = passed + 1
        else
            failed = failed + 1
            print(("FAIL %s: got %s, want %s"):format(title, tostring(got), tostring(want)))
        end
    end
    local function checkTrue(title, v) check(title, v and true or false, true) end
    local function checkFalse(title, v) check(title, v and true or false, false) end
    local function checkErr(title, fn, frag)
        local ok, err = pcall(fn)
        if ok then
            failed = failed + 1
            print(("FAIL %s: expected error, got ok"):format(title))
            return
        end
        if frag and not tostring(err):find(frag, 1, true) then
            failed = failed + 1
            print(("FAIL %s: error %s lacks %s"):format(title, tostring(err), frag))
            return
        end
        passed = passed + 1
    end
    local function approx(title, got, want, eps)
        eps = eps or 1e-6
        if type(got) == "number" and type(want) == "number"
            and math.abs(got - want) <= eps then
            passed = passed + 1
        else
            failed = failed + 1
            print(("FAIL %s: got %s, want %s"):format(title, tostring(got), tostring(want)))
        end
    end

    -- ===== geometry =====
    do
        local a = { x = 0, z = 0 }
        local b = { x = 3, z = 4 }
        check("geo.dist", geometry.distance(a, b), 5)
        check("geo.dist2", geometry.distanceSquared(a, b), 25)
        -- y игнорируется в 2D
        check("geo.dist y ignored",
            geometry.distance({ x = 0, y = 999, z = 0 }, { x = 3, y = -5, z = 4 }), 5)
        check("geo.dist no mutate", a.x, 0)
        -- круг: граница включительно
        checkTrue("geo.inCircle inside", geometry.inCircle({ x = 0, z = 0 }, { x = 0, z = 0 }, 5))
        checkTrue("geo.inCircle border", geometry.inCircle({ x = 3, z = 4 }, { x = 0, z = 0 }, 5))
        checkTrue("geo.inCircle border axis", geometry.inCircle({ x = 5, z = 0 }, { x = 0, z = 0 }, 5))
        checkFalse("geo.inCircle outside", geometry.inCircle({ x = 5.001, z = 0 }, { x = 0, z = 0 }, 5))
        checkErr("geo.inCircle bad r", function()
            geometry.inCircle({ x = 0, z = 0 }, { x = 0, z = 0 }, -1)
        end, "geometry.inCircle")
        -- прямоугольник: границы включительно + неупорядоченный rect
        local r = { x1 = 0, z1 = 0, x2 = 10, z2 = 10 }
        checkTrue("geo.inRect inside", geometry.inRect({ x = 5, z = 5 }, r))
        checkTrue("geo.inRect border", geometry.inRect({ x = 0, z = 0 }, r))
        checkTrue("geo.inRect border2", geometry.inRect({ x = 10, z = 10 }, r))
        checkFalse("geo.inRect outside", geometry.inRect({ x = 10.1, z = 10 }, r))
        checkFalse("geo.inRect outside2", geometry.inRect({ x = -0.1, z = 0 }, r))
        checkTrue("geo.inRect unordered",
            geometry.inRect({ x = 5, z = 5 }, { x1 = 10, z1 = 10, x2 = 0, z2 = 0 }))
        -- сектор: ось +x, полуугол 45°, дальность 10
        local org = { x = 0, z = 0 }
        checkTrue("geo.sector axis", geometry.inSector({ x = 5, z = 0 }, org, 0, math.pi / 4, 10))
        checkTrue("geo.sector border angle",
            geometry.inSector({ x = 5, z = 5 }, org, 0, math.pi / 4, 10))
        checkFalse("geo.sector outside angle",
            geometry.inSector({ x = 0, z = 5 }, org, 0, math.pi / 4, 10))
        checkFalse("geo.sector outside r",
            geometry.inSector({ x = 11, z = 0 }, org, 0, math.pi / 4, 10))
        checkTrue("geo.sector border r",
            geometry.inSector({ x = 10, z = 0 }, org, 0, math.pi / 4, 10))
        checkTrue("geo.sector origin", geometry.inSector({ x = 0, z = 0 }, org, 0, 0.1, 10))
        checkTrue("geo.sector full",
            geometry.inSector({ x = -5, z = 0 }, org, 0, math.pi, 10))
        -- отрезок: проекция + вырожденный
        local c = geometry.closestPointOnSegment({ x = 5, z = 5 }, { x = 0, z = 0 }, { x = 10, z = 0 })
        approx("geo.closest x", c.x, 5)
        approx("geo.closest z", c.z, 0)
        local cd = geometry.closestPointOnSegment({ x = 0, z = 0 }, { x = 3, z = 4 }, { x = 3, z = 4 })
        check("geo.degenerate seg x", cd.x, 3)
        check("geo.degenerate seg z", cd.z, 4)
        check("geo.distToSeg", geometry.distanceToSegment({ x = 5, z = 5 }, { x = 0, z = 0 }, { x = 10, z = 0 }), 5)
        check("geo.distToSeg degenerate",
            geometry.distanceToSegment({ x = 0, z = 0 }, { x = 3, z = 4 }, { x = 3, z = 4 }), 5)
        -- пересечение прямых + параллели
        local ip = geometry.lineIntersection(
            { x = 0, z = 0 }, { x = 10, z = 10 }, { x = 0, z = 10 }, { x = 10, z = 0 })
        approx("geo.intersect x", ip.x, 5)
        approx("geo.intersect z", ip.z, 5)
        check("geo.parallel", geometry.lineIntersection(
            { x = 0, z = 0 }, { x = 10, z = 0 }, { x = 0, z = 5 }, { x = 10, z = 5 }), nil)
        checkErr("geo.line degenerate", function()
            geometry.lineIntersection({ x = 1, z = 1 }, { x = 1, z = 1 },
                { x = 0, z = 0 }, { x = 1, z = 0 })
        end, "geometry.lineIntersection")
        -- полигон: внутри/снаружи/граница/вершина/вырожденные
        local sq = { { x = 0, z = 0 }, { x = 10, z = 0 }, { x = 10, z = 10 }, { x = 0, z = 10 } }
        checkTrue("geo.poly inside", geometry.polygonContains({ x = 5, z = 5 }, sq))
        checkFalse("geo.poly outside", geometry.polygonContains({ x = 15, z = 5 }, sq))
        checkTrue("geo.poly border", geometry.polygonContains({ x = 0, z = 5 }, sq))
        checkTrue("geo.poly vertex", geometry.polygonContains({ x = 0, z = 0 }, sq))
        checkFalse("geo.poly degenerate empty", geometry.polygonContains({ x = 0, z = 0 }, {}))
        checkFalse("geo.poly degenerate 1", geometry.polygonContains({ x = 0, z = 0 }, { { x = 0, z = 0 } }))
        checkFalse("geo.poly degenerate 2", geometry.polygonContains({ x = 0, z = 0 },
            { { x = 0, z = 0 }, { x = 1, z = 1 } }))
        local ctr = geometry.polygonCenter(sq)
        approx("geo.center x", ctr.x, 5)
        approx("geo.center z", ctr.z, 5)
        checkErr("geo.center empty", function() geometry.polygonCenter({}) end,
            "geometry.polygonCenter")
        local bb = geometry.polygonBounds(sq)
        check("geo.bounds x1", bb.x1, 0)
        check("geo.bounds z1", bb.z1, 0)
        check("geo.bounds x2", bb.x2, 10)
        check("geo.bounds z2", bb.z2, 10)
        checkErr("geo.bounds empty", function() geometry.polygonBounds({}) end,
            "geometry.polygonBounds")
        -- окружность/поворот/азимут
        local pts = geometry.circlePoints({ x = 0, z = 0 }, 1, 4, 0)
        check("geo.circle count", #pts, 4)
        approx("geo.circle p1x", pts[1].x, 1)
        approx("geo.circle p1z", pts[1].z, 0)
        approx("geo.circle p2x", pts[2].x, 0)
        approx("geo.circle p2z", pts[2].z, 1)
        local pts0 = geometry.circlePoints({ x = 0, z = 0 }, 1, 4)
        approx("geo.circle default angle", pts0[1].x, 1)
        local rp = geometry.rotatePoint({ x = 1, z = 0 }, { x = 0, z = 0 }, math.pi / 2)
        approx("geo.rotate x", rp.x, 0)
        approx("geo.rotate z", rp.z, 1)
        local rp0 = geometry.rotatePoint({ x = 1, z = 2 }, { x = 0, z = 0 }, 0)
        approx("geo.rotate zero x", rp0.x, 1)
        approx("geo.look east", geometry.lookAngle({ x = 0, z = 0 }, { x = 1, z = 0 }), 0)
        approx("geo.look north", geometry.lookAngle({ x = 0, z = 0 }, { x = 0, z = 1 }), math.pi / 2)
        checkErr("geo.distance bad", function() geometry.distance(nil, { x = 0, z = 0 }) end,
            "geometry.distance")
    end

    -- ===== scheduler (время через UTIL_CLOCK + fireEvt game.tick) =====
    do
        scheduler.clear()
        UTIL_CLOCK.t = 1000
        check("sched.pending empty", scheduler.pending(), 0)
        check("sched.now", scheduler.now(), 1000)
        -- порядок при равном времени (монотонный seq)
        local order = {}
        scheduler.after(5, function() order[#order + 1] = 1 end)
        scheduler.after(5, function() order[#order + 1] = 2 end)
        scheduler.after(5, function() order[#order + 1] = 3 end)
        UTIL_CLOCK.t = 1004
        fireEvt("game.tick")
        check("sched.not yet", #order, 0)
        UTIL_CLOCK.t = 1005
        fireEvt("game.tick")
        check("sched.order n", #order, 3)
        check("sched.order 1", order[1], 1)
        check("sched.order 2", order[2], 2)
        check("sched.order 3", order[3], 3)
        scheduler.clear()
        -- отмена
        local hit = 0
        local id = scheduler.after(10, function() hit = hit + 1 end)
        checkTrue("sched.cancel ok", scheduler.cancel(id))
        checkFalse("sched.cancel twice", scheduler.cancel(id))
        checkFalse("sched.cancel unknown", scheduler.cancel(999999))
        UTIL_CLOCK.t = 2000
        fireEvt("game.tick")
        check("sched.cancelled no fire", hit, 0)
        scheduler.clear()
        -- группы
        UTIL_CLOCK.t = 3000
        local ghit = {}
        scheduler.after(5, function() ghit[#ghit + 1] = "a1" end, { group = "g1" })
        scheduler.after(5, function() ghit[#ghit + 1] = "a2" end, { group = "g1" })
        scheduler.after(5, function() ghit[#ghit + 1] = "b1" end, { group = "g2" })
        check("sched.pending all", scheduler.pending(), 3)
        check("sched.pending g1", scheduler.pending("g1"), 2)
        check("sched.cancelGroup", scheduler.cancelGroup("g1"), 2)
        check("sched.pending after group", scheduler.pending(), 1)
        UTIL_CLOCK.t = 3005
        fireEvt("game.tick")
        check("sched.group fired n", #ghit, 1)
        check("sched.group fired which", ghit[1], "b1")
        scheduler.clear()
        -- every без backlog: прыжок через 3 интервала даёт 1 вызов
        UTIL_CLOCK.t = 4000
        local ec = 0
        scheduler.every(5, function() ec = ec + 1 end)
        UTIL_CLOCK.t = 4005
        fireEvt("game.tick")
        check("sched.every 1", ec, 1)
        UTIL_CLOCK.t = 4020 -- пропущены 4010/4015/4020
        fireEvt("game.tick")
        check("sched.every no backlog", ec, 2)
        UTIL_CLOCK.t = 4024
        fireEvt("game.tick")
        check("sched.every not yet", ec, 2)
        UTIL_CLOCK.t = 4025
        fireEvt("game.tick")
        check("sched.every next", ec, 3)
        scheduler.clear()
        -- at (абсолютное время)
        UTIL_CLOCK.t = 5000
        local athit = 0
        scheduler.at(5010, function() athit = athit + 1 end)
        UTIL_CLOCK.t = 5009
        fireEvt("game.tick")
        check("sched.at not yet", athit, 0)
        UTIL_CLOCK.t = 5010
        fireEvt("game.tick")
        check("sched.at fired", athit, 1)
        scheduler.clear()
        -- debounce: только последний вызов стреляет
        UTIL_CLOCK.t = 6000
        local dc = 0
        scheduler.debounce("dk", 5, function() dc = dc + 1 end)
        UTIL_CLOCK.t = 6003
        scheduler.debounce("dk", 5, function() dc = dc + 1 end)
        UTIL_CLOCK.t = 6006
        fireEvt("game.tick")
        check("sched.debounce not yet", dc, 0)
        UTIL_CLOCK.t = 6008
        fireEvt("game.tick")
        check("sched.debounce fired once", dc, 1)
        UTIL_CLOCK.t = 7000
        fireEvt("game.tick")
        check("sched.debounce once only", dc, 1)
        scheduler.clear()
        -- throttle leading (по умолч.): сразу, повтор в окне игнор
        UTIL_CLOCK.t = 8000
        local tc = 0
        local r1 = scheduler.throttle("tk1", 10, function() tc = tc + 1 end)
        check("sched.throttle leading now", tc, 1)
        check("sched.throttle leading ret", r1, 0)
        local r2 = scheduler.throttle("tk1", 10, function() tc = tc + 1 end)
        check("sched.throttle suppressed", tc, 1)
        check("sched.throttle suppressed ret", r2, nil)
        UTIL_CLOCK.t = 8010
        local r3 = scheduler.throttle("tk1", 10, function() tc = tc + 1 end)
        check("sched.throttle after window", tc, 2)
        check("sched.throttle after ret", r3, 0)
        scheduler.clear()
        -- throttle trailing (leading=false): план на конец окна
        UTIL_CLOCK.t = 9000
        local trc = 0
        local tid = scheduler.throttle("tk2", 10, function() trc = trc + 1 end, false)
        check("sched.trailing not immediate", trc, 0)
        checkTrue("sched.trailing id", type(tid) == "number" and tid > 0)
        UTIL_CLOCK.t = 9005
        fireEvt("game.tick")
        check("sched.trailing not yet", trc, 0)
        UTIL_CLOCK.t = 9010
        fireEvt("game.tick")
        check("sched.trailing fired", trc, 1)
        scheduler.clear()
        -- ошибка колбэка не останавливает остальных
        UTIL_CLOCK.t = 10000
        local okhit = 0
        scheduler.after(1, function() error("boom") end)
        scheduler.after(1, function() okhit = okhit + 1 end)
        UTIL_CLOCK.t = 10001
        local okTick, tickErr = pcall(fireEvt, "game.tick")
        checkTrue("sched.err isolated tick ok", okTick)
        check("sched.err other fired", okhit, 1)
        scheduler.clear()
        -- очистка по game.end (и game.menu ставит тот же clear)
        UTIL_CLOCK.t = 11000
        local eh = 0
        scheduler.after(5, function() eh = eh + 1 end)
        check("sched.before end", scheduler.pending(), 1)
        fireEvt("game.end")
        check("sched.after end", scheduler.pending(), 0)
        UTIL_CLOCK.t = 11005
        fireEvt("game.tick")
        check("sched.end no fire", eh, 0)
        UTIL_CLOCK.t = 12000
        scheduler.after(5, function() eh = eh + 1 end)
        fireEvt("game.menu")
        check("sched.after menu", scheduler.pending(), 0)
        scheduler.clear()
        checkErr("sched.after bad", function() scheduler.after(-1, function() end) end,
            "scheduler.after")
        checkErr("sched.every bad", function() scheduler.every(0, function() end) end,
            "scheduler.every")
    end

    -- ===== rng =====
    do
        -- одинаковый seed → одинаковые последовательности
        local r1 = rng.new(12345)
        local r2 = rng.new(12345)
        local same = true
        for _ = 1, 20 do
            if r1:nextInt(1, 100) ~= r2:nextInt(1, 100) then same = false end
        end
        checkTrue("rng.same seed ints", same)
        local f1 = rng.new(777)
        local f2 = rng.new(777)
        local fsame = true
        for _ = 1, 20 do
            if f1:nextFloat() ~= f2:nextFloat() then fsame = false end
        end
        checkTrue("rng.same seed floats", fsame)
        -- setState восстанавливает
        local r = rng.new(42)
        r:nextInt(1, 1000)
        r:nextInt(1, 1000)
        local s = r:state()
        checkTrue("rng.state shape", type(s) == "table" and s.a ~= nil and s.b ~= nil)
        local b1 = r:nextInt(1, 1000)
        r:setState(s)
        local b2 = r:nextInt(1, 1000)
        check("rng.setState restores", b1, b2)
        -- границы nextInt
        check("rng.single value", rng.new(1):nextInt(5, 5), 5)
        local inRange = true
        local rr = rng.new(9)
        for _ = 1, 100 do
            local v = rr:nextInt(1, 10)
            if v < 1 or v > 10 then inRange = false end
        end
        checkTrue("rng.nextInt bounds", inRange)
        checkErr("rng.nextInt min>max", function() rng.new(1):nextInt(10, 1) end,
            "rng.nextInt")
        -- shuffle не мутирует вход
        local orig = { 1, 2, 3, 4, 5 }
        local rs = rng.new(2024)
        local sh = rs:shuffle(orig)
        check("rng.shuffle len", #sh, 5)
        local origOk = orig[1] == 1 and orig[2] == 2 and orig[3] == 3
            and orig[4] == 4 and orig[5] == 5
        checkTrue("rng.shuffle no mutate", origOk)
        checkTrue("rng.shuffle new table", sh ~= orig)
        local sorted = { sh[1], sh[2], sh[3], sh[4], sh[5] }
        table.sort(sorted)
        check("rng.shuffle permutation", table.concat(sorted, ","), "1,2,3,4,5")
        -- pick пустой → nil
        check("rng.pick empty", rng.new(3):pick({}), nil)
        checkTrue("rng.pick one", rng.new(3):pick({ 7 }) == 7)
        -- nextFloat/range/chance диапазоны
        local rf = rng.new(11)
        local fok = true
        for _ = 1, 50 do
            local v = rf:nextFloat()
            if v < 0 or v >= 1 then fok = false end
        end
        checkTrue("rng.nextFloat range", fok)
        local rv = rng.new(11):range(10, 20)
        checkTrue("rng.range bounds", rv >= 10 and rv < 20)
        checkTrue("rng.chance 1", rng.new(5):chance(1))
        checkFalse("rng.chance 0", rng.new(5):chance(0))
        -- сиды игры: детерминированы, без времени
        local g1 = rng.seedFromGame()
        local g2 = rng.seedFromGame()
        checkTrue("rng.seedFromGame number", type(g1) == "number")
        check("rng.seedFromGame stable", g1, g2)
        local s1 = rng.sharedSeed("loot")
        local s2 = rng.sharedSeed("loot")
        check("rng.sharedSeed stable", s1, s2)
        checkTrue("rng.sharedSeed differs",
            rng.sharedSeed("loot") ~= rng.sharedSeed("battle"))
        checkErr("rng.sharedSeed bad", function() rng.sharedSeed("") end,
            "rng.sharedSeed")
        checkErr("rng.new bad", function() rng.new("nope") end, "rng.new")
    end

    return passed, failed
end
