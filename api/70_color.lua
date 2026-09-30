-- color — единый формат цветов: КОМПОНЕНТЫ 0..255 ЦЕЛЫЕ (как ui-таблицы движка).
--
-- Всегда { r, g, b, a } целыми 0..255 (a = 255 непрозрачный, 0 прозрачный).
-- rgb()/rgba()/withAlpha() out-of-range НЕ кидают: clamp + round (300 → 255, -5 → 0,
-- 128.6 → 129; NaN/не-число — ошибка). hex() мусор — ошибка. Входные таблицы не мутируются.
--
--   local c = color.rgb(255, 128, 0)
--   local d = color.hex("#FF8000")
--   local e = color.withAlpha(c, 128)
--   local f = color.lerp(color.red, color.blue, 0.5)   -- t clamped 0..1
--   local s = color.toHex(c)                            -- "#FF8000"
--
-- Сторона: везде (pure Lua). Десинка нет (только картинка/логика представления).

color = {}

-- clamp+round в байт 0..255 (NaN/не-число — ошибка с именем вызывателя).
local function byte(v, where)
    if type(v) ~= "number" or v ~= v then
        error(where .. ": color component must be a number", 2)
    end
    local r = math.floor(v + 0.5)
    if r < 0 then r = 0 end
    if r > 255 then r = 255 end
    return r
end

-- Проверка цвета { r, g, b, a } (a опционален, default 255). Возвращает r, g, b, a байтами.
local function parts(c, where)
    if type(c) ~= "table" then error(where .. ": color must be a { r, g, b, a } table", 2) end
    return byte(c.r, where), byte(c.g, where), byte(c.b, where),
        (c.a == nil and 255 or byte(c.a, where))
end

-- color.rgb(r, g, b): цвет, a = 255 (clamp+round out-of-range). Возврат: { r, g, b, a }.
-- Сторона: везде (pure). Ошибки: color.rgb: color component must be a number.
function color.rgb(r, g, b)
    return { r = byte(r, "color.rgb"), g = byte(g, "color.rgb"), b = byte(b, "color.rgb"), a = 255 }
end

-- color.rgba(r, g, b, a): цвет с альфой (clamp+round). Возврат: { r, g, b, a }.
-- Сторона: везде (pure). Ошибки: color.rgba: color component must be a number.
function color.rgba(r, g, b, a)
    return { r = byte(r, "color.rgba"), g = byte(g, "color.rgba"),
             b = byte(b, "color.rgba"), a = byte(a, "color.rgba") }
end

-- color.hex(value): "#RGB"/"#RRGGBB"/"#RRGGBBAA" ("#" опционален, регистр любой).
-- Короткий #RGB раскрывается (F0A → FF00AA, a = 255). Мусор — ошибка.
-- Парам: value — строка. Возврат: { r, g, b, a }. Сторона: везде (pure).
-- Ошибки: color.hex: must be a hex string ... / bad hex digits.
function color.hex(value)
    if type(value) ~= "string" then
        error("color.hex: must be a hex string '#RGB'/'#RRGGBB'/'#RRGGBBAA'", 2)
    end
    local s = value:match("^%s*(.-)%s*$")
    s = s:gsub("^#", "")
    s = s:upper()
    if #s == 3 then
        s = s:sub(1, 1):rep(2) .. s:sub(2, 2):rep(2) .. s:sub(3, 3):rep(2)
    end
    if #s ~= 6 and #s ~= 8 then
        error("color.hex: must be a hex string '#RGB'/'#RRGGBB'/'#RRGGBBAA'", 2)
    end
    if not s:match("^[0-9A-F]+$") then
        error("color.hex: bad hex digits in '" .. tostring(value) .. "'", 2)
    end
    local r = tonumber(s:sub(1, 2), 16)
    local g = tonumber(s:sub(3, 4), 16)
    local b = tonumber(s:sub(5, 6), 16)
    local a = 255
    if #s == 8 then a = tonumber(s:sub(7, 8), 16) end
    return { r = r, g = g, b = b, a = a }
end

-- color.withAlpha(c, alpha): копия цвета с новой альфой (clamp+round; вход не мутируется).
-- Парам: c — цвет; alpha — 0..255. Возврат: новый { r, g, b, a }. Сторона: везде (pure).
-- Ошибки: color.withAlpha: color must be ... / component must be ...
function color.withAlpha(c, alpha)
    local r, g, b = parts(c, "color.withAlpha")
    return { r = r, g = g, b = b, a = byte(alpha, "color.withAlpha") }
end

-- color.lerp(a, b, t): линейная интерполяция (включая альфу); t clamped 0..1 (NaN — ошибка).
-- Парам: a, b — цвета; t — 0..1. Возврат: новый цвет (round). Входы не мутируются.
-- Сторона: везде (pure). Ошибки: color.lerp: ...
function color.lerp(a, b, t)
    local ar, ag, ab, aa = parts(a, "color.lerp")
    local br, bg, bb, ba = parts(b, "color.lerp")
    if type(t) ~= "number" or t ~= t then
        error("color.lerp: param 't' must be a number", 2)
    end
    if t < 0 then t = 0 end
    if t > 1 then t = 1 end
    local function mix(x, y)
        local v = math.floor(x + (y - x) * t + 0.5)
        if v < 0 then v = 0 end
        if v > 255 then v = 255 end
        return v
    end
    return { r = mix(ar, br), g = mix(ag, bg), b = mix(ab, bb), a = mix(aa, ba) }
end

-- color.toHex(c, includeAlpha): цвет в "#RRGGBB" (или "#RRGGBBAA" при includeAlpha=true).
-- Парам: c — цвет; includeAlpha — bool (nil = false). Возврат: строка (верхний регистр).
-- Сторона: везде (pure). Ошибки: color.toHex: color must be ...
function color.toHex(c, includeAlpha)
    local r, g, b, a = parts(c, "color.toHex")
    if includeAlpha then
        return string.format("#%02X%02X%02X%02X", r, g, b, a)
    end
    return string.format("#%02X%02X%02X", r, g, b)
end

-- Константы (целые 0..255, a = 255 кроме transparent).
color.red = { r = 255, g = 0, b = 0, a = 255 }
color.green = { r = 0, g = 255, b = 0, a = 255 }
color.blue = { r = 0, g = 0, b = 255, a = 255 }
color.white = { r = 255, g = 255, b = 255, a = 255 }
color.black = { r = 0, g = 0, b = 0, a = 255 }
color.yellow = { r = 255, g = 255, b = 0, a = 255 }
color.transparent = { r = 0, g = 0, b = 0, a = 0 }
