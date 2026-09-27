-- status — эффекты на юнитах: горение, яд, оглушение, регенерация, невидимость.
--
-- МЕНЯЕТ МИР: только server/shared (урон/лечение через state.set, блокировка
-- приказов через unit.order). Тикает в game.tick, чистится сам.
--
--   status.add(h, "burning", { duration = 10, damage = 20 })   -- 20 HP раз в 1 с
--   status.add(h, "stunned", { duration = 3 })                 -- стоит, приказы режутся
--   (для резки приказов один раз в shared: status.installBlocker(events.on))
--   status.add(h, "regen", { duration = 15, heal = 10 })
--   status.add(h, "invisible", { duration = 20 })              -- скрыт (model.show)
--   status.has(h, "burning")    -- status.remove(h, "burning") / status.list(h)
--
-- Свои эффекты: status.define("rage", { onTick = function(h) ... end, ... }).
-- Пресеты: burning, poison, bleeding, regen, stunned, invisible.

status = {}

local active = {}   -- [h] = { [name] = { until=, next=, spec= } }
local sub = nil
local defs = {}

local function needServer(where)
    if not game.exec then
        error("status." .. where .. ": only server/shared scripts can change units", 3)
    end
    if not game.isInGame() then
        error("status." .. where .. ": no active game (check game.isInGame())", 3)
    end
end

local function checkHandle(h)
    h = math.tointeger(tonumber(h))
    if not h or h == 0 then error("status: handle must be a non-zero number", 3) end
    return h
end

local function alive(h)
    local ok, o = pcall(objects.read, h)
    return ok and o and not o.bdead
end

local function hpOf(h)
    local ok, o = pcall(objects.read, h)
    if ok and o and o.hp then return o.hp end
    return nil
end

local function hurt(h, amount)
    local hp = hpOf(h)
    if not hp then return end
    hp = hp - amount
    if hp < 0 then hp = 0 end
    state.set("obj(" .. h .. ").hp", hp)
end

local function heal(h, amount, maxhp)
    local hp = hpOf(h)
    if not hp then return end
    hp = hp + amount
    if maxhp and hp > maxhp then hp = maxhp end
    state.set("obj(" .. h .. ").hp", hp)
end

local function ensureTick()
    if sub then return end
    sub = events.on("game.tick", function()
        if not game.isInGame() then return end
        local now = os.clock()
        for h, fx in pairs(active) do
            if not alive(h) then
                active[h] = nil
            else
                for name, e in pairs(fx) do
                    if now >= e.until_ then
                        fx[name] = nil
                        if e.def.onRemove then pcall(e.def.onRemove, h) end
                    elseif now >= e.next then
                        e.next = now + (e.def.interval or 1)
                        if e.def.onTick then pcall(e.def.onTick, h, e) end
                    end
                end
                if not next(fx) then active[h] = nil end
            end
        end
        if not next(active) and sub then events.off(sub) sub = nil end
    end)
end

-- Регистрирует свой эффект. name — имя, def = { interval, onApply(h, e), onTick(h, e), onRemove(h) }.
-- Сторона: везде (локально, мир не меняет). Возвращает true. Ошибки: bad name, def must be a table.
function status.define(name, def)
    if type(name) ~= "string" or name == "" then error("status.define: bad name", 2) end
    if type(def) ~= "table" then error("status.define: def must be a table", 2) end
    defs[name] = def
    return true
end

status.define("burning", { interval = 1,
    onApply = function(h) pcall(effects.highlight, h, "burning", true, "") end,
    onTick = function(h, e) hurt(h, e.spec.damage or 10) end,
    onRemove = function(h) pcall(effects.unhighlight, h, "burning") end })
status.define("poison", { interval = 2,
    onTick = function(h, e) hurt(h, e.spec.damage or 5) end })
status.define("bleeding", { interval = 1,
    onTick = function(h, e) hurt(h, e.spec.damage or 3) end })
status.define("regen", { interval = 1,
    onTick = function(h, e) heal(h, e.spec.heal or 5, e.spec.maxhp) end })
status.define("stunned", { interval = 60 })   -- приказы режутся ниже
status.define("invisible", { interval = 60,
    onApply = function(h) pcall(model.show, h, false) end,
    onRemove = function(h) pcall(model.show, h, true) end })

-- Оглушённые не получают приказы (shared — одинаково на всех машинах).
-- Подписка ставится только из мода (в api-окружении нет events):
--   status.installBlocker(events.on)   -- один раз в server/shared
local blockerOn = nil

-- Режет приказы оглушённым: на unit.order возвращает true, если юнит в "stunned".
-- on — events.on, вызывать один раз в shared (в api-окружении events нет). Повторный вызов — no-op.
-- Сторона: shared (одинаково на всех машинах). Ошибки: pass events.on, если on не функция.
function status.installBlocker(on)
    if blockerOn then return end
    if type(on) ~= "function" then error("status.installBlocker: pass events.on", 2) end
    blockerOn = on
    on("unit.order", function(_, h)
        local fx = active[h]
        if fx and fx["stunned"] then return true end
    end)
end

-- Вешает эффект: h — хендл, name — имя (свой или пресет), spec = { duration, damage/heal/... }.
-- Сторона: только server/shared (меняет мир, нужен game.exec + игра). Ничего не возвращает.
-- Ошибки: only server/shared scripts can change units, no active game, handle must be a non-zero number,
-- unknown effect, spec must be a table.
function status.add(h, name, spec)
    needServer("add")
    h = checkHandle(h)
    local def = defs[name] or error("status.add: unknown effect '" .. tostring(name) .. "'", 2)
    spec = spec or {}
    if type(spec) ~= "table" then error("status.add: spec must be a table", 2) end
    local dur = tonumber(spec.duration or 10) or 10
    active[h] = active[h] or {}
    active[h][name] = { until_ = os.clock() + dur, next = os.clock(),
                        spec = spec, def = def }
    if def.onApply then pcall(def.onApply, h, active[h][name]) end
    ensureTick()
end

-- Снимает эффект (вызывает onRemove). h — хендл, name — имя. Нет эффекта — no-op.
-- Сторона: везде (чистит локальную таблицу своей стороны). Ничего не возвращает.
-- Ошибки: handle must be a non-zero number.
function status.remove(h, name)
    h = checkHandle(h)
    local fx = active[h]
    if fx and fx[name] then
        fx[name] = nil
        local def = defs[name]
        if def and def.onRemove then pcall(def.onRemove, h) end
    end
end

-- Есть ли эффект на юните. h — хендл, name — имя. Возвращает true/false.
-- Сторона: везде (чтение локальной таблицы). Ошибки не кидает.
function status.has(h, name)
    local fx = active[tonumber(h) or 0]
    return fx ~= nil and fx[name] ~= nil
end

-- Список эффектов на юните. h — хендл. Возвращает { name, ... } (пустой, если нет).
-- Сторона: везде (чтение локальной таблицы). Ошибки не кидает.
function status.list(h)
    local out = {}
    for name in pairs(active[tonumber(h) or 0] or {}) do out[#out + 1] = name end
    return out
end
