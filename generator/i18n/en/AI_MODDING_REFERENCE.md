# Cossacks 3 Modloader — API reference for mod generation

This file is context for an AI (or a human) writing mods. It contains everything that exists:
if a function is not in this file, it does not exist. Do not invent functions, fields or events.
If you need something that is missing — use `native.<Name>` (list: `GAME_API.md`) or `game.exec` with game
Pascal code (variables and types: `GAME_STATE.md`).

---

## 0. Main rules (read first)

1. **A mod = a folder** `modloader/mods/<id>/` with `manifest.lua`. The mod language is **Lua 5.4**. Strings are UTF-8.
2. **Three sides.** `client` code runs on every player's machine, `server` — only on the host / in single player,
   `shared` — on all machines identically. The side determines which functions are available (table in §3).
3. **There is no `game.exec` on the client.** So on the client these do NOT work: `state.set`, `units.info/selected/orders`,
   `buildings.*`, `balance.*` (except reading through `state`), `player():add`, `world{...}`.
   These work on the client: `state.get/read`, `objects.*`, `game.eval*`, `native.Get*/Is*...`, `ui`, `web`, `input`, `gfx`.
   A CEF page (`game.api` in JS) can do everything — a client HUD gets building data through it.
4. **Multiplayer.** Everything that changes the world (stats, units, logic, order cancellation) goes in `shared` and
   is identical on all machines, otherwise you get a desync. Resources and host decisions go in `server`.
   The client asks the host via `net.send`, the host answers with `net.broadcast`.
5. **Speed.** `game.exec`, `game.eval`, `state.*`, `units.*`, `buildings.*` compile Pascal —
   ~1 ms per call. Do not call them every tick for every unit. To walk many objects —
   `objects.list()` + `objects.read(h)` / `objects.get(h, field)` (microseconds).
6. **When to change what.** The game fills type stats at the start of a match — change them in `events.on("game.start")`.
   Map settings — in `events.on("game.prepare")`. Outside a match many natives crash — check `game.isInGame()`.
7. **Errors** in a handler do not crash the game: they are written to the log with the mod name. Use `log.info/warn/error`.
8. **Do not touch game files.** Replace through `assets/`, edit scripts through `patches/*.patch`.

---

## 1. Mod structure

```
modloader/mods/<id>/
  manifest.lua          required
  client.lua            client side (optional)
  server.lua | shared.lua   server or shared side (optional, not both)
  <module>.lua          shared modules, list in files, include with require("module")
  web/<page>.html       CEF pages
  assets/<path in game> whole-file replacement of a game file
  patches/<path in game>.patch   edit of a game text file
```

At least one of these is needed: `client`, `server`/`shared`, an `assets/` folder, a `patches/` folder.

## 2. manifest.lua

Executed in an empty environment — data only, no function calls.

```lua
return {
    id = "my_mod",            -- required: [A-Za-z0-9_]
    name = "My Mod",
    version = "1.0.0",
    author = "",
    description = "",
    enabled = true,           -- true by default
    client = "client.lua",
    server = "server.lua",    -- OR shared = "shared.lua"
    files = { "utils.lua" },  -- modules for require; only .lua inside the mod folder
    multiplayer = "required", -- "required" (default) | "optional" (interface only)
    priority = 0,             -- integer; higher — loads later, its assets/patches win
    requires = { "other_id" },-- string or list of ids; won't load without them
}
```

`multiplayer = "optional"` — only if the mod changes nothing in the game (interface, graphics, keys).

## 3. What is available on which side

| table / function | client | server | shared | page (game.api) |
|---|---|---|---|---|
| `log`, `print`, `require`, `mod`, `show` | yes | yes | yes | — |
| `events.on/off/hook` | yes | yes (host only) | yes (everyone) | — |
| `game.eval/evalInt/evalFloat/evalBool`, `game.mode`, `game.isAuthority`, `game.isInGame` | yes | yes | yes | yes |
| `game.exec`, `game.run`, `game.command` | **no** | yes | yes | yes |
| `native.<Name>` | read-only ones (`Get*`, `Is*`, `Has*`, `Can*`, `Calc*`, `Check*`, `Find*`, `Count*`, GUI) | all | all | all |
| `mem.*`, `objects.*` | yes | yes | yes | yes |
| `state.get/read/list/type`, `G.x` (read) | yes | yes | yes | yes |
| `state.set`, `G.x = v` | no | yes | yes | yes |
| `units.*`, `buildings.*`, `balance.*`, `player():add`, `world{}` | no | yes | yes | yes |
| `profile.*`, `options.*`, `saves.*`, `players.*`, `map.*`, `screens.list/tags/open/press` | read (`get`); `set` — no | yes | yes | yes |
| `net.send` | yes | no | no | — |
| `net.broadcast` | no | yes | yes | — |
| `net.on` | yes | yes | yes | — |
| `input.bind`, `web.*`, `ui.*`, `gfx.*`, `screens.onButton/onAnyButton/replace` | yes | no | no | — |

`server` event handlers and `net.on` work only where the game is decided (single player/host).
`shared` — on all machines.

## 4. Lua API

### 4.1. log, mod, require, show

```lua
log.info(...)  log.warn(...)  log.error(...)   -- to the console and modloader.log with the mod name; print = log.info
local u = require("utils")                      -- a module from manifest.files (without .lua)
mod.id  mod.name  mod.version  mod.side         -- "client" | "server"
mod.files("web/img")                            --> { "a.png", ... } file names in the mod folder
show(value, depth)                              --> text of a table (for the console and logs)
```

### 4.2. events

```lua
local id = events.on(name, function(event, ...) ... end)   -- return true — cancel (where stated)
events.off(id)
events.hook("ShowHud", atEnd)   -- create a gui.ShowHud event at the start (or end) of a GUI state
```

| event | arguments after `event` | when | cancel |
|---|---|---|---|
| `game.menu` | — | entered the main menu | — |
| `game.prepare` | — | start of match creation (change `world{}`) | — |
| `game.start` | — | match loaded | — |
| `game.tick` | — | every match tick (often! keep code light) | — |
| `game.end` | — | left the match | — |
| `unit.spawn` | handle, basename | a unit appeared | — |
| `unit.death` | handle, basename | a unit died | — |
| `unit.destroy` | handle, basename | a unit vanished from the map | — |
| `building.spawn` / `building.death` / `building.destroy` | handle, basename | same for buildings | — |
| `unit.damage` | attacker, target, damage | any damage (melee, shot, explosion, area); attacker may be 0 | — |
| `unit.order` | handle, type, target, x, z | any order to any unit (player, AI, network). type is a string, see below | `return true` (online only in shared) |
| `player.order` | order | the player of this computer gave an order with the mouse | `return true` |
| `net.connect` / `net.disconnect` | payload | a player joined/left the room | — |
| `save.loaded` | — | a save was loaded, `savedata` already holds its data | — |
| `gui.<State>` | payload | after `events.hook(...)` | — |
| `*` | as of the event | all events (debugging) | — |

`basename` — the internal type name (sid), for example `"musketeer18"`, `"auscen"`.
`unit.order` type: `none, move, attackobj, gainres, produce, patrol, attackpoint, continueattackpoint,
performupgrade, fishing, creategates, buildwallcontinue, buildwall, gotomine, gototransport,
leavetransport, leavebuilding, build, guard, repair, exitunits`.
`player.order` order = `{ kind, target, x, z, group }`, kind: `move | attack | attackpoint | guard |
build | enter | gather | patrol`; target — handle of the target, x/z — a point, group — a group (move — an event per group).

### 4.3. game

```lua
game.eval("GetBuildVersion")          --> string result of a Pascal expression
game.evalInt("gMap.gamestage")        --> integer
game.evalFloat("gProfile.sndmaster")  --> number
game.evalBool("gbool_peacemode")      --> boolean
game.exec(code, arg)                  --> string from ML_RET(...) or "" ; ML_ARG in the code = arg (string). server/shared
game.run(code)                        -- asynchronous, no result. server/shared
game.command("res all 5000")          -- game chat command. server/shared
game.mode()                           --> "offline" | "host" | "client"
game.isAuthority()                    --> true if this machine decides the game (single player or host)
game.isInGame()                       --> a match is running
game.playerIndexOf(from)              --> player index by the sender from net.on
game.side                             --> "client" | "server"
```

Pascal in `game.exec`: variables are declared in place (`var h : Integer = 5;`), the result is
`ML_RET(IntToStr(x))`, strings in single quotes. An object by handle: `TObj(_unit_GetTObj(h)).hp`.
Resources in memory are inverted: read `not gPlayer[i].res[t]` (or through `player(i).gold`).
Game constants `gc_*` are available in Pascal code. Types and fields — `GAME_STATE.md`.

### 4.4. player, world

```lua
local p = player()      -- the player of this computer (in a match only); player(i) — by index
p.index
p.food  p.wood  p.stone  p.gold  p.iron  p.coal     -- read
p.gold = 1000                                       -- write (server/shared)
p:add("gold", 500)                                  -- (server/shared)

world()                          --> { size, season, terrain, relief, mines, resources, seed0, seed1 }
world{ size = 2, mines = 3 }     -- server/shared, in game.prepare
-- size: 0=320 1=480 2=640 3=256; season: 0 summer 2 winter 3 desert (<0 random); terrain 0..5; relief 0..4;
-- resources: 0=1000 1=4000 2=5000 otherwise 1000000
```

### 4.5. state and G — any game variable

```lua
state.get("gProfile.sndmaster")          --> a value (type per schema)
state.read("gMap.players[2]", depth)     --> a record as a table
state.list("gMap.players", depth)        --> an array of records
state.type("gMap.settings.gen")          --> the type name
state.set("gProfile.sndmaster", 0.5)     -- server/shared
state.get("obj(" .. h .. ").hp")         -- an object by handle (TObj)
G.gProfile.sndmaster                     -- the same with dots; G.x = v — write; G.gMap.players[2]() — a record as a table
```

### 4.6. objects and mem — fast reading (any side)

```lua
objects.list(playerIndex)   --> { handle, ... } a player's objects; nil — all players (including resources/projectiles, not filtered)
objects.each(fn, playerIndex)
objects.read(h)             --> all simple TObj fields: { hp, pl, cid, id, uid, bdead, bbuilt, kill, ... } or nil (not a unit/building)
objects.get(h, "hp")        --> one field; path as in TObj: "orders[0].itype", "orders[0].info.x"
objects.pos(h)              --> x, z (world coordinates)
objects.ptr(h)              --> TObj address or nil
objects.status()            --> "fast" | "slow" | "not calibrated", parameters
mem.i32(addr, off) mem.u32 mem.i16 mem.u16 mem.u8 mem.f32 mem.f64 mem.str mem.bytes(addr, off, n)  -- nil on error
```

`objects.read` returns `nil` for objects that are not a unit/building. Buildings are told apart by
`balance`/`gObjProp[cid][id].bbuilding`; the object type — `native.GetGameObjectBaseNameByHandle(h)`.
Read-only: change through `state.set("obj(h).field", v)` (server/shared) or api functions.

### 4.7. units (server/shared/pages)

```lua
units.selected()    --> { handle, ... } what the player has selected
units.info(h)       --> { handle, sid, player, hp, maxhp, x, z, dead } or nil
units.orders(h)     --> { { type, target, x, z }, ... } the order queue, [1] — the current one
```

### 4.8. buildings (server/shared/pages)

```lua
buildings.list(player)            --> { { handle, sid, built, hp, maxhp, x, z, queue }, ... } (player — index, own by default)
buildings.selected()              --> handle of the selected building or nil
buildings.info(h)                 --> { handle, sid, country, id, player, hp, maxhp, built, buildprogress,
                                  --     produce = { {sid, id, available, price = {food,wood,stone,gold,iron,coal}, buildtime, x, y} },
                                  --     upgrades = { {sid, index, available, enabled, level, kind, value, price, time} },
                                  --     queue = { {kind = "unit"|"upgrade", sid, amount (-1 infinite), progress} } }
buildings.produce(h, unitSid, amount)     -- order (like the player's button); amount -1 — infinite
buildings.cancel(h, unitSid, amount)
buildings.upgrade(h, upgSid)      buildings.cancelUpgrade(h, upgSid)
buildings.produceList(bsid)               --> { unitSid, ... } what a building type produces
buildings.setProduceList(bsid, list)      buildings.addProduce(bsid, sid)    buildings.removeProduce(bsid, sid)
buildings.setUpgrade(upgSid, field, value)          -- TCountryUpgrade fields: time, value, enabled, price[3] ...
buildings.canPlace(sid, x, z, player)     --> boolean
buildings.build(sid, x, z, opts)          --> handle of the construction; an error string on failure
    -- opts = { workers = "selected" | {h1, h2}, instant = true, player = i, check = false }
buildings.finish(h)                       -- finish instantly (online only shared)
```

Editing building logic (`setProduceList`, `setUpgrade`) — in `shared`, in `game.start`.

### 4.9. balance (server/shared) — type stats

```lua
balance.types()                          --> { {sid, country, id}, ... }
balance.find(sid)                        --> country, id
balance.get(sid, player)                 --> { base = TObjBase, prop = TObjProp }
balance.set(sid, field, value, player)   -- TObjBase field: "maxhp", "speed", "buildtime", "price[3]",
                                         --   "shield", "protection[0]", "weapon[0].damage", "weapon[1].radiusmax" ...
balance.setProp(sid, field, value)       -- TObjProp field (shared): "vision", ...
balance.setHP(sid, maxhp, player)        -- and to living units of this type
balance.setDamage(sid, damage, weapon, player)   -- weapon — index 0..3 (musketeer: 0 bayonet, 1 shot); nil — all
balance.setSpeed(sid, multiplier, player)        -- and to living ones
balance.dump(sid, player)                -- all fields to the log
```

player — a player index, `nil` — all. Prices: `price[0]` food, `[1]` wood, `[2]` stone, `[3]` gold,
`[4]` iron, `[5]` coal. Change in `game.start` in a `shared` mod.

### 4.10. Other data

```lua
profile.get(field)  profile.set(field, v)  profile.all()  profile.save()   -- gProfile (TProfile)
options.get(name)   options.set(name, v)                                    -- engine options ("SSAOEnable", "ShadowMap")
saves.list() --> { {name, date} }   saves.load(name)   saves.delete(name)   saves.replays.list()   saves.replays.load(name)
players.list() --> { {index, name, team, color, bai, bhuman, ...} }   players.me()   players.resources(i)
map.info()     map.settings() --> { gen = {...}, additional = {...} }
```

### 4.11. net

```lua
-- client
net.send("event", data)                      -- to the host (in single player — to its own server script)
net.on("event", function(data, from) end)    -- from the host
-- server/shared
net.broadcast("event", data)                 -- to all clients (and the host's client side)
net.on("event", function(data, from)         -- from a client
    local who = game.playerIndexOf(from)     -- identify the player THIS way, do not trust the data
end)
```

data — nil, a number, a string, a boolean or a table of those. Event names are each mod's own.

### 4.12. input (client)

```lua
input.bind("F6", function(key) end)
-- keys: A-Z, 0-9, F1-F12, Num0-Num9, Space, Enter, Tab, Escape, Backspace, Delete, Home,
-- PageUp, PageDown, Up, Down, Left, Right, LMB, RMB, MMB; modifiers: "Ctrl+", "Shift+", "Alt+"
```

Do not take Insert (the menu). With dev.txt the modloader also takes F9 (resources, single player only), End (unload), F12 (DevTools).

### 4.13. web — CEF pages (client)

```lua
web.open("hud.html")        -- <mod>/web/hud.html (or a full URL)
web.close()   web.reload()   web.isOpen()   web.url()
web.eval("js code")         -- run in the page
web.passthrough(true)       -- HUD mode: transparent (alpha < 16) lets the mouse through to the game
```

One page on screen at a time (the last `web.open` replaces the previous one).

**JS in a page** (the `window.game` object appears after load — wait for it):

```js
const v = await game.api('buildings.info', handle);   // any api function: 'module.function', arguments as in Lua
await game.api('state.set', 'gProfile.sndmaster', 0.5);
await game.tag('EventMainMenu', 104);                  // press a native button (state, tag)
await game.exec('ShowSettings');                       // run an interface state
const r = JSON.parse(await game.lua('1 + 1'));        // Lua code: an expression or a statement, the answer is a JSON string
game.log('text');   game.close();   await game.files('img');
```

An error in `game.api` is an exception (Promise reject) with the Lua error text.
Page code (`game.api`, `game.lua`) runs in the modloader console environment (server side),
not in the mod's environment: the mod's global variables and functions are not visible from the page. A mod and a page
exchange data through api functions, `web.eval(...)` (Lua → page) and the game's global tables.
`game.lua` is available only to local pages (from the mod folder).

### 4.14. ui — the game's native interface (client)

```lua
ui.window{ name=, parent=0, x=, y=, w=, h= }                                 --> an element (a number)
ui.text{ name=, parent=, text=, x=, y=, w=0, h=0, font="gc_font_serif_15", color={r,g,b,a} }
ui.image{ name=, parent=, material="mainmenu_art", x=, y=, w=0, h=0, align= }
ui.container{ name=, parent=, x=, y=, w=, h=, align= }
ui.button{ name=, parent=, text=, x=, y=, w=0, h=0, material="btn.large", hint="", tag=0, align=, onClick=function(el) end }
ui.onClick(el, fn)
ui.find(name, parent)  ui.name(h)  ui.getText(h)  ui.setText(h, s)  ui.isVisible(h)  ui.setVisible(h, b)
ui.getPosition(h)  ui.setPosition(h, x, y)  ui.setHint(h, s)  ui.setBlend(h, a)  ui.remove(h)
ui.size() --> w, h   ui.imageSize(material)   ui.locale(table, key)   ui.dump(h)   ui.children(h)
ui.exec("ShowSettings")          ui.sendTag("EventMainMenu", 103)
ui.hookState("EventMenu", function(element, press, tag) return true --[[the game won't handle it]] end)
ui.screen("MainMenu", function() ... return false --[[keep the native one too]] end)   -- build a screen yourself
```

### 4.15. screens — screens by name

```lua
screens.list()                      --> { "MainMenu", "Settings", ... }
screens.tags("MainMenu")            --> { Campaign = 101, Settings = 104, ... }
screens.button("MainMenu", 104)     --> "Settings"
screens.open("Settings")            screens.press("MainMenu", "Settings")
-- client:
screens.onButton("MainMenu", function(button, tag, element) return true --[[replace with your own]] end)
screens.onAnyButton(function(screen, button, tag, element) end)
screens.replace("Settings", function() web.open("settings.html") end)
```

Screen and button names — `GAME_SCREENS.md`.

### 4.16. gfx — graphics (client, visible only on this computer)

```lua
gfx.<group>{ key = value }   -- write;  gfx.<group>() — read
-- groups and keys:
-- post: preset, preset2, dof, ssao        render: antialiasing, culling, objectCulling, fxaa
-- camera: dof, depth, focal, angle, distance, rotateSpeed, zoomSpeed, height, freeMode, ...
-- fog: enabled, density, power, start, finish, offset, depth      clouds: visible, active, height, horizon, fog, speed
-- sky: visible, active, flareAngle, flareZ, flare                 shadows: enabled, size, scaleHeight, addHeight, lightDepth
-- light: pattern, index, blendTo, blendTime                       time: game, speed, season, dayNight, fogOfWarDay
-- water: name, index, offset     wind: vector, target, random, interval     terrain: visible, borders, colorMode
gfx.preset{ bloom = 0.1, saturation = 1.2, hdr = 1.8, contrast = 1.05, vignetteInner = 0.7, vignetteOuter = 1.5 }
gfx.presets()   gfx.presetNames()   gfx.usePreset("name")
gfx.apply{ fog = {...}, shadows = {...} }     local s = gfx.snapshot()    gfx.apply(s)
gfx.option("ShadowMapEnabled", true)          gfx.vsync(false)   gfx.highlight{...}
gfx.<GraphicsNative>(...)                     -- any graphics native directly
```

The exact list of a group's keys — read `gfx.<group>()` in the console.

### 4.16a. savedata — mod data inside a save (any side)

```lua
savedata.set("veterans", { [123] = 5 })   -- any value: nil (delete), number, string, bool, table
savedata.get("veterans")                  --> the value or nil
savedata.keys()                           --> { "veterans", ... } this mod's keys
events.on("save.loaded", function() ... end)  -- a save was loaded: savedata already holds its data
```

The data lives inside the game's save file (autosaves too), each mod has its own key namespace.
It is cleared when leaving the match. Object handles may be different after a save loads — store
`uid` (`objects.get(h, "uid")`), not handles.

### 4.17. native

```lua
native.GetCurrentMouseWorldCoord()          --> x, y, z  (var parameters are returned as values)
native.GetGameObjectBaseNameByHandle(h)     --> "musketeer18"
native.GetPlayerIndexInterfaceIO()          --> the index of your own player
```

All 4856 — `GAME_API.md` (VA, declaration). A call with the wrong number of arguments is a Lua error.
Float is single precision. Many natives crash outside a match.

## 5. Replacing files — assets/

`assets/<path as in the game>` replaces a game file: `assets/data/shaders/tone/tone.frag`.
Any files the engine reads. A game restart is needed. On conflict the higher `priority` wins.

## 6. Game script patches — patches/

A file `patches/<path in game>.patch`, for example `patches/data/scripts/lib/unit.script.patch`.
Game scripts: `data/scripts/lib/*.script` (function libraries), `data/scripts/**/*.inc` and `*.aix`
(states), `data/gui/menu.inc/*.inc` (interface). In the libraries every function is laid out like this:
the declaration at line start, `begin` at line start, the last `end;` at line start.

```
@@ comment
@replace <Name>     -- replace the whole function (the text below is the full new declaration and body)
@begin <Name>       -- insert the lines below right after the function's begin
@end <Name>         -- before the function's last end;
@before <Name>      -- before the function (put new functions here that it or others call)
@after <Name>       -- after the function
@append             -- at the end of the file
@find               -- exact text (with indentation, may be several lines)
@with               -- what to replace it with (all occurrences)
```

Rules: in the game's Pascal a function must be declared above the place it is called; `const` parameters cannot
be changed (declare a local variable); look at the result in `modloader/cache/<path>`; a compile error shows in
the log as `[engine] Compile script error`. A patch changes the game rules → `multiplayer = "required"`.

## 6a. New nations and units — content.lua (data, not code)

A `content.lua` file in the mod folder. Only `nation{...}` and `unit{...}` calls with data; `load`, `require`,
files are not available. It runs at game start, before the Lua mods.

```lua
nation { sid = "zap", from = "ukr", name = { ru = "...", en = "..." },   -- sid: 3 letters, from: a game nation with buildings (not tat, lit, mis)
         remove = { "jannisary" }, resources = { gold = 500 } }         -- remove template units; bonus to starting resources
unit {
    sid = "serdiukvet", from = "serdiuk",       -- from: an existing unit (data/objects/units/<from>.prop)
    nations = { "ukr", "zap" },                  -- required
    cell = { 1, 1 },                             -- hire panel cell; by default the parent's cell
    base = { maxhp = 150, speed = 1.2, ["price[3]"] = 20, ["weapon[1].damage"] = 20 },   -- TObjBase
    prop = { vision = 900 },                     -- TObjProp
    name = { ru = "...", en = "..." }, description = { ru = "...", en = "..." },
    actor = nil, mesh = nil, material = nil, animations = nil, icon = nil,   -- own resources (names from .lib/.mat)
}
```

A historical battle (a custom map in the "Historical battles" menu):

```lua
battle {
    sid = "poltava", from = "battle1",        -- from: battle1..battle8 — positions and player count come from it
    map = "maps/poltava.map",                 -- a .map file inside the mod folder (made in the game's editor)
    maxplayers = 4,                           -- optional
    name = { ru = "...", en = "..." }, description = { ru = "...", en = "..." },
}
```

Game nations: aus fra eng spa rus ukr pol swe pru ven tur alg net den por pie sax bav hun swi sco tat lit
(mis is internal). A new nation = a copy of a template. A new unit = a copy of the parent + `base`/`prop`;
hired in the same place as the parent. Stats can also be changed later in a match through `balance`.

## 7. Templates

### 7.1. Client mod: a key and reading

```lua
-- manifest.lua
return { id = "hp_report", name = "HP Report", version = "1.0.0", client = "client.lua", multiplayer = "optional" }

-- client.lua
input.bind("F7", function()
    if not game.isInGame() then return end
    local me = native.GetPlayerIndexInterfaceIO()
    local total, n = 0, 0
    for _, h in ipairs(objects.list(me)) do
        local o = objects.read(h)
        if o and not o.bdead then total, n = total + o.hp, n + 1 end
    end
    log.info(string.format("units and buildings: %d, total HP: %d", n, total))
end)
```

### 7.2. Balance for everyone (shared)

```lua
-- manifest.lua
return { id = "strong_musketeers", name = "Strong Musketeers", version = "1.0.0",
         shared = "shared.lua", multiplayer = "required" }

-- shared.lua
events.on("game.start", function()
    balance.setHP("musketeer18", 200)
    balance.setDamage("musketeer18", 40, 1)       -- weapon 1 — the shot
    balance.set("musketeer18", "price[3]", 30)    -- gold
end)
```

### 7.3. The client asks — the host decides

```lua
-- manifest: client = "client.lua", server = "server.lua", multiplayer = "required"
-- client.lua
input.bind("F6", function() net.send("give_gold", { amount = 500 }) end)
net.on("gold_given", function(data) log.info("player " .. data.player .. " was given " .. data.amount) end)

-- server.lua
net.on("give_gold", function(data, from)
    local who = game.playerIndexOf(from)
    local amount = math.min(tonumber(data and data.amount) or 0, 1000)   -- validate client data
    player(who):add("gold", amount)
    net.broadcast("gold_given", { player = who, amount = amount })
end)
```

### 7.4. Unit events

```lua
-- shared.lua (or server.lua)
local kills = {}
events.on("unit.death", function(_, handle, basename)
    kills[basename] = (kills[basename] or 0) + 1
end)
events.on("unit.damage", function(_, attacker, target, damage)
    if damage > 100 then log.info("heavy hit", attacker, "->", target, damage) end
end)
events.on("unit.order", function(_, handle, kind, target, x, z)
    if kind == "attackobj" and target == 0 then return true end   -- cancel (shared — on all machines)
end)
events.on("game.end", function() log.info(show(kills)) end)
```

### 7.5. A HUD on a page

```lua
-- client.lua
events.on("game.start", function() web.open("hud.html"); web.passthrough(true) end)
events.on("game.end", function() web.close() end)
```

```html
<!-- web/hud.html: the background is transparent, otherwise clicks won't reach the game -->
<html><body style="margin:0;background:transparent">
<div id="box" style="position:absolute;right:16px;bottom:16px;background:rgba(0,0,0,.7);color:#fc6;padding:8px"></div>
<script>
const wait = setInterval(() => {
  if (typeof window.game !== 'object') return;
  clearInterval(wait);
  setInterval(async () => {
    const h = await game.api('buildings.selected');
    document.getElementById('box').textContent = h ? JSON.stringify(await game.api('buildings.info', h)).slice(0, 200) : '';
  }, 500);
}, 50);
</script></body></html>
```

### 7.6. Your own button instead of a native one

```lua
-- client.lua
screens.onButton("MainMenu", function(button)
    if button == "Settings" then web.open("settings.html"); return true end
end)
```

### 7.7. Patching a game function

```
@@ patches/data/scripts/lib/miscext2.script.patch — damage x2
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

## 8. Common errors

| error | cause | what to do |
|---|---|---|
| `only server/shared scripts and pages can do this` | calling `units/buildings/balance/state.set` in client | move to server/shared or to a page (`game.api`) |
| `native.X can change the game — call it from server scripts` | a mutating native on the client | server/shared |
| `player(): no local player outside of a game` | called outside a match | check `game.isInGame()` |
| stats "don't change" | changed before `game.start` or for only one player | `game.start`, `shared`, `balance.setHP/setDamage/setSpeed` for living units |
| desync online | `server`/`client` logic changes the world | `shared`, identical everywhere |
| a page intercepts all clicks | an opaque background | `background: transparent` + `web.passthrough(true)` |
| `window.game` undefined | the page has not received the bridge yet | wait for `typeof window.game === 'object'` |
| lag | `game.exec`/`state`/`units` in a loop over units every tick | `objects.*`, less often (once per N ticks) |
| patch `block skipped` | `@find` did not match exactly / no such function | copy the text from the game file with indentation |
