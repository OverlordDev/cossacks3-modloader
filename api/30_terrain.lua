-- terrain — динамический ландшафт: траншеи, воронки, насыпи.
--
-- МЕНЯЕТ МИР (и влияет на lockstep): только server/shared, одинаково на всех машинах.
--
-- КООРДИНАТЫ. У кистей рельефа (raise/lower/smooth/plateau/random/paint) они
-- МИРОВЫЕ: карта 320 — это от -160 до +160, центр в нуле. У тайлов
-- (tile/setTile/color) — клетки сетки 0..W. Перевод: terrain.cell/terrain.world.
--
--   terrain.raise(100, 80, { delta = 2, radius = 5 })  -- насыпать холм
--   terrain.lower(100, 80, { delta = 3 })              -- вырыть воронку
--   terrain.smooth(100, 80)                            -- сгладить
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
-- Форма кисти: круглая ли и какого радиуса.
--
-- РАДИУС. В подписи натива этот параметр зовётся mb, и что это, по имени не
-- понять. Игра зовёт его так: PlateauTerrain(0, 0, False, r, True), где
-- r = (GetMapHeight div 2) - 1 — то есть «от центра до края», радиус в мировых
-- единицах (data/scripts/common.inc/dogenerate.inc, очистка карты).
-- Поэтому наружу он и называется radius. Имя mb принимаем как было, чтобы не
-- ломать написанное раньше.
local function shape(opts)
    opts = opts or {}
    if type(opts) ~= "table" then error("terrain: opts must be a table", 2) end
    return opts.round ~= false, math.tointeger(tonumber(opts.radius or opts.mb or 3)) or 3
end

-- Точка для кисти рельефа: мировые координаты, и вторая ОТРИЦАЕТСЯ.
--
-- Это не прихоть: игра зовёт PaintTerrain(px, -py, ...), где py — обычная
-- мировая координата из _misc_GetMapLeftTopPos (data/scripts/lib/misc.script,
-- _misc_CreateBorders). У кистей рельефа ось направлена навстречу мировой z.
--
-- Клетки здесь НИ ПРИ ЧЁМ — это была моя ошибка в первой версии: кисти брали
-- «клетки 0..W», и мазок уезжал за край карты, где его никто не видел. Клетки
-- нужны только тайлам (terrain.tile/setTile — там сетка правда 0..W, игра ходит
-- по ней for y:=0 to GetMapHeight).
local function brushPoint(x, z)
    return math.tointeger(math.floor(num(x, "x"))) or 0,
           math.tointeger(math.floor(-num(z, "z"))) or 0
end

-- Поднять рельеф в мировой точке (x, z). Параметры: x, z — мировые координаты
-- (карта 320 — это от -160 до +160); opts.delta (высота, по умолчанию 1),
-- opts.radius (радиус кисти, по умолчанию 3), opts.round (круглая, по умолчанию да).
-- Возвращает nil. Сторона: только server/shared.
-- Ошибки: на client (нет game.exec); вне партии; x/z не числа; opts не таблица.
function terrain.raise(x, z, opts)
    needServer("raise")
    opts = opts or {}
    local round, radius = shape(opts)
    local bx, bz = brushPoint(x, z)
    native.RaiseTerrain(bx, bz, round, radius, num(opts.delta or 1, "delta"))
end

-- Понизить рельеф в мировой точке (x, z). Параметры/возврат/сторона/ошибки — как terrain.raise.
function terrain.lower(x, z, opts)
    needServer("lower")
    opts = opts or {}
    local round, radius = shape(opts)
    local bx, bz = brushPoint(x, z)
    native.LowerTerrain(bx, bz, round, radius, num(opts.delta or 1, "delta"))
end

-- Сгладить рельеф в мировой точке (x, z). Параметры: x, z — мировые координаты;
-- opts.radius, opts.round. Возвращает nil. Сторона: только server/shared.
function terrain.smooth(x, z, opts)
    needServer("smooth")
    local round, radius = shape(opts)
    local bx, bz = brushPoint(x, z)
    native.SmoothTerrain(bx, bz, round, radius)
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

-- ---------- форма рельефа: плато и шум ----------

-- Выровнять площадку под одну высоту (кисть «плато»). Ею же игра расчищает всю
-- карту: PlateauTerrain(0, 0, False, (GetMapHeight div 2) - 1, True).
-- Параметры: x, z — мировые координаты; opts.radius, opts.round;
-- opts.reproduce (по умолчанию false) — повторить правку образцом по соседям.
-- Возвращает nil. Сторона: только server/shared. Ошибки: как у terrain.raise.
function terrain.plateau(x, z, opts)
    needServer("plateau")
    opts = opts or {}
    local round, radius = shape(opts)
    local bx, bz = brushPoint(x, z)
    native.PlateauTerrain(bx, bz, round, radius, opts.reproduce == true)
end

-- Добавить случайных неровностей (кисть «шум»): грубый рельеф без ручной работы.
-- Параметры: x, z — мировые координаты; opts.delta (размах, по умолчанию 1),
-- opts.radius, opts.round. Возвращает nil. Сторона: только server/shared.
function terrain.random(x, z, opts)
    needServer("random")
    opts = opts or {}
    local round, radius = shape(opts)
    local bx, bz = brushPoint(x, z)
    native.RandomHeightTerrain(bx, bz, round, radius, num(opts.delta or 1, "delta"))
end

-- Сгладить ЦЕЛУЮ ОБЛАСТЬ за несколько проходов (terrain.smooth сглаживает одну клетку).
-- Параметры: x, y — центр в клетках; passes — сколько проходов (по умолчанию 1);
-- radius — радиус в клетках (по умолчанию 3). Возвращает nil.
-- Сторона: только server/shared. Ошибки: как у terrain.raise.
function terrain.smoothArea(x, y, passes, radius)
    needServer("smoothArea")
    native.MapGeneratorSmoothTerrain(cell(x, "x"), cell(y, "y"),
                                     cell(passes or 1, "passes"), num(radius or 3, "radius"))
end

-- ---------- текстуры земли (тайлы) ----------
--
-- Тайл у движка двулик: у него есть ИНДЕКС (число, быстро) и ИМЯ блока (строка,
-- понятно человеку). Здесь принимается и то и другое, а наружу отдаётся пара —
-- чтобы не гадать, что именно вернулось.

-- Индекс тайла по имени блока (или само число, если дали число).
-- Возврат: integer, либо nil если такого блока нет. Сторона: server/shared.
function terrain.tileIndex(tile)
    if type(tile) == "number" then return math.tointeger(tile) end
    needServer("tileIndex")
    local i = native.MapGetTileIndexByTileBlock(tostring(tile))
    -- Движок отвечает -1 на неизвестное имя: наружу отдаём nil, чтобы
    -- «не нашлось» нельзя было случайно передать дальше как номер тайла.
    if not i or i < 0 then return nil end
    return math.tointeger(i)
end

-- Имя блока по индексу тайла. Возврат: строка или nil. Сторона: server/shared.
function terrain.tileName(index)
    needServer("tileName")
    local name = native.MapGetTileBlockByTileIndex(cell(index, "index"))
    if name == nil or name == "" then return nil end
    return name
end

-- Что лежит в клетке (i, j). Возврат: индекс, имя. Сторона: везде (только чтение).
-- Ошибки: вне партии; i/j не целые.
function terrain.tile(i, j)
    if not game.isInGame() then error("terrain.tile: no active game", 2) end
    return math.tointeger(native.GetTileIndex(cell(i, "i"), cell(j, "j"))),
           native.GetTileName(cell(i, "i"), cell(j, "j"))
end

-- Положить тайл в клетку (i, j). tile — индекс или имя блока. Возвращает nil.
-- Сторона: только server/shared. Ошибки: на client; вне партии; неизвестное имя блока.
function terrain.setTile(i, j, tile)
    needServer("setTile")
    local index = terrain.tileIndex(tile)
    if not index then error("terrain.setTile: unknown tile '" .. tostring(tile) .. "'", 2) end
    native.SetTileIndex(cell(i, "i"), cell(j, "j"), index)
end

-- Заменить по всей карте один тайл другим. swap=true — поменять их местами.
-- Возврат: сколько клеток изменилось. Сторона: только server/shared.
-- Ошибки: на client; вне партии; неизвестное имя блока.
function terrain.replaceTiles(from, to, swap)
    needServer("replaceTiles")
    local a, b = terrain.tileIndex(from), terrain.tileIndex(to)
    if not a then error("terrain.replaceTiles: unknown tile '" .. tostring(from) .. "'", 2) end
    if not b then error("terrain.replaceTiles: unknown tile '" .. tostring(to) .. "'", 2) end
    return math.tointeger(native.MapReplaceTiles(a, b, swap == true)) or 0
end

-- Сгладить стыки тайлов по всей карте (после пачки setTile). Возвращает nil.
-- Сторона: только server/shared.
function terrain.smoothTiles()
    needServer("smoothTiles")
    native.MapGeneratorSmoothTiles()
end

-- Какой тайл преобладает вокруг клетки (i, j) в радиусе rad клеток.
-- Возврат: имя блока. Сторона: везде (только чтение). Ошибки: вне партии.
function terrain.mostFrequentTile(i, j, rad)
    if not game.isInGame() then error("terrain.mostFrequentTile: no active game", 2) end
    return native.GetMapMostFrequentTile(cell(i, "i"), cell(j, "j"), num(rad or 3, "rad"))
end

-- ---------- кисть редактора: текстура, скалы и вода разом ----------

-- terrain.paint(x, z, opts) — та самая кисть, которой рисуют карту в редакторе:
-- одним мазком кладёт текстуру, ставит скалу (это и есть «горы») и/или воду.
--
--   terrain.paint(100, 80, { tile = "grass", size = 3 })        -- текстура
--   terrain.paint(100, 80, { cliff = 1, apply = 1, level = 2 }) -- скала
--   terrain.paint(100, 80, { water = 1 })                       -- вода
--
-- opts: tile — текстура (имя блока или индекс), cliff — кисть скал (индекс),
--       water — кисть воды (индекс), apply — как применять скалу, level — уровень,
--       radius — радиус кисти (по умолчанию 3), ramp — делать пандус (склон),
--       round — круглая (по умолчанию true), reproduce — повторить образцом.
--
-- «НЕ ТРОГАТЬ» — ЭТО -1, А НЕ 0. Ноль — настоящий номер: тайл 0 существует, и
-- игра сама им пользуется (PaintTerrain(0, 0, 0, -1, -1, ...) в dogenerate.inc
-- красит карту тайлом 0, не трогая скалы и воду). В первой версии я ставил в
-- пропущенные поля нули — и мазок либо не делал ничего, либо делал не то.
-- Здесь пропущенное поле уходит как -1; наружу об этом думать не надо.
--
-- Координаты — МИРОВЫЕ, и вторая отрицается внутри (см. brushPoint).
--
-- ЧЕСТНО: номера кистей скал и воды, apply и level в игре не проверены —
-- подписи натива о них молчат, а скрипты игры зовут только текстуру.
-- Подбирайте на карте-однодневке; вкладка «Мир» инспектора для этого и сделана.
-- Возвращает nil. Сторона: только server/shared. Ошибки: на client; вне партии; неизвестный тайл.
function terrain.paint(x, z, opts)
    needServer("paint")
    opts = opts or {}
    if type(opts) ~= "table" then error("terrain.paint: opts must be a table", 2) end
    local tile = -1
    if opts.tile ~= nil then
        tile = terrain.tileIndex(opts.tile)
        if not tile then error("terrain.paint: unknown tile '" .. tostring(opts.tile) .. "'", 2) end
    end
    -- Пропущено — -1 («не трогать»), а не 0 («кисть номер ноль»).
    local function brushIndex(v, name)
        if v == nil then return -1 end
        return cell(v, name)
    end
    native.PaintTerrain(num(x, "x"), -num(z, "z"),
                        tile,
                        brushIndex(opts.cliff, "cliff"),
                        brushIndex(opts.water, "water"),
                        opts.ramp == true,
                        brushIndex(opts.apply, "apply"),
                        brushIndex(opts.level, "level"),
                        cell(opts.radius or opts.size or 3, "radius"),
                        opts.round ~= false,
                        opts.reproduce ~= false)
end

-- ---------- подкраска земли ----------

-- Цвет подложки в клетке (i, j). Возврат: r, g, b, a (0..1). Сторона: везде (чтение).
function terrain.color(i, j)
    if not game.isInGame() then error("terrain.color: no active game", 2) end
    return native.GetTerrainColorData(cell(i, "i"), cell(j, "j"))
end

-- Покрасить клетку (i, j). Параметры: r, g, b — 0..1; a — прозрачность (по умолчанию 1).
-- Возвращает nil. Сторона: только server/shared.
function terrain.setColor(i, j, r, g, b, a)
    needServer("setColor")
    native.SetTerrainColorData(cell(i, "i"), cell(j, "j"),
                               num(r, "r"), num(g, "g"), num(b, "b"), num(a or 1, "a"))
end

-- ---------- клетки и мировые координаты ----------
--
-- Путаница координат — самая частая причина «мод работает, но не туда».
-- Мировые координаты идут от -W/2 до +W/2 (карта 320 — это от -160 до +160),
-- а клетки рельефа — целые от 0 до W. Отсюда перевод: клетка = мир + W/2.
--
-- ЧЕСТНО: формула выведена из того, как игра сама считает края карты
-- (halfW = GetMapWidth div 2 в скриптах), а не проверена замером в игре.
-- Проверяется одной строкой в консоли модлоадера, стоя юнитом на бугре:
--   =show{ world.pos(units.selected()[1]) }   и  =show{ terrain.cell(x, z) }
-- Если сдвиг на полклетки — правьте здесь, в одном месте, а не по модам.

-- terrain.cell(x, z): мировая точка -> клетка рельефа. Возврат: i, j (целые).
-- Сторона: везде (только чтение). Ошибки: вне партии; не числа.
function terrain.cell(x, z)
    if not game.isInGame() then error("terrain.cell: no active game", 2) end
    local w, h = native.GetMapWidth(), native.GetMapHeight()
    return math.tointeger(math.floor(num(x, "x") + w / 2)),
           math.tointeger(math.floor(num(z, "z") + h / 2))
end

-- terrain.world(i, j): клетка рельефа -> мировая точка (центр клетки).
-- Возврат: x, z. Сторона: везде (только чтение). Ошибки: вне партии; не целые.
function terrain.world(i, j)
    if not game.isInGame() then error("terrain.world: no active game", 2) end
    local w, h = native.GetMapWidth(), native.GetMapHeight()
    return cell(i, "i") - w / 2 + 0.5, cell(j, "j") - h / 2 + 0.5
end

-- ---------- проходимость: из чего сделана «настоящая» вода ----------
--
-- Водоём (water.add) — это только ЗЕРКАЛО, картинка. Порт на нём не поставить и
-- корабль не поплывёт: игра решает, где вода, по карте столкновений — отдельному
-- слою тегов поверх карты. Именно его красит редактор, и именно его читают
-- постройки (у зданий в .prop есть LayerOptions.cloWater).
--
-- Как это делает сама игра (data/scripts/common.inc/texturemap.inc):
--   MapDrawCollision(realx, realy, gc_collisiontag_water, 1, True);
--   MapDrawCollision(realx-0.5, realy-0.5, gc_collisiontag_water, 1, True);
--   ... ещё две соседние точки — сетка тегов вдвое мельче клетки, шаг 0.5
--
-- Координаты — МИРОВЫЕ и БЕЗ отрицания (в отличие от кистей рельефа):
-- misc.script читает их как x := (i-w)/2, то есть от -w/2 до +w/2.
--
-- Значения тегов — из data/scripts/dmscript.global.
COLLISION_TAG = {
    none        = 0,
    bridge      = 10,
    building    = 80,
    stretchland = 85,
    water       = 87,
    wall        = 95,
    landborder  = 109,
    terrain     = 101,
    waterborder = 110,
}

-- terrain.collision(x, z, useLayers): какой тег в мировой точке.
-- useLayers (по умолчанию false) — учитывать ли слои построек.
-- Возврат: число (сверяйте с COLLISION_TAG). Сторона: везде (только чтение).
function terrain.collision(x, z, useLayers)
    if not game.isInGame() then error("terrain.collision: no active game", 2) end
    return math.tointeger(native.GetMapCollisionTag(num(x, "x"), num(z, "z"), useLayers == true)) or 0
end

-- terrain.setCollision(x, z, tag, opts): закрасить проходимость.
-- tag — число или имя из COLLISION_TAG ("water", "none", "bridge"...).
-- opts.radius (по умолчанию 1), opts.round (по умолчанию true).
-- Возвращает nil. Сторона: только server/shared. Ошибки: на client; вне партии; неизвестное имя тега.
function terrain.setCollision(x, z, tag, opts)
    needServer("setCollision")
    opts = opts or {}
    if type(tag) == "string" then
        tag = COLLISION_TAG[tag] or error("terrain.setCollision: unknown tag '" .. tag .. "'", 2)
    end
    native.MapDrawCollision(num(x, "x"), num(z, "z"),
                            cell(tag, "tag"), num(opts.radius or 1, "radius"), opts.round ~= false)
end

-- terrain.water(x, z, opts): сделать воду по-настоящему — яма, зеркало и проходимость.
--
-- Одного из трёх всегда мало: без ямы зеркало под землёй, без зеркала не видно
-- воды, без проходимости по ней нельзя плавать и нельзя строить порт.
--
-- opts: radius (по умолчанию 8), depth (насколько опустить землю, по умолчанию 4),
--       level (высота зеркала, по умолчанию -1), name (имя водоёма).
-- Возврат: индекс водоёма. Сторона: только server/shared.
function terrain.water(x, z, opts)
    needServer("water")
    opts = opts or {}
    local radius = num(opts.radius or 8, "radius")
    local depth = num(opts.depth or 4, "depth")
    local level = num(opts.level or -1, "level")

    terrain.lower(x, z, { delta = depth, radius = radius })
    -- Один вызов на весь круг: у MapDrawCollision есть свой радиус, и игра сама
    -- так чистит карту целиком — MapDrawCollision(0, 0, 0, r*2-2, False).
    -- Красить по точкам с шагом 0.5 (как texturemap.inc) нужно только когда
    -- форма берётся из картинки; здесь форма круглая, и хватает одного мазка.
    terrain.setCollision(x, z, COLLISION_TAG.water, { radius = radius })
    local index = water.add{ name = opts.name or "water", level = level,
                             x1 = x - radius, z1 = z - radius, x2 = x + radius, z2 = z + radius }
    terrain.update()
    return index
end
