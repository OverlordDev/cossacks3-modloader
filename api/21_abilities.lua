-- abilities — детерминированные игровые способности для server/shared-модов.
--
-- Это первый низкоуровневый примитив для авиаударов, баллистики и миномётов:
--
--   abilities.define("airstrike", {
--       cooldown = 30,
--       damage = 800,
--       radius = 12,
--       target = "all",       -- "all", "units" или "buildings"
--       effect = "cannon",   -- "cannon", "howitzer", "grenade" или "none"
--       ignorePeace = false,  -- разрешить урон во время мирного периода
--   })
--   local hit = abilities.fire("airstrike", 120, -48)
--
-- fire() выполняет area damage через штатный _misc_DoDamage, поэтому проходят
-- обычные unit.damage/death и логика игры. Вызов меняет мир и доступен только
-- server/shared-коду. Клиент должен передать запрос через net.send, а сервер
-- проверить его и вызвать abilities.fire() в своём обработчике.

abilities = {}

local defs = {}
local readyAt = {}
local EFFECT_WEAPONS = {
    none = "",
    cannon = "PUEXP",
    howitzer = "PUEXPHOWITZER",
    grenade = "PU4GRE",
}

-- Число (cooldown/damage/radius/координаты). Возвращает number/integer. Ошибки: не число, NaN, inf или не целое (для integer).
local function number(value, name, integer)
    local n = tonumber(value)
    if not n or n ~= n or n == math.huge or n == -math.huge then
        error("abilities: " .. name .. " must be a number", 3)
    end
    if integer then n = math.tointeger(n) or error("abilities: " .. name .. " must be an integer", 3) end
    return n
end

-- Проверка id способности ([A-Za-z_][...]). Возвращает строку. Ошибки: неверный формат.
local function id(value)
    value = tostring(value or "")
    if not value:match("^[%a_][%w_%.%-]*$") then
        error("abilities: invalid ability id", 3)
    end
    return value
end

-- Поверхностная копия таблицы определения. Возвращает копию.
local function copy(def)
    local out = {}
    for k, v in pairs(def) do out[k] = v end
    return out
end

-- Текущее игровое время (для cooldown). Возвращает число.
local function now()
    return tonumber(native.GetGameTime()) or 0
end

-- Проверка записи: только server/shared (нужен game.exec) и только в партии. Ошибки: на client; вне партии.
local function needServer(name)
    if not game.exec then
        error("abilities." .. name .. ": only server/shared scripts can change the game", 3)
    end
    if not game.isInGame() then
        error("abilities." .. name .. ": no active game", 3)
    end
end

-- Объявить способность. Параметры: name — id; spec = { cooldown=, damage=, radius=, target="all"|"units"|"buildings", effect="cannon"|"howitzer"|"grenade"|"none", ignorePeace=, weaponKind= }. Возвращает копию определения. Сторона: любая (только данные, мир не меняет). Ошибки: неверный id; spec не таблица; target/effect неверные; числа не числа.
function abilities.define(name, spec)
    name = id(name)
    if type(spec) ~= "table" then error("abilities.define: spec must be a table", 2) end
    local target = spec.target or "all"
    if target ~= "all" and target ~= "units" and target ~= "buildings" then
        error("abilities.define: target must be all, units or buildings", 2)
    end
    local effect = tostring(spec.effect or "cannon"):lower()
    if EFFECT_WEAPONS[effect] == nil then
        error("abilities.define: effect must be cannon, howitzer, grenade or none", 2)
    end
    local def = {
        id = name,
        cooldown = math.max(0, number(spec.cooldown or 0, "cooldown")),
        damage = math.max(0, number(spec.damage or 0, "damage", true)),
        radius = math.max(0, number(spec.radius or 0, "radius")),
        target = target,
        effect = effect,
        ignorePeace = spec.ignorePeace == true,
        weaponKind = math.tointeger(tonumber(spec.weaponKind or 0)) or 0,
    }
    defs[name] = def
    return copy(def)
end

-- Определение способности. Параметры: name — id. Возвращает копию определения или nil (нет такой). Сторона: любая. Ошибки: неверный id.
function abilities.get(name)
    local def = defs[id(name)]
    return def and copy(def) or nil
end

-- Все определения. Возвращает { [id]=def, ... } (копии). Сторона: любая. Ошибки: нет.
function abilities.list()
    local out = {}
    for name, def in pairs(defs) do out[name] = copy(def) end
    return out
end

-- Готовность (прошёл ли cooldown). Параметры: name — id; owner — владелец cooldown (по умолчанию 0). Возвращает boolean. Сторона: любая. Ошибки: неверный id.
function abilities.ready(name, owner)
    name = id(name)
    local key = name .. ":" .. tostring(owner or 0)
    return now() >= (readyAt[key] or -math.huge)
end

-- Нанести урон по объектам в круге. Параметры: name — id; x, z — мировые координаты; opts = { owner=, damage=, radius=, target=, effect=, ignorePeace=, weaponKind=, source= (хендл атакующего, 0 — без источника) }. Возвращает true, hitCount (число объектов в области, не смертей) или false, "cooldown", seconds. Сторона: только server/shared (меняет мир через _misc_DoDamage). Ошибки: на client (нет game.exec); вне партии; неизвестная способность; x/z не числа; opts не таблица; target/effect неверные.
-- Нанести урон по объектам в круге. Координаты — мировые X/Z.
-- opts.source — существующий handle атакующего. Если его нет, используется 0:
-- штатный _misc_DoDamage сам поддерживает урон без источника.
function abilities.fire(name, x, z, opts)
    needServer("fire")
    name = id(name)
    local def = defs[name]
    if not def then error("abilities.fire: unknown ability '" .. name .. "'", 2) end
    opts = opts or {}
    if type(opts) ~= "table" then error("abilities.fire: opts must be a table", 2) end

    x = number(x, "x")
    z = number(z, "z")
    local owner = tostring(opts.owner or 0)
    local key = name .. ":" .. owner
    local t = now()
    if t < (readyAt[key] or -math.huge) then
        return false, "cooldown", math.max(0, (readyAt[key] or t) - t)
    end

    local damage = math.max(0, math.tointeger(tonumber(opts.damage or def.damage)) or def.damage)
    local radius = math.max(0, tonumber(opts.radius or def.radius) or def.radius)
    local target = opts.target or def.target
    if target ~= "all" and target ~= "units" and target ~= "buildings" then
        error("abilities.fire: target must be all, units or buildings", 2)
    end
    local source = math.tointeger(tonumber(opts.source or 0)) or 0
    local weaponKind = math.tointeger(tonumber(opts.weaponKind or def.weaponKind)) or 0
    local effect = tostring(opts.effect or def.effect or "cannon"):lower()
    local effectSid = EFFECT_WEAPONS[effect]
    if effectSid == nil then
        error("abilities.fire: effect must be cannon, howitzer, grenade or none", 2)
    end
    local ignorePeace = opts.ignorePeace == true or (opts.ignorePeace == nil and def.ignorePeace)

    local code = string.format([[
var ax, az, radius2, dx, dz, ay : Float;
var source, h, i, j, count, effectid : Integer;
var oldPeace : Boolean;
var plHnd : Integer;
var pobj : Pointer;
var cid, oid : Integer;
ax := %.9f;
az := %.9f;
radius2 := %.9f * %.9f;
source := %d;
count := 0;
for i := 0 to gc_MaxPlayerCount-1 do
begin
   plHnd := GetPlayerHandleByIndex(i);
   if plHnd <> 0 then
   for j := 0 to GetPlayerGameObjectsCountByHandle(plHnd)-1 do
   begin
      h := GetGameObjectHandleByIndex(j, plHnd);
      pobj := _unit_GetTObj(h);
      if pobj <> nil then
      begin
         cid := TObj(pobj).cid;
         oid := TObj(pobj).id;
         dx := GetGameObjectPositionXByHandle(h) - ax;
         dz := GetGameObjectPositionZByHandle(h) - az;
         if (not TObj(pobj).bdead) and ((dx * dx + dz * dz) <= radius2) and
            (%s or ((%s) and (not gObjProp[cid][oid].bbuilding)) or
             ((%s) and gObjProp[cid][oid].bbuilding)) then
         begin
             if %s then
             begin
                oldPeace := gbool_peacemode;
                gbool_peacemode := False;
                _misc_DoDamage(source, h, %d, -1, %d);
                gbool_peacemode := oldPeace;
             end
             else
             _misc_DoDamage(source, h, %d, -1, %d);
            count := count + 1;
         end;
      end;
   end;
end;
if '%s' <> '' then
begin
   ay := RayCastHeight(ax, az);
   var effectname : String = '%s';
   effectid := _weapon_GetWeaponIdBySID(effectname);
   if effectid >= 0 then
   _weapon_CreateProjectileByWeaponID(0, 0, False, ax, ay, az, effectid, ax, ay, az, 0, 0, 0, 0.5);
end;
ML_RET(IntToStr(count));]],
        x, z, radius, radius, source,
        target == "all" and "True" or "False",
        target == "units" and "True" or "False",
        target == "buildings" and "True" or "False",
         ignorePeace and "True" or "False", damage, weaponKind, damage, weaponKind, effectSid, effectSid)

    local result = game.exec(code) or "0"
    local hit = math.tointeger(tonumber(result)) or 0
    readyAt[key] = t + def.cooldown
    return true, hit
end
