-- Союзники в одной деревне + столько шахт рядом, чтобы хватило всей команде.
--
-- Карту генерирует сам движок, влезать в генерацию не нужно: проще поправить результат сразу после
-- того, как партия создана. Событие game.start приходит ровно в этот момент.
--
-- Всё ниже — серверная сторона: оно меняет ход партии, поэтому работает в одиночной игре и у хоста.

local config = {
    -- Собирать союзников в одно место. Команды берутся из лобби (gMap.players[i].team);
    -- игроки без команды (team = 0) остаются там, где их поставил генератор.
    gatherTeams = true,

    -- Сколько шахт каждого вида должно быть рядом с игроком. Уже стоящие рядом считаются,
    -- добавляются только недостающие — карта не превращается в свалку шахт.
    mines = { gold = 3, iron = 2, coal = 2 },

    -- Кольцо вокруг деревни, в которое кладутся шахты.
    radiusMin = 22,
    radiusMax = 48,
}

-- Бейзнеймы шахт (data/scripts/dmscript.global: gc_basename_minegold и соседние).
local BASE = { gold = "eurgol", iron = "euriro", coal = "eurcoa" }

-- Союзники к лидеру команды. Лидер — игрок с наименьшим номером в команде.
-- PlayerMoveToPlayerByHandle переносит всю стартовую деревню игрока к другому.
local function gatherTeams()
    game.exec([[
        var i, j : Integer;
        for i := 0 to gc_MaxPlayerCount-1 do
        if (gMap.players[i].bexists) and (gMap.players[i].team > 0) then
        begin
            var leader : Integer = -1;
            for j := 0 to i-1 do
            if (leader < 0) and (gMap.players[j].bexists) and (gMap.players[j].team = gMap.players[i].team) then
            leader := j;

            if (leader >= 0) then
            begin
                PlayerMoveToPlayerByHandle(GetPlayerHandleByIndex(i), GetPlayerHandleByIndex(leader));
                Log('[team_spawn] player ' + IntToStr(i) + ' moved to ' + IntToStr(leader));
            end;
        end;
    ]])
end

-- Шахты вокруг каждой деревни: считаем, что уже есть, и докладываем недостающие.
-- Считать надо ПОСЛЕ переселения, иначе позиция деревни будет старой.
local function addMines()
    game.exec(([[
        const cRadMin = %d;
        const cRadMax = %d;
        const cNeedGold = %d;
        const cNeedIron = %d;
        const cNeedCoal = %d;

        // Раса шахт в разных сборках лежит по-разному, поэтому пробуем по очереди,
        // пока движок не вернёт хендл.
        function PlaceMine(plHnd : Integer; const bn : String; px, pz : Float) : Integer;
        begin
            Result := 0;
            var t : Integer;
            for t := 0 to 63 do
            begin
                var a : Float = RandomExt * 6.28318;
                var d : Float = cRadMin + RandomExt * (cRadMax - cRadMin);
                var x : Float = px + cos(a) * d;
                var z : Float = pz + sin(a) * d;
                var y : Float = RayCastHeight(x, z);

                Result := CreatePlayerGameObjectHandleByHandle(plHnd, gc_racename_buildings, bn, x, y, z);
                if (Result = 0) then
                Result := CreatePlayerGameObjectHandleByHandle(plHnd, gc_racename_env, bn, x, y, z);
                if (Result = 0) then
                Result := CreatePlayerGameObjectHandleByHandle(plHnd, GetPlayerRaceNameByHandle(plHnd), bn, x, y, z);
                if (Result <> 0) then exit;
            end;
        end;

        var envHnd : Integer = GetPlayerHandleByIndex(gc_playerind_env);
        var i, k : Integer;
        for i := 0 to gc_MaxPlayerCount-1 do
        if (gMap.players[i].bexists) then
        begin
            var h : Integer = GetPlayerHandleByIndex(i);
            var px, pz : Float;
            GetPlayerArmyPositionByHandle(h, 0, False, px, pz);
            if (px = 0) and (pz = 0) then continue; // деревни нет — пропускаем

            // Что уже стоит рядом.
            var have : array [0..2] of Integer;
            have[0] := 0; have[1] := 0; have[2] := 0;
            GetGameObjectsInRadius(px, pz, cRadMax, False, False, 0, -1, 0,
                                   False, False, False, False, False, False);
            for k := GetGameObjectListCount-1 downto 0 do
            begin
                var bn : String = GetGameObjectBaseNameByHandle(GetGameObjectListByIndex(k));
                if (bn = gc_basename_minegold) then have[0] := have[0] + 1
                else if (bn = gc_basename_mineiron) then have[1] := have[1] + 1
                else if (bn = gc_basename_minecoal) then have[2] := have[2] + 1;
            end;

            var need : array [0..2] of Integer;
            need[0] := cNeedGold - have[0];
            need[1] := cNeedIron - have[1];
            need[2] := cNeedCoal - have[2];

            var added : Integer = 0;
            for k := 0 to 2 do
            begin
                var bn : String;
                case k of
                    0 : bn := gc_basename_minegold;
                    1 : bn := gc_basename_mineiron;
                    2 : bn := gc_basename_minecoal;
                end;
                var n : Integer;
                for n := 1 to need[k] do
                if (PlaceMine(envHnd, bn, px, pz) <> 0) then added := added + 1;
            end;

            Log('[team_spawn] player ' + IntToStr(i) + ': mines ' +
                IntToStr(have[0]) + '/' + IntToStr(have[1]) + '/' + IntToStr(have[2]) +
                ' + ' + IntToStr(added) + ' added');
        end;
    ]]):format(config.radiusMin, config.radiusMax,
               config.mines.gold, config.mines.iron, config.mines.coal))
end

events.on("game.start", function()
    if config.gatherTeams then
        gatherTeams()
        log.info("союзники собраны по командам")
    end
    addMines()
    log.info(("шахты: золото %d, железо %d, уголь %d у каждого игрока")
        :format(config.mines.gold, config.mines.iron, config.mines.coal))
end)
