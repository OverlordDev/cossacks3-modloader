-- census.lua — состав армии по ролям. ТОЛЬКО ЧТЕНИЕ, ничего не меняет.
--
-- ГЛАВНОЕ, что стоит знать (проверено 2026-09-27 в игре):
--   * sid НЕ лежит в objects.read — схема TObj (api/00_schema.lua:811) не имеет
--     такого поля. Первый вариант census фильтровал по o.sid и молча находил
--     0 юнитов. sid берётся из query.scan, который дёргает
--     native.GetGameObjectBaseNameByHandle.
--   * bbuilding тоже НЕ в objects.read — он лежит в gObjProp[cid][id].
--     Тот же query.scan умеет отсекать здания одним батчем: { building = false }.
--   * query.scan работает через game.exec, то есть ТОЛЬКО на server/shared.
--     На клиенте census построить нельзя — клиент получает снимок по сети
--     (net.broadcast "if.census" в shared.lua, приём в client.lua).
--
-- lockstep: ни одна функция здесь не меняет мир. Пересчёт на всех машинах
-- выполняется одинаковый код по одинаковому списку, поэтому расхождения быть
-- не может — на результат игры census не влияет.

local R = require("lib/registry")

local role = {}      -- h -> role
local census = {}    -- sid -> сколько живых
local snap = { units = 0, byRole = {}, census = {}, summary = "", at = 0 }

local C = {}

-- Есть ли право считать. На клиенте game.exec нет — census там пустой.
function C.canScan()
    local g = rawget(_ENV, "game")
    return g ~= nil and type(g.exec) == "function" and g.isInGame ~= nil and g.isInGame()
end

-- Пересчёт. Возвращает число новых юнитов.
function C.rescan()
    if not C.canScan() or not query or not query.scan then return 0 end
    local ok, recs = pcall(query.scan, { building = false, alive = true })
    if not ok or type(recs) ~= "table" then return 0 end

    local byRole, bySid = {}, {}
    for _, rec in ipairs(recs) do
        local sid = rec.sid
        if type(sid) == "string" and sid ~= "" then
            local r = R.roleOf(sid)
            byRole[r] = (byRole[r] or 0) + 1
            bySid[sid] = (bySid[sid] or 0) + 1
            role[rec.handle] = r
        end
    end

    -- роли назначены только что упомянутым юнитам: всё, чего нет в списке,
    -- считаем мёртвым. Это заодно чистит кэш от утечки.
    local alive = {}
    for _, rec in ipairs(recs) do alive[rec.handle] = true end
    for h in pairs(role) do
        if not alive[h] then role[h] = nil end
    end

    local n = 0
    for _ in pairs(role) do n = n + 1 end
    local parts = {}
    for r in pairs(byRole) do parts[#parts + 1] = r .. "=" .. byRole[r] end
    table.sort(parts)

    census = bySid
    snap = { units = n, byRole = byRole, census = bySid,
             summary = table.concat(parts, " "), at = n }
    return n
end

-- Роль хендля (nil, если неизвестен).
function C.role(h) return role[h] end

-- Описание роли — всегда таблица, чтобы вызывающий не проверял nil.
function C.roleDef(h) return R.roleDef(role[h] or "line") end

function C.isArty(h)
    local r = role[h]
    return r == "artillery"
end

function C.known(h) return role[h] ~= nil end

-- Снимок для UI и отчёта. Копия, чтобы вызывающий не испортил внутреннее.
function C.snapshot()
    return { units = snap.units, byRole = snap.byRole, census = snap.census,
             summary = snap.summary }
end

-- Приём снимка, пришедшего по сети (клиент).
function C.accept(remote)
    if type(remote) ~= "table" then return false end
    snap = { units = remote.units or 0, byRole = remote.byRole or {},
             census = remote.census or {}, summary = remote.summary or "", at = 0 }
    return true
end

C.report = C.snapshot

function C.line()
    if snap.units == 0 then return "IF 0.1.0  |  состав неизвестен (нужен server/shared)" end
    return string.format("IF 0.1.0  |  юнитов %d  |  %s", snap.units, snap.summary)
end

return C
