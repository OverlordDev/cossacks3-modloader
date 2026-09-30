-- map — текущая карта и настройки партии.
--
--   map.info()        --> { name, gamestage, brating, bbattle, ... } (весь gMap, тип TMap)
--   map.settings()    --> { gen = { mapsize, season, ... }, additional = { peacetime, teams, ... } }
--
-- Настройки генерации удобнее менять через world{ ... } (см. справку по world):
-- там понятные имена и запись в правильный момент (game.prepare).
-- Чтение — shared (везде: client/server/shared/страница); записи здесь нет. Ошибок своих не кидает.

map = {}

-- map.info(): весь gMap таблицей (поля — TMap в GAME_STATE.md). Возврат: таблица. Сторона: shared.
function map.info() return state.read("gMap") end
-- map.settings(): настройки партии (gen + additional, глубина 2). Возврат: таблица. Сторона: shared.
function map.settings() return state.read("gMap.settings", 2) end
