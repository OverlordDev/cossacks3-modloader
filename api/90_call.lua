-- api_call — вход для страниц: game.api('saves.list') в JS превращается в api_call('saves.list').
--
--   api_call("profile.get", "sndmaster")
--   api_call("state.read", "gMap.players[0]")
--
-- Имя — путь к функции через точку от глобальных таблиц api (state, profile, options, saves,
-- players, map, world...). Ответ модлоадер возвращает странице JSON.

function api_call(name, ...)
    local target = _ENV
    for part in tostring(name):gmatch("[^%.]+") do
        if type(target) ~= "table" then break end
        target = target[part]
    end
    if type(target) ~= "function" then
        error("api: '" .. tostring(name) .. "' is not a function", 2)
    end
    return target(...)
end
