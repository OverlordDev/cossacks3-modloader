-- profiler — замер Lua-кода модов: вызовы exec/get, время, память.
--
-- Работает везде (меряет свою сторону). start() оборачивает game.exec,
-- state.get/read/list и считает вызовы+время; stop() снимает обёртки.
--
--   profiler.start()
--   -- ... игра / способности / ИИ ...
--   log.info(profiler.report())
--   profiler.stop()
--
-- Отчёт: число вызовов, суммарное и среднее время, память Lua (collectgarbage).
-- Обработчики событий меряйте вручную: profiler.time("ai", fn) оборачивает функцию.

profiler = {}

local data = {}
local orig = {}
local on = false

local function timed(key, fn, ...)
    local t0 = os.clock()
    local r = { pcall(fn, ...) }
    local dt = os.clock() - t0
    local d = data[key] or { n = 0, total = 0 }
    d.n, d.total = d.n + 1, d.total + dt
    data[key] = d
    if not r[1] then error(r[2], 3) end
    return select(2, table.unpack(r))
end

-- Обернуть функцию замером под именем (для своих колбэков).
function profiler.time(name, fn)
    if type(fn) ~= "function" then error("profiler.time: fn must be a function", 2) end
    return function(...)
        return timed(tostring(name), fn, ...)
    end
end

-- profiler.start(): обернуть game.exec и state.get/read/list в замеры. Ничего не возвращает. Сторона: везде.
function profiler.start()
    if on then return end
    on = true
    orig.exec = game.exec
    if orig.exec then
        game.exec = function(code, arg) return timed("game.exec", orig.exec, code, arg) end
    end
    for _, k in ipairs({ "get", "read", "list" }) do
        if state and state[k] then
            orig[k] = state[k]
            local f, name = orig[k], "state." .. k
            state[k] = function(...) return timed(name, f, ...) end
        end
    end
end

-- profiler.stop(): снять обёртки с game.exec/state (вернуть оригиналы). Ничего не возвращает.
function profiler.stop()
    if not on then return end
    on = false
    if orig.exec then game.exec = orig.exec end
    for _, k in ipairs({ "get", "read", "list" }) do
        if orig[k] then state[k] = orig[k] end
    end
    orig = {}
end

-- profiler.reset(): очистить собранную статистику. Ничего не возвращает.
function profiler.reset()
    data = {}
end

-- profiler.report(): текст отчёта (вызовы, суммарное/среднее время, память Lua). Возвращает строку.
function profiler.report()
    local out = { string.format("profiler: lua %.1f KB", collectgarbage("count")) }
    local keys = {}
    for k in pairs(data) do keys[#keys + 1] = k end
    table.sort(keys)
    for _, k in ipairs(keys) do
        local d = data[k]
        out[#out + 1] = string.format("  %s: %d x %.3f s (avg %.4f)", k, d.n, d.total,
            d.n > 0 and d.total / d.n or 0)
    end
    if #keys == 0 then out[#out + 1] = "  (no calls yet — start() first)" end
    return table.concat(out, "\n")
end
