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

    -- Собрать ВСЕХ в одно место, не глядя на команды. В обычной схватке с ботами команд нет
    -- (у всех team = 0), и проверять нечего — вот для таких партий и для показа.
    gatherEveryone = false,

    -- Сколько жил каждого вида должно быть рядом с игроком (шахту на них строит уже игрок).
    -- Уже стоящие рядом считаются, добавляются только недостающие.
    mines = { gold = 3, iron = 2, coal = 2 },

    -- На каком расстоянии от лидера встают деревни союзников.
    spacing = 30,

    -- Кольцо вокруг деревни, в которое кладутся шахты.
    radiusMin = 22,
    radiusMax = 48,
}

-- Ставим ЖИЛУ, а не здание шахты. Жила — объект расы env: minegold / mineiron / minecoal
-- (data/objects/env/*.prop, CategorieName = resources). Её состояние Initial само назначает тип
-- ресурса и ставит её в ресурсную сетку (data/scripts/env/env.inc/initial.inc), поэтому достаточно
-- создать объект. Крупные варианты — с 's' на конце: minegolds / mineirons / minecoals.
-- А gc_basename_minegold ('eurgol') — это ЗДАНИЕ шахты, которое игрок строит поверх жилы.

-- Где стоит деревня игрока — это gMap.players[i].startx/starty, те же координаты, что у объектов.
-- Натив GetPlayerArmyPositionByHandle не годится: игра им нигде не пользуется и он отдаёт нули.
--
-- Союзники к лидеру команды. Лидер — игрок с наименьшим номером в команде.
--
-- ВАЖНО: PlayerMoveToPlayerByHandle для этого не годится, хотя по имени и похоже. Он передаёт всё
-- имущество одного игрока другому (проверено по дизассемблеру: перебирает объекты и меняет владельца),
-- из-за чего бот считается погибшим, а его селяне оказываются чужими. Переносим честно: сдвигаем
-- каждый объект игрока на разницу между его деревней и местом рядом с лидером.
local function gatherTeams()
    game.exec(([[
        const cSpacing = %d;
        const cEveryone = %s;

        var placed : array [0..15] of Integer;
        var t : Integer;
        for t := 0 to 15 do placed[t] := 0;

        var i, j, moved, skipped : Integer;
        moved := 0;
        skipped := 0;
        for i := 0 to gc_MaxPlayerCount-1 do
        if (gMap.players[i].bexists) then
        begin
            var team : Integer = gMap.players[i].team;
            if (not cEveryone) and (team <= 0) then
            begin
                skipped := skipped + 1;
                continue;
            end;
            if (cEveryone) then team := 1;
            if (team > 15) then continue;

            var leader : Integer = -1;
            for j := 0 to i-1 do
            if (leader < 0) and (gMap.players[j].bexists) then
            begin
                if (cEveryone) or (gMap.players[j].team = gMap.players[i].team) then
                leader := j;
            end;
            if (leader < 0) then continue; // сам лидер — остаётся на месте

            placed[team] := placed[team] + 1;

            // Деревни союзников ставим по кругу вокруг лидера, чтобы не налезали друг на друга.
            var a : Float = placed[team] * 2.0944;
            var tx : Float = gMap.players[leader].startx + cos(a) * cSpacing;
            var tz : Float = gMap.players[leader].starty + sin(a) * cSpacing;
            var dx : Float = tx - gMap.players[i].startx;
            var dz : Float = tz - gMap.players[i].starty;

            var h : Integer = GetPlayerHandleByIndex(i);
            var count : Integer = 0;
            for j := GetPlayerGameObjectsCountByHandle(h)-1 downto 0 do
            begin
                var g : Integer = GetGameObjectHandleByIndex(j, h);
                var x : Float = GetGameObjectPositionXByHandle(g) + dx;
                var z : Float = GetGameObjectPositionZByHandle(g) + dz;
                SetGameObjectPositionByHandle(g, x, RayCastHeight(x, z), z);
                count := count + 1;
            end;

            // Чтобы остальная игра тоже считала, что деревня теперь здесь.
            gMap.players[i].startx := tx;
            gMap.players[i].starty := tz;
            moved := moved + 1;

            Log('[team_spawn] player ' + IntToStr(i) + ' -> near player ' + IntToStr(leader) +
                ' (' + IntToStr(count) + ' objects)');
        end;
        Log('[team_spawn] gathered ' + IntToStr(moved) + ' player(s), ' +
            IntToStr(skipped) + ' without a team');
    ]]):format(config.spacing, config.gatherEveryone and "True" or "False"))
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

        // Жилы принадлежат игроку окружения и живут в расе env.
        function PlaceVein(plHnd : Integer; const bn : String; px, pz : Float) : Integer;
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

                Result := CreatePlayerGameObjectHandleByHandle(plHnd, gc_racename_env, bn, x, y, z);
                if (Result <> 0) then exit;
            end;
        end;

        var envHnd : Integer = GetPlayerHandleByIndex(gc_playerind_env);
        var i, k : Integer;
        for i := 0 to gc_MaxPlayerCount-1 do
        if (gMap.players[i].bexists) then
        begin
            var px : Float = gMap.players[i].startx;
            var pz : Float = gMap.players[i].starty;

            // Что уже стоит рядом.
            var have : array [0..2] of Integer;
            have[0] := 0; have[1] := 0; have[2] := 0;
            GetGameObjectsInRadius(px, pz, cRadMax, False, False, 0, -1, 0,
                                   False, False, False, False, False, False);
            for k := GetGameObjectListCount-1 downto 0 do
            begin
                var bn : String = GetGameObjectBaseNameByHandle(GetGameObjectListByIndex(k));
                if (bn = 'minegold') or (bn = 'minegolds') then have[0] := have[0] + 1
                else if (bn = 'mineiron') or (bn = 'mineirons') then have[1] := have[1] + 1
                else if (bn = 'minecoal') or (bn = 'minecoals') then have[2] := have[2] + 1;
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
                    0 : bn := 'minegold';
                    1 : bn := 'mineiron';
                    2 : bn := 'minecoal';
                end;
                var n : Integer;
                for n := 1 to need[k] do
                if (PlaceVein(envHnd, bn, px, pz) <> 0) then added := added + 1;
            end;

            Log('[team_spawn] player ' + IntToStr(i) +
                ' at ' + IntToStr(round(px)) + ',' + IntToStr(round(pz)) + ': veins ' +
                IntToStr(have[0]) + '/' + IntToStr(have[1]) + '/' + IntToStr(have[2]) +
                ' + ' + IntToStr(added) + ' added');
        end;
    ]]):format(config.radiusMin, config.radiusMax,
               config.mines.gold, config.mines.iron, config.mines.coal))
end

events.on("game.start", function()
    if config.gatherTeams or config.gatherEveryone then
        gatherTeams()
    end
    addMines()
end)
