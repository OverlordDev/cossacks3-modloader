-- EVENT_CATALOG — какие события бывают, что приходит в обработчик и что можно отменить.
--
-- ЗАЧЕМ ЭТО ОТДЕЛЬНЫМ ФАЙЛОМ. events.on принимает ЛЮБУЮ строку: подписка на
-- "unit.dies" вместо "unit.death" проходит молча, обработчик просто никогда не
-- вызывается, и мод выглядит "написанным, но не работающим". Именно так теряется
-- больше всего времени при разработке мода. Со списком модлоадер может сказать
-- об опечатке сразу — см. проверку в l_eventsOn (core/LuaHost.cpp).
--
-- Поля записи:
--   args   — что приходит в обработчик ПОСЛЕ имени события: function(event, ...)
--   block  — обработчик может вернуть true и отменить действие игры
--   about  — когда приходит
--
-- Источник правды — код, а не этот файл: tools/check_events.py сверяет каталог с
-- местами, где события рождаются (core/*.cpp), и ругается на расхождение в любую
-- сторону. Добавили событие в C++ — добавьте строку сюда, иначе тест упадёт.

EVENT_CATALOG = {
  -- ─── Партия ───────────────────────────────────────────────────────────────
  ["game.prepare"] = { args = {}, about = "новая партия создаётся: карта ещё не готова, мир трогать рано" },
  ["game.start"]   = { args = {}, about = "партия началась и интерфейс готов — обычная точка входа мода" },
  ["game.menu"]    = { args = {}, about = "вошли в главное меню" },
  ["game.end"]     = { args = {}, about = "партия закончилась; хендлы и состояния движка после этого недействительны" },
  ["game.tick"]    = { args = {}, about = "такт игры (DoProgress). Идёт десятки раз в секунду — тяжёлое сюда не кладут" },

  -- ─── Сейвы ────────────────────────────────────────────────────────────────
  ["save.loaded"]    = { args = {}, about = "модлоадер прочитал сохранённые данные модов (savedata)" },
  ["save.afterload"] = { args = {}, about = "игра догрузила сейв: переменные скриптов уже на месте" },

  -- ─── Сеть ─────────────────────────────────────────────────────────────────
  ["net.sync"]       = { args = {}, about = "шаг синхронизации lockstep — один и тот же момент у всех машин" },
  ["net.msg"]        = { args = { "payload" }, about = "пришло сетевое сообщение" },
  ["net.connect"]    = { args = { "payload" }, about = "игрок подключился к комнате" },
  ["net.disconnect"] = { args = { "payload" }, about = "игрок отключился" },

  -- ─── Жизнь объектов ───────────────────────────────────────────────────────
  -- handle — хендл объекта, base — его basename ("musketeer18", "barrack").
  ["unit.spawn"]       = { args = { "handle", "base" }, about = "юнит появился" },
  ["unit.death"]       = { args = { "handle", "base" }, about = "юнит умер (анимация смерти началась)" },
  ["unit.destroy"]     = { args = { "handle", "base" }, about = "юнит убран из мира — хендл больше не живой" },
  ["building.spawn"]   = { args = { "handle", "base" }, about = "здание построено/появилось" },
  ["building.death"]   = { args = { "handle", "base" }, about = "здание разрушено" },
  ["building.destroy"] = { args = { "handle", "base" }, about = "здание убрано из мира" },

  -- ─── Бой и приказы ────────────────────────────────────────────────────────
  ["unit.damage"] = { args = { "attacker", "target", "damage" },
                      about = "нанесён урон; attacker/target — хендлы, damage — число" },
  -- type приходит СТРОКОЙ: move, attackobj, gainres, produce, patrol, attackpoint,
  -- continueattackpoint, performupgrade, fishing, creategates, buildwallcontinue,
  -- buildwall, gotomine, gototransport, leavetransport, leavebuilding, build,
  -- guard, repair, exitunits, none. Неизвестный код придёт числом.
  ["unit.order"]   = { args = { "handle", "type", "target", "x", "z" }, block = true,
                       about = "приказ ЛЮБОМУ юниту — от игрока, ИИ или по сети; true отменяет приказ" },
  -- order = { kind, target, x, z, group }; kind: attack, attackpoint, guard,
  -- build, enter, move, gather, patrol.
  ["player.order"] = { args = { "order" }, block = true,
                       about = "приказ, отданный живым игроком мышью; true отменяет приказ" },

  -- ─── Интерфейс ────────────────────────────────────────────────────────────
  ["ui.press"] = { args = { "payload" }, about = "нажата кнопка интерфейса (внутреннее; модам — screens/panel)" },
}

-- Событий с переменной частью имени в таблице нет — их проверяют по образцу.
-- gui.<State> и gui.<State>.end — вход в состояние GUI игры и выход из него;
-- guiscreen.<State> (блокируемое) и guistate.<State> — экраны и состояния,
-- перехваченные через screens. "*" — подписка на всё сразу (для отладки).
EVENT_PATTERNS = { "^gui%.", "^guiscreen%.", "^guistate%." }

-- Имена по алфавиту. Перебор идёт по этому списку, а не по pairs(EVENT_CATALOG):
-- порядок pairs не определён, и при двух одинаково близких именах подсказка
-- получалась бы разной от запуска к запуску.
EVENT_NAMES = {}
for name in pairs(EVENT_CATALOG) do EVENT_NAMES[#EVENT_NAMES + 1] = name end
table.sort(EVENT_NAMES)

-- Известно ли такое имя события.
--
-- Возвращает true, либо false и подсказку — готовую английскую фразу для лога
-- (или nil, если сказать нечего). Подсказок две, и вторая важнее первой:
--
--   опечатка        "unit.spwan"  -> did you mean 'unit.spawn'?
--   не то слово     "unit.dies"   -> 'unit.' has: damage, death, destroy, order, spawn
--
-- Второй случай одной только близостью написания не ловится: "dies" и "death"
-- отличаются на четыре буквы — столько же, сколько "dies" и "order", то есть по
-- написанию выбор был бы случайным. Зато человек, промахнувшийся мимо имени,
-- почти всегда знает нужную группу событий — её и показываем целиком.
function eventKnown(name)
    if type(name) ~= "string" or name == "" then return false, nil end
    if name == "*" or EVENT_CATALOG[name] then return true, nil end
    for _, p in ipairs(EVENT_PATTERNS) do
        if string.find(name, p) then return true, nil end
    end

    -- Опечатка: правка на букву-две в имени такой длины. Порог намеренно тесный,
    -- иначе подсказка уводит в сторону сильнее, чем её отсутствие.
    local best, bestCost = nil, math.huge
    for _, known in ipairs(EVENT_NAMES) do
        local cost = editDistance(name, known)
        if cost < bestCost then best, bestCost = known, cost end
    end
    if bestCost <= math.max(1, math.floor(#name / 5)) then
        return false, "did you mean '" .. best .. "'?"
    end

    -- Не то слово, но группа знакомая.
    local dot = string.find(name, "%.")
    if dot then
        local prefix = string.sub(name, 1, dot)
        local tails = {}
        for _, known in ipairs(EVENT_NAMES) do
            if string.sub(known, 1, #prefix) == prefix then
                tails[#tails + 1] = string.sub(known, #prefix + 1)
            end
        end
        if #tails > 0 then
            table.sort(tails)
            return false, "'" .. prefix .. "' has: " .. table.concat(tails, ", ")
        end
    end
    return false, nil
end

-- Расстояние Левенштейна. Отдельной функцией, потому что тем же способом ищется
-- ближайшее имя и для функций api (tools/modcheck.py делает это же статически).
function editDistance(a, b)
    if a == b then return 0 end
    local la, lb = #a, #b
    if la == 0 then return lb end
    if lb == 0 then return la end
    local prev, cur = {}, {}
    for j = 0, lb do prev[j] = j end
    for i = 1, la do
        cur[0] = i
        local ca = string.byte(a, i)
        for j = 1, lb do
            local cost = (ca == string.byte(b, j)) and 0 or 1
            local m = prev[j] + 1
            if cur[j - 1] + 1 < m then m = cur[j - 1] + 1 end
            if prev[j - 1] + cost < m then m = prev[j - 1] + cost end
            cur[j] = m
        end
        prev, cur = cur, prev
    end
    return prev[lb]
end
