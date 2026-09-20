-- Своё главное меню.
--
-- Интерфейс игры — это состояния скриптовой машины (data/gui/menu.aix): ShowMainMenu строит главное
-- меню, EventMainMenu обрабатывает нажатия. ui.screen перехватывает построение: родной код состояния
-- не выполняется вообще, вместо него зовётся наша функция и рисует экран теми же средствами, что игра.
--
-- Нажатия отправляем в родной EventMainMenu через ui.sendTag — логику кампании, мультиплеера и выхода
-- переписывать не нужно, меняется только внешний вид.
--
-- Выравнивание бывает двух видов, и это главная ловушка: "left"/"middle" считаются от ЭКРАНА,
-- "parentLeft"/"parentMiddle" — от родительского элемента. Всё, что лежит внутри контейнера, должно
-- выравниваться parent*, иначе улетит к краю экрана.
--
-- Имена элементов важны: полное имя складывается из имён родителей через точку. Игра сама прячет и
-- показывает колонку меню по имени "MainMenu.col1" (см. eventmainmenu.inc), поэтому свой экран
-- строим в такой же паре контейнеров — тогда переходы в кампанию, настройки и обратно работают как были.

-- Тэги родных кнопок (см. data/gui/menu.inc/eventmainmenu.inc).
local TAG = {
    encyclopedia = 100,
    campaign     = 101,
    randomMap    = 102,
    multiplayer  = 103,
    settings     = 104,
    loadGame     = 105,
    loadReplay   = 106,
    editor       = 107,
    modManager   = 108,
    exit         = 109,
    tutorial     = 110,
}

-- Порядок и вид кнопок. locale — ключ строки игры, чтобы меню было на языке игрока.
local ITEMS = {
    { tag = TAG.campaign,    locale = { "gui", "menu.btn.campaign" },    big = true },
    { tag = TAG.multiplayer, locale = { "gui", "menu.btn.multiplayer" }, big = true },
    { tag = TAG.randomMap,   locale = { "gui", "menu.btn.randommap" } },
    { tag = TAG.loadGame,    locale = { "gui", "menu.btn.loadgame" } },
    { tag = TAG.settings,    locale = { "gui", "menu.btn.settings" } },
    { tag = TAG.editor,      locale = { "gui", "menu.btn.editor" } },
    { tag = TAG.exit,        locale = { "gui", "menu.btn.exit" },        big = true },
}

local GOLD = { 255, 220, 170, 255 }
local PALE = { 190, 190, 190, 255 }

-- Кнопки — своя картинка отдельными файлами (assets/data/hud/textures/mods/menu_mod/btn.*.tga),
-- материалы собирает tools/make_materials.py. Текстура одна, 512x110; размер кнопки задаём здесь,
-- движок растянет. Родные кнопки игры — "btn.large" и "btn.medium" без w/h.
local BTN_BIG   = { material = "menu_mod.btn", w = 268, h = 58 }
local BTN_SMALL = { material = "menu_mod.btn", w = 232, h = 50 }

-- Отладка вёрстки: каждый созданный элемент — в лог, как его видит движок (ui.dump).
local DEBUG = false
local made = {}
local function keep(name, h)
    made[#made + 1] = { name = name, h = h }
    return h
end

ui.screen("MainMenu", function()
    made = {}
    local w, h = ui.size()
    local colW = math.floor(w * 0.24)

    -- Корень экрана — контейнер, а не картинка: элемент прямо под верхним уровнем интерфейса движок
    -- создаёт скрытым, ui.container показывает его сам. Имя обязано совпадать с именем состояния без
    -- Show, иначе игра не найдёт наши элементы, когда будет прятать меню.
    local root = keep("root", ui.container{ name = "MainMenu", x = 0, y = 0, w = w, h = h })
    -- Фон — своя картинка: assets/data/hud/textures/ui/mainmenu_art.bmp подменяет файл игры.
    -- Материал в hud.mat — область 1674x1024, поэтому растягиваем её по большей стороне и обрезаем
    -- лишнее по краям: пропорции не едут на любом разрешении.
    local artW, artH = ui.imageSize("mainmenu_art")
    local scale = math.max(w / artW, h / artH)
    keep("bcg", ui.image{ name = "bcg", parent = root, material = "mainmenu_art", align = "middle",
                          x = 0, y = 0, w = math.floor(artW * scale), h = math.floor(artH * scale) })

    -- Колонка меню — по центру экрана. Игра прячет и показывает её по имени "MainMenu.col1".
    local col = keep("col1", ui.container{ name = "col1", parent = root, align = { "parentMiddle", "parentTop" },
                                           x = 0, y = 0, w = colW, h = h })
    -- Если фон окажется слишком пёстрым и кнопки перестанут читаться, сюда вернётся затемнение:
    --   local shade = ui.image{ name = "shade", parent = col, material = "misc.color.black",
    --                           align = { "parentLeft", "parentTop" }, x = 0, y = 0, w = colW, h = h }
    --   ui.setBlend(shade, 0.7)
    -- Выравнивание обязано быть parent*, иначе элемент прилипнет к краю ЭКРАНА, а не контейнера.

    -- Всё внутри колонки выравниваем по её середине — экран переживает смену разрешения.
    local center = { "parentMiddle", "parentTop" }

    local y = math.floor(h * 0.12)
    keep("logo", ui.image{ name = "logo", parent = col, material = "logo_small", align = center, x = 0, y = y })

    local _, logoH = ui.imageSize("logo_small")
    y = y + logoH + 20
    keep("title", ui.text{ name = "title", parent = col, text = "MODDED", align = center, x = 0, y = y,
             font = "gc_font_serif_15", color = GOLD })

    y = y + 44
    for _, item in ipairs(ITEMS) do
        local tag = item.tag
        local btn = item.big and BTN_BIG or BTN_SMALL
        keep("b" .. tag, ui.button{
            name     = "b" .. tag,
            parent   = col,
            text     = ui.locale(item.locale[1], item.locale[2]),
            material = btn.material,
            align    = center,
            x        = 0,
            y        = y,
            w        = btn.w,
            h        = btn.h,
            tag      = tag,
            -- Нажатие уходит родному обработчику: кампания, мультиплеер, настройки и выход работают как были.
            onClick  = function() ui.sendTag("EventMainMenu", tag) end,
        })
        y = y + btn.h + 8
    end

    ui.text{ name = "ver", parent = col, text = "menu_mod " .. mod.version, align = center,
             x = 0, y = h - 40, font = "gc_font_serif_10", color = PALE }

    log.info("custom main menu drawn (" .. w .. "x" .. h .. ")")

    if DEBUG then
        local top = ui.find("top")
        log.info("top = " .. ui.dump(top) .. ", children = " .. (top and #ui.children(top) or -1))
        for _, e in ipairs(made) do
            log.info("  " .. e.name .. ": " .. ui.dump(e.h))
        end
    end
end)

-- Панель новостей игра рисует отдельным состоянием (ShowNews), поверх главного меню. Перехватываем
-- и его: функция ничего не рисует, а раз она не вернула false — родной экран не строится.
ui.screen("News", function() end)

log.info("menu_mod ready — main menu is drawn by the mod")
