-- balance — параметры типов юнитов и зданий: читать и менять посреди партии.
--
-- Где это у игры (data/scripts/lib/classes.script, unit.script):
--   gObjProp[нация][тип]                     TObjProp — общее для всех игроков: обзор, радиусы,
--                                            роль, флаги (bartillery, bofficer...), оружие (статика)
--   gPlayer[игрок].objbase[нация][тип]       TObjBase — своё у каждого игрока (его меняют улучшения):
--                                            maxhp, shield, price[0..6], buildtime, speed,
--                                            protection[0..9], weapon[0..3].damage/radiusmax/pause...
-- Игра заполняет их в начале партии (_unit_InitBase), поэтому менять — в game.start или позже.
--
--   balance.types()                          --> { {sid="rus_strelets", country=4, id=12}, ... }
--   balance.find("rus_strelets")             --> 4, 12        (нация, номер типа)
--   balance.get("rus_strelets")              --> { base = {maxhp=..., weapon={[0]={damage=...}}...}, prop = {...} }
--   balance.get("rus_strelets", 2)           --  base игрока 2
--   balance.set("rus_strelets", "maxhp", 300)             -- всем игрокам
--   balance.set("rus_strelets", "weapon[0].damage", 40, 1) -- только игроку 1
--   balance.set("rus_strelets", "price[3]", 50)            -- цена: 0 еда 1 дерево 2 камень 3 золото 4 железо 5 уголь
--   balance.setProp("rus_strelets", "vision", 900)         -- общее свойство типа
--   balance.dump("rus_strelets")             --  всё в лог — чтобы посмотреть имена полей
--
-- Поля и типы — GAME_STATE.md (TObjBase, TObjWeapon, TObjProp, TObjWeaponStatic).
--
-- МУЛЬТИПЛЕЕР: статы юнитов считаются на каждой машине. Меняйте их одинаково у всех игроков:
-- мод со стороной shared (server.lua выполняется на всех машинах) и изменение в game.start.
-- Иначе партии разойдутся (рассинхрон).

balance = {}

local PLAYERS = 12
local cache -- sid (нижний регистр) -> { {country, id, sid}, ... } — одно имя бывает у нескольких наций

-- Все непустые типы одним вызовом скрипта: цикл по gObjProp собирает строку "нация,тип,sid;".
local function scan()
    local list = {}
    local text
    if game.exec then
        text = game.exec([[
var s : String;
var c, u : Integer;
for c := 0 to gc_MaxCountryCount-1 do
for u := 0 to gc_country_maxmembers-1 do
if gObjProp[c][u].sid <> '' then
s := s + IntToStr(c) + ',' + IntToStr(u) + ',' + gObjProp[c][u].sid + ';';
ML_RET(s);]])
    else
        -- Клиенту исполнять код нельзя — читаем по одному (медленнее, но только один раз).
        --
        -- ЧЕРЕЗ state.get, А НЕ game.eval С ЧИСЛАМИ В ТЕКСТЕ. Движок кэширует код
        -- по тексту, и каждый новый текст — это состояние ModLoader.Call.N,
        -- которое живёт до конца партии и не освобождается. Здесь 24 x 80 путей,
        -- то есть раньше этот цикл в одиночку создавал 1920 состояний движка.
        -- state.get уводит индексы в аргумент (api/01_state.lua, paramise), и
        -- текст остаётся один на все 1920 чтений.
        local parts = {}
        for c = 0, 23 do
            for u = 0, 79 do
                local sid = state.get("gObjProp[" .. c .. "][" .. u .. "].sid")
                if sid ~= nil and sid ~= "" then parts[#parts + 1] = c .. "," .. u .. "," .. sid end
            end
        end
        text = table.concat(parts, ";")
    end
    for c, u, sid in text:gmatch("(%d+),(%d+),([^;]+)") do
        list[#list + 1] = { sid = sid, country = tonumber(c), id = tonumber(u) }
    end
    return list
end

local function index()
    if cache then return cache end
    cache = {}
    for _, t in ipairs(scan()) do
        local key = t.sid:lower()
        cache[key] = cache[key] or {}
        table.insert(cache[key], t)
    end
    return cache
end

-- balance.types(): все типы юнитов/зданий. Возврат: { { sid, country, id }, ... } по алфавиту.
-- Сторона: shared (везде). Ошибок не кидает.
function balance.types()
    local out = {}
    for _, list in pairs(index()) do
        for _, t in ipairs(list) do out[#out + 1] = t end
    end
    table.sort(out, function(a, b) return a.sid < b.sid or (a.sid == b.sid and a.country < b.country) end)
    return out
end

-- balance.refresh(): сбросить кэш типов. Вызывать при смене набора наций в новой партии.
-- Сторона: shared. Ошибок не кидает.
function balance.refresh() cache = nil end

-- Все места, где живёт тип: { {country, id}, ... }.
local function places(sid, level)
    local list = index()[tostring(sid):lower()]
    if not list then
        error("balance: unknown unit type '" .. tostring(sid) .. "' (balance.types() lists all)", (level or 1) + 2)
    end
    return list
end

-- balance.find(sid): нация и номер типа по sid. Парам: sid — имя типа. Возврат: country, id.
-- Ошибки: "unknown unit type". Остальные нации — balance.places(sid).
function balance.find(sid)
    local t = places(sid, 1)[1]
    return t.country, t.id
end

-- balance.places(sid): все места типа. Парам: sid — имя типа. Возврат: { { country, id }, ... }.
-- Ошибки: "unknown unit type" при неверном sid.
function balance.places(sid) return places(sid, 1) end

local function basePath(t, player)
    return string.format("gPlayer[%d].objbase[%d][%d]", player, t.country, t.id)
end

local function propPath(t)
    return string.format("gObjProp[%d][%d]", t.country, t.id)
end

-- balance.get(sid, player): статы типа. Парам: sid — имя типа; player — игрок (по умолч. 0).
-- Возврат: { base, prop } (TObjBase, TObjProp, глубина 2). Ошибки: "unknown unit type".
function balance.get(sid, player)
    local t = places(sid, 1)[1]
    return {
        base = state.read(basePath(t, player or 0), 2),
        prop = state.read(propPath(t), 2),
    }
end

-- balance.set(sid, field, value, player): поле TObjBase. Парам: sid — тип; field — путь ("maxhp", "price[3]", "weapon[0].damage"); value — значение; player — игрок (без него — все).
-- Сторона: server/shared (game.start). Ошибки: "unknown unit type", "only server/shared scripts".
function balance.set(sid, field, value, player)
    if not game.exec then
        error("balance.set: only server/shared scripts can change the game", 2)
    end
    local first, last = 0, PLAYERS - 1
    if player then first, last = player, player end
    local sep = field:sub(1, 1) == "[" and "" or "."
    for _, t in ipairs(places(sid, 1)) do -- у всех наций с этим типом
        for p = first, last do
            state.set(basePath(t, p) .. sep .. field, value)
        end
    end
end

-- balance.setProp(sid, field, value): общее поле типа TObjProp. Парам: sid — тип; field — путь; value — значение.
-- Сторона: server/shared. Ошибки: "unknown unit type", "only server/shared scripts".
function balance.setProp(sid, field, value)
    if not game.exec then
        error("balance.setProp: only server/shared scripts can change the game", 2)
    end
    local sep = field:sub(1, 1) == "[" and "" or "."
    for _, t in ipairs(places(sid, 1)) do
        state.set(propPath(t) .. sep .. field, value)
    end
end

local function flatten(t, prefix, out)
    local keys = {}
    for k in pairs(t) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    for _, k in ipairs(keys) do
        local v = t[k]
        local name = prefix == "" and tostring(k) or (prefix .. "." .. tostring(k))
        if type(v) == "table" then flatten(v, name, out) else out[#out + 1] = name .. " = " .. tostring(v) end
    end
end

-- balance.dump(sid, player): все поля типа текстом в лог. Парам: sid — тип; player — игрок (по умолч. 0).
-- Возврат: строка дампа. Ошибки: "unknown unit type".
function balance.dump(sid, player)
    local data = balance.get(sid, player)
    local lines = {}
    flatten(data, "", lines)
    local text = sid .. ":\n  " .. table.concat(lines, "\n  ")
    if log and log.info then log.info(text) end
    return text
end

-- ---------- как улучшения игры: тип + все живые юниты ----------
--
-- balance.set меняет только тип: игра копирует здоровье и скорость в юнита при его появлении,
-- поэтому уже живые юниты изменения не увидят. Эти функции делают то же, что улучшения самой
-- игры (data/scripts/lib/player.script): меняют тип и пересчитывают всех живых.
--
--   balance.setHP("musketeer18", 500)          -- макс. здоровье; текущее у живых — пропорционально
--   balance.setDamage("musketeer18", 60)       -- урон всех видов оружия (с учётом улучшений игрока)
--   balance.setDamage("musketeer18", 60, 1)    -- только оружие 1 (у мушкетёра 0 — штык, 1 — выстрел)
--   balance.setSpeed("musketeer18", 2)         -- в 2 раза быстрее обычного (1 — как в игре)
-- Последний аргумент у всех — номер игрока (без него — все игроки).

local function needExec(name)
    if not game.exec then error("balance." .. name .. ": only server/shared scripts can change the game", 3) end
end

-- forEach(sid, player, body, values): код для каждого места типа + цикл по игрокам.
-- Парам: sid — тип; player — игрок (nil — все); body — тело на Pascal; values —
-- числа для тела (видны как v1..vN, уже целые).
-- Возврат: код, аргумент для game.exec.
--
-- ЧИСЛА НЕ ПЕКУТСЯ В ТЕКСТ. Движок кэширует скомпилированный код по тексту, и
-- каждый новый текст — это состояние ModLoader.Call.N, живущее до конца партии;
-- освободить его нельзя (ScriptRunner.cpp, g_callCache). Раньше и номер страны с
-- номером типа, и сами значения (maxhp, урон, интервал) шли прямо в текст, то
-- есть каждый тип и каждое новое значение съедали ещё одно состояние навсегда.
--
-- В тексте остаётся форма, а страна/тип/диапазон игроков/значения уезжают в
-- ML_ARG. Разбор — функциями движка: Pos/Copy в этом диалекте Pascal нет,
-- есть StrPos/SubStr/StrLength (tools/check_pascal.py).
local function forEach(sid, player, body, values)
    values = values or {}
    local spots = places(sid, 2)
    local args = { player or 0, player or (PLAYERS - 1) }
    local names = { "pfirst", "plast" }
    for i, t in ipairs(spots) do
        args[#args + 1] = t.country
        args[#args + 1] = t.id
        names[#names + 1] = "c" .. i
        names[#names + 1] = "u" .. i
    end
    for i, v in ipairs(values) do
        args[#args + 1] = math.floor(tonumber(v) or 0)
        names[#names + 1] = "v" .. i
    end

    -- Порядок объявлений — как в заведомо рабочем api/38_orders.lua: сначала
    -- строка с ML_ARG, потом остальное.
    local head = { "var s : String = ML_ARG;",
                   "var q : Integer;",
                   "var c, u, p, i, k, plHnd, h : Integer;",
                   "var pobj : Pointer;",
                   "var old, ratio : Float;",
                   "var " .. table.concat(names, ", ") .. " : Integer;" }
    for _, name in ipairs(names) do
        head[#head + 1] = string.format(
            "q := StrPos('|', s); %s := StrToInt(SubStr(s, 1, q-1)); s := SubStr(s, q+1, StrLength(s)-q);",
            name)
    end

    local out = {}
    for i = 1, #spots do
        out[#out + 1] = string.format([[
for p := pfirst to plast do
begin
c := c%d; u := u%d;
plHnd := GetPlayerHandleByIndex(p);
%s
end;]], i, i, body)
    end
    -- Аргумент заканчивается разделителем: разбор режет по '|' ровно столько раз,
    -- сколько имён, и последнему тоже нужен свой '|'.
    return table.concat(head, "\n") .. "\n" .. table.concat(out, "\n"),
           table.concat(args, "|") .. "|"
end

-- Цикл по живым объектам этого типа у игрока p: тело видит pobj (TObj) и h (хендл).
local EACH_UNIT = [[
if plHnd <> 0 then
for i := 0 to GetPlayerGameObjectsCountByHandle(plHnd)-1 do
begin
h := GetGameObjectHandleByIndex(i, plHnd);
pobj := _unit_GetTObj(h);
if (pobj <> nil) and (TObj(pobj).cid = c) and (TObj(pobj).id = u) then
begin
%s
end;
end;]]

-- balance.setHP(sid, maxhp, player): макс. здоровье типа + живых (пропорционально). Парам: sid — тип; maxhp — число; player — игрок (без него — все).
-- Сторона: server/shared. Ошибки: "unknown unit type", "only server/shared scripts".
function balance.setHP(sid, maxhp, player)
    needExec("setHP")
    maxhp = math.floor(tonumber(maxhp) or 0)
    -- v1 — новое maxhp; в текст не пишем (см. forEach).
    game.exec(forEach(sid, player, [[
old := gPlayer[p].objbase[c][u].maxhp;
gPlayer[p].objbase[c][u].maxhp := v1;
if old > 0 then
]] .. EACH_UNIT:format("TObj(pobj).hp := Round(TObj(pobj).hp / old * v1);"), { maxhp }))
end

-- balance.setDamage(sid, damage, weapon, player): урон оружия типа + живых. Парам: sid — тип; damage — число; weapon — номер (без него — все); player — игрок (без него — все).
-- Сторона: server/shared. Ошибки: "unknown unit type", "only server/shared scripts".
function balance.setDamage(sid, damage, weapon, player)
    needExec("setDamage")
    damage = math.floor(tonumber(damage) or 0)
    local first, last = weapon or 0, weapon or 3
    -- v1, v2 — диапазон оружия; v3 — урон.
    game.exec(forEach(sid, player, [[
for k := v1 to v2 do
if gObjProp[c][u].weapon[k].enabled then
begin
gPlayer[p].objbase[c][u].weapon[k].damageinit := v3;
gPlayer[p].objbase[c][u].weapon[k].damage := Floor((gPlayer[p].objbase[c][u].weapon[k].damageinit + gPlayer[p].objbase[c][u].weapon[k].damagestatic) * (1 + gPlayer[p].objbase[c][u].weapon[k].damagepercent / 100));
end;]], { first, last, damage }))
end

-- balance.setSpeed(sid, multiplier, player): скорость типа + живых. Парам: sid — тип; multiplier — во сколько раз (1 — как в игре); player — игрок (без него — все).
-- У игры — интервал шага (меньше — быстрее); здесь — понятный множитель. Сторона: server/shared.
function balance.setSpeed(sid, multiplier, player)
    needExec("setSpeed")
    local interval = 1 / (tonumber(multiplier) or 1)
    -- v1 — интервал шага в миллионных (StrToFloat зависит от локали, поэтому целое).
    game.exec(forEach(sid, player, [[
old := gPlayer[p].objbase[c][u].speed;
if old <= 0 then old := 1;
ratio := v1 / 1000000 / old;
gPlayer[p].objbase[c][u].speed := v1 / 1000000;
]] .. EACH_UNIT:format([[
SetGameObjectTrackPointMoveStepIntervalByHandle(h, Floor(GetGameObjectTrackPointMoveStepIntervalByHandle(h) * ratio));
SetGameObjectTrackPointTurnStepIntervalByHandle(h, Floor(GetGameObjectTrackPointTurnStepIntervalByHandle(h) * ratio));]]),
        { math.floor(interval * 1000000 + 0.5) }))
end
