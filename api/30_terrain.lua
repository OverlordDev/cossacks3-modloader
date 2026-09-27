-- terrain — динамический ландшафт: траншеи, воронки, насыпи.
--
-- МЕНЯЕТ МИР (и влияет на lockstep): только server/shared, одинаково на всех машинах.
-- Координаты x, y — КЛЕТКИ карты (целые), не мировые! delta — высота.
--
--   terrain.raise(100, 80, { delta = 2 })     -- насыпать холм
--   terrain.lower(100, 80, { delta = 3 })     -- вырыть воронку/траншею
--   terrain.smooth(100, 80)                   -- сгладить
--   terrain.update()                          -- пересчитать (после серии правок)
--   local h = terrain.height(x, z)            -- высота в мировой точке (можно везде)
--
-- После правок вызовите terrain.update(), иначе картинка и проходимость разойдутся.

terrain = {}

-- Проверка записи: только server/shared (нужен game.exec) и только в партии.
-- Ошибки: нет game.exec (client) или вне партии.
local function needServer(where)
    if not game.exec then
        error("terrain." .. where .. ": only server/shared scripts can change the game", 3)
    end
    if not game.isInGame() then
        error("terrain." .. where .. ": no active game (check game.isInGame())", 3)
    end
end

-- Целая клетка карты. Возвращает integer. Ошибки: не число/не целое.
local function cell(v, name)
    local n = math.tointeger(tonumber(v))
    if not n then error("terrain: " .. name .. " must be an integer cell", 3) end
    return n
end

-- Число (delta/координата). Ошибки: не число или NaN.
local function num(v, name)
    local n = tonumber(v)
    if not n or n ~= n then error("terrain: " .. name .. " must be a number", 3) end
    return n
end

-- Форма кисти из opts: round (по умолчанию true), mb. Возвращает round, mb. Ошибки: opts не таблица.
local function shape(opts)
    opts = opts or {}
    if type(opts) ~= "table" then error("terrain: opts must be a table", 2) end
    return opts.round ~= false, math.tointeger(tonumber(opts.mb or 0)) or 0
end

-- Поднять рельеф в клетке (x, y). Параметры: x, y — целые клетки; opts.delta (по умолчанию 1), opts.round, opts.mb. Возвращает nil. Сторона: только server/shared. Ошибки: на client (нет game.exec); вне партии; x/y не целые; opts не таблица; delta не число.
function terrain.raise(x, y, opts)
    needServer("raise")
    opts = opts or {}
    local round, mb = shape(opts)
    native.RaiseTerrain(cell(x, "x"), cell(y, "y"), round, mb, num(opts.delta or 1, "delta"))
end

-- Понизить рельеф в клетке (x, y). Параметры/возврат/сторона/ошибки — как terrain.raise.
function terrain.lower(x, y, opts)
    needServer("lower")
    opts = opts or {}
    local round, mb = shape(opts)
    native.LowerTerrain(cell(x, "x"), cell(y, "y"), round, mb, num(opts.delta or 1, "delta"))
end

-- Сгладить рельеф в клетке (x, y). Параметры: x, y — целые клетки; opts.round, opts.mb. Возвращает nil. Сторона: только server/shared. Ошибки: на client; вне партии; x/y не целые; opts не таблица.
function terrain.smooth(x, y, opts)
    needServer("smooth")
    local round, mb = shape(opts)
    native.SmoothTerrain(cell(x, "x"), cell(y, "y"), round, mb)
end

-- Пересчитать рельеф и горизонт после правок. Параметры: horizon (по умолчанию true; false — только рельеф). Возвращает nil. Сторона: только server/shared. Ошибки: на client; вне партии.
-- Пересчитать рельеф и горизонт после правок. horizon=false — только рельеф.
function terrain.update(horizon)
    needServer("update")
    if horizon == nil then horizon = true end
    native.TerrainUpdate(true, horizon and true or false)
end

-- Высота земли в мировой точке (x, z). Параметры: x, z — мировые координаты. Возвращает высоту (число). Сторона: любая (shared/client, только чтение). Ошибки: вне партии; x/z не числа.
-- Высота земли в мировой точке (x, z). Только чтение — с любой стороны.
function terrain.height(x, z)
    if not game.isInGame() then error("terrain.height: no active game", 2) end
    return native.RayCastHeight(num(x, "x"), num(z, "z"))
end
