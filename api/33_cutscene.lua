-- cutscene — катсцены на треках камеры: переезды, наезды, слежение.
--
-- Только картинка у этого игрока (client). Шаги выполняются по времени в game.tick.
--
--   cutscene.play{
--       { x = 10, z = 20, time = 2 },        -- переехать за 2 с
--       { follow = h, time = 3 },            -- следить за объектом 3 с
--       { x = 80, z = 70, time = 5 },
--   }
--   cutscene.stop()                           -- прервать
--   cutscene.playing()                        --> true/false
--
-- Во время сцены управление камерой у мода; в конце — camera.stop() + follow(nil).
-- Для пропуска по клавише: input.bind("Space", cutscene.stop).

cutscene = {}

local active = nil
local sub = nil

local function num(v, name)
    local n = tonumber(v)
    if not n or n ~= n then error("cutscene: " .. name .. " must be a number", 3) end
    return n
end

local function inGame(where)
    if not game.isInGame() then
        error("cutscene." .. where .. ": no active game (check game.isInGame())", 3)
    end
end

local function finish()
    if sub then events.off(sub) end
    sub, active = nil, nil
    pcall(camera.stop)
    pcall(camera.follow, nil)
end

-- play(steps): запустить катсцену по треку камеры. Параметры: steps — непустой список { x=, z=, speed= | follow=, time= }.
-- Только картинка у этого игрока (client), тикает в game.tick. Ошибки: нет игры, steps пуст/не таблица, шаг без x/z и follow, time не число.
function cutscene.play(steps)
    inGame("play")
    if type(steps) ~= "table" or #steps == 0 then
        error("cutscene.play: pass a non-empty list of steps", 2)
    end
    for i, s in ipairs(steps) do
        if type(s) ~= "table" then error("cutscene.play: step " .. i .. " must be a table", 2) end
        s.time = num(s.time or 3, "step " .. i .. ".time")
        if s.follow == nil and (s.x == nil or s.z == nil) then
            error("cutscene.play: step " .. i .. " needs x/z or follow", 2)
        end
    end
    cutscene.stop()
    active = { steps = steps, i = 1, until_ = os.clock() + steps[1].time }
    local first = steps[1]
    if first.follow ~= nil then camera.follow(first.follow)
    elseif first.x ~= nil then camera.moveTo(first.x, first.z) end
    sub = events.on("game.tick", function()
        if not active or not game.isInGame() then finish() return end
        if os.clock() < active.until_ then return end
        active.i = active.i + 1
        local s = active.steps[active.i]
        if not s then finish() return end
        active.until_ = os.clock() + s.time
        if s.follow ~= nil then camera.follow(s.follow)
        elseif s.x ~= nil then camera.moveTo(s.x, s.z, s.speed) end
    end)
end

-- stop(): прервать сцену (camera.stop + follow(nil)). Без сцены — ничего. Только client, ошибок не кидает.
function cutscene.stop()
    if active then finish() end
end

-- playing(): идёт ли сцена. Возврат: true/false. Только чтение (client), ошибок не кидает.
function cutscene.playing()
    return active ~= nil
end
