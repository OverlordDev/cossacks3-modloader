-- saves — сохранения и повторы, те же нативы, что у экрана «Загрузить игру».
--
--   saves.list()            --> { { name = "autosave", date = "20.09.26 12:40" }, ... }
--   saves.load("autosave")  -- начать загрузку (дальше игра грузит карту сама)
--   saves.delete("old")
--   saves.replays.list()
--   saves.replays.load(name)

saves = { replays = {} }

local function list(count, byIndex, date)
    local out = {}
    for i = 0, native[count]() - 1 do
        out[#out + 1] = { name = native[byIndex](i), date = native[date](i) }
    end
    return out
end

function saves.list()
    return list("UserGetProfileSavesCount", "UserGetProfileSaveByIndex", "UserGetProfileSaveDateByIndex")
end

function saves.load(name) native.UserProfileLoadMap(name) end
function saves.delete(name) native.UserProfileDeleteMap(name) end

function saves.replays.list()
    return list("UserGetProfileReplaysCount", "UserGetProfileReplayByIndex", "UserGetProfileReplayDateByIndex")
end

function saves.replays.load(name) native.UserProfileLoadReplay(name) end
