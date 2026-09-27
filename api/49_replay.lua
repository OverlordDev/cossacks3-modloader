-- replay — запись действий для разбора: метки, камера, экспорт.
--
-- Расширение netrec (он пишет шаги/приказы/хеши). replay добавляет именованные
-- метки событий и трек камеры. Работает везде; пишет своё (локально).
-- Честно: playFrom(tick) невозможен — движок не умеет откат симуляции.
--
--   replay.mark("airstrike")                 -- метка на текущем шаге netrec
--   replay.camera(true)                      -- писать позицию камеры каждый sync-шаг
--   replay.export()                          -- весь журнал в лог
--   replay.marks()                           --> { {step=, t=, name=} }

replay = {}

local marks = {}
local camOn = false
local camTrack = {}
local sub = nil

local function step()
    if netrec and netrec.isOn() then return netrec.step() end
    return 0
end

-- Именованная метка (способность, спавн, событие сценария).
function replay.mark(name)
    marks[#marks + 1] = { step = step(), t = os.clock(), name = tostring(name) }
    while #marks > 200 do table.remove(marks, 1) end
end

-- replay.marks(): все метки. Возвращает { {step, t, name}, ... } (живая таблица). Сторона: везде.
function replay.marks()
    return marks
end

-- Вкл/выкл запись камеры (client: где камера; shared: у всех своя).
function replay.camera(on)
    if on == nil then on = true end
    camOn = on and true or false
    if camOn and not sub then
        sub = events.on("net.sync", function()
            local ok, x, y, z = pcall(camera.pos)
            if ok and x then
                camTrack[#camTrack + 1] = { step = step(), x = x, y = y, z = z }
                while #camTrack > 500 do table.remove(camTrack, 1) end
            end
        end)
    elseif not camOn and sub then
        events.off(sub) sub = nil
    end
end

local function say(text)
    local l = rawget(_ENV, "log")
    if l and l.error then l.error(text) return end
    local pr = rawget(_ENV, "print")
    if pr then pr(text) end
end

-- replay.export(): выписать журнал (метки + последние точки камеры + netrec.dump) в лог. Ничего не возвращает.
function replay.export()
    say("replay: marks=" .. #marks .. ", camPoints=" .. #camTrack)
    for _, m in ipairs(marks) do
        say(string.format("  mark@%d %s", m.step, m.name))
    end
    local from = math.max(1, #camTrack - 20)
    for i = from, #camTrack do
        local c = camTrack[i]
        say(string.format("  cam@%d %.1f %.1f %.1f", c.step, c.x, c.y, c.z))
    end
    if netrec then netrec.dump() end
end
