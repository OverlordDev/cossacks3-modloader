-- effects — настоящие визуальные эффекты игры: дым, огонь, взрывы, пыль, подсветка.
--
-- Только картинка: урон НЕ наносят (урон — через abilities.fire, который уже дёргает
-- _misc_DoDamage). В сети — в shared (одинаково у всех) или чисто клиентский салют.
--
--   local id = effects.create(h, "PUEXP", "boom") -- эффект на объекте (класс из data/pfx)
--   effects.clear(h)                              -- снять все эффекты с объекта
--   effects.pfx(h, "manager", "key")              -- PFX-частицы на объекте
--   effects.setLifetime(h, "manager", "key", 5.0)
--   effects.setScale(h, "manager", "key", 2, 2, 2)
--   effects.burst(id, 1.0, 30)                    -- взрыв частиц из эффекта
--   effects.fire(id)                              -- поджечь эффект (дым->огонь)
--   effects.highlight(h, "target", true, "mat")   -- подсветка цели; effects.unhighlight(h, "target")
--
-- Классы эффектов — из data/pfx/*.pfx, менеджеры — оттуда же. Неверный класс игра
-- обычно игнорирует, но проверяйте на копии: часть PFX падает вне партии.
-- Вне партии — только effects.* с проверкой game.isInGame().

effects = {}

-- Хендл объекта/эффекта. Возвращает integer. Ошибки: не число.
local function checkHandle(h, what)
    h = math.tointeger(tonumber(h))
    if not h then error((what or "effects") .. ": handle must be a number", 3) end
    return h
end

-- Непустая строка (classname/manager/key). Возвращает строку. Ошибки: не строка или пустая.
local function checkStr(v, name, what)
    if type(v) ~= "string" or v == "" then
        error((what or "effects") .. ": " .. name .. " must be a non-empty string", 3)
    end
    return v
end

-- Число. Ошибки: не число, NaN или inf.
local function num(v, name)
    local n = tonumber(v)
    if not n or n ~= n or n == math.huge or n == -math.huge then
        error("effects: " .. name .. " must be a number", 3)
    end
    return n
end

-- Проверка партии. Ошибки: вне партии (проверяйте game.isInGame()).
local function inGame(where)
    if not game.isInGame() then
        error(where .. ": no active game (check game.isInGame())", 3)
    end
end

-- Создать эффект класса на объекте. Параметры: h — хендл объекта; classname — класс из data/pfx; key — ключ для поиска/снятия ("" — без ключа); useParser — парсить (bool). Возвращает id эффекта (для burst/ring/fire). Сторона: любая (только картинка; в сети — в shared). Ошибки: вне партии; h не число; classname пустой.
-- Создать эффект класса на объекте. key — чтобы потом найти/снять именно его.
-- Возвращает id эффекта (для burst/ring/fire).
function effects.create(h, classname, key, useParser)
    inGame("effects.create")
    h = checkHandle(h, "effects.create")
    checkStr(classname, "classname", "effects.create")
    if key == nil or key == "" then
        return native.EffectCreate(h, classname, true, useParser == true)
    end
    return native.EffectCreateWithKey(h, classname, key, useParser == true)
end

-- Снять все эффекты с объекта. Параметры: h — хендл объекта. Возвращает nil. Сторона: любая (в сети — в shared). Ошибки: вне партии; h не число.
function effects.clear(h)
    inGame("effects.clear")
    native.EffectClear(checkHandle(h, "effects.clear"))
end

-- ---------- PFX на объекте (дым/огонь/пыль из data/pfx) ----------

-- Создать PFX-частицы на объекте. Параметры: h — хендл; manager, key — из data/pfx. Возвращает nil. Сторона: любая (в сети — в shared). Ошибки: вне партии; h не число; manager/key пустые.
function effects.pfx(h, manager, key)
    inGame("effects.pfx")
    h = checkHandle(h, "effects.pfx")
    checkStr(manager, "manager", "effects.pfx")
    checkStr(key, "key", "effects.pfx")
    native.GameObjectPFXCreateByHandle(h, manager, key)
end

-- Удалить PFX-частицы с объекта. Параметры: h, manager, key. Возвращает nil. Сторона: любая (в сети — в shared). Ошибки: вне партии; h не число; manager/key пустые.
function effects.deletePfx(h, manager, key)
    inGame("effects.deletePfx")
    native.GameObjectPFXDeleteByHandle(checkHandle(h, "effects.deletePfx"),
        checkStr(manager, "manager", "effects.deletePfx"),
        checkStr(key, "key", "effects.deletePfx"))
end

-- Убрать все PFX с объекта. Параметры: h — хендл. Возвращает nil. Сторона: любая (в сети — в shared). Ошибки: вне партии; h не число.
function effects.clearPfx(h)
    inGame("effects.clearPfx")
    native.GameObjectPFXClearByHandle(checkHandle(h, "effects.clearPfx"))
end

-- Создан ли PFX на объекте. Параметры: h, manager, key. Возвращает boolean. Сторона: любая. Ошибки: вне партии; h не число; manager/key пустые.
function effects.isPfx(h, manager, key)
    inGame("effects.isPfx")
    return native.GameObjectPFXIsCreatedHandle(checkHandle(h, "effects.isPfx"),
        checkStr(manager, "manager", "effects.isPfx"),
        checkStr(key, "key", "effects.isPfx"))
end

-- Время жизни PFX. Параметры: h, manager, key; seconds — секунды. Возвращает nil. Сторона: любая (в сети — в shared). Ошибки: вне партии; h не число; manager/key пустые; seconds не число.
function effects.setLifetime(h, manager, key, seconds)
    inGame("effects.setLifetime")
    native.GameObjectPFXSetLifeTimeByHandle(checkHandle(h, "effects.setLifetime"),
        checkStr(manager, "manager", "effects.setLifetime"),
        checkStr(key, "key", "effects.setLifetime"), num(seconds, "seconds"))
end

-- Масштаб PFX. Параметры: h, manager, key; x, y, z или таблица {x,y,z} (y/z по умолчанию = x). Возвращает nil. Сторона: любая (в сети — в shared). Ошибки: вне партии; h не число; manager/key пустые; масштаб не число.
function effects.setScale(h, manager, key, x, y, z)
    inGame("effects.setScale")
    h = checkHandle(h, "effects.setScale")
    if type(x) == "table" then x, y, z = x[1], x[2], x[3] end
    native.GameObjectPFXScaleByHandle(h,
        checkStr(manager, "manager", "effects.setScale"),
        checkStr(key, "key", "effects.setScale"),
        num(x, "x"), num(y or x, "y"), num(z or x, "z"))
end

-- Масштаб эффекта PFX (effect scale). Параметры: h, manager, key; scale — множитель. Возвращает nil. Сторона: любая (в сети — в shared). Ошибки: вне партии; h не число; manager/key пустые; scale не число.
function effects.setEffectScale(h, manager, key, scale)
    inGame("effects.setEffectScale")
    native.GameObjectPFXEffectScaleByHandle(checkHandle(h, "effects.setEffectScale"),
        checkStr(manager, "manager", "effects.setEffectScale"),
        checkStr(key, "key", "effects.setEffectScale"), num(scale, "scale"))
end

-- Начальная скорость частиц. Параметры: h, manager, key; vx, vy, vz. Возвращает nil. Сторона: любая (в сети — в shared). Ошибки: вне партии; h не число; manager/key пустые; скорости не числа.
function effects.setVelocity(h, manager, key, vx, vy, vz)
    inGame("effects.setVelocity")
    native.GameObjectPFXInitialVelocityByHandle(checkHandle(h, "effects.setVelocity"),
        checkStr(manager, "manager", "effects.setVelocity"),
        checkStr(key, "key", "effects.setVelocity"),
        num(vx, "vx"), num(vy, "vy"), num(vz, "vz"))
end

-- Включить/выключить PFX. Параметры: h, manager, key; enabled (по умолчанию true). Возвращает nil. Сторона: любая (в сети — в shared). Ошибки: вне партии; h не число; manager/key пустые.
function effects.setEnabled(h, manager, key, enabled)
    inGame("effects.setEnabled")
    if enabled == nil then enabled = true end
    native.GameObjectPFXEnabledByHandle(checkHandle(h, "effects.setEnabled"),
        checkStr(manager, "manager", "effects.setEnabled"),
        checkStr(key, "key", "effects.setEnabled"), enabled and true or false)
end

-- ---------- взрывы из эффекта (id из effects.create) ----------

-- Взрыв частиц из эффекта. Параметры: id — id эффекта; time — время; count — целое число частиц. Возвращает nil. Сторона: любая (в сети — в shared). Ошибки: вне партии; id не число; time не число; count не целое.
function effects.burst(id, time, count)
    inGame("effects.burst")
    native.EffectSourcePFXBurst(checkHandle(id, "effects.burst"),
        num(time, "time"), math.tointeger(tonumber(count))
        or error("effects.burst: count must be an integer", 2))
end

-- Кольцевой взрыв из эффекта. Параметры: id — id эффекта; time; minSpeed, maxSpeed — скорости; count — целое. Возвращает nil. Сторона: любая (в сети — в shared). Ошибки: вне партии; id не число; скорости/время не числа; count не целое.
function effects.ring(id, time, minSpeed, maxSpeed, count)
    inGame("effects.ring")
    native.EffectSourcePFXRingExplosion(checkHandle(id, "effects.ring"),
        num(time, "time"), num(minSpeed, "minSpeed"), num(maxSpeed, "maxSpeed"),
        math.tointeger(tonumber(count)) or error("effects.ring: count must be an integer", 2))
end

-- Поджечь эффект (дым->огонь) с изотропным взрывом. Параметры: id — id эффекта; minSpeed, maxSpeed; lifeBoost (по умолчанию 1); count — целое. Возвращает nil. Сторона: любая (в сети — в shared). Ошибки: вне партии; id не число; скорости не числа; count не целое.
function effects.fire(id, minSpeed, maxSpeed, lifeBoost, count)
    inGame("effects.fire")
    id = checkHandle(id, "effects.fire")
    native.EffectFireFXInit(id)
    native.EffectFireFXIsotropicExplosion(id, num(minSpeed, "minSpeed"),
        num(maxSpeed, "maxSpeed"), num(lifeBoost or 1, "lifeBoost"),
        math.tointeger(tonumber(count)) or error("effects.fire: count must be an integer", 2))
end

-- ---------- подсветка ----------

-- Подсветить объект. Параметры: h — хендл; key — ключ подсветки; visible (по умолчанию true); mat — материал ("" — по умолчанию). Возвращает хендл подсветки. Сторона: любая (в сети — в shared). Ошибки: вне партии; h не число; key пустой.
-- Подсветить объект (цель, выбор, зона). mat — материал подсветки ("" — по умолчанию).
function effects.highlight(h, key, visible, mat)
    inGame("effects.highlight")
    h = checkHandle(h, "effects.highlight")
    checkStr(key, "key", "effects.highlight")
    if visible == nil then visible = true end
    return native.EffectHighlightGetOrCreate(h, key, visible and true or false, mat or "")
end

-- Снять подсветку. Параметры: h — хендл; key — ключ. Возвращает nil. Сторона: любая (в сети — в shared). Ошибки: вне партии; h не число; key пустой.
function effects.unhighlight(h, key)
    inGame("effects.unhighlight")
    native.EffectHighlightRemove(checkHandle(h, "effects.unhighlight"),
        checkStr(key, "key", "effects.unhighlight"))
end
