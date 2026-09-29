# api — the modloader's library on top of the game

> A guide for modders (manifest, events, assets, patches): `../MODDING.md`.

Lua modules that the modloader loads into every mod's environment and into the console. They live as separate
files so they can be extended without rebuilding: edit a file — `.lua reload` in the console.

In the game the folder is `<game>/modloader/api/`, in the repository — here. Files are loaded in name order.

| file | what it gives |
|---|---|
| `00_schema.lua` | **generated**, do not edit. All types and global variables of the game scripts |
| `02_screens_data.lua` | **generated** (`tools/gen_screens.py`). Game screens and button tag names |
| `01_state.lua` | `state`, `G` — reading/writing any game variable by path |
| `10_profile.lua` | `profile` — the player profile (sound, controls, language) |
| `11_options.lua` | `options` — engine options (graphics) |
| `12_saves.lua` | `saves` — saves and replays |
| `13_players.lua` | `players` — match participants |
| `14_map.lua` | `map` — the map and match settings |
| `15_screens.lua` | `screens` — screens by name: open, press a button, intercept a button, replace a screen |
| `17_balance.lua` | `balance` — unit/building type parameters: read and change in the middle of a match |
| `18_buildings.lua` | `buildings` — buildings: what they build, upgrades, the queue, player commands, logic editing |
| `19_units.lua` | `units` — selection, state and orders of units; the `unit.order` / `player.order` events |
| `20_objects.lua` | `objects` — fast reading of units and buildings from memory (no Pascal), walking all objects |
| `90_call.lua` | `api_call` — the entry point for pages (`game.api` in JS) |

A reference for all game variables and fields — `GAME_STATE.md`, for screens and buttons — `GAME_SCREENS.md`.

## How to use

From a mod's Lua:

```lua
local volume = profile.get("sndmaster")
for _, p in ipairs(players.list()) do log.info(p.name, p.team) end
local gen = map.settings().gen
```

From a page (HTML in the mod folder):

```js
const list = await game.api('saves.list');          // [{ name, date }, ...]
await game.api('profile.set', 'sndmaster', 0.5);    // any arguments, the answer is an object
const slot = await game.api('state.read', 'gMap.players[0]');
```

`game.api('a.b', x, y)` calls the function `a.b(x, y)` in the game and returns the result through JSON.

## Reading and writing game variables

`state` knows the type of every field from the schema and picks how to read it itself:

```lua
state.get("gProfile.sndmaster")        -- 0.75 (fractional)
state.get("gMap.players[2].name")      -- "Cossack" (string)
state.read("gMap.players[2]")          -- the whole record as a table, in ONE script call
state.read("gMap.settings", 2)         -- with nested records to 2 levels
state.list("gMap.players")             -- all elements of the array
state.set("gProfile.sndmaster", 0.5)   -- write

G.gMap.players[2].team                 -- the same with dots
G.gProfile.sndmaster = 0.5
```

Rules that are important to know:

- **You can read from anywhere, but only the server can write.** On the client `state.set` throws a clear
  error. Pages work with console rights, so they may write.
- **For records use `state.read`, not many `state.get`.** Every `get` is a separate game script call;
  `read` gathers the whole record into one string in one call.
- **Errors name what is wrong.** A typo in a field gives `state: 'gProfile.x': no field 'x'`, not a crash.

## How to add a module

1. Find how the game itself does it: screens — `data/gui/menu.inc/*.inc`, libraries — `data/scripts/lib/*.script`,
   natives — `GAME_API.md`.
2. If the data is in a global variable — take it through `state` (types are already known).
   If through a native — through `native.<Name>`. Check that the native exists:
   `grep "function <Name>(" "Modloader For Cossacks 3/core/NativesTable.inc"`.
3. Create `api/NN_name.lua` with a global table and a comment header with examples.
4. Add checks to `tools/api_test/run.lua` and, if needed, fake data to
   `tools/api_test/fake_game.lua`.
5. Run the tests, copy the folder into the game, `.lua reload`.

The model module is `12_saves.lua`: it is short and shows both techniques.

## Testing without the game

```bash
lua tools/api_test/run.lua
```

The fake game (`fake_game.lua`) understands the same calls as the modloader (`game.eval*`, `game.exec`,
the needed natives) and keeps state in an ordinary table. The Lua interpreter is built by the script
`tools/api_test/build_lua.ps1` from the sources in `external/lua`.

## When the game was updated

```bash
python tools/gen_game_api.py "C:/Program Files (x86)/Steam/steamapps/common/Cossacks 3"
```

Regenerates `00_schema.lua` and `GAME_STATE.md` from the game scripts.

## What is not there yet

- **Campaigns** — the list and descriptions live in separate campaign files, not in global
  variables; parsing `data/gui/menu.inc/showcampaign.inc` is needed.
- **Lobbies and rooms** — network data, updated by events; parsing `showinternetshell.inc`
  and the `OnLanEvent` events is needed.
- **Units** — type stats exist (`balance`), life events — `unit.spawn/death/destroy`, `building.*`. Missing: damage, orders, data of a specific unit (TObj).
