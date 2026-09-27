-- ai — поведение юнитов: конечный автомат поверх orders/targeting/status.
--
-- МЕНЯЕТ МИР: только server/shared (автомат отдаёт приказы).
--
--   ai.attach(h, {
--       initial = "guard",
--       states = {
--           guard = {
--               onTick = function(h, api)
--                   local foe = targeting.nearest(h, { enemy = true, maxR = 60 })
--                   if foe then api.gotoState("attack", { target = foe }) end
--               end,
--           },
--           attack = {
--               onEnter = function(h, api, params) orders.attack(h, params.target) end,
--               onTick = function(h, api, params)
--                   if not api.alive(params.target) then api.gotoState("guard") end
--                   if api.hp() < 20 then api.gotoState("retreat") end
--               end,
--           },
--           retreat = {
--               onEnter = function(h, api) orders.move(h, api.home.x, api.home.z) end,
--           },
--       },
--   })
--   ai.detach(h)   -- снять поведение
--
-- api в колбэках: gotoState(name, params), hp(), alive(h), home {x, z} (точка привязки).
-- Тик автомата — каждые tickEvery game.tick (по умолчанию 5). Мёртвый юнит снимается сам.

ai = {}

local brains = {}   -- [h] = { def, state, params, home, counter }
local sub = nil

local function needServer(where)
    if not game.exec then
        error("ai." .. where .. ": only server/shared scripts can drive units", 3)
    end
    if not game.isInGame() then
        error("ai." .. where .. ": no active game (check game.isInGame())", 3)
    end
end

local function checkHandle(h)
    h = math.tointeger(tonumber(h))
    if not h or h == 0 then error("ai: handle must be a non-zero number", 3) end
    return h
end

local function alive(h)
    local ok, o = pcall(objects.read, h)
    return ok and o and not o.bdead
end

local function ensureTick()
    if sub then return end
    sub = events.on("game.tick", function()
        if not game.isInGame() then return end
        for h, b in pairs(brains) do
            if not alive(h) then
                brains[h] = nil
            else
                b.counter = b.counter + 1
                if b.counter >= (b.def.tickEvery or 5) then
                    b.counter = 0
                    local st = b.def.states[b.state]
                    if st and st.onTick then
                        pcall(st.onTick, h, b.api, b.params)
                    end
                end
            end
        end
        if not next(brains) and sub then events.off(sub) sub = nil end
    end)
end

local function makeApi(h, b)
    return {
        home = b.home,
        hp = function() local ok, o = pcall(objects.read, h) return (ok and o and o.hp) or 0 end,
        alive = alive,
        gotoState = function(name, params) ai.set(h, name, params) end,
    }
end

-- Вешает автомат: h — хендл, def = { initial, states = { s = { onEnter(h,api,params), onTick } }, tickEvery = 5 }.
-- home — точка привязки (позиция на момент attach). Сторона: только server/shared (отдаёт приказы, нужна игра).
-- Ничего не возвращает. Ошибки: only server/shared scripts can drive units, no active game,
-- handle must be a non-zero number, pass { states = { ... } }, no state 'initial'.
function ai.attach(h, def)
    needServer("attach")
    h = checkHandle(h)
    if type(def) ~= "table" or type(def.states) ~= "table" then
        error("ai.attach: pass { states = { ... } }", 2)
    end
    local initial = def.initial or "idle"
    if not def.states[initial] then
        error("ai.attach: no state '" .. tostring(initial) .. "'", 2)
    end
    local hx, hz = objects.pos(h)
    local b = { def = def, state = initial, params = {},
                home = { x = hx or 0, z = hz or 0 }, counter = 999 }
    b.api = makeApi(h, b)
    brains[h] = b
    local st = def.states[initial]
    if st.onEnter then pcall(st.onEnter, h, b.api, b.params) end
    ensureTick()
end

-- Переход в состояние: h — хендл, name — имя из def.states, params — для onEnter/onTick.
-- Вызывает onEnter сразу, счётчик тика сбрасывает. Сторона: только server/shared.
-- Ничего не возвращает. Ошибки: only server/shared..., handle..., no brain on h (нужен ai.attach), no state 'name'.
function ai.set(h, name, params)
    needServer("set")
    h = checkHandle(h)
    local b = brains[h] or error("ai.set: no brain on " .. h .. " (ai.attach first)", 2)
    if not b.def.states[name] then error("ai.set: no state '" .. tostring(name) .. "'", 2) end
    b.state, b.params, b.counter = name, params or {}, 999
    local st = b.def.states[name]
    if st.onEnter then pcall(st.onEnter, h, b.api, b.params) end
end

-- Снять поведение. h — хендл. Нет мозга — no-op. Сторона: везде (чистит локально).
-- Ничего не возвращает. Ошибки: handle must be a non-zero number.
function ai.detach(h)
    brains[checkHandle(h)] = nil
end

-- Текущее состояние. h — хендл. Возвращает имя или nil (нет мозга).
-- Сторона: везде (чтение локального). Ошибки: handle must be a non-zero number.
function ai.state(h)
    local b = brains[checkHandle(h)]
    return b and b.state or nil
end
