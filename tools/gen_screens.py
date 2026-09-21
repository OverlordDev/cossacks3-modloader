# Таблица экранов игры и тэгов их кнопок для Lua-API модлоадера.
#
#   python tools/gen_screens.py "C:/.../Cossacks 3"
#
# Экран игры — пара состояний GUI: Show<Имя> строит его, Event<Имя> обрабатывает кнопки.
# Кнопки различаются тэгом; сами скрипты объявляют их константами:
#   const cTagCampaign = 101;      (data/gui/menu.inc/eventmainmenu.inc)
#
# Пишет api/02_screens_data.lua (таблица GAME_SCREENS) и GAME_SCREENS.md. Руками не править.
import os
import re
import sys

RE_TAG = re.compile(r"const\s+cTag(\w+)\s*=\s*(\d+)\s*;")
RE_NAME = re.compile(r"^\s*Name\s*=\s*(\w+)", re.M)
COMMON = {"Show": 8001, "Hide": 8002, "Close": 8003}  # gc_gui_event_tag* — есть у всех экранов


def states(folder):
    out = {}
    for name in sorted(os.listdir(folder)):
        if not name.endswith(".inc"):
            continue
        with open(os.path.join(folder, name), encoding="latin-1") as f:
            text = f.read()
        m = RE_NAME.search(text)
        if m:
            out[m.group(1)] = text
    return out


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    game = sys.argv[1] if len(sys.argv) > 1 else "."
    here = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    all_states = states(os.path.join(game, "data", "gui", "menu.inc"))

    screens = {}
    for state in all_states:
        for prefix in ("Show", "Event"):
            if state.startswith(prefix):
                s = screens.setdefault(state[len(prefix):], {"show": None, "event": None, "tags": {}})
                s[prefix.lower()] = state
    for name, s in screens.items():
        tags = {}
        for state in (s["event"], s["show"]):  # имена из Event важнее
            for tname, value in RE_TAG.findall(all_states.get(state) or ""):
                tags.setdefault(tname, int(value))
        if s["event"]:
            for k, v in COMMON.items():
                tags.setdefault(k, v)
        s["tags"] = tags

    lua = ["-- Сгенерировано tools/gen_screens.py из data/gui/menu.inc. Не править руками.",
           "-- screen = { show = 'Show<Имя>', event = 'Event<Имя>', tags = { ИмяКнопки = тэг } }",
           "GAME_SCREENS = {"]
    for name in sorted(screens):
        s = screens[name]
        tags = ", ".join("%s = %d" % (k, v) for k, v in sorted(s["tags"].items(), key=lambda x: x[1]))
        lua.append('  %s = { show = %s, event = %s, tags = { %s } },' % (
            name, '"%s"' % s["show"] if s["show"] else "nil", '"%s"' % s["event"] if s["event"] else "nil", tags))
    lua.append("}")
    with open(os.path.join(here, "api", "02_screens_data.lua"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lua) + "\n")

    md = ["# Экраны игры", "",
          "Сгенерировано `tools/gen_screens.py` из `data/gui/menu.inc`. Не править руками.", "",
          "Экран = `Show<Имя>` (строит) + `Event<Имя>` (кнопки). Работа с ними — `screens.*` (api/15_screens.lua).", "",
          "Тэги Show/Hide/Close (8001–8003) есть у всех экранов с Event-состоянием.", ""]
    for name in sorted(screens):
        s = screens[name]
        md.append("## %s" % name)
        md.append("")
        md.append("`%s` / `%s`" % (s["show"] or "—", s["event"] or "—"))
        md.append("")
        own = [(k, v) for k, v in sorted(s["tags"].items(), key=lambda x: x[1]) if k not in COMMON]
        if own:
            md.append("| кнопка | тэг |")
            md.append("|---|---|")
            for k, v in own:
                md.append("| %s | %d |" % (k, v))
            md.append("")
    with open(os.path.join(here, "GAME_SCREENS.md"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(md) + "\n")

    print("экранов: %d, с кнопками: %d" % (len(screens), sum(1 for s in screens.values() if len(s["tags"]) > 3)))


if __name__ == "__main__":
    main()
