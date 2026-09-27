-- scheduler — таймеры на game.tick: after/every/at + debounce/throttle.
--
-- Время — native.GetGameTime() через pcall; если натива нет или он не число —
-- fallback на os.clock(). ВНИМАНИЕ: os.clock() НЕДЕТЕРМИНИРОВАН между машинами
-- (стенное время кадра), в сети используйте только shared-таймеры от игрового
-- времени; fallback — для меню/клиентских эффектов и тестов.
-- Матч не переживает: автоочистка по game.end и game.menu.
-- Один game.tick-хендлер на всех: подписка ленивая (при первом таймере),
-- снимается когда пусто; подписки game.end/game.menu ставятся лениво вместе
-- с первой и снимаются в clear().
-- Порядок при равном времени детерминирован (монотонный seq).
-- every без backlog: при опоздании максимум 1 догоняющий вызов, дальше now+interval.
-- Ошибка колбэка глушится pcall + лог через rawget(_ENV, "log") (если есть) и дальше.
--
--   local id = scheduler.after(5, function() ... end, { group = "wave" })
--   local rep = scheduler.every(1, function() ... end)
--   scheduler.at(3720.5, function() ... end)
--   scheduler.cancel(id); scheduler.cancelGroup("wave"); scheduler.clear()
--   scheduler.debounce("chat", 0.5, function() ... end)
--   scheduler.throttle("ping", 1.0, function() ... end) -- leading по умолч. true
--   scheduler.now() --> игровое время; scheduler.pending("wave") --> число

scheduler = {}

local timers = {}   -- [id] = { id, seq, fireAt, interval|nil, cb, group, owner }
local nextId = 0
local nextSeq = 0
local tickSub = nil
local endSub = nil
local menuSub = nil
local debMap = {}   -- [key] = timer id (debounce)
local thrLast = {}  -- [key] = last run time (throttle)
local thrPend = {}  -- [key] = timer id (throttle trailing)

-- Текущее время: native.GetGameTime() через pcall, иначе os.clock() (недетерминирован!).
local function curTime()
    local ok, v = pcall(function()
        local n = rawget(_ENV, "native")
        if type(n) ~= "table" then return nil end
        local f = rawget(n, "GetGameTime")
        if type(f) ~= "function" then return nil end
        return f()
    end)
    if ok and type(v) == "number" and v == v then return v end
    local oc = rawget(_ENV, "os")
    if type(oc) == "table" and type(oc.clock) == "function" then
        local ok2, v2 = pcall(oc.clock)
        if ok2 and type(v2) == "number" and v2 == v2 then return v2 end
    end
    return 0
end

-- Ошибка колбэка: в лог мода если есть, иначе молча.
local function reportErr(err)
    local l = rawget(_ENV, "log")
    if type(l) == "table" and type(l.error) == "function" then
        pcall(l.error, err)
    elseif type(l) == "function" then
        pcall(l, err)
    end
end

-- Снять tick-подписку если таймеров не осталось (end/menu живут до clear).
local function maybeUnsubTick()
    if next(timers) == nil and tickSub ~= nil then
        local ev = rawget(_ENV, "events")
        if type(ev) == "table" and type(ev.off) == "function" then
            pcall(ev.off, tickSub)
        end
        tickSub = nil
    end
end

-- Убрать id из debounce/throttle-карт (после срабатывания или отмены).
local function forgetId(id)
    for k, vid in pairs(debMap) do
        if vid == id then debMap[k] = nil end
    end
    for k, vid in pairs(thrPend) do
        if vid == id then thrPend[k] = nil end
    end
end

-- Главный тик: собрать due, отсортировать (fireAt, seq), выполнить через pcall.
local function onTick()
    local t = curTime()
    local due = {}
    for id, e in pairs(timers) do
        if t >= e.fireAt then due[#due + 1] = e end
    end
    if #due == 0 then
        maybeUnsubTick()
        return
    end
    table.sort(due, function(a, b)
        if a.fireAt ~= b.fireAt then return a.fireAt < b.fireAt end
        return a.seq < b.seq
    end)
    for _, e in ipairs(due) do
        local cur = timers[e.id]
        if cur ~= nil then
            if cur.interval == nil then
                timers[e.id] = nil
                local wasThr = nil
                for k, vid in pairs(thrPend) do
                    if vid == e.id then wasThr = k end
                end
                forgetId(e.id)
                if wasThr ~= nil then thrLast[wasThr] = t end
                local ok, err = pcall(cur.cb)
                if not ok then reportErr(err) end
            else
                local ok, err = pcall(cur.cb)
                if not ok then reportErr(err) end
                local still = timers[e.id]
                if still ~= nil then
                    still.fireAt = still.fireAt + still.interval
                    if still.fireAt <= t then
                        still.fireAt = t + still.interval
                    end
                end
            end
        end
    end
    maybeUnsubTick()
end

-- Лениво подписаться на game.tick + game.end/game.menu (снимаются в clear).
local function ensureSubs()
    local ev = rawget(_ENV, "events")
    if type(ev) ~= "table" or type(ev.on) ~= "function" then
        error("scheduler: no events bus (need base events.on/off)", 3)
    end
    if tickSub == nil then
        tickSub = ev.on("game.tick", onTick)
    end
    if endSub == nil then
        endSub = ev.on("game.end", function() scheduler.clear() end)
    end
    if menuSub == nil then
        menuSub = ev.on("game.menu", function() scheduler.clear() end)
    end
end

-- Проверить секунды (>= 0 или > 0).
local function checkSec(v, where, allowZero)
    local n = tonumber(v)
    if not n or n ~= n or n < 0 or (not allowZero and n <= 0) then
        if allowZero then
            error("scheduler." .. where .. ": sec must be a number >= 0", 3)
        else
            error("scheduler." .. where .. ": sec must be a number > 0", 3)
        end
    end
    return n
end

-- Проверить колбэк.
local function checkCb(cb, where)
    if type(cb) ~= "function" then
        error("scheduler." .. where .. ": cb must be a function", 3)
    end
    return cb
end

-- Разобрать opts { group, owner } без мутации входа.
local function checkOpts(opts, where)
    if opts == nil then return nil, nil end
    if type(opts) ~= "table" then
        error("scheduler." .. where .. ": opts must be a table", 3)
    end
    return opts.group, opts.owner
end

-- Текущее время (native.GetGameTime() или os.clock fallback — см. шапку про недетерминизм).
function scheduler.now()
    return curTime()
end

-- Разовый таймер через sec секунд (>= 0). Возвращает id. opts = { group, owner }.
function scheduler.after(sec, cb, opts)
    sec = checkSec(sec, "after", true)
    checkCb(cb, "after")
    local group, owner = checkOpts(opts, "after")
    nextId = nextId + 1
    nextSeq = nextSeq + 1
    local id = nextId
    timers[id] = { id = id, seq = nextSeq, fireAt = curTime() + sec,
                   interval = nil, cb = cb, group = group, owner = owner }
    ensureSubs()
    return id
end

-- Повторяющийся таймер каждые sec секунд (> 0), первый раз через sec. Без backlog.
-- Возвращает id. opts = { group, owner }.
function scheduler.every(sec, cb, opts)
    sec = checkSec(sec, "every", false)
    checkCb(cb, "every")
    local group, owner = checkOpts(opts, "every")
    nextId = nextId + 1
    nextSeq = nextSeq + 1
    local id = nextId
    timers[id] = { id = id, seq = nextSeq, fireAt = curTime() + sec,
                   interval = sec, cb = cb, group = group, owner = owner }
    ensureSubs()
    return id
end

-- Разовый таймер на абсолютное игровое время gameTime. Возвращает id. opts = { group, owner }.
function scheduler.at(gameTime, cb, opts)
    local t = tonumber(gameTime)
    if not t or t ~= t then
        error("scheduler.at: gameTime must be a number", 2)
    end
    checkCb(cb, "at")
    local group, owner = checkOpts(opts, "at")
    nextId = nextId + 1
    nextSeq = nextSeq + 1
    local id = nextId
    timers[id] = { id = id, seq = nextSeq, fireAt = t,
                   interval = nil, cb = cb, group = group, owner = owner }
    ensureSubs()
    return id
end

-- Отменить таймер по id. Возвращает true (был) / false (нет). Ошибок не кидает.
function scheduler.cancel(id)
    if timers[id] ~= nil then
        timers[id] = nil
        forgetId(id)
        maybeUnsubTick()
        return true
    end
    return false
end

-- Отменить все таймеры группы. Возвращает число снятых. group обязателен.
function scheduler.cancelGroup(group)
    if group == nil then
        error("scheduler.cancelGroup: group required", 2)
    end
    local n = 0
    for id, e in pairs(timers) do
        if e.group == group then
            timers[id] = nil
            forgetId(id)
            n = n + 1
        end
    end
    maybeUnsubTick()
    return n
end

-- Снять все таймеры/debounce/throttle и все три подписки. Не переживает матч.
-- Вызывается сам по game.end/game.menu. Ошибок не кидает.
function scheduler.clear()
    for k in pairs(timers) do timers[k] = nil end
    for k in pairs(debMap) do debMap[k] = nil end
    for k in pairs(thrLast) do thrLast[k] = nil end
    for k in pairs(thrPend) do thrPend[k] = nil end
    local ev = rawget(_ENV, "events")
    local function off(id)
        if id ~= nil and type(ev) == "table" and type(ev.off) == "function" then
            pcall(ev.off, id)
        end
    end
    off(tickSub)
    off(endSub)
    off(menuSub)
    tickSub, endSub, menuSub = nil, nil, nil
end

-- Debounce: cb сработает через sec после ПОСЛЕДНЕГО вызова с тем же key.
-- Предыдущий pending с тем же key отменяется. Возвращает id нового таймера.
function scheduler.debounce(key, sec, cb)
    if key == nil then
        error("scheduler.debounce: key required", 2)
    end
    sec = checkSec(sec, "debounce", true)
    checkCb(cb, "debounce")
    local old = debMap[key]
    if old ~= nil and timers[old] ~= nil then
        timers[old] = nil
        forgetId(old)
    end
    nextId = nextId + 1
    nextSeq = nextSeq + 1
    local id = nextId
    timers[id] = { id = id, seq = nextSeq, fireAt = curTime() + sec,
                   interval = nil, cb = function()
                       debMap[key] = nil
                       local ok, err = pcall(cb)
                       if not ok then reportErr(err) end
                   end, group = nil, owner = nil }
    debMap[key] = id
    ensureSubs()
    return id
end

-- Throttle: не чаще 1 раза в sec секунд (> 0) для key.
-- leading true (по умолч.): первый вызов выполняет cb СРАЗУ (pcall), повторные в окне игнорятся.
-- leading false: trailing — планирует на конец окна (last+sec), повторные пока pending игнорятся.
-- Возвращает: 0 — выполнен сразу; id — запланирован trailing; nil — подавлен в окне.
function scheduler.throttle(key, sec, cb, leading)
    if key == nil then
        error("scheduler.throttle: key required", 2)
    end
    sec = checkSec(sec, "throttle", false)
    checkCb(cb, "throttle")
    if leading == nil then
        leading = true
    else
        leading = not not leading
    end
    local t = curTime()
    local last = thrLast[key]
    if last == nil or (t - last) >= sec then
        if leading then
            thrLast[key] = t
            local ok, err = pcall(cb)
            if not ok then reportErr(err) end
            return 0
        else
            local pend = thrPend[key]
            if pend ~= nil and timers[pend] ~= nil then return pend end
            nextId = nextId + 1
            nextSeq = nextSeq + 1
            local id = nextId
            timers[id] = { id = id, seq = nextSeq, fireAt = t + sec,
                           interval = nil, cb = function()
                               thrPend[key] = nil
                               thrLast[key] = curTime()
                               local ok2, err2 = pcall(cb)
                               if not ok2 then reportErr(err2) end
                           end, group = nil, owner = nil }
            thrPend[key] = id
            ensureSubs()
            return id
        end
    else
        if leading then
            return nil
        else
            local pend = thrPend[key]
            if pend ~= nil and timers[pend] ~= nil then return pend end
            local delay = sec - (t - last)
            if delay < 0 then delay = 0 end
            nextId = nextId + 1
            nextSeq = nextSeq + 1
            local id = nextId
            timers[id] = { id = id, seq = nextSeq, fireAt = t + delay,
                           interval = nil, cb = function()
                               thrPend[key] = nil
                               thrLast[key] = curTime()
                               local ok2, err2 = pcall(cb)
                               if not ok2 then reportErr(err2) end
                           end, group = nil, owner = nil }
            thrPend[key] = id
            ensureSubs()
            return id
        end
    end
end

-- Число pending-таймеров (всего или по group). Возвращает integer >= 0.
function scheduler.pending(group)
    local n = 0
    if group == nil then
        for _ in pairs(timers) do n = n + 1 end
    else
        for _, e in pairs(timers) do
            if e.group == group then n = n + 1 end
        end
    end
    return n
end
