-- map — текущая карта и настройки партии.
--
--   map.info()        --> { name, gamestage, brating, bbattle, ... }
--   map.settings()    --> { gen = { mapsize, season, ... }, additional = { peacetime, teams, ... } }
--
-- Настройки генерации удобнее менять через world{ ... } (см. справку по world):
-- там понятные имена и запись в правильный момент (game.prepare).

map = {}

function map.info() return state.read("gMap") end
function map.settings() return state.read("gMap.settings", 2) end
