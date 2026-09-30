-- client.lua — интерфейс стенда + кейсы, которые видны только этому игроку.
--
-- Здесь три вещи:
--   1) кейсы client-стороны (dbg, sound, markers, cutscene, gui, panel, minimap,
--      камера, steam) — они по определению не могут проверяться на shared;
--   2) панель управления на родном интерфейсе игры (panel.*/gui.*) — заодно
--      проверяет сами gui/panel, потому что на них строится управление;
--   3) приём результатов shared-стороны по сети и вывод отчёта.
--
-- Клавиши (F9/F12/End заняты модлоадером в dev-режиме, их не трогаем):
--   F5          открыть/закрыть панель
--   F6          прогнать ТЕКУЩИЙ раздел (безопасные кейсы)
--   F7          прогнать все безопасные
--   F8          прогнать опасные кейсы текущего раздела (с подтверждением)
--   F10         отчёт в лог
--   F11         полная очистка мусора
--   Ctrl+F6     прогнать раздел, включая опасные
--   Ctrl+F7     прогнать вообще всё, включая опасные
--   Ctrl+F10    подробный отчёт (все строки, включая успешные)
--   Ctrl+F11    очистить отчёт (без очистки мусора)
--   F4          открыть/закрыть страницу отчёта в CEF

local H = require("harness")

-- Разделы, которые клиент умеет гонять (все — но steam/visual требуют партии).
local current = "env"        -- текущий раздел для F6/F8

-- ===========================================================================
-- КЕЙСЫ CLIENT-СТОРОНЫ
-- ===========================================================================

H.case({ id = "visual.dbg.text", section = "visual", side = "client", fn = function(t)
    t:inGame("dbg")
    local s = t:spot()
    local y = t:ground(s.x, s.z) + 20
    local id = "ast_txt"
    dbg.text(id, s.x, y, s.z, "AST: dbg.text", { scale = 2, color = { 255, 220, 80, 255 } })
    t:note("dbg.text поставил надпись, dbg.count() = " .. tostring(dbg.count()))
    t:keep("dbs", id)

    local idx = dbg.indexOf(id)
    t:note("dbg.indexOf = " .. tostring(idx))
    t:note("повторный вызов с тем же id должен ПЕРЕЗАПИСАТЬ надпись, а не добавить вторую")
    local before = dbg.count()
    dbg.text(id, s.x, y, s.z, "AST: перезапись", { scale = 2 })
    t:eq(dbg.count(), before, "повторный dbg.text добавил вторую надпись вместо перезаписи")

    dbg.clear(id)
    H.forget("dbs", id)
    t:note(string.format("dbg.clear(id) выполнен, осталось надписей: %s", tostring(dbg.count())))
    t:need(not pcall(dbg.text, "", 0, 0, 0, "x"), "dbg.text принял пустой id")
    t:note("пустой id отклонён верно")
end })

H.case({ id = "visual.dbg.shapes", section = "visual", side = "client", fn = function(t)
    t:inGame("dbg shapes")
    local s = t:spot()
    local y = t:ground(s.x, s.z) + 5

    dbg.line("ast_ln", s.x, y, s.z, s.x + 40, y, s.z + 40, "red")
    dbg.box("ast_bx", s.x, y, s.z, 12, "green")
    dbg.sphere("ast_sp", s.x + 20, y, s.z + 20, 15, "blue")
    dbg.axis("ast_ax", s.x, y, s.z, 0, 1, 0, "yellow")
    t:note("линия/куб/сфера/ось нарисованы — их видно только у тебя")
    t:keep("shapes", "ast_ln"); t:keep("shapes", "ast_bx")
    t:keep("shapes", "ast_sp"); t:keep("shapes", "ast_ax")

    -- Цвет таблицей и безымянный (должен стать белым).
    dbg.line("ast_ln2", s.x, y, s.z, s.x + 20, y, s.z, { 1, 0.5, 0 })
    t:keep("shapes", "ast_ln2")
    dbg.line("ast_ln3", s.x, y, s.z, s.x + 20, y, s.z)
    t:keep("shapes", "ast_ln3")
    t:note("цвет строкой, таблицей и по умолчанию — все три приняты")

    local h = t:ownUnit()
    dbg.unitBox(h, "cyan")
    t:keep("shapes", "u" .. tostring(h))
    t:note("dbg.unitBox нарисован вокруг юнита " .. h)

    t:note("dbg.unit(h) = " .. dbg.unit(h))
    t:need(not pcall(dbg.line, "", 0, 0, 0, 1, 1, 1, "red"), "dbg.line принял пустое имя")

    for _, n in ipairs({ "ast_ln", "ast_bx", "ast_sp", "ast_ax", "ast_ln2", "ast_ln3" }) do
        pcall(dbg.clean, n)
    end
    t:note("dbg.clean по всем именам — фигуры убраны")
end })

H.case({ id = "visual.dbg.ray", section = "visual", side = "client", fn = function(t)
    t:inGame("dbg.ray")
    local s = t:spot()
    local y1 = t:ground(s.x, s.z) + 30
    local ground = t:ground(s.x, s.z)
    local hit, hx, hy, hz = dbg.ray(s.x, y1, s.z, s.x, y1 - 100, s.z)
    t:note(string.format("луч вниз: hit=%s точка (%.1f, %.2f, %.1f)", tostring(hit), hx or -1, hy or -1, hz or -1))
    t:eq(type(hit), "boolean", "dbg.ray вернул не boolean первым значением")
    -- ОСТОРОЖНО: на ПЛОСКОЙ земле (высота 0.00) RayCastTerrain не находит
    -- пересечения — луч не «попадает», потому что поверхности по сути нет.
    -- Проверяем только когда рельеф реально ненулевой.
    if math.abs(ground) > 0.5 then
        t:eq(hit, true, "луч вниз не попал в рельеф на высоте " .. string.format("%.2f", ground))
    else
        t:note(string.format("земля здесь плоская (%.2f) — RayCastTerrain не даёт пересечения,", ground))
        t:note("это ОСОБЕННОСТЬ натива, а не ошибка dbg.ray. Проверь на холме.")
    end

    -- Горизонтальный луч над землёй — промах.
    local hit2 = dbg.ray(s.x, y1, s.z, s.x + 500, y1, s.z)
    t:note(string.format("горизонтальный луч на высоте %.1f: hit=%s", y1, tostring(hit2)))
    t:eq(hit2, false, "горизонтальный луч над рельефом не должен попадать")
    t:note("высоты RayCastTerrain в этой игре различаются — проверь на своей карте")
end })

H.case({ id = "visual.sound", section = "visual", side = "client", fn = function(t)
    t:inGame("sound")
    local h = t:ownUnit()
    -- Имена библиотек берутся из data/sounds; перебираемKnown-кандидаты.
    local libs = { "explosion", "cannon", "gunshot", "musket", "click", "menu_click" }
    local got
    for _, lib in ipairs(libs) do
        local ok, s = pcall(sound.get, h, lib)
        if ok and s and s ~= 0 then
            got, t._lib = s, lib
            t:note(string.format("sound.get(h, '%s') = %s", lib, tostring(s)))
            break
        end
        t:note(string.format("sound.get(h, '%s'): %s", lib, tostring(s)))
    end
    if not got then
        t:skip("ни одна из " .. #libs .. " звуковых библиотек не принята движком — проверь имена в data/sounds")
    end
    t:keep("sounds", got)
    t:keep("soundTags", h)   -- sound.remove принимает тег излучателя, не id звука

    t:eq(sound.isPlaying(got), false, "новый звук не играет")
    sound.play(got)
    t:eq(sound.isPlaying(got), true, "sound.play включил звук")

    sound.volume(got, 0.4)
    t:note(string.format("volume = %s", tostring(sound.volume(got))))
    sound.frequency(got, 22050)
    t:note(string.format("frequency = %s", tostring(sound.frequency(got))))
    sound.radius(got, 3000)
    t:note(string.format("radius = %s", tostring(sound.radius(got))))
    sound.mute(got, true)
    t:note("mute(true) — должен быть тишина")
    sound.mute(got, false)

    sound.loop(got, true)
    t:note("loop(true)")
    sound.pause(got, true)
    t:note("pause(true)")
    sound.pause(got, false)
    sound.stop(got)
    t:eq(sound.isPlaying(got), false, "sound.stop остановил звук")

    -- Смена сэмпла и playAt/loopOn.
    local okSrc = pcall(sound.source, got, "explosion")
    t:note("sound.source: " .. tostring(okSrc))
    local s2 = sound.playAt(h, t._lib, { volume = 0.5, radius = 2000 })
    t:notNil(s2, "sound.playAt вернул nil")
    t:keep("sounds", s2)
    local s3 = sound.loopOn(h, t._lib, { volume = 0.2 })
    t:keep("sounds", s3)
    t:note("playAt/loopOn вернули " .. tostring(s2) .. " / " .. tostring(s3))

    sound.remove(h)
    t:note("sound.remove(h) — звук излучателя убран (remove принимает ТЕГ, не id звука)")
end })

H.case({ id = "visual.markers", section = "visual", side = "client", fn = function(t)
    t:inGame("markers")
    local s = t:spot()
    local id = markers.add({ x = s.x, z = s.z, icon = "attack", tag = 777, duration = 8 })
    t:notNil(id, "markers.add вернул nil")
    t:note("маркер " .. tostring(id) .. " на миникарте, tag=777")
    t:keep("markers", id)

    local rec = markers.get(id)
    t:need(type(rec) == "table", "markers.get вернул не запись")
    t:note(string.format("запись: x=%.1f z=%.1f mi=%s", rec.x, rec.z, tostring(rec.mi)))
    t:near(rec.x, s.x, 0.01, "markers.get вернул ту же координату X")

    -- Поиск по тегу на миникарте.
    t:note("minimap.findByTag(777) = " .. tostring(minimap.findByTag(777)))

    -- Второй маркер с подсветкой объекта и без срока жизни.
    local h = t:ownUnit()
    local id2 = markers.add({ x = s.x + 20, z = s.z + 20, icon = "defend", tag = 778,
        highlight = { handle = h, key = "ast_mk" } })
    t:note("маркер с подсветкой объекта: " .. tostring(id2))
    t:keep("markers", id2)

    -- Декаль на земле.
    local id3 = markers.add({ x = s.x, z = s.z + 30, decal = "mlscorch" })
    t:note("маркер с декалью: " .. tostring(id3))
    t:keep("markers", id3)

    t:eq(markers.get(999999), nil, "markers.get для несуществующего id вернул не nil")
    markers.remove(id2)
    H.forget("markers", id2)
    t:note("markers.remove(id2) — маркер с подсветкой убран")
    t:note("все маркеры с duration истекут сами за 8 с")
end })

H.case({ id = "visual.cutscene", section = "visual", side = "client", risky = true, fn = function(t)
    t:inGame("cutscene")
    t:eq(cutscene.playing(), false, "изначально катсцена не идёт")
    local s = t:spot()
    local h = t:ownUnit()
    cutscene.play({
        { x = s.x + 60, z = s.z + 60, time = 1.5 },
        { follow = h, time = 2 },
        { x = s.x, z = s.z, time = 1.5 },
    })
    t:eq(cutscene.playing(), true, "cutscene.play запустил сцену")
    t:note("сцена из 3 шагов: переезд -> слежение за юнитом -> возврат (5 с)")
    t:note("камера сейчас под управлением мода — не жми мышь, дождись конца")
    t:need(not pcall(cutscene.play, {}), "cutscene.play принял пустой список шагов")
    t:note("пустой список отклонён верно")
    t:need(not pcall(cutscene.play, { { time = 1 } }), "cutscene.play принял шаг без x/z и follow")
    t:note("шаг без цели отклонён верно")
    t:note("пропуск: пробел или F8 позже; cutscene.stop() в очистке")
end })

H.case({ id = "visual.camera", section = "visual", side = "client", risky = true, fn = function(t)
    t:inGame("camera")
    local x, y, z = camera.pos()
    t:need(type(x) == "number", "camera.pos вернул не координаты")
    t:note(string.format("камера: (%.1f, %.1f, %.1f)", x, y, z))
    local gx, _, gz = camera.gamePos()
    t:note(string.format("точка под камерой: (%.1f, %.1f)", gx or -1, gz or -1))
    t:note("текущий слеженый объект: " .. tostring(camera.followed()))
    t:note("camera.target() = " .. tostring(camera.target()))

    -- Треки камеры (кинематографические пути). AddCameraTrack возвращает индекс 1-based.
    local cnt = camera.trackCount()
    t:note("треков камеры в сцене: " .. tostring(cnt))
    local added = camera.trackAdd()
    t:notNil(added, "camera.trackAdd вернул nil")
    t:note(string.format("добавлен трек #%s, теперь их %s", tostring(added), tostring(camera.trackCount())))
    t:note("camera.trackName(#" .. tostring(added) .. ") = " .. tostring(camera.trackName(added)))
    local okPoint = pcall(camera.trackPoint, "ast_pt", gx, t:ground(gx, gz) + 40, gz, gx + 40, 0, gz)
    t:note("camera.trackPoint: " .. tostring(okPoint))
    local ok = pcall(camera.trackPlay, added)
    t:note("camera.trackPlay: " .. tostring(ok) .. ", trackCurrent = " .. tostring(camera.trackCurrent()))
    -- ВАЖНО: trackPlay включает кинематографию — если не вернуть, камера остаётся
    -- «в режиме» и управление не возвращается игроку. Гасим сразу.
    pcall(camera.stop)
    pcall(camera.trackPlay, 0)
    t:note("камера остановлена и переведена на трек 0 — управление возвращено")

    -- Сдвиг: position принимает ИМЕННО (x, z), третьего аргумента нет.
    camera.moveTo(gx + 40, gz + 40, 8)
    t:note(string.format("camera.moveTo(%.0f, %.0f, speed=8) — смотри, камера поехала", gx + 40, gz + 40))
    t:note("возврат камеры делает F11 (H.restoreWorld) — не жди конца кейса")

    t:defer(function(c)
        local bx, _, bz = camera.gamePos()
        c:note(string.format("через 1.5 с камера в (%.1f, %.1f), было (%.1f, %.1f)",
            bx or -1, bz or -1, gx or -1, gz or -1))
        c:note("если камера не вернулась и руками не управляется — жми F11")
        c:eq(game.isInGame(), true, "партия жива")
    end, 1.5, "камера")
end })

H.case({ id = "visual.minimap", section = "visual", side = "client", fn = function(t)
    t:inGame("minimap")
    local was = minimap.isVisible()
    local zoom0 = minimap.getZoom()
    t:note("миникарта видна = " .. tostring(was) .. ", зум = " .. tostring(zoom0))

    -- ВАЖНО: zoom/frustum мы МЕНЯЕМ, значит обязаны вернуть как было, даже если
    -- ниже что-то упадёт. Поэтому откат — в defer, а не в конце кейса.
    t:defer(function(c)
        minimap.zoom(zoom0)
        minimap.show(was)
        c:note("зум и видимость миникарты возвращены (было " .. tostring(zoom0) .. ")")
    end, 0.5, "откат миникарты")

    minimap.show(false)
    t:eq(minimap.isVisible(), false, "minimap.show(false)")
    minimap.show(true)
    t:eq(minimap.isVisible(), true, "minimap.show(true)")

    minimap.zoom(2)
    t:note(string.format("minimap.zoom(2) -> %s (было %s)", tostring(minimap.getZoom()), tostring(zoom0)))
    minimap.update()
    t:note("minimap.update() — текстура пересчитана")

    -- Свои иконки: положить по курсору.
    local s = t:spot()
    local i = minimap.put("attack", s.x, s.z, { tag = 999, visible = true })
    t:note("minimap.put -> " .. tostring(i) .. ", всего иконок " .. tostring(minimap.count()))
    minimap.setTag(i, 999)
    minimap.setName(i, "AST")
    minimap.setBlink(i, 0.5, 3)
    t:note("setTag/setName/setBlink отработали")
    t:eq(minimap.findByTag(999), i, "findByTag нашёл свою иконку")
    minimap.setVisible(i, false)
    t:eq(minimap.isVisibleAt(i), false, "setVisible(false)")
    minimap.setVisible(i, true)
    minimap.remove(i)
    t:note("minimap.remove(i) — иконка убрана")

    -- Чужие слоты иконок (штатные стрелки игроков).
    local n = minimap.count()
    t:note("после remove осталось иконок: " .. tostring(n))
    -- minimap.frustum -> SetMiniMapFrustumVisible, а он меняет игру => только server/shared.
    -- На клиенте это ошибка по контракту, а не повод ронять кейс.
    local okFr, frErr = pcall(minimap.frustum, true)
    t:note("minimap.frustum(true): ok=" .. tostring(okFr) ..
        (okFr and " — обрезка по камере включена, возвращаю" or
            (" err=" .. tostring(frErr):sub(1, 70))))
    if okFr then
        minimap.frustum(false)
        t:note("minimap.frustum(false) — обрезка выключена")
    else
        t:note("ОГРАНИЧЕНИЕ API: minimap.frustum только server/shared (SetMiniMapFrustumVisible)")
    end
end })

H.case({ id = "visual.gui", section = "visual", side = "client", fn = function(t)
    -- модуль может быть не загружен при битой копии api
    t:mod("gui")
    t:mod("panel")
    -- gui работает только из client.lua с ui — проверяем link и создание элементов.
    gui.link(ui)
    panel.link(ui)
    t:note("gui.link(ui) и panel.link(ui) выполнены")

    local p = gui.create("panel", { name = "ast_gui_panel", x = 60, y = 60, w = 260, h = 120 })
    t:notNil(p, "gui.create('panel') вернул nil")
    local lbl = gui.create("label", { parent = p, text = "AST: элементы интерфейса", x = 8, y = 8,
        w = 240, h = 20 })
    local btn = gui.create("button", { parent = p, text = "Нажми меня", x = 8, y = 40, w = 120, h = 0,
        onClick = function() t:note("кнопка gui нажата") end })
    t:note(string.format("созданы: panel=%s label=%s button=%s", tostring(p), tostring(lbl), tostring(btn)))

    -- position/where/text/show.
    gui.position(lbl, 12, 12)
    local lx, ly = gui.where(lbl)
    t:near(lx, 12, 1, "gui.where вернул x")
    t:near(ly, 12, 1, "gui.where вернул y")
    gui.text(lbl, "AST: текст изменён")
    t:eq(gui.text(lbl), "AST: текст изменён", "gui.text прочитал то, что записал")
    gui.show(p, false)
    t:note("gui.show(p, false) — панель скрыта")
    gui.show(p, true)
    t:note("gui.show(p, true) — панель снова видна")

    -- image требует материал.
    t:need(not pcall(gui.create, "image", { name = "x" }), "gui.create('image') без material прошёл")
    t:note("image без material отклонён верно")
    local okImg = pcall(gui.create, "image", { parent = p, material = "logo_small", x = 140, y = 40,
        w = 60, h = 60 })
    t:note("image с материалом logo_small: " .. tostring(okImg))
    t:need(not pcall(gui.create, "нет_такого_kind"), "gui.create принял неизвестный kind")
    t:note("неизвестный kind отклонён верно")

    -- onClick отдельно (для существующей кнопки).
    gui.onClick(btn, function() t:note("gui.onClick сработал") end)

    -- find родного элемента игры: ищем что-то заведомо существующее на HUD.
    local found = gui.find("gc_hud")
    t:note("gui.find('gc_hud') = " .. tostring(found))

    for _, hnd in ipairs({ btn, lbl, p }) do pcall(gui.remove, hnd) end
    t:note("все элементы gui.remove удалены")
end })

H.case({ id = "visual.panel", section = "visual", side = "client", fn = function(t)
    panel.link(ui)
    local p = panel.new({ name = "ast_panel", title = "AST: панель", x = 80, y = 80, w = 300 })
    t:notNil(p, "panel.new вернул nil")
    t:eq(panel.get("ast_panel"), p, "panel.get вернул ту же панель")
    t:eq(panel.get("нет_такой"), nil, "panel.get для несуществующей вернул не nil")

    local l1 = p:label("метка 1")
    local b1 = p:button("кнопка 1", function() t:note("кнопка панели нажата") end)
    t:notNil(l1, "p:label вернул nil")
    t:notNil(b1, "p:button вернул nil")

    p:visible(false)
    t:note("p:visible(false) — панель скрыта (кнопки не должны кликаться)")
    p:visible(true)
    t:note("p:visible(true) — панель видна, нажми «кнопка 1»")
    t:need(not pcall(function() p:button("x", "не функция") end),
        "p:button принял не-функцию")
    t:note("p:button с не-функцией отклонён верно")

    p:close()
    t:eq(panel.get("ast_panel"), nil, "после p:close панели в реестре нет")
    t:note("panel.clear() на пустом наборе — должен быть безопасен")
    panel.clear()
end })

H.case({ id = "visual.effects", section = "visual", side = "client", fn = function(t)
    t:inGame("effects")
    local h = t:ownUnit()
    local s = t:spot()
    -- PFX: имена менеджеров из data/effects, подбираем перебором.
    local made = false
    for _, mgr in ipairs({ "fire", "smoke", "explosion", "damage", "default" }) do
        local ok, pfx = pcall(effects.pfx, h, mgr, "ast_fx")
        if ok and pfx then
            t:note(string.format("effects.pfx(h, '%s', 'ast_fx') создан", mgr))
            t:keep("pfx", h, mgr, "ast_fx")
            made = true
            break
        end
    end
    t:note("подходящий менеджер PFX найден: " .. tostring(made))
    if made then
        local isPfx = effects.isPfx(h, "fire", "ast_fx")
        t:note("effects.isPfx после создания: " .. tostring(isPfx))
        pcall(effects.setLifetime, h, "fire", "ast_fx", 3)
        pcall(effects.setScale, h, "fire", "ast_fx", 2, 2, 2)
        pcall(effects.setEffectScale, h, "fire", "ast_fx", 1.5)
        pcall(effects.setVelocity, h, "fire", "ast_fx", 0, 3, 0)
        pcall(effects.setEnabled, h, "fire", "ast_fx", true)
        t:note("setLifetime/setScale/setEffectScale/setVelocity/setEnabled — без ошибок")
        pcall(effects.deletePfx, h, "fire", "ast_fx")
        t:note("PFX удалён")
    end

    -- Взрывы/кольца/огонь — по id эффекта из data/effects.
    -- Подписи: burst(id,time,count) / ring(id,time,minSpeed,maxSpeed,count) /
    -- fire(id,minSpeed,maxSpeed,lifeBoost,count). count обязан быть ЦЕЛЫМ.
    local effCalls = {
        { "burst", 1, 0.5, 2 },
        { "ring", 1, 0.5, 2, 3, 12 },
        { "fire", 1, 2, 3, 0, 12 },
    }
    for _, c in ipairs(effCalls) do
        local fn = table.remove(c, 1)
        local ok, err = pcall(effects[fn], table.unpack(c))
        t:note(string.format("effects.%s(%d арг.): ok=%s%s", fn, #c, tostring(ok),
            ok and "" or (" (" .. tostring(err):sub(1, 50) .. ")")))
        t:need(ok, "effects." .. fn .. " отклонил корректный вызов: " .. tostring(err):sub(1, 60))
    end
    t:note("create/clear объекта:")
    local okCreate = pcall(effects.create, h, "ast_class", "ast_key", false)
    t:note("effects.create(h, 'ast_class', 'ast_key'): " .. tostring(okCreate))
    pcall(effects.clearPfx, h)
    pcall(effects.clear, h)
    t:note("все эффекты с объекта сняты")
    t:need(not pcall(effects.highlight, h, "", true, ""), "effects.highlight принял пустой key")
    t:note("effects.highlight с пустым key отклонён верно")
end })

H.case({ id = "visual.model", section = "visual", side = "client", fn = function(t)
    t:inGame("model/animation")
    local h = t:ownUnit()
    local info = animation.info(h)
    t:note("animation.info = " .. tostring(info))
    t:note("циклов анимации: " .. tostring(animation.cycleFrames and "есть" or "нет"))

    -- Список циклов, доступных модели: без него нельзя выбрать имя для play.
    local list = model.getCyclesList(h)
    if type(list) == "table" then
        local n = #list
        t:note("циклов в модели юнита: " .. n)
        if n > 0 then
            t:note("примеры: " .. tostring(list[1]) .. ", " .. tostring(list[2]))
            local ok = pcall(animation.play, h, tostring(list[1]))
            t:note("animation.play(h, '" .. tostring(list[1]) .. "'): " .. tostring(ok))
        else
            t:skip("модель юнита не отдала список циклов")
        end
    else
        t:skip("model.getCyclesList недоступна для этого юнита")
    end

    -- show/scale/rotate — обратимы, обязаны восстанавливаться.
    pcall(model.show, h, false)
    t:note("model.show(h, false) — юнит скрыт")
    pcall(model.show, h, true)
    t:note("model.show(h, true) — юнит виден")
    local okScale = pcall(model.scale, h, 1.5, 1.5, 1.5)
    t:note("model.scale(1.5): " .. tostring(okScale))
    pcall(model.scale, h, 1, 1, 1)
    t:note("масштаб возвращён к 1")
    local s = t:spot()
    local okPoint = pcall(model.pointTo, h, s.x + 50, t:ground(s.x + 50, s.z) , s.z, 0, 1, 0)
    t:note("model.pointTo: " .. tostring(okPoint))
    t:note("model.rotate(h, 0, 1.5, 0) — разворот")
    pcall(model.rotate, h, 0, 0, 0)
end })

H.case({ id = "visual.snapshot", section = "visual", side = "client", fn = function(t)
    t:inGame("snapshot")
    -- Безымянный вариант зовёт native.CreateSnapShot — он МЕНЯЕТ ИГРУ и доступен
    -- только server/shared, поэтому с клиента падает. Это задокументированное
    -- ограничение, а не баг: снимаем снимок именованным вариантом с client нельзя
    -- (CreateSnapShotExt тоже серверный), поэтому здесь только проверяем контракт.
    local ok, err = pcall(scenario.snapshot)
    t:note("scenario.snapshot() без имени с client: ok=" .. tostring(ok) ..
        (ok and (" -> " .. tostring(err)) or (" err=" .. tostring(err):sub(1, 80))))
    t:note("безымянный снимок — только server/shared; именованный ( ast_snapshot.png )")
    t:note("тоже только server/shared. На клиенте снимок экрана недоступен.")
    t:need(not ok, "безымянный scenario.snapshot неожиданно сработал с client")
end })

-- Приём диалогов scenario: без scenario.present() клиент шумит
-- "net message 'scenario.dialog' has no client handler".
-- Линк сценария ОБЯЗАН выполняться на загрузке клиента, а не в обработчике
-- ast.run: клиент этот ивент ОТПРАВЛЯЕТ серверу, но сам себе не доставляет,
-- поэтому код внутри обработчика не запускался НИКОГДА — отсюда и была
-- ошибка "net message 'scenario.dialog' has no client handler".
if scenario and scenario.present and not scenario._astLinked then
    local okS, errS = pcall(function()
        scenario.link({ on = net.on })
        scenario.present()
        scenario._astLinked = true
    end)
    if okS then
        log.info("[AST] scenario.present подключён на загрузке клиента - диалоги сценария не потеряются")
    else
        log.warn("[AST] scenario.present не подключился: " .. tostring(errS))
    end
end

-- steam.status() возвращает СТРОКУ, playedWith(id) — СЕТТЕР (нужен SteamID64),
-- троттлинг setMatch — 3 секунды. Это и есть главное, что тут надо проверить.
H.case({ id = "steam.presence", section = "steam", side = "client", fn = function(t)
    if not steam then t:skip("таблицы steam нет в этом окружении") end
    local avail = steam.available()
    t:note("steam.available() = " .. tostring(avail) .. " -> status = " .. tostring(steam.status()))
    if not avail then
        t:note("мост Steam недоступен (ISteamFriends не найден) — setMatch вернёт false,")
        t:note("это ожидаемо. Проверяем только то, что заглушки не падают.")
    end

    -- setMatch: true (ок), либо true,"unchanged", либо false,"throttled".
    local r1, why1 = steam.setMatch({ status = "Стенд API", map = "ast", mode = "test" })
    t:note(string.format("setMatch: %s (%s)", tostring(r1), tostring(why1)))
    if avail then
        t:eq(r1, true, "setMatch не отправил статус (" .. tostring(why1) .. ")")
        t:note("повтор с тем же статусом обязан дать true + 'unchanged':")
        local r1b, why1b = steam.setMatch({ status = "Стенд API", map = "ast", mode = "test" })
        t:note(string.format("  повтор: %s (%s)", tostring(r1b), tostring(why1b)))
        t:eq(why1b, "unchanged", "повторный setMatch должен вернуть 'unchanged'")
    else
        t:need(r1 == false or r1 == nil,
            "setMatch сообщил об успехе, хотя available() = false")
    end

    local r2, why2 = steam.setOpponent("AST_Sparring")
    t:note(string.format("setOpponent: %s (%s)", tostring(r2), tostring(why2)))
    t:note("троттлинг 3 с: сразу после setMatch expect false + 'throttled'")

    local r3 = steam.clearOpponent()
    t:note("clearOpponent: " .. tostring(r3) .. " (пишет пустого соперника напрямую)")

    -- Негативные ветки работают всегда, независимо от Steam.
    t:need(not pcall(steam.setMatch, "не таблица"), "steam.setMatch принял не таблицу")
    t:need(not pcall(steam.setOpponent, ""), "steam.setOpponent принял пустое имя")
    t:need(not pcall(steam.setOpponent, { name = "x" }), "steam.setOpponent принял таблицу")
    t:note("все три негативные ветки отклонены верно")

    t:note("steam.clear(): " .. tostring(steam.clear()))
    t:note("проверь в Steam: РП должен показать «Стенд API» (если у Cossacks 3")
    t:note("включено отображение в настройках приложения Steamworks)")
end })

H.case({ id = "steam.played", section = "steam", side = "client", fn = function(t)
    if not steam then t:skip("таблицы steam нет в этом окружении") end
    local myId = steam.myId()
    t:note("steam.myId() = " .. tostring(myId) .. " (nil — Steam не запущен)")

    -- playedWith — СЕТТЕР: принимает SteamID64, а не возвращает список.
    t:need(not pcall(steam.playedWith, "не число"), "steam.playedWith принял не SteamID64")
    t:note("playedWith с мусором отклонён верно (native бросает ошибку)")
    t:need(not pcall(steam.playedWith), "steam.playedWith без аргумента не ругается")
    t:note("playedWith без аргумента отклонён верно (luaL_checkstring)")

    if type(myId) == "string" and #myId > 0 then
        local ok = pcall(steam.playedWith, myId)
        t:note("playedWith(свой SteamID) вернул без ошибки: " .. tostring(ok))
        t:note("теперь ты в списке «играл с» у самого себя — Steam это примет")
    else
        t:skip("SteamID недоступен, реальный playedWith проверить нельзя")
    end
end })

H.case({ id = "net.local", section = "net", side = "client", fn = function(t)
    -- ВАЖНО: net.send с клиента уходит ХОСТУ (сторона 's'), а не обратно клиенту.
    -- Поэтому проверяем канал так: клиент шлёт, хост ловит, хост шлёт обратно,
    -- клиент получает. В одиночной игре оба перехода локальные.
    local gotBack
    net.on("ast.pong", function(data) gotBack = data end)
    local n = (t._pingSeq or 0) + 1
    t._pingSeq = n
    local ok, err = pcall(net.send, "ast.ping", { n = n, s = "ping" })
    t:need(ok, "net.send не удался: " .. tostring(err))
    t:note("net.send('ast.ping') отправлен хосту (from=" .. tostring(game.mode()) .. ")")
    t:note("game.mode() = " .. tostring(game.mode()))
    t:defer(function(c)
        c:note("ответ хоста ast.pong: " .. tostring(gotBack and gotBack.s or "не пришёл"))
        c:need(gotBack ~= nil, "хост не ответил на ast.ping — канал client->server->client не работает")
        if gotBack then c:eq(gotBack.n, n, "ответ пришёл с тем же номером") end
    end, 0.3, "ping-pong")
end })

-- ===========================================================================
-- ПРИЁМ РЕЗУЛЬТАТОВ ОТ SHARED-СТОРОНЫ
-- ===========================================================================

-- ВНИМАНИЕ, Lua: функции ниже вызывают друг друга (net-обработчики зовут refreshStatus,
-- кнопки панели зовут requestRun/doReport). Все они объявлены ЗАРАНЕЕ одним блоком:
-- если объявить `local function f` ПОСЛЕ замыкания, которое её использует, замыкание
-- поймает глобальное имя (nil) и упадёт на "attempt to call a nil value".
local refreshStatus, pushToPage, openPage, doReport, requestRun, confirmRisky

local sharedRows = {} -- строки, пришедшие от shared-стороны

net.on("ast.results", function(data)
    if type(data) ~= "table" or type(data.rows) ~= "table" then return end
    for _, r in ipairs(data.rows) do
        r.side = "shared"
        sharedRows[#sharedRows + 1] = r
    end
    if data.last then
        log.info(string.format("[AST] получено строк от shared: %d (всего в отчёте %d)",
            #data.rows, #sharedRows))
    end
end)

net.on("ast.done", function(data)
    if type(data) ~= "table" then return end
    if data.side == "shared" then
        log.info(string.format("[AST] shared закончил: %s — ok %s, fail %s, error %s, skip %s (%s мс)",
            tostring(data.section), tostring(data.ok), tostring(data.fail), tostring(data.error),
            tostring(data.skip), tostring(data.ms)))
    end
    refreshStatus()
    pushToPage()
end)

-- ===========================================================================
-- ОТЧЁТ В CEF (страница только читает — кнопки там не нужны, они в панели)
-- ===========================================================================

local pageOpen = false

local function jsonEscape(s)
    s = tostring(s or "")
    s = s:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n"):gsub("\r", "")
    s = s:gsub("[%z\1-\31]", function(c) return string.format("\\u%04x", c:byte()) end)
    return s
end

-- Отчёт -> одна большая строка, страница сама разбирает по строкам.
local function reportText(verbose)
    local own = H.report(nil, verbose)
    local parts = { "[AST]" .. jsonEscape(own) }
    if #sharedRows > 0 then
        local c = { ok = 0, fail = 0, error = 0, skip = 0 }
        local lines = {}
        for _, r in ipairs(sharedRows) do
            if c[r.status] then c[r.status] = c[r.status] + 1 end
            if verbose or r.status ~= "ok" then
                lines[#lines + 1] = string.format("   %s %-28s %-4s %s", r.status == "ok" and "+" or
                    (r.status == "skip" and "-" or "x"), r.id, r.side, r.msg)
            end
        end
        parts[#parts + 1] = "[AST]" .. jsonEscape(table.concat({
            "=== РЕЗУЛЬТАТЫ SHARED-СТОРОНЫ ===",
            string.format("строк: %d | ok %d | fail %d | error %d | skip %d",
                #sharedRows, c.ok, c.fail, c.error, c.skip),
            table.concat(lines, "\n"),
        }, "\n"))
    end
    return table.concat(parts, "\n")
end

pushToPage = function()
    if not pageOpen then return end
    local text = reportText(true)
    -- Страница получает JSON-строку в window.AST_set.
    pcall(web.eval, 'window.AST_set && window.AST_set("' .. jsonEscape(text) .. '")')
end

openPage = function()
    if not game.isInGame() then
        log.warn("AST: страница отчёта открывается только в партии (нужен gamestage >= 2)")
        return
    end
    if state.get("gMap.gamestage") < 2 then
        log.warn("AST: партия ещё загружается, страница откроется позже")
        return
    end
    web.open("report")
    web.passthrough(false)   -- страница не HUD: мышь и клавиатура у неё
    pageOpen = true
    pushToPage()
    log.info("AST: страница отчёта открыта (F4 — закрыть/открыть)")
end

-- ===========================================================================
-- ПАНЕЛЬ УПРАВЛЕНИЯ (родной интерфейс игры)
-- ===========================================================================

local statusText, headText
local root = nil
local pendingRisky = nil

local function setStatus(s)
    if not statusText then return end
    pcall(ui.setText, statusText, s)
end

local function togglePanel()
    if root then
        pcall(panel.clear)
        root = nil
        statusText, headText = nil, nil
        log.info("AST: панель закрыта")
        return
    end
    panel.link(ui)
    gui.link(ui)
    root = panel.new({ name = "ast_root", title = "API STRESS TEST 0.2.0", x = 16, y = 16, w = 330 })
    headText = root:label("раздел: " .. tostring(current))
    root:label("F6 — раздел   F7 — все   F8 — опасные   F11 — очистка")
    root:label("Ctrl+F7 — всё   F10 — отчёт   F4 — страница")

    for _, s in ipairs(H.SECTIONS) do
        root:button(s.title, function()
            current = s.id
            if headText then pcall(ui.setText, headText, "раздел: " .. s.id) end
            setStatus("выбран раздел " .. s.id .. " — жми F6")
        end)
    end

    root:label("---")
    root:button("Прогнать раздел (F6)", function() requestRun(current, false) end)
    root:button("Прогнать ВСЁ безопасно (F7)", function() requestRun("all", false) end)
    root:button("Опасные кейсы раздела (F8)", function() confirmRisky(current) end)
    root:button("ВСЁ включая опасные (Ctrl+F7)", function() requestRun("all", true) end)
    root:label("---")
    root:button("Отчёт в лог (F10)", function() doReport(false) end)
    root:button("Подробный отчёт (Ctrl+F10)", function() doReport(true) end)
    root:button("Страница отчёта (F4)", function()
        if pageOpen then
            pcall(web.close)
            pageOpen = false
            setStatus("страница закрыта")
        else
            openPage()
        end
    end)
    root:label("---")
    root:button("Очистить мусор (F11)", function()
        local n = H.cleanup(game.isInGame())
        setStatus("очищено шагов: " .. tostring(n))
        log.info("[AST] очистка: " .. tostring(n) .. " шагов")
    end)
    root:button("Сбросить отчёт (Ctrl+F11)", function()
        H.reset()
        sharedRows = {}
        setStatus("отчёт сброшен")
        pushToPage()
    end)
    root:label("---")
    statusText = root:label("готов")
    setStatus(H.summaryLine())
    log.info("AST: панель открыта")
end

-- Отправляем запрос shared-стороне и параллельно гоним свои client-кейсы.
requestRun = function(section, risky)
    if not game.isInGame() then
        setStatus("нет партии — сначала начни игру")
        log.warn("AST: прогон только в активной партии")
        return
    end
    sharedRows = {}
    H.reset()
    setStatus("прогон '" .. tostring(section) .. "'..." .. (risky and " (включая опасные)" or ""))

    -- Своя сторона — сразу, синхронно (кейсы клиента быстрые и рисуют только у нас).
    local res, err = H.run(section, { risky = risky })
    if not res then
        setStatus(tostring(err))
    else
        log.info(string.format("[AST] client: ok %d, fail %d, error %d, skip %d (%d мс)",
            res.counts.ok, res.counts.fail, res.counts.error, res.counts.skip, res.ms))
    end

    -- Shared-сторона — запросом по сети (в одиночке доставится локально).
    local ok, errSend = pcall(net.send, "ast.run", { section = section, risky = risky })
    if not ok then
        setStatus("shared-сторона недоступна: " .. tostring(errSend))
        log.warn("AST: net.send не удался: " .. tostring(errSend))
    end

    setStatus(H.summaryLine() .. " (ждём shared)")
    pushToPage()
end

-- Опасный прогон требует второго нажатия: случайно F8 не должен испортить партию.
confirmRisky = function(section)
    if pendingRisky ~= section then
        pendingRisky = section
        setStatus("ТОЧНО ЖЕ: ещё раз нажми F8, чтобы пустить опасные кейсы")
        log.warn("[AST] опасные кейсы требуют подтверждения (повторное нажатие)")
        return
    end
    pendingRisky = nil
    requestRun(section, true)
end

doReport = function(verbose)
    local text = reportText(verbose)
    log.info("[AST] ===== ОТЧЁТ " .. (verbose and "(подробный)" or "(краткий)") .. " =====")
    for line in text:gmatch("[^\n]+") do log.info(line) end
    log.info("[AST] ===== конец отчёта =====")
    setStatus("отчёт в лог (" .. #H.results .. " строк)")
    pushToPage()
end

refreshStatus = function()
    if statusText then
        local extra = (#sharedRows > 0) and ("  +shared " .. tostring(#sharedRows)) or ""
        setStatus(H.summaryLine() .. extra)
    end
end

-- ===========================================================================
-- КЛАВИШИ И ЖИЗНЕННЫЙ ЦИКЛ
-- ===========================================================================

-- Переключение раздела стрелками. Раньше раздел менялся ТОЛЬКО кнопкой в панели
-- (F5), и F6 всегда гонял env — об этом спотыкались. Ctrl+Left/Ctrl+Right листают.
local function stepSection(dir)
    local idx = 1
    for i, s in ipairs(H.SECTIONS) do if s.id == current then idx = i break end end
    local nextIdx = ((idx - 1 + dir) % #H.SECTIONS) + 1
    current = H.SECTIONS[nextIdx].id
    if headText then pcall(ui.setText, headText, "раздел: " .. current) end
    setStatus("раздел: " .. current .. "  (" .. H.SECTIONS[nextIdx].title .. ") — жми F6")
    log.info("[AST] раздел: " .. current)
end
input.bind("Ctrl+Left", function() stepSection(-1) end)
input.bind("Ctrl+Right", function() stepSection(1) end)

input.bind("F5", togglePanel)
input.bind("F4", function()
    if pageOpen then pcall(web.close); pageOpen = false; setStatus("страница закрыта")
    else openPage() end
end)
input.bind("F6", function()
    -- Пишем раздел ДО запуска: по логу должно быть видно, что именно запустилось.
    log.info("[AST] F6 -> раздел '" .. tostring(current) .. "' (" ..
        tostring(H.SECTION_TITLE[current]) .. ")")
    requestRun(current, false)
end)
input.bind("Ctrl+F6", function() requestRun(current, true) end)
input.bind("F7", function() requestRun("all", false) end)
input.bind("Ctrl+F7", function() requestRun("all", true) end)
input.bind("F8", function() confirmRisky(current) end)
input.bind("F10", function() doReport(false) end)
input.bind("Ctrl+F10", function() doReport(true) end)
input.bind("F11", function()
    local n = H.cleanup(game.isInGame())
    log.info("[AST] очистка: " .. tostring(n) .. " шагов")
    setStatus("очищено шагов: " .. tostring(n))
end)
input.bind("Ctrl+F11", function()
    H.reset(); sharedRows = {}
    setStatus("отчёт сброшен"); pushToPage()
end)

-- Раз в секунду освежаем панель и страницу, чтобы видеть ход прогона.
local lastRefresh = 0
events.on("game.tick", function()
    local now = os.clock()
    if now - lastRefresh < 1 then return end
    lastRefresh = now
    refreshStatus()
    if pageOpen then pushToPage() end
end)

events.on("game.start", function()
    -- Элементы интерфейса живут до game.end — на каждом game.start пересоздаём.
    root = nil
    statusText, headText = nil, nil
    pendingRisky = nil
    sharedRows = {}
    H.reset()
    log.info(string.format("[AST] client готов. Кейсов на client-стороне: %d. F5 — панель.",
        #H.myCases("all")))
end)

events.on("game.end", function()
    pcall(panel.clear)
    pcall(web.close)
    root, statusText, headText, pageOpen = nil, nil, nil, false
    sharedRows = {}
    H.reset()
    -- Остатки эффектов/надписей клиента снимаем (мир уже не нужен).
    pcall(H.cleanup, false)
end)

-- Отчёт по клиенту при выходе — чтобы ничего не потерялось.
events.on("game.menu", function()
    if #H.results > 0 then
        log.info("[AST] последний отчёт клиента: " .. H.summaryLine())
    end
end)

return H
