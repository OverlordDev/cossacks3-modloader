-- Хост: принимает отпечатки от всех игроков (и от себя), сравнивает при одинаковом игровом времени.
-- Первое расхождение — главное: дальше мир уже разный и расходится всё. Поэтому после первого
-- расхождения просим подробный список юнитов игрока, у которого разошлось, и показываем, какие
-- именно юниты отличаются и чем.

local fps = {}          -- fps[t][who] = отпечаток
local details = {}      -- details[t][who] = { parts, count, got = { [k] = строка } }
local order = {}        -- времена по порядку прихода, для чистки
local lastOk = nil      -- последнее время, когда все совпадали
local reported = false  -- первое расхождение уже описано
local stats = { compared = 0, bad = 0 }

local function name(who) return "игрок " .. tostring(who) end

local function report(text)
    for line in text:gmatch("[^\n]+") do log.error(line) end
    net.broadcast("dw.report", text)
end

local function diffKeys(a, b)
    local keys = {}
    for k, v in pairs(a) do if b[k] ~= v then keys[#keys + 1] = k end end
    for k in pairs(b) do if a[k] == nil then keys[#keys + 1] = k end end
    table.sort(keys)
    return keys
end

local function compare(t)
    local baseWho
    for who in pairs(fps[t]) do
        if not baseWho or who < baseWho then baseWho = who end
    end
    local base = fps[t][baseWho]
    local bad = {}
    for who, c in pairs(fps[t]) do
        if who ~= baseWho then
            local keys = diffKeys(base, c)
            if #keys > 0 then bad[#bad + 1] = { who = who, keys = keys } end
        end
    end
    stats.compared = stats.compared + 1
    if #bad == 0 then
        if not reported then lastOk = t end
        net.broadcast("dw.ok", t)
        return
    end
    stats.bad = stats.bad + 1
    if reported then return end
    reported = true
    local lines = { string.format("РАССИНХРОН на игровом времени %s (последняя сверка без расхождений: %s)",
        t, lastOk or "не было") }
    local firstPlayer
    for _, d in ipairs(bad) do
        lines[#lines + 1] = string.format("  %s против %s: разошлось %s", name(d.who), name(baseWho),
            table.concat(d.keys, ", "))
        firstPlayer = firstPlayer or tonumber(d.keys[1]:match("^p(%d+)%."))
    end
    if firstPlayer then
        lines[#lines + 1] = string.format("  на следующей сверке придёт список юнитов игрока %d", firstPlayer)
        net.broadcast("dw.want", firstPlayer)
    end
    report(table.concat(lines, "\n"))
end

net.on("dw.fp", function(data, from)
    if type(data) ~= "table" or type(data.c) ~= "table" then return end
    local who = game.playerIndexOf(from)
    local t = tostring(data.t)
    if not fps[t] then
        fps[t] = {}
        order[#order + 1] = t
        while #order > 40 do
            local old = table.remove(order, 1)
            fps[old], details[old] = nil, nil
        end
    end
    fps[t][who] = data.c
    local n = 0
    for _ in pairs(fps[t]) do n = n + 1 end
    if n >= 2 then compare(t) end
end)

local function parse(s)
    local map = {}
    for line in s:gmatch("[^\n]+") do
        local uid = line:match("^(%-?%d+):")
        if uid then map[uid] = line end
    end
    return map
end

local function compareDetails(t)
    local sets = {}
    for who, d in pairs(details[t]) do
        if d.count == d.parts then
            local all = {}
            for k = 1, d.parts do all[#all + 1] = d.got[k] end
            sets[#sets + 1] = { who = who, map = parse(table.concat(all, "\n")) }
        end
    end
    if #sets < 2 then return end
    table.sort(sets, function(x, y) return x.who < y.who end)
    local a, b = sets[1], sets[2]
    local uids = {}
    for uid in pairs(a.map) do uids[#uids + 1] = uid end
    for uid in pairs(b.map) do if not a.map[uid] then uids[#uids + 1] = uid end end
    table.sort(uids, function(x, y) return tonumber(x) < tonumber(y) end)
    local lines = { string.format("РАССИНХРОН, юниты на времени %s (%s против %s):", t, name(b.who), name(a.who)) }
    local n = 0
    for _, uid in ipairs(uids) do
        local la, lb = a.map[uid], b.map[uid]
        if la ~= lb then
            n = n + 1
            if n <= 10 then
                lines[#lines + 1] = "  " .. name(a.who) .. ": " .. (la or uid .. ": нет такого юнита")
                lines[#lines + 1] = "  " .. name(b.who) .. ": " .. (lb or uid .. ": нет такого юнита")
            end
        end
    end
    lines[#lines + 1] = string.format("  отличается юнитов: %d из %d", n, #uids)
    report(table.concat(lines, "\n"))
    details[t] = nil
end

net.on("dw.detail", function(data, from)
    if type(data) ~= "table" then return end
    local who = game.playerIndexOf(from)
    local t = tostring(data.t)
    details[t] = details[t] or {}
    local d = details[t][who]
    if not d then
        d = { parts = tonumber(data.parts) or 1, got = {}, count = 0 }
        details[t][who] = d
    end
    local k = tonumber(data.part) or 1
    if not d.got[k] then d.count = d.count + 1 end
    d.got[k] = tostring(data.s or "")
    compareDetails(t)
end)

events.on("game.start", function()
    fps, details, order = {}, {}, {}
    lastOk, reported = nil, false
    stats.compared, stats.bad = 0, 0
end)

-- Раз в минуту — сводка. Если отпечатки приходят, а сверок нет, значит в момент снимка у игроков
-- было разное игровое время (кадр перескочил шаг симуляции) — это тоже видно по этой строке.
local lastSummary = os.clock()
events.on("game.tick", function()
    if os.clock() - lastSummary < 60 then return end
    lastSummary = os.clock()
    local single = 0
    for _, rec in pairs(fps) do
        local n = 0
        for _ in pairs(rec) do n = n + 1 end
        if n == 1 then single = single + 1 end
    end
    log.info(string.format("сверок: %d, с расхождением: %d; снимков без пары по времени (из последних %d): %d",
        stats.compared, stats.bad, #order, single))
end)
