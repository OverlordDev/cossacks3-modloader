-- Выполняется у ВСЕХ игроков одинаково (shared): время улучшений — часть правил партии.
-- Статы и улучшения игра заполняет в начале партии, поэтому правим их в game.start.
events.on("game.start", function()
    game.exec([[
var c, i : Integer;
for c := 0 to gc_MaxCountryCount-1 do
begin
   for i := 0 to 319 do
   begin
      if gCountry[c].upgrade[i].id <> '' then
      gCountry[c].upgrade[i].time := _misc_FramesToTime(1);
   end;
end;]])
    log.info("instant_upgrades: время всех улучшений — 1 кадр")
end)
