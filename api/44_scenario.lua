-- scenario — конструктор миссий: цели, волны, диалоги. Кампании без .aix.
--
-- Логика — server/shared; показ диалогов — client (ставится сам через net).
-- Мод делит файл: logic в server/shared, scenario.present() вызвать в client.
--
--   -- shared.lua
--   scenario.objective("mill", { type = "capture", x = 100, z = 50, radius = 20, player = 0,
--       onDone = function(id) log.info("мельница наша") end })
--   scenario.wave({ delay = 60, units = { "peauk", "peacav" }, race = "tat",
--       x = 200, z = 100, player = 1 })
--   scenario.dialog("intro", { speaker = "Гетьман", text = "Ворог наближається..." })
--
--   -- client.lua
--   scenario.present()   -- показывать диалоги поверх игры
--
-- Цели: capture (юнит игрока в зоне), destroy (цель мёртва), survive (пережить время),
-- gather (столько-то своего ресурса — видит только server). Волны спавнят через world.spawn.

scenario = {}

local objectives = {}
local waves = {}
local sub = nil
local bus = nil   -- { broadcast = fn, on = fn }: net есть только у мода, не в api

-- Привязать сеть мода (один раз в server/shared и client записях):
--   scenario.link({ broadcast = net.broadcast, on = net.on })   -- server/shared
--   scenario.link({ on = net.on })                              -- client (только показ)
-- Без link dialog/present кидают ошибку. Привязка локальна (сторона: везде), ничего не возвращает.
-- Ошибки: pass { broadcast = net.broadcast, on = net.on }, если on не функция.
function scenario.link(t)
    if type(t) ~= "table" or type(t.on) ~= "function" then
        error("scenario.link: pass { broadcast = net.broadcast, on = net.on }", 2)
    end
    bus = t
end

local function needBus(where)
    if not bus then
        error("scenario." .. where .. ": call scenario.link(...) in your mod entry first", 3)
    end
    return bus
end

local function say(text)
    local ok, mod = pcall(function() return log end)
    if ok and type(mod) == "table" and mod.info then mod.info(text) return end
end

local function needLogic(where)
    if not game.exec then
        error("scenario." .. where .. ": objectives/waves/dialogs run on server/shared", 3)
    end
end

local function num(v, name)
    local n = tonumber(v)
    if not n or n ~= n then error("scenario: " .. name .. " must be a number", 3) end
    return n
end

local function ensureTick()
    if sub then return end
    sub = events.on("game.tick", function()
        if not game.isInGame() then return end
        local now = os.clock()
        for id, w in pairs(waves) do
            if now >= w.at then
                waves[id] = nil
                for _, sid in ipairs(w.units) do
                    world.spawn({ player = w.player, race = w.race, base = sid, x = w.x, z = w.z })
                end
                if w.onSpawn then pcall(w.onSpawn, id) end
            end
        end
        for id, o in pairs(objectives) do
            local done = scenario.check(id)
            if done then
                objectives[id] = nil
                if o.onDone then pcall(o.onDone, id) end
                if bus and bus.broadcast then
                    pcall(bus.broadcast, "scenario.done", { id = id })
                end
            end
        end
        if not next(waves) and not next(objectives) and sub then
            events.off(sub) sub = nil
        end
    end)
end

-- Цель. id — имя, spec.type: capture (свой юнит в зоне x,z,radius), destroy (target мёртв),
-- survive (продержаться seconds), gather (ресурс res >= amount у player). spec.onDone(id) — по готовности.
-- Сторона: только server/shared. Возвращает id. Ошибки: objectives/waves... run on server/shared,
-- bad id, spec table required, seconds/amount must be a number.
function scenario.objective(id, spec)
    needLogic("objective")
    if type(id) ~= "string" or id == "" then error("scenario.objective: bad id", 2) end
    if type(spec) ~= "table" then error("scenario.objective: spec table required", 2) end
    if spec.type == 'survive' then spec.deadline = os.clock() + num(spec.seconds or 60, 'seconds') end
    objectives[id] = spec
    ensureTick()
    return id
end

-- Проверка цели вручную. id — имя. Возвращает true/false (нет цели — false).
-- Сторона: везде (чистое чтение, survive тикает при вызове). Ошибки не кидает.
function scenario.check(id)
    local o = objectives[id]
    if not o then return false end
    if o.type == "destroy" then
        local ok, info = pcall(objects.read, o.target)
        if not ok or not info then return true end   -- нет объекта = уничтожен
        return info.bdead == true
    elseif o.type == "capture" then
        for _, h in ipairs(targeting.inCircle(o.x, o.z, o.radius or 20,
            { player = o.player, alive = true })) do
            return true
        end
        return false
    elseif o.type == "survive" then
        o.left = (o.left == nil) and num(o.seconds or 60, "seconds") or o.left
        o.left = o.left - 1 / 10   -- примерно: тиков ~10 в секунду
        return o.left <= 0
    elseif o.type == "gather" then
        local p = player(o.player)
        return (p[o.res] or 0) >= num(o.amount or 1, "amount")
    end
    return false
end

-- Отменить цель. id — имя. Нет цели — no-op. Сторона: везде. Ничего не возвращает, не кидает.
function scenario.cancelObjective(id)
    objectives[id] = nil
end

-- Волна подкрепления через delay секунд: spec = { delay, units = { basenames }, race, x, z, player, onSpawn }.
-- Спавн через world.spawn. Сторона: только server/shared. Возвращает id волны.
-- Ошибки: objectives/waves... run on server/shared, pass { delay=, units=, ... } (units не таблица),
-- delay/x/z must be a number.
function scenario.wave(spec)
    needLogic("wave")
    if type(spec) ~= "table" or type(spec.units) ~= "table" then
        error("scenario.wave: pass { delay=, units=, race=, x=, z= }", 2)
    end
    local id = "wave" .. tostring(os.clock())
    waves[id] = { at = os.clock() + num(spec.delay or 0, "delay"), units = spec.units,
                  race = spec.race or "ukr", x = num(spec.x, "x"), z = num(spec.z, "z"),
                  player = spec.player or 1, onSpawn = spec.onSpawn }
    ensureTick()
    return id
end

-- Реплика всем клиентам: id — имя, spec = { speaker, text, duration = 8 }.
-- Требует link с broadcast (иначе call scenario.link...). Сторона: только server/shared.
-- Ничего не возвращает. Ошибки: objectives/waves... run on server/shared, pass { speaker=, text= }, link missing.
function scenario.dialog(id, spec)
    needLogic("dialog")
    if type(spec) ~= "table" then error("scenario.dialog: pass { speaker=, text= }", 2) end
    needBus("dialog").broadcast("scenario.dialog", { id = id, speaker = spec.speaker or "",
        text = spec.text or "", duration = spec.duration or 8 })
end

-- Client: показывать диалоги (нужен link с on). Вызвать один раз в client.lua.
function scenario.present()
    local bus = needBus("present")
    local box = nil
    bus.on("scenario.dialog", function(data)
        if ui and ui.text then
            if box then pcall(ui.remove, box) end
            local w, h = ui.size()
            box = ui.text({ name = "scn_dlg", parent = 0,
                text = (data.speaker ~= "" and data.speaker .. ": " or "") .. data.text,
                x = w / 2 - 300, y = h - 120, w = 600, h = 60 })
        else
            say((data.speaker ~= "" and data.speaker .. ": " or "") .. data.text)
        end
    end)
    bus.on("scenario.done", function(data)
        say("цель выполнена: " .. tostring(data.id))
    end)
end

-- Триггер: один раз выполнить action, когда событие пришло и filter пропустил.
--   scenario.trigger("first_blood", { on = "unit.death",
--       filter = function(handle, basename) return basename == "hetman" end,
--       action = function(handle, basename) scenario.dialog("d1", {...}) end })
function scenario.trigger(id, spec)
    if type(spec) ~= "table" or type(spec.on) ~= "string" then
        error("scenario.trigger: pass { on = event, action = fn }", 2)
    end
    if type(spec.action) ~= "function" then
        error("scenario.trigger: action must be a function", 2)
    end
    local sub
    sub = events.on(spec.on, function(event, ...)
        if spec.filter and not spec.filter(...) then return end
        if spec.once ~= false then events.off(sub) end
        spec.action(...)
    end)
    return sub
end

-- Кадр-снимок экрана (не сейв!): для брифингов и отчётов миссии.
-- Возвращает имя файла. Отката состояния движок НЕ умеет — restore() нет.
function scenario.snapshot(filename, w, h)
    if filename ~= nil then
        if type(filename) ~= "string" then error("scenario.snapshot: bad filename", 2) end
        native.CreateSnapShotExt(true, filename,
            math.tointeger(tonumber(w or 800)) or 800,
            math.tointeger(tonumber(h or 600)) or 600)
        return filename
    end
    native.CreateSnapShot(true)
    return native.GetLastCreateSnapShotFileName()
end

-- Запустить текущий сценарий игры (сингл, из меню сценариев).
function scenario.begin()
    if not game.exec then
        error("scenario.begin: only server/shared scripts", 2)
    end
    native.BeginPlayingCurrentScenario()
end
