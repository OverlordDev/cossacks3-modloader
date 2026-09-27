-- panel — игровые панели без CEF: поверх ui.* (окно игры, не браузер).
--
-- Только client. Меньше задержка, чем у CEF, и живёт внутри настоящего HUD.
--
--   local p = panel.new{ name = "air", title = "Авиаудар", x = 100, y = 100, w = 260 }
--   p:label("Выберите цель (F6 — удар)")
--   p:button("Ударить", function() net.send("airstrike.request", {}) end)
--   p:close()   -- убрать; panel.clear() — убрать все
--
-- Элементы — родные ui.*: button/text/container. Шрифты и цвета — как у игры.

panel = {}

local panels = {}
local modUi = nil   -- ui мода (button/onClick живут только там): panel.link(ui)

-- Привязать ui мода (один раз в client.lua): panel.link(ui).
-- Без link работают только container/text; кнопки требуют link.
function panel.link(t)
    if type(t) ~= "table" then error("panel.link: pass mod ui", 2) end
    modUi = t
end

local function U()
    return modUi or ui
end

local function checkUi()
    local u = U()
    if not u or not u.container then
        error("panel: needs client ui (call from client.lua, not from pages)", 3)
    end
    return u
end

-- Новая панель. Возвращает объект с методами label/button/close/visible.
function panel.new(opts)
    local ui = checkUi()
    if type(opts) ~= "table" then error("panel.new: pass { name=, ... }", 2) end
    local name = tostring(opts.name or ("panel" .. tostring(#panels + 1)))
    local x, y, w = opts.x or 100, opts.y or 100, opts.w or 260
    local root = ui.container({ name = name, parent = 0, x = x, y = y, w = w, h = 40 })
    local title = opts.title or name
    ui.text({ name = name .. "_title", parent = root, text = title,
              x = 8, y = 6, w = w - 16, h = 24, font = "gc_font_serif_15" })
    local p = { name = name, root = root, w = w, y = 36, items = { root } }
    function p:label(text)
        local ui = checkUi()
        local h = ui.text({ name = self.name .. "_l" .. #self.items, parent = self.root,
            text = text, x = 8, y = self.y, w = self.w - 16, h = 20 })
        self.items[#self.items + 1] = h
        self.y = self.y + 24
        return h
    end
    function p:button(text, fn)
        local ui = checkUi()
        if not modUi or not ui.button then
            error("panel button: call panel.link(ui) in client.lua first", 2)
        end
        if type(fn) ~= "function" then error("panel button: fn must be a function", 2) end
        local h = ui.button({ name = self.name .. "_b" .. #self.items, parent = self.root,
            text = text, x = 8, y = self.y, w = self.w - 16, h = 0,
            onClick = function() fn(self) end })
        self.items[#self.items + 1] = h
        self.y = self.y + 36
        return h
    end
    function p:close()
        local ui = U()
        for _, h in ipairs(self.items) do if ui then pcall(ui.remove, h) end end
        panels[self.name] = nil
    end
    function p:visible(v)
        if v == nil then v = true end
        local ui = U()
        if ui then pcall(ui.setVisible, self.root, v and true or false) end
    end
    panels[name] = p
    return p
end

-- panel.get(name): панель по имени. Возврат: объект панели или nil. Сторона: client.
function panel.get(name)
    return panels[name]
end

-- panel.clear(): убрать все панели. Сторона: client. Ничего не возвращает.
function panel.clear()
    for _, p in pairs(panels) do p:close() end
end
