#!/usr/bin/env python3
"""Catalog of engine natives: side, risk, category + native.info() for Lua.

Reads Modloader For Cossacks 3/core/NativesTable.inc ({ addr, "decl" }),
mirrors IsClientNative() from core/LuaHost.cpp (keep in sync!),
writes api/57_native_catalog.lua (NATIVE_CATALOG + native.info())
and NATIVE_CATALOG.md (summary for humans).

  python tools/gen_native_catalog.py
"""
import json
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parent.parent
INC = ROOT / "Modloader For Cossacks 3" / "core" / "NativesTable.inc"
OUT_LUA = ROOT / "api" / "57_native_catalog.lua"
OUT_MD = ROOT / "NATIVE_CATALOG.md"
OUT_JSON = ROOT / "tools" / "docs_site" / "app" / "public" / "data" / "natives.json"

ENTRY = re.compile(r'\{\s*(0x[0-9A-Fa-f]+)\s*,\s*"((?:[^"\\]|\\.)*)"\s*\},?')
NAME = re.compile(r'^(?:function|procedure)\s+([A-Za-z_][\w$]*)\s*(\(.*\))?')

# --- mirror of IsClientNative (LuaHost.cpp) ---
READ_PREFIXES = ("Get", "Is", "Has", "Can", "Calc", "Check", "Find", "Count")
READ_EXACT = {"StateMachineGetArgDataByInd", "RayCastHeight"}
VISUAL_EXACT = {
    "GameObjectSetFrameAnimationByHandle", "GameObjectSwitchToFrameAnimationByHandle",
    "GameObjectSwitchToAnimationCyclesByHandle", "GameObjectSwitchToTreeAnimationCyclesByHandle",
    "GameObjectSwitchToFBAnimationCyclesByHandle", "GameObjectSwitchToFrameAnimationBlendByHandle",
    "GameObjectSwitchToAnimationCyclesBlendByHandle", "GameObjectSwitchToTreeAnimationCyclesBlendByHandle",
    "GameObjectSwitchToFBAnimationCyclesBlendByHandle", "GameObjectSwitchToAnimationCyclesDefaultByHandle",
    "GameObjectSwitchToTreeAnimationCyclesDefaultByHandle", "GameObjectSwitchToFBAnimationCyclesDefaultByHandle",
    "SetGameObjectCurrentFrameByHandle", "SetGameObjectActorNameByHandle",
    "SetGameObjectMaterialNameByHandle", "SetGameObjectScaleByHandle",
    "SetGameObjectVisibleByHandle", "GameObjectRotateAbsoluteByHandle", "GameObjectPointToByHandle",
    "SetGameObjectAnimationCyclesModeByHandle", "SetGameObjectAnimationCyclesListByHandle",
    "SetGameObjectFrameAnimationSynchronizeOptionByHandle", "SetGameObjectActorIndexByHandle",
    "GameObjectResetFrameAnimationBlend",
}
QUERY_EXACT = {"TopologyGetPathDistance", "GroupGetFindPathByHandle", "RayCastTerrain"}


def is_client(name: str) -> bool:
    if name in READ_EXACT:
        return True
    if name.startswith(READ_PREFIXES):
        return True
    if "ExecuteState" in name or "DelayExecute" in name or "TimeExec" in name:
        return False
    if "GUI" in name:
        return True
    if "Camera" in name:
        return True
    if "Decal" in name:
        return True
    if "PFX" in name or name.startswith("Effect") or "EffectHighlight" in name:
        return True
    if name in VISUAL_EXACT:
        return True
    if "CalcPath" in name or name in QUERY_EXACT:
        return True
    if name.startswith("DebugText") or name.startswith("DebugDraw"):
        return True
    if name.startswith(("Snd", "SetSnd", "GetSnd")):
        return True
    return False


FORBIDDEN = ("CreateFunction", "AddProcAddress", "AddrToPointer", "CloseFileStream",
             "DeleteFileStream", "ClearPlayers", "DeletePlayer", "FastClearPlayers",
             "PathDataThread", "Steamwrap", "Editor")


def category(name: str) -> str:
    n = name
    checks = [
        ("camera", "Camera"), ("minimap", "MiniMap"), ("gui", "GUI"),
        ("effect", "Effect"), ("pfx", "PFX"), ("decal", "Decal"),
        ("sound", "Snd"), ("anim", "Animation"), ("actor", "Actor"),
        ("group", "Group"), ("order", "Order"), ("path", "Path"),
        ("topology", "Topology"), ("terrain", "Terrain"), ("fow", "FOW"),
        ("fog", "Fog"), ("weather", "Weather"), ("wind", "Wind"),
        ("water", "Water"), ("sky", "Sky"), ("cloud", "Cloud"),
        ("light", "Light"), ("shadow", "Shadow"), ("player", "Player"),
        ("weapon", "Weapon"), ("projectile", "Projectile"), ("behaviour", "Behaviour"),
        ("state", "State"), ("track", "TrackNode"), ("debug", "Debug"),
        ("save", "Save"), ("replay", "Replay"), ("net", "Lan"),
        ("chat", "Message"), ("locale", "Locale"), ("cam", None),
    ]
    for cat, pat in checks:
        if pat and pat in n:
            return cat
    if "GameObject" in n or "Unit" in n or "Obj" in n:
        return "object"
    return "misc"


def risk(name: str, client: bool) -> str:
    if name.startswith(FORBIDDEN):
        return "forbidden"
    if not client:
        return "world"
    if (name in VISUAL_EXACT or "Camera" in name or "Decal" in name
            or "PFX" in name or name.startswith("Effect")
            or name.startswith(("DebugText", "DebugDraw"))
            or name.startswith(("Snd", "SetSnd", "GetSnd")) or "GUI" in name):
        return "visual"
    return "read"


# native -> "module.fn" for the most useful wrapped natives
WRAPPED = {
    "SetMainCameraPositionXZ": "camera.position", "SetMainCameraRotateXYZ": "camera.rotate",
    "GetCameraAbsolutePosition": "camera.pos", "GetCameraTargetPosition": "camera.target",
    "SetGUIMiniMapVisible": "minimap.show", "SetGUIMinimapZoom": "minimap.zoom",
    "CreateGUIMiniMapPrimitive": "minimap.icon",
    "GameObjectSetFrameAnimationByHandle": "animation.play",
    "GameObjectSwitchToAnimationCyclesByHandle": "animation.cycle",
    "SetGameObjectScaleByHandle": "model.scale", "SetGameObjectVisibleByHandle": "model.show",
    "EffectCreateWithKey": "effects.create", "PutDecalByName": "decals.put",
    "CreatePlayerGameObjectHandleByHandle": "world.spawn",
    "GameObjectDestroyByHandle": "world.destroyNow", "SetGameObjectPositionByHandle": "world.move",
    "GameObjectSwitchToStateByHandle": "object.setState",
    "GameObjectCalcPathByHandle": "pathfind.calculate",
    "TopologyGetPathDistance": "pathfind.distance",
    "RaiseTerrain": "terrain.raise", "LowerTerrain": "terrain.lower",
    "SetFOWEnable": "fow.enable", "AddFOWObjects": "fow.revealObject",
    "DebugTextWrite": "dbg.text", "DebugDrawLine": "dbg.line",
    "RayCastTerrain": "dbg.ray", "SetTimeSpeedFactor": "time.speed",
    "SndGetOrCreateSound": "sound.get",
    "BehaviourCreate": "behaviour.create", "BehaviourInertiaApplyForce": "behaviour.force",
    "CreateGroupByPlHandle": "group.create", "GroupAddGameObjectByHandle": "group.add",
    "AddTrackNode": "tracks.add", "ConnectTrackNodesByHandle": "tracks.connect",
    "CreateSnapShotExt": "scenario.snapshot", "BeginPlayingCurrentScenario": "scenario.begin",
}


def main() -> None:
    text = INC.read_text(encoding="utf-8", errors="replace")
    entries = []
    for m in ENTRY.finditer(text):
        addr, decl = m.group(1), m.group(2)
        nm = NAME.match(decl)
        if not nm:
            continue
        name = nm.group(1)
        client = is_client(name)
        entries.append({
            "name": name, "addr": addr, "decl": decl,
            "side": "client" if client else "server",
            "risk": risk(name, client), "cat": category(name),
            "wrap": WRAPPED.get(name, ""),
        })
    entries.sort(key=lambda e: e["name"])
    by_side = {"client": 0, "server": 0}
    by_risk: dict[str, int] = {}
    by_cat: dict[str, int] = {}
    for e in entries:
        by_side[e["side"]] += 1
        by_risk[e["risk"]] = by_risk.get(e["risk"], 0) + 1
        by_cat[e["cat"]] = by_cat.get(e["cat"], 0) + 1

    def esc(s: str) -> str:
        return s.replace("\\", "\\\\").replace('"', '\\"')

    lua = []
    lua.append("-- NATIVE_CATALOG — сгенерировано tools/gen_native_catalog.py, НЕ ПРАВИТЬ ВРУЧНУЮ.")
    lua.append("-- Источник: core/NativesTable.inc. Правила стороны — зеркало IsClientNative")
    lua.append("-- (core/LuaHost.cpp): расхождение лечится в генераторе, не здесь.")
    lua.append(f"-- Записей: {len(entries)}, client: {by_side['client']}, server: {by_side['server']}.")
    lua.append("")
    lua.append("-- native.info(\"GameObjectSetFrameAnimationByHandle\")")
    lua.append('--   --> { addr=, decl=, side="client", risk="visual", cat="anim", wrappedBy="animation.play" }')
    lua.append("-- risk: read (только чтение) | visual (картинка у себя) | world (меняет мир: server/shared)")
    lua.append("--   | forbidden (НИКОГДА не открывать на client: файлы/память/потоки/плееры).")
    lua.append("")
    lua.append("NATIVE_CATALOG = {")
    for e in entries:
        lua.append(f'  ["{e["name"]}"] = {{ "{e["addr"]}", "{esc(e["decl"])}", '
                   f'"{e["side"]}", "{e["risk"]}", "{e["cat"]}", "{e["wrap"]}" }},')
    lua.append("}")
    lua.append("")
    lua.append("function native.info(name)")
    lua.append("    local e = NATIVE_CATALOG[tostring(name)]")
    lua.append("    if not e then return nil end")
    lua.append("    return { addr = e[1], decl = e[2], side = e[3], risk = e[4],")
    lua.append("             category = e[5], wrappedBy = e[6] ~= '' and e[6] or nil }")
    lua.append("end")
    lua.append("")
    lua.append("function native.catalogStats()")
    lua.append(f"    return {{ total = {len(entries)}, client = {by_side['client']}, "
               f"server = {by_side['server']} }}")
    lua.append("end")
    lua.append("")
    OUT_LUA.write_text("\n".join(lua) + "\n", encoding="utf-8")

    md = []
    md.append("# NATIVE_CATALOG — все нативы движка со стороной и риском")
    md.append("")
    md.append(f"Всего: **{len(entries)}** (client: {by_side['client']}, server-only: {by_side['server']}).")
    md.append("Сгенерировано `tools/gen_native_catalog.py` из `core/NativesTable.inc`.")
    md.append("")
    md.append("## Риск")
    for k in ("read", "visual", "world", "forbidden"):
        md.append(f"- `{k}`: {by_risk.get(k, 0)}")
    md.append("")
    md.append("## Категории (топ)")
    for k, v in sorted(by_cat.items(), key=lambda kv: -kv[1])[:20]:
        md.append(f"- `{k}`: {v}")
    md.append("")
    md.append("## Forbidden (никогда на client)")
    for e in entries:
        if e["risk"] == "forbidden":
            md.append(f"- `{e['name']}` ({e['addr']})")
    md.append("")
    OUT_MD.write_text("\n".join(md) + "\n", encoding="utf-8")
    OUT_JSON.parent.mkdir(parents=True, exist_ok=True)
    OUT_JSON.write_text(json.dumps(
        [{"n": e["name"], "a": e["addr"], "d": e["decl"],
          "s": e["side"], "r": e["risk"], "c": e["cat"], "w": e["wrap"]}
         for e in entries],
        ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    print(f"natives: {len(entries)}, client {by_side['client']}, "
          f"server {by_side['server']}, forbidden {by_risk.get('forbidden', 0)}")


if __name__ == "__main__":
    main()
