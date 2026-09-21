-- Главное меню и настройки на HTML.
--
-- Родные экраны игры не строятся вообще: ui.screen перехватывает состояние, и вместо
-- паскалевского кода игры на экран выходит страница, нарисованная Chromium.
--
-- Кнопки в страницах зовут game.tag('<Event...>', <тэг>) — это те же обработчики, что у родных
-- кнопок, поэтому кампания, настройки и выход работают без единой строки своей логики.
-- Тэги смотреть в data/gui/menu.inc/eventmainmenu.inc и showsettings.inc.
--
-- Вёрстка — в web/. Править её можно без перезапуска игры: команда .web reload.

-- Перейти на страницу, не перезагружая её, если она уже открыта: игра перестраивает экраны
-- по нескольку раз (смена разрешения, возврат из подменю), и перезагрузка на каждый раз — мигание.
local function goTo(page)
    if web.isOpen() then
        web.eval(string.format("if (!location.pathname.endsWith('/%s.html')) location.href = '%s.html'", page, page))
    else
        web.open(page)
    end
end

ui.screen("MainMenu", function()
    goTo("menu")
end)

ui.screen("Settings", function()
    -- Значения страница спрашивает сама: game.lua теперь возвращает ответ.
    web.open("settings")
    log.info("настройки: страница открыта")
end)

ui.screen("LoadGame", function()
    -- Список сохранений страница читает сама нативами UserGetProfileSave*.
    web.open("loadgame")
    log.info("загрузка игры: страница открыта")
end)

ui.screen("News", function() end)

-- Остальные экраны меню (случайная карта, кампании, мультиплеер...) — родные экраны игры:
-- menu.html закрывает браузер, и дальше рисует игра. Флаг партии — чтобы знать, что мы в бою.
local inGame = false

-- Экран загрузки партии. Родной прогресс-бар игры остаётся под нашей страницей и не виден:
-- слой браузера рисуется поверх всего кадра.
--
-- game.prepare — игра начала готовить партию (DoNewGame), game.start — партия построена.

-- Новая партия (случайная карта, кампания): игра вызывает DoNewGame. Загрузку сохранения это
-- событие не ловит — там экран показывает сама страница загрузки, сразу после нажатия.
-- Список картинок передаём странице сразу: пока игра генерирует карту, она почти не отвечает
-- на запросы, и страница, спрашивающая сама, осталась бы без картинок.
local function slidesJs()
    local names = {}
    for _, name in ipairs(mod.files("LoadScreen")) do
        if name:lower():match("%.png$") or name:lower():match("%.jpe?g$") or name:lower():match("%.webp$") then
            names[#names + 1] = '"' .. name:gsub('[\\"]', "\\%0") .. '"'
        end
    end
    return "setSlides([" .. table.concat(names, ",") .. "], 7)"
end

-- Случайная карта: как только игра начинает генерировать карту, она перестаёт рисовать кадры,
-- и открытая в этот момент страница не успевает появиться. Поэтому «Начать игру» придерживаем:
-- сначала показываем экран загрузки, а страница, уже нарисовав первую картинку, сама жмёт кнопку
-- ещё раз (startWhenShown в loading.html) — второе нажатие пропускаем к игре.
local loadingShown, letStartThrough = false, false

local function showLoading()
    inGame = true
    web.open("loading")
    web.eval(slidesJs())
    loadingShown = true
    log.info("загрузка партии: страница открыта")
end

screens.onButton("CustomGame", function(button, tag)
    if button ~= "StartGame" then return end
    if letStartThrough then
        letStartThrough = false
        return -- второе нажатие — от страницы: пусть игра начинает
    end
    showLoading()
    letStartThrough = true
    web.eval(string.format("startWhenShown('%s', %d)", screens.info("CustomGame").event, tag))
    return true
end)

-- Остальные пути в партию (кампания, миссии) — экран загрузки открываем здесь.
events.on("game.prepare", function()
    inGame = true
    if not loadingShown then showLoading() end
end)

-- Выход из партии: страница меню должна вернуться, даже если игра успела построить родное меню.
events.on("game.menu", function()
    inGame = false
    if not web.isOpen() then web.open("menu") end
end)

-- Когда убирать экран загрузки. game.start для этого рано: партия уже «игровая», но игра ещё
-- догружает карту и показывает свой экран загрузки (gMap.gamestage = 1, ждём игроков/загрузку).
-- Убираем страницу, только когда партия реально пошла: gamestage >= 2 (gc_map_gamestage_started).
local STAGE_STARTED = 2

events.on("game.tick", function()
    -- Закрываем только свой экран загрузки: в партии страницу могут открыть другие моды (HUD).
    if web.isOpen() and web.url():find("loading%.html") and state.get("gMap.gamestage") >= STAGE_STARTED then
        loadingShown = false
        web.close()
    end
end)

events.on("game.start", function() inGame = true end)
