# Cossacks 3 Modloader

**Write Cossacks 3 mods in Lua, build interfaces in HTML, and change the game without touching its files.**

🇬🇧 English · [🇷🇺 Русский](README.ru.md)

📖 **[Documentation site](https://overlorddev.github.io/cossacks3-modloader/en/)** · [Русская документация](https://overlorddev.github.io/cossacks3-modloader/)

> Pre-release. Windows, Steam build 2.2.3 (the game is 32-bit). This is a fan project and is not affiliated with GSC Game World.

## Why

Out of the box, Cossacks 3 mods are written in `.script`, a Pascal-like language, and changing one line usually means shipping a copy of a whole game file. The modloader hooks into the game at launch, so you can do this instead:

```lua
-- strong musketeers, for everyone in the match
events.on("game.start", function()
    balance.setHP("musketeer18", 200)
    balance.setDamage("musketeer18", 40, 1)
    balance.set("musketeer18", "price[3]", 30)
end)
```

Edit the script, type `.lua reload` in the modloader console, and see the result without restarting the game.

## What you get

- **Lua 5.4 mods** with events (`game.start`, `unit.death`, `unit.order`, ...), a library over the game (`state`, `units`, `buildings`, `balance`, `objects`, ...) and access to the engine's native functions.
- **HTML/CSS/JS interfaces** (Chromium Embedded Framework) drawn over the game: HUDs, hire panels, menus, or whole screens replaced with your own page.
- **File replacement and script patches:** replace game files from a mod folder, or patch only the lines you need in the game's scripts.
- **`content.lua`:** describe new nations, units and historical battles (with your own maps) as data.
- **Graphics control:** post-processing presets, fog, shadows, light, sky.
- **`.glb` models:** drop a model in and the modloader unpacks it into the game. Static objects work today, animations are in development.
- **Mod data inside saves** (`savedata`), so your mod's state survives save and load.
- **Multiplayer checks:** the host verifies that everyone has the same gameplay mods, and a built-in watchdog reports desyncs.
- **Developer tools:** an in-game console, crash reports with stack traces, a profiler, and page reload on save.

The game's files are never modified: everything happens in memory, so launching the game without the launcher gives you vanilla Cossacks 3.

## Install

**From a release archive.** If a release zip is published on the Releases page, unpack it into the game folder and start the game with `Cossacks3Launcher.exe`. Example mods ship disabled; turn them on from the **Insert** menu in game.

**From source:**

1. Build `Modloader For Cossacks 3.slnx` (Release, x86; the game is 32-bit).
2. Copy `Cossacks3Launcher.exe`, `Cossacks3Loader.dll`, `Modloader For Cossacks 3.dll` (and the `.pdb` for readable crash reports) and `Cossacks3Cef.exe` into the game folder.
3. Run `python tools/install_cef.py` to install CEF into `<game>/cef`.
4. Copy `api/` to `<game>/modloader/api/` and your mods to `<game>/modloader/mods/`.
5. Start the game through `Cossacks3Launcher.exe`.

Command-line build:

```bash
MSBuild "Modloader For Cossacks 3.slnx" -t:"Modloader For Cossacks 3" -p:Configuration=Release -p:Platform=x86
```

The launcher starts the game suspended, injects the loader, and only then lets the game run, so file replacement, script patches and shaders work from the very first read.

## Make your first mod

A mod is a folder in `<game>/modloader/mods/` with a `manifest.lua`:

```lua
return {
    id = "hp_report",
    name = "HP Report",
    version = "1.0.0",
    client = "client.lua",
    multiplayer = "optional",
}
```

Pick the side that fits: `client` (interface and keys, on every player's machine), `server` (host decisions), or `shared` (rules that must be identical on all machines, such as balance).

- Quick start: [MODDING.md](MODDING.md) (Russian) or the [English guide](https://overlorddev.github.io/cossacks3-modloader/en/guide.html)
- Full API reference: [English](https://overlorddev.github.io/cossacks3-modloader/en/core-rules.html) · [AI_MODDING_REFERENCE.md](AI_MODDING_REFERENCE.md) (Russian, written to be fed to an AI that writes mods)
- Examples: [`examples/mods/`](examples/mods): balance, HUD, custom main menu, graphics, new nations and units, patches, saved data.
- **VS Code extension** with autocomplete for the whole API, manifest validation and a "create mod" generator: [`vscode-extension` branch](https://github.com/OverlordDev/cossacks3-modloader/tree/vscode-extension).

## Repository layout

| folder | what |
|---|---|
| `Modloader For Cossacks 3/core/` | the main DLL (C++): hooks, Lua, CEF, events |
| `Launcher/`, `Loader/` | game launch and the small loader |
| `CefSub/`, `CefWrapper/` | Chromium process and libcef wrapper |
| `api/` | the Lua library that is copied to `<game>/modloader/api` |
| `builtin/` | components shipped inside the modloader (desync watchdog) |
| `examples/mods/` | example mods |
| `tools/` | reference generators (IDA exports, game scripts), API tests, release packer |
| `external/` | Lua, Dear ImGui, MinHook, CEF |

## Known limitations

- Mods that change gameplay must be identical for everyone in an online match (`shared`, `multiplayer = "required"`).
- Cancelling `unit.order` online is only safe when done identically on all machines.
- New map or file names the game did not list itself are not picked up (folder enumeration is not intercepted).
- Shaders and some resources are read once at start, so changing them needs a game restart.
- The mod check and lobby checksum behaviour have not yet been verified in a real network game.
- CEF runs on the game thread, so a heavy page slows the game down.

## Feedback

Found a bug or want an API function? [Open an issue](https://github.com/OverlordDev/cossacks3-modloader/issues). Attach `modloader/modloader.log`, it is always written. Ideas for mods, ports of existing mods and pull requests are welcome.

## Built with

[MinHook](https://github.com/TsudaKageyu/minhook), [Lua](https://github.com/lua/lua), [Dear ImGui](https://github.com/ocornut/imgui), [Chromium Embedded Framework](https://bitbucket.org/chromiumembedded/cef).
