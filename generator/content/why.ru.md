# Почему не `.script`

Моды к Cossacks 3 «из коробки» пишутся на `.script` — Pascal-подобном языке. Ниже — как это выглядит и как то же самое делается через Modloader.

## Как выглядит оригинал

Это кусок настоящего `player.script` из игры: процедура, которая делает двух игроков союзниками. Всего одна из 72 функций в файле на 3 544 строки.

```pascal
procedure _player_MakeAlly(plInd1, plInd2 : Integer);
begin
   if (plInd1 <> plInd2) and (plInd1 >= 0) and (plInd1 < gc_MaxPlayerCount) and (plInd2 >= 0) and (plInd2 < gc_MaxPlayerCount) then
   begin
      var team1 : Integer = gPlayer[plInd1].team;
      var team2 : Integer = gPlayer[plInd2].team;
      if team1 <> team2 then
      begin
         var i : Integer;
         var enMask : Integer;
         for i := 0 to gc_MaxPlayerCount-1 do
         begin
            if (gPlayer[i].team = team1) or (gPlayer[i].team = team2) then
            gPlayer[i].team := team1
            else
            enMask := enMask or (1 shl i);
         end;

         for i := 0 to gc_MaxPlayerCount-1 do
         if gPlayer[i].team = team1 then
         gPlayer[i].enemyPlMask := enMask;

         var pEnemyInfo : Pointer = _misc_GetTeamEnemyInfo(team2);
         if pEnemyInfo <> nil then
         TEnemyInfo(pEnemyInfo).Reset;
```

Что здесь пугает новичка:

- имена вроде `plInd1` и `enMask`, битовые маски (`1 shl i`);
- ручные циклы по слотам игроков и внутренние структуры игры (`TEnemyInfo(pEnemyInfo).Reset`);
- чтобы поправить одну строку, в мод приходится класть копию файла целиком, все 3 544 строки. Такая замена ломается при обновлении игры и конфликтует с другими модами.

*Фрагмент `player.script` принадлежит GSC Game World и приведён как иллюстрация.*

## То же самое у нас

### 1. Поправить одно место в скрипте игры

Патч правит только нужные строки, файл игры не меняется. Это пример «весь урон ×2» из `examples/mods/patch_example`:

```patch
@before _misc_DoDamage
function ML_DamageMultiplier : Integer;
begin
   Result := 2;
end;

@find
            var damage : Integer = indamage;
@with
            var damage : Integer = indamage * ML_DamageMultiplier;
```

Это всё ещё Pascal, но вместо копии на тысячи строк — десяток. Патчи разных модов на один файл накладываются друг на друга.

### 2. Поменять баланс: обычный Lua

Мушкетёрам 200 здоровья, урон 40, подешевле. Никакого Pascal:

```lua
events.on("game.start", function()
    balance.setHP("musketeer18", 200)
    balance.setDamage("musketeer18", 40, 1)     -- оружие 1 — выстрел
    balance.set("musketeer18", "price[3]", 30)  -- цена в золоте
end)
```

Поправил файл и набрал `.lua reload` в консоли модлоадера: результат в игре без перезапуска.

### 3. Сделать интерфейс: HTML вместо скриптов GUI

Интерфейс — обычная веб-страница (CEF). Данные берёт из игры одной строкой:

```html
<div id="box" style="position:absolute;right:16px;bottom:16px;background:rgba(0,0,0,.7);color:#fc6;padding:8px"></div>
<script>
  setInterval(async () => {
    const h = await game.api('buildings.selected');
    document.getElementById('box').textContent = h ? 'Здание #' + h : '';
  }, 500);
</script>
```

Дизайнер, который ни разу не видел `.script`, справится с этим сразу: HTML, CSS, JS. Готовая панель найма и улучшений на такой странице — `examples/mods/hud_example`.

### 4. Свои модели: перетащить `.glb`

Кидаешь `.glb`, модлоадер сам распаковывает его в игру. Для 3D-художника это привычный формат: нарисовал в Blender, экспортировал, положил.

> **Статус.** Сейчас работает со статическими объектами. Анимации в разработке.

## Итого

| | Оригинал | Modloader |
|---|---|---|
| Язык | Pascal-подобный `.script` | Lua 5.4 |
| Правка скриптов игры | копия файла целиком | патч на несколько строк |
| Интерфейс | скрипты состояний GUI | HTML / CSS / JS (CEF) |
