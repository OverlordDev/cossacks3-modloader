-- Инспектор — клиентская половина: клавиша, страница и поток событий.
--
-- Почти всё делает сама страница: со страницы доступны game.api('модуль.функция', ...)
-- и game.lua(...), то есть весь api модлоадера. Здесь остаётся то, чего страница
-- сама не может: горячая клавиша и подписка на события (события живут в Lua мода,
-- на страницу их надо пересылать).

-- ─── Когда инспектор вообще включается ──────────────────────────────────────
--
-- Страница исполняет Lua с правами сервера, то есть может менять мир. В сетевой
-- партии это пульт для читерства, поэтому включаемся ТОЛЬКО в режиме
-- разработчика (есть modloader/dev.txt) — там же, где модлоадер уже разрешает
-- себе F9 с ресурсами и выгрузку по End.
--
-- Игроку без dev.txt инспектора просто нет: ни клавиши, ни страницы.
if not game.dev then
    return
end

local PAGE = "devtools.html"
local open = false

-- ─── Поток событий ──────────────────────────────────────────────────────────
-- Кольцевой буфер: страница может быть закрыта, и копить бесконечно незачем.
local LIMIT = 200
-- Имя буфера НЕ events: так называется таблица API событий, и локал её
-- перекрыл бы — events.on перестал бы существовать.
local ring, first, count = {}, 1, 0

-- Аргументы событий приходят ПОЗИЦИОННО и у разных событий разные, поэтому
-- складываем их как есть, а показывать будем строкой.
local function remember(name, ...)
    local parts = {}
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        parts[#parts + 1] = type(v) == "table" and "{…}" or tostring(v)
    end
    local at = (first + count - 1) % LIMIT + 1
    if count < LIMIT then count = count + 1 else first = first % LIMIT + 1 end
    ring[at] = { t = os.date("%H:%M:%S"), name = name, args = table.concat(parts, ", ") }
end

-- События, за которыми имеет смысл следить при разработке мода. Тик и net.sync
-- НЕ берём: они идут десятки раз в секунду и утопят всё остальное.
for _, name in ipairs({ "game.start", "game.end", "game.menu", "game.prepare",
                        "unit.spawn", "unit.death", "unit.destroy", "unit.order", "unit.damage",
                        "building.spawn", "building.death", "building.destroy",
                        "player.order", "save.afterload",
                        "net.connect", "net.disconnect", "net.msg" }) do
    events.on(name, function(...) remember(name, ...) end)
end

-- Страница спрашивает события через api, но api у неё — серверный, а буфер
-- здесь, на клиенте. Поэтому шлём сами: web.eval вызывает функцию на странице.
local function pushEvents()
    if not open then return end
    local out = {}
    for i = 0, count - 1 do
        local e = ring[(first + i - 1) % LIMIT + 1]
        if e then
            out[#out + 1] = string.format("{t:%q,name:%q,args:%q}", e.t, e.name, e.args)
        end
    end
    web.eval("window.devtoolsEvents && devtoolsEvents([" .. table.concat(out, ",") .. "])")
end

-- ─── Клавиша ────────────────────────────────────────────────────────────────
-- Ctrl+I: Insert занят меню модлоадера, F9/End/F12 — самим модлоадером в
-- dev-режиме, F1-F8 разбирают примеры модов.
input.bind("Ctrl+I", function()
    if open then
        open = false
        web.close()
        log.info("[инспектор] закрыт")
        return
    end
    open = true
    web.open(PAGE)
    -- Прозрачные места пропускают мышь в игру: можно выделять юнитов, не закрывая
    -- панель. Ради этого панель и занимает только полосу справа.
    web.passthrough(true)
    log.info("[инспектор] открыт (Ctrl+I — закрыть)")
end)

-- Раз в полсекунды подкидываем странице события. Чаще незачем: человек читает
-- глазами, а лишние web.eval — это работа в потоке игры.
local tick = 0
events.on("game.tick", function()
    tick = tick + 1
    if tick % 30 ~= 0 then return end
    if open and not web.isOpen() then
        open = false          -- страницу закрыли не нами (например, другим модом)
        return
    end
    pushEvents()
end)

log.info("[инспектор] готов: Ctrl+I")
