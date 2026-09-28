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

-- screens.list(): все экраны по именам. Возврат: список строк, отсортирован.
-- Сторона: shared (везде). Ошибок не кидает.
function screens.list()
    local out = {}
    for name in pairs(DATA) do out[#out + 1] = name end
    table.sort(out)
    return out
end

-- screens.info(name): описание экрана. Парам: name — имя экрана. Возврат: { name, show, event, tags }.
-- Сторона: shared. Ошибки: "unknown screen" при неверном имени.
function screens.info(name)
    local s = info(name)
    return { name = name, show = s.show, event = s.event, tags = s.tags }
end

-- screens.tags(name): кнопки экрана. Парам: name — имя экрана. Возврат: таблица имя -> тэг.
-- Сторона: shared. Ошибки: "unknown screen" при неверном имени.
function screens.tags(name) return info(name).tags end

-- screens.button(name, tag): имя кнопки по тэгу. Парам: name — экран; tag — число.
-- Возврат: имя кнопки; неизвестный тэг — числом строкой. Ошибок не кидает.
function screens.button(name, tag)
    for k, v in pairs(info(name).tags) do
        if v == tag then return k end
    end
    return tostring(tag)
end

-- screens.of(state): имя экрана по состоянию ("EventMainMenu"/"ShowMainMenu" -> "MainMenu").
-- Парам: state — имя состояния. Возврат: имя экрана или nil. Ошибок не кидает.
function screens.of(state)
    for name, s in pairs(DATA) do
        if s.event == state or s.show == state then return name end
    end
end

-- screens.open(name): показать экран. Парам: name — имя экрана.
-- Сторона: client (мод) и server/shared/страница. Ошибки: "unknown screen", "has no Show state".
function screens.open(name)
    local s = info(name)
    if not s.show then error("screens.open: '" .. name .. "' has no Show state", 2) end
    -- Со страницы (game.api) ui нет — там работают с правами сервера и зовут игру напрямую.
    --
    -- Имя состояния уходит АРГУМЕНТОМ, а не в текст кода: движок кэширует
    -- скомпилированный Pascal по тексту, и каждый новый текст — это состояние
    -- ModLoader.Call.N, живущее до конца партии (освободить его нельзя,
    -- ScriptRunner.cpp). С именем в тексте каждый экран съедал своё состояние;
    -- теперь на все экраны один текст.
    if ui then ui.exec(s.show) else game.exec("GUIExecuteState(ML_ARG);", s.show) end
end

-- screens.press(name, button): нажать кнопку экрана. Парам: name — экран; button — имя или тэг.
-- Сторона: client (мод) и server/shared/страница. Ошибки: "unknown screen/button", "has no Event state".
function screens.press(name, button)
    local s = info(name)
    if not s.event then error("screens.press: '" .. name .. "' has no Event state", 2) end
    local tag = tagOf(s, name, button)
    if ui then
        ui.sendTag(s.event, tag)
    else
        -- И тэг, и имя состояния — аргументом (см. screens.open). Тэгов у экранов
        -- много, поэтому с тэгом в тексте состояния множились по числу нажатых
        -- кнопок, а не по числу экранов.
        --
        -- Число идёт первым и режется по '|', имя — остатком строки: остаток не
        -- режем, поэтому его содержимое ничего не ломает. Строки — функциями
        -- движка: Pos/Copy в этом диалекте Pascal нет (tools/check_pascal.py).
        game.exec([[
var s : String = ML_ARG;
var q, tag : Integer;
q := StrPos('|', s); tag := StrToInt(SubStr(s, 1, q-1)); s := SubStr(s, q+1, StrLength(s)-q);
_gui_SendTagToState(s, tag);]],
                  math.floor(tonumber(tag) or 0) .. "|" .. s.event)
    end
end

local function modOnly()
    error("screens: onButton/onAnyButton/replace work only inside a mod (client.lua)", 3)
end
screens.onButton, screens.onAnyButton, screens.replace = modOnly, modOnly, modOnly

-- screens.bind(modUi): копия screens для мода (перехваты через его ui, снимаются при выгрузке).
-- Парам: modUi — ui мода. Возврат: таблица screens. Зовёт модлоадер сам, вручную не вызывать.
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
