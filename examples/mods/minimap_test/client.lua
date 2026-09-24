-- Своя миникарта на CEF, собранная из данных игры (без снимков экрана):
--   рельеф — высоты земли (RayCastHeight) сеткой, один раз за партию;
--   юниты и здания — точки цвета игрока (objects: быстрое чтение памяти), несколько раз в секунду;
--   рамка камеры — точка, куда смотрит камера (GetCameraTargetPosition).
-- Родная миникарта прячется так же, как её прячет сама игра (menu.inc/doinitialize.inc).
-- Клик по нашей миникарте — камера едет туда. Ctrl+M — показать родную рядом (сравнить).

local cfg = {
    fps = 4,        -- обновлений точек в секунду
    grid = 96,      -- клеток рельефа по стороне
}

local opened, sentMap = false, false
local lastSend, lastCheck = 0, 0
local showNative = false
local mapW, mapH = 0, 0
local colors = {}   -- игрок -> "#rrggbb"

local function ourPage() return web.isOpen() and web.url():find("minimap_test/web/minimap%.html") ~= nil end

local function nativeMinimap(visible)
    native.SetGUIMiniMapVisible(visible)
    local h = game.evalInt("GetGUIElementIndexByNameParent('minimap', _gui_GetTop)")
    if h and h ~= 0 then native.SetGUIElementVisible(h, visible) end
end

-- Цвет игрока: индекс цвета из лобби -> gKeyColor (так игра красит юнитов).
local function playerColor(i)
    local ci = state.get(("gMap.players[%d].color"):format(i))
    if not ci then return "#ffffff" end
    local c = {}
    for k = 0, 2 do
        local v = tonumber(state.get(("gKeyColor[%d][%d]"):format(ci, k))) or 1
        if v <= 1 then v = v * 255 end
        c[k + 1] = math.max(0, math.min(255, math.floor(v + 0.5)))
    end
    return ("#%02x%02x%02x"):format(c[1], c[2], c[3])
end

-- Рельеф: высоты сеткой grid x grid -> строка чисел (высота * 10, целые), страница раскрасит.
local function sendMap()
    mapW, mapH = native.GetMapWidth(), native.GetMapHeight()
    local n = cfg.grid
    local rows = {}
    for gy = 0, n - 1 do
        local z = -mapH / 2 + (gy + 0.5) * mapH / n    -- сверху — меньшие z (как у миникарты игры)
        local row = {}
        for gx = 0, n - 1 do
            local x = -mapW / 2 + (gx + 0.5) * mapW / n
            row[#row + 1] = math.floor((native.RayCastHeight(x, z) or 0) * 10 + 0.5)
        end
        rows[#rows + 1] = table.concat(row, ",")
    end
    -- Леса и камни: объекты «природы» (игрок 12) — сколько их в каждой клетке. Тёмные пятна, как у игры.
    local forest = {}
    for k = 1, n * n do forest[k] = 0 end
    for _, h in ipairs(objects.list(12)) do
        local x, z = objects.pos(h)
        if x then
            local gx = math.floor((x + mapW / 2) / mapW * n)
            local gy = math.floor((z + mapH / 2) / mapH * n)
            if gx >= 0 and gx < n and gy >= 0 and gy < n then
                local k = gy * n + gx + 1
                forest[k] = forest[k] + 1
            end
        end
    end
    for i = 0, 11 do colors[i] = playerColor(i) end
    local cs = {}
    for i = 0, 11 do cs[#cs + 1] = ("%q"):format(colors[i]) end
    web.eval(("window.mm && mm.map(%d, %d, %d, [%s], [%s], [%s])"):format(mapW, mapH, n, table.concat(rows, ","),
        table.concat(cs, ","), table.concat(forest, ",")))
    sentMap = true
end

-- Точки: "игрок,x,z,здание;..." — координаты мира, целые.
local function sendUnits()
    local parts = {}
    for i = 0, 11 do
        for _, h in ipairs(objects.list(i)) do
            local o = objects.get(h, "hp")
            if o and o > 0 then
                local x, z = objects.pos(h)
                if x then
                    local b = objects.get(h, "bbuilt") and 1 or 0
                    parts[#parts + 1] = ("%d,%d,%d,%d"):format(i, math.floor(x), math.floor(z), b)
                end
            end
        end
    end
    -- Куда смотрит камера: луч от камеры через её цель до земли (цель бывает не на земле).
    local cx, cz
    local ex, ey, ez = native.GetCameraAbsolutePosition()
    local tx, ty, tz = native.GetCameraTargetPosition()
    if ex and tx then
        local ground = native.RayCastHeight(tx, tz) or 0
        local t = (ey - ty) ~= 0 and (ey - ground) / (ey - ty) or 1
        cx, cz = ex + (tx - ex) * t, ez + (tz - ez) * t
    end
    web.eval(("window.mm && mm.units(%q, %s, %s)"):format(table.concat(parts, ";"),
        tostring(cx and math.floor(cx) or "null"), tostring(cz and math.floor(cz) or "null")))
end

events.on("game.tick", function()
    local now = os.clock()
    if now - lastCheck >= 1 then
        lastCheck = now
        if state.get("gMap.gamestage") >= 2 then
            if not ourPage() then       -- страницу мог занять другой мод или экран загрузки
                web.open("minimap.html")
                web.passthrough(true)
                opened, sentMap = true, false
                return                  -- страница грузится — данные со следующего раза
            end
            nativeMinimap(showNative)   -- игра возвращает её при смене размера окна
            if not sentMap then
                local t0 = os.clock()
                sendMap()
                log.info(("миникарта: карта %dx%d, рельеф %dx%d за %.0f мс"):format(mapW, mapH, cfg.grid, cfg.grid,
                    (os.clock() - t0) * 1000))
            end
        end
    end
    if not opened or not sentMap or now - lastSend < 1 / cfg.fps or not ourPage() then return end
    lastSend = now
    sendUnits()
end)

events.on("game.end", function()
    opened, sentMap = false, false
    web.passthrough(false)
end)

input.bind("Ctrl+M", function()
    if not game.isInGame() then return end
    showNative = not showNative
    nativeMinimap(showNative)
    log.info(showNative and "родная миникарта видна (сравнить)" or "родная миникарта спрятана")
end)

if game.isInGame() then opened, sentMap = false, false end -- .lua reload посреди партии
