-- decals — следы на земле: воронки, гарь, кровь, грязь, стройразметка.
--
-- Только картинка у всех одинаково: в сети — в shared, иначе у одного воронка есть,
-- у другого нет. Вне партии нативы падают.
--
--   local d = decals.put("scorch", x, z)          -- декаль по имени из data/decals
--   decals.move(d, x, z)
--   decals.rotate(d, 1.2)                         -- угол разворота текстуры
--   decals.show(d, false)                         -- скрыть; decals.isVisible(d)
--   decals.remove(d)                              -- убрать
--   decals.clear()                                -- убрать все
--   local n = decals.count()                      -- сколько всего
--
-- Имена декалей — из data/decals/*.lib (смотрите cache/ и model_example).
-- GetDecalsInArea у игры — процедура без ответа (заполняет внутренний список),
-- поэтому здесь isInCircle(x, y, r, material) — проверка наличия декали в круге.

decals = {}

-- Число (координата/угол/радиус). Ошибки: не число, NaN или inf.
local function num(v, name)
    local n = tonumber(v)
    if not n or n ~= n or n == math.huge or n == -math.huge then
        error("decals: " .. name .. " must be a number", 3)
    end
    return n
end

-- Хендл декали. Возвращает integer. Ошибки: не число.
local function dh(v, what)
    local h = math.tointeger(tonumber(v))
    if not h then error((what or "decals") .. ": decal handle must be a number", 3) end
    return h
end

-- Проверка партии. Ошибки: вне партии (проверяйте game.isInGame()).
local function inGame(where)
    if not game.isInGame() then
        error(where .. ": no active game (check game.isInGame())", 3)
    end
end

-- Положить декаль по имени библиотеки. Параметры: name — имя из data/decals; x, z — мировые координаты; opts.angle/visible/x/z — сразу применить. Возвращает хендл декали. Сторона: любая (только картинка; в сети — в shared). Ошибки: вне партии; имя пустое; x/z не числа; opts не таблица.
-- Положить декаль по имени библиотеки. Возвращает хендл декали.
function decals.put(name, x, z, opts)
    inGame("decals.put")
    if type(name) ~= "string" or name == "" then
        error("decals.put: name must be a non-empty string", 2)
    end
    local d = native.PutDecalByName(num(x, "x"), num(z, "z"), name)
    if opts then
        if type(opts) ~= "table" then error("decals.put: opts must be a table", 2) end
        if opts.angle ~= nil then decals.rotate(d, opts.angle) end
        if opts.visible ~= nil then decals.show(d, opts.visible) end
        if opts.x ~= nil and opts.z ~= nil then decals.move(d, opts.x, opts.z) end
    end
    return d
end

-- Убрать декаль. Параметры: d — хендл декали. Возвращает nil. Сторона: любая (только картинка; в сети — в shared). Ошибки: вне партии; хендл не число.
function decals.remove(d)
    inGame("decals.remove")
    native.DestroyDecalByHandle(dh(d, "decals.remove"))
end

-- Убрать все декали. Возвращает nil. Сторона: любая (только картинка; в сети — в shared). Ошибки: вне партии.
function decals.clear()
    inGame("decals.clear")
    native.DecalManagerClear()
end

-- Переместить декаль. Параметры: d — хендл; x, z — мировые координаты. Возвращает nil. Сторона: любая (в сети — в shared). Ошибки: вне партии; хендл не число; x/z не числа.
function decals.move(d, x, z)
    inGame("decals.move")
    native.SetDecalPositionByHandle(dh(d, "decals.move"), num(x, "x"), num(z, "z"))
end

-- Позиция декали. Параметры: d — хендл. Возвращает x, z. Сторона: любая. Ошибки: вне партии; хендл не число.
function decals.pos(d)
    inGame("decals.pos")
    return native.GetDecalPositionByHandle(dh(d, "decals.pos"))
end

-- Показать/скрыть декаль. Параметры: d — хендл; visible (по умолчанию true). Возвращает nil. Сторона: любая (в сети — в shared). Ошибки: вне партии; хендл не число.
function decals.show(d, visible)
    inGame("decals.show")
    if visible == nil then visible = true end
    native.SetDecalVisibleByHandle(dh(d, "decals.show"), visible and true or false)
end

-- Видна ли декаль. Параметры: d — хендл. Возвращает boolean. Сторона: любая. Ошибки: вне партии; хендл не число.
function decals.isVisible(d)
    inGame("decals.isVisible")
    return native.GetDecalVisibleByHandle(dh(d, "decals.isVisible"))
end

-- Повернуть текстуру декали. Параметры: d — хендл; angle — радианы. Возвращает nil. Сторона: любая (в сети — в shared). Ошибки: вне партии; хендл не число; angle не число.
function decals.rotate(d, angle)
    inGame("decals.rotate")
    native.SetDecalTexRollAngleByHandle(dh(d, "decals.rotate"), num(angle, "angle"))
end

-- Угол текстуры декали. Параметры: d — хендл. Возвращает angle (радианы). Сторона: любая. Ошибки: вне партии; хендл не число.
function decals.angle(d)
    inGame("decals.angle")
    return native.GetDecalTexRollAngleByHandle(dh(d, "decals.angle"))
end

-- Имя декали. Параметры: d — хендл. Возвращает имя (строка). Сторона: любая. Ошибки: вне партии; хендл не число.
function decals.name(d)
    inGame("decals.name")
    return native.GetDecalNameByHandle(dh(d, "decals.name"))
end

-- Имя материала декали. Параметры: d — хендл. Возвращает материал (строка). Сторона: любая. Ошибки: вне партии; хендл не число.
function decals.material(d)
    inGame("decals.material")
    return native.GetDecalMaterialNameByHandle(dh(d, "decals.material"))
end

-- Сколько всего декалей. Возвращает число. Сторона: любая. Ошибки: вне партии.
function decals.count()
    inGame("decals.count")
    return native.DecalManagerGetDecalCount()
end

-- Есть ли декаль материала в круге. Параметры: x, z — центр (мировые); radius — радиус; material — материал (строка). Возвращает boolean. Сторона: любая. Ошибки: вне партии; координаты/радиус не числа; material не строка.
-- Есть ли декаль материала в круге (центр x, z, радиус).
function decals.isInCircle(x, z, radius, material)
    inGame("decals.isInCircle")
    if type(material) ~= "string" then error("decals.isInCircle: material must be a string", 2) end
    return native.IsDecalInCircle(num(x, "x"), num(z, "z"), num(radius, "radius"), material)
end

-- Расстояние от точки до декали (для поиска ближайшей). Параметры: d — хендл; x, z — мировая точка. Возвращает дистанцию (число). Сторона: любая. Ошибки: вне партии; хендл не число; x/z не числа.
-- Расстояние от точки до декали (для поиска ближайшей).
function decals.distance(d, x, z)
    inGame("decals.distance")
    return native.GetPointDecalDistance(dh(d, "decals.distance"), num(x, "x"), num(z, "z"))
end
