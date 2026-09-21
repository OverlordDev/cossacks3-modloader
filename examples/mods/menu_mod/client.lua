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

ui.screen("MainMenu", function()
    -- Игра перестраивает экран не один раз (смена разрешения, возврат из подменю), а страницу
    -- достаточно открыть однажды: перезагружать её на каждый вызов — только мигать зря.
    if not web.isOpen() then
        web.open("menu")
        log.info("главное меню: страница открыта")
    end
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
    if not loadingShown then showLoading() end
end)

-- Выход из партии: страница меню должна вернуться, даже если игра успела построить родное меню.
events.on("game.menu", function()
    if not web.isOpen() then web.open("menu") end
end)

events.on("game.start", function()
    loadingShown = false
    web.close()
end)

-- Подстраховка: если game.start почему-то не придёт, страница не должна остаться
-- поверх партии и забирать себе мышь.
events.on("game.tick", function()
    if web.isOpen() then
        web.close()
    end
end)

log.info("menu_mod ready — меню и настройки на HTML (web/)")
