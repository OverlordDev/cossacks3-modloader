-- harness.lua — каркас стенда: регистрация кейсов, запуск, отчёт, очистка.
--
-- Грузится в ОКРУЖЕНИЕ МОДА через require("harness") (в manifest files). Один и тот же
-- файл попадает и в client-окружение, и в server/shared — поэтому здесь нет ничего
-- сторонне-специфичного: кейсыregister'ятся в shared.lua и client.lua, а запуск
-- на своей стороне инициируется автоматически.
--
-- Кейс: harness.case{ id, section, risky, fn }
--   fn(t) -> строка-подробность (успех)  |  t.skip(причина)  |  ошибка (провал)
--   t: need(cond, msg) / fail(msg) / eq(a, b, что) / note(msg)
--   t: me() / ownUnit() / foeUnit() / ownBuilding() / spot() / isBuilding(h)
--   t: keep(kind, value) — зарегистрировать объект для очистки (F11)
--
-- ВАЖНО ДЛЯ LOCKSTEP: всё, что меняет мир, итерируется только через ipairs/отсортированные
-- списки. pairs() по хешу даёт разный порядок на разных машинах — это рассинхрон.
--
-- Каждый кейс пишет в лог [AST] START/END. Если игра упала — по последней строке START
-- сразу видно, какой кейс её убил.

local H = {}

H.VERSION = "0.2.0"

-- ---------------------------------------------------------------------------
-- Разделы (порядок = порядок кнопок в панели)
-- ---------------------------------------------------------------------------

H.SECTIONS = {
    { id = "env",     title = "1. Окружение, права, нативы" },
    { id = "util",    title = "2. Библиотеки-утилиты" },
    { id = "read",    title = "3. Чтение мира" },
    { id = "world",   title = "4. Мир, рельеф, поведения" },
    { id = "combat",  title = "5. Приказы, отряды, статусы, ИИ" },
    { id = "fow",     title = "6. Туман войны" },
    { id = "flow",    title = "7. Время, сценарии, экономика, реплей" },
    { id = "net",     title = "8. Сеть, детектор рассинхрона" },
    { id = "visual",  title = "9. Картинка, звук, интерфейс" },
    { id = "steam",   title = "10. Steam Presence" },
}

H.SECTION_TITLE = {}
for _, s in ipairs(H.SECTIONS) do H.SECTION_TITLE[s.id] = s.title end

-- ---------------------------------------------------------------------------
-- Регистрация кейсов
-- ---------------------------------------------------------------------------

-- side: "client" | "shared" | "both" (кейс годен обеим сторонам).
H.cases = {}

-- side определяется по наличию game.exec в текущем окружении, если не указан явно:
-- в api нет способа узнать сторону надёжнее, чем наличие game.exec.
local function autoSide()
    if game and game.exec then return "shared" end
    return "client"
end

function H.case(spec)
    assert(type(spec) == "table", "harness.case: spec must be a table")
    assert(type(spec.id) == "string" and spec.id ~= "", "harness.case: spec.id required")
    assert(type(spec.fn) == "function", "harness.case: spec.fn required for " .. tostring(spec.id))
    spec.section = spec.section or "env"
    spec.risky = spec.risky == true
    spec.side = spec.side or autoSide()
    spec.here = autoSide()          -- где кейс реально выполняется
    H.cases[#H.cases + 1] = spec
    return spec
end

-- Кейсы этой стороны (для отчёта и кнопок).
function H.myCases(section)
    local out = {}
    for _, c in ipairs(H.cases) do
        if c.here == autoSide() and (section == nil or section == "all" or c.section == section) then
            out[#out + 1] = c
        end
    end
    return out
end

-- Все зарегистрированные кейсы указанной стороны — для проверки покрытия.
function H.allCases(side)
    local out = {}
    for _, c in ipairs(H.cases) do
        if c.side == side or c.side == "both" then out[#out + 1] = c end
    end
    return out
end

-- ---------------------------------------------------------------------------
-- Мусор, который нужно убрать (F11 / автоочистка)
-- ---------------------------------------------------------------------------

H.trash = {
    objects = {},     -- хендлы, удалить world.destroyNow
    groups = {},      -- хендлы групп, group.destroy
    regions = {},     -- имена зон, regions.remove
    trackGroups = {}, -- имена сетей, tracks.clear
    dbs = {},         -- id надписей dbg, dbg.clear
    shapes = {},      -- имена фигур dbg, dbg.clean
    markers = {},     -- id маркеров, markers.remove
    decals = {},      -- id декалей, decals.remove
    sounds = {},      -- id звуков, sound.stop
    soundTags = {},   -- хендлы ИЗЛУЧАТЕЛЕЙ, sound.remove(tag) — это не то же, что id звука
    brains = {},      -- хендлы с ai.attach, ai.detach
    statuses = {},    -- { h, name }, status.remove
    follows = {},     -- хендлы с attach.follow, attach.unfollow
    behaviours = {},  -- id поведений, behaviour.destroy
    pfx = {},         -- { h, manager, key }, effects.deletePfx
}

local function push(list, v)
    list[#list + 1] = v
end

-- Отметить объект для очистки. kind — поле H.trash.
function H.keep(kind, ...)
    local t = H.trash[kind]
    if t == nil then return end
    push(t, { n = select("#", ...), ... })
end

-- Забыть хендл (объект уже уничтожен сам) — чтобы очистка не била по мёртвым.
function H.forget(kind, value)
    local list = H.trash[kind]
    if not list then return end
    for i = #list, 1, -1 do
        local e = list[i]
        if kind == "objects" and e == value then table.remove(list, i) end
    end
end

-- Полная очистка. Каждый шаг под pcall: падение одного не должно мешать остальным.
-- inGame=false — вне партии (чистим только то, что не требует игры).
function H.cleanup(inGame)
    local n = 0
    local function step(fn)
        local ok, err = pcall(fn)
        if ok then n = n + 1 else log.warn("AST cleanup: " .. tostring(err)) end
    end

    for _, h in ipairs(H.trash.brains) do step(function() ai.detach(h) end) end
    for _, s in ipairs(H.trash.statuses) do step(function() status.remove(s[1], s[2]) end) end
    for _, h in ipairs(H.trash.follows) do step(function() attach.unfollow(h) end) end
    for _, id in ipairs(H.trash.behaviours) do step(function() behaviour.destroy(id) end) end
    for _, g in ipairs(H.trash.groups) do step(function() group.destroy(g) end) end
    for _, name in ipairs(H.trash.regions) do step(function() regions.remove(name) end) end
    for _, name in ipairs(H.trash.trackGroups) do step(function() tracks.clear(name) end) end
    for _, id in ipairs(H.trash.markers) do step(function() markers.remove(id) end) end
    for _, id in ipairs(H.trash.decals) do step(function() decals.remove(id) end) end
    for _, s in ipairs(H.trash.sounds) do step(function() sound.stop(s) end) end
    -- sound.remove принимает ТЕГ ИЗЛУЧАТЕЛЯ, а не id звука — это разные числа.
    for _, tag in ipairs(H.trash.soundTags) do step(function() sound.remove(tag) end) end
    for _, p in ipairs(H.trash.pfx) do
        step(function() effects.deletePfx(p[1], p[2], p[3]) end)
    end
    for _, id in ipairs(H.trash.dbs) do step(function() dbg.clear(id) end) end
    for _, name in ipairs(H.trash.shapes) do step(function() dbg.clean(name) end) end

    if inGame then
    for _, h in ipairs(H.trash.objects) do
        -- Повторно уничтожать уже мёртвый объект нельзя: это краш (см. H.kill).
        if not H.isDead(h) then
            step(function() world.destroyNow(h) end)
            H.kill(h)
        end
    end
    end

    -- Сбросить списки (в т.ч. частично — если что-то не удалилось, не повторяем).
    for _, list in pairs(H.trash) do
        if type(list) == "table" then
            for i = #list, 1, -1 do list[i] = nil end
        end
    end

    -- Вернуть игровые настройки, которые кейсы могли изменить.
    if inGame then
        pcall(function() time.resume() end)
        pcall(function() fow.clearObjects() end)
        pcall(function() fow.clearPlayers() end)
        pcall(function() markers.clear() end)
        pcall(function() decals.clear() end)
        pcall(function() scheduler.clear() end)
        H.restoreWorld()
    end
    return n
end

-- Запомнить «мир до прогона», чтобы F11 вернул камеру и туман.
-- Кейсы трогают camera.moveTo/position, replay.camera, fow.enable, vision.night —
-- без отката это может оставить партию в неудобном состоянии.
function H.snapshotWorld()
    H.world = { fow = nil, fowLerp = nil, fowElev = nil, fowTextured = nil, minimapZoom = nil }
    if not game.isInGame() then return H.world end
    local okFow, was = pcall(fow.isEnabled)
    if okFow then H.world.fow = was end
    local okL, l = pcall(fow.lerp); if okL then H.world.fowLerp = l end
    local okE, e = pcall(fow.elevation); if okE then H.world.fowElev = e end
    local okT, tt = pcall(fow.textured); if okT then H.world.fowTextured = tt end
    local okZ, z = pcall(minimap.getZoom); if okZ then H.world.minimapZoom = z end
    return H.world
end

function H.restoreWorld()
    local w = H.world
    if not w then return 0 end
    local n = 0
    if w.fow ~= nil then
        local ok = pcall(fow.enable, w.fow); if ok then n = n + 1 end
    end
    if w.fowLerp ~= nil then pcall(fow.lerp, w.fowLerp) end
    if w.fowElev ~= nil then pcall(fow.elevation, w.fowElev) end
    if w.fowTextured ~= nil then pcall(fow.textured, w.fowTextured) end
    -- Миникарта: без этого она остаётся с чужим зумом (кейс visual.minimap меняет zoom).
    if w.minimapZoom ~= nil then pcall(minimap.zoom, w.minimapZoom) end
    -- Камера: снимаем слежение и останавливаем кинематографию.
    pcall(camera.follow, nil)
    pcall(camera.stop)
    pcall(replay.camera, false)
    pcall(cutscene.stop)
    return n
end

-- ---------------------------------------------------------------------------
-- Уничтоженные хендлы: к ним нельзя даже прикасаться
-- ---------------------------------------------------------------------------
--
-- КРАШ (2026-09-27, crashes/..._C0000005.txt): после world.destroy/destroyNow
-- любой вызов вроде objects.read(h) или object.state(h) уходит в
-- native GetGameObjectStateMachineHandle -> TObject.InheritsFrom по
-- освобождённому указателю -> ACCESS_VIOLATION и падение ВСЕЙ игры.
-- Lua-side SEH это не спасает: исключение ловится, но игра уже мертва.
--
-- Поэтому мод ведёт свой список уничтоженных хендлов и НИКОГДА не трогает их.

H.dead = {}

function H.kill(h)
    if h and h ~= 0 then H.dead[h] = true end
end

function H.isDead(h)
    return H.dead[h] == true
end

-- Безопасная обёртка: вернёт nil вместо падения, если хендл уже мёртв.
function H.readAlive(h)
    if H.isDead(h) then return nil end
    if objects and objects.alive and not objects.alive(h) then return nil end
    local ok, v = pcall(objects.read, h)
    if not ok then return nil end
    return v
end

function H.posAlive(h)
    if H.isDead(h) then return nil, nil end
    local ok, x, z = pcall(objects.pos, h)
    if not ok then return nil, nil end
    return x, z
end

-- Очистить список при game.end / F11.
function H.forgetDead()
    H.dead = {}
end

-- ---------------------------------------------------------------------------
-- Контекст кейса
-- ---------------------------------------------------------------------------

local Ctx = {}
Ctx.__index = Ctx

-- --- утверждения -------------------------------------------------------------

function Ctx:fail(msg)
    error({ ast = true, msg = tostring(msg) }, 3)
end

function Ctx:need(cond, msg)
    if not cond then self:fail(msg or "условие не выполнено") end
    return cond
end

-- Равенство с читаемым сообщением: eq(group.count(g), 3, "group.count").
function Ctx:eq(got, want, what)
    if got ~= want then
        self:fail(string.format("%s: получено %s, ожидалось %s",
            what or "значение", tostring(got), tostring(want)))
    end
    return got
end

-- Число в допуске (float-поля движка почти всегда плюсуют).
function Ctx:near(got, want, tol, what)
    tol = tol or 0.001
    if type(got) ~= "number" or math.abs(got - want) > tol then
        self:fail(string.format("%s: получено %s, ожидалось %s ±%s",
            what or "значение", tostring(got), tostring(want), tostring(tol)))
    end
    return got
end

-- Не пропустить молчаливое nil там, где api обещает число/строку.
function Ctx:notNil(v, what)
    if v == nil then self:fail((what or "значение") .. ": api вернул nil") end
    return v
end

function Ctx:note(msg)
    self.notes[#self.notes + 1] = tostring(msg)
    return msg
end

-- Пропустить кейс: нет партии, нет цели, нужна другая сторона.
function Ctx:skip(reason)
    error({ ast = true, skip = true, msg = tostring(reason) }, 3)
end

-- Проверить, что api-модуль вообще загружен. В игре они всегда есть, но если
-- модуль выпадет (обновление api, битая копия) — кейс должен честно сказать
-- «модуля нет», а не падать на nil.
-- ВАЖНО: api-таблицы лежат в БАЗОВОМ окружении, а мод видит его через
-- __index в метамётоде своего _ENV. Поэтому rawget(_ENV, name) вернёт nil
-- даже для загруженного модуля — нужно обычное обращение по имени.
function Ctx:mod(name)
    local m = _ENV[name]
    if type(m) ~= "table" then
        self:skip("api-модуль " .. name .. " не загружен в этом окружении")
    end
    return m
end

-- --- поиск целей (работает на обеих сторонах) -------------------------------

function Ctx:inGame(where)
    if not game.isInGame() then
        self:skip("нет активной партии (" .. tostring(where) .. ")")
    end
end

-- Индекс своего игрока. В одиночке/хосте это наш слот.
function Ctx:me()
    if self._me == nil then
        self._me = players.me()
        if self._me == nil then self:skip("players.me() = nil (вне партии или не наш слот)") end
    end
    return self._me
end

-- Здание или юнит? Через game.evalBool — работает и на client (только чтение),
-- в отличие от query.* с building-фильтром (ему нужен game.exec).
function Ctx:isBuilding(h)
    local o = objects.read(h)
    if not o or type(o.cid) ~= "number" or type(o.id) ~= "number" then return false end
    local ok, v = pcall(game.evalBool, string.format("gObjProp[%d][%d].bbuilding", o.cid, o.id))
    return ok and v == true
end

-- Свои живые юниты (не здания), до limit штук. Аналог query.units, но без
-- зависимости от сломанного на 0.2.0 query.* — и с правильным флагом здания.
function Ctx:myUnits(limit)
    local out = {}
    for _, r in ipairs(self:scanObjects({ player = self:me(), alive = true })) do
        if not self:isBuilding(r.handle) then
            out[#out + 1] = r.handle
            if limit and #out >= limit then break end
        end
    end
    return out
end

-- Все живые юниты (любой владелец), до limit штук.
function Ctx:allUnits(limit)
    local out = {}
    for _, r in ipairs(self:scanObjects({ alive = true })) do
        if not self:isBuilding(r.handle) then
            out[#out + 1] = r.handle
            if limit and #out >= limit then break end
        end
    end
    return out
end

-- Свой юнит: сперва выделение (units.selected доступен только server/shared —
-- на клиенте он бросает ошибку), потом ближайший к камере живой не-здание.
-- Сканируем objects.list напрямую, а НЕ через query.*: на 0.2.0 query.scan
-- падает на rawget(_G, ...) — см. кейс util.query. Так стенд не зависит от
-- сломанного модуля и всё равно проверяет быстрый путь objects.*.
function Ctx:scanObjects(opts)
    opts = opts or {}
    local out = {}
    for _, h in ipairs(objects.list()) do
        local ok, o = pcall(objects.read, h)
        if ok and type(o) == "table" then
            if not (opts.alive ~= false and o.bdead) then
                if opts.player == nil or o.pl == opts.player then
                    local okP, px, pz = pcall(objects.pos, h)
                    out[#out + 1] = { handle = h, x = okP and px or nil, z = okP and pz or nil,
                        hp = o.hp, player = o.pl, cid = o.cid, id = o.id }
                end
            end
        end
    end
    return out
end

function Ctx:ownUnit()
    if self._own then return self._own end
    self:inGame("ownUnit")
    local me = self:me()

    if game.exec then   -- units.selected есть только у server/shared
        for _, h in ipairs(units.selected() or {}) do
            if h and h ~= 0 then
                local o = objects.read(h)
                if o and not o.bdead and not self:isBuilding(h) then self._own = h return h end
            end
        end
    end

    -- Ближайший к центру камеры — обычно это то, на что игрок смотрит.
    local cx, cz = camera.gamePos()
    local best, bestD
    for _, r in ipairs(self:scanObjects({ player = me, alive = true })) do
        if r.x and not self:isBuilding(r.handle) then
            local d = cx and ((r.x - cx) ^ 2 + (r.z - cz) ^ 2) or 0
            if not bestD or d < bestD then best, bestD = r.handle, d end
        end
    end
    if not best then self:skip("нет своих живых юнитов (поставь юнита или начни партию за своего игрока)") end
    self._own = best
    return best
end

-- Любой живой юнит (свой или чужой) — для тестов, где владелец не важен.
function Ctx:anyUnit()
    if self._any then return self._any end
    self:inGame("anyUnit")
    for _, r in ipairs(self:scanObjects({ alive = true })) do
        if not self:isBuilding(r.handle) then self._any = r.handle return r.handle end
    end
    self:skip("на карте нет живых юнитов")
end

-- Чужой юнит. В одиночной игре их нет — кейс честно пропустится.
function Ctx:foeUnit()
    if self._foe then return self._foe end
    self:inGame("foeUnit")
    local me = self:me()
    for _, r in ipairs(self:scanObjects({ alive = true })) do
        if r.player ~= nil and r.player ~= me and not self:isBuilding(r.handle) then
            self._foe = r.handle
            return r.handle
        end
    end
    self:skip("нет чужих юнитов (одиночная партия — нужен противник или ИИ)")
end

-- Своё здание.
function Ctx:ownBuilding()
    if self._bld then return self._bld end
    self:inGame("ownBuilding")
    local me = self:me()
    for _, r in ipairs(self:scanObjects({ player = me, alive = true })) do
        if self:isBuilding(r.handle) then self._bld = r.handle return r.handle end
    end
    self:skip("нет своих зданий (построй мельницу или казарму — нужен реальный sid)")
end

-- Базовая точка для спавна/рисования: позиция ближайшего к камере своего юнита.
-- Кэшируется, чтобы все кейсы мерили в одном месте.
function Ctx:spot()
    if self._spot then return self._spot end
    self:inGame("spot")
    local h = self:ownUnit()
    local x, z = objects.pos(h)
    if not x then
        -- юнита может не быть (дерево/камень) — берём любой объект с позицией
        local n = 0
        for _, r in ipairs(self:scanObjects({ alive = true })) do
            if r.x then x, z = r.x, r.z break end
            n = n + 1
            if n > 200 then break end
        end
    end
    if not x then self:skip("не нашлась точка на карте (нет объектов с позицией)") end
    self._spot = { x = x, z = z }
    return self._spot
end

-- Точка со смещением от базовой. Смещение нужно, чтобы кейсы не накладывали
-- объекты друг на друга: спавн десяти юнитов в одну точку — плохая проверка.
function Ctx:spotAt(dx, dz)
    local s = self:spot()
    return { x = s.x + (tonumber(dx) or 0), z = s.z + (tonumber(dz) or 0) }
end

-- Базовая точка со смещением: spot(60) — это spotAt по обоим осям.
function Ctx:spotOffset(d)
    return self:spotAt(d, d)
end

-- sid (basename) любого живого юнита на карте — для world.spawn/scenario.wave.
-- Строки вроде "musketeer18" зависят от нации и версии игры, поэтому берём
-- настоящий: GetGameObjectBaseNameByHandle.
function Ctx:unitSid()
    if self._usid then return self._usid end
    local h = self:anyUnit()
    local ok, sid = pcall(native.GetGameObjectBaseNameByHandle, h)
    if not ok or type(sid) ~= "string" or sid == "" then
        self:skip("не удалось узнать sid юнита (GetGameObjectBaseNameByHandle)")
    end
    self._usid = sid
    return sid
end

-- Нация (racename) для world.spawn. Берём у своего юнита — нативом
-- GetGameObjectRaceNameByHandle. Угадывать "ukr" нельзя: нация может быть любой,
-- а ещё можно играть за другой народ.
function Ctx:race()
    if self._race then return self._race end
    local h = self:ownUnit()
    local ok, race = pcall(native.GetGameObjectRaceNameByHandle, h)
    if not ok or type(race) ~= "string" or race == "" then
        -- Запасной путь: racename в слоте игрока.
        local ok2, p = pcall(state.get, "gMap.players[" .. (self:me() + 1) .. "].racename")
        if ok2 and type(p) == "string" and p ~= "" then race = p end
    end
    if type(race) ~= "string" or race == "" then
        self:skip("не удалось узнать нацию (GetGameObjectRaceNameByHandle и gMap.players[].racename)")
    end
    self._race = race
    return race
end

-- Настоящий sid здания/юнита из игры — не угадывать: конкретные строки ("musketeer18",
-- "ukrmill") зависят от нации и версии игры, а натив требует точный basename.
function Ctx:buildingSid()
    if self._bsid then return self._bsid end
    local b = self:ownBuilding()
    local ok, sid = pcall(native.GetGameObjectBaseNameByHandle, b)
    if not ok or type(sid) ~= "string" or sid == "" then
        self:skip("не удалось узнать sid своего здания (GetGameObjectBaseNameByHandle)")
    end
    self._bsid = sid
    return sid
end

-- Свободная высота в точке (RayCastHeight через native, без Pascal).
function Ctx:ground(x, z)
    local ok, y = pcall(native.RayCastHeight, x, z)
    if not ok or type(y) ~= "number" then return 0 end
    return y
end

-- --- удобства для кейсов ----------------------------------------------------

-- Заспавнить объект и запомнить его для очистки.
function Ctx:spawn(spec)
    local h = world.spawn(spec)
    if h and h ~= 0 then H.keep("objects", h) end
    return h
end

-- Отметить что-то на очистку (группы, зоны, треки, надписи...).
function Ctx:keep(kind, ...)
    H.keep(kind, ...)
end

-- Отложенная проверка. Многие api срабатывают не сразу, а на следующих game.tick:
-- weapon.fire (время подлёта), terrain (пересчёт), object.waitFor, regions.onEnter,
-- scheduler. Такой кейс нельзя проверить «здесь и сейчас» — он ставит проверку и
-- возвращает управление. Через delaySec игрового времени выполняется fn(cont),
-- а её результат попадает в отчёт отдельной строкой "<id>#через Nс".
--
--   t:defer(function(c)
--       c:eq(object.state(h), "burning", "объект перешёл в burning")
--   end, 2, "проверка состояния через 2 с")
function Ctx:defer(fn, delaySec, label)
    if type(fn) ~= "function" then self:fail("defer: fn must be a function") end
    delaySec = tonumber(delaySec) or 1
    label = tostring(label or ("через " .. string.format("%.1f", delaySec) .. " с"))
    local id = self.id
    local section = self.section
    local side = H.runningSide
    local sub = scheduler.after(delaySec, function()
        local cont = setmetatable({ id = id, section = section, notes = {}, started = os.clock() }, Ctx)
        local rec = { id = id .. "#" .. label, section = section, side = side, risky = false,
            status = "ok", msg = "", ms = 0, deferred = true }
        local ok, err = pcall(fn, cont)
        rec.ms = math.floor((os.clock() - cont.started) * 1000 + 0.5)
        if ok then
            rec.msg = type(err) == "string" and err or cont:detail()
        elseif type(err) == "table" and err.ast then
            rec.status = err.skip and "skip" or "fail"
            rec.msg = err.msg or "?"
        else
            rec.status = "error"
            rec.msg = tostring(err)
        end
        local tag = rec.status == "ok" and "OK  " or (rec.status == "skip" and "SKIP" or
            (rec.status == "fail" and "FAIL" or "ERR "))
        log.info(string.format("[AST] DEFER %s %s %s (%d ms)", tag, rec.id, rec.msg, rec.ms))
        H.results[#H.results + 1] = rec
        if H.onResult then pcall(H.onResult, rec) end
    end)
    self.notes[#self.notes + 1] = "отложенная проверка: " .. label
    return id
end

-- Строки итоговой подробности.
function Ctx:detail()
    if #self.notes == 0 then return "ok" end
    local s = table.concat(self.notes, "; ")
    if #s > 400 then s = s:sub(1, 397) .. "..." end
    return s
end

-- ---------------------------------------------------------------------------
-- Запуск
-- ---------------------------------------------------------------------------

H.results = {}     -- newest last: { id, section, side, risky, status, msg, ms }
H.running = false
H.runningSide = nil
H.lastRun = nil    -- { section, risky, started, ms, counts }
H.onResult = nil   -- вызывается с каждой новой записью (клиент шлёт в страницу)

local function counts(list)
    local c = { ok = 0, fail = 0, error = 0, skip = 0 }
    for _, r in ipairs(list) do
        if c[r.status] ~= nil then c[r.status] = c[r.status] + 1 end
    end
    c.total = c.ok + c.fail + c.error + c.skip
    return c
end

H.counts = function() return counts(H.results) end

-- Один кейс. opts.quiet — не писать START/END в лог.
-- Возвращает запись результата.
function H.runCase(c, opts)
    opts = opts or {}
    local t = setmetatable({
        id = c.id, section = c.section, notes = {}, started = os.clock(),
    }, Ctx)

    local rec = {
        id = c.id, section = c.section, side = c.here, risky = c.risky,
        status = "ok", msg = "", ms = 0,
    }

    -- Лог ДО запуска: если игра упала, последняя START — виновник.
    if not opts.quiet then
        log.info(string.format("[AST] START %s (%s%s)", c.id, c.section, c.risky and ", risky" or ""))
    end

    local ok, err = pcall(c.fn, t)
    rec.ms = math.floor((os.clock() - t.started) * 1000 + 0.5)

    if ok then
        rec.msg = type(err) == "string" and err or t:detail()
    elseif type(err) == "table" and err.ast then
        rec.status = err.skip and "skip" or "fail"
        rec.msg = err.msg or "?"
    else
        rec.status = "error"
        rec.msg = tostring(err)
    end

    if not opts.quiet then
        local tag = rec.status == "ok" and "OK  " or (rec.status == "skip" and "SKIP" or
            (rec.status == "fail" and "FAIL" or "ERR "))
        log.info(string.format("[AST] END   %s %s %s (%d ms)", tag, rec.id, rec.msg, rec.ms))
    end
    return rec
end

-- Прогнать кейсы этой стороны.
--   section = "all" | id раздела
--   opts.risky = true — разрешить опасные кейсы
--   opts.only  = { id, ... } — точечный прогон (используется для повтора одного кейса)
--   opts.quiet = true — не писать START/END в лог (для автопрогона)
-- Возвращает { counts, ms, records }.
function H.run(section, opts)
    opts = opts or {}
    if H.running then return nil, "прогон уже идёт" end
    H.running = true
    H.runningSide = autoSide()

    local t0 = os.clock()
    local list = H.myCases(section)
    if opts.only then
        local want = {}
        for _, id in ipairs(opts.only) do want[id] = true end
        local filtered = {}
        for _, c in ipairs(list) do if want[c.id] then filtered[#filtered + 1] = c end end
        list = filtered
    end
    H.snapshotWorld()

    local made = {}
    for _, c in ipairs(list) do
        if c.risky and not opts.risky then
            made[#made + 1] = { id = c.id, section = c.section, side = c.here, risky = true,
                status = "skip", msg = "опасный кейс — нужен подтверждённый прогон (F8)", ms = 0 }
            if not opts.quiet then
                log.info(string.format("[AST] END   SKIP %s опасный кейс — нужен подтверждённый прогон (F8)", c.id))
            end
        else
            made[#made + 1] = H.runCase(c, opts)
        end
    end

    for _, r in ipairs(made) do
        H.results[#H.results + 1] = r
        if H.onResult then pcall(H.onResult, r) end
    end
    H.running = false
    H.runningSide = nil

    local ms = math.floor((os.clock() - t0) * 1000 + 0.5)
    local c = counts(made)
    H.lastRun = { section = section or "all", risky = opts.risky == true, ms = ms, counts = c }
    log.info(string.format("[AST] %s: %d кейсов — ok %d, fail %d, error %d, skip %d (%d ms)",
        tostring(section or "all"), c.total, c.ok, c.fail, c.error, c.skip, ms))
    return { counts = c, ms = ms, records = made }
end

function H.reset()
    H.results = {}
    H.lastRun = nil
end

-- ---------------------------------------------------------------------------
-- Отчёт
-- ---------------------------------------------------------------------------

local ICON = { ok = "+", fail = "x", error = "!", skip = "-" }

-- report(section) -> строка. section=nil — весь отчёт по разделам.
function H.report(section, verbose)
    local out = {}
    local function line(s) out[#out + 1] = s end

    local c = H.counts()
    local mode = "?"
    pcall(function() mode = tostring(game.mode()) end)
    line(string.format("=== API STRESS TEST %s — режим: %s ===", H.VERSION, mode))
    line(string.format("итого: %d проверок | ok %d | fail %d | error %d | skip %d",
        c.total, c.ok, c.fail, c.error, c.skip))
    line("")

    -- Порядок разделов: сначала объявленные, потом неизвестные (в порядке появления).
    local order, known = {}, {}
    for _, s in ipairs(H.SECTIONS) do
        order[#order + 1] = s.id
        known[s.id] = true
    end
    for _, r in ipairs(H.results) do
        if not known[r.section] then
            known[r.section] = true
            order[#order + 1] = r.section
        end
    end

    local bySection = {}
    for _, r in ipairs(H.results) do
        local b = bySection[r.section]
        if b == nil then b = {}; bySection[r.section] = b end
        b[#b + 1] = r
    end

    for _, sid in ipairs(order) do
        local rows = bySection[sid]
        if rows and (section == nil or section == "all" or sid == section) then
            local title = H.SECTION_TITLE[sid] or sid
            local sc = counts(rows)
            line(string.format("-- %s  [%d: ok %d, fail %d, error %d, skip %d]",
                title, sc.total, sc.ok, sc.fail, sc.error, sc.skip))
            for _, r in ipairs(rows) do
                if verbose or r.status ~= "ok" then
                    line(string.format("   %s %-28s %-4s %s%s", ICON[r.status] or "?",
                        r.id, r.side, r.msg, r.ms > 0 and string.format("  (%d ms)", r.ms) or ""))
                end
            end
            if not verbose then
                local shown = 0
                for _, r in ipairs(rows) do if r.status == "ok" then shown = shown + 1 end end
                if shown > 0 then line(string.format("   ... ещё %d успешных (verbose-режим покажет)", shown)) end
            end
            line("")
        end
    end
    return table.concat(out, "\n")
end

-- Короткая строка для панели/статус-бара.
function H.summaryLine()
    local c = H.counts()
    if c.total == 0 then return "нет прогонов" end
    return string.format("%d: ok %d, fail %d, err %d, skip %d",
        c.total, c.ok, c.fail, c.error, c.skip)
end

-- ---------------------------------------------------------------------------
-- Передача результатов по сети (shared -> client), кусками по 8 КБ
-- ---------------------------------------------------------------------------

H.MAX_MSG = 7000
H.MAX_FIELD = 220

local function trim(s)
    s = tostring(s or "")
    s = s:gsub("[\r\n]+", " ")          -- одна строка = одна запись
    if #s > H.MAX_FIELD then s = s:sub(1, H.MAX_FIELD - 3) .. "..." end
    return s
end

-- Разбить записи на сообщения примерно по 7 КБ.
function H.chunk(records)
    local out, cur, size = {}, {}, 0
    for _, r in ipairs(records) do
        local row = {
            id = trim(r.id), section = trim(r.section), side = trim(r.side),
            risky = r.risky and true or false, status = trim(r.status),
            msg = trim(r.msg), ms = r.ms or 0,
        }
        local cost = #row.id + #row.msg + 90
        if #cur > 0 and size + cost > H.MAX_MSG then
            out[#out + 1] = cur
            cur, size = {}, 0
        end
        cur[#cur + 1] = row
        size = size + cost
    end
    if #cur > 0 then out[#out + 1] = cur end
    return out
end

-- Отправить результаты всем клиентам (вызывать на shared после H.run).
function H.broadcast(tag, records, done)
    local parts = H.chunk(records)
    for i, rows in ipairs(parts) do
        local ok, err = pcall(net.broadcast, "ast.results", {
            tag = tag, part = i, last = (i == #parts), rows = rows,
        })
        if not ok then
            log.error("AST: не отправить результаты (" .. tostring(err) .. ")")
            return false
        end
    end
    if #parts == 0 then
        pcall(net.broadcast, "ast.results", { tag = tag, part = 1, last = true, rows = {} })
    end
    if done then pcall(net.broadcast, "ast.done", done) end
    return true
end

return H
