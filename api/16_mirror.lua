-- mirror — родной интерфейс игры как данные: что сейчас на экране и как на это нажать.
--
-- Страница mirror.html (menu_mod/web) рисует по этим данным любой экран игры в HTML, а нажатия
-- отдаёт обратно в игру — обрабатывает их родная логика. Так любой экран получает новый вид без
-- переписывания его кода.
--
--   mirror.snapshot()              --> { width, height, items = { {id, kind, x, y, w, h, text, ...}, ... } }
--   mirror.click(id)               --  нажать кнопку/чекбокс (как мышью)
--   mirror.select(id, index)       --  выбрать строку списка или выпадающего списка
--   mirror.input(id, text)         --  ввести текст в поле
--
-- kind: "button", "checkbox", "combo", "list", "input", "text", "image", "panel".
-- Элемент попадает в снимок, только если виден он сам и все его родители.

mirror = {}

local N = native

-- Пустые и служебные картинки не рисуем: на странице свой фон.
local function isDecor(material)
    return material == "" or material == "misc.blank" or material:find("^blank")
end

local function classOf(h)
    local ok, name = pcall(N.GetObjectClassNameByHandle, h)
    return ok and name or ""
end

local function kindOf(h, class, press, material)
    if class == "TXGuiComboBox" then return "combo" end
    if class == "TXGuiListBox" then return "list" end
    if class == "TXEditControl" then return "input" end
    local normal = N.GetGUIElementStateNormalMaterial(h)
    if press ~= "" and normal:find("^checkbox") then return "checkbox" end
    if press ~= "" then return "button" end
    if N.GetGUIElementText(h) ~= "" then return "text" end
    if not isDecor(material) then return "image" end
    return nil
end

local function items(h)
    local out = {}
    for i = 0, N.GetGUIListBoxItemsCount(h) - 1 do
        out[#out + 1] = N.GetGUIListBoxItemValue(h, i)
    end
    return out
end

local function walk(h, out, depth)
    if depth > 40 or not N.GetGUIElementVisible(h) then return end

    local class = classOf(h)
    local press = N.GetGUIElementPressState(h)
    local material = N.GetGUIElementMaterial(h)
    local kind = kindOf(h, class, press, material)

    if kind then
        local x, y, w, hh = N.GetGUIElementBoundingBox(h)
        if w > 0 and hh > 0 then
            local e = {
                id = h, kind = kind, x = x, y = y, w = w, h = hh,
                text = N.GetGUIElementText(h),
                name = N.GetGUIElementNameByIndex(h),
                hint = N.GetGUIElementHint(h),
                tag = N.GetGUIElementTag(h),
                enabled = N.GetGUIElementEnabled(h),
                material = material,
                z = depth,
            }
            if kind == "checkbox" then e.checked = N.GetGUIElementChecked(h) end
            if kind == "combo" or kind == "list" then
                e.items = items(h)
                e.selected = N.GetGUIListBoxItemIndex(h)
            end
            out[#out + 1] = e
        end
        -- Строки списков — его собственные дочерние элементы, их уже отдали в items.
        if kind == "combo" or kind == "list" or kind == "input" then return end
    end

    for i = 0, N.GetGUIElementChildrenCount(h) - 1 do
        walk(N.GetGUIElementChildrenByIndex(h, i), out, depth + 1)
    end
end

function mirror.snapshot()
    local top = N.GetGUIElementTopIndexByName("top")
    local out = {}
    if top ~= 0 then walk(top, out, 0) end
    return { width = N.GetViewerWidth(), height = N.GetViewerHeight(), items = out }
end

-- Нажатие уходит в состояние, которое игра назначила элементу, с теми же переменными, что ставит
-- сама игра при щелчке мышью (см. _gui_SendTagToStateExt в data/scripts/lib/gui.script).
local function send(h, status)
    local state = N.GetGUIElementPressState(h)
    if state == "" or not state:match("^[%w_]+$") then
        error("mirror: element " .. tostring(h) .. " has no press state", 3)
    end
    game.exec(string.format("_gui_SendTagToStateExt('%s', %d, 'c', 'LButton', '%s', %d);",
        state, N.GetGUIElementTag(h), status, h))
end

function mirror.click(h)
    if N.GetGUIElementStateNormalMaterial(h):find("^checkbox") then
        N.SetGUIElementChecked(h, not N.GetGUIElementChecked(h))
    end
    send(h, "button")
end

function mirror.select(h, index)
    N.SetGUIListBoxItemIndexSilent(h, index)
    send(h, "select")
end

function mirror.input(h, text)
    N.SetGUIElementText(h, text)
    if N.GetGUIElementPressState(h) ~= "" then send(h, "change") end
end
