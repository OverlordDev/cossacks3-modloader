-- config — конфигурация мода поверх savedata (живёт внутри сейвов игры!).
--
--   config.link(savedata)                      -- один раз в записи мода (server/shared/client)
--   local cfg = config.load("my_mod", { _version = 2, volume = 0.8 })
--   local v = cfg:get("volume", 0.8)
--   cfg:set("volume", 0.5)                     -- только флаг dirty, записи в savedata НЕТ
--   cfg:save()                                 -- пишет ОДНИМ ключом "cfg:<name>" всю таблицу
--   cfg:reset("volume")                        -- вернуть дефолт ключа; cfg:reset() — всё
--
-- ОДИН ключ "cfg:<name>" под всю таблицу (меньше записей в savedata, один get/set).
-- dirty-флаг: save() пишет только если были set/reset/migrate (иначе no-op, возвращает false).
-- Версия схемы: defaults._version vs stored._version; несовпадение — opts.migrate(old)→new
-- или сброс к defaults (migrate нет). Повреждённые данные (stored не таблица или
-- с превышением лимитов) — молча defaults (не кидает; перезапишется при set/save).
-- Лимиты: глубина ≤ 5, всего ключей ≤ 1000 (включая вложенные) — превышение в set/save — ошибка.
-- Автосейв: при базовом событии "game.end" все dirty-конфиги дописываются (подписка один раз).
-- РАЗДЕЛЕНИЕ client/shared — только соглашением: client-настройки (камера, HUD) храните
-- под ДРУГИМ именем (например "my_mod_client"), shared/server — под своим. Client-конфиг
-- НЕ источник игровой логики (иначе десинк в сети): баланс/правила — только shared/server.
-- Сторона: везде после link (чтение/запись savedata локальны для стороны).

config = {}

local store = nil     -- savedata мода: config.link(savedata)
local registry = {}   -- все загруженные конфиги (для автосейва)
local subscribed = false

-- Привязать хранилище мода (один раз в записи мода):
--   config.link(savedata)
-- Ошибки: config.link: pass mod savedata (нужен table с get/set).
function config.link(s)
    if type(s) ~= "table" or type(s.get) ~= "function" or type(s.set) ~= "function" then
        error("config.link: pass mod savedata", 2)
    end
    store = s
end

-- Требует link (внутреннее). Возвращает store. Ошибки: config.<where>: call config.link(savedata) ...
local function needStore(where)
    if not store then
        error("config." .. where .. ": call config.link(savedata) in your entry first", 3)
    end
    return store
end

-- Глубокая копия без циклов (циклы — ошибка). Возвращает копию.
local function deepCopy(t, seen)
    if type(t) ~= "table" then return t end
    seen = seen or {}
    if seen[t] then error("config: cycle detected (config tables must be trees)", 3) end
    seen[t] = true
    local c = {}
    for k, v in pairs(t) do
        c[deepCopy(k, seen)] = deepCopy(v, seen)
    end
    seen[t] = nil
    return c
end

-- Глубина таблицы: не-таблица 0; {} 1; { a = { b = 1 } } 2. Лимит 5.
local function depthOf(t, seen)
    if type(t) ~= "table" then return 0 end
    seen = seen or {}
    if seen[t] then return math.huge end
    seen[t] = true
    local m = 0
    for _, v in pairs(t) do
        if type(v) == "table" then
            local d = depthOf(v, seen)
            if d > m then m = d end
        end
    end
    seen[t] = nil
    return 1 + m
end

-- Всего ключей рекурсивно (включая вложенные таблицы). Лимит 1000.
local function countKeys(t, seen)
    if type(t) ~= "table" then return 0 end
    seen = seen or {}
    if seen[t] then return 0 end
    seen[t] = true
    local n = 0
    for k, v in pairs(t) do
        n = n + 1
        if type(v) == "table" then n = n + countKeys(v, seen) end
    end
    seen[t] = nil
    return n
end

-- Проверка лимитов (внутренняя). Ошибки: config.<where>: too deep / too many keys.
local function checkLimits(data, where)
    if depthOf(data) > 5 then
        error("config." .. where .. ": too deep (max depth 5)", 3)
    end
    if countKeys(data) > 1000 then
        error("config." .. where .. ": too many keys (max 1000)", 3)
    end
end

-- Подписка автосейва один раз (базовые events.on/off, есть везде). Ошибок не кидает.
local function ensureAutosave()
    if subscribed then return end
    local ev = rawget(_ENV, "events")
    if type(ev) ~= "table" or type(ev.on) ~= "function" then return end
    subscribed = true
    ev.on("game.end", function()
        for _, c in ipairs(registry) do
            pcall(function() c:save() end)
        end
    end)
end

-- config.load(name, defaults, opts): загрузить/создать конфиг. Возврат: cfg { get,set,reset,save,isDirty }.
-- Парам: name — имя (строка, ключ "cfg:<name>"); defaults — таблица дефолтов (с _version);
-- opts — { migrate(old)→new } на несовпадение версий. Входные таблицы не мутируются.
-- Сторона: везде после link. Ошибки: call config.link...; bad name/defaults; migrate must return a table.
function config.load(name, defaults, opts)
    local st = needStore("load")
    if type(name) ~= "string" or name == "" then
        error("config.load: param 'name' must be a non-empty string", 2)
    end
    if type(defaults) ~= "table" then
        error("config.load: param 'defaults' must be a table", 2)
    end
    opts = opts or {}
    if type(opts) ~= "table" then
        error("config.load: param 'opts' must be a table", 2)
    end
    if opts.migrate ~= nil and type(opts.migrate) ~= "function" then
        error("config.load: param 'migrate' must be a function", 2)
    end
    local key = "cfg:" .. name
    local storedOk, stored = pcall(st.get, key)
    if not storedOk then stored = nil end
    local data, dirty
    if stored == nil then
        data, dirty = deepCopy(defaults), false
    elseif type(stored) ~= "table" then
        data, dirty = deepCopy(defaults), false
    elseif depthOf(stored) > 5 or countKeys(stored) > 1000 then
        data, dirty = deepCopy(defaults), false
    elseif stored._version ~= defaults._version then
        if opts.migrate ~= nil then
            local ok, newData = pcall(opts.migrate, deepCopy(stored))
            if not ok then error("config.load: migrate failed: " .. tostring(newData), 2) end
            if type(newData) ~= "table" then
                error("config.load: migrate must return a table", 2)
            end
            checkLimits(newData, "load")
            -- После миграции данные БЕЗУСЛОВНО новой версии, поэтому проставляем
            -- _version сами. Иначе автор миграции, который забудет его поднять,
            -- получает тихий цикл: migrate запускается на каждой загрузке и
            -- каждый раз меняет данные (например удваивает счётчик) — без единой
            -- ошибки. Проверено 2026-09-27 на api_stress_test/env.config.
            newData._version = defaults._version
            data, dirty = deepCopy(newData), true
        else
            data, dirty = deepCopy(defaults), true
        end
    else
        data, dirty = deepCopy(stored), false
    end
    local defCopy = deepCopy(defaults)
    local cfg = {}
    cfg._key = key
    -- cfg:get(k, fallback): значение (data → defaults → fallback). Таблицы — по ссылке, не мутировать.
    -- Парам: k — ключ-строка; fallback — если нет нигде. Сторона: везде. Ошибки: bad key.
    function cfg:get(k, fb)
        if type(k) ~= "string" or k == "" then
            error("config.get: param 'k' must be a non-empty string", 2)
        end
        if data[k] ~= nil then return data[k] end
        if defCopy[k] ~= nil then return defCopy[k] end
        return fb
    end
    -- cfg:set(k, v): задать + dirty (без записи; лимиты проверяются, превышение — ошибка с откатом).
    -- Парам: k — ключ-строка; v — значение (nil — удалить ключ). Сторона: везде. Ошибки: bad key/too deep/too many.
    function cfg:set(k, v)
        if type(k) ~= "string" or k == "" then
            error("config.set: param 'k' must be a non-empty string", 2)
        end
        local old = data[k]
        data[k] = deepCopy(v)
        local ok, err = pcall(checkLimits, data, "set")
        if not ok then
            data[k] = old
            error(err, 2)
        end
        dirty = true
    end
    -- cfg:reset([k]): без k — всё к defaults; с k — ключ к defaults (или удалить, если нет в defaults).
    -- Ставит dirty. Сторона: везде. Ошибки: bad key.
    function cfg:reset(k)
        if k == nil then
            data = deepCopy(defCopy)
            dirty = true
            return
        end
        if type(k) ~= "string" or k == "" then
            error("config.reset: param 'k' must be a non-empty string", 2)
        end
        if defCopy[k] ~= nil then data[k] = deepCopy(defCopy[k])
        else data[k] = nil end
        dirty = true
    end
    -- cfg:save(): записать ОДНИМ store.set при dirty (иначе no-op false). Возврат: true (писал) / false.
    -- Сторона: везде. Ошибки: too deep/too many keys; ошибки store пробрасываются.
    function cfg:save()
        if not dirty then return false end
        checkLimits(data, "save")
        st.set(key, deepCopy(data))
        dirty = false
        return true
    end
    -- cfg:isDirty(): есть ли несохранённые изменения. Возврат: boolean. Сторона: везде. Не кидает.
    function cfg:isDirty()
        return dirty
    end
    registry[#registry + 1] = cfg
    ensureAutosave()
    return cfg
end
