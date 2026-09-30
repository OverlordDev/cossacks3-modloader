-- geometry — чистая 2D-геометрия поверх XZ (без вызовов игры, везде).
--
-- Точки: { x =, z = } или { x =, y =, z = } (y игнорируется в 2D).
-- Массивы { x, z } тоже принимаются (x = p[1], z = p[2]).
-- УГЛЫ ВЕЗДЕ РАДИАНЫ (0 — +x, рост против часовой в плоскости XZ).
-- Границы включительно: inCircle/inRect/inSector считают касание попаданием;
-- polygonContains считает границу и вершину попаданием (внутри = true).
-- Входы не мутируются: все функции возвращают новые таблицы.
--
--   local d = geometry.distance({ x = 0, z = 0 }, { x = 3, z = 4 }) --> 5
--   geometry.inCircle({ x = 3, z = 4 }, { x = 0, z = 0 }, 5)        --> true (граница)
--   geometry.polygonContains({ x = 5, z = 5 }, square)              --> true/false

geometry = {}

local EPS = 1e-9
local DENOM_EPS = 1e-12

-- Достать x/z из точки (поддерживает {x,z}, {x,y,z}, {x,z} массивом).
local function getXZ(p, fname, pname)
    if type(p) ~= "table" then
        error("geometry." .. fname .. ": " .. pname .. " must be a point {x=,z=}", 3)
    end
    local x = p.x
    if x == nil then x = p[1] end
    local z = p.z
    if z == nil then z = p[2] end
    x = tonumber(x)
    z = tonumber(z)
    if not x or x ~= x then
        error("geometry." .. fname .. ": " .. pname .. ".x must be a number", 3)
    end
    if not z or z ~= z then
        error("geometry." .. fname .. ": " .. pname .. ".z must be a number", 3)
    end
    return x, z
end

-- Проверить число (радиус/угол/счётчик идут через неё с понятным префиксом).
local function checkNum(v, fname, pname)
    local n = tonumber(v)
    if not n or n ~= n then
        error("geometry." .. fname .. ": " .. pname .. " must be a number", 3)
    end
    return n
end

-- Нормализовать разность углов в [-pi, pi].
local function normAngle(a)
    while a > math.pi do a = a - 2 * math.pi end
    while a < -math.pi do a = a + 2 * math.pi end
    return a
end

-- Квадрат расстояния (без корня, для внутренних проверок).
local function dist2(x1, z1, x2, z2)
    local dx, dz = x1 - x2, z1 - z2
    return dx * dx + dz * dz
end

-- Точка на отрезке (включая концы) с допуском EPS.
local function onSegment(px, pz, ax, az, bx, bz)
    local cross = (px - ax) * (bz - az) - (pz - az) * (bx - ax)
    local len2 = dist2(ax, az, bx, bz)
    if len2 <= EPS * EPS then
        return dist2(px, pz, ax, az) <= EPS * EPS
    end
    if math.abs(cross) > 1e-9 * math.sqrt(len2) + 1e-12 then return false end
    local dot = (px - ax) * (bx - ax) + (pz - az) * (bz - az)
    return dot >= -EPS and dot <= len2 + EPS
end

-- Расстояние между точками a и b. Возвращает число >= 0. Входы не меняются.
function geometry.distance(a, b)
    local ax, az = getXZ(a, "distance", "a")
    local bx, bz = getXZ(b, "distance", "b")
    return math.sqrt(dist2(ax, az, bx, bz))
end

-- Квадрат расстояния между a и b (без корня). Возвращает число >= 0.
function geometry.distanceSquared(a, b)
    local ax, az = getXZ(a, "distanceSquared", "a")
    local bx, bz = getXZ(b, "distanceSquared", "b")
    return dist2(ax, az, bx, bz)
end

-- Точка внутри круга (граница включительно). radius >= 0. Возвращает true/false.
function geometry.inCircle(point, center, radius)
    local px, pz = getXZ(point, "inCircle", "point")
    local cx, cz = getXZ(center, "inCircle", "center")
    radius = checkNum(radius, "inCircle", "radius")
    if radius < 0 then error("geometry.inCircle: radius must be >= 0", 2) end
    return dist2(px, pz, cx, cz) <= radius * radius + EPS
end

-- Точка внутри прямоугольника rect = { x1, z1, x2, z2 } (границы включительно).
-- Неупорядоченные x1>x2 / z1>z2 нормализуются (min/max). Возвращает true/false.
function geometry.inRect(point, rect)
    local px, pz = getXZ(point, "inRect", "point")
    if type(rect) ~= "table" then
        error("geometry.inRect: rect must be {x1=,z1=,x2=,z2=}", 2)
    end
    local x1 = checkNum(rect.x1, "inRect", "rect.x1")
    local z1 = checkNum(rect.z1, "inRect", "rect.z1")
    local x2 = checkNum(rect.x2, "inRect", "rect.x2")
    local z2 = checkNum(rect.z2, "inRect", "rect.z2")
    local xa, xb = math.min(x1, x2), math.max(x1, x2)
    local za, zb = math.min(z1, z2), math.max(z1, z2)
    return px + EPS >= xa and px - EPS <= xb and pz + EPS >= za and pz - EPS <= zb
end

-- Точка в секторе: origin — вершина, direction — ось (радианы),
-- halfAngle — полуугол >= 0 (радианы), radius — дальность >= 0.
-- Границы (угол и дуга) включительно; сам origin всегда внутри.
-- halfAngle >= pi вырождается в круг. Возвращает true/false.
function geometry.inSector(point, origin, direction, halfAngle, radius)
    local px, pz = getXZ(point, "inSector", "point")
    local ox, oz = getXZ(origin, "inSector", "origin")
    direction = checkNum(direction, "inSector", "direction")
    halfAngle = checkNum(halfAngle, "inSector", "halfAngle")
    radius = checkNum(radius, "inSector", "radius")
    if halfAngle < 0 then error("geometry.inSector: halfAngle must be >= 0", 2) end
    if radius < 0 then error("geometry.inSector: radius must be >= 0", 2) end
    local d2 = dist2(px, pz, ox, oz)
    if d2 > radius * radius + EPS then return false end
    if d2 <= EPS * EPS then return true end
    if halfAngle >= math.pi then return true end
    local ang = math.atan(pz - oz, px - ox)
    return math.abs(normAngle(ang - direction)) <= halfAngle + 1e-9
end

-- Ближайшая к p точка отрезка a-b. Вырожденный a==b возвращает копию a.
-- Возвращает новую { x=, z= }, входы не меняются.
function geometry.closestPointOnSegment(p, a, b)
    local px, pz = getXZ(p, "closestPointOnSegment", "p")
    local ax, az = getXZ(a, "closestPointOnSegment", "a")
    local bx, bz = getXZ(b, "closestPointOnSegment", "b")
    local abx, abz = bx - ax, bz - az
    local len2 = abx * abx + abz * abz
    if len2 <= EPS * EPS then
        return { x = ax, z = az }
    end
    local t = ((px - ax) * abx + (pz - az) * abz) / len2
    if t < 0 then t = 0 elseif t > 1 then t = 1 end
    return { x = ax + abx * t, z = az + abz * t }
end

-- Расстояние от p до отрезка a-b (>= 0). Вырожденный отрезок — дистанция до a.
function geometry.distanceToSegment(p, a, b)
    local px, pz = getXZ(p, "distanceToSegment", "p")
    local c = geometry.closestPointOnSegment(p, a, b)
    local dx, dz = px - c.x, pz - c.z
    return math.sqrt(dx * dx + dz * dz)
end

-- Пересечение бесконечных прямых a1-a2 и b1-b2. Возвращает { x=, z= } или nil (параллельные).
-- Вырожденные прямые (a1==a2 или b1==b2) дают ошибку. Входы не меняются.
function geometry.lineIntersection(a1, a2, b1, b2)
    local x1, z1 = getXZ(a1, "lineIntersection", "a1")
    local x2, z2 = getXZ(a2, "lineIntersection", "a2")
    local x3, z3 = getXZ(b1, "lineIntersection", "b1")
    local x4, z4 = getXZ(b2, "lineIntersection", "b2")
    if dist2(x1, z1, x2, z2) <= EPS * EPS then
        error("geometry.lineIntersection: a1==a2 (degenerate line)", 2)
    end
    if dist2(x3, z3, x4, z4) <= EPS * EPS then
        error("geometry.lineIntersection: b1==b2 (degenerate line)", 2)
    end
    local denom = (x1 - x2) * (z3 - z4) - (z1 - z2) * (x3 - x4)
    if math.abs(denom) < DENOM_EPS then return nil end
    local s1 = x1 * z2 - z1 * x2
    local s2 = x3 * z4 - z3 * x4
    return {
        x = (s1 * (x3 - x4) - (x1 - x2) * s2) / denom,
        z = (s1 * (z3 - z4) - (z1 - z2) * s2) / denom,
    }
end

-- Точка в полигоне (луч вправо). Граница и вершина считаются внутри (true).
-- Вырожденный полигон (< 3 точек) всегда false, без ошибки. Входы не меняются.
function geometry.polygonContains(point, polygon)
    local px, pz = getXZ(point, "polygonContains", "point")
    if type(polygon) ~= "table" then
        error("geometry.polygonContains: polygon must be an array of points", 2)
    end
    local n = #polygon
    if n < 3 then return false end
    local xs, zs = {}, {}
    for i = 1, n do
        local x, z = getXZ(polygon[i], "polygonContains", "polygon[" .. i .. "]")
        xs[i], zs[i] = x, z
    end
    for i = 1, n do
        local j = i % n + 1
        if onSegment(px, pz, xs[i], zs[i], xs[j], zs[j]) then return true end
    end
    local inside = false
    for i = 1, n do
        local j = i % n + 1
        if (zs[i] > pz) ~= (zs[j] > pz) then
            local cross = (xs[j] - xs[i]) * (pz - zs[i]) / (zs[j] - zs[i]) + xs[i]
            if px < cross then inside = not inside end
        end
    end
    return inside
end

-- Центр полигона как среднее арифметическое вершин. Пустой полигон — ошибка.
-- Возвращает новую { x=, z= }, вход не меняется.
function geometry.polygonCenter(polygon)
    if type(polygon) ~= "table" then
        error("geometry.polygonCenter: polygon must be an array of points", 2)
    end
    local n = #polygon
    if n < 1 then error("geometry.polygonCenter: polygon is empty", 2) end
    local sx, sz = 0, 0
    for i = 1, n do
        local x, z = getXZ(polygon[i], "polygonCenter", "polygon[" .. i .. "]")
        sx, sz = sx + x, sz + z
    end
    return { x = sx / n, z = sz / n }
end

-- Границы полигона. Пустой полигон — ошибка. Возвращает { x1=, z1=, x2=, z2= }.
function geometry.polygonBounds(polygon)
    if type(polygon) ~= "table" then
        error("geometry.polygonBounds: polygon must be an array of points", 2)
    end
    local n = #polygon
    if n < 1 then error("geometry.polygonBounds: polygon is empty", 2) end
    local x1, z1 = getXZ(polygon[1], "polygonBounds", "polygon[1]")
    local x2, z2 = x1, z1
    for i = 2, n do
        local x, z = getXZ(polygon[i], "polygonBounds", "polygon[" .. i .. "]")
        if x < x1 then x1 = x end
        if z < z1 then z1 = z end
        if x > x2 then x2 = x end
        if z > z2 then z2 = z end
    end
    return { x1 = x1, z1 = z1, x2 = x2, z2 = z2 }
end

-- Точки по окружности: count (>= 1, integer) точек от startAngle (радианы, по умолч. 0).
-- radius >= 0. Возвращает массив { { x=, z= }, ... }, входы не меняются.
function geometry.circlePoints(center, radius, count, startAngle)
    local cx, cz = getXZ(center, "circlePoints", "center")
    radius = checkNum(radius, "circlePoints", "radius")
    if radius < 0 then error("geometry.circlePoints: radius must be >= 0", 2) end
    local c = math.tointeger(count)
    if not c or c < 1 then
        error("geometry.circlePoints: count must be an integer >= 1", 2)
    end
    if startAngle == nil then startAngle = 0 end
    startAngle = checkNum(startAngle, "circlePoints", "startAngle")
    local out = {}
    for i = 0, c - 1 do
        local a = startAngle + i * 2 * math.pi / c
        out[#out + 1] = { x = cx + radius * math.cos(a), z = cz + radius * math.sin(a) }
    end
    return out
end

-- Поворот точки вокруг центра на angle радиан (против часовой в XZ).
-- Возвращает новую { x=, z= }, входы не меняются.
function geometry.rotatePoint(point, center, angle)
    local px, pz = getXZ(point, "rotatePoint", "point")
    local cx, cz = getXZ(center, "rotatePoint", "center")
    angle = checkNum(angle, "rotatePoint", "angle")
    local co, si = math.cos(angle), math.sin(angle)
    local dx, dz = px - cx, pz - cz
    return { x = cx + dx * co - dz * si, z = cz + dx * si + dz * co }
end

-- Направление от from к to: math.atan(dz, dx) (радианы). Совпавшие точки дают 0.
function geometry.lookAngle(from, to)
    local fx, fz = getXZ(from, "lookAngle", "from")
    local tx, tz = getXZ(to, "lookAngle", "to")
    return math.atan(tz - fz, tx - fx)
end
