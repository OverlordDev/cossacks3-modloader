-- builtin: автостатус Steam Rich Presence на всех экранах.
--
-- game.menu    -> "В главном меню" (ключи матча стираются)
-- game.prepare -> "В лобби" / "Настройка игры" (есть режим сети, карты ещё нет)
-- game.start   -> "В партии": карта, режим (2v2/FFA), соперники (ники врагов)
-- game.end     -> очистить
-- Троттлинг и дедуп — внутри steam.setMatch (api/58_steam.lua).

local function safe(fn, ...)
    local ok, r = pcall(fn, ...)
    if ok then return r end
    return nil
end

-- "2v2" / "3x3" / "FFA 4" по живым игрокам и командам.
local function modeText()
    local list = safe(players.list) or {}
    if #list == 0 then return game.mode() == "offline" and "Одиночная" or game.mode() end
    local teams = {}
    for _, p in ipairs(list) do
        teams[p.team or 0] = (teams[p.team or 0] or 0) + 1
    end
    local sizes = {}
    for _, n in pairs(teams) do sizes[#sizes + 1] = n end
    table.sort(sizes)
    if #sizes == 2 then return sizes[1] .. "v" .. sizes[2] end
    if #sizes > 2 then return "FFA " .. #list end
    return "Одиночная"
end

-- Ники врагов (не своя команда), максимум 3.
local function opponents()
    local list = safe(players.list) or {}
    local me = safe(players.me)
    local myTeam = nil
    for _, p in ipairs(list) do
        if p.index == me then myTeam = p.team break end
    end
    local out = {}
    for _, p in ipairs(list) do
        if p.team ~= myTeam and p.name and p.name ~= "" then
            out[#out + 1] = p.name
            if #out >= 3 then break end
        end
    end
    return out
end

local function mapName()
    local info = safe(map.info)
    if type(info) == "table" and info.name and info.name ~= "" then
        return tostring(info.name)
    end
    return nil
end

events.on("game.menu", function()
    steam.clear()
    steam.setMatch({ status = "В главном меню" })
end)

events.on("game.prepare", function()
    steam.clear()
    local mode = game.mode()
    local where = (mode == "offline") and "Настройка игры" or "В лобби"
    steam.setMatch({ status = where, mode = modeText() })
end)

events.on("game.start", function()
    steam.clear()
    steam.setMatch({ status = "В партии", map = mapName(),
                     mode = modeText(), opponents = opponents() })
end)

events.on("game.end", function()
    steam.clear()
end)
