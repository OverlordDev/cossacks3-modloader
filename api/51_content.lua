-- content — проверка окружения перед партией: моды, версии, разрешения.
--
-- Работает везде (mods.list доступен всем сторонам). Для кампаний и паков:
-- проверить, что нужные моды стоят в нужных версиях, иначе — понятная ошибка
-- вместо загадочного вылета или рассинхрона.
--
--   local ok, report = content.check({ mods = { my_pack = "1.2.0", weapons = "0.9" } })
--   if not ok then log.error(report) end
--   content.require({ mods = { my_pack = "1.2.0" } })   -- или ошибка Lua сразу
--
-- Версии сравниваются как строки (точное совпадение). Разрешения мода —
-- mods.list()[i].permissions (из manifest.lua: permissions = { world_spawn = true }).

content = {}

-- Проверить требования к окружению: { mods = { id = "version", ... } }.
-- Возвращает ok, report (текст со списком проблем). Сторона: везде (client/server/shared).
-- Ошибки: req не таблица.
function content.check(req)
    if type(req) ~= "table" then error("content.check: pass { mods = {...} }", 2) end
    local want = req.mods or {}
    local have = {}
    for _, m in ipairs(mods.list()) do have[m.id] = m end
    local problems = {}
    for id, ver in pairs(want) do
        local m = have[id]
        if not m then
            problems[#problems + 1] = "нет мода '" .. id .. "' (нужен " .. tostring(ver) .. ")"
        elseif tostring(m.version) ~= tostring(ver) then
            problems[#problems + 1] = "мод '" .. id .. "': стоит " .. tostring(m.version) ..
                                      ", нужен " .. tostring(ver)
        end
    end
    if #problems == 0 then return true, "все моды на месте" end
    return false, "content.check:\n  " .. table.concat(problems, "\n  ")
end

-- То же, что check, но кидает ошибку с report вместо возврата false (удобно в game.start).
-- Парам: req — как в check. Возвращает true. Сторона: везде. Ошибки: требования не выполнены; req не таблица.
function content.require(req)
    local ok, report = content.check(req)
    if not ok then error(report, 2) end
    return true
end

-- Разрешения мода из manifest (permissions = { ... }) для меню/проверок.
-- Парам: id — строка. Возвращает таблицу разрешений или nil (нет мода). Сторона: везде. Ошибок не кидает.
function content.permissions(id)
    for _, m in ipairs(mods.list()) do
        if m.id == id then return m.permissions or {} end
    end
    return nil
end
