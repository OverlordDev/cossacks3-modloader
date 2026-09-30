-- gui — родные элементы интерфейса без CEF: панели, кнопки, текст.
--
-- Только client. Это те же элементы, что рисует сама игра (ui.*), собранные
-- в один API: создать, подвинуть, показать, клик, убрать. Для кнопок внутри
-- городских панелей — parent = хендл панели (найдите через ui.find).
--
--   local p = gui.create("panel", { name = "shop", x = 100, y = 100, w = 300, h = 200 })
--   local b = gui.create("button", { parent = p, text = "Авиаудар" })
--   gui.onClick(b, function() net.send("airstrike.request", {}) end)
--   gui.position(b, 120, 140)                 -- gui.size(b, 200, 40)
--   gui.text(b, "Новый текст")                -- gui.show(b, false); gui.remove(b)
--
-- Типы: panel (контейнер), button, label (текст), image (материал игры).

gui = {}

-- Счётчик имён: os.clock() даёт"lbl67.328" — точка в имени ломает ui.text
-- (проверено 2026-09-27: ui.text 'lbl67.328' failed). Поэтому простой счётчик.
local autoName = 0

local function nextName()
    autoName = autoName + 1
    return tostring(autoName)
end
local modUi = nil   -- ui мода (button/onClick живут только там): gui.link(ui)

-- Привязать ui мода (один раз в client.lua): gui.link(ui).
function gui.link(t)
    if type(t) ~= "table" then error("gui.link: pass mod ui", 2) end
    modUi = t
end

local function U()
    return modUi or ui
end

local function checkUi()
    local u = U()
    if not u or not u.container then
        error("gui: needs client ui (call from client.lua, not from pages)", 3)
    end
    return u
end

local function num(v, name)
    local n = tonumber(v)
    if not n or n ~= n then error("gui: " .. name .. " must be a number", 3) end
    return n
end

-- gui.create(kind, opts): создать элемент (panel/button/label/image). Парам: kind — тип; opts — parent/pos/size/text/material.
-- Возвращает хендл. Сторона: только client. Ошибки: неизвестный kind; image без material; button без gui.link(ui).
function gui.create(kind, opts)
    local ui = checkUi()
    opts = opts or {}
    if type(opts) ~= "table" then error("gui.create: opts must be a table", 2) end
    local parent = opts.parent or 0
    if kind == "panel" then
        return ui.container({ name = opts.name or ("gui" .. nextName()),
            parent = parent, x = opts.x or 0, y = opts.y or 0,
            w = opts.w or 200, h = opts.h or 100 })
    elseif kind == "button" then
        if not modUi or not ui.button then
            error("gui.create: button needs gui.link(ui) in client.lua", 2)
        end
        return ui.button({ name = opts.name or ("btn" .. nextName()),
            parent = parent, text = opts.text or "OK",
            x = opts.x or 0, y = opts.y or 0, w = opts.w or 0, h = opts.h or 0,
            material = opts.material or "btn.large", hint = opts.hint or "",
            tag = opts.tag or 0,
            onClick = opts.onClick })
    elseif kind == "label" then
        return ui.text({ name = opts.name or ("lbl" .. nextName()),
            parent = parent, text = opts.text or "",
            x = opts.x or 0, y = opts.y or 0, w = opts.w or 0, h = opts.h or 0,
            font = opts.font or "gc_font_serif_15" })
    elseif kind == "image" then
        if not opts.material then error("gui.create: image needs material", 2) end
        return ui.image({ name = opts.name or ("img" .. nextName()),
            parent = parent, material = opts.material,
            x = opts.x or 0, y = opts.y or 0, w = opts.w or 0, h = opts.h or 0 })
    end
    error("gui.create: unknown kind '" .. tostring(kind) .. "' (panel/button/label/image)", 2)
end

-- gui.onClick(h, fn): клик по кнопке. Парам: h — хендл; fn — функция. Ничего не возвращает. Сторона: только client.
function gui.onClick(h, fn)
    local ui = checkUi()
    if not modUi or not ui.onClick then
        error("gui.onClick: needs gui.link(ui) in client.lua", 2)
    end
    if type(fn) ~= "function" then error("gui.onClick: fn must be a function", 2) end
    ui.onClick(h, fn)
end

-- gui.position(h, x, y): подвинуть элемент. Парам: h — хендл; x, y — числа. Ничего не возвращает. Сторона: только client.
function gui.position(h, x, y)
    local ui = checkUi()
    ui.setPosition(h, num(x, "x"), num(y, "y"))
end

-- gui.where(h): позиция элемента. Парам: h — хендл. Возвращает x, y. Сторона: только client.
function gui.where(h)
    local ui = checkUi()
    return ui.getPosition(h)
end

-- gui.text(h, s): текст элемента (без s — прочитать). Парам: h — хендл; s — строка/nil. Возвращает текст при чтении.
function gui.text(h, s)
    local ui = checkUi()
    if s == nil then return ui.getText(h) end
    ui.setText(h, tostring(s))
end

-- gui.show(h, v): показать/скрыть элемент. Парам: h — хендл; v — true/false (nil = true). Ничего не возвращает.
function gui.show(h, v)
    local ui = checkUi()
    if v == nil then v = true end
    ui.setVisible(h, v and true or false)
end

-- gui.remove(h): убрать элемент. Парам: h — хендл. Ничего не возвращает. Сторона: только client.
function gui.remove(h)
    local ui = checkUi()
    ui.remove(h)
end

-- gui.find(name, parent): найти родной элемент игры по имени (городская панель, кнопка найма...). Парам: имя; parent — хендл/nil.
-- Возвращает хендл или nil. Сторона: только client.
function gui.find(name, parent)
    local ui = checkUi()
    return ui.find(name, parent)
end
