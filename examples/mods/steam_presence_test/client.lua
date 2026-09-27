-- steam_presence_test: ручная проверка Rich Presence.
-- В партии ставит тестовый статус; F7 — обновить (счётчик), F8 — очистить.

local n = 0

local function report(where)
    log.info(string.format("steam %s: available=%s status=%s myId=%s",
        where, tostring(steam.available()), tostring(steam.status()),
        tostring(steam.myId() or "-")))
end

events.on("game.menu", function()
    report("menu")
end)

events.on("game.start", function()
    if game.mode() == "offline" then
        log.warn("steam test: offline-режим — статус ставится, но соперников нет")
    end
    report("start")
    n = 0
    local ok, why = steam.setMatch({ status = "Тест модлоадера", map = "Полтава",
                                     mode = "тест", opponents = { "Иван" } })
    log.info("steam test: setMatch -> " .. tostring(ok) .. " " .. tostring(why or ""))
end)

events.on("game.end", function()
    log.info("steam test: партия кончилась, статус снят builtin-модом")
end)

input.bind("F7", function()
    if not game.isInGame() then
        log.warn("steam test: вне партии нечего обновлять")
        return
    end
    n = n + 1
    local ok, why = steam.setOpponent("Иван " .. n)
    log.info("steam test: F7 update -> " .. tostring(ok) .. " " .. tostring(why or ""))
end)

input.bind("F8", function()
    local ok = steam.clear()
    log.info("steam test: F8 clear -> " .. tostring(ok))
end)
