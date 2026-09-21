-- Баланс и события объектов. Шпаргалка: api/17_balance.lua, события — README модлоадера.
--
-- События объектов: function(event, handle, basename)
--   unit.spawn / unit.death / unit.destroy          — юниты
--   building.spawn / building.death / building.destroy — здания
-- handle — хендл объекта (для native.GetGameObject*ByHandle), basename — его тип.

local kills = {}

events.on("game.start", function()
    -- Имена типов — balance.types(); поля — GAME_STATE.md (TObjBase).
    -- Сначала посмотрим, что есть: список типов в лог (первые 20).
    local types = balance.types()
    log.info("типов юнитов и зданий: " .. #types)
    for i = 1, math.min(20, #types) do log.info("  " .. types[i].sid) end

    -- Пример правки: всем юнитам первого типа из списка — +50% здоровья.
    local sid = types[1] and types[1].sid
    if sid then
        local hp = balance.get(sid).base.maxhp
        balance.set(sid, "maxhp", math.floor(hp * 1.5))
        log.info(string.format("%s: maxhp %d -> %d", sid, hp, balance.get(sid).base.maxhp))
    end
end)

events.on("unit.spawn", function(_, handle, basename)
    log.info("появился " .. basename .. " #" .. handle)
end)

events.on("unit.death", function(_, handle, basename)
    kills[basename] = (kills[basename] or 0) + 1
    log.info(string.format("погиб %s #%d (всего таких: %d)", basename, handle, kills[basename]))
end)

events.on("building.death", function(_, handle, basename)
    log.info("разрушено здание " .. basename .. " #" .. handle)
end)
