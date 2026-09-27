-- animation + model — анимации, актёры, материалы и трансформ юнитов.
--
-- Только внешность объекта у всех игроков одинаково: в сети вызывайте в shared
-- (иначе у одного играет, у другого нет — визуальный рассинхрон, партию не роняет,
-- но выглядит сломанным). Для чисто клиентских катсцен — на client.
--
--   animation.play(h, "attack")           -- разовая frame-анимация
--   animation.cycle(h, "work")            -- зацикленная (idle/work/walk...)
--   animation.frame(h, 12)                -- поставить кадр; animation.frame(h) — прочитать
--   local info = animation.info(h)        -- { frame=, frameName=, cycle= }
--   model.actor(h, "my_actor")            -- сменить актёр (ресурсы из content.lua/мода)
--   model.material(h, "my_material")
--   model.scale(h, 1.2, 1.2, 1.2)
--   model.show(h, false)                  -- скрыть; model.isVisible(h)
--   model.rotate(h, 0, 1.57, 0)           -- абсолютный поворот (радианы)
--   model.pointTo(h, x, y, z)             -- развернуть к точке (верх +Y)
--
-- Имена анимаций — из .oss актёра юнита (смотрите GAME_STATE / model_example).
-- Неверное имя игра обычно игнорирует, но может и упасть — проверяйте на копии сейва.

animation = {}
model = {}

-- Ненулевой хендл объекта. Возвращает integer. Ошибки: не число или 0.
local function checkHandle(h)
    h = math.tointeger(tonumber(h))
    if not h or h == 0 then error("animation: handle must be a non-zero number", 3) end
    return h
end

-- Непустое имя (анимация/актёр/материал). Возвращает строку. Ошибки: не строка или пустая.
local function checkName(name, what)
    if type(name) ~= "string" or name == "" then
        error((what or "animation") .. ": name must be a non-empty string", 3)
    end
    return name
end

-- Число (масштаб/угол/координата). Ошибки: не число, NaN или inf.
local function num(v, name)
    local n = tonumber(v)
    if not n or n ~= n or n == math.huge or n == -math.huge then
        error("animation: " .. name .. " must be a number", 3)
    end
    return n
end

-- Проверка партии. Ошибки: вне партии (проверяйте game.isInGame()).
local function inGame(where)
    if not game.isInGame() then
        error(where .. ": no active game (check game.isInGame())", 3)
    end
end

-- Разовая анимация. Параметры: h — хендл; name — имя из .oss; randomOffset — случайное смещение (bool). Возвращает nil. Сторона: любая (только внешность; в сети — в shared). Ошибки: вне партии; h нулевой; имя пустое.
-- Разовая анимация (выстрел, удар, смерть).
function animation.play(h, name, randomOffset)
    inGame("animation.play")
    h = checkHandle(h)
    checkName(name, "animation.play")
    native.GameObjectSetFrameAnimationByHandle(h, name, randomOffset == true)
end

-- Зацикленная анимация. Параметры: h — хендл; name — имя цикла; randomCycles/randomFrame — случайность (bool). Возвращает nil. Сторона: любая (в сети — в shared). Ошибки: вне партии; h нулевой; имя пустое.
-- Переключить на зацикленную (стойка, ходьба, работа).
function animation.cycle(h, name, randomCycles, randomFrame)
    inGame("animation.cycle")
    h = checkHandle(h)
    checkName(name, "animation.cycle")
    native.GameObjectSwitchToAnimationCyclesByHandle(h, name,
        randomCycles == true, randomFrame == true)
end

-- Разовая анимация через SwitchTo-вариант движка. Параметры: h — хендл; name — имя; randomOffset — bool. Возвращает nil. Сторона: любая (в сети — в shared). Ошибки: вне партии; h нулевой; имя пустое.
-- Переключить на разовую с проигрыванием (вариант движка SwitchTo...).
function animation.switch(h, name, randomOffset)
    inGame("animation.switch")
    h = checkHandle(h)
    checkName(name, "animation.switch")
    native.GameObjectSwitchToFrameAnimationByHandle(h, name, randomOffset == true)
end

-- Кадр анимации: чтение или запись. Параметры: h — хендл; frame — целое (nil — прочитать). Возвращает номер кадра при чтении, иначе nil. Сторона: любая (в сети — в shared). Ошибки: вне партии; h нулевой; frame не целое.
-- Кадр: animation.frame(h) -> номер; animation.frame(h, 12) — поставить.
function animation.frame(h, frame)
    inGame("animation.frame")
    h = checkHandle(h)
    if frame == nil then return native.GetGameObjectCurrentFrameByHandle(h) end
    native.SetGameObjectCurrentFrameByHandle(h, math.tointeger(tonumber(frame))
        or error("animation.frame: frame must be an integer", 2))
end

-- Что сейчас играет. Параметры: h — хендл. Возвращает { frameName=, cycle=, frame= }. Сторона: любая. Ошибки: вне партии; h нулевой.
-- Что сейчас играет: имена frame-анимации и цикла + текущий кадр.
function animation.info(h)
    inGame("animation.info")
    h = checkHandle(h)
    return {
        frameName = native.GetGameObjectFrameAnimationNameByHandle(h),
        cycle = native.GetGameObjectAnimationCycleNameByHandle(h),
        frame = native.GetGameObjectCurrentFrameByHandle(h),
    }
end

-- Сколько кадров в цикле. Параметры: h — хендл; name — имя цикла. Возвращает число кадров (0 — цикла нет). Сторона: любая. Ошибки: вне партии; h нулевой; имя пустое.
-- Сколько кадров в цикле; 0/ничего — такого цикла у актёра нет.
function animation.cycleFrames(h, name)
    inGame("animation.cycleFrames")
    h = checkHandle(h)
    checkName(name, "animation.cycleFrames")
    return native.GetGameObjectAnimationCycleCountFrameByHandle(h, name)
end

-- Сколько кадров осталось в текущем цикле. Параметры: h — хендл. Возвращает число. Сторона: любая. Ошибки: вне партии; h нулевой.
function animation.cycleLeft(h)
    inGame("animation.cycleLeft")
    return native.GetGameObjectAnimationCycleLeftFrameByHandle(checkHandle(h))
end

-- ---------- model: внешность ----------

-- Сменить актёр объекта. Параметры: h — хендл; name — имя актёра. Возвращает nil. Сторона: любая (в сети — в shared). Ошибки: вне партии; h нулевой; имя пустое.
function model.actor(h, name)
    inGame("model.actor")
    native.SetGameObjectActorNameByHandle(checkHandle(h), checkName(name, "model.actor"))
end

-- Сменить материал объекта. Параметры: h — хендл; name — имя материала. Возвращает nil. Сторона: любая (в сети — в shared). Ошибки: вне партии; h нулевой; имя пустое.
function model.material(h, name)
    inGame("model.material")
    native.SetGameObjectMaterialNameByHandle(checkHandle(h), checkName(name, "model.material"))
end

-- Масштаб объекта. Параметры: h — хендл; x, y, z или таблица {x,y,z} (y/z по умолчанию = x). Возвращает nil. Сторона: любая (в сети — в shared). Ошибки: вне партии; h нулевой; масштаб не число.
function model.scale(h, x, y, z)
    inGame("model.scale")
    h = checkHandle(h)
    if type(x) == "table" then x, y, z = x[1], x[2], x[3] end
    native.SetGameObjectScaleByHandle(h, num(x, "x"), num(y or x, "y"), num(z or x, "z"))
end

-- Показать/скрыть объект. Параметры: h — хендл; visible (по умолчанию true). Возвращает nil. Сторона: любая (в сети — в shared). Ошибки: вне партии; h нулевой.
function model.show(h, visible)
    inGame("model.show")
    if visible == nil then visible = true end
    native.SetGameObjectVisibleByHandle(checkHandle(h), visible and true or false)
end

-- Абсолютный поворот объекта. Параметры: h — хендл; rx, ry, rz — радианы. Возвращает nil. Сторона: любая (в сети — в shared). Ошибки: вне партии; h нулевой; углы не числа.
function model.rotate(h, rx, ry, rz)
    inGame("model.rotate")
    h = checkHandle(h)
    native.GameObjectRotateAbsoluteByHandle(h, num(rx, "rx"), num(ry, "ry"), num(rz, "rz"))
end

-- Развернуть объект к точке. Параметры: h — хендл; x, y, z — мировая точка; upx/upy/upz — верх (по умолчанию 0,1,0). Возвращает nil. Сторона: любая (в сети — в shared). Ошибки: вне партии; h нулевой; координаты не числа.
-- Развернуть объект к точке (мировые x, y, z). Вверх — +Y.
function model.pointTo(h, x, y, z, upx, upy, upz)
    inGame("model.pointTo")
    h = checkHandle(h)
    native.GameObjectPointToByHandle(h, num(x, "x"), num(y, "y"), num(z, "z"),
        num(upx or 0, "upx"), num(upy or 1, "upy"), num(upz or 0, "upz"))
end

-- Сменить набор циклов анимации. Параметры: h — хендл; libName — имя библиотеки циклов. Возвращает nil. Сторона: любая (в сети — в shared). Ошибки: вне партии; h нулевой; имя пустое.
function model.setCyclesList(h, libName)
    inGame("model.setCyclesList")
    native.SetGameObjectAnimationCyclesListByHandle(checkHandle(h), checkName(libName, "model.setCyclesList"))
end

-- Имя текущего набора циклов. Параметры: h — хендл. Возвращает имя (строка). Сторона: любая. Ошибки: вне партии; h нулевой.
function model.getCyclesList(h)
    inGame("model.getCyclesList")
    return native.GetGameObjectAnimationCyclesListByHandle(checkHandle(h))
end
