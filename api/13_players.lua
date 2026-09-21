-- players — участники партии (и слоты лобби до её начала).
--
--   players.list()          --> занятые слоты gMap.players: { index, name, team, color, bai, bhuman, ... }
--   players.me()            --> индекс игрока за этим компьютером (только в партии)
--   players.resources(i)    --> { food, wood, stone, gold, iron, coal } (только в партии)
--
-- Все поля слота — тип TMapPlayer в GAME_STATE.md. Для ресурсов и их изменения есть player(i).

players = {}

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

function players.me()
    if not game.isInGame() then return nil end
    return native.GetPlayerIndexInterfaceIO()
end

function players.resources(index)
    local p = player(index)
    return { food = p.food, wood = p.wood, stone = p.stone, gold = p.gold, iron = p.iron, coal = p.coal }
end
