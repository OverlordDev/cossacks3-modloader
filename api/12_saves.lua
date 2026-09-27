-- saves — сохранения и повторы, те же нативы, что у экрана «Загрузить игру».
--
--   saves.list()            --> { { name = "autosave", date = "20.09.26 12:40" }, ... }
--   saves.load("autosave")  -- начать загрузку (дальше игра грузит карту сама)
--   saves.delete("old")
--   saves.replays.list()
--   saves.replays.load(name)
--
-- Списки (list) — shared (везде); load/delete — server/shared/страница
-- (меняют состояние игры; с client — только через страницу game.api).

saves = { replays = {} }

-- list(count, byIndex, date): общий обход нативов UserGetProfile*Count/ByIndex/DateByIndex.
-- Парам: имена трёх нативов. Возврат: { { name, date }, ... }. Сторона: shared. Ошибок не кидает.
local function list(count, byIndex, date)
    local out = {}
    for i = 0, native[count]() - 1 do
        out[#out + 1] = { name = native[byIndex](i), date = native[date](i) }
    end
    return out
end

-- saves.list(): все сохранения профиля. Возврат: { { name, date }, ... }.
-- Сторона: shared (везде). Ошибок не кидает (пусто — {}).
function saves.list()
    return list("UserGetProfileSavesCount", "UserGetProfileSaveByIndex", "UserGetProfileSaveDateByIndex")
end

-- saves.load(name): начать загрузку сейва (дальше карта грузится сама). Парам: name — имя сейва.
-- Сторона: server/shared/страница. Ошибок своих не кидает (неизвестное имя игнорирует игра).
function saves.load(name) native.UserProfileLoadMap(name) end
-- saves.delete(name): удалить сейв. Парам: name — имя. Сторона: server/shared/страница. Ошибок не кидает.
function saves.delete(name) native.UserProfileDeleteMap(name) end

-- saves.replays.list(): все повторы. Возврат: { { name, date }, ... }. Сторона: shared (везде).
function saves.replays.list()
    return list("UserGetProfileReplaysCount", "UserGetProfileReplayByIndex", "UserGetProfileReplayDateByIndex")
end

-- saves.replays.load(name): загрузить повтор. Парам: name — имя. Сторона: server/shared/страница.
function saves.replays.load(name) native.UserProfileLoadReplay(name) end
