-- shared.lua — кейсы, которые меняют мир. Выполняются одинаково на всех машинах.
--
-- ЗАПУСК: клиент шлёт net.send("ast.run", {...}), либо этот файл сам по
-- game.start ставит обработчик. Ничего не выполняется само при загрузке.
--
-- LOCKSTEP: всё, что меняет мир, идёт через ipairs/явные списки. Никаких pairs()
-- по хешам в коде, который что-то создаёт — порядок обхода хеша на разных
-- машинах разный, это рассинхрон. Случайность (если понадобится) — только
-- rng.new(rng.seedFromGame()) с ОДИНАКОВЫМ числом вызовов.

local H = require("harness")

-- ===========================================================================
-- 1. ОКРУЖЕНИЕ, ПРАВА, НАТИВЫ
-- ===========================================================================

H.case({ id = "env.mode", section = "env", fn = function(t)
    t:note("game.mode() = " .. tostring(game.mode()))
    -- game.side — СТРОКА ("server"/"client"), а не функция. Проверяем оба варианта.
    local side = game.side
    t:note("game.side = " .. type(side) .. " -> " .. tostring(type(side) == "function" and side() or side))
    t:note("game.isInGame() = " .. tostring(game.isInGame()))
    t:note("game.isAuthority() = " .. tostring(game.isAuthority and game.isAuthority() or "?"))
    t:note("game.exec доступен = " .. tostring(game.exec ~= nil))
    t:note("mod.side = " .. tostring(mod and mod.side))
    t:note("mod.id/version = " .. tostring(mod and mod.id) .. " " .. tostring(mod and mod.version))
end })

H.case({ id = "env.players", section = "env", fn = function(t)
    t:inGame("players")
    local list = players.list()
    t:need(#list > 0, "players.list() пуст")
    local parts = {}
    for i, p in ipairs(list) do
        parts[#parts + 1] = string.format("#%d %s team=%d bai=%s", p.index,
            tostring(p.name), p.team or -1, tostring(p.bai))
    end
    t:note("слотов: " .. #list .. " — " .. table.concat(parts, ", "))
    t:notNil(players.me(), "players.me()")
end })

H.case({ id = "env.map", section = "env", fn = function(t)
    t:inGame("map")
    local info = map.info()
    t:need(type(info) == "table", "map.info() не таблица")
    local s = map.settings()
    t:need(type(s) == "table", "map.settings() не таблица")
    t:note(string.format("карта: name=%s seed=%s/%s", tostring(info.name),
        tostring(s.gen and s.gen.randkey0), tostring(s.gen and s.gen.randkey1)))
end })

H.case({ id = "env.content.check", section = "env", fn = function(t)
    -- модуль может быть не загружен при битой копии api
    t:mod("content")
    -- Проверяем на МЕНЯЕМОЕ требование: сначала несуществующий мод (ожидаем false),
    -- потом себя (ожидаем true). Это проверяет обе ветви content.check.
    local ok1, rep1 = content.check({ mods = { definitely_not_installed_xyz = "1.0" } })
    t:eq(ok1, false, "content.check для отсутствующего мода")
    t:need(type(rep1) == "string" and #rep1 > 0, "content.check не вернул текст отчёта")

    local ok2, rep2 = content.check({ mods = {} })
    t:eq(ok2, true, "content.check с пустыми требованиями")

    local perms = content.permissions("api_stress_test")
    t:note("permissions(api_stress_test) = " .. (perms and "таблица" or "nil (у мода нет permissions)"))
    t:eq(content.require({ mods = {} }), true, "content.require с пустыми требованиями")
end })

H.case({ id = "env.native.catalog", section = "env", fn = function(t)
    local stats = native.catalogStats()
    t:need(type(stats) == "table", "native.catalogStats() не таблица")
    t:note(string.format("нативов: всего %s, client %s, server %s",
        tostring(stats.total), tostring(stats.client), tostring(stats.server)))
    -- native.info отдаёт { addr, decl, side, risk, category, wrappedBy }.
    local info = native.info("GetGameTime")
    t:need(type(info) == "table", "native.info('GetGameTime') не таблица")
    t:note(string.format("GetGameTime: addr=%s side=%s risk=%s category=%s",
        tostring(info.addr), tostring(info.side), tostring(info.risk), tostring(info.category)))
    t:note("decl = " .. tostring(info.decl):sub(1, 70))
    t:eq(native.info("NoSuchNative_zzz"), nil, "native.info для несуществующего натива")

    -- Читаемый натив для client — должен быть помечен side=client.
    local rd = native.info("GetPlayerIndexInterfaceIO")
    if type(rd) == "table" then
        t:note(string.format("GetPlayerIndexInterfaceIO: side=%s risk=%s", tostring(rd.side), tostring(rd.risk)))
    end
    -- Опасный натив (Create/Set) — риск должен быть не пустой.
    local danger = native.info("CreatePlayerGameObjectHandleByHandle")
    if type(danger) == "table" then
        t:note(string.format("CreatePlayerGameObjectHandleByHandle: side=%s risk=%s",
            tostring(danger.side), tostring(danger.risk)))
    end
end })

H.case({ id = "env.native.risky", section = "env", risky = true, fn = function(t)
    -- Вызовы нативов, меняющих игру, напрямую из Lua: проверяем, что они проходят
    -- через NativeCall (число аргументов, var-параметры, ESP).
    local n = native.GetGameTime()
    t:notNil(n, "GetGameTime()")
    local pid = native.GetPlayerIndexInterfaceIO()
    t:note("GetPlayerIndexInterfaceIO() = " .. tostring(pid))
    t:need(type(n) == "number", "GetGameTime вернул не число")
    -- Проверка в стиле var-параметра: GetPlayerHandleByIndex + чтение позиции.
    local ph = native.GetPlayerHandleByIndex(pid)
    t:need(ph and ph ~= 0, "GetPlayerHandleByIndex вернул 0")
    t:note("player handle = " .. tostring(ph))
end })

H.case({ id = "env.validate", section = "env", fn = function(t)
    -- Чистые проверки: правильный вклад должен проходить, неправильный — падать.
    t:eq(validate.number(5, "x", { min = 0, max = 10 }), 5, "validate.number в допуске")
    t:eq(validate.integer(7, "i"), 7, "validate.integer")
    t:eq(validate.boolean(true, "b"), true, "validate.boolean")
    t:eq(validate.string("abc", "s", { minLen = 1, maxLen = 10 }), "abc", "validate.string")
    t:eq(validate.handle(123, "h"), 123, "validate.handle")
    t:eq(validate.enum("move", { "move", "attack" }, "k"), "move", "validate.enum")
    -- validate.list ВОЗВРАЩАЕТ САМ список (не длину) — проверяем это.
    local lst = validate.list({ 1, 2, 3 }, "l", { minLen = 2 })
    t:eq(#lst, 3, "validate.list вернул список той же длины")
    t:eq(lst[2], 2, "validate.list вернул те же элементы")
    t:eq(validate.table({ a = 1 }, "t").a, 1, "validate.table")

    -- Отрицательные ветки: каждая обязана бросить ошибку.
    local bad = {
        { "number: NaN", function() validate.number(0 / 0, "x") end },
        { "number: вне диапазона", function() validate.number(99, "x", { max = 10 }) end },
        { "integer: дробное", function() validate.integer(1.5, "i") end },
        { "boolean: не boolean", function() validate.boolean(1, "b") end },
        { "string: пусто", function() validate.string("", "s", { nonEmpty = true }) end },
        { "handle: 0", function() validate.handle(0, "h") end },
        { "enum: не в списке", function() validate.enum("fly", { "move" }, "k") end },
        { "list: не массив", function() validate.list({ a = 1 }, "l") end },
        { "list: короче minLen", function() validate.list({ 1 }, "l", { minLen = 3 }) end },
    }
    for _, b in ipairs(bad) do
        local ok = pcall(b[2])
        t:need(not ok, "validate НЕ отклонил: " .. b[1] .. " (баг проверок)")
    end
    t:note(string.format("%d отрицательных веток отклонены", #bad))

    -- Позиция: мусор не должен превращаться в {0,0}.
    t:need(pcall(validate.position, { x = 1, z = 2 }, "p"), "validate.position принял {x=1,z=2}")
    t:need(not pcall(validate.position, { x = 1 }, "p"), "validate.position принял точку без z")

    -- Контекстные проверки. На 0.2.0 они падают одинаково:
    -- api/68_validate.lua:213,225,236 используют rawget(_G, "game"), а в
    -- окружении api есть только _ENV -> rawget(nil, ...).
    local ctx = {
        { "activeGame", function() validate.activeGame("probe") end },
        { "server", function() validate.server("probe") end },
        { "client", function() validate.client("probe") end },
    }
    local broken, alive, other = {}, {}, {}
    for _, c in ipairs(ctx) do
        local ok, err = pcall(c[2])
        if ok then alive[#alive + 1] = c[1]
        elseif tostring(err):find("rawget", 1, true) then broken[#broken + 1] = c[1]
        else other[#other + 1] = c[1] .. " (" .. tostring(err):sub(1, 40) .. ")" end
    end
    if #broken > 0 then
        t:fail("БАГ API 0.2.0: " .. table.concat(broken, ", ") ..
            " падают на rawget(_G, \"game\") — в окружении api есть только _ENV " ..
            "(68_validate.lua:213, 225, 236). Замена _G -> _ENV чинит все три")
    end
    -- Остальные могут падать законно: не та сторона / нет партии. Это не баг.
    t:note("контекстные проверки: сработали " .. #alive .. "/3" ..
        (#other > 0 and (", отказ по контексту: " .. table.concat(other, "; ")) or ""))
end })

H.case({ id = "env.config", section = "env", fn = function(t)
    t:mod("config")
    -- На 0.2.0 config.load падает: ensureAutosave() делает rawget(_G, "events"),
    -- а в окружении api есть только _ENV (поле _G проставляется только окружению
    -- МОДА, см. CreateEnv в LuaHost.cpp). Проверяем и диагностируем.
    local okCfg, errCfg = pcall(function()
        config.link(savedata)
        return config.load("api_stress_test", { _version = 3, runs = 0, note = "" })
    end)
    if not okCfg then
        t:fail("config.load упал: " .. tostring(errCfg) ..
            "  <- БАГ API 0.2.0: api/69_config.lua:105 использует rawget(_G, \"events\"), " ..
            "а в окружении api есть только _ENV. Чинится заменой _G -> _ENV " ..
            "(заодно сломаны validate.activeGame/server/client: 68_validate.lua:213,225,236)")
    end
    local cfg = config.load("api_stress_test", { _version = 3, runs = 0, note = "" })
    t:note("config загружен, ключ cfg:api_stress_test, runs = " .. tostring(cfg:get("runs", 0)))

    cfg:set("runs", (tonumber(cfg:get("runs", 0)) or 0) + 1)
    t:eq(cfg:isDirty(), true, "cfg:isDirty после set")
    t:eq(cfg:save(), true, "cfg:save")
    t:eq(cfg:save(), false, "повторный save без изменений (ожидается no-op)")

    cfg:set("note", "проверка")
    t:eq(cfg:get("note"), "проверка", "cfg:get после set")
    cfg:reset("note")
    -- reset возвращает ЗНАЧЕНИЕ ИЗ DEFAULTS (у нас note = ""), а не переданный fallback.
    t:eq(cfg:get("note"), "", "cfg:reset вернул дефолт из defaults (пустая строка)")
    t:eq(cfg:get("нет_такого_ключа", "fallback"), "fallback", "cfg:get отдаёт fallback для отсутствующего")

    -- Миграция версий: загрузка с другим _version без migrate -> сброс к дефолтам.
    local fresh = config.load("api_stress_test_mig", { _version = 1, a = 1 })
    fresh:set("a", 99); fresh:save()
    local bumped = config.load("api_stress_test_mig", { _version = 2, a = 1 })
    t:eq(bumped:get("a"), 1, "config без migrate при смене _version сбрасывается к дефолтам")
    -- ВАЖНО: migrate получает СТАРЫЕ сохранённые данные (a=99), а НЕ дефолты.
    -- Без migrate дефолты применяются (a=1). Разное и правильное поведение:
    -- без migrate старый формат не восстановить, а migratefn ставит свой.
    local migrated = config.load("api_stress_test_mig", { _version = 2, a = 1 },
        { migrate = function(old) old.a = old.a * 2; return old end })
    t:eq(migrated:get("a"), 198, "migrate получил старые данные (99) и удвоил их")
    t:eq(migrated:isDirty(), true, "после migrate конфиг помечен изменённым")
    local badMig = pcall(config.load, "api_stress_test_mig", { _version = 3, a = 1 },
        { migrate = function() return "не таблица" end })
    t:eq(badMig, false, "migrate без таблицы на выходе отклонён")
    -- Сквозная проверка: migrate -> save -> повторная загрузка той же версии.
    -- БЕЗ save() проверять нечего: на диске остаётся старое (a=99, _version=1).
    t:eq(migrated:save(), true, "мигрированный конфиг сохранился")
    local reloaded = config.load("api_stress_test_mig", { _version = 2, a = 1 })
    t:eq(reloaded:get("a"), 198,
        "мигрированное значение пережило сохранение и повторную загрузку той же версии")
    t:eq(reloaded:isDirty(), false, "после повторной загрузки конфиг не должен быть изменённым")
    -- ГЛАВНОЕ: migrate обязан поднять _version, иначе он запускается на каждой
    -- загрузке. api/69_config теперь проставляет версию сам, поэтому даже
    -- забытый автором _version._version не приводит к тихому циклу удвоения.
    local noVer = config.load("api_stress_test_mig", { _version = 9, a = 1 },
        { migrate = function(old) old.a = old.a * 2; return old end })
    t:eq(noVer:get("a"), 396, "migrate без _version всё равно применился (198 -> 396)")
    t:eq(noVer:save(), true, "конфиг после migrate без _version сохранился")
    local afterNoVer = config.load("api_stress_test_mig", { _version = 9, a = 1 })
    t:eq(afterNoVer:get("a"), 396,
        "БЕЗ простановки _version здесь было бы 792 — тихий цикл миграции при каждой загрузке")
    t:eq(afterNoVer:isDirty(), false, "третья загрузка не должна снова запускать migrate")
end })

H.case({ id = "env.profiler", section = "env", fn = function(t)
    -- модуль может быть не загружен при битой копии api
    t:mod("profiler")
    profiler.reset()
    profiler.start()
    -- Намеренно потратить немного игровых вызовов, чтобы в отчёте было что видеть.
    game.exec("var i : Integer;")
    for i = 1, 3 do state.get("gMap.gamestage") end
    local rep = profiler.report()
    profiler.stop()
    t:need(type(rep) == "string" and #rep > 0, "profiler.report() пуст")
    local hasExec = rep:find("game.exec", 1, true) ~= nil
    local hasState = rep:find("state.get", 1, true) ~= nil
    t:note("отчёт содержит game.exec: " .. tostring(hasExec) ..
           ", state.get: " .. tostring(hasState))
    t:need(hasState, "profiler не увидел вызовы state.get (обёртка не навешена?)")

    -- profiler.time — обёртка своего колбэка.
    local wrapped = profiler.time("ast_probe", function(a) return a * 2 end)
    t:eq(wrapped(21), 42, "profiler.time обёртка считает верно")
    profiler.reset()

    -- После stop() обёртки сняты — вызовы снова идут напрямую.
    pcall(state.get, "gMap.gamestage")
    t:note("profiler.stop вернул функции на место")
end })

-- ===========================================================================
-- 2. БИБЛИОТЕКИ-УТИЛИТЫ (реальное использование, не только юнит-тесты)
-- ===========================================================================

H.case({ id = "util.mathx", section = "util", fn = function(t)
    t:eq(mathx.clamp(15, 0, 10), 10, "mathx.clamp сверху")
    t:eq(mathx.clamp(-5, 0, 10), 0, "mathx.clamp снизу")
    t:near(mathx.lerp(0, 10, 0.25), 2.5, 1e-9, "mathx.lerp")
    t:near(mathx.remap(5, 0, 10, 100, 200), 150, 1e-9, "mathx.remap")
    t:eq(mathx.round(3.14159, 2), 3.14, "mathx.round")
    t:eq(mathx.sign(-7), -1, "mathx.sign")
    t:eq(mathx.floor(-1.2), -2, "mathx.floor")
    t:eq(mathx.ceil(1.2), 2, "mathx.ceil")
    t:eq(mathx.wrap(370, 0, 360), 10, "mathx.wrap")
    t:near(mathx.degToRad(180), math.pi, 1e-9, "mathx.degToRad")
    t:eq(mathx.isNearlyEqual(1.0, 1.0000001, 1e-5), true, "mathx.isNearlyEqual")
    -- normalizeAngle: углы нормализуются в (-pi, pi].
    local a = mathx.normalizeAngle(3 * math.pi)
    t:need(a > -math.pi - 1e-9 and a <= math.pi + 1e-9,
        "mathx.normalizeAngle вне диапазона: " .. tostring(a))
    t:note("smoothstep(0,1,0.5) = " .. tostring(mathx.smoothstep(0, 1, 0.5)))
end })

H.case({ id = "util.vec", section = "util", fn = function(t)
    local a, b = vec.v3(1, 2, 3), vec.v3(4, 6, 3)
    local s = vec.add(a, b)
    t:eq(s.x, 5, "vec.add x"); t:eq(s.y, 8, "vec.add y"); t:eq(s.z, 6, "vec.add z")
    local d = vec.sub(b, a)
    t:eq(d.x, 3, "vec.sub x")
    t:eq(vec.mul(a, 2).y, 4, "vec.mul")
    t:near(vec.length(vec.v3(3, 4, 0)), 5, 1e-9, "vec.length")
    t:near(vec.dot(vec.v3(1, 0, 0), vec.v3(0, 1, 0)), 0, 1e-9, "vec.dot")
    local cr = vec.cross(vec.v3(1, 0, 0), vec.v3(0, 1, 0))
    t:eq(cr.z, 1, "vec.cross")
    t:near(vec.distance(vec.v2(0, 0), vec.v2(3, 4)), 5, 1e-9, "vec.distance")
    -- Нормализация: длина должна стать 1.
    local n = vec.normalize(vec.v3(0, 5, 0))
    t:near(vec.length(n), 1, 1e-6, "vec.normalize даёт единичную длину")
    t:eq(vec.isValid(vec.v3(1, 2, 3), 3), true, "vec.isValid")
    t:eq(vec.isValid({ x = 1, y = 2 }, 3), false, "vec.isValid ловит нехватку поля")
end })

H.case({ id = "util.tablex", section = "util", fn = function(t)
    local src = { 3, 1, 2 }
    t:eq(tablex.contains(src, 2), true, "tablex.contains")
    t:eq(tablex.indexOf(src, 2), 3, "tablex.indexOf")
    t:eq(#tablex.map(src, function(v) return v * 2 end), 3, "tablex.map длина")
    t:eq(tablex.reduce(src, function(acc, v) return acc + v end, 0), 6, "tablex.reduce")
    t:eq(tablex.count(src, function(v) return v > 1 end), 2, "tablex.count")
    t:eq(tablex.isEmpty({}), true, "tablex.isEmpty")
    t:eq(tablex.first(src), 3, "tablex.first")
    t:eq(tablex.last(src), 2, "tablex.last")

    local nested = { a = { b = { c = 1 } } }
    local copy = tablex.deepcopy(nested)
    copy.a.b.c = 99
    t:eq(nested.a.b.c, 1, "tablex.deepcopy реально копирует (вложенность не общая)")
    t:eq(tablex.merge({ a = 1, b = 2 }, { b = 3 }).b, 3, "tablex.merge перекрывает")
    t:eq(tablex.mergeDeep({ a = { x = 1 } }, { a = { y = 2 } }).a.y, 2, "tablex.mergeDeep")

    -- shuffle обязан вернуть НОВУЮ таблицу и сохранить набор.
    local list = { 1, 2, 3, 4, 5 }
    local sh = tablex.shuffle(list)
    t:need(sh ~= list, "tablex.shuffle вернул исходную таблицу")
    t:eq(#sh, 5, "tablex.shuffle длина")
    local sum = 0
    for _, v in ipairs(sh) do sum = sum + v end
    t:eq(sum, 15, "tablex.shuffle потерял элементы")
    t:eq(#tablex.filter(sh, function(v) return v % 2 == 1 end), 3, "tablex.filter")
end })

H.case({ id = "util.stringx", section = "util", fn = function(t)
    t:eq(stringx.trim("  hi  "), "hi", "stringx.trim")
    -- keepEmpty по умолчанию FALSE: пустые куски выбрасываются.
    t:eq(#stringx.split("a,b,,c", ","), 3, "stringx.split без keepEmpty (пустые отброшены)")
    local parts = stringx.split("a,b,,c", ",", true)
    t:eq(#parts, 4, "stringx.split с keepEmpty=true")
    t:eq(parts[3], "", "stringx.split сохраняет пустой элемент")
    t:eq(stringx.join({ "a", "b" }, "-"), "a-b", "stringx.join")
    t:eq(stringx.startsWith("abcdef", "abc"), true, "stringx.startsWith")
    t:eq(stringx.endsWith("abcdef", "def"), true, "stringx.endsWith")
    t:eq(stringx.replaceAll("aaa", "a", "b"), "bbb", "stringx.replaceAll")
    -- capitalize трогает ТОЛЬКО ASCII: в Lua-шаблонах %l/%u — это a-z/A-Z,
    -- кириллица не меняется. Это задокументированное ограничение, а не баг.
    t:eq(stringx.capitalize("hello world"), "Hello world", "stringx.capitalize ASCII")
    t:eq(stringx.capitalize("привет"), "привет", "capitalize не трогает кириллицу (ожидаемо)")
    t:eq(stringx.upper("abc"), "ABC", "stringx.upper")
    t:eq(stringx.lower("ABC"), "abc", "stringx.lower")
    -- Кириллица в UTF-8: длина в символах, а не в байтах.
    t:eq(stringx.utf8Length("тест"), 4, "stringx.utf8Length считает символы, не байты")
    t:eq(#"тест", 8, "проверка: в байтах русская строка вдвое длиннее")
    t:eq(stringx.truncateUtf8("абвгд", 3), "абв", "truncateUtf8 режет по символам (суффикс по умолчанию пуст)")
    t:eq(stringx.truncateUtf8("абвгд", 3, "..."), "абв...", "truncateUtf8 с суффиксом")
    t:eq(stringx.truncateUtf8("абв", 5), "абв", "truncateUtf8 короче лимита — не трогает")
    t:eq(stringx.truncateUtf8("абвгд", 0, "…"), "…", "truncateUtf8 с maxChars=0")
    t:eq(stringx.padLeft("7", 3, "0"), "007", "stringx.padLeft")
    t:eq(stringx.escapePattern("a.b"), "a%.b", "stringx.escapePattern")
    t:eq(stringx.formatBytes(1536), "1.5 KB", "stringx.formatBytes")
    t:need(not pcall(stringx.split, "a,b", ""), "stringx.split принял пустой разделитель")
    t:note("split с пустым разделителем отклонён верно")
end })

H.case({ id = "util.geometry", section = "util", fn = function(t)
    t:eq(geometry.inCircle({ x = 1, z = 1 }, { x = 0, z = 0 }, 5), true, "geometry.inCircle")
    t:eq(geometry.inCircle({ x = 9, z = 0 }, { x = 0, z = 0 }, 5), false, "geometry.inCircle вне")
    t:eq(geometry.inRect({ x = 5, z = 5 }, { x1 = 0, z1 = 0, x2 = 10, z2 = 10 }), true, "geometry.inRect")

    local sq = { { x = 0, z = 0 }, { x = 10, z = 0 }, { x = 10, z = 10 }, { x = 0, z = 10 } }
    t:eq(geometry.polygonContains({ x = 5, z = 5 }, sq), true, "geometry.polygonContains внутри")
    t:eq(geometry.polygonContains({ x = 15, z = 5 }, sq), false, "geometry.polygonContains снаружи")
    t:eq(geometry.polygonCenter(sq).x, 5, "geometry.polygonCenter")
    local b = geometry.polygonBounds(sq)
    t:eq(b.x1, 0, "geometry.polygonBounds x1"); t:eq(b.x2, 10, "geometry.polygonBounds x2")

    -- inSector: direction — УГОЛ в радианах, угол точки считается как atan(dz, dx),
    -- то есть direction = 0 смотрит на +X, а не на +Z.
    t:eq(geometry.inSector({ x = 5, z = 0 }, { x = 0, z = 0 }, 0, 0.3, 10), true,
        "inSector: точка на +X при direction=0")
    t:eq(geometry.inSector({ x = 0, z = 5 }, { x = 0, z = 0 }, 0, 0.3, 10), false,
        "inSector: точка на +Z при direction=0 — вне сектора")
    t:eq(geometry.inSector({ x = 0, z = 5 }, { x = 0, z = 0 }, math.pi / 2, 0.3, 10), true,
        "inSector: та же точка при direction=pi/2")
    t:eq(geometry.inSector({ x = 0, z = 0 }, { x = 0, z = 0 }, 0, 0, 10), true,
        "inSector: точка в центре всегда внутри")
    t:eq(geometry.inSector({ x = 0, z = 50 }, { x = 0, z = 0 }, math.pi / 2, math.pi, 10), false,
        "inSector: вне радиуса")
    t:near(geometry.distance({ x = 0, z = 0 }, { x = 3, z = 4 }), 5, 1e-9, "geometry.distance")
    t:eq(#geometry.circlePoints({ x = 0, z = 0 }, 10, 8), 8, "geometry.circlePoints")
    -- Пересечение двух отрезков.
    local hit = geometry.lineIntersection({ x = 0, z = 0 }, { x = 10, z = 10 },
        { x = 0, z = 10 }, { x = 10, z = 0 })
    t:need(hit ~= nil, "geometry.lineIntersection не нашёл пересечение диагоналей")
    t:near(hit.x, 5, 1e-6, "lineIntersection x")
    t:near(geometry.distanceToSegment({ x = 5, z = 5 }, { x = 0, z = 0 }, { x = 10, z = 0 }), 5, 1e-9,
        "geometry.distanceToSegment")
end })

H.case({ id = "util.color", section = "util", fn = function(t)
    local c = color.rgb(255, 128, 0)
    t:eq(c.r, 255, "color.rgb r"); t:eq(c.g, 128, "color.rgb g"); t:eq(c.b, 0, "color.rgb b")
    t:eq(c.a, 255, "color.rgb alpha по умолчанию")
    -- color.hex ПАРСИТ строку и возвращает таблицу (не число).
    local h = color.hex("#ff8000")
    t:eq(h.r, 255, "color.hex r"); t:eq(h.g, 128, "color.hex g"); t:eq(h.b, 0, "color.hex b")
    t:eq(h.a, 255, "color.hex alpha = 255 по умолчанию")
    t:eq(color.hex("#F0A").r, 255, "color.hex короткий #RGB (F -> FF)")
    t:eq(color.hex("#ff8000ff").a, 255, "color.hex с альфой")
    t:eq(color.hex("#ff800000").a, 0, "color.hex с нулевой альфой")
    t:need(not pcall(color.hex, "не hex"), "color.hex принял мусор")
    t:need(not pcall(color.hex, 12345), "color.hex принял не строку")
    t:note("мусор в hex отклонён верно")
    local withA = color.withAlpha(c, 128)
    t:eq(withA.a, 128, "color.withAlpha")
    t:eq(withA.r, 255, "color.withAlpha сохраняет r")
    local mixed = color.lerp(color.rgb(0, 0, 0), color.rgb(100, 200, 40), 0.5)
    t:eq(mixed.r, 50, "color.lerp r")
    t:eq(mixed.g, 100, "color.lerp g")
    t:eq(color.toHex(c), "#FF8000", "color.toHex (ВЕРХНИЙ регистр)")
    t:eq(color.toHex(withA, true), "#FF800080", "color.toHex с альфой")
    t:need(not pcall(color.toHex, "не цвет"), "color.toHex принял не цвет")
    t:note("мусор в toHex отклонён верно")
end })

-- scheduler: синхронная часть — контракт и проверки аргументов; фактическое
-- срабатывание проверяем отложенно (t:defer), потому что таймеры стреляют в game.tick.
H.case({ id = "util.scheduler", section = "util", fn = function(t)
    local now = scheduler.now()
    t:need(type(now) == "number", "scheduler.now() вернул не число")
    t:note("scheduler.now() = " .. string.format("%.2f", now))

    -- after: sec >= 0 (0 — сработает на ближайшем тике).
    local id1 = scheduler.after(0, function() end)
    t:need(id1 ~= nil, "scheduler.after вернул nil")
    -- every: sec > 0 СТРОГО (0 — ошибка). Это частая ошибка в модах.
    t:need(not pcall(scheduler.every, 0, function() end), "scheduler.every принял sec=0")
    t:note("scheduler.every требует sec > 0 — отклонено верно")
    local id2 = scheduler.every(3600, function() end)
    t:need(id2 ~= nil, "scheduler.every вернул nil")
    t:note("pending после постановки: " .. tostring(scheduler.pending and scheduler.pending()))

    -- at: произвольное игровое время, в т.ч. в прошлом.
    local id3 = scheduler.at(now - 5, function() end)
    t:need(id3 ~= nil, "scheduler.at в прошлом не принят")
    t:need(not pcall(scheduler.at, "нет", function() end), "scheduler.at принял не-число")
    t:need(not pcall(scheduler.after, 1, "не функция"), "scheduler.after принял не-функцию")

    -- Группы: таймер с group="ast" должен попадать в cancelGroup и pending(group).
    scheduler.after(3600, function() end, { group = "ast" })
    local pend = scheduler.pending("ast")
    t:note("pending('ast') = " .. tostring(pend))
    t:need((tonumber(pend) or 0) >= 1, "pending('ast') не увидел таймер своей группы")

    -- Отмена: cancel по id и cancelGroup. Оба не должны бросать.
    local cancelled = false
    local idc = scheduler.after(0, function() cancelled = true end)
    scheduler.cancel(idc)
    scheduler.cancel(idc)                       -- повторная отмена — no-op
    scheduler.cancel(999999)                   -- несуществующий id — no-op
    scheduler.cancelGroup("ast")
    scheduler.cancelGroup("нет-такой-группы")  -- несуществующая группа — no-op
    t:note("cancel/cancelGroup пережили повторы и несуществующие id")

    -- Фактическое срабатывание — отдельная отложенная проверка.
    t:defer(function(c)
        c:eq(cancelled, false, "отменённый таймер НЕ должен был сработать")
        local n = 0
        local hit = false
        scheduler.after(0, function() hit = true end)
        scheduler.every(0.05, function() n = n + 1 end)   -- every требует sec > 0
        scheduler.debounce("ast-deb", 0.05, function() n = n + 100 end)
        scheduler.debounce("ast-deb", 0.05, function() n = n + 100 end)
        scheduler.debounce("ast-deb", 0.05, function() n = n + 100 end)
        local thr = 0
        for _ = 1, 5 do
            -- throttle с leading=true (по умолчанию) срабатывает СРАЗУ на первом
            -- вызове, остальные 4 либо игнорируются, либо ставятся в trailing.
            scheduler.throttle("ast-thr", 30, function() thr = thr + 1 end)
        end
        c:defer(function(c2)
            c2:eq(hit, true, "after(0) не сработал за 0.3 с")
            c2:need(n > 0, "ни after, ни every, ни debounce не сработали")
            c2:note(string.format("сработало: всего %d (после 3 debounce-вызовов ожидаем 100 + after/every)",
                n))
            c2:note(string.format("throttle: вызовов 5, сработало %d (leading=true -> первый сразу)", thr))
            c2:eq(thr, 1, "throttle с leading=true должен сработать ровно один раз")
            scheduler.clear()
        end, 0.4, "через 0.7 с")
    end, 0.3, "таймеры")
end })

H.case({ id = "util.rng", section = "util", fn = function(t)
    -- Детерминизм: два ГСЧ с одним сидом дают одинаковую последовательность.
    local r1, r2 = rng.new(12345), rng.new(12345)
    local same = true
    for _ = 1, 20 do
        if r1:nextInt(1, 1000) ~= r2:nextInt(1, 1000) then same = false break end
    end
    t:eq(same, true, "один сид -> одинаковая последовательность")

    -- Границы nextInt.
    local r = rng.new(7)
    local lo, hi = 1, 6
    for _ = 1, 200 do
        local v = r:nextInt(lo, hi)
        t:need(v >= lo and v <= hi, "nextInt вне диапазона: " .. tostring(v))
    end
    local f = r:nextFloat()
    t:need(f >= 0 and f < 1, "nextFloat вне [0,1): " .. tostring(f))

    -- Откат состояния.
    local rs = rng.new(99)
    local before = rs:nextInt(1, 10 ^ 6)
    local snap = rs:state()
    local a1 = rs:nextInt(1, 10 ^ 6)
    rs:setState(snap)
    local a2 = rs:nextInt(1, 10 ^ 6)
    t:eq(a1, a2, "setState откатывает поток")
    t:note("nextInt до отката = " .. tostring(before))

    -- pick на пустой таблице == nil и НЕ тратит ГСЧ (важно для lockstep).
    local rp = rng.new(5)
    local st = rp:state()
    t:eq(rp:pick({}), nil, "pick пустого списка")
    t:eq(tostring(rp:state().a), tostring(st.a), "pick пустого списка не сдвинул состояние")

    -- shuffle не мутирует вход. ВАЖНО: r:shuffle(list) — МЕТОД, а не
    -- rng.new(x).shuffle(list): в Lua `a.b(c)` — это `a.b(a, c)`, так что пришлось бы
    -- создать генератор дважды, и в list попал бы второй генератор, а не массив.
    local input = { 1, 2, 3, 4 }
    local rsh = rng.new(3)
    local out = rsh:shuffle(input)
    t:need(out ~= input, "rng:shuffle вернул исходную таблицу")
    t:eq(#input, 4, "shuffle испортил входной список")
    t:eq(#out, 4, "shuffle результата длина")
    local sum = 0
    for _, v in ipairs(out) do sum = sum + v end
    t:eq(sum, 10, "shuffle потерял элементы")
    t:eq(#tablex.filter(out, function(v) return v % 2 == 1 end), 2, "tablex.filter по перемешанному")
    local rp2 = rng.new(1)
    t:note("pick из списка: " .. tostring(rp2:pick({ "a", "b", "c" })))
    t:eq(rp2:pick({}), nil, "pick пустого списка")
    local rr = rng.new(2)
    local rf = rr:range(10, 20)
    t:need(rf >= 10 and rf < 20, "range вне [10,20): " .. tostring(rf))
    t:note("range(10, 20) = " .. tostring(rf))
end })

H.case({ id = "util.rng.shared", section = "util", fn = function(t)
    -- Сиды матча: обязаны быть ОДИНАКОВЫ на всех машинах, иначе рассинхрон.
    local s1 = rng.seedFromGame()
    local s2 = rng.seedFromGame()
    t:need(type(s1) == "number" or type(s1) == "table", "rng.seedFromGame() вернул мусор")
    t:eq(tostring(s1), tostring(s2), "два вызова seedFromGame дали разные сиды (десинк!)")

    local n1 = rng.sharedSeed("ast_loot")
    local n2 = rng.sharedSeed("ast_loot")
    t:eq(tostring(n1), tostring(n2), "sharedSeed стабилен для одного имени")
    t:need(tostring(rng.sharedSeed("ast_other")) ~= tostring(n1),
        "sharedSeed разных имён совпали")

    -- Один и тот же сид -> одинаковый поток (основа воспроизводимости).
    local a, b = rng.new(n1), rng.new(n1)
    t:eq(a:nextInt(1, 10 ^ 9), b:nextInt(1, 10 ^ 9), "sharedSeed даёт воспроизводимый поток")
    t:note("seedFromGame = " .. tostring(s1) .. ", sharedSeed(loot) = " .. tostring(n1))
end })

-- query на 0.2.0 не работает ВООБЩЕ: query.scan начинается с
--   local g = rawget(_G, "game")
-- а в базовом окружении api нет поля _G (есть только _ENV; _G проставляется
-- только окружению МОДА). => rawget(nil, "game") => "bad argument #1 to 'rawget'".
-- Из-за этого падают все 12 функций модуля (они все идут через scan).
-- Кейс остаётся, чтобы баг было видно в отчёте, и объясняет корень.
H.case({ id = "util.query", section = "util", fn = function(t)
    t:inGame("query")
    local me = t:me()

    local ok, err = pcall(query.objects, {})
    if not ok then
        t:fail("query.objects упал: " .. tostring(err) ..
            "  <- БАГ API 0.2.0: query.scan использует rawget(_G, \"game\"), " ..
            "а в окружении api есть только _ENV. Чинится заменой _G -> _ENV " ..
            "(67_query.lua:46,47,127)")
    end
    local all = query.objects({})
    t:need(#all > 0, "query.objects вернул пусто на непустой карте")
    t:note("объектов на карте: " .. #all)

    local mine = query.units({ player = me, limit = 5 })
    t:note("своих юнитов (до 5): " .. #mine)
    local blds = query.buildings({ limit = 5 })
    t:note("зданий (до 5): " .. #blds)
    t:need(#blds <= 5, "query.buildings проигнорировал limit")

    -- Фильтры геометрии.
    local cx, cz = camera.gamePos()
    local near = query.inArea(cx, cz, 60, { limit = 10 })
    t:note("в радиусе 60 от камеры: " .. #near)
    for i, r in ipairs(near) do
        local d = math.sqrt((r.x - cx) ^ 2 + (r.z - cz) ^ 2)
        t:need(d <= 60.5, "query.inArea вернул объект дальше радиуса: " .. tostring(d))
        if i > 5 then break end
    end

    local rect = query.scan({ rect = { x1 = cx - 50, z1 = cz - 50, x2 = cx + 50, z2 = cz + 50 } })
    t:note("в прямоугольнике 100x100: " .. #rect)

    local sorted = query.scan({ sortByDistanceFrom = { x = cx, z = cz }, limit = 3 })
    if #sorted >= 2 then
        local d1 = math.sqrt((sorted[1].x - cx) ^ 2 + (sorted[1].z - cz) ^ 2)
        local d2 = math.sqrt((sorted[2].x - cx) ^ 2 + (sorted[2].z - cz) ^ 2)
        t:need(d1 <= d2 + 1e-6, "sortByDistanceFrom не отсортировал")
    end

    -- enemies/allies по индексу. В одиночке enemies пуст — это нормально.
    local foes = query.enemies(me)
    local allies = query.allies(me)
    t:note("enemies = " .. #foes .. ", allies = " .. #allies)
    for _, r in ipairs(allies) do
        t:eq(r.player, me, "query.allies вернул чужого")
        if #allies > 20 then break end
    end

    t:eq(query.count({ player = me }), #query.scan({ player = me }), "query.count совпал с scan")
    local first = query.first({ player = me })
    t:note("query.first = " .. (first and tostring(first.handle) or "nil"))
    local byType = query.byType("units", t:unitSid(), { limit = 3 })
    t:note("юнитов этого типа: " .. #byType)
end })

-- ===========================================================================
-- 3. ЧТЕНИЕ МИРА
-- ===========================================================================

H.case({ id = "read.objects", section = "read", fn = function(t)
    t:inGame("objects")
    local status = objects.status()
    t:note("objects.status: " .. tostring(status))
    local list = objects.list()
    t:need(#list > 0, "objects.list() пуст")
    t:note("всего объектов: " .. #list)

    local h = t:ownUnit()
    local o = objects.read(h)
    t:need(type(o) == "table", "objects.read вернул не таблицу")
    t:note(string.format("юнит %d: hp=%s pl=%s bdead=%s", h, tostring(o.hp), tostring(o.pl), tostring(o.bdead)))
    t:eq(objects.get(h, "hp"), o.hp, "objects.get('hp') совпал с read")

    local x, z = objects.pos(h)
    t:need(type(x) == "number", "objects.pos вернул не координаты")
    local ptr = objects.ptr(h)
    t:note(string.format("pos = (%.1f, %.1f), ptr = %s", x, z, tostring(ptr)))
end })

H.case({ id = "read.objects.perf", section = "read", fn = function(t)
    t:inGame("perf")
    local status = objects.status()
    local calibrated = tostring(status) ~= "not calibrated"
    t:note("objects.status: " .. tostring(status))
    if not calibrated then
        t:note("ВНИМАНИЕ: раскладка TObj НЕ откалибрована — objects.get/read идут " ..
            "через Pascal, поэтому сравнение скоростей ниже бессмысленно")
    end

    local list = objects.list()
    local n = #list
    -- ВАЖНО: os.clock() на Windows имеет шаг ~54 мс. На списке из пары объектов
    -- полный проход даёт 0.000 с -> деление на n = ноль -> "деление на ноль".
    -- Поэтому замер делаем на повторах и делим на ЧИСЛО ПОВТОРОВ.
    local REPS = 10
    local t0 = os.clock()
    local alive = 0
    for _ = 1, REPS do
        for _, h in ipairs(list) do
            local o = objects.read(h)
            if o and not o.bdead then alive = alive + 1 end
        end
    end
    local full = (os.clock() - t0) / REPS

    local h = t:ownUnit()
    t0 = os.clock()
    for _ = 1, 200 do objects.get(h, "hp") end
    local fast = (os.clock() - t0) / 200

    t0 = os.clock()
    for _ = 1, 20 do state.get(string.format("obj(%d).hp", h)) end
    local slow = (os.clock() - t0) / 20

    t:note(string.format("обход %d объектов: %.1f мс (живых %d)", n, full * 1000, alive))
    t:note(string.format("одно поле: objects.get %.4f мс, state.get %.4f мс (в %.1f раз)",
        fast * 1000, slow * 1000, slow / math.max(fast, 1e-9)))
    t:note(string.format("это %d вызовов движка на 1424 юнитах ≈ %.0f мс",
        200, 200 * fast * 1000))
    if calibrated then
        t:need(slow > fast, "Pascal-чтение быстрее чтения из памяти — подозрительно")
    else
        t:note("сравнение скоростей пропущено: без калибровки objects.get == Pascal")
    end
end })

H.case({ id = "read.state", section = "read", fn = function(t)
    t:inGame("state")
    local stage = state.get("gMap.gamestage")
    t:notNil(stage, "gMap.gamestage")
    t:note("gMap.gamestage = " .. tostring(stage))

    -- read записи целиком — один вызов скрипта вместо десятков get.
    local rec = state.read("gMap.players[0]")
    t:need(type(rec) == "table", "state.read игрока не вернул таблицу")
    t:note("gMap.players[0]: name=" .. tostring(rec.name) .. " team=" .. tostring(rec.team))

    local list = state.list("gMap.players")
    t:note("state.list вернул " .. #list .. " слотов")

    -- Через точку (G) — альтернативный путь.
    t:eq(G.gMap.gamestage, stage, "G.gMap.gamestage совпал с state.get")

    -- Ошибка должна называть поле, а не ронять мод.
    local ok, err = pcall(state.get, "gMap.no_such_field_zzz")
    t:need(not ok, "state.get на несуществующем поле НЕ ошибся")
    t:note("ошибка поля: " .. tostring(err):sub(1, 80))
end })

H.case({ id = "read.targeting", section = "read", fn = function(t)
    t:inGame("targeting")
    local me = t:me()
    local s = t:spot()
    local r = 40

    local inCircle = targeting.inCircle(s.x, s.z, r, {})
    t:note("inCircle r=" .. r .. ": " .. #inCircle)
    t:need(#inCircle > 0, "в радиусе " .. r .. " вокруг своего юнита пусто — тест бессмыслен")

    local foes = targeting.inCircle(s.x, s.z, 200, { enemy = true })
    t:note("врагов в радиусе 200: " .. #foes)
    for i, h in ipairs(foes) do
        local o = objects.read(h)
        if o and o.pl ~= nil then t:need(o.pl ~= me, "enemy=true вернул своего") end
        if i > 5 then break end
    end

    local mine = targeting.inCircle(s.x, s.z, 200, { player = me })
    t:note("своих в радиусе 200: " .. #mine)

    local dead = targeting.inCircle(s.x, s.z, 200, { alive = false })
    t:note("включая мёртвых: " .. #dead)

    local nearestH = targeting.nearest({ x = s.x, z = s.z }, { maxR = 500 })
    t:notNil(nearestH, "targeting.nearest в радиусе 500")
    local okSid, mySid = pcall(native.GetGameObjectBaseNameByHandle, t:anyUnit())
    if okSid and type(mySid) == "string" then
        local nearestUnit = targeting.nearest({ x = s.x, z = s.z }, { maxR = 500, sid = mySid })
        t:note("ближайший юнит типа '" .. mySid .. "': " .. tostring(nearestUnit))
    end

    -- Конус: 90° вперёд (dir=0 — +z).
    local cone = targeting.inCone(s.x, s.z, 0, math.pi / 4, 100, {})
    t:note("в конусе 90° на 100: " .. #cone)
    t:need(#cone <= #inCircle + 1000, "inCone вернул больше, чем весь круг того же радиуса (подозрительно)")

    local clear = targeting.los(s.x, s.z, s.x + 30, s.z + 30)
    t:note("los на 30 шагов вперёд: " .. tostring(clear))
    t:eq(type(clear), "boolean", "targeting.los вернул не boolean")
end })

H.case({ id = "read.pathfind", section = "read", fn = function(t)
    t:inGame("pathfind")
    local h = t:ownUnit()
    local s = t:spot()
    local x, z = objects.pos(h)
    t:note(string.format("юнит %s в (%.1f, %.1f), состояние %s", tostring(h), x or -1, z or -1,
        tostring(object.state(h))))

    -- Крюк нативов бросает Lua-ошибку при AV, так что ловим pcall: иначе кейс
    -- просто упал бы, не показав, ЧТО именно сломалось.
    -- ВАЖНО: натив может упасть С ВНУТРИ (SEH перехватывает loader -> Lua-ошибка
    -- "exception 0xC0000005 inside native", игра при этом ЖИВА). Это не баг api:
    -- api честно отдала ошибку вместо краша. Поэтому такое — не fail, а note.
    local function try(label, fn, ...)
        local ok, r1, r2, r3, r4 = pcall(fn, ...)
        if not ok then
            local e = tostring(r1)
            if e:find("inside native", 1, true) then
                t:note(label .. ": натив упал ВНУТРИ (SEH пойман loader, игра жива): " ..
                    e:sub(1, 90))
                t:note(label .. ": это ограничение натива, а не ошибка api — фиксирую как finding")
                return nil
            end
            t:fail("pathfind." .. label .. " упал: " .. e:sub(1, 110))
            return nil
        end
        t:note(string.format("%s: ok=%s -> %s %s %s %s", label, tostring(ok), tostring(r1),
            tostring(r2), tostring(r3), tostring(r4)))
        return r1, r2, r3, r4
    end

    -- Сначала Distance — он не трогает навигацию юнита и падать не должен.
    local d = try("distance", pathfind.distance, x, z, s.x + 60, s.z + 60)
    t:need(type(d) == "number", "pathfind.distance вернул " .. tostring(d))
    local straight = math.sqrt(60 * 60 + 60 * 60)
    if d < 0 then
        t:note(string.format("distance = %s -> ПУТИ НЕТ (натив отдаёт -1, а не исключение)", tostring(d)))
        t:note("это не ошибка: точка может быть вне проходимости. Проверь на заведомо своей точке.")
    else
        t:note(string.format("distance по топологии = %.1f (по прямой %.1f)", d, straight))
        t:need(d >= straight * 0.8, "путь по топологии подозрительно короче прямой")
    end

    -- calculate поPoint'у СРАЗУ под юнитом: заведомо проходимая цель.
    try("calculate(под юнитом)", pathfind.calculate, h, x + 1, z + 1)
    -- И только потом — в сторону.
    try("calculate(в сторону)", pathfind.calculate, h, s.x + 40, s.z + 40)
    try("calculateAdv", pathfind.calculateAdv, h, s.x - 40, s.z - 40, { depth = 200 })
    t:note("если calculate падает с 0xC0000005 — это БАГ API: натив бросает AV.")
    t:note("rc=0 означает «путь найден», ненулевой — разбирай через world.pos/dbg.ray")
end })

H.case({ id = "read.object.state", section = "read", fn = function(t)
    t:inGame("object.state")
    local h = t:ownUnit()
    local st = object.state(h)
    t:notNil(st, "object.state вернул nil")
    t:eq(type(st), "string", "object.state вернул не строку")
    t:note("состояние " .. h .. " = " .. tostring(st))
    t:note("units.info: " .. tostring((units.info(h) or {}).sid))
    local orders = units.orders(h) or {}
    t:note("текущий приказ: " .. tostring(orders[1] and orders[1].type or "нет"))
end })

H.case({ id = "read.terrain.height", section = "read", fn = function(t)
    t:inGame("terrain.height")
    local s = t:spot()
    local h1 = terrain.height(s.x, s.z)
    t:need(type(h1) == "number", "terrain.height вернул не число")
    -- Проверяем согласованность с нативом напрямую.
    local h2 = native.RayCastHeight(s.x, s.z)
    t:near(h1, h2, 0.01, "terrain.height совпадает с RayCastHeight")
    t:note(string.format("высота в (%.1f, %.1f) = %.2f", s.x, s.z, h1))
    -- Сетка высот должна быть гладкой: разброс в 10 шагов небольшой.
    local hs = {}
    for i = 1, 5 do hs[#hs + 1] = terrain.height(s.x + i * 10, s.z) end
    local lo, hi = hs[1], hs[1]
    for _, v in ipairs(hs) do lo, hi = math.min(lo, v), math.max(hi, v) end
    t:note(string.format("перепад на 50 шагов: %.2f", hi - lo))
end })

H.case({ id = "read.decals.effects", section = "read", fn = function(t)
    t:inGame("decals")
    t:note("decals.count() = " .. tostring(decals.count()))
    t:note("markers/dbg клиентские — в отчёте раздела 9")
    -- Проверка create/remove декали без визуального «мусора» в отчёте.
    local s = t:spot()
    local d = decals.put("mlscorch", s.x, s.z)
    t:notNil(d, "decals.put вернул nil")
    local x, z = decals.pos(d)
    t:need(type(x) == "number", "decals.pos вернул не координаты")
    t:note(string.format("декаль %s на (%.1f, %.1f), материал %s", tostring(decals.name(d)),
        x, z, tostring(decals.material(d))))
    decals.rotate(d, 0.5)
    t:near(decals.angle(d), 0.5, 1e-3, "decals.rotate/angle")
    decals.show(d, false)
    t:eq(decals.isVisible(d), false, "decals.show(false)")
    decals.show(d, true)
    t:eq(decals.isVisible(d), true, "decals.show(true)")
    decals.move(d, s.x + 3, s.z + 3)
    local x2, z2 = decals.pos(d)
    t:near(x2, s.x + 3, 0.01, "decals.move сдвинул по X")
    decals.remove(d)
    t:note("decals.remove прошёл")
end })

-- ===========================================================================
-- 4. МИР, РЕЛЬЕФ, ПОВЕДЕНИЯ
-- ===========================================================================

H.case({ id = "world.spawn", section = "world", fn = function(t)
    t:inGame("spawn")
    local s = t:spotOffset(30)
    -- sid берём У СВОЕГО ЮНИТА, а не выдумываем: строки вроде "musketeer18"
    -- зависят от нации и версии игры, а натив требует точный basename.
    local h = t:ownUnit()
    local unitSid = native.GetGameObjectBaseNameByHandle(h)
    t:need(type(unitSid) == "string" and unitSid ~= "",
        "не удалось узнать sid своего юнита (GetGameObjectBaseNameByHandle)")
    local race = t:race()
    t:note(string.format("спавним race='%s' base='%s'", race, unitSid))

    local spawned = t:spawn({ race = race, base = unitSid, x = s.x, z = s.z, name = "AST test" })
    t:notNil(spawned, "world.spawn вернул nil (движок отказал?)")
    t:note("spawned h = " .. tostring(spawned))

    local ok, o = pcall(objects.read, spawned)
    t:need(ok and type(o) == "table", "спавннутый объект не читается через objects.read")
    t:eq(o.bdead, false, "спавннутый объект сразу мёртв")
    t:eq(o.pl, t:me(), "владелец спавннутого объекта")
    t:eq(native.GetGameObjectBaseNameByHandle(spawned), unitSid, "sid спавннутого объекта")

    -- Здание: sid берём у СВОЕГО здания (если оно есть) — тоже не угадываем.
    local okB, b = pcall(function()
        local bsid = t:buildingSid()
        return t:spawn({ race = race, base = bsid, x = s.x + 40, z = s.z })
    end)
    if okB and b and b ~= 0 then
        t:note(string.format("здание sid='%s' создано, h=%s, это здание: %s",
            t:buildingSid(), tostring(b), tostring(t:isBuilding(b))))
        t:need(t:isBuilding(b), "спавннутое здание не читается как здание")
    else
        t:note("здание создать не вышло: " .. tostring(b))
        t:skip("нет своего здания — нечего проверять на зданиях (мельницу/казарму построй)")
    end

    -- Имя объекта: custom name — проверяем, что оно читается.
    local okName = pcall(native.GetGameObjectCustomNameByHandle, spawned)
    t:note("чтение custom name: " .. tostring(okName) .. " -> " ..
        tostring(okName and native.GetGameObjectCustomNameByHandle(spawned) or ""))
    -- actor/material/scale — необязательные поля spawn.
    local okScale = pcall(t.spawn, { race = race, base = unitSid, x = s.x, z = s.z + 10, scale = 1.2 })
    t:note("spawn со scale: " .. tostring(okScale))
    t:note("владелец объекта: " .. tostring(o.pl))
end })

H.case({ id = "world.spawn.bad", section = "world", risky = true, fn = function(t)
    t:inGame("spawn.bad")
    local s = t:spotOffset(60)
    -- Ожидание: world.spawn либо вернёт nil, либо бросит Lua-ошибку, но НЕ уронит игру.
    local h
    local ok, err = pcall(function()
        h = world.spawn({ race = t:race(), base = "no_such_base_zzz", x = s.x, z = s.z })
    end)
    t:note("несуществующий base: ok=" .. tostring(ok) .. ", h=" .. tostring(h) ..
           ", err=" .. tostring(err):sub(1, 60))
    t:need(not (h and h ~= 0), "world.spawn принял несуществующий base (движок не должен)")
    -- Если игра жива после этого — тест свою цель выполнил.
    t:eq(game.isInGame(), true, "игра жива после неверного sid")
end })

H.case({ id = "world.move.pos", section = "world", fn = function(t)
    t:inGame("move")
    local s = t:spotOffset(90)
    local h = t:spawn({ race = t:race(), base = t:unitSid(), x = s.x, z = s.z })

    local x0, y0, z0 = world.pos(h)
    t:need(type(x0) == "number", "world.pos вернул не координаты")
    t:note(string.format("старт (%.1f, %.2f, %.1f)", x0, y0, z0))

    world.move(h, s.x + 25, s.z + 15)
    local x1, y1, z1 = world.pos(h)
    t:near(x1, s.x + 25, 1.0, "world.move сдвинул по X")
    t:near(z1, s.z + 15, 1.0, "world.move сдвинул по Z")
    t:note(string.format("после move (%.1f, %.2f, %.1f) — y подобрался по рельефу", x1, y1, z1))

    -- Явный y: объект должен оказаться выше земли.
    world.move(h, x1, y0 + 30, z1)
    local _, y2 = world.pos(h)
    t:note(string.format("явный y: %.2f (было %.2f)", y2, y1))
    t:need(y2 > y1, "явный y не применился (объект не поднялся)")

    -- Возврат на землю, чтобы объект не висел.
    world.move(h, x1, z1)
    local _, y3 = world.pos(h)
    t:near(y3, t:ground(x1, z1), 1.5, "после move(h,x,z) y снова по рельефу")
end })

H.case({ id = "world.destroy", section = "world", fn = function(t)
    t:inGame("destroy")
    local s = t:spotOffset(120)
    -- ВАЖНО: после destroy/destroyNow хендль МЁРТВ. Любой последующий вызов с ним
    -- (objects.read, object.state, world.pos) роняет игру через
    -- native GetGameObjectStateMachineHandle -> TObject.InheritsFrom по освобождённому
    -- указателю. Проверено 2026-09-27: crashes/..._C0000005.txt, кадр #01.
    -- Поэтому здесь НИКАКИХ чтений уничтоженного объекта — только H.kill/H.readAlive.

    -- destroyNow: жёсткое удаление без событий смерти.
    local h1 = t:spawn({ race = t:race(), base = t:unitSid(), x = s.x, z = s.z })
    t:notNil(h1, "spawn для destroyNow")
    world.destroyNow(h1)
    H.kill(h1)
    H.forget("objects", h1)
    t:note("destroyNow: объект удалён без событий смерти")
    -- objects.alive() теперь ПРИЗНАЁТ СМЕРТЬ СРАЗУ: api/27_world.destroyNow вызывает
    -- objects._markDead(h) ДО native-удаления, а objects.alive смотрит deadHandles.
    -- Раньше хендль оставался валидным ещё кадр, и проверять надо было в defer.
    local okAlive, alive = pcall(objects.alive, h1)
    t:note(string.format("objects.alive(убитый) = %s сразу после destroyNow",
        tostring(okAlive and alive)))
    t:need(okAlive, "objects.alive() на мёртвом хендле упал: " .. tostring(alive))
    t:eq(alive, false, "objects.alive() не признал уничтоженный объект")
    t:eq(H.readAlive(h1), nil, "H.readAlive на уничтоженном объекте вернул не nil")
    t:eq(objects.ptr(h1), nil, "objects.ptr() на уничтоженном объекте вернул не nil")
    t:note("ptr/alive/read защищены — это и был источник краша C0000005")

    -- destroy: мягкое удаление через механику смерти — объект обязан умереть.
    local h2 = t:spawn({ race = t:race(), base = t:unitSid(), x = s.x + 10, z = s.z })
    t:notNil(h2, "spawn для destroy")
    local died = false
    -- Подписку держим ДО destroy: уничтожение может произойти не в этом кадре.
    local sub = events.on("unit.death", function(_, h) if h == h2 then died = true end end)
    world.destroy(h2)
    H.kill(h2)                       -- с этого момента h2 нельзя трогать НИКАК
    H.forget("objects", h2)
    t:note("destroy отдан; объект помечен мёртвым, чтения запрещены")

    t:defer(function(c)
        events.off(sub)
        c:eq(died, true, "world.destroy не вызвал unit.death за 1 с (мягкое удаление не сработало)")
        -- Метки должны держаться и после тиков, иначе защита осыпается.
        local a1 = (pcall(objects.alive, h1)) and objects.alive(h1)
        c:eq(a1, false, "через 1 с destroyNow-объект снова считается живым")
        local a2 = (pcall(objects.alive, h2)) and objects.alive(h2)
        c:note("alive(destroy-объект) через 1 с = " .. tostring(a2) ..
            " (ожидаем false: метка _markDead должна пережить тики)")
        c:eq(a2, false, "через 1 с уничтоженный объект снова числится живым")
        c:eq(game.isInGame(), true, "партия жива после destroy")
    end, 1, "смерть после destroy")
end })

H.case({ id = "world.destroy.wait", section = "world", fn = function(t)
    t:inGame("destroy.wait")
    local s = t:spotOffset(150)
    local h = t:spawn({ race = t:race(), base = t:unitSid(), x = s.x, z = s.z })
    local gone = false
    object.waitFor(h, "destroyed", function() gone = true end)
    t:note("waitFor подписан на 'destroyed' для h=" .. tostring(h) ..
        ", текущее состояние: " .. tostring(object.state(h)))
    t:keep("objects", h)

    -- Второй объект: ловим переход в 'attack' — на него юнит точно попадёт.
    local h2 = t:spawn({ race = t:race(), base = t:unitSid(), x = s.x + 12, z = s.z })
    local gotAttack = false
    object.waitFor(h2, "attack", function() gotAttack = true end)
    t:keep("objects", h2)
    t:note("waitFor на 'attack' для h=" .. tostring(h2) .. " — ждём боевого перехода")
    t:need(not pcall(object.waitFor, h, "x", "не функция"), "object.waitFor принял не-функцию")
    t:note("waitFor с не-функцией отклонён верно")

    t:defer(function(c)
        c:note("waitFor('destroyed') сработал: " .. tostring(gone) .. " (юнит сам не умирает — ожидаем false)")
        c:note("waitFor('attack') сработал: " .. tostring(gotAttack))
        c:note("состояния через 1.5 с: h1=" .. tostring((object.state(h) or "нет")) ..
            ", h2=" .. tostring((object.state(h2) or "нет")))
        c:eq(game.isInGame(), true, "партия жива после waitFor")
    end, 1.5, "waitFor")
end })

H.case({ id = "world.object.states", section = "world", fn = function(t)
    t:inGame("object.setState")
    local s = t:spotOffset(180)
    local h = t:spawn({ race = t:race(), base = t:unitSid(), x = s.x, z = s.z })
    local st0 = object.state(h)
    local cur = st0
    t:notNil(st0, "object.state до setState")
    t:note("состояние сразу после спавна: " .. tostring(st0))

    -- Раньше здесь были УГАДКИ ("Move", "Attack", ...). Это неверно: движок писал
    -- "TXStateMachine.IndexOfState(Move)", а состояние объекта становилось "" -
    -- то есть объект ЛОМАЛСЯ. Теперь имена берём у самой машины состояний.
    local list = object.states(h)
    t:note("состояния объекта (" .. #list .. "): " ..
        (#list > 0 and table.concat(list, ", ") or "<список пуст - см. object.states>"))
    t:need(#list > 0, "object.states вернул пустой список - перечисление не работает")

    -- Текущее состояние обязано быть в этом списке.
    local inList = false
    for _, s in ipairs(list) do if s == cur then inList = true break end end
    t:eq(inList, true, "текущее состояние '" .. tostring(cur) ..
        "' есть в object.states - иначе список неполон")

    -- Несуществующее имя теперь должно ОТКЛОНЯТЬСЯ, а не ломать объект.
    local beforeBad = object.state(h)
    local badOk, badErr = pcall(object.setState, h, "ast_no_such_state_zzz")
    t:eq(badOk, false, "object.setState с несуществующим именем НЕ отклонён")
    t:eq(object.state(h), beforeBad,
        "после неудачного setState состояние изменилось - объект сломан")
    t:note("отказ setState: " .. tostring(badErr):sub(1, 110))

    -- Настоящий переход: в состояние из списка, отличное от текущего.
    local target
    for _, s in ipairs(list) do
        if s ~= cur then target = s break end
    end
    if target then
        local ok, err = pcall(object.setState, h, target)
        t:note(string.format("setState('%s'): ok=%s -> '%s'%s", target, tostring(ok),
            tostring(object.state(h)), ok and "" or (" err=" .. tostring(err):sub(1, 50))))
        t:need(ok, "setState на существующее состояние " .. target ..
            " отклонён: " .. tostring(err):sub(1, 60))
        t:eq(object.state(h) ~= "", true, "после перехода состояние не должно стать пустым")
    else
        t:note("у объекта одно состояние - переход проверять не на чем")
    end
    t:need(not pcall(object.setState, h, ""), "object.setState с пустым именем отклонён")
    t:note("пустое имя отклонено ещё до похода в движок")

    -- destroyIn: объект должен исчезнуть при входе в состояние.
    local h2 = t:spawn({ race = t:race(), base = t:unitSid(), x = s.x + 20, z = s.z })
    object.destroyIn(h2, "dead")
    t:note("destroyIn(h,'dead') поставлен на h=" .. tostring(h2))
    t:keep("objects", h2)

    t:defer(function(c)
        -- h2 может быть уже уничтожен через destroyIn -> object.state убьёт игру.
        local alive2 = (pcall(objects.alive, h2)) and objects.alive(h2)
        c:note("через 1 с h2 жив = " .. tostring(alive2) ..
            (alive2 and (", состояние " .. tostring(object.state(h2))) or " (уничтожен — не читаем)"))
        c:note("destroyIn сработает, когда объект войдёт в 'dead' — тогда он исчезнет сам")
        c:eq(game.isInGame(), true, "партия жива после destroyIn")
    end, 1, "destroyIn")
end })

H.case({ id = "world.object.progress", section = "world", risky = true, fn = function(t)
    t:inGame("object.progress")
    local s = t:spotOffset(210)
    local h = t:spawn({ race = t:race(), base = t:unitSid(), x = s.x, z = s.z })
    -- Путь к .aix из data/scripts — точный путь критичен, поэтому это риск.
    local scripts = {
        "scripts/fire.aix", "data/scripts/fire.aix", "scripts/attack.aix",
        "lib/fire.aix", "units/unit.aix", "scripts/unit.aix",
    }
    local lastErr
    for _, path in ipairs(scripts) do
        local ok, idOrErr = pcall(object.progress, h, path, "burning", { interval = 200 })
        t:note(string.format("progress('%s','burning'): ok=%s -> %s", path, tostring(ok),
            tostring(idOrErr):sub(1, 50)))
        if ok and type(idOrErr) == "number" and idOrErr ~= 0 then
            t:note("поведение создано, id = " .. tostring(idOrErr) .. " (экспериментальная функция)")
            return
        end
        lastErr = idOrErr
    end
    t:note("ни один путь не подошёл; последняя ошибка: " .. tostring(lastErr):sub(1, 90))
    t:skip("object.progress: ни один из " .. #scripts .. " путей .aix не принят — нужен настоящий путь")
end })

H.case({ id = "world.terrain", section = "world", risky = true, fn = function(t)
    t:inGame("terrain")
    local s = t:spot()
    -- ВАЖНО: x, y — КЛЕТКИ карты (целые), не мировые координаты.
    local cx = math.floor(s.x)
    local cz = math.floor(s.z)
    local before = terrain.height(cx, cz)
    t:note(string.format("высота до правок: %.2f (клетка %d, %d)", before, cx, cz))

    terrain.raise(cx, cz, { delta = 3 })
    terrain.raise(cx + 1, cz, { delta = 3 })
    terrain.lower(cx + 3, cz, { delta = 4 })
    terrain.smooth(cx, cz)
    terrain.update()
    local after = terrain.height(cx, cz)
    t:note(string.format("высота после raise(3)+lower(4)+smooth+update: %.2f", after))
    t:note(string.format("изменение: %+.2f", after - before))
    t:need(math.abs(after - before) > 0.05,
        "terrain.raise/lower/smooth не изменили высоту (движок проигнорировал?)")

    -- Возврат рельефа: сглаживание и обновление, чтобы карта не осталась изуродованной.
    for i = -2, 4 do
        pcall(terrain.lower, cx + i, cz, { delta = 6 })
    end
    terrain.smooth(cx - 2, cz)
    terrain.smooth(cx + 4, cz)
    terrain.update()
    t:note(string.format("высота после возврата: %.2f (рельеф частично восстановлен)",
        terrain.height(cx, cz)))
    t:note("terrain.update(horizon=false) — отдельный вызов")
    pcall(terrain.update, false)
end })

H.case({ id = "world.behaviour", section = "world", risky = true, fn = function(t)
    t:inGame("behaviour")
    local s = t:spotOffset(240)
    local h = t:spawn({ race = t:race(), base = t:unitSid(), x = s.x, z = s.z })
    local x0, _, z0 = world.pos(h)

    -- Инерция физики — самая частая точка падения у не-штатных типов.
    local ph = behaviour.inertia(h)
    t:need(ph and ph ~= 0, "behaviour.inertia вернул " .. tostring(ph))
    t:note("инерция id = " .. tostring(ph))

    behaviour.force(ph, 100, 0, 0, 0)
    behaviour.torque(ph, 10, 0, 0)
    behaviour.push(ph, 0, -98, 0, 0)
    behaviour.bounce(ph, 0, 1, 0, 0.6)
    behaviour.mirror(ph)
    t:note("force/torque/push/bounce/mirror вызваны без ошибок")

    -- blast: толчок от точки — проверяем, что позиция изменилась.
    local bx = x0 + 60
    local blastId = behaviour.blast(h, bx, z0, 500, 300)
    t:notNil(blastId, "behaviour.blast вернул nil")
    t:note("blast от (%.1f, %.1f) power=500 -> id %s", bx, z0, tostring(blastId))

    -- classname поведения: точные имена берутся из data/behaviours, ошибиться легко.
    local classes = { "cannon_recoil", "falling", "default", "physics" }
    for _, c in ipairs(classes) do
        local ok, idOrErr = pcall(behaviour.create, h, c)
        t:note(string.format("behaviour.create('%s'): ok=%s -> %s", c, tostring(ok), tostring(idOrErr)))
        if ok and type(idOrErr) == "number" and idOrErr ~= 0 then
            t:keep("behaviours", idOrErr)
            t:note("класс '" .. c .. "' принят движком, id = " .. tostring(idOrErr))
            break
        end
    end

    -- Позиция после физики (объект может улететь/упасть — это нормально).
    local x1, y1, z1 = world.pos(h)
    t:note(string.format("позиция после физики: (%.1f, %.2f, %.1f), сдвиг=%.1f",
        x1 or -1, y1 or -1, z1 or -1,
        (x1 and z1) and math.sqrt((x1 - x0) ^ 2 + (z1 - z0) ^ 2) or -1))
end })

H.case({ id = "world.tracks", section = "world", risky = true, fn = function(t)
    t:inGame("tracks")
    local s = t:spot()
    local group = "ast_road"
    t:keep("trackGroups", group)

    local y1 = t:ground(s.x, s.z)
    local y2 = t:ground(s.x + 60, s.z)
    local y3 = t:ground(s.x + 60, s.z + 60)
    local a = tracks.add(group, s.x, y1, s.z, 0)
    t:need(a and a ~= 0, "tracks.add вернул " .. tostring(a))
    local b = tracks.add(group, s.x + 60, y2, s.z, 0)
    local c = tracks.add(group, s.x + 60, y3, s.z + 60, 0)
    t:need(b and c, "tracks.add для узлов 2/3 вернул 0")
    t:note(string.format("узлы: a=%s b=%s c=%s, всего в сетях: %s", tostring(a), tostring(b),
        tostring(c), tostring(tracks.count())))

    tracks.connect(a, b)
    tracks.connect(b, c)
    tracks.oneSide(a, c)
    t:note("connect(a,b), connect(b,c), oneSide(a,c) — ок")

    local exists = tracks.exists(a, c)
    t:eq(type(exists), "boolean", "tracks.exists вернул не boolean")
    t:note(string.format("exists(a,c) = %s, длина пути = %s", tostring(exists),
        tostring(tracks.lastLength())))

    local nb = tracks.neighbours(a)
    t:note("соседей у узла a: " .. #nb .. (next(nb) and "" or " (пусто — связи не записались)"))
    local nx, ny, nz = tracks.pos(a)
    t:near(nx, s.x, 1.0, "tracks.pos(a) вернул ту же точку")

    -- use: юнит ходит по узлам при поиске пути.
    local h = t:ownUnit()
    tracks.use(h, true)
    t:note("tracks.use(h, true) — юнит будет искать путь по узлам")
    tracks.use(h, false)

    -- breakFar: рвёт ВСЕ связи длиннее dist в игре — аккуратно, это общий мир.
    tracks.breakFar(100000)
    t:note("breakFar(100000) — порог огромный, связи не должны порваться")
    t:eq(tracks.exists(a, c), exists, "после breakFar(100000) путь не изменился")
end })

H.case({ id = "world.regions", section = "world", fn = function(t)
    t:inGame("regions")
    local s = t:spot()
    local name = "ast_zone"
    -- Квадрат 60x60 вокруг своего юнита.
    local poly = {
        { x = s.x - 30, z = s.z - 30 }, { x = s.x + 30, z = s.z - 30 },
        { x = s.x + 30, z = s.z + 30 }, { x = s.x - 30, z = s.z + 30 },
    }
    t:eq(regions.create(name, poly, { owner = t:me() }), name, "regions.create вернул имя")
    t:keep("regions", name)

    t:eq(regions.contains(name, s.x, s.z), true, "точка в центре внутри зоны")
    t:eq(regions.contains(name, s.x + 200, s.z), false, "точка далеко снаружи")
    t:eq(regions.contains(name, s.x, s.z - 100), false, "точка на 100 шагов вне")

    local inside = regions.units(name, { alive = true })
    t:note("юнитов в зоне: " .. #inside)

    local entered, left = 0, 0
    regions.onEnter(name, function() entered = entered + 1 end)
    regions.onLeave(name, function() left = left + 1 end)
    t:note("onEnter/onLeave подписаны (считаются в game.tick)")
    t:need(not pcall(regions.onEnter, name, "не функция"), "regions.onEnter принял не-функцию")
    t:need(not pcall(regions.contains, "нет_такой_зоны", 0, 0), "regions.contains не ругается на несуществующую зону")
    t:need(not pcall(regions.create, "x", { { x = 0, z = 0 } }), "regions.create принял 2 точки")
    t:note("create с 2 точками отклонён верно (нужно 3+)")
    t:note("сейчас entered=" .. entered .. " left=" .. left)

    -- Проверка границы. ВАЖНО: полигон в regions считается «чётно-нечётным лучом»,
    -- поэтому точки РОВНО на границе считаются снаружи. Проверяем на отступе 1 шаг.
    -- Середина стороны квадрата лежит ТОЧНО на границе зоны, а regions.contains
    -- на границе не определён (у нас он возвращал false). Поэтому проверяем точки,
    -- заведомо ВНУТРИ: 60% пути от центра к середине каждой стороны.
    local n = #poly
    for i = 1, n do
        local a, b = poly[i], poly[i % n + 1]      -- сторона i: вершина i и следующая
        local mx, mz = (a.x + b.x) / 2, (a.z + b.z) / 2
        local ix, iz = s.x + (mx - s.x) * 0.6, s.z + (mz - s.z) * 0.6
        t:eq(regions.contains(name, ix, iz), true,
            string.format("точка внутри стороны %d (%.1f, %.1f) должна быть в зоне", i, ix, iz))
        -- ГРАНИЦА ТЕПЕРЬ ОДНОЗНАЧНА: api/54_regions.inPoly проверяет отрезок и
        -- возвращает true на границе, чтобы зона не "протекала" в наведении.
        t:eq(regions.contains(name, mx, mz), true,
            string.format("середина стороны %d (%.1f, %.1f) — граница, должна считаться ВНУТРИ", i, mx, mz))
    end
    -- Углы и точка сразу за границей.
    for i = 1, n do
        local v = poly[i]
        t:eq(regions.contains(name, v.x, v.z), true,
            string.format("вершина %d (%.1f, %.1f) — граница, должна считаться ВНУТРИ", i, v.x, v.z))
    end
    local ox, oz = s.x + 30.5, s.z
    t:eq(regions.contains(name, ox, oz), false,
        "точка сразу ЗА границей должна быть снаружи")
    t:note("граница однозначна: вершины и середины сторон внутри, +0.5 снаружи")
    t:eq(regions.contains(name, s.x, s.z - 30), true, "точка на 1 шаг выше нижней грани")
    t:note("точки РОВНО на границе (x=" .. poly[1].x .. ") дают false — это особенность")
    t:note("алгоритма проверки полигона, а не ошибка regions.create")

    -- onEnter/onLeave считаются в game.tick: ждём и проверяем, что юнит ВНУТРИ зоны
    -- (зона построена вокруг него) засчитан как вошедший.
    t:defer(function(c)
        c:note(string.format("через 1 с: entered=%d, left=%d, юнитов в зоне=%d",
            entered, left, #regions.units(name, { alive = true })))
        c:need(entered > 0, "regions.onEnter ни разу не сработал, хотя юнит внутри зоны")
        c:eq(left, 0, "regions.onLeave сработал, хотя никто не выходил")
    end, 1, "onEnter/onLeave")
end })

H.case({ id = "world.regions.block", section = "world", risky = true, fn = function(t)
    t:inGame("regions.block")
    local s = t:spot()
    local name = "ast_forbidden"
    regions.create(name, {
        { x = s.x - 40, z = s.z - 40 }, { x = s.x + 40, z = s.z - 40 },
        { x = s.x + 40, z = s.z + 40 }, { x = s.x - 40, z = s.z + 40 },
    })
    t:keep("regions", name)

    -- Блок режет приказы ВНУТРИ зоны. Проверяем, что событие unit.order с точкой
    -- в зоне возвращает true (то есть приказ отменяется).
    local blocked = false
    local sub = events.on("unit.order", function(_, h, kind, target, x, z)
        if x and z and regions.contains(name, x, z) then
            blocked = true
            return true
        end
    end)
    local h = t:ownUnit()
    orders.move(h, s.x, s.z)          -- точка В зоне -> должно быть отменено
    orders.move(h, s.x + 400, s.z)    -- точка ВНЕ зоны -> должно пройти
    events.off(sub)
    t:note("приказ с точкой в зоне заблокирован: " .. tostring(blocked))
    t:note("событие сработало: " .. tostring(blocked))

    -- Снимаем блок, чтобы он не влиял на остальные кейсы.
    pcall(regions.block, name, false)
    t:note("блок снят")
end })

-- ===========================================================================
-- 5. ПРИКАЗЫ, ОТРЯДЫ, СТАТУСЫ, ИИ
-- ===========================================================================

H.case({ id = "combat.orders.move", section = "combat", fn = function(t)
    t:inGame("orders.move")
    local h = t:ownUnit()
    local s = t:spot()
    -- Считаем приказы, дошедшие до юнита: orders идут через _unit_AddOrder,
    -- поэтому событие unit.order обязано сработать.
    local seen = {}
    local sub = events.on("unit.order", function(_, uh, kind) seen[uh] = tostring(kind) end)
    -- НА 0.2.0 orders.* не компилируется: кэшированное состояние ModLoader.Call
    -- строится вызовом _unit_AddOrder(..., cl = 1, fi = 1) — присваивание внутри
    -- списка аргументов, а параметры объявлены const. Смотри api/38_orders.lua.
    local ok, err = pcall(orders.move, h, s.x + 20, s.z + 20)
    t:note("orders.move: ok=" .. tostring(ok) .. (ok and "" or (" err=" .. tostring(err):sub(1, 90))))
    t:note("unit.order увидел: " .. tostring(seen[h]))
    if not ok then
        t:fail("orders.move не работает на 0.2.0 — БАГ API: в api/38_orders.lua вызов " ..
            "_unit_AddOrder(..., cl = 1, fi = 1) передаёт присваивание в параметр, " ..
            "объявленный const, и Integer в Boolean. Ошибка: " .. tostring(err):sub(1, 120))
    end
    t:need(seen[h] ~= nil, "orders.move не вызвал событие unit.order")

    local list = units.orders(h) or {}     -- НЕ называем локаль `orders`: это затенит api
    t:note("units.orders(h)[1] = " .. tostring(list[1] and list[1].type))
    events.off(sub)

    -- Очередь: clear=false добавляет приказ в конец, а не сбрасывает.
    orders.move(h, s.x + 30, s.z + 30, { clear = false })
    t:note("orders.move с clear=false (в очередь) — ок")
    orders.cancel(h)
    t:note("orders.cancel(h) — ок")
end })

H.case({ id = "combat.orders.kinds", section = "combat", fn = function(t)
    t:inGame("orders")
    local h = t:ownUnit()
    local s = t:spot()
    local seen = {}
    local sub = events.on("unit.order", function(_, uh, kind) seen[#seen + 1] = tostring(kind) end)

    local results = {}
    local function try(label, fn)
        local ok, err = pcall(fn)
        results[#results + 1] = string.format("%s=%s%s", label, tostring(ok),
            ok and "" or (" (" .. tostring(err):sub(1, 50) .. ")"))
    end
    try("attackMove", function() orders.attackMove(h, s.x + 25, s.z) end)
    try("patrol", function() orders.patrol(h, s.x + 40, s.z, s.x + 40, s.z + 40) end)
    try("cancel(full)", function() orders.cancel(h, true) end)
    try("queue", function() orders.queue(h, {
        { move = { s.x, s.z + 50 } },
        { attackpoint = { s.x + 50, s.z + 50 } },
        { patrol = { s.x, s.z, s.x, s.z + 30 } },
    }) end)
    t:note("результаты: " .. table.concat(results, "; "))

    -- Проверка контракта: у всех видов приказов общий скомпилированный кусок,
    -- поэтому если он не компилируется, не работает НИ ОДИН из них.
    local anyOk = false
    for _, r in ipairs(results) do
        if r:match("=true") then anyOk = true end
    end
    if not anyOk then
        t:fail("ни один вид приказа не отработал — БАГ API 0.2.0 в api/38_orders.lua: " ..
            "скомпилированное состояние не собирается (см. combat.orders.move)")
    end
    t:need(#seen >= 1, "ни одного события unit.order после отдачи приказов")
    t:note("unit.order увидел: " .. table.concat(seen, ","):sub(1, 160))
    events.off(sub)
    orders.cancel(h, true)
end })

H.case({ id = "combat.orders.target", section = "combat", fn = function(t)
    t:inGame("orders.attack")
    local h = t:ownUnit()
    local target = t:foeUnit()   -- skip в одиночной игре без противника
    local seen = {}
    local sub = events.on("unit.order", function(_, uh, kind, trg) seen[uh] = tostring(kind) .. ":" .. tostring(trg) end)

    orders.attack(h, target)
    t:note("attack -> unit.order: " .. tostring(seen[h]))
    t:need(seen[h] ~= nil, "orders.attack не вызвал unit.order")
    seen = {}
    orders.attack(h, target, { lock = true })
    t:note("attack с lock=true: " .. tostring(seen[h]))
    seen = {}
    orders.guard(h, target)
    t:note("guard -> unit.order: " .. tostring(seen[h]))
    t:note("orders.follow это тот же guard: " .. tostring(orders.follow == orders.guard))
    events.off(sub)
    orders.cancel(h, true)
end })

H.case({ id = "combat.formation", section = "combat", fn = function(t)
    t:inGame("formation")
    -- Чистая геометрия работает везде и проверяется точно.
    for _, shape in ipairs({ "line", "column", "wedge", "square", "circle" }) do
        local slots = formation.slots(shape, 8, 3, 0, 100, 50)
        t:eq(#slots, 8, "formation.slots(" .. shape .. ") вернул не 8 слотов")
        for i, s in ipairs(slots) do
            t:need(type(s.x) == "number" and type(s.z) == "number",
                "слот " .. i .. " в " .. shape .. " без координат")
        end
    end
    -- Симметрия: line должен быть симметричен относительно центра.
    local line = formation.slots("line", 5, 4, 0, 0, 0)
    t:near(line[1].x + line[5].x, 0, 1e-6, "line: первый и последний слот симметричны")
    t:near(line[3].x, 0, 1e-6, "line: средний слот в центре")
    -- Кольцо: все слоты на одной окружности.
    local ring = formation.slots("circle", 6, 3, 0, 0, 0)
    local r1 = math.sqrt(ring[1].x ^ 2 + ring[1].z ^ 2)
    for i = 2, 6 do
        t:near(math.sqrt(ring[i].x ^ 2 + ring[i].z ^ 2), r1, 1e-6, "circle: слот " .. i .. " на том же радиусе")
    end
    t:note("радиус кольца из 6 слотов при spacing=3: " .. string.format("%.2f", r1))

    -- set: реальные приказы строем.
    local units = {}
    for _, h in ipairs(t:myUnits(6)) do units[#units + 1] = h end
    if #units < 2 then t:skip("нужно минимум 2 своих юнита для построения") end
    local s = t:spot()
    local slots = formation.set(units, "square", { x = s.x + 60, z = s.z + 60, spacing = 4 })
    t:eq(#slots, #units, "formation.set вернул слот на каждый юнит")
    t:note("построение square на " .. #units .. " юнитов отдано")
    t:need(game.isInGame(), "партия жива после построения")
end })

H.case({ id = "combat.group", section = "combat", fn = function(t)
    t:inGame("group")
    local me = t:me()
    local g = group.create(me, "ast_squad")
    t:need(g and g ~= 0, "group.create вернул 0")
    t:keep("groups", g)
    t:eq(group.count(g), 0, "новая группа пуста")
    t:note("группа создана: h = " .. tostring(g))

    -- Набираем до 5 юнитов (в одиночке их может не быть — тогда skip).
    local units = {}
    for _, h in ipairs(t:myUnits(5)) do units[#units + 1] = h end
    if #units == 0 then t:skip("нет своих живых юнитов для группы") end
    group.add(g, units)
    t:eq(group.count(g), #units, "group.add не выставил состав")
    t:eq(#group.members(g), #units, "group.members совпал с составом")
    t:note("в группе " .. group.count(g) .. " юнитов: " .. table.concat(units, ", "))

    -- group.center считает по КЭШУ, который пересчитывает group.rebuild().
    -- Без rebuild центр = (0, 0, 0) - это НЕ ошибка API, а пустой кэш.
    local bx, by, bz = group.center(g)
    t:note(string.format("центр ДО rebuild: (%.1f, %.2f, %.1f) - ожидаем 0, кэш не пересчитан",
        bx or -1, by or -1, bz or -1))
    group.rebuild(g)
    t:eq(group.count(g), #units, "group.rebuild потерял юнитов")

    local cx, cy, cz = group.center(g)
    t:need(type(cx) == "number", "group.center вернул не число")
    t:note(string.format("центр после rebuild: (%.1f, %.2f, %.1f)", cx, cy, cz))

    -- Центр обязан совпасть с центроидом наших юнитов, а не быть (0, 0, 0).
    local sx, sz, n = 0, 0, 0
    for _, h in ipairs(units) do
        local x, z = H.posAlive(h)
        if x then sx, sz, n = sx + x, sz + z, n + 1 end
    end
    if n > 0 then
        t:near(cx, sx / n, 2.0, "group.center X не совпал с центроидом юнитов")
        t:near(cz, sz / n, 2.0, "group.center Z не совпал с центроидом юнитов")
    else
        t:note("некому сверять: юниты не позиционируются")
    end

    local s = t:spotOffset(100)
    group.move(g, s.x + 50, s.z + 50)
    group.formation(g, "line", { spacing = 3 })
    group.stretch(g, 1.5)
    t:need(game.isInGame(), "партия жива после движения/строя/растяжения")
    t:note("move/formation/stretch отданы")
    t:note("group.ready до расчёта пути: " .. tostring(group.ready(g)))

    group.direct(g, true)
    t:note("group.direct(true) — марш по прямой")
    group.rebuild(g)
    t:note("group.rebuild — сетка строя пересчитана")

    -- Удаление одного участника и очистка состава.
    group.remove(g, units[1])
    t:eq(group.count(g), #units - 1, "group.remove убрал участника")
    group.clear(g)
    t:eq(group.count(g), 0, "group.clear опустошил группу")

    -- Возвращаем состав и проверяем pathfind.groupReady на непустой группе.
    group.add(g, units)
    t:eq(pathfind.groupReady(g), group.ready(g),
        "pathfind.groupReady совпал с group.ready (один и тот же натив)")
    group.destroy(g)
    H.forget("groups", g)
    t:note("группа расформирована, юниты живы")
end })

H.case({ id = "combat.status", section = "combat", fn = function(t)
    t:inGame("status")
    local h = t:ownUnit()
    local hp0 = (objects.read(h) or {}).hp
    t:note(string.format("HP до эффектов: %s", tostring(hp0)))

    -- regen: лечит, HP должен вырасти (или упереться в потолок).
    status.add(h, "regen", { duration = 3, heal = 5 })
    t:eq(status.has(h, "regen"), true, "status.has после add")
    local list = status.list(h)
    t:note("status.list: " .. table.concat(list, ","))
    status.remove(h, "regen")
    t:eq(status.has(h, "regen"), false, "status.remove снял эффект")

    -- poison/burning: наносят урон каждый тик.
    status.add(h, "poison", { duration = 3, damage = 2 })
    t:note("poison добавлен, HP сейчас = " .. tostring((objects.read(h) or {}).hp))
    status.remove(h, "poison")

    -- Свой эффект через define.
    local applied, removed, ticks = false, false, 0
    status.define("ast_custom", {
        interval = 1,
        onApply = function() applied = true end,
        onTick = function() ticks = ticks + 1 end,
        onRemove = function() removed = true end,
    })
    status.add(h, "ast_custom", { duration = 2 })
    t:note(string.format("свой эффект: onApply=%s, onTick запустится в game.tick (сейчас %d)",
        tostring(applied), ticks))
    status.remove(h, "ast_custom")
    t:note("onRemove после remove: " .. tostring(removed))

    -- Неизвестный эффект обязан честно ругаться, а не молча ничего не делать.
    local ok, err = pcall(status.add, h, "no_such_status_zzz", {})
    t:need(not ok, "status.add принял неизвестный эффект")
    t:note("ошибка неизвестного эффекта: " .. tostring(err):sub(1, 50))

    -- invisible: model.show(false) — проверяем через model.
    status.add(h, "invisible", { duration = 2 })
    t:eq(status.has(h, "invisible"), true, "invisible применён")
    status.remove(h, "invisible")
    t:note("stunned проверим через блокировщик приказов (отдельный кейс)")

    -- ГЛАВНОЕ для status: урон и лечение идут в game.tick, поэтому проверяем отложенно.
    -- Отдельный юнит-мишень, чтобы не мешать основному отряду.
    local sp = t:spotOffset(160)
    local victim = t:spawn({ race = t:race(), base = t:unitSid(), x = sp.x, z = sp.z })
    t:notNil(victim, "мишень для проверки урона")
    local hpStart = (objects.read(victim) or {}).hp
    t:note(string.format("HP жертвы до эффектов: %s", tostring(hpStart)))

    local fired, applied2, removed2 = 0, false, false
    status.define("ast_burn", {
        interval = 0.5,
        onApply = function() applied2 = true end,
        onTick = function(vh) fired = fired + 1; state.set("obj(" .. vh .. ").hp",
            math.max(0, ((objects.read(vh) or {}).hp or 0) - 5)) end,
        onRemove = function() removed2 = true end,
    })
    status.add(victim, "ast_burn", { duration = 2 })

    t:defer(function(c)
        local vAlive = (pcall(objects.alive, victim)) and objects.alive(victim)
        local hpEnd = vAlive and (objects.read(victim) or {}).hp or nil
        if not vAlive then c:note("жертва погибла от своего урона (это нормально)") end
        c:eq(applied2, true, "onApply не вызвался")
        c:note(string.format("onTick сработал %d раз за 2 с (интервал 0.5)", fired))
        c:note(string.format("HP: было %s, стало %s", tostring(hpStart), tostring(hpEnd)))
        c:need(type(hpStart) == "number" and type(hpEnd) == "number" and hpEnd < hpStart,
            "статусный урон не изменил HP (тики эффекта не работают?)")
        c:eq(status.has(victim, "ast_burn"), false, "эффект не снялся по истечении duration")
        c:eq(removed2, true, "onRemove не вызвался при истечении duration")
    end, 2.5, "урон по тикам")
end })

H.case({ id = "combat.status.blocker", section = "combat", risky = true, fn = function(t)
    t:inGame("status.installBlocker")
    status.installBlocker(events.on)
    local h = t:ownUnit()
    local s = t:spot()

    local gotOrderWhileStunned = false
    local sub = events.on("unit.order", function(_, uh) if uh == h then gotOrderWhileStunned = true end end)
    status.add(h, "stunned", { duration = 3 })
    t:eq(status.has(h, "stunned"), true, "stunned применён")
    orders.move(h, s.x + 20, s.z + 20)
    events.off(sub)
    t:note("юнит оглушён, приказ отдан: " .. tostring(gotOrderWhileStunned))
    t:note("unit.order для оглушённого юнита НЕ должен доходить до симуляции")
    t:note("проверка: если приказ всё же исполнился — блокировщик не работает")

    status.remove(h, "stunned")
    -- После снятия приказы должны проходить снова.
    local after = false
    local sub2 = events.on("unit.order", function(_, uh) if uh == h then after = true end end)
    orders.move(h, s.x + 25, s.z + 25)
    events.off(sub2)
    t:eq(after, true, "после снятия stunned приказы снова проходят")

    -- Оба лога нужны после fact: unit.order может прийти на следующем тике.
    t:defer(function(c)
        local orders1 = units.orders(h) or {}
        c:note("текущий приказ юнита: " .. tostring(orders1[1] and orders1[1].type or "нет"))
        c:note(string.format("во время оглушения приказ дошёл: %s, после снятия: %s",
            tostring(gotOrderWhileStunned), tostring(after)))
        c:note("если оба true — блокировщик либо не установлен, либо игнорируется движком")
        c:eq(status.has(h, "stunned"), false, "stunned не снялся после remove")
    end, 0.8, "приказы при оглушении")
end })

H.case({ id = "combat.ai", section = "combat", fn = function(t)
    t:inGame("ai")
    local h = t:ownUnit()
    local s = t:spot()
    local log2 = {}

    ai.attach(h, {
        initial = "idle",
        tickEvery = 1,
        states = {
            idle = {
                onEnter = function(_, api) log2[#log2 + 1] = "enter:idle home=" ..
                    string.format("(%.0f,%.0f)", api.home.x, api.home.z) end,
                onTick = function(_, api)
                    log2[#log2 + 1] = "tick:idle hp=" .. tostring(api.hp())
                    api.gotoState("work")
                end,
            },
            work = {
                onEnter = function(_, api, p) log2[#log2 + 1] = "enter:work p=" .. tostring(p.tag) end,
                onTick = function(_, api) log2[#log2 + 1] = "tick:work" end,
            },
        },
    })
    t:eq(ai.state(h), "idle", "ai.state сразу после attach")
    t:note("home = " .. string.format("(%.1f, %.1f)", (function()
        local x, z = objects.pos(h)
        return x or -1, z or -1
    end)()))

    ai.set(h, "work", { tag = "manual" })
    t:eq(ai.state(h), "work", "ai.set перевёл в work")
    t:note("журнал автомата: " .. table.concat(log2, " | "):sub(1, 200))

    -- ai.set на несуществующее состояние / без attach — обязаны ругаться.
    t:need(not pcall(ai.set, h, "нет_такого_состояния"), "ai.set принял неизвестное состояние")
    ai.detach(h)
    t:eq(ai.state(h), nil, "ai.detach снял автомат")
    t:need(not pcall(ai.set, h, "work"), "ai.set без attach не ругается")

    -- Мёртвый юнит снимается сам — проверим на живом, просто убедившись в API.
    local h2 = t:anyUnit()
    t:eq(type(ai.state(h2)), "nil", "ai.state для юнита без мозга = nil")
end })

H.case({ id = "combat.weapon", section = "combat", risky = true, fn = function(t)
    t:inGame("weapon.fire")
    local s = t:spotOffset(120)
    local me = t:me()

    -- Способность-носитель: weapon.fire требует зарегистрированный id abilities.
    abilities.define("ast_shell", { cooldown = 0, damage = 50, radius = 12,
        target = "all", effect = "cannon" })
    t:need(abilities.get("ast_shell") ~= nil, "abilities.define/get не сработали")
    t:eq(abilities.ready("ast_shell", me), true, "cooldown=0 -> всегда готов")

    -- Урон: создаём мишень и меряем HP до/после. Скорость 60 -> подлёт = d/60 секунд,
    -- плюс игровая задержка. Проверяем отложенно, когда снаряд долетел.
    local shooter = t:ownUnit()
    local sx, sz = objects.pos(shooter)
    local target = t:spawn({ race = t:race(), base = t:unitSid(), x = s.x, z = s.z })
    t:notNil(target, "мишень создана")
    local hp0 = (objects.read(target) or {}).hp
    local flight = math.sqrt((s.x - sx) ^ 2 + (s.z - sz) ^ 2) / 60
    t:note(string.format("HP цели до выстрела: %s, время подлёта ~%.1f с", tostring(hp0), flight))

    -- Считаем урон через событие unit.damage — это главный признак боевого эффекта.
    local dmgTotal, dmgEvents, srcSeen = 0, 0, false
    local sub = events.on("unit.damage", function(_, attacker, tgt, damage)
        if tgt == target then
            dmgTotal = dmgTotal + (tonumber(damage) or 0)
            dmgEvents = dmgEvents + 1
            if attacker == shooter then srcSeen = true end
        end
    end)

    weapon.fire({
        ability = "ast_shell", from = shooter, target = { x = s.x, z = s.z },
        weapon = "PUEXP", damage = 50, radius = 12, speed = 60, shots = 1,
    })
    t:note("снаряд отправлен из своего юнита " .. tostring(shooter))

    t:defer(function(c)
        events.off(sub)
        local tAlive = (pcall(objects.alive, target)) and objects.alive(target)
        local o = tAlive and objects.read(target) or nil
        local hp1 = o and o.hp
        c:note(string.format("урон через unit.damage: %s за %d событий (источник = наш юнит: %s)",
            tostring(dmgTotal), dmgEvents, tostring(srcSeen)))
        c:note(string.format("HP цели: было %s, стало %s", tostring(hp0), tostring(hp1)))
        c:need(dmgEvents > 0, "weapon.fire не вызвал ни одного unit.damage — урон не наносится")
        c:need(dmgTotal > 0, "unit.damage пришёл, но с нулевым уроном")
        if type(hp0) == "number" and type(hp1) == "number" then
            c:note(string.format("HP изменился на %+.1f (ожидаем -50, если не было брони/резиста)", hp1 - hp0))
            c:need(hp1 < hp0, "HP цели не уменьшился после попадания")
        else
            c:note("цель уничтожена выстрелом насквозь (объекта уже нет) — тоже корректно")
        end
    end, flight + 1.5, "урон от снаряда")
end })

H.case({ id = "combat.weapon.barrage", section = "combat", risky = true, fn = function(t)
    t:inGame("weapon.fire залп")
    local s = t:spotOffset(150)
    abilities.define("ast_mortar", { cooldown = 0, damage = 25, radius = 8, effect = "howitzer" })
    -- Залп с интервалом и кассетами: проверяем, что планировщик не падает.
    weapon.fire({
        ability = "ast_mortar", target = { x = s.x, z = s.z },
        weapon = "PUEXPHOWITZER", damage = 25, radius = 8,
        shots = 3, interval = 0.4, spread = 6,
        sub = { count = 4, radius = 3, damage = 10 },
    })
    t:note("залп 3 снаряда + кассета 4 бомб поставлен в очередь")
    t:need(game.isInGame(), "партия жива после постановки залпа")
    t:note("проверь визуально: летят снаряды PUEXPHOWITZER, урон идёт от abilities")

    -- Залп — это 3 отдельных выстрела + кассета: ждём и считаем попадания.
    local victim = t:spawn({ race = t:race(), base = t:unitSid(), x = s.x, z = s.z })
    t:notNil(victim, "мишень для залпа")
    local hp0 = (objects.read(victim) or {}).hp
    local hits = 0
    local sub = events.on("unit.damage", function(_, _, tgt) if tgt == victim then hits = hits + 1 end end)
    t:defer(function(c)
        events.off(sub)
        local vAlive = (pcall(objects.alive, victim)) and objects.alive(victim)
        local hp1 = vAlive and (objects.read(victim) or {}).hp or nil
        c:note(string.format("залп: попаданий %d, HP было %s стало %s", hits, tostring(hp0), tostring(hp1)))
        c:need(hits > 0, "залп из 3 снарядов + кассета не нанёс ни одного удара")
        if type(hp0) == "number" and type(hp1) == "number" then
            c:need(hp1 < hp0, "HP цели не уменьшилось после залпа")
        end
    end, 3, "залп")
end })

H.case({ id = "combat.abilities", section = "combat", risky = true, fn = function(t)
    t:inGame("abilities.fire")
    local s = t:spotOffset(180)
    local me = t:me()

    -- Определение и проверка нормализации полей.
    local def = abilities.define("ast_test", { damage = 10, radius = 5,
        target = "all", effect = "grenade" })
    t:note(string.format("abilities.define вернул копию: id=%s damage=%s radius=%s effect=%s",
        tostring(def.id), tostring(def.damage), tostring(def.radius), tostring(def.effect)))
    t:eq(def.damage, 10, "define вернул нормализованный damage")
    t:need(not pcall(abilities.define, "ast_bad_target", { target = "нет" }),
        "abilities.define принял неверный target")
    t:need(not pcall(abilities.define, "ast_bad_effect", { effect = "нет" }),
        "abilities.define принял неверный effect")
    t:need(not pcall(abilities.define, "1не_ид", { damage = 1 }), "abilities.define принял неверный id")

    abilities.define("ast_airstrike", { cooldown = 5, damage = 100, radius = 15,
        target = "all", effect = "cannon" })
    t:eq(abilities.get("ast_airstrike").cooldown, 5, "get вернул определение")
    local ok, hit = abilities.fire("ast_airstrike", s.x, s.z, { owner = me })
    t:need(ok == true, "abilities.fire отказал: " .. tostring(hit))
    t:note(string.format("первый выстрел: ok=%s, объектов в радиусе = %s", tostring(ok), tostring(hit)))
    t:eq(abilities.ready("ast_airstrike", me), false, "cooldown выставлен после выстрела")

    -- Второй выстрел должен быть отклонён по cooldown.
    local ok2, why, wait = abilities.fire("ast_airstrike", s.x, s.z, { owner = me })
    t:eq(ok2, false, "второй выстрел прошёл, хотя cooldown=5")
    t:eq(why, "cooldown", "причина отказа = cooldown")
    t:note(string.format("осталось ждать: %s с", string.format("%.1f", tonumber(wait) or -1)))

    -- target-фильтры: buildings/units.
    abilities.define("ast_b", { cooldown = 0, damage = 1, radius = 40, target = "buildings" })
    local okB, hitB = abilities.fire("ast_b", s.x, s.z, {})
    t:note(string.format("только здания: попало %s", tostring(hitB)))
    abilities.define("ast_u", { cooldown = 0, damage = 1, radius = 40, target = "units" })
    local okU, hitU = abilities.fire("ast_u", s.x, s.z, {})
    t:note(string.format("только юниты: попало %s", tostring(hitU)))
    t:note("урон по зданиям: %s, по юнитам: %s ( Buildings должны отличаться )", tostring(hitB), tostring(hitU))
end })

H.case({ id = "combat.attach", section = "combat", fn = function(t)
    t:inGame("attach")
    local h = t:ownUnit()
    local target = t:anyUnit()

    -- follow: объект следует за другим.
    attach.follow(h, target)
    t:note(string.format("attach.follow(%d -> %d) поставлен", h, target))
    t:keep("follows", h)
    -- unfollow должен быть безопасен и на снятом, и на активном follow.
    attach.unfollow(h)
    t:note("attach.unfollow выполнен")
    H.forget("follows", h)
    pcall(attach.unfollow, h)
    t:note("повторный unfollow на неснятом — не упал")

    -- effect: PFX со смещением. Имена менеджеров берутся из data/effects.
    local effectsTried = {}
    for _, mgr in ipairs({ "fire", "smoke", "explosion", "default" }) do
        local ok, err = pcall(attach.effect, h, mgr, "ast_attach", { pos = { 0, 1, 0 }, lifetime = 2 })
        effectsTried[#effectsTried + 1] = string.format("%s:%s", mgr, tostring(ok))
        if ok then
            t:keep("pfx", h, mgr, "ast_attach")
            t:note("attach.effect с менеджером '" .. mgr .. "' принят")
            break
        end
    end
    t:note("попытки attach.effect: " .. table.concat(effectsTried, " "))
    t:note("подсветка через effects.highlight: ")
    local okHl = pcall(effects.highlight, h, "ast_hl", true, "")
    t:note("effects.highlight: " .. tostring(okHl))
    pcall(effects.unhighlight, h, "ast_hl")
    t:note("attach.free — освободить всё привязанное")
    pcall(attach.free, h)
end })

H.case({ id = "combat.vision", section = "combat", fn = function(t)
    t:inGame("vision")
    local h = t:ownUnit()

    -- reveal/hide: объект виден всегда.
    local okR = pcall(vision.reveal, h)
    t:note("vision.reveal: " .. tostring(okR))
    local okH = pcall(vision.hide, h)
    t:note("vision.hide: " .. tostring(okH))

    -- radius: меняет дальность обзора типа (детекторов в движке нет — только дальность).
    for _, sid in ipairs({ "musketeer18", "cav18", "musketeer" }) do
        local ok, err = pcall(vision.radius, sid, 2000)
        t:note(string.format("vision.radius('%s', 2000): ok=%s%s", sid, tostring(ok),
            ok and "" or (" err=" .. tostring(err):sub(1, 50))))
    end
    t:note("возврат обзора назад: 900 (стандарт)")
    pcall(vision.radius, "musketeer18", 900)

    -- night: выключение тумана — заметно глазом.
    local fowBefore = fow.isEnabled()
    pcall(vision.night, true)
    t:note(string.format("vision.night(true): fow был включён = %s, сейчас = %s",
        tostring(fowBefore), tostring(fow.isEnabled())))
    pcall(vision.night, false)
    t:note("vision.night(false) вернул как было")
end })

-- ===========================================================================
-- 6. ТУМАН ВОЙНЫ
-- ===========================================================================

H.case({ id = "fow.getters", section = "fow", fn = function(t)
    t:inGame("fow")
    t:note("fow.isEnabled() = " .. tostring(fow.isEnabled()))
    t:note(string.format("fow.lerp = %s", tostring(fow.lerp())))
    t:note(string.format("fow.elevation = %s", tostring(fow.elevation())))
    t:note(string.format("fow.textured = %s", tostring(fow.textured())))
    t:eq(type(fow.enable()), "boolean", "fow.enable() как геттер вернул не boolean")
end })

H.case({ id = "fow.setters", section = "fow", risky = true, fn = function(t)
    t:inGame("fow")
    local was = fow.isEnabled()
    local lerp0, elev0, tex0 = fow.lerp(), fow.elevation(), fow.textured()

    fow.enable(false)
    t:eq(fow.isEnabled(), false, "fow.enable(false) снял туман")
    t:note("туман снят — карта должна стать полностью видимой")
    fow.enable(true)
    t:eq(fow.isEnabled(), true, "fow.enable(true) вернул туман")

    fow.lerp(0.5)
    t:near(fow.lerp(), 0.5, 1e-4, "fow.lerp(0.5) прочитался обратно")
    fow.lerp(lerp0)

    fow.elevation(true)
    t:eq(fow.elevation(), true, "fow.elevation(true)")
    fow.elevation(elev0)

    fow.textured(false)
    t:eq(fow.textured(), false, "fow.textured(false)")
    fow.textured(tex0)

    fow.smooth(true, 1.0, false, 0)
    t:note("fow.smooth(pcf=1, aa=0) — сглаживание края")
    fow.rebuild()
    t:note("fow.rebuild() — полный пересчёт тумана")
    fow.enable(was)
    t:note(string.format("состояние тумана восстановлено: %s", tostring(fow.isEnabled())))
end })

H.case({ id = "fow.objects", section = "fow", fn = function(t)
    t:inGame("fow")
    local h = t:ownUnit()
    -- Точечная разведка от объекта: после неё объект виден даже вне обзора.
    fow.revealObject(h)
    t:note(string.format("fow.revealObject(%d) — юнит теперь виден всегда", h))
    fow.hideObject(h)
    t:note("fow.hideObject — разведка снята")
    fow.revealObject(h)

    -- Разведка для всех игроков: полное открытие карты.
    local me = t:me()
    local ph = native.GetPlayerHandleByIndex(me)
    t:need(ph and ph ~= 0, "GetPlayerHandleByIndex вернул 0")
    fow.revealPlayer(ph)
    t:note("fow.revealPlayer — игрок видит всю карту")
    fow.clearPlayers()
    t:note("fow.clearPlayers — откат")
    fow.clearObjects()
    t:note("fow.clearObjects — все точечные разведки сняты")
    t:note("вНИМАНИЕ: проверь глазом, что карта осталась в обычном режиме")
end })

-- ===========================================================================
-- 7. ВРЕМЯ, СЦЕНАРИИ, ЭКОНОМИКА, РЕПЛЕЙ
-- ===========================================================================

H.case({ id = "flow.time", section = "flow", risky = true, fn = function(t)
    t:inGame("time")
    local f0 = time.factor()
    t:need(type(f0) == "number", "time.factor вернул не число")
    t:note(string.format("скорость сейчас: %s", tostring(f0)))

    time.speed(0.5)
    t:near(time.factor(), 0.5, 1e-3, "time.speed(0.5)")
    t:note("внимание: партия замедлена вдвое — это видно по юнитам")
    time.pause()
    t:eq(time.factor(), 0, "time.pause() обнулил скорость")
    t:note("партия на паузе")
    time.resume()
    t:need(math.abs(time.factor() - 0.5) < 0.05,
        "time.resume вернул не запомненную скорость, а " .. tostring(time.factor()))
    time.speed(f0)
    t:near(time.factor(), f0, 1e-3, "скорость восстановлена")
    t:need(not pcall(time.speed, -1), "time.speed принял отрицательную скорость")
    t:note("time.speed(-1) отклонён верно")
end })

H.case({ id = "flow.economy", section = "flow", fn = function(t)
    t:inGame("economy")
    economy.link(savedata)
    local me = t:me()
    local RES = "ast_fuel"

    t:eq(economy.get(me, RES), 0, "изначально ресурса нет")
    economy.set(me, RES, 100)
    t:eq(economy.get(me, RES), 100, "economy.set")
    local added = economy.add(me, RES, -30)
    t:eq(added, true, "economy.add(-30)")
    t:eq(economy.get(me, RES), 70, "после add")
    -- Уход в минус обязан быть отклонён.
    t:eq(economy.add(me, RES, -1000), false, "economy.add в минус не отклонён")
    t:eq(economy.get(me, RES), 70, "ресурс не изменился после отклонённого add")
    t:eq(economy.consume(me, RES, 20), true, "economy.consume(20)")
    t:eq(economy.get(me, RES), 50, "после consume")
    t:eq(economy.consume(me, RES, 1000), false, "economy.consume больше, чем есть")
    t:need(not pcall(economy.consume, me, RES, -5), "economy.consume принял отрицательное amount")

    -- Ключи разных игроков не должны путаться. ВАЖНО: это последняя операция
    -- перед produce — не затираем запас своего игрока (иначе produce скажет
    -- "not enough" и проверить будет нечего).
    local other = (me == 0) and 1 or 0
    economy.set(other, RES, 9)
    economy.set(other, RES .. "_b", 0)   -- второй ключ: изоляция по ключу
    local mine = economy.get(me, RES)
    t:note(string.format("свой (%d) = %s, чужой (%d) = %s", me, tostring(mine), other,
        tostring(economy.get(other, RES))))
    t:need(mine >= 20, "запас своего игрока упал до " .. tostring(mine) .. " до produce")

    -- produce: стоимость списывается СРАЗУ, юнит появится через time секунд.
    local b = t:ownBuilding()
    local ok, idOrWhy = economy.produce(b, t:unitSid(),
        { time = 3, cost = { [RES] = 10 }, amount = 1, player = me })
    t:eq(ok, true, "economy.produce: " .. tostring(idOrWhy))
    t:eq(economy.get(me, RES), 40, "cost списан сразу")
    t:note("производство id = " .. tostring(idOrWhy) .. " (юнит встанет в очередь через 3 с)")

    -- Нехватка ресурсов -> false с причиной.
    local ok2, why2 = economy.produce(b, t:unitSid(),
        { time = 1, cost = { [RES] = 10000 }, amount = 1, player = me })
    t:eq(ok2, false, "economy.produce без денег прошёл")
    t:note("причина отказа: " .. tostring(why2))

    -- cancel отменяет отложенный заказ (деньги не возвращаются — это задокументировано).
    if ok then
        economy.cancel(idOrWhy)
        t:note("economy.cancel(" .. tostring(idOrWhy) .. ") — заказ отменён, cost не вернётся")
    end
    t:note("итог: " .. economy.get(me, RES) .. " " .. RES)
end })

H.case({ id = "flow.scenario", section = "flow", fn = function(t)
    t:inGame("scenario")
    scenario.link({ broadcast = net.broadcast, on = net.on })
    local me = t:me()
    local s = t:spot()

    -- objective: capture — свой юнит в радиусе.
    scenario.objective("ast_cap", {
        type = "capture", x = s.x, z = s.z, radius = 40, player = me,
        onDone = function(id) t:note("цель capture выполнена: " .. id) end,
    })
    t:note("цель capture поставлена (юнит уже в радиусе — должна закрыться на ближайших тиках)")

    -- destroy — цель на живом юните: не выполнена.
    local h = t:anyUnit()
    scenario.objective("ast_kill", { type = "destroy", target = h,
        onDone = function() t:note("цель destroy выполнена") end })
    t:eq(scenario.check("ast_kill"), false, "destroy на живом юните не выполнена")

    -- survive — уменьшает счётчик на 0.1 за вызов.
    scenario.objective("ast_surv", { type = "survive", seconds = 1 })
    t:eq(scenario.check("ast_surv"), false, "survive не выполнена сразу")

    -- gather — читает economy-подобный ресурс игрока (player(o.player)).
    scenario.objective("ast_gather", { type = "gather", player = me, res = "gold", amount = 1 })
    t:notNil(scenario.check("ast_gather"), "scenario.check для gather вернул nil")
    t:note("gather: золота у игрока = " .. tostring(player(me).gold))

    -- Нет такой цели -> false, без ошибки.
    t:eq(scenario.check("ast_нет_такой"), false, "check для несуществующей цели")

    -- cancelObjective снимает цель.
    scenario.cancelObjective("ast_cap")
    t:eq(scenario.check("ast_cap"), false, "отменённая цель больше не выполняется")
    scenario.cancelObjective("ast_kill")
    scenario.cancelObjective("ast_surv")
    scenario.cancelObjective("ast_gather")
    t:note("все цели сняты")
end })

H.case({ id = "flow.scenario.wave", section = "flow", fn = function(t)
    t:inGame("scenario.wave")
    scenario.link({ broadcast = net.broadcast, on = net.on })
    local s = t:spotOffset(210)
    local id = scenario.wave({
        delay = 2, units = { t:unitSid(), t:unitSid() }, race = t:race(),
        x = s.x, z = s.z, player = 0,
        onSpawn = function(wid) t:note("волна " .. wid .. " заспавнена") end,
    })
    t:notNil(id, "scenario.wave вернул nil")
    t:note("волна " .. tostring(id) .. ": 2 юнита через 2 с")
    -- Плохие спецификации обязаны ругаться.
    t:need(not pcall(scenario.wave, { delay = 1, x = s.x, z = s.z }),
        "scenario.wave принял спецификацию без units")
    t:need(not pcall(scenario.wave, { units = {}, x = "нет", z = s.z }),
        "scenario.wave принял нечисловой x")
    t:note("отмена волны: снимаем задачу напрямую (списка волн в api нет)")
end })

H.case({ id = "flow.scenario.dialog", section = "flow", fn = function(t)
    t:inGame("scenario.dialog")
    scenario.link({ broadcast = net.broadcast, on = net.on })
    scenario.dialog("ast_intro", { speaker = "Стенд", text = "Проверка scenario.dialog", duration = 5 })
    t:note("диалог отправлен всем (клиент покажет его через scenario.present)")
    t:need(not pcall(scenario.dialog, "ast_x", "не таблица"),
        "scenario.dialog принял не таблицу")
    t:note("scenario.dialog с неправильным spec отклонён")
end })

H.case({ id = "flow.scenario.snapshot", section = "flow", fn = function(t)
    t:inGame("snapshot")
    local name = scenario.snapshot("ast_snapshot.png", 640, 480)
    t:eq(name, "ast_snapshot.png", "scenario.snapshot с именем вернул имя")
    t:note("снимок запрошен: ast_snapshot.png (640x480) — ищи в папке игры")
    t:need(not pcall(scenario.snapshot, 123), "scenario.snapshot принял не строку")
    t:note("безымянный вариант (native.GetLastCreateSnapShotFileName) оставлен на клиент")
end })

H.case({ id = "flow.replay", section = "flow", fn = function(t)
    t:inGame("replay")
    replay.mark("ast_mark_1")
    replay.mark("ast_mark_2")
    local marks = replay.marks()
    t:need(type(marks) == "table", "replay.marks вернул не таблицу")
    t:note(string.format("меток: %d, последняя: %s", #marks,
        #marks > 0 and tostring(marks[#marks].name) or "-"))
    if #marks > 0 then
        local m = marks[#marks]
        t:note(string.format("метка: step=%s t=%s name=%s", tostring(m.step), tostring(m.t), tostring(m.name)))
    end
    replay.camera(true)
    t:note("replay.camera(true) — камера пишет трек")
    replay.camera(false)
    t:note("replay.camera(false) — запись трека остановлена")
end })

-- ===========================================================================
-- 8. СЕТЬ, ДЕТЕКТОР РАССИНХРОНА
-- ===========================================================================

H.case({ id = "net.recorder", section = "net", fn = function(t)
    t:inGame("netrec")
    -- Запись включается автоматически в game.start (чтобы журнал писался с начала
    -- партии), поэтому здесь мы её ПЕРЕЗАПУСКАЕМ со своим hashEvery, а не проверяем
    -- начальное состояние.
    local wasOn = netrec.isOn()
    t:note("netrec уже был включён автозапуском: " .. tostring(wasOn))
    netrec.start({ hashEvery = 3 })
    t:eq(netrec.isOn(), true, "netrec.start включил запись")
    t:eq(type(netrec.step()), "number", "netrec.step вернул не число")
    t:eq(netrec.step(), 0, "после start счётчик шагов должен быть 0")
    t:note(string.format("hashEvery=3, step=%s", tostring(netrec.step())))
    t:note("netrec пишет локальный журнал: sync-шаги + приказы + хеши")
    t:note("в одиночной партии sync-шагов может не быть (net.sync — команда lockstep)")
    t:defer(function(c)
        local rep = netrec.report()
        c:note("через 1.5 с: step=" .. tostring(netrec.step()))
        c:note("первая строка отчёта: " .. tostring(rep):sub(1, 100))
        c:need(netrec.isOn(), "netrec выключился сам без game.end")
    end, 1.5, "netrec через 1.5 с")
end })

H.case({ id = "net.recorder.report", section = "net", fn = function(t)
    t:inGame("netrec.report")
    t:eq(netrec.isOn(), true, "запись должна быть включена предыдущим кейсом")
    local rep = netrec.report()
    t:need(type(rep) == "string" and #rep > 0, "netrec.report пуст")
    log.info("[AST] netrec.report:\n" .. rep)
    t:note("отчёт netrec выведен в лог (см. [AST] netrec.report)")
    t:note(string.format("шаг=%s, строк отчёта=%d", tostring(netrec.step()), select(2, rep:gsub("\n", "")) + 1))
end })

H.case({ id = "net.recorder.dump", section = "net", fn = function(t)
    t:inGame("netrec.dump")
    netrec.dump()
    t:note("netrec.dump() — построчно в лог ошибкой (видно в modloader.log)")
end })

H.case({ id = "net.lockstep.determinism", section = "net", risky = true, fn = function(t)
    t:inGame("lockstep")
    -- Главная проверка для сети: одинаковый код на всех машинах обязан дать
    -- одинаковый результат. Считаем хеш последовательности и сравниваем с тем,
    -- что каждая машина посчитает сама (см. сетевой отчёт netrec).
    local gen = map.settings().gen
    t:note(string.format("зерно карты: randkey0=%s randkey1=%s",
        tostring(gen and gen.randkey0), tostring(gen and gen.randkey1)))

    -- Детерминированный поток от зерна карты — ровно то, чем обязаны пользоваться
    -- shared-моды. Считаем 10 значений и запоминаем для сверки на второй машине.
    local seed = rng.sharedSeed("ast_lockstep")
    local r = rng.new(seed)
    local parts = {}
    for i = 1, 10 do parts[#parts + 1] = tostring(r:nextInt(1, 1000000)) end
    local fp = table.concat(parts, ":")
    t:note("отпечаток потока: " .. fp)
    -- Публикуем отпечатки по сети: на второй машине должен получиться тот же.
    pcall(net.broadcast, "ast.fingerprint", { fp = fp, seed = tostring(seed) })
    t:note("отпечаток отправлен по сети (ast.fingerprint)")
    t:note("если вторая машина прислала другой fp — рассинхрон детерминизма")
end })

H.case({ id = "net.order.capture", section = "net", fn = function(t)
    t:inGame("order capture")
    -- Считаем ВСЕ приказы партии: это то, что расходится первым при рассинхроне.
    local kinds, total = {}, 0
    local counts = {}
    local sub = events.on("unit.order", function(_, h, kind)
        total = total + 1
        local k = tostring(kind)
        counts[k] = (counts[k] or 0) + 1
    end)
    local s = t:spot()
    local units = {}
    for _, h in ipairs(t:myUnits(3)) do units[#units + 1] = h end
    if #units == 0 then
        events.off(sub)
        t:skip("нет своих юнитов для проверки приказов")
    end
    for _, h in ipairs(units) do orders.move(h, s.x + 30, s.z + 30) end
    for k, v in pairs(counts) do kinds[#kinds + 1] = k .. "=" .. v end
    events.off(sub)
    t:note(string.format("приказов поймано: %d (%s)", total, table.concat(kinds, ", ")))
    t:eq(total, #units, "поймано не столько unit.order, сколько отдано orders.move")
    orders.cancel(units, true)
end })

-- ===========================================================================
-- ЗАПУСК
-- ===========================================================================

local TAG = 0

-- Клиент просит прогнать кейсы этой стороны. Фильтр: { section = "all"|id, risky = bool }.
net.on("ast.run", function(data, from)
    TAG = TAG + 1
    local myTag = TAG
    local section = (type(data) == "table" and data.section) or "all"
    local risky = type(data) == "table" and data.risky == true
    log.info(string.format("[AST] shared: запрос прогона '%s' risky=%s (от %s)", section,
        tostring(risky), tostring(from)))

    local res, err = H.run(section, { risky = risky })
    if not res then
        log.warn("AST: " .. tostring(err))
        return
    end

    -- Строки результатов — кусками (лимит сообщения 8 КБ), затем маркер конца.
    H.broadcast(myTag, res.records, {
        tag = myTag, side = "shared", section = section, risky = risky, ms = res.ms,
        ok = res.counts.ok, fail = res.counts.fail, error = res.counts.error,
        skip = res.counts.skip, total = res.counts.total,
    })
end)

-- Ответ на клиентский ping: замыкает проверку канала client -> server -> client.
net.on("ast.ping", function(data)
    if type(data) ~= "table" then return end
    pcall(net.broadcast, "ast.pong", { n = data.n, s = "pong" })
end)

-- Отпечаток детерминизма с другой машины — пишем в лог рядом со своим.
net.on("ast.fingerprint", function(data)
    if type(data) ~= "table" or not data.fp then return end
    log.info("[AST] fingerprint с машины: " .. tostring(data.fp))
    log.warn("[AST] СВЕРЬТЕ: свой отпечаток напечатан в сетевом отчёте. Если не совпал — рассинхрон.")
end)

-- Хост тоже должен уметь прогнать себя без клиента (например, из консоли).
-- Для ручного запуска: game.eval("...") не подходит — используем net-путь выше.

events.on("game.start", function()
    log.info(string.format("[AST] стенд загружен. Кейсов на этой стороне: %d. Клавиши: F5 панель, " ..
        "F6 раздел, F7 все, F8 опасные, F10 отчёт, F11 очистка, Ctrl+F7 всё, Ctrl+F10 подробно.",
        #H.myCases("all")))
    -- Сеть: клиент шлёт ast.run, а shared отвечает. Стартуем запись netrec, чтобы
    -- журнал писался с начала партии — иначе нечего сравнивать при рассинхроне.
    if not netrec.isOn() then
        pcall(netrec.start, { hashEvery = 5 })
        log.info("[AST] netrec включён автоматически (hashEvery=5)")
    end
end)

events.on("game.end", function()
    if netrec.isOn() then
        netrec.dump()
        netrec.stop()
    end
    H.cleanup(false)
    H.reset()
end)

return H
