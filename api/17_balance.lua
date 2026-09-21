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
local cache -- sid (нижний регистр) -> { country, id }

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
        local parts = {}
        for c = 0, 23 do
            for u = 0, 79 do
                local sid = game.eval("gObjProp[" .. c .. "][" .. u .. "].sid")
                if sid ~= "" then parts[#parts + 1] = c .. "," .. u .. "," .. sid end
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
    for _, t in ipairs(scan()) do cache[t.sid:lower()] = t end
    return cache
end

function balance.types()
    local out = {}
    for _, t in pairs(index()) do out[#out + 1] = t end
    table.sort(out, function(a, b) return a.sid < b.sid end)
    return out
end

-- Список типов строится при первом обращении; после смены набора наций в новой партии — сбросить.
function balance.refresh() cache = nil end

function balance.find(sid)
    local t = index()[tostring(sid):lower()]
    if not t then
        error("balance: unknown unit type '" .. tostring(sid) .. "' (balance.types() lists all)", 2)
    end
    return t.country, t.id
end

local function basePath(sid, player)
    local c, u = balance.find(sid)
    return string.format("gPlayer[%d].objbase[%d][%d]", player, c, u)
end

local function propPath(sid)
    local c, u = balance.find(sid)
    return string.format("gObjProp[%d][%d]", c, u)
end

function balance.get(sid, player)
    return {
        base = state.read(basePath(sid, player or 0), 2),
        prop = state.read(propPath(sid), 2),
    }
end

-- field: путь внутри TObjBase: "maxhp", "speed", "price[3]", "weapon[0].damage", "protection[2]".
function balance.set(sid, field, value, player)
    if not game.exec then
        error("balance.set: only server/shared scripts can change the game", 2)
    end
    local first, last = 0, PLAYERS - 1
    if player then first, last = player, player end
    local sep = field:sub(1, 1) == "[" and "" or "."
    for p = first, last do
        state.set(basePath(sid, p) .. sep .. field, value)
    end
end

function balance.setProp(sid, field, value)
    if not game.exec then
        error("balance.setProp: only server/shared scripts can change the game", 2)
    end
    local sep = field:sub(1, 1) == "[" and "" or "."
    state.set(propPath(sid) .. sep .. field, value)
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

function balance.dump(sid, player)
    local data = balance.get(sid, player)
    local lines = {}
    flatten(data, "", lines)
    local text = sid .. ":\n  " .. table.concat(lines, "\n  ")
    if log and log.info then log.info(text) end
    return text
end
