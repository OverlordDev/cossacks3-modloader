-- Своя миникарта на CEF. Шаг 1: картинка — сама миникарта игры.
--
-- Движок умеет сохранить миникарту в файл (GUIMiniMapSaveToBitmap). Сохраняем её несколько раз в секунду
-- в папку страницы, по очереди в два файла (пока страница читает один, пишем другой), и говорим странице,
-- какой показать. Родную миникарту и её рамку прячем.
--
-- Как прятать — вопрос для теста: вдруг спрятанная миникарта перестаёт обновляться. Ctrl+M переключает:
--   1 — SetGUIMiniMapVisible(false) (так её прячет сама игра, если в настройках выключена миникарта)
--   2 — оставить видимой, но унести за экран
--   3 — не прятать (сравнить свою с родной)

local cfg = {
    fps = 4,  -- сколько раз в секунду обновлять картинку
}

local mode = 1
local modes = { "скрыта (Visible false)", "унесена за экран", "не скрыта (для сравнения)" }
local opened = false
local lastSave, lastCheck = 0, 0
local flip = false
local origin = nil        -- где миникарта стояла у игры (вернуть в режиме 3)
local dir = "modloader\\mods\\" .. mod.id .. "\\web\\"  -- путь от папки игры: так движок пишет файлы

local function ourPage() return web.isOpen() and web.url():find("minimap_test/web/minimap%.html") ~= nil end

local function frame(visible)
    -- Рамка миникарты — элемент интерфейса 'minimap' (так же её прячет сама игра, menu.inc/doinitialize.inc).
    local h = game.evalInt("GetGUIElementIndexByNameParent('minimap', _gui_GetTop)")
    if h and h ~= 0 then native.SetGUIElementVisible(h, visible) end
end

local function hideNative()
    if not origin then
        origin = { native.GetGUIMiniMapPositionX(), native.GetGUIMiniMapPositionY(), native.GetGUIMiniMapPositionZ() }
    end
    if mode == 1 then
        native.SetGUIMiniMapVisible(false)
        frame(false)
    elseif mode == 2 then
        native.SetGUIMiniMapVisible(true)
        native.SetGUIMiniMapPosition(-10000, -10000, origin[3])
        frame(false)
    else
        native.SetGUIMiniMapVisible(true)
        native.SetGUIMiniMapPosition(origin[1], origin[2], origin[3])
        frame(true)
    end
end

events.on("game.tick", function()
    local now = os.clock()
    if now - lastCheck >= 1 then
        lastCheck = now
        if state.get("gMap.gamestage") >= 2 then
            if not ourPage() then       -- страницу мог занять другой мод или экран загрузки
                web.open("minimap.html")
                web.passthrough(true)
                if not opened then
                    log.info(("миникарта: текстура игры %dx%d, режим %d — %s. Ctrl+M — сменить"):format(
                        native.GetGUIMiniMapTextureWidth(), native.GetGUIMiniMapTextureHeight(), mode, modes[mode]))
                end
                opened = true
            end
            hideNative() -- игра возвращает миникарту при смене размера окна и т.п.
        end
    end
    if not opened or now - lastSave < 1 / cfg.fps or not ourPage() then return end
    lastSave = now
    flip = not flip
    local file = flip and "mm_a.bmp" or "mm_b.bmp"
    native.GUIMiniMapSaveToBitmap(dir .. file)
    web.eval(("window.mm && mm.show(%q)"):format(file))
end)

events.on("game.end", function()
    opened, origin = false, nil
    web.passthrough(false)
end)

input.bind("Ctrl+M", function()
    if not game.isInGame() then return end
    mode = mode % 3 + 1
    hideNative()
    log.info(("миникарта игры: %d — %s"):format(mode, modes[mode]))
    web.eval(("window.mm && mm.mode(%q)"):format(modes[mode]))
end)

if game.isInGame() then opened = false end -- .lua reload посреди партии
