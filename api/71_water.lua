-- water — водоёмы на карте: добавить, подвинуть, убрать; и что вообще под водой.
--
-- МЕНЯЕТ МИР: добавление и правка водоёмов — только server/shared, одинаково на
-- всех машинах. Чтение (есть ли вода в точке, глубина объекта) — везде.
--
--   local i = water.add{ name = "lake", x1 = -40, z1 = -40, x2 = 40, z2 = 40, level = 0 }
--   water.move(i, { x1 = -50, z1 = -50, x2 = 50, z2 = 50 })
--   water.level(i, -1.5)                 -- опустить зеркало
--   water.remove(i)                      -- water.clear() — убрать все
--   for _, f in ipairs(water.list()) do print(f.name, f.x1, f.z1, f.x2, f.z2) end
--   if water.at(100, 50) then ... end    -- есть ли вода в мировой точке
--   local under = water.depth(handle)    -- насколько объект под водой
--
-- Водоём — ПРЯМОУГОЛЬНИК: две угловые точки в мировых координатах (клетки карты,
-- как и везде: карта 320 — это от -160 до +160) и уровень зеркала по высоте.
-- Форму берега рисует рельеф: чтобы получился не бассейн, а озеро, землю внутри
-- прямоугольника опускают (terrain.lower) ниже уровня воды.
--
-- Материал воды (как она выглядит) общий для карты: water.material("river").

water = {}

-- Проверка записи: только server/shared (нужен game.exec) и только в партии.
local function needServer(where)
    if not game.exec then
        error("water." .. where .. ": only server/shared scripts can change the game", 3)
    end
    if not game.isInGame() then
        error("water." .. where .. ": no active game (check game.isInGame())", 3)
    end
end

local function num(v, name)
    local n = tonumber(v)
    if not n or n ~= n then error("water: " .. name .. " must be a number", 3) end
    return n
end

local function index(v)
    local n = math.tointeger(tonumber(v))
    if not n or n < 0 then error("water: index must be a whole number >= 0", 3) end
    return n
end

-- Углы прямоугольника из opts. Порядок углов движку важен (tx,tz — один угол,
-- bx,bz — другой), поэтому нормализуем сами: пользователю всё равно, какой угол
-- он назвал первым.
local function corners(opts, where)
    if type(opts) ~= "table" then error("water." .. where .. ": opts must be a table", 3) end
    local x1, z1 = num(opts.x1, "x1"), num(opts.z1, "z1")
    local x2, z2 = num(opts.x2, "x2"), num(opts.z2, "z2")
    if x1 > x2 then x1, x2 = x2, x1 end
    if z1 > z2 then z1, z2 = z2, z1 end
    return x1, z1, x2, z2
end

-- water.add(opts): новый водоём. opts: x1, z1, x2, z2 — углы (мировые координаты);
-- level — высота зеркала (по умолчанию 0); name — имя (по умолчанию "water").
-- Возврат: индекс водоёма. Сторона: только server/shared. Ошибки: на client; вне партии; не числа.
function water.add(opts)
    needServer("add")
    local x1, z1, x2, z2 = corners(opts, "add")
    return math.tointeger(native.WaterFieldAdd(tostring(opts.name or "water"),
                                               x1, z1, x2, z2, num(opts.level or 0, "level")))
end

-- water.move(i, opts): передвинуть/растянуть водоём. opts — как у add (level по
-- умолчанию берётся текущий). Возвращает nil. Сторона: только server/shared.
function water.move(i, opts)
    needServer("move")
    i = index(i)
    local x1, z1, x2, z2 = corners(opts, "move")
    local level = opts.level
    if level == nil then
        -- Не сказали уровень — не меняем его: читаем текущий, а не подставляем 0,
        -- иначе «подвинуть озеро» молча подняло бы воду до нуля.
        level = native.WaterFieldGetOffsetY(i)
    end
    native.WaterFieldSetCoord(i, x1, z1, x2, z2, num(level or 0, "level"))
end

-- water.level(i, y): поднять/опустить зеркало. y — высота. Возвращает nil. Сторона: server/shared.
function water.level(i, y)
    needServer("level")
    native.WaterFieldSetOffsetY(index(i), num(y, "y"))
end

-- water.rename(i, name): переименовать водоём. Возвращает nil. Сторона: server/shared.
function water.rename(i, name)
    needServer("rename")
    native.WaterFieldSetName(index(i), tostring(name))
end

-- water.remove(i): убрать водоём. Возвращает nil. Сторона: server/shared.
-- ВНИМАНИЕ: после удаления индексы оставшихся могут сдвинуться — если удаляете
-- несколько, идите с конца списка или заново берите water.list().
function water.remove(i)
    needServer("remove")
    native.WaterFieldDelete(index(i))
end

-- water.clear(): убрать все водоёмы. Возвращает nil. Сторона: server/shared.
function water.clear()
    needServer("clear")
    native.WaterFieldsClear()
end

-- water.count(): сколько водоёмов на карте. Возврат: число. Сторона: server/shared.
function water.count()
    needServer("count")
    return math.tointeger(native.WaterFieldGetCount()) or 0
end

-- water.get(i): один водоём. Возврат: { index, name, x1, z1, x2, z2, level } или nil.
-- Сторона: server/shared. Ошибки: на client; вне партии.
function water.get(i)
    needServer("get")
    i = index(i)
    if i >= (math.tointeger(native.WaterFieldGetCount()) or 0) then return nil end
    -- WaterFieldGetCoord отдаёт ПЯТЬ значений (minx, minz, maxx, maxz, offsety):
    -- все var-параметры по порядку объявления. Взять меньше — получить не то.
    local x1, z1, x2, z2, level = native.WaterFieldGetCoord(i)
    return { index = i, name = native.WaterFieldGetNameByIndex(i),
             x1 = x1, z1 = z1, x2 = x2, z2 = z2, level = level }
end

-- water.list(): все водоёмы. Возврат: список записей как у water.get. Сторона: server/shared.
function water.list()
    needServer("list")
    local out = {}
    for i = 0, (math.tointeger(native.WaterFieldGetCount()) or 0) - 1 do
        out[#out + 1] = water.get(i)
    end
    return out
end

-- water.find(name): индекс водоёма по имени. Возврат: число или nil. Сторона: server/shared.
function water.find(name)
    needServer("find")
    local i = native.WaterFieldGetIndexByName(tostring(name))
    if not i or i < 0 then return nil end
    return math.tointeger(i)
end

-- ---------- как вода выглядит ----------

-- water.material(name): сменить материал воды на карте (общий для всех водоёмов).
-- Без аргумента — вернуть текущий. Возврат: имя (при чтении) или nil.
-- Сторона: чтение везде, запись — server/shared.
function water.material(name)
    if name == nil then return native.GetCurrentWaterName() end
    needServer("material")
    native.SetCurrentWaterName(tostring(name))
end

-- ---------- чтение ----------

-- water.at(x, z): есть ли вода в мировой точке. Возврат: true/false, уровень зеркала.
-- Сторона: везде (только чтение). Ошибки: вне партии.
function water.at(x, z)
    if not game.isInGame() then error("water.at: no active game", 2) end
    -- GetWaterExt: результат функции плюс var woffset — два значения.
    return native.GetWaterExt(num(x, "x"), num(z, "z"))
end

-- water.cell(i, j): есть ли вода в клетке карты. Возврат: true/false.
-- Сторона: везде (только чтение). Ошибки: вне партии.
function water.cell(i, j)
    if not game.isInGame() then error("water.cell: no active game", 2) end
    return native.GetWater(index(i), index(j)) == true
end

-- water.depth(handle): насколько объект погружён. Возврат: глубина, в воде ли он.
-- Сторона: везде (только чтение). Ошибки: вне партии; handle не число.
function water.depth(handle)
    if not game.isInGame() then error("water.depth: no active game", 2) end
    local h = math.tointeger(tonumber(handle)) or error("water.depth: handle must be a number", 2)
    return native.GetGameObjectDepthUnderWaterByHandle(h),
           native.GetGameObjectPositionInWaterByHandle(h) == true
end
