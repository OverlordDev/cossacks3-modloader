-- players — участники партии (и слоты лобби до её начала).
--
--   players.list()          --> занятые слоты gMap.players: { index, name, team, color, bai, bhuman, ... }
--   players.me()            --> индекс игрока за этим компьютером (только в партии)
--   players.resources(i)    --> { food, wood, stone, gold, iron, coal } (только в партии)
--
-- Все поля слота — тип TMapPlayer в GAME_STATE.md. Для ресурсов и их изменения есть player(i).
-- Всё чтение — shared (везде); вне партии me() — nil. Своих ошибок не кидает.

players = {}

-- players.list(): занятые слоты (bexists) из gMap.players. Возврат: список записей + поле index (0-based).
-- Сторона: shared (везде). Ошибки: только из state.list при битом пути (своего не кидает).
function players.list()
    local out = {}
    for i, slot in ipairs(state.list("gMap.players")) do
        if slot.bexists then
            slot.index = i - 1
            out[#out + 1] = slot
        end
    end
    return out
end

-- players.me(): индекс игрока за этим компьютером. Возврат: number или nil (вне партии).
-- Сторона: shared (везде; натив Get*). Ошибок не кидает.
function players.me()
    if not game.isInGame() then return nil end
    return native.GetPlayerIndexInterfaceIO()
end

-- players.resources(index): ресурсы игрока таблицей. Парам: index — индекс игрока.
-- Возврат: { food, wood, stone, gold, iron, coal }. Только в партии (вне — нативы падают).
-- Сторона: shared (везде). Ошибок своих не кидает.
function players.resources(index)
    local p = player(index)
    return { food = p.food, wood = p.wood, stone = p.stone, gold = p.gold, iron = p.iron, coal = p.coal }
end
