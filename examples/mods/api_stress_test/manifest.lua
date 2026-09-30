-- Стенд для жёсткого тестирования API модлоадера 0.2.0.
--
-- Ничего не делает сам: ни одного события, меняющего мир, пока не нажмёшь кнопку
-- или клавишу. Все проверки собраны в кейсы (harness.case), каждый кейс выполняется
-- под pcall, пишет PASS/FAIL/SKIP в отчёт и в лог. Опасные кейсы (terrain.*,
-- world.destroy, tracks.breakFar, weapon.fire по своим) помечены risky и требуют
-- явного подтверждения.
--
-- Клавиши: F5 — панель, F6 — раздел (безопасные), F7 — все безопасные,
-- F8 — опасные кейсы раздела, F10 — отчёт, F11 — полная очистка,
-- Ctrl+F7 — всё включая опасное, Ctrl+F10 — подробный отчёт в лог.
--
-- multiplayer = "required": есть shared-часть, меняющая мир, — в сети мод должен
-- стоять у всех (ModCheck проверяет отпечатки). Это нужно и для проверки
-- netrec/десинка на двух машинах. В одиночке ограничений нет.
return {
    id = "api_stress_test",
    name = "API Stress Test 0.2.0",
    version = "0.2.0",
    author = "Illia / opencode",
    description = "Стенд для проверки непроверенного API: world/terrain/fow/orders/group/" ..
        "status/scenario/economy/tracks/regions/behaviour/gui/panel/sound/netrec и чистых " ..
        "библиотек. Кейсы под pcall, отчёт в лог и в CEF-страницу, полная очистка F11.",

    enabled = true,

    -- shared меняет мир (спавн, рельеф, приказы) — обязательно одинаково у всех машин.
    shared = "shared.lua",
    -- client: интерфейс стенда, клавиши, проверки картинки и звука.
    client = "client.lua",

    files = {
        "harness.lua",
    },

    multiplayer = "required",
    priority = 100,
}
