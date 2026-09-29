# How to make mods for Cossacks 3 Modloader

A short guide for the team. Full documentation — `DOCUMENTATION.md`, API reference for an AI — `AI_MODDING_REFERENCE.md`. Function details — `api/README.md` and the comments at the top of
each `api/*.lua`; game variables and types — `GAME_STATE.md`; screens and buttons — `GAME_SCREENS.md`;
native engine functions — `GAME_API.md`.

## 1. Where a mod lives

```
<game>/modloader/mods/<mod folder>/
    manifest.lua      required — the mod's passport
    client.lua        interface script (optional)
    server.lua        rules script (optional) — or shared.lua
    web/              HTML pages (CEF): menus, HUD
    assets/           replacement of game files (textures, shaders, configs, whole scripts)
    patches/          piecewise edits of game scripts (*.patch)
```

A mod can be data-only — no Lua, just `assets/` or `patches/`.

## 2. manifest.lua

```lua
return {
    id = "my_mod",               -- latin letters, digits, _
    name = "My Mod",
    version = "1.0.0",
    author = "...",
    description = "...",
    enabled = true,              -- false — present but not loaded (also toggled in the Insert menu)

    client = "client.lua",       -- on every player's machine: interface, keys, reading state
    server = "server.lua",       -- only where the game is decided (single player, host)
    -- shared = "shared.lua",    -- instead of server: runs on ALL machines identically (for world edits)

    files = { "utils.lua" },     -- modules for require("utils")

    multiplayer = "required",    -- "required" — everyone online must have it, "optional" — interface only
    priority = 0,                -- order: higher loads later and overrides others (files, patches)
    requires = { "base_mod" },   -- won't load without these mods (and loads after them)
}
```

**Which side to pick.** Interface and keys — `client`. Decisions made by the host (give
resources, punish) — `server`. Anything that changes the world identically on every machine (balance, stats,
building logic) — `shared`: otherwise the match desyncs online.

## 3. Events

```lua
events.on("unit.death", function(event, handle, basename) ... end)
```

| event | arguments after the name | when |
|---|---|---|
| `game.menu` | — | main menu |
| `game.prepare` | — | start of match creation (map settings can still be changed) |
| `game.start` | — | match loaded |
| `game.tick` | — | every match tick |
| `game.end` | — | leaving the match |
| `unit.spawn` / `unit.death` / `unit.destroy` | handle, basename | unit appeared / died / removed |
| `building.spawn` / `.death` / `.destroy` | handle, basename | same for buildings |
| `unit.damage` | attacker, target, damage | any damage (melee, shot, explosion, area) |
| `unit.order` | handle, type, target, x, z | any order to any unit (player, AI, network). `return true` — cancel |
| `player.order` | order = {kind, target, x, z, group} | the player clicked an order. `return true` — cancel |
| `net.connect` / `net.disconnect` | payload | a player in the room |
| `*` | event name, ... | all events in a row (debugging) |

Cancelling `unit.order` online — only in a `shared` mod, identically on all machines.
To check that events work, use the `event_test` mod (F8 — report).

## 4. Main functions

| what | how |
|---|---|
| log | `log.info(...)`, `log.warn`, `log.error` |
| keys | `input.bind("F6", fn)`, `"Ctrl+LMB"` |
| game code | `game.exec("pascal code")` (server/shared), `game.eval("expression")` |
| game variables | `state.read("gMap.players[0]")`, `state.set(path, value)` |
| units | `units.selected()`, `units.info(h)`, `units.orders(h)` |
| fast, thousands of objects | `objects.list()`, `objects.read(h)`, `objects.get(h, "orders[0].info.x")` — straight from memory |
| buildings | `buildings.info(h)`, `buildings.produce(h, sid, n)`, `buildings.build(sid, x, z)` |
| balance | `balance.setHP("musketeer18", 200)`, `balance.setDamage(sid, damage)`, `balance.set(sid, field, value)` |
| screens | `screens.open(name)`, `screens.press(name, button)`, `ui.screen("MainMenu", fn)` |
| pages | `web.open("web/menu.html")`, `web.passthrough(true)` (HUD), in JS — `game.api("buildings.info", h)` |
| network | `net.send("name", data)`, `net.on("name", fn)`, `net.broadcast(...)` |
| engine native | `native.GetCurrentMouseWorldCoord()` (list — `GAME_API.md`) |
| readable output | `show(table)` in the console |
| data in a save | `savedata.set(key, table)`, `savedata.get(key)`, event `save.loaded` |

## 5. Replacing files — assets/

A file is placed at the same path as in the game:

```
mods/my_mod/assets/data/shaders/tone/tone.frag   ->  instead of  <game>/data/shaders/tone/tone.frag
```

Works for everything the engine reads from disk: scripts, textures, models, shaders, configs.
Files are read when the game starts — after editing, restart the game (through the Launcher).
If two mods replace the same file, the mod with the higher `priority` wins (on a tie — the later folder name).
You may add new files that the game doesn't have, but if the game itself enumerates a folder (map lists and so on),
it won't see them yet.

## 6. Script patches — patches/

Replacing a whole file breaks when the game updates and conflicts with other mods. A patch edits only
the place you need:

```
mods/my_mod/patches/data/scripts/lib/unit.script.patch
```

```
@@ lines with @@ are comments

@replace _unit_OrderMove          replace the whole function (declaration ... end;)
function _unit_OrderMove(...) : Pointer;
begin
   ...
end;

@begin _unit_AddOrder             insert at the start of the function (right after begin)
@end _unit_AddOrder               insert at the end (before end;)
@before _unit_AddOrder            insert before the function — this is how new functions are added
@after _unit_AddOrder             insert after the function
@append                           at the end of the file

@find                             find text (exactly, with indentation)...
            var damage : Integer = indamage;
@with                             ...and replace it (all occurrences)
            var damage : Integer = indamage * 2;
```

- Many patches to one file are fine (from different mods) — they are applied in mod order.
- If a block did not find its place — the log gets `[patch] ... block skipped`, the other blocks still work.
- The resulting file is in `modloader/cache/<path>` — look at it if something does not compile.
- Patch encoding is UTF-8 or ANSI; comments in any language are fine.
- Example — `examples/mods/patch_example` (damage ×2).
- A patch changes the rules — set `multiplayer = "required"`.

## 6a. New nations and unit types — content.lua

Instead of hand-written patches — a description in `mods/<mod>/content.lua`; the modloader itself edits the scripts,
object lists, `.prop` files, icons and names. Example — `examples/mods/content_example`.

```lua
nation {
    sid = "zap",            -- 3 latin letters, new
    from = "ukr",           -- template: units, buildings, upgrades, AI — same as its
    name = { ru = "Запорожская Сечь", en = "Zaporozhian Sich" },
    remove = { "jannisary" },      -- template units the nation doesn't have (not hireable, AI won't order them)
    resources = { gold = 500 },    -- bonus to starting resources (food wood stone gold iron coal)
}

unit {
    sid = "serdiukvet",     -- new sid
    from = "serdiuk",       -- parent: model, animations, icon, stats, where it is hired
    nations = { "ukr", "zap" },
    cell = { 1, 1 },        -- cell in the hire panel (otherwise — same as the parent)
    base = { maxhp = 150, ["weapon[1].damage"] = 20 },   -- TObjBase fields
    prop = { vision = 900 },                             -- TObjProp fields
    name = { ru = "Сердюк-ветеран", en = "Veteran Serdiuk" },
    -- actor = "my_actor", material = "my_material", animations = "serdiuk", icon = "icons.unit.serdiuk"
}
```

- A nation with buildings works as a template: `tat` and `lit` are empty in the game.
- Special start modes (army, cannons) work for the new nation as they do for the template.
- The nation gets number 24, 25... (the game has 24). The nation's buildings are copies of the template's buildings under its own sid
  (`zapcen`, `zapbar`...). Everything in game scripts that checks the template nation (`if (ukr)`) also fires
  for the new one. Differences are set by patches (`if (csid='zap')`) or by new units.
- A new unit is computed like its parent (all parent-specific handling in `_unit_InitBase`), then `base`/`prop`.
  Hired in the same place as the parent. Not inherited: whatever the game does by the parent's name outside
  `_unit_InitBase` (officer formations, AI lists): use patches for that.
- Names (`name`, `description`) — by game language (`ru`, `uk`, `en`...); without them — the parent's name.
- A custom map: `battle { sid = "poltava", from = "battle1", map = "maps/poltava.map", name = {...} }` —
  appears in "Historical battles" (player positions come from the template). The game does not scan map folders:
  the battle list is `game/var/battles.cfg`, which the modloader extends.
- `.content` in the console — what is described; `[content]` in the log — what was built.
- Changes game rules → `multiplayer = "required"`. Saves with the new nation do not open without the mod.

## 7. Network

- A host with the modloader checks incoming players' `multiplayer = "required"` mods (those that have a
  server/shared part, assets or patches) and kicks anyone who lacks them or has different ones.
- Client mods (`optional`) are not checked.
- The modloader's built-in edits must not change the lobby checksum (for library edits it is also
  verified by the `.checksum` command) — you can play online with the modloader.
  Mods with patches and script replacement do change it: you can play only with those who have them installed too.

## 8. Debugging

- `modloader/dev.txt` (an empty file) — verbose log and developer tools.
- The log is always written to `modloader/modloader.log`; crashes go to `modloader/crashes/`.
- F12 — page DevTools; pages reload themselves when a file is saved (dev).
- The modloader console (a window next to the game): a line is game Pascal code, `=` at the start — Lua
  (`=show(units.selected())`), `?` — print an expression, `/` — a game chat command. Commands:
  `.help`, `.mods`, `.events`, `.assets` (replacements and patches), `.checksum`, `.modcheck`, `.find word`,
  `.lua reload` — reload Lua mods without restarting the game.
- The `dev_tools` mod: LMB — point coordinates, order log.
