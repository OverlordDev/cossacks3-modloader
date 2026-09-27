-- minimap — родная миникарта игры: видимость, зум, позиция и свои иконки.
--
-- Оставляем игровой рендер и рисуем поверх: иконки, цели, направления, мигание.
-- Только картинка у этого игрока (client). Вне партии нативы падают.
--
--   minimap.show(true)
--   minimap.zoom(1.5); local z = minimap.getZoom()
--   minimap.frustum(true)                 -- показывать конус камеры
--   local i = minimap.icon("target")      -- новый примитив -> индекс
--   minimap.setPos(i, x, y)               -- x,y — координаты карты (как у игры)
--   minimap.setDir(i, dx, dy)             -- направление стрелки
--   minimap.setBlink(i, 0.5, 5)           -- мигать: интервал, число раз (0 — бесконечно?)
--   minimap.setVisible(i, true)
--   minimap.clear()                       -- убрать все свои иконки
--
-- Координаты примитивов — в системе миникарты (x, y), не мировые x, z.
-- Мировые координаты переводите сами (пропорция к размеру карты из map.info()).

minimap = {}

-- Число. Ошибки: не число, NaN или inf.
local function num(v, name)
    local n = tonumber(v)
    if not n or n ~= n or n == math.huge or n == -math.huge then
        error("minimap: " .. name .. " must be a number", 3)
    end
    return n
end

-- Индекс/тэг примитива. Возвращает integer. Ошибки: не число.
local function idx(v, name)
    local i = math.tointeger(tonumber(v))
    if not i then error("minimap: " .. (name or "index") .. " must be a number", 3) end
    return i
end

-- Проверка партии (нужна части функций). Ошибки: вне партии (проверяйте game.isInGame()).
local function inGame(where)
    if not game.isInGame() then
        error("minimap." .. where .. ": no active game (check game.isInGame())", 3)
    end
end

-- Показать/скрыть миникарту. Параметры: visible (по умолчанию true). Возвращает nil. Сторона: client (только картинка). Ошибки: нет (вне партии не проверяется).
function minimap.show(visible)
    if visible == nil then visible = true end
    native.SetGUIMiniMapVisible(visible and true or false)
end

-- Видна ли миникарта. Возвращает boolean. Сторона: client. Ошибки: нет.
function minimap.isVisible()
    return native.GetGUIMiniMapVisible()
end

-- Перерисовать миникарту. Возвращает nil. Сторона: client. Ошибки: нет (натив сам решает).
function minimap.update()
    native.GUIMiniMapUpdate()
end

-- Размер текстуры миникарты: чтение или запись. Параметры: без args — прочитать (возвращает w, h); с w, h — записать целыми. Возвращает w, h при чтении. Сторона: client. Ошибки: при записи w/h не целые.
-- Размер текстуры миникарты в пикселях.
function minimap.textureSize(w, h)
    if w == nil and h == nil then
        return native.GetGUIMiniMapTextureWidth(), native.GetGUIMiniMapTextureHeight()
    end
    native.SetGUIMiniMapTextureSize(math.tointeger(tonumber(w))
        or error("minimap.textureSize: w must be an integer", 2),
        math.tointeger(tonumber(h)) or error("minimap.textureSize: h must be an integer", 2))
end

-- Положение элемента миникарты: чтение или запись. Параметры: без args — возвращает x, y, z; с x, y, z — ставит. Сторона: client. Ошибки: при записи x/y/z не числа.
-- Положение элемента миникарты на экране.
function minimap.pos(x, y, z)
    if x == nil then
        return native.GetGUIMiniMapPositionX(), native.GetGUIMiniMapPositionY(),
               native.GetGUIMiniMapPositionZ()
    end
    native.SetGUIMiniMapPosition(num(x, "x"), num(y, "y"), num(z or 0, "z"))
end

-- Зум миникарты: чтение или запись. Параметры: z nil — прочитать (возвращает число); иначе поставить. Сторона: client. Ошибки: z не число.
function minimap.zoom(z)
    if z == nil then return native.GetGUIMinimapZoom() end
    native.SetGUIMinimapZoom(num(z, "zoom"))
end

-- Текущий зум. Возвращает число. Сторона: client. Ошибки: нет.
function minimap.getZoom()
    return native.GetGUIMinimapZoom()
end

-- Конус камеры на миникарте: чтение или запись. Параметры: visible nil — прочитать (boolean); иначе показать/скрыть. Сторона: client. Ошибки: нет.
function minimap.frustum(visible)
    if visible == nil then return native.GetMiniMapFrustumVisible() end
    native.SetMiniMapFrustumVisible(visible and true or false)
end

-- ---------- примитивы (свои иконки поверх) ----------

-- Создать примитив с именем. Параметры: name — уникальное непустое имя. Возвращает индекс. Сторона: client (нужна партия). Ошибки: вне партии; имя пустое.
-- Создать примитив с именем -> индекс. Имя — любое уникальное ("target1").
function minimap.icon(name)
    inGame("icon")
    if type(name) ~= "string" or name == "" then
        error("minimap.icon: name must be a non-empty string", 2)
    end
    return native.CreateGUIMiniMapPrimitive(name)
end

-- Позиция примитива в координатах миникарты. Параметры: i — индекс; x, y. Возвращает nil. Сторона: client (нужна партия). Ошибки: вне партии; индекс/координаты не числа.
function minimap.setPos(i, x, y)
    inGame("setPos")
    native.SetGUIMiniMapPrimitivePosition(idx(i), num(x, "x"), num(y, "y"))
end

-- Направление стрелки примитива. Параметры: i — индекс; x, y — вектор. Возвращает nil. Сторона: client (нужна партия). Ошибки: вне партии; индекс/вектор не числа.
function minimap.setDir(i, x, y)
    inGame("setDir")
    native.SetGUIMiniMapPrimitiveDirection(idx(i), num(x, "x"), num(y, "y"))
end

-- Тэг примитива (для поиска). Параметры: i — индекс; tag — целое. Возвращает nil. Сторона: client (нужна партия). Ошибки: вне партии; индекс/тэг не целые.
function minimap.setTag(i, tag)
    inGame("setTag")
    native.SetGUIMiniMapPrimitiveTag(idx(i), math.tointeger(tonumber(tag))
        or error("minimap.setTag: tag must be an integer", 2))
end

-- Имя примитива. Параметры: i — индекс; name — строка. Возвращает nil. Сторона: client (нужна партия). Ошибки: вне партии; индекс не число; name не строка.
function minimap.setName(i, name)
    inGame("setName")
    if type(name) ~= "string" then error("minimap.setName: name must be a string", 2) end
    native.SetGUIMiniMapPrimitiveName(idx(i), name)
end

-- Мигание примитива. Параметры: i — индекс; interval — секунды; count — целое число раз. Возвращает nil. Сторона: client (нужна партия). Ошибки: вне партии; индекс не число; interval не число; count не целое.
function minimap.setBlink(i, interval, count)
    inGame("setBlink")
    native.SetGUIMiniMapPrimitiveBlink(idx(i), num(interval, "interval"),
        math.tointeger(tonumber(count)) or error("minimap.setBlink: count must be an integer", 2))
end

-- Видимость примитива. Параметры: i — индекс; visible — bool. Возвращает nil. Сторона: client (нужна партия). Ошибки: вне партии; индекс не число.
function minimap.setVisible(i, visible)
    inGame("setVisible")
    native.SetGUIMiniMapPrimitiveVisible(idx(i), visible and true or false)
end

-- Виден ли примитив. Параметры: i — индекс. Возвращает boolean. Сторона: client. Ошибки: индекс не число (вне партии не проверяется).
function minimap.isVisibleAt(i)
    return native.GetGUIMiniMapPrimitiveVisible(idx(i))
end

-- Убрать примитив. Параметры: i — индекс. Возвращает nil. Сторона: client. Ошибки: индекс не число.
function minimap.remove(i)
    native.RemoveGUIMiniMapPrimitive(idx(i))
end

-- Убрать все свои примитивы. Возвращает nil. Сторона: client. Ошибки: нет.
function minimap.clear()
    native.GUIMiniMapPrimitivesClear()
end

-- Сколько своих примитивов. Возвращает число. Сторона: client. Ошибки: нет.
function minimap.count()
    return native.GetGUIMiniMapPrimitivesCount()
end

-- Индекс примитива по тэгу. Параметры: tag — целое. Возвращает индекс (или -1/ничего). Сторона: client. Ошибки: tag не целое.
function minimap.findByTag(tag)
    return native.GetGUIMiniMapPrimitiveIndexOfTag(math.tointeger(tonumber(tag))
        or error("minimap.findByTag: tag must be an integer", 2))
end

-- Поставить иконку в точку (создаёт или двигает по тэгу). Параметры: name — имя; x, y — координаты миникарты; opts.tag/dx/dy/blink={интервал,число}/visible. Возвращает индекс примитива. Сторона: client (нужна партия). Ошибки: вне партии; имя пустое; координаты не числа.
-- Удобное: поставить иконку с именем в точку (создаёт или двигает существующую по тэгу).
-- Возвращает индекс примитива.
function minimap.put(name, x, y, opts)
    inGame("put")
    opts = opts or {}
    if type(name) ~= "string" or name == "" then
        error("minimap.put: name must be a non-empty string", 2)
    end
    local tag = opts.tag
    local i
    if tag ~= nil then
        i = minimap.findByTag(tag)
        if i == nil or i < 0 then i = minimap.icon(name) end
    else
        i = minimap.icon(name)
    end
    minimap.setPos(i, x, y)
    if opts.dx or opts.dy then minimap.setDir(i, opts.dx or 0, opts.dy or 0) end
    if tag ~= nil then minimap.setTag(i, tag) end
    if opts.blink then minimap.setBlink(i, opts.blink[1] or 0.5, opts.blink[2] or 0) end
    if opts.visible ~= nil then minimap.setVisible(i, opts.visible) end
    return i
end
