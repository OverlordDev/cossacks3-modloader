#!/usr/bin/env python3
"""Генератор данных для сайта документации.

Парсит api/*.lua (шапки + функции + комменты) и *.md гайды в JSON
для React-приложения tools/docs_site.

  python tools/docs_site/gen.py
"""
import json
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parent.parent.parent
API = ROOT / "api"
APP = pathlib.Path(__file__).resolve().parent / "app"
OUT = APP / "src" / "data"          # маленькое — в бандл
PUB = APP / "public" / "data"       # тяжёлое — fetch по требованию

FUNC = re.compile(r"^function\s+([\w]+)[.:]([\w]+)\s*\(([^)]*)\)")
TABLE = re.compile(r"^([\w]+)\s*=\s*(?:\{|world\s+or\s+\{)")


def parse_lua(path: pathlib.Path) -> dict:
    lines = path.read_text(encoding="utf-8").splitlines()
    header: list[str] = []
    for line in lines:
        if line.startswith("--"):
            header.append(line[2:].strip())
        elif line.strip() == "":
            continue
        else:
            break
    tables: list[str] = []
    funcs: list[dict] = []
    pending: list[str] = []
    for line in lines:
        s = line.strip()
        if s.startswith("--"):
            pending.append(s[2:].strip())
            continue
        m = TABLE.match(s)
        if m and m.group(1) not in tables:
            # только верхнеуровневые таблицы (без отступа)
            if not line.startswith((" ", "\t")):
                tables.append(m.group(1))
            pending = []
            continue
        m = FUNC.match(s)
        if m and not line.startswith((" ", "\t")):
            mod, fn, args = m.group(1), m.group(2), m.group(3).strip()
            funcs.append({"mod": mod, "name": fn, "args": args,
                          "doc": "\n".join(pending).strip()})
        if s != "":
            pending = []
    return {"file": path.name, "header": "\n".join(header).strip(),
            "tables": tables, "functions": funcs}


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    mods = []
    for path in sorted(API.glob("*.lua")):
        if path.name == "00_schema.lua" or path.name == "02_screens_data.lua":
            continue  # generated data, не модули
        info = parse_lua(path)
        if info["tables"] or info["functions"]:
            mods.append(info)
    (OUT / "modules.json").write_text(
        json.dumps(mods, ensure_ascii=False, separators=(",", ":")),
        encoding="utf-8")
    guides = []
    for path in sorted(ROOT.glob("*.md")):
        text = path.read_text(encoding="utf-8")
        title = path.stem
        m = re.search(r"^#\s+(.+)$", text, re.M)
        if m:
            title = m.group(1).strip()
        guides.append({"id": path.stem, "title": title, "md": text})
    PUB.mkdir(parents=True, exist_ok=True)
    (PUB / "guides.json").write_text(
        json.dumps(guides, ensure_ascii=False, separators=(",", ":")),
        encoding="utf-8")
    (PUB / "guides_index.json").write_text(
        json.dumps([{"id": g["id"], "title": g["title"]} for g in guides],
                   ensure_ascii=False, separators=(",", ":")),
        encoding="utf-8")
    total_fns = sum(len(m["functions"]) for m in mods)
    try:
        natives_n = len(json.loads((PUB / "natives.json").read_text(encoding="utf-8")))
    except Exception:
        natives_n = 0
    (PUB / "stats.json").write_text(
        json.dumps({"modules": len(mods), "functions": total_fns,
                    "guides": len(guides), "natives": natives_n},
                   separators=(",", ":")),
        encoding="utf-8")
    print(f"modules: {len(mods)}, guides: {len(guides)}, functions: {total_fns}")


if __name__ == "__main__":
    main()
