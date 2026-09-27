-- shared.lua — боевая логика «Железного Фронтира». Выполняется ОДИНАКОВО у всех
-- в сети (это lockstep-игра), поэтому здесь запрещено всё недетерминированное:
--   * os.time / os.clock для игровых решений — только для логов
--   * pairs по изменяемым таблицам там, где порядок влияет на игру
--   * накопительные вычисления с плавающей точкой по кадрам
-- Всё, что меняет мир, обязано быть здесь, а не в client.lua.

local R = require("lib/registry")
local C = require("lib/census")

local IF = {}

-- ═════════════════════════════════════════════════════════════════════════════
-- Баланс
-- ═════════════════════════════════════════════════════════════════════════════
-- content.lua просит maxhp/damage у модлоадера, и он правит игровые СКРИПТЫ
-- (_unit_InitBase и подобные). Но таблицы TObjBase/TObjProp, из которых движок
-- читает статы в партии, остаются родными. Поэтому дублируем через balance.* —
-- иначе значения из content.lua не подействуют на созданные таблицы.
local function applyBalance()
    local ok, fail = 0, 0
    for _, u in ipairs(R.UNITS) do
        local good, err = pcall(function()
            balance.set(u.sid, "maxhp", u.hp)
            balance.set(u.sid, "weapon[1].damage", u.dmg)
            balance.set(u.sid, "price[0]", u.price)
            balance.setProp(u.sid, "vision", u.vision)
        end)
        if good then ok = ok + 1
        else
            fail = fail + 1
            log.warn("[IF] balance " .. u.sid .. ": " .. tostring(err))
        end
    end
    balance.refresh()
    log.info(string.format("[IF] баланс применён: %d типов, ошибок %d", ok, fail))
    return ok, fail
end

IF.applyBalance = applyBalance
IF.role = C.role
IF.roleDef = C.roleDef
IF.isArty = C.isArty
IF.report = C.report
IF.line = C.line

-- ═════════════════════════════════════════════════════════════════════════════
-- Жизненный цикл
-- ═════════════════════════════════════════════════════════════════════════════
-- Счётчик тиков: обычный целый счётчик, детерминирован.
local tick = 0

events.on("game.start", function()
    log.info("[IF] «Железный Фронтир» 0.1.0 — 19 век, 1812-1815")
    applyBalance()
    C.rescan()
    log.info("[IF] " .. C.line())
    net.broadcast("if.census", C.snapshot())     -- клиенту census недоступен
end)

-- save.afterload идёт ПОСЛЕ game.start, поэтому после загрузки сейва нужен
-- повторный проход: без него юниты, бывшие в сейве, не попадут в кэш.
events.on("save.afterload", function()
    C.rescan()
    log.info("[IF] после загрузки: " .. C.line())
    net.broadcast("if.census", C.snapshot())
end)

events.on("game.tick", function()
    tick = tick + 1
    -- Раз в ~5 с: пересчёт и рассылка. Пересчёт сам чистит мёртвые хендли —
    -- сверяемся с движком, а не доверяем событиям: событие может не прийти,
    -- а мёртвый хендль трогать нельзя (краш C0000005, CPP_FIX_REPORT.md).
    if tick % 300 == 0 then
        C.rescan()
        net.broadcast("if.census", C.snapshot())
    end
end)

-- ── Команды от клиента ───────────────────────────────────────────────────────
-- КЛАВИШИ ЗДЕСЬ НЕ БИНДИМ: input существует только в client-окружении
-- (AI_MODDING_REFERENCE §4.12 "input (client)"). Обращение к нему из shared
-- роняет мод при загрузке — проверено 2026-09-27: "shared.lua:80: attempt to
-- index a nil value (global 'input')". Клиент шлёт net.send, сервер отвечает.
net.on("if.rebalance", function(_, from)
    applyBalance()
    log.info("[IF] переприменение баланса по запросу " .. tostring(from))
end)

net.on("if.census", function(_, from)
    -- ответ клиенту не шлём: census и так есть на его стороне (census.lua
    -- только читает и одинаково считается на всех машинах).
    log.info("[IF] запрос состава от " .. tostring(from) .. ": " .. C.line())
end)

return IF
