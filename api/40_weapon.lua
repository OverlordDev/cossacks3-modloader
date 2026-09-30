-- weapon — баллистика: настоящие летящие снаряды + урон по площади.
--
-- МЕНЯЕТ МИР: только server/shared. Снаряд летит средствами игры
-- (_weapon_CreateProjectileByWeaponID), урон — через abilities.fire, поэтому
-- проходят события unit.damage/death. Детерминировано: разброс и seed считаются
-- от координат (золотое сечение), math.random НЕ используется — иначе рассинхрон.
--
--   weapon.fire{ target = { x = 100, z = 50 }, damage = 500, radius = 8 }
--   weapon.fire{ from = h, target = { x = 100, z = 50 }, weapon = "PUEXPHOWITZER",
--               speed = 80, damage = 800, radius = 12, shots = 3, interval = 0.5,
--               spread = 4, sub = { count = 5, radius = 3, damage = 100 } }
--
-- Поля: from (хендл стрелка, nil — без стрелка), target {x, z} (обязательно),
-- weapon (SID оружия, по умолчанию "PUEXP"), speed (м/с для задержки подлёта),
-- damage/radius/target/effect/ignorePeace/weaponKind — как в abilities.fire,
-- shots/interval (залп), spread (разброс), sub (кассета: count/radius/damage),
-- height (высота старта над стрелком/землёй, по умолчанию 2).

weapon = {}

local timers = {}
local sub = nil

local function needServer(where)
    if not game.exec then
        error("weapon." .. where .. ": only server/shared scripts can fire", 3)
    end
    if not game.isInGame() then
        error("weapon." .. where .. ": no active game (check game.isInGame())", 3)
    end
end

local function num(v, name)
    local n = tonumber(v)
    if not n or n ~= n then error("weapon: " .. name .. " must be a number", 3) end
    return n
end

local function ensureTick()
    if sub then return end
    sub = events.on("game.tick", function()
        local now = os.clock()
        for i = #timers, 1, -1 do
            if now >= timers[i].at then
                local fn = timers[i].fn
                table.remove(timers, i)
                fn()
            end
        end
        if #timers == 0 and sub then events.off(sub) sub = nil end
    end)
end

local function after(delay, fn)
    table.insert(timers, { at = os.clock() + (delay or 0), fn = fn })
    ensureTick()
end

-- Детерминированное «случайное» смещение k-й точки (спираль золотого сечения).
local function spreadXY(x, z, spread, k, n)
    if not spread or spread <= 0 or n <= 1 then return x, z end
    local r = spread * math.sqrt((k - 0.5) / n)
    local a = (k - 1) * 2.399963 + (x * 0.37 + z * 0.73)
    return x + math.cos(a) * r, z + math.sin(a) * r
end

-- Выпустить снаряд из точки в точку средствами игры (визуал полёта).
local function launch(sx, sy, sz, tx, ty, tz, weaponSid, seed)
    local code = string.format([[
var sx, sy, sz, tx, ty, tz : Float;
var wid : Integer;
sx := %.3f; sy := %.3f; sz := %.3f;
tx := %.3f; ty := %.3f; tz := %.3f;
wid := _weapon_GetWeaponIdBySID('%s');
if wid >= 0 then
_weapon_CreateProjectileByWeaponID(0, 0, False, sx, sy, sz, wid, tx, ty, tz, 0, 0, 0, %.4f);]],
        sx, sy, sz, tx, ty, tz, weaponSid, seed)
    game.exec(code)
end

local function strike(spec, x, z, k, n)
    local sx, sy, sz = x, 0, z
    if spec.from then
        sx, sz = objects.pos(spec.from)
        sx, sz = sx or x, sz or z
    end
    sy = (native.RayCastHeight(sx, sz) or 0) + (spec.height or 2)
    local ty = native.RayCastHeight(x, z) or 0
    -- seed из координат: одинаковый у всех машин
    local seed = ((math.abs(x * 13.7 + z * 7.3 + k * 3.1) % 1))
    launch(sx, sy, sz, x, ty, z, spec.weapon, seed)
    local flight = 0
    if spec.speed and spec.speed > 0 then
        local dx, dz = x - sx, z - sz
        flight = math.sqrt(dx * dx + dz * dz) / spec.speed
    end
    after(flight, function()
        if not game.isInGame() then return end
        abilities.fire(spec.ability, x, z, {
            damage = spec.damage, radius = spec.radius, target = spec.targetType,
            effect = "none", -- взрыв уже летит снарядом; урон без дубля визуала
            ignorePeace = spec.ignorePeace, weaponKind = spec.weaponKind,
            owner = spec.owner, source = spec.from or 0,
        })
        if spec.sub and spec.sub.count and spec.sub.count > 0 then
            for i = 1, spec.sub.count do
                local cx, cz = spreadXY(x, z, spec.sub.radius or spec.radius, i, spec.sub.count)
                abilities.fire(spec.ability, cx, cz, {
                    damage = spec.sub.damage or spec.damage, radius = spec.sub.radius or 3,
                    target = spec.targetType, effect = "none", ignorePeace = spec.ignorePeace,
                    owner = spec.owner, source = spec.from or 0,
                })
            end
        end
    end)
end

-- Огонь! ability — зарегистрированная в abilities.define способность-носитель
-- (несёт cooldown; урон/радиус берутся из spec).
-- Поля: target = {x, z} (обязательно), targetType = "all"/"units"/"buildings",
-- from, weapon (SID), speed, height, damage, radius, shots, interval, spread,
-- sub = { count=, radius=, damage= }, ignorePeace, weaponKind, owner.
function weapon.fire(input)
    needServer("fire")
    if type(input) ~= "table" then error("weapon.fire: pass { target = {x, z}, ... }", 2) end
    if type(input.target) ~= "table" then error("weapon.fire: target = { x=, z= } required", 2) end
    if not input.ability or not abilities.get(input.ability) then
        error("weapon.fire: ability must be a defined abilities id (carries cooldown)", 2)
    end
    local spec = {
        ability = input.ability, from = input.from,
        weapon = tostring(input.weapon or "PUEXP"),
        speed = input.speed and num(input.speed, "speed") or nil,
        height = input.height and num(input.height, "height") or 2,
        damage = input.damage, radius = input.radius,
        targetType = input.targetType or "all",
        ignorePeace = input.ignorePeace, weaponKind = input.weaponKind, owner = input.owner,
        shots = math.tointeger(tonumber(input.shots or 1)) or 1,
        interval = num(input.interval or 0, "interval"),
        spread = input.spread and num(input.spread, "spread") or 0,
        sub = input.sub,
    }
    if spec.targetType ~= "all" and spec.targetType ~= "units" and spec.targetType ~= "buildings" then
        error("weapon.fire: targetType must be all, units or buildings", 2)
    end
    local px, pz = num(input.target.x, "target.x"), num(input.target.z, "target.z")
    for k = 1, spec.shots do
        local x, z = spreadXY(px, pz, spec.spread, k, spec.shots)
        if k == 1 then strike(spec, x, z, k, spec.shots)
        else after((k - 1) * spec.interval, function() strike(spec, x, z, k, spec.shots) end) end
    end
end
