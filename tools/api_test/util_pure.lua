-- util_pure — тесты api/60_mathx.lua, api/61_vec.lua, api/62_tablex.lua, api/63_stringx.lua.
--
-- Запуск (корень репозитория; fake_game НЕ нужен — модули чистые):
--   .\tools\api_test\lua.exe -e "dofile('api/60_mathx.lua'); dofile('api/61_vec.lua'); dofile('api/62_tablex.lua'); dofile('api/63_stringx.lua'); dofile('tools/api_test/util_pure.lua'); local p,f=run_util_pure(); print(p,f); assert(f==0)"

-- Прогон всех pure-тестов. Возвращает passed, failed.
function run_util_pure()
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

    -- ===== mathx =====
    do
        check("mathx.clamp in", mathx.clamp(5, 0, 10), 5)
        check("mathx.clamp lo", mathx.clamp(-5, 0, 10), 0)
        check("mathx.clamp hi", mathx.clamp(15, 0, 10), 10)
        check("mathx.clamp border", mathx.clamp(10, 0, 10), 10)
        checkErr("mathx.clamp min>max", function() mathx.clamp(5, 10, 0) end, "mathx.clamp: min > max")
        checkErr("mathx.clamp NaN", function() mathx.clamp(0 / 0, 0, 1) end, "mathx.clamp: x must be a number")
        checkErr("mathx.clamp str", function() mathx.clamp("x", 0, 1) end, "mathx.clamp: x must be a number")

        check("mathx.lerp mid", mathx.lerp(0, 10, 0.5), 5)
        check("mathx.lerp t0", mathx.lerp(2, 8, 0), 2)
        check("mathx.lerp t1", mathx.lerp(2, 8, 1), 8)
        check("mathx.lerp extrapol", mathx.lerp(0, 10, 2), 20)
        checkErr("mathx.lerp bad", function() mathx.lerp(0, 1, 0 / 0) end, "mathx.lerp: t must be a number")

        check("mathx.invLerp mid", mathx.inverseLerp(0, 10, 5), 0.5)
        check("mathx.invLerp ends", mathx.inverseLerp(2, 4, 2), 0)
        checkErr("mathx.invLerp a==b", function() mathx.inverseLerp(3, 3, 3) end,
            "mathx.inverseLerp: a and b must differ")

        check("mathx.remap", mathx.remap(5, 0, 10, 0, 100), 50)
        check("mathx.remap neg", mathx.remap(0, -1, 1, 10, 20), 15)
        checkErr("mathx.remap flat", function() mathx.remap(1, 2, 2, 0, 1) end,
            "mathx.remap: inMin and inMax must differ")

        check("mathx.round int", mathx.round(2.5), 3)
        check("mathx.round down", mathx.round(2.4), 2)
        check("mathx.round neg", mathx.round(-2.5), -2)
        check("mathx.round dec", mathx.round(1.235, 2), 1.24)
        check("mathx.round dec0", mathx.round(1.5, 0), 2)
        checkErr("mathx.round bad dec", function() mathx.round(1, -1) end,
            "mathx.round: decimals must be a non-negative integer")
        checkErr("mathx.round frac dec", function() mathx.round(1, 1.5) end,
            "mathx.round: decimals must be a non-negative integer")

        check("mathx.floor", mathx.floor(2.9), 2)
        check("mathx.floor neg", mathx.floor(-2.1), -3)
        check("mathx.ceil", mathx.ceil(2.1), 3)
        check("mathx.ceil neg", mathx.ceil(-2.9), -2)
        checkErr("mathx.floor NaN", function() mathx.floor(0 / 0) end, "mathx.floor: x must be a number")

        check("mathx.sign pos", mathx.sign(5), 1)
        check("mathx.sign neg", mathx.sign(-0.1), -1)
        check("mathx.sign zero", mathx.sign(0), 0)
        check("mathx.abs", mathx.abs(-3), 3)
        check("mathx.abs pos", mathx.abs(3), 3)

        check("mathx.approach up", mathx.approach(0, 10, 3), 3)
        check("mathx.approach snap up", mathx.approach(8, 10, 5), 10)
        check("mathx.approach snap down", mathx.approach(12, 10, 5), 10)
        check("mathx.approach exact", mathx.approach(10, 10, 5), 10)
        check("mathx.approach zero", mathx.approach(0, 10, 0), 0)
        checkErr("mathx.approach neg", function() mathx.approach(0, 1, -1) end,
            "mathx.approach: delta must be non-negative")
        check("mathx.moveTowards alias", mathx.moveTowards(8, 10, 5), 10)
        check("mathx.moveTowards up", mathx.moveTowards(0, 10, 3), 3)

        check("mathx.smooth lo", mathx.smoothstep(0, 10, -5), 0)
        check("mathx.smooth hi", mathx.smoothstep(0, 10, 15), 1)
        check("mathx.smooth mid", mathx.smoothstep(0, 10, 5), 0.5)
        approx("mathx.smooth q", mathx.smoothstep(0, 1, 0.25), 0.15625)
        checkErr("mathx.smooth flat", function() mathx.smoothstep(1, 1, 0.5) end,
            "mathx.smoothstep: edge0 must be < edge1")
        checkErr("mathx.smooth rev", function() mathx.smoothstep(2, 1, 0.5) end,
            "mathx.smoothstep: edge0 must be < edge1")
        check("mathx.smoother lo", mathx.smootherstep(0, 1, -1), 0)
        check("mathx.smoother hi", mathx.smootherstep(0, 1, 2), 1)
        check("mathx.smoother mid", mathx.smootherstep(0, 1, 0.5), 0.5)
        checkErr("mathx.smoother flat", function() mathx.smootherstep(5, 5, 5) end,
            "mathx.smootherstep: edge0 must be < edge1")

        check("mathx.ping 0", mathx.pingPong(0, 2), 0)
        check("mathx.ping peak", mathx.pingPong(2, 2), 2)
        check("mathx.ping back", mathx.pingPong(3, 2), 1)
        check("mathx.ping period", mathx.pingPong(4, 2), 0)
        check("mathx.ping neg", mathx.pingPong(-1, 2), 1)
        checkErr("mathx.ping zero", function() mathx.pingPong(1, 0) end,
            "mathx.pingPong: length must be positive")
        checkErr("mathx.ping neg len", function() mathx.pingPong(1, -2) end,
            "mathx.pingPong: length must be positive")

        check("mathx.wrap in", mathx.wrap(1, 0, 3), 1)
        check("mathx.wrap over", mathx.wrap(5, 0, 3), 2)
        check("mathx.wrap neg", mathx.wrap(-1, 0, 3), 2)
        check("mathx.wrap hi edge", mathx.wrap(3, 0, 3), 0)
        check("mathx.wrap big neg", mathx.wrap(-7, 0, 3), 2)
        checkErr("mathx.wrap flat", function() mathx.wrap(1, 2, 2) end, "mathx.wrap: min must be < max")
        checkErr("mathx.wrap rev", function() mathx.wrap(1, 5, 2) end, "mathx.wrap: min must be < max")

        approx("mathx.deg2rad", mathx.degToRad(180), math.pi)
        check("mathx.deg2rad 0", mathx.degToRad(0), 0)
        approx("mathx.rad2deg", mathx.radToDeg(math.pi), 180)

        check("mathx.norm 0", mathx.normalizeAngle(0), 0)
        approx("mathx.norm 2pi", mathx.normalizeAngle(math.pi * 2), 0)
        approx("mathx.norm 3pi", mathx.normalizeAngle(math.pi * 3), -math.pi)
        local na = mathx.normalizeAngle(100)
        checkTrue("mathx.norm range", na >= -math.pi and na <= math.pi)
        check("mathx.adiff 0", mathx.angleDiff(0, 0), 0)
        approx("mathx.adiff fwd", mathx.angleDiff(0, 0.5), 0.5)
        approx("mathx.adiff back", mathx.angleDiff(0.5, 0), -0.5)
        approx("mathx.adiff pi", math.abs(mathx.angleDiff(0, math.pi)), math.pi)
        local ad = mathx.angleDiff(1, -1)
        checkTrue("mathx.adiff range", ad >= -math.pi and ad <= math.pi)

        checkTrue("mathx.near default", mathx.isNearlyEqual(1.0, 1.0 + 5e-7))
        checkFalse("mathx.near default far", mathx.isNearlyEqual(1.0, 1.001))
        checkTrue("mathx.near custom", mathx.isNearlyEqual(1.0, 1.05, 0.1))
        checkFalse("mathx.near custom far", mathx.isNearlyEqual(1.0, 1.5, 0.1))
        checkErr("mathx.near neg eps", function() mathx.isNearlyEqual(1, 1, -1) end,
            "mathx.isNearlyEqual: epsilon must be a non-negative number")
    end

    -- ===== vec =====
    do
        local a = vec.v2(1, 2)
        check("vec.v2 x", a.x, 1)
        check("vec.v2 y", a.y, 2)
        local b3 = vec.v3(1, 2, 3)
        check("vec.v3 z", b3.z, 3)
        check("vec.new v2", vec.new(1, 2).y, 2)
        check("vec.new v3", vec.new(1, 2, 3).z, 3)
        checkErr("vec.v2 NaN", function() vec.v2(0 / 0, 1) end, "vec.v2: x must be a number")

        checkTrue("vec.valid v2", vec.isValid(vec.v2(1, 2)))
        checkTrue("vec.valid v3", vec.isValid(vec.v3(1, 2, 3)))
        checkFalse("vec.invalid str", vec.isValid("nope"))
        checkFalse("vec.invalid nan", vec.isValid({ x = 0 / 0, y = 1 }))
        checkFalse("vec.invalid missing", vec.isValid({ x = 1 }))
        checkTrue("vec.valid dim2", vec.isValid(vec.v2(1, 2), 2))
        checkFalse("vec.valid dim2 on v3", vec.isValid(vec.v3(1, 2, 3), 2))
        checkTrue("vec.valid dim3", vec.isValid(vec.v3(1, 2, 3), 3))
        checkErr("vec.valid baddim", function() vec.isValid(vec.v2(1, 2), 4) end,
            "vec.isValid: dim must be 2, 3 or nil")

        local s = vec.add(vec.v2(1, 2), vec.v2(3, 4))
        check("vec.add x", s.x, 4)
        check("vec.add y", s.y, 6)
        local s3 = vec.add(vec.v3(1, 2, 3), vec.v3(4, 5, 6))
        check("vec.add3 z", s3.z, 9)
        checkErr("vec.add mix", function() vec.add(vec.v2(1, 2), vec.v3(1, 2, 3)) end,
            "vec.add: vectors must have same dimension")
        local d = vec.sub(vec.v2(5, 5), vec.v2(2, 1))
        check("vec.sub x", d.x, 3)
        check("vec.sub y", d.y, 4)
        local m = vec.mul(vec.v2(2, 3), 4)
        check("vec.mul x", m.x, 8)
        local dv = vec.div(vec.v2(4, 6), 2)
        check("vec.div x", dv.x, 2)
        check("vec.div y", dv.y, 3)
        checkErr("vec.div zero", function() vec.div(vec.v2(1, 2), 0) end,
            "vec.div: division by zero")
        local n = vec.neg(vec.v2(1, -2))
        check("vec.neg x", n.x, -1)
        check("vec.neg y", n.y, 2)
        -- входы не мутируются, результаты — новые таблицы
        local orig = vec.v2(1, 2)
        local r = vec.add(orig, vec.v2(1, 1))
        check("vec.no mutate add", orig.x, 1)
        checkTrue("vec.new table", r ~= orig)
        local c = vec.clone(orig)
        check("vec.clone x", c.x, 1)
        checkTrue("vec.clone new", c ~= orig)

        check("vec.len 3-4", vec.length(vec.v2(3, 4)), 5)
        check("vec.len0", vec.length(vec.v2(0, 0)), 0)
        check("vec.lenSq", vec.lengthSquared(vec.v2(3, 4)), 25)
        approx("vec.len3", vec.length(vec.v3(1, 2, 2)), 3)
        local un = vec.normalize(vec.v2(3, 4))
        approx("vec.norm x", un.x, 0.6)
        approx("vec.norm y", un.y, 0.8)
        local z = vec.normalize(vec.v2(0, 0))
        check("vec.norm zero x", z.x, 0)
        check("vec.norm zero y", z.y, 0)
        checkTrue("vec.norm zero no NaN", z.x == z.x and z.y == z.y)
        local z3 = vec.normalize(vec.v3(0, 0, 0))
        check("vec.norm3 zero", z3.x + z3.y + z3.z, 0)

        check("vec.dist", vec.distance(vec.v2(0, 0), vec.v2(3, 4)), 5)
        check("vec.distSq", vec.distanceSquared(vec.v2(0, 0), vec.v2(3, 4)), 25)
        checkErr("vec.dist mix", function() vec.distance(vec.v2(0, 0), vec.v3(0, 0, 0)) end,
            "vec.distance: vectors must have same dimension")

        check("vec.dot", vec.dot(vec.v2(1, 2), vec.v2(3, 4)), 11)
        check("vec.dot3", vec.dot(vec.v3(1, 0, 0), vec.v3(0, 1, 0)), 0)
        check("vec.cross2", vec.cross(vec.v2(1, 0), vec.v2(0, 1)), 1)
        check("vec.cross2 neg", vec.cross(vec.v2(0, 1), vec.v2(1, 0)), -1)
        local cr = vec.cross(vec.v3(1, 0, 0), vec.v3(0, 1, 0))
        check("vec.cross3 x", cr.x, 0)
        check("vec.cross3 y", cr.y, 0)
        check("vec.cross3 z", cr.z, 1)

        local lp = vec.lerp(vec.v2(0, 0), vec.v2(10, 10), 0.5)
        check("vec.lerp x", lp.x, 5)
        check("vec.lerp y", lp.y, 5)
        local rt = vec.rotate2(vec.v2(1, 0), math.pi / 2)
        approx("vec.rot x", rt.x, 0)
        approx("vec.rot y", rt.y, 1)
        checkErr("vec.rot v3", function() vec.rotate2(vec.v3(1, 0, 0), 1) end,
            "vec.rotate2: expected v2")
        local fa = vec.fromAngle(0)
        approx("vec.fromAngle x", fa.x, 1)
        approx("vec.fromAngle y", fa.y, 0)
        approx("vec.toAngle", vec.toAngle(vec.v2(0, 1)), math.pi / 2)
        check("vec.toAngle 0", vec.toAngle(vec.v2(1, 0)), 0)
        checkErr("vec.toAngle v3", function() vec.toAngle(vec.v3(1, 0, 0)) end,
            "vec.toAngle: expected v2")

        local rv = vec.round(vec.v2(1.25, 1.35), 1)
        approx("vec.round x", rv.x, 1.3)
        approx("vec.round y", rv.y, 1.4)
        local fv = vec.floor(vec.v2(1.9, -1.1))
        check("vec.floor x", fv.x, 1)
        check("vec.floor y", fv.y, -2)
        local tt = vec.toTable(vec.v3(1, 2, 3))
        check("vec.toTable z", tt.z, 3)
        tt.x = 99
        check("vec.toTable copy", vec.v3(1, 2, 3).x, 1)
    end

    -- ===== tablex =====
    do
        checkTrue("tablex.contains", tablex.contains({ 1, 2, 3 }, 2))
        checkFalse("tablex.contains no", tablex.contains({ 1, 2, 3 }, 9))
        check("tablex.indexOf", tablex.indexOf({ "a", "b", "c" }, "b"), 2)
        check("tablex.indexOf nil", tablex.indexOf({ 1, 2 }, 5), nil)
        checkErr("tablex.contains bad", function() tablex.contains("x", 1) end,
            "tablex.contains: t must be a table")

        local fv, fi = tablex.find({ 5, 6, 7 }, function(v) return v > 5 end)
        check("tablex.find v", fv, 6)
        check("tablex.find i", fi, 2)
        check("tablex.find none", tablex.find({ 1 }, function(v) return v > 9 end), nil)

        local src = { 1, 2, 3 }
        local mp = tablex.map(src, function(v, i) return v * 2 + i end)
        check("tablex.map 1", mp[1], 3)
        check("tablex.map 3", mp[3], 9)
        check("tablex.map no mutate", src[1], 1)
        checkTrue("tablex.map new", mp ~= src)
        local fl = tablex.filter({ 1, 2, 3, 4 }, function(v) return v % 2 == 0 end)
        check("tablex.filter n", #fl, 2)
        check("tablex.filter v", fl[1] .. "," .. fl[2], "2,4")

        check("tablex.reduce sum", tablex.reduce({ 1, 2, 3 }, function(a, v) return a + v end, 0), 6)
        check("tablex.reduce str", tablex.reduce({ "a", "b" }, function(a, v) return a .. v end, ""), "ab")
        checkErr("tablex.reduce no init", function()
            tablex.reduce({ 1 }, function(a, v) return a + v end)
        end, "tablex.reduce: initial is required")

        local kk = tablex.keys({ x = 1, y = 2 })
        table.sort(kk)
        check("tablex.keys", table.concat(kk, ","), "x,y")
        check("tablex.keys empty", #tablex.keys({}), 0)
        local vv = tablex.values({ x = 1, y = 2 })
        table.sort(vv)
        check("tablex.values", table.concat(vv, ","), "1,2")

        check("tablex.count all", tablex.count({ 1, 2, 3 }), 3)
        check("tablex.count dict", tablex.count({ a = 1, b = 2 }), 2)
        check("tablex.count pred", tablex.count({ 1, 2, 3, 4 }, function(v) return v % 2 == 0 end), 2)
        checkTrue("tablex.isEmpty", tablex.isEmpty({}))
        checkFalse("tablex.isEmpty no", tablex.isEmpty({ 1 }))

        check("tablex.first", tablex.first({ 7, 8 }), 7)
        check("tablex.first empty", tablex.first({}), nil)
        check("tablex.last", tablex.last({ 7, 8 }), 8)
        check("tablex.last empty", tablex.last({}), nil)

        local nest = { sub = { n = 1 } }
        local cp = tablex.copy(nest)
        checkTrue("tablex.copy shallow shared", cp.sub == nest.sub)
        cp.top = 1
        check("tablex.copy no mutate", nest.top, nil)
        local dc = tablex.deepcopy(nest)
        checkTrue("tablex.deepcopy split", dc.sub ~= nest.sub)
        check("tablex.deepcopy val", dc.sub.n, 1)
        dc.sub.n = 99
        check("tablex.deepcopy no alias", nest.sub.n, 1)
        check("tablex.deepcopy scalar", tablex.deepcopy(5), 5)
        local cyc = {}
        cyc.self = cyc
        checkErr("tablex.deepcopy cycle", function() tablex.deepcopy(cyc) end,
            "tablex.deepcopy: cycle detected")
        local deep = { a = { b = { c = 1 } } }
        checkErr("tablex.deepcopy depth", function() tablex.deepcopy(deep, 1) end,
            "tablex.deepcopy: max depth exceeded")
        check("tablex.deepcopy depth ok", tablex.deepcopy({ a = 1 }, 1).a, 1)

        local ma = tablex.merge({ x = 1, y = 1 }, { y = 2, z = 3 })
        check("tablex.merge a", ma.x, 1)
        check("tablex.merge b wins", ma.y, 2)
        check("tablex.merge new key", ma.z, 3)
        local msrc = { x = 1 }
        tablex.merge(msrc, { x = 2 })
        check("tablex.merge no mutate", msrc.x, 1)

        local md = tablex.mergeDeep({ a = { x = 1, y = 1 }, k = 1 }, { a = { y = 2, z = 3 } })
        check("tablex.mergeDeep keep", md.a.x, 1)
        check("tablex.mergeDeep win", md.a.y, 2)
        check("tablex.mergeDeep add", md.a.z, 3)
        check("tablex.mergeDeep top", md.k, 1)

        local rsrc = { 1, 2, 3 }
        local rv = tablex.reverse(rsrc)
        check("tablex.reverse", table.concat(rv, ","), "3,2,1")
        check("tablex.reverse no mutate", table.concat(rsrc, ","), "1,2,3")
        check("tablex.reverse empty", #tablex.reverse({}), 0)

        -- shuffle с фиксированным random детерминирован
        local function fixedseq()
            local vals = { 0.1, 0.9, 0.3, 0.7, 0.5 }
            local i = 0
            return function()
                i = i + 1
                return vals[((i - 1) % #vals) + 1]
            end
        end
        local sh1 = tablex.shuffle({ 1, 2, 3, 4, 5 }, fixedseq())
        local sh2 = tablex.shuffle({ 1, 2, 3, 4, 5 }, fixedseq())
        check("tablex.shuffle determ", table.concat(sh1, ","), table.concat(sh2, ","))
        local srt = { sh1[1], sh1[2], sh1[3], sh1[4], sh1[5] }
        table.sort(srt)
        check("tablex.shuffle perm", table.concat(srt, ","), "1,2,3,4,5")
        local shsrc = { 1, 2, 3 }
        local shout = tablex.shuffle(shsrc, fixedseq())
        check("tablex.shuffle no mutate", table.concat(shsrc, ","), "1,2,3")
        checkTrue("tablex.shuffle new", shout ~= shsrc)
        checkErr("tablex.shuffle bad rnd", function()
            tablex.shuffle({ 1, 2 }, function() return 1.5 end)
        end, "tablex.shuffle: random must return [0,1)")
        checkErr("tablex.shuffle not fn", function()
            tablex.shuffle({ 1, 2 }, 42)
        end, "tablex.shuffle: random must be a function")
        local dsh = tablex.shuffle({ 1, 2, 3, 4, 5 }) -- default math.random: smoke
        check("tablex.shuffle default len", #dsh, 5)

        local cl = { a = 1 }
        local clr = tablex.clear(cl)
        checkTrue("tablex.clear empty", next(cl) == nil)
        checkTrue("tablex.clear same", clr == cl)
    end

    -- ===== stringx (включая кириллицу) =====
    do
        check("stringx.trim", stringx.trim("  hi\t\n"), "hi")
        check("stringx.trim empty", stringx.trim("   "), "")
        check("stringx.trim none", stringx.trim("x"), "x")
        checkErr("stringx.trim bad", function() stringx.trim(1) end,
            "stringx.trim: s must be a string")

        local sp1 = stringx.split("a,b,c", ",")
        check("stringx.split n", #sp1, 3)
        check("stringx.split v", table.concat(sp1, "|"), "a|b|c")
        local sp2 = stringx.split(";a;;b;", ";")
        check("stringx.split drop", table.concat(sp2, "|"), "a|b")
        local sp3 = stringx.split(";a;;b;", ";", true)
        check("stringx.split keep", #sp3, 5)
        check("stringx.split keep v", sp3[1] .. "," .. sp3[3] .. "," .. sp3[5], ",,")
        local sp4 = stringx.split("", ",", true)
        check("stringx.split empty keep", #sp4, 1)
        check("stringx.split empty drop", #stringx.split("", ","), 0)
        -- sep — ОБЫЧНАЯ строка, не pattern
        local sp5 = stringx.split("a.b*c", ".")
        check("stringx.split plain", table.concat(sp5, "|"), "a|b*c")
        checkErr("stringx.split empty sep", function() stringx.split("a", "") end,
            "stringx.split: sep must be a non-empty string")

        check("stringx.join", stringx.join({ "a", "b" }, "-"), "a-b")
        check("stringx.join default", stringx.join({ "a", "b" }), "ab")
        check("stringx.join nums", stringx.join({ 1, 2 }, ","), "1,2")
        checkErr("stringx.join bad elem", function() stringx.join({ {} }, ",") end,
            "stringx.join: parts[1] must be a string or number")

        checkTrue("stringx.starts", stringx.startsWith("hello", "he"))
        checkFalse("stringx.starts no", stringx.startsWith("hello", "lo"))
        checkTrue("stringx.starts empty", stringx.startsWith("hello", ""))
        checkTrue("stringx.ends", stringx.endsWith("hello", "lo"))
        checkFalse("stringx.ends no", stringx.endsWith("hello", "he"))
        checkTrue("stringx.ends empty", stringx.endsWith("hello", ""))
        checkTrue("stringx.contains", stringx.contains("hello", "ll"))
        checkFalse("stringx.contains no", stringx.contains("hello", "xx"))
        -- contains — plain, не pattern
        checkTrue("stringx.contains dot", stringx.contains("a.b", "."))
        checkFalse("stringx.contains plain", stringx.contains("axb", "a.b"))

        check("stringx.replace", stringx.replaceAll("aaa", "a", "b"), "bbb")
        check("stringx.replace multi", stringx.replaceAll("a,b,a", "a", "zz"), "zz,b,zz")
        check("stringx.replace dot", stringx.replaceAll("a.b.c", ".", "-"), "a-b-c")
        check("stringx.replace cyr", stringx.replaceAll("привет привет", "привет", "пока"), "пока пока")
        checkErr("stringx.replace empty", function() stringx.replaceAll("a", "", "b") end,
            "stringx.replaceAll: old must be a non-empty string")

        -- capitalize/lower/upper: только ASCII, кириллицу не меняют
        check("stringx.cap ascii", stringx.capitalize("hello"), "Hello")
        check("stringx.cap cyr", stringx.capitalize("привет"), "привет")
        check("stringx.cap empty", stringx.capitalize(""), "")
        check("stringx.lower ascii", stringx.lower("HeLLo"), "hello")
        check("stringx.lower cyr", stringx.lower("ПРИВЕТ"), "ПРИВЕТ")
        check("stringx.upper ascii", stringx.upper("HeLLo"), "HELLO")
        check("stringx.upper cyr", stringx.upper("привет"), "привет")

        -- utf8
        check("stringx.u8 ascii", stringx.utf8Length("hello"), 5)
        check("stringx.u8 cyr", stringx.utf8Length("привет"), 6)
        check("stringx.u8 mixed", stringx.utf8Length("hi-привет"), 9)
        check("stringx.u8 empty", stringx.utf8Length(""), 0)

        check("stringx.trunc short", stringx.truncateUtf8("привет", 10), "привет")
        check("stringx.trunc exact", stringx.truncateUtf8("привет", 6), "привет")
        check("stringx.trunc cyr", stringx.truncateUtf8("привет, мир", 6, "..."), "привет...")
        -- последовательность не режется: длина результата ровно 6 + суффикс
        local tr = stringx.truncateUtf8("привет, мир", 6, "…")
        check("stringx.trunc seq", stringx.utf8Length(tr), 7)
        check("stringx.trunc zero", stringx.truncateUtf8("привет", 0, "..."), "...")
        check("stringx.trunc nosuffix", stringx.truncateUtf8("приветмир", 6), "привет")
        checkErr("stringx.trunc bad", function() stringx.truncateUtf8("a", -1) end,
            "stringx.truncateUtf8: maxChars must be a non-negative integer")

        check("stringx.padL", stringx.padLeft("42", 5), "   42")
        check("stringx.padR", stringx.padRight("42", 5), "42   ")
        check("stringx.padL cyr", stringx.padLeft("привет", 8), "  привет")
        check("stringx.padR cyr", stringx.padRight("привет", 8, "-"), "привет--")
        check("stringx.pad wide", stringx.padLeft("abcdef", 3), "abcdef")
        checkErr("stringx.pad bad", function() stringx.padLeft("a", 3, "xx") end,
            "stringx.padLeft: pad must be a single character")

        check("stringx.bytes B", stringx.formatBytes(0), "0 B")
        check("stringx.bytes 1023", stringx.formatBytes(1023), "1023 B")
        check("stringx.bytes KB", stringx.formatBytes(1024), "1.0 KB")
        check("stringx.bytes KB15", stringx.formatBytes(1536), "1.5 KB")
        check("stringx.bytes MB", stringx.formatBytes(1048576), "1.0 MB")
        check("stringx.bytes GB", stringx.formatBytes(1073741824), "1.0 GB")
        checkErr("stringx.bytes neg", function() stringx.formatBytes(-1) end,
            "stringx.formatBytes: bytes must be non-negative")

        local esc = stringx.escapePattern("a.b*c?")
        checkTrue("stringx.escape", ("axbxxc?"):find(esc) == nil)
        checkTrue("stringx.escape match", ("a.b*c?"):find(esc) ~= nil)
        check("stringx.escape exact", stringx.escapePattern("a.c"), "a%.c")
    end

    return passed, failed
end
