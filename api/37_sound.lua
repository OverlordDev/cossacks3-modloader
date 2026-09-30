-- sound — звуковые источники: взрывы, сирены, двигатели, атмосфера.
--
-- Только звук у этого игрока (client): на партию не влияет.
-- Источник звука в движке — emittertag (обычно хендл объекта-излучателя),
-- библиотека — имя из data/sounds. Семантика тэгов и имён библиотек проверена
-- частично: подбирайте на копии, слушайте результат.
--
--   local s = sound.get(h, "explosion")   -- создать/найти звук излучателя h
--   sound.play(s)                         -- sound.stop(s), sound.pause(s, true)
--   sound.volume(s, 0.5)                  -- sound.loop(s, true)
--   sound.source(s, "cannon_fire")        -- сменить сэмпл
--   sound.remove(h)                       -- убрать звук излучателя
--
-- owner — владелец (по умолчанию 0). Возвращает id звука для остальных функций.

sound = {}

local function id(v, name)
    v = math.tointeger(tonumber(v))
    if not v then error("sound: " .. (name or "id") .. " must be a number", 3) end
    return v
end

local function num(v, name)
    local n = tonumber(v)
    if not n or n ~= n then error("sound: " .. name .. " must be a number", 3) end
    return n
end

local function inGame(where)
    if not game.isInGame() then
        error("sound." .. where .. ": no active game (check game.isInGame())", 3)
    end
end

-- Найти или создать звук излучателя tag из библиотеки. Возвращает id звука.
function sound.get(tag, library, owner)
    inGame("get")
    if type(library) ~= "string" or library == "" then
        error("sound.get: library must be a non-empty string", 2)
    end
    return native.SndGetOrCreateSound(id(tag, "tag"), library, id(owner or 0, "owner"))
end

-- remove(tag, owner): убрать звук излучателя. Парам: tag, owner (по умолч. 0). Возврат: код движка.
-- Только звук (client), мир не меняет. Ошибки: вне партии; tag/owner не числа.
function sound.remove(tag, owner)
    inGame("remove")
    return native.SndRemoveSound(id(tag, "tag"), id(owner or 0, "owner"))
end

-- play(s): включить воспроизведение. Парам: s — id звука. Возврат: nil. Только client. Ошибки: вне партии; s не число.
function sound.play(s)
    inGame("play")
    native.SetSndSoundPlaying(id(s, "sound"), true)
end

-- stop(s): остановить воспроизведение (Playing=false). Парам: s — id звука. Только client. Ошибки: вне партии; s не число.
function sound.stop(s)
    inGame("stop")
    native.SetSndSoundPlaying(id(s, "sound"), false)
end

-- isPlaying(s): играет ли звук. Парам: s — id звука. Возврат: bool. Только чтение (client). Ошибки: s не число.
function sound.isPlaying(s)
    return native.GetSndSoundPlaying(id(s, "sound"))
end

-- pause(s, v): пауза/анпауза (v по умолч. true). Парам: s — id звука. Только client. Ошибки: вне партии; s не число.
function sound.pause(s, v)
    inGame("pause")
    if v == nil then v = true end
    native.SetSndSoundPause(id(s, "sound"), v and true or false)
end

-- loop(s, v): зацикливание (v по умолч. true). Парам: s — id звука. Только client. Ошибки: вне партии; s не число.
function sound.loop(s, v)
    inGame("loop")
    if v == nil then v = true end
    native.SetSndSoundLoop(id(s, "sound"), v and true or false)
end

-- volume(s, v): громкость; без v — геттер. Парам: s — id звука, v — число. Возврат: геттер — число. Только client.
-- Ошибки: вне партии; s не число; v не число.
function sound.volume(s, v)
    inGame("volume")
    if v == nil then return native.GetSndSoundVolume(id(s, "sound")) end
    native.SetSndSoundVolume(num(v, "volume"), id(s, "sound"))
end

-- source(s, name): сменить сэмпл звука. Парам: s — id звука, name — имя сэмпла. Только client. Ошибки: вне партии; s не число; имя пустое.
function sound.source(s, name)
    inGame("source")
    if type(name) ~= "string" or name == "" then
        error("sound.source: name must be a non-empty string", 2)
    end
    native.SetSndSoundSourceName(name, id(s, "sound"))
end

-- frequency(s, v): частота (целое); без v — геттер. Парам: s — id звука. Возврат: геттер — число. Только client.
-- Ошибки: вне партии; s не число; v не целое.
function sound.frequency(s, v)
    inGame("frequency")
    if v == nil then return native.GetSndSoundFrequency(id(s, "sound")) end
    native.SetSndSoundFrequency(math.tointeger(tonumber(v))
        or error("sound.frequency: must be an integer", 2), id(s, "sound"))
end

-- radius(s, v): радиус слышимости; без v — геттер. Парам: s — id звука, v — число. Возврат: геттер — число. Только client.
-- Ошибки: вне партии; s не число; v не число.
function sound.radius(s, v)
    inGame("radius")
    if v == nil then return native.GetSndSoundRadius(id(s, "sound")) end
    native.SetSndSoundRadius(num(v, "radius"), id(s, "sound"))
end

-- mute(s, v): заглушить/разглушить (v по умолч. true). Парам: s — id звука. Только client. Ошибки: вне партии; s не число.
function sound.mute(s, v)
    inGame("mute")
    if v == nil then v = true end
    native.SetSndSoundMute(v and true or false, id(s, "sound"))
end

-- Удобное: одноразовый звук излучателя (создать, сыграть, вернуть id).
function sound.playAt(tag, library, opts)
    opts = opts or {}
    if type(opts) ~= "table" then error("sound.playAt: opts must be a table", 2) end
    local s = sound.get(tag, library, opts.owner)
    if opts.volume then sound.volume(s, opts.volume) end
    if opts.radius then sound.radius(s, opts.radius) end
    sound.play(s)
    return s
end

-- Удобное: зацикленный звук на объекте (двигатель, сирена). Остановить — sound.stop(s).
function sound.loopOn(tag, library, opts)
    local s = sound.playAt(tag, library, opts)
    sound.loop(s, true)
    return s
end
