-- client.lua — интерфейс и визуальная часть «Железного Фронтира».
--
-- Здесь НЕЛЬЗЯ менять мир: в сети исход боя решает хост, а не клиент.
-- Только чтение состояния, панели, камера, эффекты, звук.
-- Всё, что влияет на бой, живёт в shared.lua.
--
-- shared.lua отсюда НЕ require-им: он загрузился бы вторым экземпляром в
-- окружении клиента, где balance/game.exec недоступны, а события зарегистрировались
-- бы дважды. Общая часть вынесена в lib/census.lua — он только читает.

local R = require("lib/registry")
local C = require("lib/census")

local panel = false

-- census строится ТОЛЬКО на server/shared: query.scan внутри ходит в игру через
-- game.exec, которого на клиенте нет. Поэтому клиент просто хранит снимок,
-- пришедший по сети (shared рассылает net.broadcast "if.census" раз в 5 с).
net.on("if.census", function(data) C.accept(data) end)

events.on("game.start", function()
    log.info("[IF] client: жду состав армии от сервера")
end)

-- F5 — панель состава. Периодически, а не каждый кадр.
input.bind("F5", function() panel = not panel end)

-- F6 — подробный отчёт по ростеру.
input.bind("F6", function()
    local s = C.snapshot()
    log.info("[IF] " .. C.line())
    local sids = {}
    for sid in pairs(s.census) do sids[#sids + 1] = sid end
    table.sort(sids)
    if #sids == 0 then
        log.info("[IF] снимок ещё не пришёл от сервера (подожди пару секунд)")
    end
    for _, sid in ipairs(sids) do
        log.info(string.format("   %-10s %d", sid, s.census[sid]))
    end
end)

-- F7 — переприменить баланс. Баланс меняет ТОЛЬКО server/shared, поэтому клиент
-- не может сделать это сам и отправляет команду. Так же, как стенд шлёт ast.run.
input.bind("F7", function()
    net.send("if.rebalance", {})
    log.info("[IF] запрос на переприменение баланса отправлен")
end)

local tick = 0
events.on("game.tick", function()
    tick = tick + 1
    if panel and tick % 60 == 0 then log.info("[IF] " .. C.line()) end
end)

-- Состав ростера нации — для будущей панели выбора стороны.
function IFcensus(nation)
    local sids = R.sidsOf(nation)
    log.info("[IF] ростер " .. nation .. ": " .. table.concat(sids, ", "))
    return sids
end
_G.IFcensus = IFcensus

-- Раскладка ролей — чтобы не искать в коде.
function IFroles()
    local names = {}
    for role, def in pairs(R.ROLE) do
        names[#names + 1] = string.format("%s=%s/строй %s/мораль %.1f",
            role, def.name, def.formation, def.moraleLoss)
    end
    table.sort(names)
    log.info("[IF] роли:\n  " .. table.concat(names, "\n  "))
    return names
end
_G.IFroles = IFroles
