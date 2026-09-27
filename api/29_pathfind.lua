-- pathfind — запросы поиска пути: БПЛА, колонны, время прибытия, отладка застреваний.
--
-- Только запросы (мир не меняют): работают на server/shared и на client.
-- Вне партии нативы падают.
--
--   local rc = pathfind.calculate(h, x, z)   -- синхронный поиск пути юнита к точке
--   local rc = pathfind.calculateAdv(h, x, z, { clear = true, depth = 200 })
--   local d = pathfind.distance(x1, z1, x2, z2)   -- длина пути по топологии (не прямая!)
--   local ready = pathfind.groupReady(grHandle)   -- группа досчитала путь
--
-- rc у calculate — код результата движка (0 — путь найден; точные коды зависят от
-- версии игры, ненулевой — разбирайте через dbg.ray и world.pos).

pathfind = {}

-- Ненулевой хендл объекта/группы. Возвращает integer. Ошибки: не число или 0.
local function checkHandle(h, where)
    h = math.tointeger(tonumber(h))
    if not h or h == 0 then error("pathfind." .. where .. ": handle must be a non-zero number", 3) end
    return h
end

-- Число (координата). Ошибки: не число, NaN или inf.
local function num(v, name)
    local n = tonumber(v)
    if not n or n ~= n or n == math.huge or n == -math.huge then
        error("pathfind: " .. name .. " must be a number", 3)
    end
    return n
end

-- Проверка партии. Ошибки: вне партии (проверяйте game.isInGame()).
local function inGame(where)
    if not game.isInGame() then
        error("pathfind." .. where .. ": no active game (check game.isInGame())", 3)
    end
end

-- Синхронный поиск пути юнита к (x, z). Параметры: h — хендл юнита; x, z — мировые координаты; useClear (по умолчанию true) — забыть старый путь. Возвращает код движка (0 — путь найден). Сторона: любая (только запрос, мир не меняет). Ошибки: вне партии; h нулевой/не число; x/z не числа.
-- Синхронный поиск пути юнита к (x, z). useClear=true — забыть старый путь.
function pathfind.calculate(h, x, z, useClear)
    inGame("calculate")
    return native.GameObjectCalcPathByHandle(checkHandle(h, "calculate"),
        num(x, "x"), num(z, "z"), false, useClear ~= false)
end

-- Расширенный поиск пути. Параметры: h — хендл юнита; x, z — цель (мировые); opts.fromX/fromZ — старт (иначе от юнита), opts.clear (по умолчанию true), opts.depth (0 — default игры). Возвращает код движка (0 — путь найден). Сторона: любая. Ошибки: вне партии; h нулевой; opts не таблица; координаты не числа.
-- Расширенный поиск: от своей или заданной точки, с глубиной волны.
-- opts = { fromX=, fromZ=, clear = true, depth = 0 (0 — по умолчанию игры) }.
function pathfind.calculateAdv(h, x, z, opts)
    inGame("calculateAdv")
    h = checkHandle(h, "calculateAdv")
    opts = opts or {}
    if type(opts) ~= "table" then error("pathfind.calculateAdv: opts must be a table", 2) end
    local depth = math.tointeger(tonumber(opts.depth or 0)) or 0
    if opts.fromX ~= nil or opts.fromZ ~= nil then
        return native.GameObjectCalcPathExtByHandle(h, num(opts.fromX, "fromX"),
            num(opts.fromZ, "fromZ"), num(x, "x"), num(z, "z"),
            false, opts.clear ~= false)
    end
    return native.GameObjectCalcPathAdvByHandle(h, num(x, "x"), num(z, "z"),
        false, opts.clear ~= false, 0, 0, depth, "", false)
end

-- Длина пути между точками по проходимости (с учётом препятствий). Параметры: x1, z1, x2, z2 — мировые координаты; irregular — считать через нерегулярную сетку (точнее, медленнее). Возвращает длину (число). Сторона: любая. Ошибки: вне партии; координаты не числа.
-- Длина пути между точками по проходимости (с учётом препятствий).
-- irregular=true — считать через нерегулярную сетку (точнее, медленнее).
function pathfind.distance(x1, z1, x2, z2, irregular)
    inGame("distance")
    return native.TopologyGetPathDistance(num(x1, "x1"), num(z1, "z1"),
        num(x2, "x2"), num(z2, "z2"), irregular == true)
end

-- Группа (хендл группы, не юнита) закончила считать путь. Параметры: grHandle — хендл группы. Возвращает boolean. Сторона: любая. Ошибки: вне партии; хендл нулевой/не число.
-- Группа (хендл группы, не юнита) закончила считать путь.
function pathfind.groupReady(grHandle)
    inGame("groupReady")
    return native.GroupGetFindPathByHandle(checkHandle(grHandle, "groupReady"))
end
