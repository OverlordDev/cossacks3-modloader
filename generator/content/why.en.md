# Why not `.script`

Out of the box, Cossacks 3 mods are written in `.script`, a Pascal-like language. Here is what that looks like, and how the same things are done with the Modloader.

## What the original looks like

This is a piece of the real `player.script` from the game: the procedure that makes two players allies. It is just one of 72 functions in a 3,544-line file.

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

What scares a newcomer here:

- names like `plInd1` and `enMask`, bit masks (`1 shl i`);
- hand-written loops over player slots and the game's internal structures (`TEnemyInfo(pEnemyInfo).Reset`);
- to change a single line you have to ship a copy of the whole file in your mod, all 3,544 lines. Such a replacement breaks when the game updates and conflicts with other mods.

*The `player.script` excerpt belongs to GSC Game World and is shown for illustration.*

## The same things with us

### 1. Change one spot in a game script

A patch edits only the lines you need, and the game file stays untouched. This is the "all damage ×2" example from `examples/mods/patch_example`:

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

It is still Pascal, but a dozen lines instead of a copy of thousands. Patches from different mods to the same file stack on top of each other.

### 2. Change the balance: plain Lua

Musketeers get 200 health, 40 damage and a lower price. No Pascal at all:

```lua
events.on("game.start", function()
    balance.setHP("musketeer18", 200)
    balance.setDamage("musketeer18", 40, 1)     -- weapon 1 — the shot
    balance.set("musketeer18", "price[3]", 30)  -- gold price
end)
```

Edit the file, type `.lua reload` in the modloader console, and the result is in the game with no restart.

### 3. Build an interface: HTML instead of GUI scripts

The interface is an ordinary web page (CEF). It pulls data from the game in one line:

```html
<div id="box" style="position:absolute;right:16px;bottom:16px;background:rgba(0,0,0,.7);color:#fc6;padding:8px"></div>
<script>
  setInterval(async () => {
    const h = await game.api('buildings.selected');
    document.getElementById('box').textContent = h ? 'Building #' + h : '';
  }, 500);
</script>
```

A designer who has never seen `.script` can do this immediately: HTML, CSS, JS. A ready hire and upgrade panel built this way is `examples/mods/hud_example`.

### 4. Your own models: drop in a `.glb`

Drop in a `.glb` and the modloader unpacks it into the game for you. For a 3D artist this is a familiar format: draw it in Blender, export, drop it in.

> **Status.** It works with static objects right now. Animations are in development.

## Summary

| | Original | Modloader |
|---|---|---|
| Language | Pascal-like `.script` | Lua 5.4 |
| Editing game scripts | a copy of the whole file | a patch of a few lines |
| Interface | GUI state scripts | HTML / CSS / JS (CEF) |
