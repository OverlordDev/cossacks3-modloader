-- Баланс юнитов: статы применяются сами при каждом входе в партию — новой, загруженной из
-- сохранения, после перезахода. Правьте таблицу ниже и перезагрузите моды (.lua reload).
--
-- Имена типов — как в логе событий (musketeer18) или списком: =balance.types() в консоли.
-- Все поля типа: =balance.dump("musketeer18")
--
--   hp     = максимальное здоровье (живым пересчитывается пропорционально)
--   damage = урон всех видов оружия; или таблица по номеру оружия: { [1] = 300 } (у мушкетёра 0 — штык, 1 — выстрел)
--   speed  = множитель скорости: 1 — как в игре, 2 — вдвое быстрее, 0.5 — вдвое медленнее
--
-- Мод shared: server.lua выполняется на всех машинах, у всех игроков статы одинаковые — без рассинхрона.

local BALANCE = {
    musketeer18 = { hp = 2000, damage = { [1] = 300 }, speed = 3 },
}

-- Лог всех событий объектов: появление, гибель, удаление юнитов и зданий.
-- false — выключить (строк много: на выходе из партии игра «убивает» всех разом).
local LOG_UNITS = true

if LOG_UNITS then
    local TEXT = { spawn = "появился", death = "погиб", destroy = "удалён" }
    for _, kind in ipairs({ "unit", "building" }) do
        for event, text in pairs(TEXT) do
            events.on(kind .. "." .. event, function(_, handle, basename)
                log.info(string.format("%s %s %s #%d", kind == "unit" and "юнит" or "здание", text, basename, handle))
            end)
        end
    end
end
