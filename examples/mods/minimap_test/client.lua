-- Своя миникарта на CEF. Шаг 1: картинка — сама миникарта игры, снятая с экрана.
--
-- GUIMiniMapSaveToBitmap игры отдаёт мусор (проверено), поэтому снимаем кадр сами: gfx.capture берёт
-- прямоугольник кадра в момент вывода, ДО того как поверх нарисована страница. Родная миникарта
-- рисуется как обычно (иначе снимать нечего), а страница закрывает её место непрозрачной панелью.
-- Ctrl+M — показать/закрыть родную (сравнить).

local cfg = {
    fps = 10,  -- снимков в секунду
}

local opened = false
local rect = nil            -- где на экране рамка миникарты игры: x, y, w, h (пиксели окна)
local lastSave, lastCheck = 0, 0
local covered = true
local file = "modloader\\mods\\" .. mod.id .. "\\web\\mm.bmp"   -- от папки игры

local function ourPage() return web.isOpen() and web.url():find("minimap_test/web/minimap%.html") ~= nil end

-- Прямоугольник рамки миникарты — элемент интерфейса 'minimap' (menu.inc/doinitialize.inc).
local function findRect()
    local h = game.evalInt("GetGUIElementIndexByNameParent('minimap', _gui_GetTop)")
    if not h or h == 0 then return nil end
    return { x = native.GetGUIElementPositionX(h), y = native.GetGUIElementPositionY(h),
             w = native.GetGUIElementWidth(h), h = native.GetGUIElementHeight(h) }
end

local function sendCover()
    if rect then
        web.eval(("window.mm && mm.cover(%d, %d, %d, %d, %s)"):format(rect.x, rect.y, rect.w, rect.h, tostring(covered)))
    end
end

events.on("game.tick", function()
    local now = os.clock()
    if now - lastCheck >= 1 then
        lastCheck = now
        if state.get("gMap.gamestage") >= 2 then
            local r = findRect()
            local moved = r and (not rect or r.x ~= rect.x or r.y ~= rect.y or r.w ~= rect.w or r.h ~= rect.h)
            if moved then
                rect = r
                log.info(("миникарта игры: рамка x=%d y=%d %dx%d; сама карта: позиция %.0f,%.0f размер %.0fx%.0f, %s/%s")
                    :format(r.x, r.y, r.w, r.h, native.GetGUIMiniMapPositionX(), native.GetGUIMiniMapPositionY(),
                            native.GetGUIMiniMapWidth(), native.GetGUIMiniMapHeight(),
                            native.GetGUIMiniMapHAlign(), native.GetGUIMiniMapVAlign()))
            end
            if not ourPage() then       -- страницу мог занять другой мод или экран загрузки
                web.open("minimap.html")
                web.passthrough(true)
                opened = true
                moved = true
            end
            if moved then sendCover() end
        end
    end
    if not opened or not rect or now - lastSave < 1 / cfg.fps or not ourPage() then return end
    lastSave = now
    gfx.capture(file, rect.x, rect.y, rect.w, rect.h)
    web.eval("window.mm && mm.show('mm.bmp')")
end)

events.on("game.end", function()
    opened, rect = false, nil
    web.passthrough(false)
end)

input.bind("Ctrl+M", function()
    if not game.isInGame() then return end
    covered = not covered
    sendCover()
    log.info(covered and "родная миникарта закрыта страницей" or "родная миникарта видна (сравнить)")
end)

if game.isInGame() then opened = false end -- .lua reload посреди партии
