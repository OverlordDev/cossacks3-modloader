#!/usr/bin/env python3
"""Генератор сайта-документации в docs/ (для GitHub Pages).

Источники (ничего не переписывается руками — всё берётся из репозитория):
  api/*.lua                    шапки модулей, список функций, исходники
  api/README.md                обзор api
  MODDING.md                   быстрый старт
  AI_MODDING_REFERENCE.md      справочник ядра (Lua API движка), режется по разделам
  GAME_STATE.md, GAME_SCREENS.md  справочники данных игры

Запуск:
  python gen_docs.py --repo <путь к клону cossacks3-modloader> --out <куда писать сайт>
Без аргументов: репозиторий — родитель папки со скриптом, результат — <репозиторий>/docs.
Зависимостей нет (только стандартная библиотека). Результат — статический сайт: docs/*.html.
"""

import html
import json
import re
import shutil
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent  # корень репозитория с api/ и справочниками (--repo)
OUT = ROOT / "docs"  # куда писать сайт (--out)
SITE = HERE / "docs_site"  # стили и скрипт сайта лежат рядом с генератором
REPO = "https://github.com/OverlordDev/cossacks3-modloader"
BLOB = REPO + "/blob/master/"
SITE_NAME = "COSSACKS 3 MODLOADER"

# --------------------------------------------------------------------------------------------------
# Markdown -> HTML (минимальный, под наши документы)
# --------------------------------------------------------------------------------------------------


def slugify(text):
    text = re.sub(r"`", "", text.lower())
    text = re.sub(r"[^\w\- ]", "", text, flags=re.UNICODE).strip()
    return re.sub(r"[\s]+", "-", text) or "section"


class Md:
    """Рендер markdown. link_map(target, base_dir) -> href для ссылок на другие файлы репозитория."""

    def __init__(self, link_map, src_dir="", shift=0):
        self.link_map = link_map
        self.src_dir = src_dir
        self.shift = shift
        self.headings = []  # (level, id, text)
        self.used_ids = set()

    # ---- inline
    def inline(self, text):
        stash = []

        def keep(m):
            stash.append("<code>%s</code>" % html.escape(m.group(1), quote=False))
            return "\x00%d\x00" % (len(stash) - 1)

        text = re.sub(r"`([^`]+)`", keep, text)
        text = html.escape(text, quote=False)
        text = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", text)
        text = re.sub(r"(?<![\w*])\*([^*\s][^*]*?)\*(?![\w*])", r"<em>\1</em>", text)

        def link(m):
            label, href = m.group(1), html.unescape(m.group(2))
            return '<a href="%s">%s</a>' % (html.escape(self.resolve(href), quote=True), label)

        text = re.sub(r"\[([^\]]+)\]\(([^)\s]+)\)", link, text)
        return re.sub(r"\x00(\d+)\x00", lambda m: stash[int(m.group(1))], text)

    def resolve(self, href):
        if re.match(r"^(https?:|mailto:|#)", href):
            return href
        path, _, frag = href.partition("#")
        mapped = self.link_map(path, self.src_dir)
        return mapped + ("#" + frag if frag else "")

    # ---- blocks
    def heading_id(self, text):
        base = slugify(text)
        hid, n = base, 2
        while hid in self.used_ids:
            hid = "%s-%d" % (base, n)
            n += 1
        self.used_ids.add(hid)
        return hid

    @staticmethod
    def split_row(line):
        line = line.strip()
        if line.startswith("|"):
            line = line[1:]
        if line.endswith("|") and not line.endswith("\\|"):
            line = line[:-1]
        cells, cur, in_code, i = [], "", False, 0
        while i < len(line):
            ch = line[i]
            if ch == "`":
                in_code = not in_code
            if ch == "\\" and i + 1 < len(line) and line[i + 1] == "|":
                cur += "|"
                i += 2
                continue
            if ch == "|" and not in_code:
                cells.append(cur.strip())
                cur = ""
            else:
                cur += ch
            i += 1
        cells.append(cur.strip())
        return cells

    def render(self, text):
        lines = text.replace("\r\n", "\n").split("\n")
        out = []
        i, n = 0, len(lines)
        while i < n:
            line = lines[i]
            if not line.strip():
                i += 1
                continue
            m = re.match(r"^```\s*(\w*)", line)
            if m:
                lang = m.group(1) or "lua"
                i += 1
                buf = []
                while i < n and not lines[i].startswith("```"):
                    buf.append(lines[i])
                    i += 1
                i += 1
                out.append('<pre><code data-lang="%s">%s</code></pre>' % (lang, html.escape("\n".join(buf), quote=False)))
                continue
            m = re.match(r"^(#{1,6})\s+(.*?)\s*#*\s*$", line)
            if m:
                level = max(1, len(m.group(1)) + self.shift)
                raw = m.group(2)
                plain = re.sub(r"[`*]", "", raw)
                if level == 1:
                    out.append("<h1>%s</h1>" % self.inline(raw))
                else:
                    hid = self.heading_id(plain)
                    self.headings.append((level, hid, plain))
                    out.append('<h%d id="%s" data-t="%s">%s<a class="h-anchor" href="#%s">#</a></h%d>' % (
                        level, hid, html.escape(plain, quote=True), self.inline(raw), hid, level))
                i += 1
                continue
            if re.match(r"^\s*(-{3,}|\*{3,})\s*$", line):
                out.append("<hr>")
                i += 1
                continue
            if line.lstrip().startswith("|") and i + 1 < n and re.match(r"^\s*\|?\s*:?-{2,}", lines[i + 1]):
                head = self.split_row(line)
                i += 2
                rows = []
                while i < n and lines[i].lstrip().startswith("|"):
                    rows.append(self.split_row(lines[i]))
                    i += 1
                t = ['<div class="tblwrap"><table><thead><tr>']
                t += ["<th>%s</th>" % self.inline(c) for c in head]
                t.append("</tr></thead><tbody>")
                for r in rows:
                    r = (r + [""] * len(head))[: max(len(head), len(r))]
                    t.append("<tr>" + "".join("<td>%s</td>" % self.inline(c) for c in r) + "</tr>")
                t.append("</tbody></table></div>")
                out.append("".join(t))
                continue
            if line.startswith(">"):
                buf = []
                while i < n and lines[i].startswith(">"):
                    buf.append(lines[i].lstrip(">").strip())
                    i += 1
                out.append("<blockquote>%s</blockquote>" % self.inline(" ".join(buf)))
                continue
            if re.match(r"^\s*([-*]|\d+\.)\s+", line):
                html_list, i = self.list_block(lines, i, len(line) - len(line.lstrip()))
                out.append(html_list)
                continue
            buf = []
            while i < n and lines[i].strip() and not re.match(r"^(```|#{1,6}\s|>|\s*([-*]|\d+\.)\s+|\s*\|)", lines[i]):
                buf.append(lines[i].strip())
                i += 1
            if not buf:  # защита от зацикливания на неожиданной строке
                buf.append(lines[i].strip())
                i += 1
            out.append("<p>%s</p>" % self.inline(" ".join(buf)))
        return "\n".join(out)

    def list_block(self, lines, i, indent):
        n = len(lines)
        ordered = bool(re.match(r"^\s*\d+\.", lines[i]))
        items = []
        while i < n:
            line = lines[i]
            m = re.match(r"^(\s*)([-*]|\d+\.)\s+(.*)$", line)
            if not m or len(m.group(1)) != indent:
                break
            body = [m.group(3)]
            i += 1
            sub = ""
            while i < n and lines[i].strip():
                nxt = lines[i]
                mm = re.match(r"^(\s*)([-*]|\d+\.)\s+", nxt)
                if mm and len(mm.group(1)) > indent:
                    sub, i = self.list_block(lines, i, len(mm.group(1)))
                    continue
                if mm and len(mm.group(1)) <= indent:
                    break
                body.append(nxt.strip())
                i += 1
            items.append("<li>%s%s</li>" % (self.inline(" ".join(body)), sub))
            while i < n and not lines[i].strip() and i + 1 < n and re.match(r"^(\s*)([-*]|\d+\.)\s+", lines[i + 1]) \
                    and len(re.match(r"^(\s*)", lines[i + 1]).group(1)) == indent:
                i += 1
        tag = "ol" if ordered else "ul"
        return "<%s>%s</%s>" % (tag, "".join(items), tag), i


# --------------------------------------------------------------------------------------------------
# Разбор api/*.lua
# --------------------------------------------------------------------------------------------------

GENERATED = {"00_schema": "schema", "02_screens_data": "screens_data"}


def read(path):
    return Path(path).read_text(encoding="utf-8-sig")


def header_comment(src):
    """Первый блок комментариев файла -> список строк без '-- '."""
    out = []
    for line in src.split("\n"):
        if line.startswith("--"):
            out.append(line[2:][1:] if line[2:3] == " " else line[2:])
        elif not line.strip() and not out:
            continue
        else:
            break
    return out


def header_to_html(lines, md):
    """Проза + код: строки с отступом от 2 пробелов (после '-- ') — код."""
    blocks, prose, code = [], [], []

    def flush_prose():
        if prose:
            blocks.append("<p>%s</p>" % md.inline(" ".join(prose)))
            prose.clear()

    def flush_code():
        if code:
            while code and not code[-1].strip():
                code.pop()
            indent = min((len(c) - len(c.lstrip()) for c in code if c.strip()), default=0)
            text = "\n".join(c[indent:] for c in code)
            blocks.append('<pre><code data-lang="lua">%s</code></pre>' % html.escape(text, quote=False))
            code.clear()

    for line in lines[1:]:  # первая строка — заголовок модуля
        stripped = line.strip()
        if not stripped:
            if code:
                code.append("")
            else:
                flush_prose()
            continue
        if line.startswith("  ") or line.startswith("\t"):
            flush_prose()
            code.append(line)
        else:
            if code:
                # «ЗАГОЛОВОК:» после примеров начинает новый раздел
                flush_code()
            head = re.match(r"^([А-ЯЁA-Z][А-ЯЁA-Z0-9 /«»,\-]{3,}?)(\s*\(.*\))?:?$", stripped)
            if head and len(stripped) < 90:
                flush_prose()
                note = ' <small style="text-transform:none;letter-spacing:0;opacity:.7">%s</small>' % md.inline(head.group(2).strip()) if head.group(2) else ""
                blocks.append("<h3>%s%s</h3>" % (html.escape(head.group(1).strip().capitalize()), note))
            else:
                prose.append(stripped)
    flush_prose()
    flush_code()
    return "\n".join(blocks)


FUNC_RE = re.compile(r"^function\s+([A-Za-z_][\w]*(?:[.:][A-Za-z_]\w*)*)\s*\(([^)]*)\)(.*)$")


REF_EXAMPLES = {}  # имя функции -> (строка кода, комментарий) из блоков кода справочника


def collect_reference_examples(text):
    in_code = False
    for line in text.split("\n"):
        if line.startswith("```"):
            in_code = not in_code
            continue
        if not in_code:
            continue
        m = re.match(r"^\s*(?:local\s+\w+\s*=\s*)?([A-Za-z_]\w*(?:[.:][A-Za-z_]\w*)*)\s*\((.*?)\)\s*(--.*)?$", line)
        if m and m.group(3):
            REF_EXAMPLES.setdefault(m.group(1).replace(":", "."), (line.strip(), m.group(3)))


def comment_to_text(comment):
    if comment.startswith("-->"):
        return "Возвращает: " + comment[3:].strip()
    return comment.lstrip("-").strip()


def parse_functions(src, header_lines):
    """Функции верхнего уровня: имя, аргументы, описание, пример из шапки."""
    header_examples = {}
    for line in header_lines:
        if not (line.startswith("  ") or line.startswith("\t")):
            continue
        code = line.strip()
        m = re.match(r"^([A-Za-z_]\w*(?:[.:][A-Za-z_]\w*)*)\s*\(", code)
        if m:
            name = m.group(1).replace(":", ".")
            header_examples.setdefault(name, code)

    funcs, lines = [], src.split("\n")
    for idx, line in enumerate(lines):
        m = FUNC_RE.match(line)
        if not m:
            continue
        name, args, tail = m.group(1), m.group(2).strip(), m.group(3)
        desc = []
        j = idx - 1
        while j >= 0 and lines[j].startswith("--"):
            desc.insert(0, lines[j][2:].strip())
            j -= 1
        inline = re.search(r"--\s*(.+)$", tail)
        text = " ".join(d for d in desc if d)
        if not text and inline:
            text = inline.group(1).strip()
        key = name.replace(":", ".")
        example = header_examples.get(key)
        if not text and example:
            trailing = re.search(r"(-->|--)\s*(.+)$", example)
            if trailing:
                text = comment_to_text(trailing.group(1) + " " + trailing.group(2))
        if key in REF_EXAMPLES:
            ref_code, ref_comment = REF_EXAMPLES[key]
            if not text:
                text = comment_to_text(ref_comment)
            if not example:
                example = ref_code
        funcs.append({"name": name, "args": args, "desc": text, "example": example})
    return funcs


# --------------------------------------------------------------------------------------------------
# Сборка страниц
# --------------------------------------------------------------------------------------------------

PAGES = []  # порядок = порядок навигации: dict(id, file, title, label, group, body, src, toc, heads)
SEARCH = []


def add_page(pid, title, label, group, body, src=None, headings=None, summary="", toc=True):
    PAGES.append({
        "id": pid, "file": pid + ".html", "title": title, "label": label, "group": group,
        "body": body, "src": src, "headings": headings or [], "summary": summary, "toc": toc,
    })


def link_map_factory(known):
    """Ссылки на файлы репозитория -> страницы сайта или GitHub."""
    def link_map(path, src_dir):
        if not path:
            return ""
        norm = (Path(src_dir) / path).as_posix() if src_dir else path
        parts = []
        for p in norm.split("/"):
            if p == "..":
                if parts:
                    parts.pop()
            elif p and p != ".":
                parts.append(p)
        norm = "/".join(parts)
        if norm in known:
            return known[norm]
        m = re.match(r"^api/(\d+_)?(\w+)\.lua$", norm)
        if m and ("api/" + (m.group(1) or "") + m.group(2) + ".lua") in known:
            return known["api/" + (m.group(1) or "") + m.group(2) + ".lua"]
        return BLOB + norm
    return link_map


def build():
    known = {
        "MODDING.md": "guide.html",
        "AI_MODDING_REFERENCE.md": "core-rules.html",
        "GAME_STATE.md": "ref-state.html",
        "GAME_SCREENS.md": "ref-screens.html",
        "api/README.md": "api-overview.html",
    }
    api_files = sorted((ROOT / "api").glob("*.lua"))
    modules = []
    for f in api_files:
        m = re.match(r"^(\d+)_(\w+)$", f.stem)
        name = m.group(2) if m else f.stem
        known["api/" + f.name] = "api-%s.html" % name
        modules.append((f, name))
    link_map = link_map_factory(known)

    # ---- НАЧАЛО
    home_placeholder = {"id": "index"}  # главная строится отдельно, после подсчёта статистики

    md = Md(link_map, "")
    guide_src = read(ROOT / "MODDING.md")
    body = md.render(guide_src)
    add_page("guide", "Быстрый старт", "Быстрый старт", "НАЧАЛО", body, "MODDING.md", md.headings,
             "Как сделать первый мод: структура, manifest.lua, события, главные функции.")

    md = Md(link_map, "api")
    body = md.render(read(ROOT / "api" / "README.md"))
    add_page("api-overview", "Обзор api", "Обзор api/", "НАЧАЛО", body, "api/README.md", md.headings,
             "Что лежит в папке api, как вызывать из Lua и из страниц, как добавить модуль.")

    # ---- СПРАВОЧНИК ЯДРА (AI_MODDING_REFERENCE.md)
    ref = read(ROOT / "AI_MODDING_REFERENCE.md")
    collect_reference_examples(ref)
    sections = split_reference(ref)
    core_slugs = {"0": "rules", "1": "structure", "2": "manifest", "3": "sides", "5": "assets", "6": "patches",
                  "6а": "content", "7": "templates", "8": "errors"}
    lua_api_slugs = {}
    used = set()
    for sec in sections:
        num = sec["num"]
        if sec["kind"] == "h2":
            slug = core_slugs.get(num)
            if not slug:
                continue
            md = Md(link_map, "", shift=-1)
            body = md.render(sec["text"])
            title = sec["title"]
            add_page("core-" + slug, title, title.split(" — ")[0], "СПРАВОЧНИК", body, "AI_MODDING_REFERENCE.md",
                     md.headings, first_sentence(sec["text"]))
        else:
            ascii_word = re.search(r"[A-Za-z_]+", sec["title"])
            slug = (ascii_word.group(0).lower() if ascii_word else "misc")
            base, k = slug, 2
            while slug in used:
                slug = "%s%d" % (base, k)
                k += 1
            used.add(slug)
            lua_api_slugs[num] = slug
            md = Md(link_map, "", shift=-2)
            body = md.render(sec["text"])
            add_page("core-" + slug, sec["title"], sec["title"].split(" — ")[0].split(" (")[0], "LUA API ДВИЖКА", body,
                     "AI_MODDING_REFERENCE.md", md.headings, first_sentence(sec["text"]))

    # ---- МОДУЛИ API
    total_funcs = 0
    module_cards = []
    fn_names = []
    for f, name in modules:
        src = read(f)
        header = header_comment(src)
        title_line = header[0] if header else name
        m = re.match(r"^\s*([\w.]+)\s+[—-]\s+(.*)$", title_line)
        summary = (m.group(2) if m else title_line).strip()
        md = Md(link_map, "api")
        page_id = "api-" + name
        if f.stem in GENERATED:
            body = generated_page(f, name, src, md)
            add_page(page_id, name, name, "МОДУЛИ API", body, "api/" + f.name, [], summary)
            module_cards.append((name, page_id, summary, 0, True))
            continue
        funcs = parse_functions(src, header)
        total_funcs += len(funcs)
        add_page(page_id, name, name, "МОДУЛИ API", module_body(f, name, src, header, funcs, md, summary),
                 "api/" + f.name, [(2, "opisanie", "Описание")] + ([(2, "funkcii", "Функции")] if funcs else [])
                 + [(2, "istochnik", "Исходник")], summary)
        module_cards.append((name, page_id, summary, len(funcs), False))
        for fn in funcs:
            fn_names.append(fn["name"])
            SEARCH.append({"t": fn["name"] + "()", "s": "api/" + name, "d": (fn["desc"] or "")[:110],
                           "u": "%s.html#f-%s" % (page_id, fn_anchor(fn["name"])), "k": "fn",
                           "x": (fn["desc"] + " " + fn["args"]).lower()})

    # ---- ДАННЫЕ ИГРЫ
    md = Md(link_map, "", shift=0)
    state_src = read(ROOT / "GAME_STATE.md")
    body = md.render(state_src)
    add_page("ref-state", "Состояние игры", "Переменные и типы", "ДАННЫЕ ИГРЫ", body, "GAME_STATE.md", md.headings,
             "Все глобальные переменные и типы скриптов игры: поля, размеры, вложенность.", toc=False)
    md = Md(link_map, "", shift=0)
    screens_src = read(ROOT / "GAME_SCREENS.md")
    body = md.render(screens_src)
    add_page("ref-screens", "Экраны игры", "Экраны и кнопки", "ДАННЫЕ ИГРЫ", body, "GAME_SCREENS.md", md.headings,
             "Экраны интерфейса игры, их состояния и тэги кнопок.", toc=False)

    # ---- статистика для главной
    natives = re.search(r"Всего нативов:\s*\*\*(\d+)\*\*", read(ROOT / "GAME_API.md"))
    stats = {
        "modules": sum(1 for c in module_cards if not c[4]),
        "functions": total_funcs,
        "screens": len(re.findall(r"^## ", screens_src, re.M)),
        "natives": int(natives.group(1)) if natives else 0,
        "types": len(re.findall(r"^### ", state_src, re.M)),
    }
    guide_code = {
        "client": 'input.bind("F7", function()\n    if not game.isInGame() then return end\n    local me = native.GetPlayerIndexInterfaceIO()\n    local total, count = 0, 0\n    for _, h in ipairs(objects.list(me)) do\n        local o = objects.read(h)\n        if o and not o.bdead then total, count = total + o.hp, count + 1 end\n    end\n    log.info(string.format("объектов: %d, HP всего: %d", count, total))\nend)',
        "shared": 'events.on("game.start", function()\n    balance.setHP("musketeer18", 200)\n    balance.setDamage("musketeer18", 40, 1)   -- оружие 1 — выстрел\n    balance.set("musketeer18", "price[3]", 30) -- цена в золоте\nend)',
        "server": 'net.on("give_gold", function(data, from)\n    local who = game.playerIndexOf(from)\n    local amount = math.min(tonumber(data and data.amount) or 0, 1000)\n    player(who):add("gold", amount)\n    net.broadcast("gold_given", { player = who, amount = amount })\nend)',
    }
    home = home_page(stats, module_cards, guide_code, fn_names)
    PAGES.insert(0, {"id": "index", "file": "index.html", "title": "Документация API", "label": "Главная",
                     "group": "НАЧАЛО", "body": home, "src": None, "headings": [], "summary": "", "toc": False, "home": True})

    # ---- поиск по заголовкам
    for p in PAGES:
        if p.get("home"):
            continue
        SEARCH.append({"t": p["title"], "s": p["group"].title(), "d": p["summary"][:110], "u": p["file"], "k": "page",
                       "x": (p["summary"] + " " + p["label"]).lower()})
        for level, hid, text in p["headings"]:
            if p["id"].startswith("api-") and hid in ("opisanie", "funkcii", "istochnik"):
                continue
            SEARCH.append({"t": text, "s": p["title"], "d": "", "u": "%s#%s" % (p["file"], hid), "k": "h", "x": ""})
    return stats


def fn_anchor(name):
    return re.sub(r"[^\w]+", "-", name)


def first_sentence(md_text):
    for line in md_text.split("\n")[1:]:
        s = line.strip()
        if s and not s.startswith(("#", "|", "```", ">", "-", "*")) and len(s) > 25:
            s = re.sub(r"[`*]", "", s)
            return s[:160]
    return ""


def split_reference(text):
    """Режет справочник: '## N. …' — раздел; в разделе 4 каждый '### 4.x' отдельной страницей."""
    lines = text.split("\n")
    sections, cur = [], None

    def close():
        nonlocal cur
        if cur:
            cur["text"] = "\n".join(cur["lines"]).strip()
            sections.append(cur)
        cur = None

    in_code = False
    for line in lines:
        if line.startswith("```"):
            in_code = not in_code
        m2 = None if in_code else re.match(r"^## (\d+[а-я]?)\.\s+(.*)$", line)
        m3 = None if in_code else re.match(r"^### (4\.\d+[а-я]?)\.\s+(.*)$", line)
        if m2:
            close()
            if m2.group(1) == "4":
                cur = None
                continue
            title = re.sub(r"`", "", m2.group(2))
            cur = {"kind": "h2", "num": m2.group(1), "title": title, "lines": ["## " + m2.group(2)]}
        elif m3:
            close()
            title = re.sub(r"`", "", m3.group(2))
            cur = {"kind": "h3", "num": m3.group(1), "title": title, "lines": ["### " + m3.group(2)]}
        elif cur is not None:
            if not in_code and re.match(r"^---\s*$", line):
                continue
            cur["lines"].append(line)
    close()
    return sections


def generated_page(f, name, src, md):
    first = src.split("\n")[0].lstrip("- ").strip()
    if f.stem == "00_schema":
        types = len(re.findall(r"^    (\w+) = \{", src, re.M))
        extra = "<p>В схеме описано типов (записей) скриптов игры: <strong>%d</strong>.</p>" % types
        link = '<a class="btn black" href="ref-state.html">ПЕРЕМЕННЫЕ И ТИПЫ →</a>'
    else:
        screens = len(re.findall(r"^  (\w+) = \{ show", src, re.M))
        extra = "<p>Описано экранов: <strong>%d</strong>.</p>" % screens
        link = '<a class="btn black" href="ref-screens.html">ЭКРАНЫ И КНОПКИ →</a>'
    return (
        "<h1>%s</h1><p class=\"lead\">Файл генерируется, руками не правится.</p>"
        "<div class=\"meta\"><span class=\"badge fill\">GENERATED</span><a class=\"badge\" href=\"%sapi/%s\">api/%s</a></div>"
        "<p>%s</p>%s"
        "<p>Человекочитаемая версия этих данных — в справочнике. Обновить после патча игры: "
        "<code>python tools/gen_game_api.py &lt;папка игры&gt;</code>.</p><p>%s</p>"
    ) % (html.escape(name), BLOB, f.name, f.name, html.escape(first), extra, link)


def module_body(f, name, src, header, funcs, md, summary):
    parts = ["<h1>%s</h1>" % html.escape(name), '<p class="lead">%s</p>' % md.inline(summary)]
    parts.append('<div class="meta"><span class="badge fill">api/%s</span><span class="badge">%d функций</span>'
                 '<a class="badge" href="%sapi/%s">GITHUB ↗</a></div>' % (f.name, len(funcs), BLOB, f.name))
    parts.append('<h2 id="opisanie" data-t="Описание">Описание</h2>')
    parts.append(header_to_html(header, md) or "<p>Описание в шапке файла не оформлено — смотрите исходник ниже.</p>")
    if funcs:
        parts.append('<h2 id="funkcii" data-t="Функции">Функции</h2>')
        parts.append('<div class="tblwrap"><table class="fn"><thead><tr><th>ФУНКЦИЯ</th><th>ОПИСАНИЕ</th></tr></thead><tbody>')
        for fn in funcs:
            sig = "%s(%s)" % (fn["name"], html.escape(fn["args"]).replace(", ", ",<wbr> "))
            ex = ""
            if fn["example"]:
                ex = '<span class="ex"><code>%s</code></span>' % html.escape(fn["example"], quote=False)
            desc = md.inline(fn["desc"]) if fn["desc"] else '<span style="opacity:.55">—</span>'
            parts.append('<tr id="f-%s"><td><code>%s</code></td><td>%s%s</td></tr>' % (fn_anchor(fn["name"]), sig, desc, ex))
        parts.append("</tbody></table></div>")
    parts.append('<h2 id="istochnik" data-t="Исходник">Исходник</h2>')
    parts.append('<div class="acc"><div class="acc-head"><span>api/%s — %d строк</span><span>+</span></div>'
                 '<div class="acc-body"><pre><code data-lang="lua">%s</code></pre></div></div>'
                 % (f.name, src.count("\n") + 1, html.escape(src, quote=False)))
    return "\n".join(parts)


def home_page(stats, cards, code, fn_names):
    marquee = "".join("<span>%s()</span>" % html.escape(n) for n in fn_names[:60])
    card_html = "".join(
        '<a class="card rv" href="%s.html"><b>%s</b><span>%s</span><em>%s →</em></a>'
        % (pid, html.escape(name), html.escape(summary[:120]),
           ("%d ФУНКЦИЙ" % cnt) if cnt else "ДАННЫЕ")
        for name, pid, summary, cnt, gen in cards)
    tabs = "".join('<button class="%s">%s</button>' % ("active" if i == 0 else "", t.upper())
                   for i, t in enumerate(("client", "shared", "server")))
    panes = "".join('<div class="tabpane%s"><pre><code data-lang="lua">%s</code></pre></div>'
                    % (" active" if i == 0 else "", html.escape(code[k], quote=False))
                    for i, k in enumerate(("client", "shared", "server")))
    faq = [
        ("Как установить модлоадер?",
         "<ol><li>Собрать решение <code>Modloader For Cossacks 3.slnx</code> (Release, x86).</li>"
         "<li>Скопировать в папку игры <code>Cossacks3Launcher.exe</code>, <code>Cossacks3Loader.dll</code>, основную DLL и <code>Cossacks3Cef.exe</code>.</li>"
         "<li>Поставить CEF: <code>python tools/install_cef.py</code>.</li>"
         "<li>Скопировать <code>api/</code> в <code>&lt;игра&gt;/modloader/api/</code>, моды — в <code>modloader/mods/</code>.</li>"
         "<li>Запускать через <code>Cossacks3Launcher.exe</code>.</li></ol>"),
        ("Где лежат моды?",
         "<p><code>&lt;игра&gt;/modloader/mods/&lt;папка мода&gt;/</code> — внутри обязательно <code>manifest.lua</code>. "
         "Мод может быть только из данных: одни <code>assets/</code>, <code>patches/</code> или <code>content.lua</code>.</p>"),
        ("Как поправить api без пересборки?",
         "<p>Файлы <code>api/*.lua</code> лежат отдельно от DLL: поправил файл — команда <code>.lua reload</code> в консоли модлоадера.</p>"),
        ("Что менять на клиенте, а что на сервере?",
         "<p>Интерфейс и клавиши — <code>client</code>. Решения хоста — <code>server</code>. Всё, что меняет мир одинаково на всех машинах "
         "(баланс, статы, логика), — <code>shared</code>: иначе в сети партия разойдётся. Подробнее — "
         "<a href=\"core-sides.html\">какая сторона что умеет</a>.</p>"),
    ]
    faq_html = "".join('<div class="acc"><div class="acc-head"><span>%s</span><span>+</span></div><div class="acc-body">%s</div></div>'
                       % (html.escape(q), a) for q, a in faq)
    return """
<section class="hero rv"><div class="bg"></div>
  <h1>МОДЫ ДЛЯ COSSACKS 3<br>БЕЗ ПЕРЕСБОРКИ<span class="caret"></span></h1>
  <p>Modloader встраивается в игру при запуске: Lua, события, HTML-интерфейсы, замена файлов и правка скриптов игры.
  Файлы игры не меняются — всё в памяти процесса. Здесь — полная документация по API.</p>
  <div class="cta"><a class="btn black" href="guide.html">НАЧАТЬ →</a><a class="btn" href="api-overview.html">ОБЗОР API →</a>
  <a class="btn" href="core-events.html">СОБЫТИЯ →</a></div>
</section>
<div class="stats">
  <div class="stat rv"><div class="cnt" data-count="%(modules)d">0</div><small>МОДУЛЕЙ API</small></div>
  <div class="stat rv"><div class="cnt" data-count="%(functions)d">0</div><small>ФУНКЦИЙ</small></div>
  <div class="stat rv"><div class="cnt" data-count="%(natives)d">0</div><small>НАТИВОВ ДВИЖКА</small></div>
  <div class="stat rv"><div class="cnt" data-count="%(screens)d">0</div><small>ЭКРАНОВ ИГРЫ</small></div>
</div>
<div class="marq rv"><div>%(marquee)s%(marquee)s</div></div>
<h2 class="sec-title">Пример за минуту</h2>
<div class="rv"><div class="tabs">%(tabs)s</div>%(panes)s</div>
<h2 class="sec-title">Модули api/</h2>
<div class="cards">%(cards)s</div>
<h2 class="sec-title">Частые вопросы</h2>
<div class="rv">%(faq)s</div>
""" % {"modules": stats["modules"], "functions": stats["functions"], "natives": stats["natives"], "screens": stats["screens"],
       "marquee": marquee, "tabs": tabs, "panes": panes, "cards": card_html, "faq": faq_html}


# --------------------------------------------------------------------------------------------------
# Шаблон страницы и вывод
# --------------------------------------------------------------------------------------------------

TOP_NAV = [("ГАЙД", "guide.html", ("НАЧАЛО",)), ("СПРАВОЧНИК", "core-rules.html", ("СПРАВОЧНИК",)),
           ("LUA API", "core-log.html", ("LUA API ДВИЖКА",)), ("МОДУЛИ", None, ("МОДУЛИ API",)),
           ("ДАННЫЕ", "ref-state.html", ("ДАННЫЕ ИГРЫ",))]

GROUP_ORDER = ["НАЧАЛО", "СПРАВОЧНИК", "LUA API ДВИЖКА", "МОДУЛИ API", "ДАННЫЕ ИГРЫ"]


def sidebar(current):
    out = []
    for g in GROUP_ORDER:
        items = [p for p in PAGES if p["group"] == g]
        if not items:
            continue
        out.append('<div class="group"><span class="group-title">%s</span>' % html.escape(g))
        for p in items:
            cls = ' class="active"' if p["id"] == current["id"] else ""
            out.append('<a href="%s"%s>%s</a>' % (p["file"], cls, html.escape(p["label"])))
        if g == "ДАННЫЕ ИГРЫ":
            out.append('<a href="%sGAME_API.md" target="_blank" rel="noopener">Нативы (GAME_API) ↗</a>' % BLOB)
        out.append("</div>")
    return "\n".join(out)


def topnav(current):
    firsts = {}
    for p in PAGES:
        firsts.setdefault(p["group"], p["file"])
    out = []
    for label, target, groups in TOP_NAV:
        href = target or firsts.get(groups[0], "index.html")
        active = ' class="active"' if current["group"] in groups and not current.get("home") else ""
        out.append('<a href="%s"%s>%s</a>' % (href, active, label))
    return "".join(out)


def prev_next(idx):
    nav = [p for p in PAGES]
    parts = ['<div class="pn">']
    if idx > 0:
        p = nav[idx - 1]
        parts.append('<a href="%s"><small>← НАЗАД</small>%s</a>' % (p["file"], html.escape(p["title"])))
    else:
        parts.append("<span></span>")
    if idx < len(nav) - 1:
        p = nav[idx + 1]
        parts.append('<a class="next" href="%s"><small>ДАЛЬШЕ →</small>%s</a>' % (p["file"], html.escape(p["title"])))
    parts.append("</div>")
    return "".join(parts)


def render_page(idx, p):
    title = "%s — %s" % (p["title"], "Cossacks 3 Modloader") if not p.get("home") else "Cossacks 3 Modloader — документация API"
    desc = p["summary"] or "Документация API Cossacks 3 Modloader: Lua, события, интерфейсы, замена файлов и правка скриптов игры."
    edit = ""
    if p["src"]:
        edit = '<div class="meta" style="margin-top:36px"><a class="badge" href="%s%s">РЕДАКТИРОВАТЬ НА GITHUB ↗</a></div>' % (BLOB, p["src"])
    body = p["body"]
    if not p.get("home"):
        body = '<article>%s</article>%s%s' % (body, edit, prev_next(idx))
    toc = '<aside class="toc" id="toc"><b>НА СТРАНИЦЕ</b></aside>' if p["toc"] else "<aside></aside>"
    layout = '<div class="layout"><aside class="side">%s</aside><main>%s</main>%s</div>' % (sidebar(p), body, toc)
    if p.get("home"):
        layout = '<div class="layout home-layout" style="grid-template-columns:minmax(0,1fr)"><main>%s</main></div>' % body
    return """<!DOCTYPE html>
<html lang="ru">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>%(title)s</title>
<meta name="description" content="%(desc)s">
<link rel="icon" href="assets/favicon.svg" type="image/svg+xml">
<link rel="stylesheet" href="assets/style.css">
<script>try{var t=localStorage.getItem('cs3-theme');if(t==='light')document.documentElement.setAttribute('data-theme','light')}catch(e){}</script>
</head>
<body>
<div class="page">
  <header class="site-header">
    <div class="hl">
      <a class="logo" href="index.html">%(site)s</a>
      <nav class="nav">%(nav)s</nav>
    </div>
    <div class="ha">
      <button class="iconbtn menu-btn" id="menu" type="button" aria-label="Меню">☰</button>
      <div class="search-wrap"><input class="search" id="q" placeholder="Поиск по API…" autocomplete="off" aria-label="Поиск"><span class="kbd">/</span><div class="results" id="results"></div></div>
      <a class="btn black sm" href="%(repo)s" target="_blank" rel="noopener">GITHUB →</a>
      <button class="iconbtn" id="theme" type="button" aria-label="Тема">☀</button>
    </div>
  </header>
  %(layout)s
  <footer class="footer">
    <div><a class="logo" href="index.html" style="display:inline-block">%(site)s</a><br><br>Документация API<br>Собрана из папки <code>api/</code> репозитория</div>
    <div>ДОКУМЕНТЫ<br><a href="guide.html">Быстрый старт</a><a href="core-rules.html">Справочник</a><a href="api-overview.html">Обзор api/</a></div>
    <div>ДАННЫЕ<br><a href="ref-state.html">Переменные игры</a><a href="ref-screens.html">Экраны</a><a href="%(blob)sGAME_API.md">Нативы ↗</a></div>
    <div>ПРОЕКТ<br><a href="%(repo)s">GitHub ↗</a><a href="%(repo)s/issues">Issues ↗</a><a href="%(blob)sDOCUMENTATION.md">Устройство ↗</a></div>
  </footer>
</div>
<script src="assets/search-index.js"></script>
<script src="assets/app.js"></script>
</body>
</html>
""" % {"title": html.escape(title), "desc": html.escape(desc, quote=True), "site": SITE_NAME, "nav": topnav(p),
       "layout": layout, "repo": REPO, "blob": BLOB}


FAVICON = """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32"><rect width="32" height="32" fill="#111"/><path d="M8 9h16v3H8zM8 15h16v3H8zM8 21h10v3H8z" fill="#fff"/></svg>
"""


def write_site():
    if OUT.exists():
        for old in OUT.glob("*.html"):
            old.unlink()
    (OUT / "assets").mkdir(parents=True, exist_ok=True)
    for i, p in enumerate(PAGES):
        (OUT / p["file"]).write_text(render_page(i, p), encoding="utf-8")
    shutil.copy(SITE / "style.css", OUT / "assets" / "style.css")
    shutil.copy(SITE / "app.js", OUT / "assets" / "app.js")
    (OUT / "assets" / "favicon.svg").write_text(FAVICON, encoding="utf-8")
    (OUT / "assets" / "search-index.js").write_text(
        "window.CS3_SEARCH=" + json.dumps(SEARCH, ensure_ascii=False, separators=(",", ":")) + ";\n", encoding="utf-8")
    (OUT / ".nojekyll").write_text("", encoding="utf-8")
    (OUT / "404.html").write_text(render_404(), encoding="utf-8")


def render_404():
    page = {"id": "404", "file": "404.html", "title": "Страница не найдена", "label": "404", "group": "НАЧАЛО",
            "body": '<h1>404</h1><p class="lead">Такой страницы нет.</p><p><a class="btn black" href="index.html">НА ГЛАВНУЮ →</a></p>',
            "src": None, "headings": [], "summary": "", "toc": False}
    return render_page(0, page)


def main():
    global ROOT, OUT
    import argparse
    ap = argparse.ArgumentParser(description="Сборка сайта-документации из api/ и справочников репозитория")
    ap.add_argument("--repo", help="корень клона репозитория (где лежат api/, MODDING.md, ...)")
    ap.add_argument("--out", help="папка для сайта")
    args = ap.parse_args()
    if args.repo:
        ROOT = Path(args.repo).resolve()
    OUT = Path(args.out).resolve() if args.out else ROOT / "docs"
    if not (ROOT / "api").is_dir():
        sys.exit("не найдена папка api/ в %s — укажите --repo" % ROOT)
    stats = build()
    write_site()
    print("pages: %d, search entries: %d, %s" % (len(PAGES), len(SEARCH), stats))


if __name__ == "__main__":
    sys.exit(main())
