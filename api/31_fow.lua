-- fow — туман войны: вкл/выкл, плотность, точечная разведка, дымовая завеса.
--
-- Чтение — отовсюду; запись — только server/shared (видимость влияет на игру).
-- В сети — в shared, иначе у игроков разная разведка.
--
--   fow.enable(false)                 -- снять туман (тест/катсцена); fow.isEnabled()
--   fow.lerp(0.5)                     -- резкость края; fow.smooth(true, 1.0, false, 0)
--   fow.revealObject(h)               -- объект разведывает (прожектор); fow.hideObject(h)
--   fow.clearObjects()                -- снять все точечные разведки
--   fow.rebuild()                     -- пересчитать туман целиком

fow = {}

local function needServer(where)
    if not game.exec then
        error("fow." .. where .. ": only server/shared scripts can change the game", 3)
    end
    if not game.isInGame() then
        error("fow." .. where .. ": no active game (check game.isInGame())", 3)
    end
end

local function checkHandle(h, where)
    h = math.tointeger(tonumber(h))
    if not h or h == 0 then error("fow." .. where .. ": handle must be a non-zero number", 3) end
    return h
end

local function num(v, name)
    local n = tonumber(v)
    if not n or n ~= n then error("fow: " .. name .. " must be a number", 3) end
    return n
end

-- enable(v): вкл/выкл туман; без аргумента — геттер. Чтение — везде, запись — server/shared. Ошибки: запись не с server, нет игры.
function fow.enable(v)
    if v == nil then return native.GetFOWEnable() end
    needServer("enable")
    native.SetFOWEnable(v and true or false)
end

-- isEnabled(): вкл ли туман. Возврат: bool. Чтение — везде (client/server/shared), ошибок не кидает.
function fow.isEnabled()
    return native.GetFOWEnable()
end

-- lerp(v): резкость края тумана; без аргумента — геттер. Чтение — везде, запись — server/shared. Ошибки: запись не с server, нет игры, v не число.
function fow.lerp(v)
    if v == nil then return native.GetFOWLerpFactor() end
    needServer("lerp")
    native.SetFOWLerpFactor(num(v, "lerp"))
end

-- elevation(v): учёт высоты в тумане; без аргумента — геттер. Чтение — везде, запись — server/shared. Ошибки: запись не с server, нет игры, v не число.
function fow.elevation(v)
    if v == nil then return native.GetFOWElevation() end
    needServer("elevation")
    native.SetFOWElevation(num(v, "elevation"))
end

-- textured(v): текстурированный туман; без аргумента — геттер. Чтение — везде, запись — server/shared. Ошибки: запись не с server, нет игры.
function fow.textured(v)
    if v == nil then return native.GetFOWTextured() end
    needServer("textured")
    native.SetFOWTextured(v and true or false)
end

-- Сглаживание края тумана: pcf/aa и их сила (pcfFactor, aaFactor — числа).
-- Только server/shared, ничего не возвращает. Ошибки: не server, нет игры, факторы не числа.
function fow.smooth(pcf, pcfFactor, aa, aaFactor)
    needServer("smooth")
    native.SetFOWSmooth(pcf and true or false, num(pcfFactor or 1, "pcfFactor"),
        aa and true or false, num(aaFactor or 0, "aaFactor"))
end

-- rebuild(): пересчитать туман целиком. Только server/shared. Ошибки: не server, нет игры.
function fow.rebuild()
    needServer("rebuild")
    native.FOWBuildFull()
end

-- Точечная разведка от объекта (прожектор, разведчик, ракета). Параметр: h — хендл объекта.
-- Только server/shared. Ошибки: не server, нет игры, h нулевой/не число.
function fow.revealObject(h)
    needServer("revealObject")
    native.AddFOWObjects(checkHandle(h, "revealObject"))
end

-- hideObject(h): снять точечную разведку с объекта. Параметр: h — хендл. Только server/shared. Ошибки: не server, нет игры, h нулевой/не число.
function fow.hideObject(h)
    needServer("hideObject")
    native.DelFOWObjects(checkHandle(h, "hideObject"))
end

-- clearObjects(): снять все точечные разведки. Только server/shared. Ошибки: не server, нет игры.
function fow.clearObjects()
    needServer("clearObjects")
    native.ClearFOWObjects()
end

-- revealPlayer(ph): игрок (хендл игрока) видит всё. Только server/shared. Ошибки: не server, нет игры, ph нулевой/не число.
function fow.revealPlayer(ph)
    needServer("revealPlayer")
    native.AddFOWPlayers(checkHandle(ph, "revealPlayer"))
end

-- clearPlayers(): сбросить полное открытие игрокам. Только server/shared. Ошибки: не server, нет игры.
function fow.clearPlayers()
    needServer("clearPlayers")
    native.ClearFOWPlayers()
end
