#include "pch.h"
#include "ScriptPatch.h"
#include "Console.h"
#include "Text.h"

#include <vector>

namespace
{
    std::vector<std::string> SplitLines(const std::string& text)
    {
        std::vector<std::string> lines;
        size_t from = 0;
        while (from <= text.size())
        {
            size_t nl = text.find('\n', from);
            std::string line = text.substr(from, nl == std::string::npos ? std::string::npos : nl - from);
            if (!line.empty() && line.back() == '\r')
                line.pop_back();
            lines.push_back(line);
            if (nl == std::string::npos)
                break;
            from = nl + 1;
        }
        if (!lines.empty() && lines.back().empty())
            lines.pop_back(); // текст кончался переводом строки
        return lines;
    }

    std::string JoinLines(const std::vector<std::string>& lines)
    {
        std::string out;
        for (const std::string& l : lines)
            out += l + "\r\n";
        return out;
    }

    std::string Lower(std::string s)
    {
        for (char& c : s)
            c = static_cast<char>(tolower(static_cast<unsigned char>(c)));
        return s;
    }

    std::string TrimRight(std::string s)
    {
        while (!s.empty() && (s.back() == ' ' || s.back() == '\t'))
            s.pop_back();
        return s;
    }

    bool IsIdent(char c) { return isalnum(static_cast<unsigned char>(c)) || c == '_'; }

    // Объявление функции в начале строки: "function Имя" / "procedure Имя" + не буква после имени.
    bool IsDecl(const std::string& line, const std::string& lowName)
    {
        std::string low = Lower(line);
        for (const char* kw : { "function ", "procedure " })
        {
            size_t n = strlen(kw);
            if (low.compare(0, n, kw) != 0)
                continue;
            size_t p = low.find_first_not_of(' ', n);
            if (p == std::string::npos || low.compare(p, lowName.size(), lowName) != 0)
                continue;
            size_t after = p + lowName.size();
            return after >= low.size() || !IsIdent(low[after]);
        }
        return false;
    }

    bool IsTopDecl(const std::string& line)
    {
        std::string low = Lower(line);
        return low.rfind("function ", 0) == 0 || low.rfind("procedure ", 0) == 0;
    }

    // Границы функции: объявление, её begin и end; — все с начала строки (так оформлены lib/*.script).
    struct Range { int decl = -1, begin = -1, end = -1; };

    Range FindFunction(const std::vector<std::string>& lines, const std::string& name)
    {
        Range r;
        std::string lowName = Lower(name);
        for (int i = 0; i < static_cast<int>(lines.size()); ++i)
            if (IsDecl(lines[i], lowName))
            {
                // forward-объявление ("...; forward;") — пропускаем, ищем настоящее
                if (Lower(lines[i]).find("forward;") != std::string::npos)
                    continue;
                r.decl = i;
                break;
            }
        if (r.decl < 0)
            return r;
        for (int i = r.decl + 1; i < static_cast<int>(lines.size()); ++i)
        {
            std::string t = Lower(TrimRight(lines[i]));
            if (i > r.decl + 1 && IsTopDecl(lines[i]))
                break; // дошли до следующей функции — формат не тот
            if (r.begin < 0 && t == "begin")
                r.begin = i;
            else if (r.begin >= 0 && t == "end;")
            {
                r.end = i;
                break;
            }
        }
        if (r.begin < 0 || r.end < 0)
            r.decl = -1;
        return r;
    }

    struct Block
    {
        std::string cmd, arg;
        std::vector<std::string> body, with;
        int line = 0;
    };

    std::vector<Block> ParseBlocks(const std::vector<std::string>& lines)
    {
        std::vector<Block> blocks;
        bool inWith = false;
        for (int i = 0; i < static_cast<int>(lines.size()); ++i)
        {
            const std::string& l = lines[i];
            if (l.rfind("@@", 0) == 0)
                continue;
            if (!l.empty() && l[0] == '@')
            {
                std::string head = TrimRight(l.substr(1));
                size_t sp = head.find(' ');
                std::string cmd = Lower(head.substr(0, sp));
                std::string arg = sp == std::string::npos ? "" : head.substr(head.find_first_not_of(' ', sp));
                if (cmd == "with" && !blocks.empty() && blocks.back().cmd == "find")
                {
                    inWith = true;
                    continue;
                }
                blocks.push_back({ cmd, arg, {}, {}, i + 1 });
                inWith = false;
                continue;
            }
            if (blocks.empty())
                continue; // текст до первой команды — описание патча
            (inWith ? blocks.back().with : blocks.back().body).push_back(l);
        }
        // пустые строки в конце блока — разделители между блоками, не часть вставки
        for (Block& b : blocks)
            for (auto* v : { &b.body, &b.with })
                while (!v->empty() && TrimRight(v->back()).empty())
                    v->pop_back();
        return blocks;
    }

    // Патч может быть в UTF-8 (так сохраняют редакторы) — игре нужен ANSI.
    std::string ToGameEncoding(std::string s)
    {
        if (s.rfind("\xEF\xBB\xBF", 0) == 0)
            return Text::Utf8ToAnsi(s.substr(3));
        bool high = false;
        for (unsigned char c : s)
            if (c >= 0x80) { high = true; break; }
        if (high && MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, s.data(), static_cast<int>(s.size()), nullptr, 0) > 0)
            return Text::Utf8ToAnsi(s);
        return s;
    }
}

int ScriptPatch::Apply(std::string& text, const std::string& patchText, const std::string& who)
{
    std::vector<std::string> lines = SplitLines(text);
    std::vector<Block> blocks = ParseBlocks(SplitLines(ToGameEncoding(patchText)));
    int applied = 0;

    for (const Block& b : blocks)
    {
        auto fail = [&](const char* why) {
            LOG_WARN("[patch] %s:%d: @%s %s — %s, block skipped", who.c_str(), b.line, b.cmd.c_str(), b.arg.c_str(), why);
        };

        if (b.cmd == "append")
        {
            lines.insert(lines.end(), b.body.begin(), b.body.end());
            ++applied;
            continue;
        }
        if (b.cmd == "find")
        {
            if (b.body.empty())
            {
                fail("empty @find");
                continue;
            }
            std::string joined = JoinLines(lines);
            std::string from = JoinLines(b.body), to = JoinLines(b.with);
            from.resize(from.size() - 2); // без последнего перевода строки: ищем и внутри строки
            if (!to.empty())
                to.resize(to.size() - 2);
            int n = 0;
            for (size_t p = 0; (p = joined.find(from, p)) != std::string::npos; p += to.size(), ++n)
                joined.replace(p, from.size(), to);
            if (!n)
            {
                fail("text not found");
                continue;
            }
            lines = SplitLines(joined);
            ++applied;
            continue;
        }

        bool known = b.cmd == "replace" || b.cmd == "begin" || b.cmd == "end" || b.cmd == "before" || b.cmd == "after";
        if (!known)
        {
            fail("unknown command");
            continue;
        }
        Range r = FindFunction(lines, b.arg);
        if (r.decl < 0)
        {
            fail("function not found");
            continue;
        }
        auto at = [&](int index) { return lines.begin() + index; };
        if (b.cmd == "replace")
        {
            lines.erase(at(r.decl), at(r.end + 1));
            lines.insert(at(r.decl), b.body.begin(), b.body.end());
        }
        else if (b.cmd == "begin")
            lines.insert(at(r.begin + 1), b.body.begin(), b.body.end());
        else if (b.cmd == "end")
            lines.insert(at(r.end), b.body.begin(), b.body.end());
        else if (b.cmd == "before")
        {
            // над объявлением обычно стоят комментарии "// _имя" — вставляем выше них
            int i = r.decl;
            while (i > 0 && TrimRight(lines[i - 1]).rfind("//", 0) == 0)
                --i;
            lines.insert(at(i), b.body.begin(), b.body.end());
        }
        else
            lines.insert(at(r.end + 1), b.body.begin(), b.body.end());
        ++applied;
    }
    text = JoinLines(lines);
    return applied;
}

std::string ScriptPatch::Builtin(const std::string& key)
{
    // unit.order: любой приказ любому юниту — игрока, ИИ, из сети, из скриптов. Через одну функцию
    // игры проходят все приказы. Обработчик может вернуть true — приказ не добавится (Result = nil).
    if (key == "data\\scripts\\lib\\unit.script")
        return "@begin _unit_AddOrder\r\n"
               "DScriptSetgDbgString0('ML:unit.order|'+IntToStr(goHnd)+'|'+IntToStr(itype)+'|'+IntToStr(itrghnd)+'|'+"
               "FloatToStr(ix)+'|'+FloatToStr(iy)); if (DScriptGetgDbgString0='ML:block') then exit;\r\n";
    // unit.damage: весь урон — ближний бой, выстрелы, картечь, взрывы, по площади — идёт через _misc_DoDamage.
    if (key == "data\\scripts\\lib\\miscext2.script")
        return "@begin _misc_DoDamage\r\n"
               "DScriptSetgDbgString0('ML:unit.damage|'+IntToStr(goHnd)+'|'+IntToStr(trgHnd)+'|'+IntToStr(indamage));\r\n";
    // savedata: строковая глобальная переменная для данных модов — движок сам пишет её в сейв и читает
    // при загрузке (список serialized в dmscript.source).
    if (key == "data\\scripts\\dmscript.global")
        return "@find\r\n   gpointer_register0 = Pointer\r\n@with\r\n   gstring_modloader_save = String\r\n   gpointer_register0 = Pointer\r\n";
    if (key == "data\\scripts\\dmscript.source")
        return "@find\r\n      [*] = gbool_recordwascleared\r\n@with\r\n      [*] = gbool_recordwascleared\r\n      [*] = gstring_modloader_save\r\n";
    return {};
}
