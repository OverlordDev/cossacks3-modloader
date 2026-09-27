-- economy — абстрактные ресурсы модов: топливо, боеприпасы, снабжение.
--
-- Хранится в savedata мода (живёт внутри сейвов игры!), меняется на server/shared,
-- читается везде. Ключ — "eco:<player>:<res>".
--
--   economy.set(0, "fuel", 100)                       -- выдать
--   economy.add(0, "fuel", -20)                       -- списать (false, если не хватает)
--   economy.get(0, "fuel")                            --> 80
--   economy.produce(h, "musketeer18", { time = 30, cost = { fuel = 10 }, amount = 5 })
--       -- через time секунд закажет 5 юнитов в здании h (если хватило ресурсов)
--
-- produce списывает cost СРАЗУ (бронь), при отмене деньги не возвращаются —
-- держите cost маленьким или стройте через buildings.produce напрямую.

economy = {}

local jobs = {}
local sub = nil
local store = nil   -- savedata есть только у мода: economy.link(savedata) в server/shared

-- Привязать хранилище мода (один раз в server/shared записи):
--   economy.link(savedata)
function economy.link(s)
    if type(s) ~= "table" or type(s.get) ~= "function" or type(s.set) ~= "function" then
        error("economy.link: pass mod savedata", 2)
    end
    store = s
end

local function needStore(where)
    if not store then
        error("economy." .. where .. ": call economy.link(savedata) in your entry first", 3)
    end
    return store
end

local function needServer(where)
    if not game.exec then
        error("economy." .. where .. ": only server/shared scripts can change resources", 3)
    end
end

local function key(player, res)
    if type(res) ~= "string" or res == "" then error("economy: res must be a non-empty string", 3) end
    return "eco:" .. tostring(player) .. ":" .. res
end

local function num(v, name)
    local n = tonumber(v)
    if not n or n ~= n then error("economy: " .. name .. " must be a number", 3) end
    return n
end

-- economy.get(player, res): сколько ресурса у игрока. Возврат: число (0, если нет). Сторона: везде (чтение).
function economy.get(player, res)
    local value = needStore("get").get(key(player, res))
    if value == nil then return 0 end
    local n = tonumber(value)
    -- savedata старых версий/чужого мода может вернуть число как строку. Внутри
    -- economy наружу всегда выходит число, иначе add/consume падают на `string + number`.
    return n or 0
end

-- economy.set(player, res, amount): задать количество ресурса. Сторона: только server/shared.
function economy.set(player, res, amount)
    needServer("set")
    needStore("set").set(key(player, res), num(amount, "amount"))
end

-- Списать amount (положительное). Возвращает true или false (не хватает).
function economy.consume(player, res, amount)
    needServer("consume")
    amount = num(amount, "amount")
    if amount < 0 then error("economy.consume: amount must be >= 0", 2) end
    local have = economy.get(player, res)
    if have < amount then return false end
    needStore("consume").set(key(player, res), have - amount)
    return true
end

-- economy.add(player, res, amount): прибавить (amount может быть отрицательным). Возврат: true/false (false — ушло бы в минус).
-- Сторона: только server/shared.
function economy.add(player, res, amount)
    needServer("add")
    amount = num(amount, "amount")
    local have = economy.get(player, res)
    if have + amount < 0 then return false end
    needStore("add").set(key(player, res), have + amount)
    return true
end

local function ensureTick()
    if sub then return end
    sub = events.on("game.tick", function()
        if not game.isInGame() then return end
        local now = os.clock()
        for id, j in pairs(jobs) do
            if now >= j.at then
                jobs[id] = nil
                if game.isInGame() then
                    pcall(buildings.produce, j.building, j.unit, j.amount)
                    if j.onDone then pcall(j.onDone, id) end
                end
            end
        end
        if not next(jobs) and sub then events.off(sub) sub = nil end
    end)
end

-- Заказать производство: стоимость списывается сразу, юнит встанет в очередь через time с.
function economy.produce(building, unitSid, opts)
    needServer("produce")
    if type(unitSid) ~= "string" or unitSid == "" then
        error("economy.produce: unitSid must be a non-empty string", 2)
    end
    opts = opts or {}
    local player = num(opts.player or 0, "player")
    for res, amount in pairs(opts.cost or {}) do
        if not economy.consume(player, res, amount) then
            return false, "not enough " .. res
        end
    end
    local id = "eco" .. tostring(os.clock())
    jobs[id] = { at = os.clock() + num(opts.time or 10, "time"), building = building,
                 unit = unitSid, amount = opts.amount or 1, onDone = opts.onDone }
    ensureTick()
    return true, id
end

-- economy.cancel(id): отменить отложенный заказ из produce. Нет задачи — no-op. Сторона: везде.
function economy.cancel(id)
    jobs[id] = nil
end
