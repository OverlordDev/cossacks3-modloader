-- behaviour — физика объектов: импульсы, отдача, подброс, отскоки.
--
-- МЕНЯЕТ МИР (инерция двигает объекты): только server/shared, в shared —
-- одинаково на всех машинах. Имена классов поведений — из data/behaviours
-- (подбирайте в игре: неверный класс игра игнорирует или роняет объект).
--
--   local b = behaviour.create(h, "cannon_recoil")  -- класс + ключ; behaviour.destroy(b)
--   local ph = behaviour.inertia(h)                 -- физика объекта -> id
--   behaviour.force(ph, 500, 200, 0)                -- толчок (отброс, взрывная волна)
--   behaviour.torque(ph, 0, 0, 30)                 -- закрутить (turn, roll, pitch)
--   behaviour.push(ph, 0, -981, 0)                 -- постоянное ускорение (падение)
--   behaviour.bounce(ph, 0, 1, 0, 0.6)             -- отскок от плоскости (нормаль + упругость)
--   behaviour.mirror(ph)                            -- отразить скорость
--
-- w-компонента силы/ускорения — кручение вокруг оси (конвенция движка).

behaviour = {}

local function checkId(id, where)
    id = math.tointeger(tonumber(id))
    if not id then error("behaviour." .. where .. ": id must be a number", 3) end
    return id
end

local function checkHandle(h)
    h = math.tointeger(tonumber(h))
    if not h or h == 0 then error("behaviour: handle must be a non-zero number", 3) end
    return h
end

local function num(v, name)
    local n = tonumber(v)
    if not n or n ~= n then error("behaviour: " .. name .. " must be a number", 3) end
    return n
end

local function needServer(where)
    if not game.exec then
        error("behaviour." .. where .. ": only server/shared scripts can touch physics", 3)
    end
    if not game.isInGame() then
        error("behaviour." .. where .. ": no active game (check game.isInGame())", 3)
    end
end

-- Повесить класс поведения на объект. Парам: h — хендл; classname — из data/behaviours; key — опциональный ключ.
-- Возвращает id поведения. Сторона: только server/shared. Ошибки: нулевой хендл; пустой classname; плохой key; вызов с client; нет игры.
function behaviour.create(h, classname, key)
    needServer("create")
    h = checkHandle(h)
    if type(classname) ~= "string" or classname == "" then
        error("behaviour.create: classname must be a non-empty string", 2)
    end
    if key ~= nil then
        if type(key) ~= "string" then error("behaviour.create: key must be a string", 2) end
        return native.BehaviourCreateWithKey(h, classname, key, false)
    end
    return native.BehaviourCreate(h, classname, true, false)
end

-- Снять поведение с объекта. Парам: id — id поведения. Ничего не возвращает.
-- Сторона: только server/shared. Ошибки: id не число; вызов с client; нет игры.
function behaviour.destroy(id)
    needServer("destroy")
    native.BehaviourDestroy(checkId(id, "destroy"))
end

-- Физика объекта (создаёт, если нет). Парам: h — хендл объекта. Возвращает id инерции.
-- Дальше — force/torque/push/bounce по id. Сторона: только server/shared.
-- Ошибки: нулевой хендл; вызов с client; нет игры.
function behaviour.inertia(h)
    needServer("inertia")
    return native.GetOrCreateBehaviourInertia(checkHandle(h))
end

-- Разовый толчок: взрывная волна, отдача, отбрасывание. Парам: id; fx, fy, fz — сила; fw — кручение (0).
-- Ничего не возвращает. Сторона: только server/shared. Ошибки: нечисловые компоненты; вызов с client; нет игры.
function behaviour.force(id, fx, fy, fz, fw)
    needServer("force")
    native.BehaviourInertiaApplyForce(checkId(id, "force"),
        num(fx, "fx"), num(fy, "fy"), num(fz, "fz"), num(fw or 0, "fw"))
end

-- Вращательный импульс. Парам: id; turn, roll, pitch — числа. Ничего не возвращает.
-- Сторона: только server/shared. Ошибки: нечисловые компоненты; вызов с client; нет игры.
function behaviour.torque(id, turn, roll, pitch)
    needServer("torque")
    native.BehaviourInertiaApplyTorque(checkId(id, "torque"),
        num(turn, "turn"), num(roll, "roll"), num(pitch, "pitch"))
end

-- Постоянное ускорение (гравитация, ветер, течение). Парам: id; ax, ay, az — ускорение; aw — кручение (0).
-- Ничего не возвращает. Сторона: только server/shared. Ошибки: нечисловые компоненты; вызов с client; нет игры.
function behaviour.push(id, ax, ay, az, aw)
    needServer("push")
    native.BehaviourInertiaApplyTranslationAcceleration(checkId(id, "push"),
        num(ax, "ax"), num(ay, "ay"), num(az, "az"), num(aw or 0, "aw"))
end

-- Отскок от плоскости с нормалью (nx, ny, nz) и упругостью restitution 0..1. Парам: id + числа.
-- Ничего не возвращает. Сторона: только server/shared. Ошибки: нечисловые компоненты; вызов с client; нет игры.
function behaviour.bounce(id, nx, ny, nz, restitution)
    needServer("bounce")
    native.BehaviourInertiaSurfaceBounce(checkId(id, "bounce"),
        num(nx, "nx"), num(ny, "ny"), num(nz, "nz"), 0, num(restitution, "restitution"))
end

-- Отразить скорость (зеркальный отскок). Парам: id — id инерции. Ничего не возвращает.
-- Сторона: только server/shared. Ошибки: id не число; вызов с client; нет игры.
function behaviour.mirror(id)
    needServer("mirror")
    native.BehaviourInertiaMirrorTranslation(checkId(id, "mirror"))
end

-- Удобное: взрывной толчок от точки (сила падает с расстоянием). Парам: h; x, z — эпицентр; power — сила; up — вверх (300).
-- Возвращает id инерции или nil (нет позиции). Сторона: только server/shared.
-- Ошибки: нулевой хендл; нечисловые x/power; вызов с client; нет игры.
function behaviour.blast(h, x, z, power, up)
    needServer("blast")
    h = checkHandle(h)
    power = num(power, "power")
    local px, _, pz = world.pos(h)
    if not px then return end
    local dx, dz = px - num(x, "x"), pz - num(z, "z")
    local d = math.max(1, math.sqrt(dx * dx + dz * dz))
    local id = behaviour.inertia(h)
    behaviour.force(id, dx / d * power / d, num(up or 300, "up"), dz / d * power / d, 0)
    return id
end
