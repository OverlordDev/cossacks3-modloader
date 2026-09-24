-- Своя миникарта на CEF, собранная из данных игры (без снимков экрана):
--   рельеф — высоты земли (RayCastHeight) сеткой, один раз за партию;
--   юниты и здания — точки цвета игрока (objects: быстрое чтение памяти), несколько раз в секунду;
--   рамка камеры — точка, куда смотрит камера (GetCameraTargetPosition).
-- Родная миникарта прячется так же, как её прячет сама игра (menu.inc/doinitialize.inc).
-- Клик по нашей миникарте — камера едет туда. Ctrl+M — показать родную рядом (сравнить).

local cfg = {
    fps = 4,        -- обновлений точек в секунду
    grid = 160,     -- клеток рельефа по стороне
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

-- Стартовые точки всех слотов карты — белые пиксели маски генератора (data/gen/terrainmasks/...tga).
-- Границы мирного времени на миникарте игры — между областями, ближайшими к этим точкам.
local function maskStarts()
    local function gen(key)
        for _, tmp in ipairs({ "True", "False" }) do
            local v = game.eval(("ParserGetValueByKeyByHandle(_misc_SelectRecordManagerGeneratorParser(%s), '%s')"):format(tmp, key))
            if v and v ~= "" then return v end
        end
    end
    local dir, name = gen("maskpath"), gen("maskname")
    if not dir or not name then return nil, "маска генератора не найдена" end
    local path = (dir .. "\\" .. name):gsub("^%.[\\/]", "")
    local d = game.readFile(path)
    if not d or #d < 18 then return nil, "не прочитать " .. path end
    local w, h = d:byte(13) + d:byte(14) * 256, d:byte(15) + d:byte(16) * 256
    local bpp, typ, i = d:byte(17) // 8, d:byte(3), 19 + d:byte(1)
    if (typ ~= 2 and typ ~= 10) or bpp < 3 then return nil, "формат маски не поддержан: " .. path end
    local starts, k = {}, 0
    local function pixel(b, g, r)
        if r > 200 and g > 200 and b > 200 then
            local col, row = k % w, k // w           -- строки снизу вверх
            starts[#starts + 1] = { (col + 0.5) / w * mapW - mapW / 2, (row + 0.5) / h * mapH - mapH / 2 }
        end
        k = k + 1
    end
    while k < w * h and i <= #d do
        if typ == 2 then
            pixel(d:byte(i, i + 2)); i = i + bpp
        else
            local c = d:byte(i); i = i + 1
            local n = (c & 127) + 1
            if c >= 128 then
                local b, g, r = d:byte(i, i + 2); i = i + bpp
                for _ = 1, n do pixel(b, g, r) end
            else
                for _ = 1, n do pixel(d:byte(i, i + 2)); i = i + bpp end
            end
        end
    end
    return starts, path
end

-- Рельеф: высоты сеткой grid x grid -> строка чисел (высота * 10, целые), страница раскрасит.
local function sendMap()
    mapW, mapH = native.GetMapWidth(), native.GetMapHeight()
    local n = cfg.grid
    local rows = {}
    local tiles, tileIds, tileNames, tileCount = {}, {}, {}, {}
    local cell = math.max(mapW, mapH) / n
    for gy = 0, n - 1 do
        local z = -mapH / 2 + (gy + 0.5) * mapH / n    -- сверху — меньшие z (как у миникарты игры)
        local row = {}
        for gx = 0, n - 1 do
            local x = -mapW / 2 + (gx + 0.5) * mapW / n
            row[#row + 1] = math.floor((native.RayCastHeight(x, z) or 0) * 10 + 0.5)
            -- Тип земли (трава, поле, грязь...) — им игра и раскрашивает свою миникарту.
            local name = native.GetMapMostFrequentTile(math.floor(x), math.floor(z), cell / 2) or ""
            local id = tileIds[name]
            if not id then
                tileNames[#tileNames + 1] = name
                id = #tileNames
                tileIds[name] = id
                tileCount[id] = 0
            end
            tileCount[id] = tileCount[id] + 1
            tiles[#tiles + 1] = id
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
    local starts, info = maskStarts()
    -- Чей слот: игрок, чья стартовая позиция рядом с точкой слота; пустой слот — -1 (как в FillOwnerMap игры).
    local owners = {}
    for i = 0, 11 do
        local list = objects.list(i)
        if #list > 0 then
            local sx = tonumber(state.get(("gMap.players[%d].startx"):format(i)))
            local sz = tonumber(state.get(("gMap.players[%d].starty"):format(i)))
            if sx and sz then owners[#owners + 1] = { i, sx, sz } end
        end
    end
    local st = {}
    for _, p in ipairs(starts or {}) do
        local who, best = -1, 16 * 16
        for _, o in ipairs(owners) do
            local d = (o[2] - p[1]) ^ 2 + (o[3] - p[2]) ^ 2
            if d < best then best, who = d, o[1] end
        end
        st[#st + 1] = ("[%d,%d,%d]"):format(math.floor(p[1]), math.floor(p[2]), who)
    end
    log.info(starts and ("миникарта: %d стартовых точек из %s"):format(#starts, info) or ("миникарта: " .. info))
    local names = {}
    for i, nm in ipairs(tileNames) do names[i] = ("%q"):format(nm) end
    web.eval(("window.mm && mm.map(%d, %d, %d, [%s], [%s], [%s], [%s], [%s], [%s])"):format(mapW, mapH, n,
        table.concat(rows, ","), table.concat(cs, ","), table.concat(forest, ","), table.concat(tiles, ","),
        table.concat(names, ","), table.concat(st, ",")))
    local stat = {}
    for i, nm in ipairs(tileNames) do stat[#stat + 1] = { nm, tileCount[i] } end
    table.sort(stat, function(a, b) return a[2] > b[2] end)
    local out = {}
    for i = 1, math.min(12, #stat) do out[#out + 1] = ("%s=%d"):format(stat[i][1], stat[i][2]) end
    log.info("миникарта: тайлы земли: " .. table.concat(out, ", "))
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
