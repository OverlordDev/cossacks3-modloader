-- time — скорость игры: замедление, ускорение, пауза для тестов и катсцен.
--
-- МЕНЯЕТ ХОД ПАРТИИ: только server/shared. В сети — в shared (скорость у всех одна).
--
--   time.speed(0.5)     -- slow-mo для отладки анимаций; time.speed(2) — ускорение ИИ
--   time.pause()        -- time.resume() (запоминает предыдущую скорость)
--   time.factor()       --> текущая скорость (1 — норма)

time = {}

local saved = nil

local function needServer(where)
    if not game.exec then
        error("time." .. where .. ": only server/shared scripts can change the game", 3)
    end
    if not game.isInGame() then
        error("time." .. where .. ": no active game (check game.isInGame())", 3)
    end
end

-- factor(): текущая скорость игры (1 — норма). Возврат: число. Только чтение (везде). Ошибки: вне партии.
function time.factor()
    if not game.isInGame() then error("time.factor: no active game", 2) end
    return native.GetTimeSpeedFactor()
end

-- speed(f): задать скорость (0 — пауза, 0.5 — slow-mo, 2 — ускорение). Парам: f — число >= 0.
-- Сторона: только server/shared. Ошибки: на client; вне партии; f не число или < 0.
function time.speed(f)
    needServer("speed")
    f = tonumber(f)
    if not f or f ~= f or f < 0 then error("time.speed: factor must be a number >= 0", 2) end
    native.SetTimeSpeedFactor(f)
end

-- pause(): пауза (запоминает скорость для resume). Сторона: только server/shared. Ошибки: на client; вне партии.
function time.pause()
    needServer("pause")
    if saved == nil then saved = time.factor() end
    native.SetTimeSpeedFactor(0)
end

-- resume(): вернуть скорость до pause (или 1). Сторона: только server/shared. Ошибки: на client; вне партии.
function time.resume()
    needServer("resume")
    native.SetTimeSpeedFactor(saved or 1)
    saved = nil
end
