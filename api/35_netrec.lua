-- netrec — сетевой рекордер: что случилось перед рассинхроном.
--
-- Дополнение к builtin/desync_watchdog (он сравнивает отпечатки между машинами).
-- netrec пишет ЛОКАЛЬНЫЙ журнал: шаги симуляции, приказы, хеши — после рассинхрона
-- логи с двух машин кладутся рядом и видно первый разошедшийся шаг и последнюю команду.
-- Работает в shared (у всех одинаково пишет своё). В одиночке тоже полезен для отладки.
--
--   netrec.start()                        -- начать запись (обычно в game.start)
--   netrec.start{ hashEvery = 5 }         -- хеш каждые 5 sync-шагов (по умолчанию 10)
--   netrec.stop()                         -- остановить и снять подписки
--   log.info(netrec.report())             -- последние шаги + последние приказы + сводка
--   netrec.dump()                         -- то же в лог ошибкой (видно в modloader.log)
--
-- Шаг — событие net.sync (все машины выполняют его на одном шаге симуляции).
-- Хеш шага — лёгкий: число объектов + ресурсы игроков (не полный снимок!).

netrec = {}

local rec = { on = false, step = 0, steps = {}, orders = {}, subs = {},
              hashEvery = 10, maxSteps = 200, maxOrders = 100 }

local function hash()
    local n = 0
    if objects and objects.list then
        local ok, list = pcall(objects.list)
        if ok and type(list) == "table" then n = #list end
    end
    local res = {}
    if players and players.resources then
        for _, p in ipairs(players.list()) do
            local ok, r = pcall(players.resources, p.index)
            if ok and type(r) == "table" then
                res[#res + 1] = string.format("p%d=%d/%d/%d", p.index,
                    r.gold or 0, r.wood or 0, r.food or 0)
            end
        end
    end
    return string.format("obj=%d %s", n, table.concat(res, " "))
end

-- start(opts): начать запись (сбрасывает старую). Парам: opts.hashEvery — хеш каждые N sync-шагов (по умолч. 10).
-- Только память (shared/client), мир не меняет. Ошибки: opts не таблица.
function netrec.start(opts)
    if rec.on then netrec.stop() end
    opts = opts or {}
    if type(opts) ~= "table" then error("netrec.start: opts must be a table", 2) end
    rec.hashEvery = math.tointeger(tonumber(opts.hashEvery or 10)) or 10
    if rec.hashEvery < 1 then rec.hashEvery = 1 end
    rec.on, rec.step = true, 0
    rec.steps, rec.orders = {}, {}
    rec.subs = {
        events.on("net.sync", function()
            rec.step = rec.step + 1
            if rec.step % rec.hashEvery == 0 then
                rec.steps[#rec.steps + 1] = { step = rec.step, h = hash() }
                while #rec.steps > rec.maxSteps do table.remove(rec.steps, 1) end
            end
        end),
        events.on("unit.order", function(_, h, kind, target, x, z)
            rec.orders[#rec.orders + 1] = { step = rec.step, h = h,
                kind = tostring(kind), target = target, x = x, z = z }
            while #rec.orders > rec.maxOrders do table.remove(rec.orders, 1) end
        end),
        events.on("game.end", function() netrec.stop() end),
    }
end

-- stop(): остановить запись и снять подписки (сама вызывается в game.end). Возврат: nil. Ошибок не кидает.
function netrec.stop()
    for _, id in ipairs(rec.subs) do pcall(events.off, id) end
    rec.subs, rec.on = {}, false
end

-- isOn(): идёт ли запись. Возврат: true/false. Только чтение, ошибок не кидает.
function netrec.isOn()
    return rec.on
end

-- step(): текущий sync-шаг (события net.sync). Возврат: integer. Только чтение, ошибок не кидает.
function netrec.step()
    return rec.step
end

-- report(): сводка строкой: шаг, последние хеши и приказы. Возврат: string. Только чтение, ошибок не кидает.
function netrec.report()
    local out = { string.format("netrec: step=%d, шагов с хешем=%d, приказов=%d",
        rec.step, #rec.steps, #rec.orders) }
    local from = math.max(1, #rec.steps - 9)
    for i = from, #rec.steps do
        out[#out + 1] = string.format("  step %d: %s", rec.steps[i].step, rec.steps[i].h)
    end
    local ofrom = math.max(1, #rec.orders - 9)
    for i = ofrom, #rec.orders do
        local o = rec.orders[i]
        out[#out + 1] = string.format("  order@%d: h=%s %s tgt=%s x=%.1f z=%.1f",
            o.step, tostring(o.h), o.kind, tostring(o.target),
            tonumber(o.x) or 0, tonumber(o.z) or 0)
    end
    return table.concat(out, "\n")
end

local function say(text)
    local l = rawget(_ENV, "log")
    if l and l.error then l.error(text) return end
    local pr = rawget(_ENV, "print")
    if pr then pr(text) end
end

-- dump(): тот же отчёт в лог построчно (log.error, иначе print). Возврат: nil. Ошибок не кидает.
function netrec.dump()
    for line in netrec.report():gmatch("[^\n]+") do say(line) end
end
