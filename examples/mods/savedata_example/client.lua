-- Проверка: начни партию, дай погибнуть нескольким юнитам, Ctrl+J — счётчик. Сохранись,
-- выйди в меню (счётчик сбросится), загрузи сейв — придёт save.loaded, Ctrl+J покажет прежнее число.

local deaths = 0

events.on("game.start", function()
    deaths = savedata.get("deaths") or 0 -- после загрузки сейва здесь уже старое значение
end)

events.on("save.loaded", function()
    deaths = savedata.get("deaths") or 0
    log.info("savedata_example: из сейва восстановлено погибших: " .. deaths ..
             ", последний сейв записан: " .. tostring(savedata.get("stamp")))
end)

events.on("unit.death", function()
    deaths = deaths + 1
    savedata.set("deaths", deaths)
    savedata.set("stamp", os.date("%H:%M:%S"))
end)

input.bind("Ctrl+J", function()
    log.info("savedata_example: погибло юнитов в этой партии (с учётом сейва): " .. deaths ..
             "  ключи: " .. table.concat(savedata.keys(), ", "))
end)
