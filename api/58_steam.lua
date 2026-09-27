-- steam — Steam Rich Presence локального игрока (client-only).
--
-- На server стороны таблицы steam от C++ нет: здесь лежат заглушки (available=false),
-- чтобы общий код не падал. Статус виден друзьям в Steam; ОТОБРАЖЕНИЕ текста зависит
-- от настройки Rich Presence приложения Cossacks 3 в Steamworks (без неё ключи всё
-- равно пишутся и читаются через GetFriendRichPresence, но клиент может показать
-- только "В игре"). SteamID соперников движок не отдаёт — для текста используйте
-- игровые ники, для playedWith — ручной steam.playedWith(steamId).
--
--   steam.setMatch{ status = "В партии", map = "Полтава", mode = "2v2",
--                   opponents = { "Иван", "Пётр" } }
--   steam.setOpponent("Иван")                 -- steam.clearOpponent()
--   steam.playedWith("76561198000000000")     -- вручную (SteamID из профиля друга)
--   steam.myId()                              --> свой SteamID64 или nil
--
-- Лимиты: ключ ≤64 Б, значение ≤200 Б (режется по границе UTF-8).
-- Не чаще 1 раза в 3 с, одинаковый статус повторно не отправляется.
-- Автостатусы меню/лобби/партии ставит builtin/steam_presence (client).

if steam == nil then
    -- server-сторона: статуса здесь нет (client-only), только понятные заглушки.
    steam = {
        available = function() return false end,
        status = function() return "no_steam" end,
        set = function() return false end,
        clear = function() return false end,
        playedWith = function() return false end,
        myId = function() return nil end,
    }
end

local MAX_KEY, MAX_VAL, MIN_INTERVAL = 64, 200, 3
local lastSent, lastAt = {}, -MIN_INTERVAL

-- Обрезать UTF-8 строку до n байт по границе символа.
local function cut(s, n)
    s = tostring(s or "")
    if #s <= n then return s end
    local i = n
    while i > 0 and s:byte(i) >= 0x80 and s:byte(i) < 0xC0 do i = i - 1 end
    return s:sub(1, i)
end

-- Низкоуровневая отправка с лимитами (без троттлинга — для setMatch).
local function put(key, value)
    key, value = cut(key, MAX_KEY), cut(value or "", MAX_VAL)
    if key == "" then return false end
    return steam.set(key, value)
end

-- Собрать и отправить статус матча. Возвращает true или false, причина.
-- identical → true, "unchanged"; слишком часто → false, "throttled".
function steam.setMatch(t)
    if type(t) ~= "table" then error("steam.setMatch: pass { status=, map=, mode= }", 2) end
    local want = {}
    if t.status ~= nil then want.status = cut(t.status, MAX_VAL) end
    if t.map ~= nil then want.map = cut(t.map, MAX_VAL) end
    if t.mode ~= nil then want.mode = cut(t.mode, MAX_VAL) end
    if t.opponents ~= nil then
        if type(t.opponents) ~= "table" then error("steam.setMatch: opponents must be a list", 2) end
        local names = {}
        for i = 1, math.min(3, #t.opponents) do names[#names + 1] = tostring(t.opponents[i]) end
        want.opponents = cut(table.concat(names, ", "), MAX_VAL)
    end
    if t.opponent ~= nil then want.opponent = cut(t.opponent, MAX_VAL) end
    local same = true
    for k, v in pairs(want) do if lastSent[k] ~= v then same = false break end end
    for k in pairs(lastSent) do if want[k] == nil then same = false break end end
    if same then return true, "unchanged" end
    if os.clock() - lastAt < MIN_INTERVAL then return false, "throttled" end
    lastAt = os.clock()
    lastSent = want
    local okAll = true
    for k, v in pairs(want) do
        if not put(k, v) then okAll = false end
    end
    return okAll
end

-- steam.setOpponent(name): записать ник соперника в статус матча. Парам: name — непустая строка.
-- Возвращает результат setMatch. Сторона: только client. Ошибки: пустое имя.
function steam.setOpponent(name)
    if type(name) ~= "string" or name == "" then
        error("steam.setOpponent: non-empty name required", 2)
    end
    return steam.setMatch({ opponent = name })
end

-- steam.clearOpponent(): стереть ник соперника из статуса (пишет пустой opponent). Возвращает результат steam.set.
function steam.clearOpponent()
    lastSent.opponent = nil
    return put("opponent", "")
end
