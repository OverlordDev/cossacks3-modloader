-- camera — свободная камера, лимиты, слежение и кинематографические треки.
--
-- Только картинка у этого игрока: на ход партии не влияет, работает на client
-- (и на server). Вне партии многие нативы падают — проверяйте game.isInGame().
--
--   local x, y, z = camera.pos()          -- абсолютная позиция камеры
--   local tx, ty, tz = camera.target()    -- точка, куда смотрит
--   camera.position(x, z)                 -- поставить камеру по XZ
--   camera.rotate(x, y, z)                -- повернуть
--   camera.moveTo(x, z, speed)            -- плавный переезд (speed nil — скорость игры)
--   camera.follow(handle)                 -- следить за юнитом; camera.follow(nil) — отпустить
--   camera.limits{ left=, top=, right=, bottom= }   -- ограничение области
--   local l = camera.getLimits()
--   local h = camera.height(x, z)         -- высота земли под точкой
--   camera.trackClear()                   -- стереть кинематографический трек
--   local i = camera.trackAdd()           -- новый трек -> индекс
--   camera.trackPoint("name", tx,ty,tz, ex,ey,ez)   -- точка трека: цель + глаз
--   camera.trackPlay(i)                   -- играть трек
--
-- Треки игры: AddCameraTrack / AddCameraTrackPoint / SetCameraCurrentTrackIndex /
-- CameraTrackListClear. Имена треков — строки, индексы — с 0 или 1 по версии игры
-- (сверяйтесь с GetCameraCurrentTrackIndex после добавления).

camera = {}

-- Число. Ошибки: не число, NaN или inf.
local function num(v, name)
    local n = tonumber(v)
    if not n or n ~= n or n == math.huge or n == -math.huge then
        error("camera: " .. name .. " must be a number", 3)
    end
    return n
end

-- Хендл объекта. Возвращает integer. Ошибки: не число.
local function handle(v)
    local h = math.tointeger(tonumber(v))
    if not h then error("camera: handle must be a number", 3) end
    return h
end

-- Проверка партии. Ошибки: вне партии (проверяйте game.isInGame()).
local function inGame(where)
    if not game.isInGame() then
        error("camera." .. where .. ": no active game (check game.isInGame())", 3)
    end
end

-- Абсолютная позиция камеры. Возвращает x, y, z. Сторона: любая (только картинка). Ошибки: вне партии.
-- Абсолютная позиция камеры: x, y, z.
function camera.pos()
    inGame("pos")
    return native.GetCameraAbsolutePosition()
end

-- Позиция камеры во внутренних координатах игры. Возвращает x, y, z. Сторона: любая. Ошибки: вне партии.
-- Позиция камеры в её внутренних координатах (для совместимости со скриптами игры).
function camera.gamePos()
    inGame("gamePos")
    return native.GetCameraPosition()
end

-- Точка взгляда камеры. Возвращает x, y, z. Сторона: любая. Ошибки: вне партии.
-- Точка взгляда: x, y, z.
function camera.target()
    inGame("target")
    return native.GetCameraTargetPosition()
end

-- Поставить камеру по XZ. Параметры: x, z — мировые координаты (высоту подберёт движок). Возвращает nil. Сторона: любая. Ошибки: вне партии; x/z не числа.
-- Поставить камеру по XZ (высоту движок подберёт сам).
function camera.position(x, z)
    inGame("position")
    native.SetMainCameraPositionXZ(num(x, "x"), num(z, "z"))
end

-- Повернуть камеру. Параметры: x, y, z — радианы. Возвращает nil. Сторона: любая. Ошибки: вне партии; углы не числа.
-- Повернуть камеру (радианы XYZ).
function camera.rotate(x, y, z)
    inGame("rotate")
    native.SetMainCameraRotateXYZ(num(x, "x"), num(y, "y"), num(z, "z"))
end

-- Плавно ехать к точке XZ. Параметры: x, z — цель; speed — скорость (nil — скорость игры). Возвращает nil. Сторона: любая. Ошибки: вне партии; x/z/speed не числа.
-- Плавно ехать к точке XZ. speed — скорость (nil — оставить скорость игры).
-- Без speed(==nil) просто включает режим «ехать к цели».
function camera.moveTo(x, z, speed)
    inGame("moveTo")
    x, z = num(x, "x"), num(z, "z")
    if speed ~= nil then
        native.SetMainCameraMoveToTargetSpeed(num(speed, "speed"))
    end
    native.SetMainCameraMoveToTargetXZ(x, z)
    native.SetMainCameraMoveToTarget(true)
end

-- Остановить плавный переезд. Возвращает nil. Сторона: любая. Ошибки: вне партии.
function camera.stop()
    inGame("stop")
    native.SetMainCameraMoveToTarget(false)
end

-- Следить за объектом. Параметры: h — хендл юнита/здания, nil/0 — отпустить. Возвращает nil. Сторона: любая (только картинка). Ошибки: вне партии; h не число.
-- Следить за объектом: handle юнита/здания, nil/0 — отпустить.
function camera.follow(h)
    inGame("follow")
    if h == nil then h = 0 end
    native.SetCameraElasticTargetObject(handle(h))
end

-- За кем следит камера. Возвращает хендл объекта (0 — ни за кем). Сторона: любая. Ошибки: вне партии.
function camera.followed()
    inGame("followed")
    return native.GetCameraElasticTargetObject()
end

-- Ограничить область камеры. Параметры: t = { left=, top=, right=, bottom= } (мировые XZ). Возвращает nil. Сторона: любая. Ошибки: вне партии; t не таблица; границы не числа.
-- Ограничить область камеры: { left=, top=, right=, bottom= } (мировые XZ).
function camera.limits(t)
    inGame("limits")
    if type(t) ~= "table" then error("camera.limits: pass { left=, top=, right=, bottom= }", 2) end
    native.SetCameraElasticRestrict(num(t.left, "left"), num(t.top, "top"),
        num(t.right, "right"), num(t.bottom, "bottom"))
end

-- Текущие лимиты камеры. Возвращает { left=, top=, right=, bottom= }. Сторона: любая. Ошибки: вне партии.
function camera.getLimits()
    inGame("getLimits")
    local l, t, r, b = native.GetCameraElasticRestrict()
    return { left = l, top = t, right = r, bottom = b }
end

-- Высота камеры/земли над точкой XZ. Параметры: x, z — мировые координаты. Возвращает высоту (число). Сторона: любая. Ошибки: вне партии; x/z не числа.
-- Высота камеры/земли над точкой XZ (натив игры, учитывает рельеф).
function camera.height(x, z)
    inGame("height")
    return native.GetCameraAbsoluteHeightByXZ(num(x, "x"), num(z, "z"))
end

-- ---------- кинематографические треки ----------

-- Стереть кинематографические треки. Возвращает nil. Сторона: любая. Ошибки: вне партии.
function camera.trackClear()
    inGame("trackClear")
    native.CameraTrackListClear()
end

-- Сколько треков. Возвращает число. Сторона: любая. Ошибки: вне партии.
function camera.trackCount()
    inGame("trackCount")
    return native.GetCameraTrackListCount()
end

-- Новый трек. Возвращает индекс трека (сверьте с trackCurrent: 0 или 1-based по версии игры). Сторона: любая. Ошибки: вне партии.
function camera.trackAdd()
    inGame("trackAdd")
    return native.AddCameraTrack()
end

-- Добавить точку трека: цель + глаз. Параметры: name — имя точки; tx, ty, tz — цель; ex, ey, ez — глаз. Возвращает nil. Сторона: любая. Ошибки: вне партии; имя пустое; координаты не числа.
function camera.trackPoint(name, tx, ty, tz, ex, ey, ez)
    inGame("trackPoint")
    if type(name) ~= "string" or name == "" then
        error("camera.trackPoint: name must be a non-empty string", 2)
    end
    native.AddCameraTrackPoint(name, num(tx, "tx"), num(ty, "ty"), num(tz, "tz"),
        num(ex, "ex"), num(ey, "ey"), num(ez, "ez"))
end

-- Играть трек. Параметры: index — индекс трека. Возвращает nil. Сторона: любая. Ошибки: вне партии; index не число.
function camera.trackPlay(index)
    inGame("trackPlay")
    native.SetCameraCurrentTrackIndex(math.tointeger(tonumber(index))
        or error("camera.trackPlay: index must be a number", 2))
end

-- Текущий трек. Возвращает индекс. Сторона: любая. Ошибки: вне партии.
function camera.trackCurrent()
    inGame("trackCurrent")
    return native.GetCameraCurrentTrackIndex()
end

-- Имя трека по индексу. Параметры: index — индекс трека. Возвращает имя (строка). Сторона: любая. Ошибки: вне партии; index не число.
function camera.trackName(index)
    inGame("trackName")
    return native.GetCameraTrackNameByIndex(math.tointeger(tonumber(index))
        or error("camera.trackName: index must be a number", 2))
end
