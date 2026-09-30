-- vec — чистые 2D/3D векторы (без вызовов игры, везде: shared/lockstep-safe).
--
-- Векторы — обычные таблицы: v2 { x =, y = }, v3 { x =, y =, z = }.
-- ВАЖНО ДЛЯ КАРТЫ COSSACKS: карта плоская (оси x/z), поэтому координату z карты
-- передавайте ВТОРЫМ компонентом v2: vec.v2(x, z). Поле называется y, но хранит z карты:
--   local p = vec.v2(10, 20)   -- x = 10, z карты = 20 (лежит в p.y)
--   local q = vec.v3(10, 5, 20) -- полный 3D: x, y (высота), z
-- УГЛЫ ВЕЗДЕ РАДИАНЫ (rotate2/fromAngle/toAngle).
-- Все функции возвращают НОВЫЕ таблицы, входы не мутируются.
-- Нулевой вектор нормализуется в нулевой (НЕ NaN). Деление на 0 — ошибка.
-- cross для v2 возвращает СКАЛЯР, для v3 — ВЕКТОР.
-- Библиотеки math/table/string/os НЕ изменяются, только читаются. math.random нет.
--
--   local d = vec.distance(vec.v2(0, 0), vec.v2(3, 4)) --> 5
--   local n = vec.normalize(vec.v2(3, 4))              --> { x = 0.6, y = 0.8 }
--
-- Сторона: везде (pure Lua). Десинка нет (детерминированные вычисления).

vec = {}

-- Размерность таблицы-вектора: 2, 3 или nil (не вектор; NaN-компоненты — не вектор).
local function dimOf(v)
    if type(v) ~= "table" then return nil end
    local x = tonumber(v.x)
    local y = tonumber(v.y)
    if x == nil or x ~= x or y == nil or y ~= y then return nil end
    if v.z == nil then return 2 end
    local z = tonumber(v.z)
    if z == nil or z ~= z then return nil end
    return 3
end

-- Проверить вектор (ошибка "vec.<fn>: <param> must be a vector"). Возвращает размерность.
local function checkVec(v, fname, pname)
    local d = dimOf(v)
    if not d then
        error("vec." .. fname .. ": " .. pname .. " must be a vector {x=,y=} or {x=,y=,z=}", 3)
    end
    return d
end

-- Проверить скаляр (ошибка "vec.<fn>: <param> must be a number"). Возвращает число.
local function checkScalar(s, fname, pname)
    local n = tonumber(s)
    if n == nil or n ~= n then
        error("vec." .. fname .. ": " .. pname .. " must be a number", 3)
    end
    return n
end

-- Проверить целые decimals для round (ошибка "vec.<fn>: decimals must be a non-negative integer").
local function checkDecimals(decimals, fname)
    if decimals == nil then decimals = 0 end
    local d = math.tointeger(decimals)
    if not d or d < 0 then
        error("vec." .. fname .. ": decimals must be a non-negative integer", 3)
    end
    return d
end

-- vec.v2(x, y): новый 2D-вектор { x =, y = }. Для карты Cossacks вторым идёт z карты.
-- NaN/не-число — ошибка. Возврат: новая таблица. Сторона: везде (pure).
-- Ошибки: vec.v2: x/y must be a number.
function vec.v2(x, y)
    x = checkScalar(x, "v2", "x")
    y = checkScalar(y, "v2", "y")
    return { x = x, y = y }
end

-- vec.v3(x, y, z): новый 3D-вектор { x =, y =, z = }. NaN/не-число — ошибка.
-- Возврат: новая таблица. Сторона: везде (pure). Ошибки: vec.v3: x/y/z must be a number.
function vec.v3(x, y, z)
    x = checkScalar(x, "v3", "x")
    y = checkScalar(y, "v3", "y")
    z = checkScalar(z, "v3", "z")
    return { x = x, y = y, z = z }
end

-- vec.new(x, y, z): конструктор (z == nil → v2, иначе v3). Возврат: новая таблица.
-- Сторона: везде (pure). Ошибки: vec.new: x/y/z must be a number.
function vec.new(x, y, z)
    if z == nil then
        return vec.v2(x, y)
    end
    return vec.v3(x, y, z)
end

-- vec.clone(v): копия вектора той же размерности. Возврат: новая таблица.
-- Сторона: везде (pure). Ошибки: vec.clone: v must be a vector.
function vec.clone(v)
    local d = checkVec(v, "clone", "v")
    if d == 3 then
        return { x = v.x, y = v.y, z = v.z }
    end
    return { x = v.x, y = v.y }
end

-- vec.isValid(v, dim): проверка формы (компоненты — числа, не NaN).
-- dim nil → v2 или v3; dim 2/3 → только та размерность. Другое dim — ошибка.
-- Возврат: boolean (на плохом векторе false, НЕ ошибка). Сторона: везде (pure).
-- Ошибки: vec.isValid: dim must be 2, 3 or nil.
function vec.isValid(v, dim)
    if dim == nil then
        return dimOf(v) ~= nil
    end
    if dim ~= 2 and dim ~= 3 then
        error("vec.isValid: dim must be 2, 3 or nil", 2)
    end
    return dimOf(v) == dim
end

-- vec.add(a, b): покомпонентная сумма. Размерности должны совпадать, иначе ошибка.
-- Возврат: новый вектор. Сторона: везде (pure).
-- Ошибки: vec.add: ... must be a vector; vectors must have same dimension.
function vec.add(a, b)
    local da = checkVec(a, "add", "a")
    local db = checkVec(b, "add", "b")
    if da ~= db then
        error("vec.add: vectors must have same dimension", 2)
    end
    if da == 3 then
        return { x = a.x + b.x, y = a.y + b.y, z = a.z + b.z }
    end
    return { x = a.x + b.x, y = a.y + b.y }
end

-- vec.sub(a, b): покомпонентная разность. Размерности должны совпадать, иначе ошибка.
-- Возврат: новый вектор. Сторона: везде (pure).
-- Ошибки: vec.sub: ... must be a vector; vectors must have same dimension.
function vec.sub(a, b)
    local da = checkVec(a, "sub", "a")
    local db = checkVec(b, "sub", "b")
    if da ~= db then
        error("vec.sub: vectors must have same dimension", 2)
    end
    if da == 3 then
        return { x = a.x - b.x, y = a.y - b.y, z = a.z - b.z }
    end
    return { x = a.x - b.x, y = a.y - b.y }
end

-- vec.mul(v, scalar): умножение на скаляр. Возврат: новый вектор. Сторона: везде (pure).
-- Ошибки: vec.mul: v must be a vector; scalar must be a number.
function vec.mul(v, scalar)
    local d = checkVec(v, "mul", "v")
    scalar = checkScalar(scalar, "mul", "scalar")
    if d == 3 then
        return { x = v.x * scalar, y = v.y * scalar, z = v.z * scalar }
    end
    return { x = v.x * scalar, y = v.y * scalar }
end

-- vec.div(v, scalar): деление на скаляр. Деление на 0 — ошибка "vec.div: division by zero".
-- Возврат: новый вектор. Сторона: везде (pure).
-- Ошибки: vec.div: v must be a vector; scalar must be a number; division by zero.
function vec.div(v, scalar)
    local d = checkVec(v, "div", "v")
    scalar = checkScalar(scalar, "div", "scalar")
    if scalar == 0 then
        error("vec.div: division by zero", 2)
    end
    if d == 3 then
        return { x = v.x / scalar, y = v.y / scalar, z = v.z / scalar }
    end
    return { x = v.x / scalar, y = v.y / scalar }
end

-- vec.neg(v): противоположный вектор. Возврат: новый вектор. Сторона: везде (pure).
-- Ошибки: vec.neg: v must be a vector.
function vec.neg(v)
    local d = checkVec(v, "neg", "v")
    if d == 3 then
        return { x = -v.x, y = -v.y, z = -v.z }
    end
    return { x = -v.x, y = -v.y }
end

-- vec.length(v): длина (модуль) вектора. Возврат: число. Сторона: везде (pure).
-- Ошибки: vec.length: v must be a vector.
function vec.length(v)
    local d = checkVec(v, "length", "v")
    if d == 3 then
        return math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
    end
    return math.sqrt(v.x * v.x + v.y * v.y)
end

-- vec.lengthSquared(v): квадрат длины (без корня, для сравнений). Возврат: число.
-- Сторона: везде (pure). Ошибки: vec.lengthSquared: v must be a vector.
function vec.lengthSquared(v)
    local d = checkVec(v, "lengthSquared", "v")
    if d == 3 then
        return v.x * v.x + v.y * v.y + v.z * v.z
    end
    return v.x * v.x + v.y * v.y
end

-- vec.normalize(v): единичный вектор того же направления.
-- Нулевой вектор даёт нулевой (НЕ NaN). Возврат: новый вектор. Сторона: везде (pure).
-- Ошибки: vec.normalize: v must be a vector.
function vec.normalize(v)
    local d = checkVec(v, "normalize", "v")
    local len = vec.length(v)
    if len == 0 then
        if d == 3 then return { x = 0, y = 0, z = 0 } end
        return { x = 0, y = 0 }
    end
    if d == 3 then
        return { x = v.x / len, y = v.y / len, z = v.z / len }
    end
    return { x = v.x / len, y = v.y / len }
end

-- vec.distance(a, b): расстояние между векторами. Размерности должны совпадать.
-- Возврат: число. Сторона: везде (pure).
-- Ошибки: vec.distance: ... must be a vector; vectors must have same dimension.
function vec.distance(a, b)
    local da = checkVec(a, "distance", "a")
    local db = checkVec(b, "distance", "b")
    if da ~= db then
        error("vec.distance: vectors must have same dimension", 2)
    end
    if da == 3 then
        local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
        return math.sqrt(dx * dx + dy * dy + dz * dz)
    end
    local dx, dy = a.x - b.x, a.y - b.y
    return math.sqrt(dx * dx + dy * dy)
end

-- vec.distanceSquared(a, b): квадрат расстояния (без корня). Размерности должны совпадать.
-- Возврат: число. Сторона: везде (pure).
-- Ошибки: vec.distanceSquared: ... must be a vector; vectors must have same dimension.
function vec.distanceSquared(a, b)
    local da = checkVec(a, "distanceSquared", "a")
    local db = checkVec(b, "distanceSquared", "b")
    if da ~= db then
        error("vec.distanceSquared: vectors must have same dimension", 2)
    end
    if da == 3 then
        local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
        return dx * dx + dy * dy + dz * dz
    end
    local dx, dy = a.x - b.x, a.y - b.y
    return dx * dx + dy * dy
end

-- vec.dot(a, b): скалярное произведение. Размерности должны совпадать.
-- Возврат: число. Сторона: везде (pure).
-- Ошибки: vec.dot: ... must be a vector; vectors must have same dimension.
function vec.dot(a, b)
    local da = checkVec(a, "dot", "a")
    local db = checkVec(b, "dot", "b")
    if da ~= db then
        error("vec.dot: vectors must have same dimension", 2)
    end
    if da == 3 then
        return a.x * b.x + a.y * b.y + a.z * b.z
    end
    return a.x * b.x + a.y * b.y
end

-- vec.cross(a, b): векторное произведение. Размерности должны совпадать.
-- v2 → СКАЛЯР (x1*y2 - y1*x2); v3 → ВЕКТОР. Сторона: везде (pure).
-- Ошибки: vec.cross: ... must be a vector; vectors must have same dimension.
function vec.cross(a, b)
    local da = checkVec(a, "cross", "a")
    local db = checkVec(b, "cross", "b")
    if da ~= db then
        error("vec.cross: vectors must have same dimension", 2)
    end
    if da == 3 then
        return {
            x = a.y * b.z - a.z * b.y,
            y = a.z * b.x - a.x * b.z,
            z = a.x * b.y - a.y * b.x,
        }
    end
    return a.x * b.y - a.y * b.x
end

-- vec.lerp(a, b, t): покомпонентная интерполяция a + (b - a) * t (t не ограничивается).
-- Размерности должны совпадать. Возврат: новый вектор. Сторона: везде (pure).
-- Ошибки: vec.lerp: ... must be a vector/number; vectors must have same dimension.
function vec.lerp(a, b, t)
    local da = checkVec(a, "lerp", "a")
    local db = checkVec(b, "lerp", "b")
    if da ~= db then
        error("vec.lerp: vectors must have same dimension", 2)
    end
    t = checkScalar(t, "lerp", "t")
    if da == 3 then
        return {
            x = a.x + (b.x - a.x) * t,
            y = a.y + (b.y - a.y) * t,
            z = a.z + (b.z - a.z) * t,
        }
    end
    return {
        x = a.x + (b.x - a.x) * t,
        y = a.y + (b.y - a.y) * t,
    }
end

-- vec.rotate2(v, angle): поворот v2 на angle радиан против часовой.
-- Только v2 (v3 — ошибка). Возврат: новый вектор. Сторона: везде (pure).
-- Ошибки: vec.rotate2: v must be a vector; expected v2; angle must be a number.
function vec.rotate2(v, angle)
    local d = checkVec(v, "rotate2", "v")
    if d ~= 2 then
        error("vec.rotate2: expected v2", 2)
    end
    angle = checkScalar(angle, "rotate2", "angle")
    local c, s = math.cos(angle), math.sin(angle)
    return { x = v.x * c - v.y * s, y = v.x * s + v.y * c }
end

-- vec.fromAngle(angle): единичный v2 по углу (радианы): { x = cos, y = sin }.
-- Возврат: новый вектор. Сторона: везде (pure).
-- Ошибки: vec.fromAngle: angle must be a number.
function vec.fromAngle(angle)
    angle = checkScalar(angle, "fromAngle", "angle")
    return { x = math.cos(angle), y = math.sin(angle) }
end

-- vec.toAngle(v): угол v2 (радианы) через atan2(y, x). Только v2 (v3 — ошибка).
-- Возврат: число. Сторона: везде (pure).
-- Ошибки: vec.toAngle: v must be a vector; expected v2.
function vec.toAngle(v)
    local d = checkVec(v, "toAngle", "v")
    if d ~= 2 then
        error("vec.toAngle: expected v2", 2)
    end
    return math.atan(v.y, v.x)
end

-- vec.round(v, decimals): покомпонентное округление (half-up, decimals default 0).
-- Возврат: новый вектор. Сторона: везде (pure).
-- Ошибки: vec.round: v must be a vector; decimals must be a non-negative integer.
function vec.round(v, decimals)
    local d = checkVec(v, "round", "v")
    decimals = checkDecimals(decimals, "round")
    local m = 10 ^ decimals
    local function r(c)
        return math.floor(c * m + 0.5) / m
    end
    if d == 3 then
        return { x = r(v.x), y = r(v.y), z = r(v.z) }
    end
    return { x = r(v.x), y = r(v.y) }
end

-- vec.floor(v): покомпонентное округление вниз. Возврат: новый вектор.
-- Сторона: везде (pure). Ошибки: vec.floor: v must be a vector.
function vec.floor(v)
    local d = checkVec(v, "floor", "v")
    if d == 3 then
        return { x = math.floor(v.x), y = math.floor(v.y), z = math.floor(v.z) }
    end
    return { x = math.floor(v.x), y = math.floor(v.y) }
end

-- vec.toTable(v): plain-копия { x =, y = } / { x =, y =, z = } (то же, что clone).
-- Возврат: новая таблица. Сторона: везде (pure). Ошибки: vec.toTable: v must be a vector.
function vec.toTable(v)
    return vec.clone(v)
end
