-- dbg — debug-оверлей разработчика: текст в мире, инспектор юнитов, лучи.
--
-- Только картинка у этого игрока (client). Вне партии DebugText падает.
--
--   dbg.text("tgt", x, y, z, "HP: 100")            -- надпись в мировой точке
--   dbg.text("tgt", x, y, z, "HP", { scale = 2, color = {255, 0, 0} })
--   dbg.clear("tgt")                              -- убрать; dbg.count()
--   log.info(dbg.unit(h))                         -- "h=123 musketeer18 pl=0 hp=80/100 x=.. z=.. state=idle"
--   local hit, x, y, z = dbg.ray(x1,y1,z1, x2,y2,z2)  -- пересечение с рельефом
--
-- id — строка (один id — одна надпись; повторный text перезаписывает).
-- font — имя шрифта игры ("" — по умолчанию).

dbg = {}

local function num(v, name)
    local n = tonumber(v)
    if not n or n ~= n then error("dbg: " .. name .. " must be a number", 3) end
    return n
end

local function inGame(where)
    if not game.isInGame() then
        error("dbg." .. where .. ": no active game (check game.isInGame())", 3)
    end
end

-- Надпись в мировой точке (один id — одна надпись, повтор перезаписывает).
-- Параметры: id (строка), x/y/z, text, opts = { font=, scale=, color={r,g,b,a 0..255}, align=, layout= }.
-- Только картинка (client), вне партии падает. Ошибки: нет игры, пустой id, opts не таблица, координаты/цвет не числа.
function dbg.text(id, x, y, z, text, opts)
    inGame("text")
    if type(id) ~= "string" or id == "" then error("dbg.text: id must be a non-empty string", 2) end
    opts = opts or {}
    if type(opts) ~= "table" then error("dbg.text: opts must be a table", 2) end
    local c = opts.color or { 255, 255, 255, 255 }
    native.DebugTextWrite(id, opts.font or "", tostring(text),
        num(x, "x"), num(y, "y"), num(z, "z"), num(opts.scale or 1, "scale"),
        num(c[1] or 255, "color[1]"), num(c[2] or 255, "color[2]"),
        num(c[3] or 255, "color[3]"), num(c[4] or 255, "color[4]"),
        math.tointeger(tonumber(opts.align or 0)) or 0,
        math.tointeger(tonumber(opts.layout or 0)) or 0)
end

-- clear(id): убрать надпись по id. Параметр: id — строка. Только client. Ошибки: id не строка.
function dbg.clear(id)
    if type(id) ~= "string" then error("dbg.clear: id must be a string", 2) end
    native.DebugTextClean(id)
end

-- count(): число надписей. Возврат: integer. Только чтение (client), ошибок не кидает.
function dbg.count()
    return native.DebugTextCount()
end

-- indexOf(id): индекс надписи по id. Параметр: id — строка. Только чтение (client). Ошибки: id не строка.
function dbg.indexOf(id)
    if type(id) ~= "string" then error("dbg.indexOf: id must be a string", 2) end
    return native.DebugTextIndexByID(id)
end

-- Одна строка про объект: sid, владелец, HP, позиция, состояние. Параметр: h — хендл.
-- Возврат: строка "h=.. sid pl=.. hp=.. x=.. z=.. state=..". Только чтение (client). Ошибки: нет игры, h не число.
function dbg.unit(h)
    inGame("unit")
    h = math.tointeger(tonumber(h))
    if not h then error("dbg.unit: handle must be a number", 2) end
    local o = objects.read(h) or {}
    local sid = native.GetGameObjectBaseNameByHandle(h)
    local st = native.GetGameObjectStateNameByHandle(h)
    local x, z = objects.pos(h)
    return string.format("h=%d %s pl=%s hp=%s x=%.1f z=%.1f state=%s", h,
        tostring(sid), tostring(o.pl), tostring(o.hp), x or 0, z or 0, tostring(st))
end

-- Луч в рельеф: пересечение отрезка с землёй. Возврат: hit, x, y, z точки.
-- Только чтение (client). Ошибки: нет игры, координаты не числа.
function dbg.ray(x1, y1, z1, x2, y2, z2)
    inGame("ray")
    local hit, x, y, z = native.RayCastTerrain(num(x1, "x1"), num(y1, "y1"), num(z1, "z1"),
        num(x2, "x2"), num(y2, "y2"), num(z2, "z2"))
    return hit, x, y, z
end

-- ---------- фигуры DebugDraw (линии/боксы/сферы/оси) ----------

local COLORS = {
    red = { 1, 0, 0 }, green = { 0, 1, 0 }, blue = { 0, 0, 1 },
    yellow = { 1, 1, 0 }, white = { 1, 1, 1 }, cyan = { 0, 1, 1 },
}

local function color(c)
    if type(c) == "string" then return COLORS[c] or COLORS.white end
    if type(c) == "table" then return { num(c[1] or 1, "c"), num(c[2] or 1, "c"), num(c[3] or 1, "c") } end
    return COLORS.white
end

local function dname(name)
    if type(name) ~= "string" or name == "" then
        error("dbg: name must be a non-empty string", 3)
    end
    return name
end

-- Линия между точками (пути, баллистика, зоны). Параметры: name (строка), точки, c — цвет ("red"|{r,g,b 0..1}).
-- Только картинка (client). Ошибки: нет игры, пустое имя, координаты/цвет не числа.
function dbg.line(name, x1, y1, z1, x2, y2, z2, c)
    inGame("line")
    local r, g, b = table.unpack(color(c))
    native.DebugDrawLine(dname(name), num(x1, "x1"), num(y1, "y1"), num(z1, "z1"),
        num(x2, "x2"), num(y2, "y2"), num(z2, "z2"), r, g, b)
end

-- Куб вокруг точки (hitbox, зона). Параметры: name, x/y/z, size — ребро, c — цвет. Только картинка (client).
-- Ошибки: нет игры, пустое имя, координаты/size не числа.
function dbg.box(name, x, y, z, size, c)
    inGame("box")
    local r, g, b = table.unpack(color(c))
    native.DebugDrawBox(dname(name), num(x, "x"), num(y, "y"), num(z, "z"),
        num(size, "size"), r, g, b)
end

-- Куб вокруг юнита по его позиции (ребро 4). Параметры: h — хендл, c — цвет. Без позиции — ничего.
-- Только картинка (client). Ошибки: нет игры.
function dbg.unitBox(h, c)
    inGame("unitBox")
    local x, y, z = world.pos(h)
    if x then dbg.box("u" .. tostring(h), x, y, z, 4, c) end
end

-- Сфера (радиус поражения, обзор). Параметры: name, x/y/z, radius, c — цвет, slices/stacks — детализация.
-- Только картинка (client). Ошибки: нет игры, пустое имя, координаты/радиус не числа.
function dbg.sphere(name, x, y, z, radius, c, slices, stacks)
    inGame("sphere")
    local r, g, b = table.unpack(color(c))
    native.DebugDrawSphere(dname(name), num(x, "x"), num(y, "y"), num(z, "z"),
        num(radius, "radius"), math.tointeger(tonumber(slices or 12)) or 12,
        math.tointeger(tonumber(stacks or 8)) or 8, r, g, b)
end

-- Оси направления в точке (нормаль nx, ny, nz). Параметры: name, x/y/z, nx/ny/nz, c — цвет ("red"|{r,g,b 0..1}).
-- Только картинка (client). Ошибки: нет игры, пустое имя, координаты не числа.
function dbg.axis(name, x, y, z, nx, ny, nz, c)
    inGame("axis")
    local r, g, b = table.unpack(color(c))
    native.DebugDrawAxis(dname(name), num(x, "x"), num(y, "y"), num(z, "z"),
        num(nx, "nx"), num(ny, "ny"), num(nz, "nz"), r, g, b)
end

-- Убрать фигуру по имени (dbg.clear убирает только текст). Парам: name — строка. Только client. Ошибки: имя пустое/не строка.
function dbg.clean(name)
    native.DebugDrawClean(dname(name))
end
