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

-- Часть нативов падает на элементах «не своего» класса (GetGUIElementText на картинке или
-- слое — нарушение доступа внутри игры). Модлоадер ловит это и превращает в ошибку Lua,
-- а здесь она означает просто «у элемента этого свойства нет».
local N = setmetatable({}, { __index = function(_, name)
    local f = native[name]
    return function(...)
        local ok, a, b, c, d = pcall(f, ...)
        if ok then return a, b, c, d end
        return nil
    end
end })

-- Классы, у которых текст точно есть; у остальных GetGUIElementText не зовём вовсе.
local TEXT_CLASSES = { TOSWBaseGuiTextControl = true, TXEditControl = true, TXGuiComboBox = true }
local function textOf(h, class, press)
    if not TEXT_CLASSES[class] and press == "" then return "" end
    return N.GetGUIElementText(h) or ""
end

-- Пустые и служебные картинки не рисуем: на странице свой фон.
local function isDecor(material)
    return material == "" or material == "misc.blank" or material:find("^blank")
end

local function classOf(h)
    return N.GetObjectClassNameByHandle(h) or ""
end

local function kindOf(h, class, press, material)
    if class == "TXGuiComboBox" then return "combo" end
    if class == "TXGuiListBox" then return "list" end
    if class == "TXEditControl" then return "input" end
    local normal = press ~= "" and N.GetGUIElementStateNormalMaterial(h) or ""
    if normal:find("^checkbox") then return "checkbox" end
    if press ~= "" then return "button" end
    if textOf(h, class, press) ~= "" then return "text" end
    if not isDecor(material) then return "image" end
    return nil
end

local function items(h)
    local out = {}
    for i = 0, (N.GetGUIListBoxItemsCount(h) or 0) - 1 do
        out[#out + 1] = N.GetGUIListBoxItemValue(h, i) or ""
    end
    return out
end

local stats

local function walk(h, out, depth)
    stats.visited = stats.visited + 1
    if depth > 40 or N.GetGUIElementVisible(h) == false then
        stats.hidden = stats.hidden + 1
        return
    end

    local class = classOf(h)
    -- Интерфейс партии (HUD) живёт в том же дереве и в меню числится видимым — не наш экран.
    if class == "TXGroupHUDCollection" then return end
    local press = N.GetGUIElementPressState(h) or ""
    local material = N.GetGUIElementMaterial(h) or ""
    local kind = kindOf(h, class, press, material)

    if kind then
        -- Рамка у движка: y отсчитывается вверх от верхнего края экрана, высота отрицательная
        -- (сверху вниз). Переводим в обычные экранные координаты.
        local x, y, w, hh = N.GetGUIElementBoundingBox(h)
        if x then y, hh = -y, math.abs(hh) end
        if x and w > 0 and hh > 0 then
            local e = {
                id = h, kind = kind, x = x, y = y, w = w, h = hh,
                text = textOf(h, class, press),
                name = N.GetGUIElementNameByIndex(h) or "",
                hint = N.GetGUIElementHint(h) or "",
                tag = N.GetGUIElementTag(h) or 0,
                enabled = N.GetGUIElementEnabled(h) ~= false,
                material = material,
                z = depth,
            }
            if kind == "checkbox" then e.checked = N.GetGUIElementChecked(h) == true end
            if kind == "combo" or kind == "list" then
                e.items = items(h)
                e.selected = N.GetGUIListBoxItemIndex(h) or -1
            end
            out[#out + 1] = e
        end
        -- Строки списков — его собственные дочерние элементы, их уже отдали в items.
        if kind == "combo" or kind == "list" or kind == "input" then return end
    end

    for i = 0, (N.GetGUIElementChildrenCount(h) or 0) - 1 do
        local child = N.GetGUIElementChildrenByIndex(h, i)
        if child and child ~= 0 then walk(child, out, depth + 1) end
    end
end

function mirror.snapshot()
    local top = N.GetGUIElementTopIndexByName("top")
    local out = {}
    stats = { top = top or 0, visited = 0, hidden = 0 }
    if top and top ~= 0 then walk(top, out, 0) end
    -- stats — чтобы по пустому снимку было видно, где потерялись элементы.
    return { width = N.GetViewerWidth(), height = N.GetViewerHeight(), items = out, stats = stats }
end

-- Нажатие уходит в состояние, которое игра назначила элементу, с теми же переменными, что ставит
-- сама игра при щелчке мышью (см. _gui_SendTagToStateExt в data/scripts/lib/gui.script).
local function send(h, status)
    local state = N.GetGUIElementPressState(h) or ""
    if state == "" or not state:match("^[%w_]+$") then
        error("mirror: element " .. tostring(h) .. " has no press state", 3)
    end
    game.exec(string.format("_gui_SendTagToStateExt('%s', %d, 'c', 'LButton', '%s', %d);",
        state, N.GetGUIElementTag(h) or 0, status, h))
end

function mirror.click(h)
    if (N.GetGUIElementStateNormalMaterial(h) or ""):find("^checkbox") then
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
    if (N.GetGUIElementPressState(h) or "") ~= "" then send(h, "change") end
end

-- Отладка: сырые ответы нативов по первым видимым элементам (с текстом ошибки, если натив упал).
--   =mirror.debug(8)
function mirror.debug(limit)
    local rows, count = {}, 0
    local function raw(name, ...)
        local ok, a, b, c, d = pcall(native[name], ...)
        if not ok then return "ERR " .. tostring(a) end
        if b ~= nil then return table.concat({ tostring(a), tostring(b), tostring(c), tostring(d) }, ",") end
        return tostring(a)
    end
    local function visit(h, depth)
        if count >= (limit or 8) or depth > 40 then return end
        if raw("GetGUIElementVisible", h) == "true" and depth > 0 then
            count = count + 1
            rows[#rows + 1] = string.format("%d d=%d vis class=%s name=%s press=%s mat=%s box=%s",
                h, depth, raw("GetObjectClassNameByHandle", h), raw("GetGUIElementNameByIndex", h),
                raw("GetGUIElementPressState", h), raw("GetGUIElementMaterial", h),
                raw("GetGUIElementBoundingBox", h))
        end
        local n = tonumber(raw("GetGUIElementChildrenCount", h)) or 0
        for i = 0, n - 1 do visit(tonumber(raw("GetGUIElementChildrenByIndex", h, i)), depth + 1) end
    end
    visit(native.GetGUIElementTopIndexByName("top"), 0)
    return table.concat(rows, "\n")
end
