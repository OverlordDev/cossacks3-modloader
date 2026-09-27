-- object — машины состояний объектов: огонь, ремонт, захват, ранения.
--
-- Чтение состояния — с любой стороны; смена — только server/shared (меняет мир).
--
--   object.state(h)                       --> "idle" / "burning" / ... (имя текущего состояния)
--   object.setState(h, "burning")         -- перевести в состояние (server/shared)
--   object.destroyIn(h, "destroyed")      -- объект уничтожится при входе в состояние
--   object.waitFor(h, "destroyed", function(h) log.info("сгорел") end)
--                                         -- разовый колбэк на вход в состояние (любая сторона)
--   object.progress(h, "scripts/fire.aix", "burning", { interval = 100 })
--                                         -- повесить прогресс-поведение (экспериментально)
--
-- Имена состояний — из .aix юнита/здания. Неверное имя игра игнорирует или падает —
-- проверять на копии сейва. waitFor опрашивает в game.tick (дешёвый Get-натив).

object = {}

-- Ненулевой хендл объекта. Возвращает integer. Ошибки: не число или 0.
local function checkHandle(h, where)
    h = math.tointeger(tonumber(h))
    if not h or h == 0 then error("object." .. where .. ": handle must be a non-zero number", 3) end
    return h
end

-- Непустое имя состояния. Возвращает строку. Ошибки: не строка или пустая.
local function checkName(name, where)
    if type(name) ~= "string" or name == "" then
        error("object." .. where .. ": state name must be a non-empty string", 3)
    end
    return name
end

-- Проверка записи: только server/shared (нужен game.exec) и только в партии. Ошибки: на client; вне партии.
local function needServer(where)
    if not game.exec then
        error("object." .. where .. ": only server/shared scripts can change the game", 3)
    end
    if not game.isInGame() then
        error("object." .. where .. ": no active game (check game.isInGame())", 3)
    end
end

-- Текущее состояние объекта. Параметры: h — хендл объекта. Возвращает имя состояния (строка). Сторона: любая (Get-натив, только чтение). Ошибки: вне партии; h нулевой/не число.
-- Текущее состояние объекта (Get-натив — можно и на client).
function object.state(h)
    if not game.isInGame() then error("object.state: no active game", 2) end
    return native.GetGameObjectStateNameByHandle(checkHandle(h, "state"))
end

-- Перевести объект в состояние. Параметры: h — хендл; name — имя состояния из .aix. Возвращает nil. Сторона: только server/shared. Ошибки: на client (нет game.exec); вне партии; h нулевой; имя пустое.
-- Перевести объект в состояние.
function object.setState(h, name)
    needServer("setState")
    native.GameObjectSwitchToStateByHandle(checkHandle(h, "setState"), checkName(name, "setState"))
end

-- Объект будет уничтожен при входе в состояние. Параметры: h — хендл; name — имя состояния-триггера. Возвращает nil. Сторона: только server/shared. Ошибки: на client; вне партии; h нулевой; имя пустое.
-- Объект будет уничтожен при входе в состояние (ловушка сработала, огонь догорел).
function object.destroyIn(h, name)
    needServer("destroyIn")
    native.SetGameObjectOnStateDestroyByHandle(checkHandle(h, "destroyIn"), checkName(name, "destroyIn"))
end

-- Повесить тикающее поведение из скрипта игры. Параметры: h — хендл; script — путь .aix; statename — состояние; opts.static/enabled/interval (мс, по умолчанию 100). Возвращает id поведения. Сторона: только server/shared (экспериментально). Ошибки: на client; вне партии; h нулевой; script пустой; opts не таблица; interval не целое.
-- Повесить тикающее поведение из скрипта игры (экспериментально).
-- opts = { static = false, enabled = true, interval = 100 } (interval — мс).
function object.progress(h, script, statename, opts)
    needServer("progress")
    h = checkHandle(h, "progress")
    if type(script) ~= "string" or script == "" then
        error("object.progress: script must be a non-empty path", 2)
    end
    checkName(statename, "progress")
    opts = opts or {}
    if type(opts) ~= "table" then error("object.progress: opts must be a table", 2) end
    return native.GameObjectCreateProgressStateMachineBehaviour(h, script, statename,
        opts.static == true, opts.enabled ~= false,
        math.tointeger(tonumber(opts.interval or 100))
        or error("object.progress: interval must be an integer", 2))
end

-- Разово дождаться состояния: fn(handle) при первом входе. Параметры: h — хендл; name — имя состояния; fn — колбэк. Возвращает id подписки (снять через events.off). Сторона: любая (опрос в game.tick одним Get-нативом). Ошибки: h нулевой; имя пустое; fn не функция.
-- Разово дождаться состояния: fn(handle) при первом входе. Возвращает id подписки
-- (можно снять через events.off(id)). Опрос — в game.tick, один Get-натив на объект.
function object.waitFor(h, name, fn)
    h = checkHandle(h, "waitFor")
    checkName(name, "waitFor")
    if type(fn) ~= "function" then error("object.waitFor: fn must be a function", 2) end
    local id
    id = events.on("game.tick", function()
        if not game.isInGame() then return end
        local ok, cur = pcall(native.GetGameObjectStateNameByHandle, h)
        if ok and cur == name then
            events.off(id)
            fn(h)
        end
    end)
    return id
end
