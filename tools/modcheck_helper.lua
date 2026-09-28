-- Вспомогательный кусок modcheck.py, который должен выполняться настоящим Lua.
--
-- ЗАЧЕМ ОТДЕЛЬНО. Две вещи нельзя честно сделать регулярками: прочитать
-- manifest.lua (это код, а не данные — там бывают конкатенации и условия) и
-- проверить синтаксис файла мода. А проверку имени события незачем писать второй
-- раз на Python: eventKnown уже живёт в api/59_events.lua, и две реализации
-- разошлись бы.
--
--   lua.exe modcheck_helper.lua <корень> syntax  <файл.lua>
--   lua.exe modcheck_helper.lua <корень> manifest <файл.lua>
--   lua.exe modcheck_helper.lua <корень> event   <имя события> [ещё имена...]
--
-- Печатает строки вида "ключ<таб>значение"; ошибки — "error<таб>текст".
local root, mode, arg3 = arg[1], arg[2], arg[3]

local function out(k, v) print(k .. "\t" .. tostring(v)) end

if mode == "syntax" then
    local chunk, err = loadfile(arg3)
    if not chunk then out("error", err) else out("ok", 1) end

elseif mode == "manifest" then
    -- Манифест исполняется в пустом окружении — ровно как в модлоадере
    -- (LoadChunk с emptyEnv): манифест, которому нужны game или native, там
    -- всё равно упадёт, и лучше узнать об этом здесь.
    local chunk, err = loadfile(arg3, "t", {})
    if not chunk then out("error", err) return end
    local ok, t = pcall(chunk)
    if not ok then out("error", t) return end
    if type(t) ~= "table" then out("error", "manifest.lua must return a table") return end
    for _, key in ipairs({ "id", "name", "version", "author", "description",
                           "client", "server", "shared", "entry", "multiplayer" }) do
        if type(t[key]) == "string" then out(key, t[key])
        elseif t[key] ~= nil then out("badtype", key .. " must be a string") end
    end
    if t.priority ~= nil then
        if math.type(t.priority) == "integer" then out("priority", t.priority)
        else out("badtype", "priority must be a whole number") end
    end
    if t.enabled ~= nil then out("enabled", t.enabled and 1 or 0) end
    if t.files ~= nil then
        if type(t.files) ~= "table" then out("badtype", "files must be a list of strings") end
        for _, f in ipairs(t.files or {}) do out("file", f) end
    end
    if t.requires ~= nil then
        if type(t.requires) == "string" then out("requires", t.requires)
        elseif type(t.requires) == "table" then
            for _, d in ipairs(t.requires) do out("requires", d) end
        else out("badtype", "requires must be a string or a list of strings") end
    end
    if t.permissions ~= nil then
        if type(t.permissions) ~= "table" then out("badtype", "permissions must be a table")
        else for k, v in pairs(t.permissions) do out("permission", tostring(k) .. "=" .. tostring(v)) end end
    end

elseif mode == "event" then
    -- Имён может быть много; запускать lua.exe на каждое — расточительно.
    assert(loadfile(root .. "/api/59_events.lua"))()
    for i = 3, #arg do
        local known, hint = eventKnown(arg[i])
        out(known and "known" or "unknown", arg[i] .. "	" .. (hint or ""))
    end

else
    out("error", "unknown mode " .. tostring(mode))
    os.exit(2)
end
