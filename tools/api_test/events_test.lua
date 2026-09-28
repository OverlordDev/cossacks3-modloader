-- Стенд каталога событий (api/59_events.lua): eventKnown должна отличать
-- настоящее имя от выдуманного и подсказывать ближайшее при опечатке.
--
-- Запуск: lua.exe events_test.lua <корень репозитория>
local root = arg[1] or "../.."
local chunk = assert(loadfile(root .. "/api/59_events.lua"))
chunk()

local failed = 0
local function check(cond, what)
    if not cond then
        failed = failed + 1
        print("ПРОВАЛ: " .. what)
    end
end

-- Настоящие имена.
for _, name in ipairs({ "game.start", "game.tick", "unit.death", "building.spawn",
                        "unit.damage", "player.order", "save.afterload", "net.sync" }) do
    check(eventKnown(name), name .. " должно быть известно")
end

-- Имена с переменной частью и подписка на всё.
for _, name in ipairs({ "gui.DoCreate", "gui.DoProgress.end",
                        "guiscreen.MainMenu", "guistate.SomeState", "*" }) do
    check(eventKnown(name), name .. " должно проходить по образцу")
end

-- Опечатки: не известно, и названо ближайшее имя.
for wrong, right in pairs({ ["game.tik"] = "game.tick",
                            ["unit.spwan"] = "unit.spawn",
                            ["player.orders"] = "player.order",
                            ["building.spwan"] = "building.spawn" }) do
    local known, hint = eventKnown(wrong)
    check(not known, wrong .. " не должно считаться известным")
    check(hint == "did you mean '" .. right .. "'?",
          wrong .. ": ждали подсказку про " .. right .. ", получили " .. tostring(hint))
end

-- Не опечатка, а другое слово в знакомой группе: показываем всю группу.
-- "dies" и "death" расходятся на столько же букв, сколько "dies" и "order",
-- поэтому подсказывать одно конкретное имя здесь нельзя.
local known, hint = eventKnown("unit.dies")
check(not known, "unit.dies не должно считаться известным")
check(hint == "'unit.' has: damage, death, destroy, order, spawn",
      "unit.dies: ждали список группы, получили " .. tostring(hint))

-- Незнакомая группа: сказать нечего.
local known2, hint2 = eventKnown("weather.rain")
check(not known2, "weather.rain не должно считаться известным")
check(hint2 == nil, "weather.rain: подсказки быть не должно, получили " .. tostring(hint2))

-- Совсем другое слово без точки: тоже нечего подсказать.
for _, name in ipairs({ "somethingEntirelyDifferent", "hello" }) do
    local k, h = eventKnown(name)
    check(not k, name .. " не должно считаться известным")
    check(h == nil, name .. ": подсказка не нужна, получили " .. tostring(h))
end

-- Мусор вместо имени не должен ронять проверку.
for _, v in ipairs({ 5, true, {} }) do
    check(not eventKnown(v), "мусор не известен")
end
check(not eventKnown(nil), "nil не известен")
check(not eventKnown(""), "пустая строка не известна")

if failed > 0 then
    print(failed .. " проверок провалено")
    os.exit(1)
end
print("каталог событий: все проверки прошли")
