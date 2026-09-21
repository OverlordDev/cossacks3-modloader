-- screens — экраны игры и их кнопки по именам.
--
-- Экран игры = два состояния GUI: Show<Имя> строит его, Event<Имя> обрабатывает нажатия.
-- Кнопки различаются тэгом, имена тэгов взяты из скриптов игры (02_screens_data.lua, GAME_SCREENS.md).
--
--   screens.list()                          --> { "AIAssistant", "Campaign", "MainMenu", ... }
--   screens.tags("MainMenu")                --> { Campaign = 101, Settings = 104, Exit = 109, ... }
--   screens.button("MainMenu", 104)         --> "Settings"
--   screens.open("Settings")                --  показать экран (как игра)
--   screens.press("MainMenu", "Settings")   --  нажать кнопку экрана (как игрок)
--
-- Только в модах (клиент):
--   screens.onButton("MainMenu", function(button, tag, element)
--       log.info("нажата", button)
--       -- return true  -- игра это нажатие НЕ обработает (заменили своим)
--   end)
--   screens.onAnyButton(function(screen, button, tag, element) ... end)   -- все экраны сразу
--   screens.replace("Settings", function() web.open("settings") end)     -- вместо родного экрана
--
-- Замена экрана на свою страницу — одна строка screens.replace; кнопки страницы жмут
-- родные обработчики через game.tag('EventMainMenu', 104) или game.api('screens.press', 'MainMenu', 'Settings').

local DATA = GAME_SCREENS or error("screens: GAME_SCREENS is missing (api/02_screens_data.lua)")

screens = {}

local function info(name)
    local s = DATA[name]
    if not s then error("screens: unknown screen '" .. tostring(name) .. "' (see GAME_SCREENS.md)", 3) end
    return s
end

local function tagOf(s, name, button)
    if type(button) == "number" then return button end
    local tag = s.tags[button]
    if not tag then error("screens: screen '" .. name .. "' has no button '" .. tostring(button) .. "'", 3) end
    return tag
end

function screens.list()
    local out = {}
    for name in pairs(DATA) do out[#out + 1] = name end
    table.sort(out)
    return out
end

function screens.info(name)
    local s = info(name)
    return { name = name, show = s.show, event = s.event, tags = s.tags }
end

function screens.tags(name) return info(name).tags end

-- Имя кнопки по тэгу; у неизвестных — число строкой.
function screens.button(name, tag)
    for k, v in pairs(info(name).tags) do
        if v == tag then return k end
    end
    return tostring(tag)
end

-- Имя экрана по имени состояния: "EventMainMenu" / "ShowMainMenu" -> "MainMenu".
function screens.of(state)
    for name, s in pairs(DATA) do
        if s.event == state or s.show == state then return name end
    end
end

function screens.open(name)
    local s = info(name)
    if not s.show then error("screens.open: '" .. name .. "' has no Show state", 2) end
    ui.exec(s.show)
end

function screens.press(name, button)
    local s = info(name)
    if not s.event then error("screens.press: '" .. name .. "' has no Event state", 2) end
    ui.sendTag(s.event, tagOf(s, name, button))
end

local function modOnly()
    error("screens: onButton/onAnyButton/replace work only inside a mod (client.lua)", 3)
end
screens.onButton, screens.onAnyButton, screens.replace = modOnly, modOnly, modOnly

-- Своя копия для мода: перехваты идут через ui мода и снимаются при его выгрузке.
-- Зовёт модлоадер при создании окружения мода, самим вызывать не нужно.
function screens.bind(modUi)
    local own = setmetatable({}, { __index = screens })

    function own.onButton(name, fn)
        local s = info(name)
        if not s.event then error("screens.onButton: '" .. name .. "' has no Event state", 2) end
        modUi.hookState(s.event, function(element, press, tag)
            if press ~= "c" then return end -- только щелчок: игра зовёт Event и на наведение
            return fn(screens.button(name, tag), tag, element)
        end)
    end

    function own.onAnyButton(fn)
        for _, name in ipairs(screens.list()) do
            if DATA[name].event then
                own.onButton(name, function(button, tag, element)
                    return fn(name, button, tag, element)
                end)
            end
        end
    end

    function own.replace(name, fn)
        local s = info(name)
        if not s.show then error("screens.replace: '" .. name .. "' has no Show state", 2) end
        modUi.screen(s.show, fn)
    end

    return own
end
