#include "pch.h"
#include "Content.h"
#include "Console.h"
#include "GameApi.h"
#include "Hooks.h"
#include "NativeCall.h"
#include "Text.h"

// Lua собран как C++ — заголовки без extern "C" (как в LuaHost.cpp).
#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"

#include <algorithm>
#include <fstream>
#include <map>
#include <mutex>
#include <set>
#include <sstream>

namespace fs = std::filesystem;

namespace
{
    // ---------- описания ----------

    using Names = std::map<std::string, std::string>; // язык ("ru", "en", "*") -> текст (UTF-8)

    struct NationDef
    {
        std::string mod, sid, from;
        Names name;
        int id = -1;
    };

    struct UnitDef
    {
        std::string mod, sid, from;
        std::vector<std::string> nations;
        int cellX = -1, cellY = -1;
        std::string actor, mesh, material, animations, icon;
        std::vector<std::pair<std::string, std::string>> base, prop; // поле -> литерал Pascal
        Names name, description;
    };

    std::vector<NationDef> g_nations;
    std::vector<UnitDef> g_units;

    // ---------- локализация ----------

    std::mutex g_locMutex;
    std::map<std::string, Names> g_locText;       // ключ (нижний регистр) -> тексты по языкам
    std::map<std::string, std::string> g_locAlias; // sid нового типа -> sid родителя (для названий и подсказок)
    std::map<std::string, GameApi::DelphiString> g_locCache; // готовые строки для движка

    std::string Lower(std::string s)
    {
        for (char& c : s)
            c = static_cast<char>(tolower(static_cast<unsigned char>(c)));
        return s;
    }

    bool ValidSid(const std::string& s)
    {
        return !s.empty() && s.size() <= 32 && std::all_of(s.begin(), s.end(), [](unsigned char c) {
            return islower(c) || isdigit(c) || c == '_';
        });
    }

    // ---------- чтение content.lua ----------

    std::string FieldString(lua_State* L, int t, const char* name)
    {
        lua_getfield(L, t, name);
        std::string v = lua_type(L, -1) == LUA_TSTRING ? lua_tostring(L, -1) : "";
        lua_pop(L, 1);
        return v;
    }

    std::vector<std::string> FieldList(lua_State* L, int t, const char* name)
    {
        std::vector<std::string> out;
        lua_getfield(L, t, name);
        if (lua_type(L, -1) == LUA_TSTRING)
            out.push_back(lua_tostring(L, -1));
        else if (lua_istable(L, -1))
            for (lua_Integer i = 1; lua_rawgeti(L, -1, i) == LUA_TSTRING; ++i)
            {
                out.push_back(lua_tostring(L, -1));
                lua_pop(L, 1);
            }
        lua_pop(L, lua_istable(L, -1) ? 2 : 1);
        return out;
    }

    Names FieldNames(lua_State* L, int t, const char* name)
    {
        Names out;
        lua_getfield(L, t, name);
        if (lua_type(L, -1) == LUA_TSTRING)
            out["*"] = lua_tostring(L, -1);
        else if (lua_istable(L, -1))
        {
            lua_pushnil(L);
            while (lua_next(L, -2))
            {
                if (lua_type(L, -2) == LUA_TSTRING && lua_type(L, -1) == LUA_TSTRING)
                    out[Lower(lua_tostring(L, -2))] = lua_tostring(L, -1);
                lua_pop(L, 1);
            }
        }
        lua_pop(L, 1);
        return out;
    }

    // Значение Lua -> литерал Pascal. Пусто — тип не подходит.
    std::string PascalLiteral(lua_State* L, int idx)
    {
        switch (lua_type(L, idx))
        {
        case LUA_TBOOLEAN:
            return lua_toboolean(L, idx) ? "True" : "False";
        case LUA_TNUMBER:
            if (lua_isinteger(L, idx))
                return std::to_string(lua_tointeger(L, idx));
            else
            {
                char buf[64];
                snprintf(buf, sizeof(buf), "%.9g", lua_tonumber(L, idx));
                std::string s = buf;
                return s.find_first_of(".e") == std::string::npos ? s + ".0" : s;
            }
        case LUA_TSTRING:
        {
            std::string s = "'";
            for (char c : Text::Utf8ToAnsi(lua_tostring(L, idx)))
                s += c == '\'' ? std::string("''") : std::string(1, c);
            return s + "'";
        }
        default:
            return {};
        }
    }

    bool ValidFieldPath(const std::string& p)
    {
        return !p.empty() && std::all_of(p.begin(), p.end(), [](unsigned char c) {
            return isalnum(c) || c == '_' || c == '.' || c == '[' || c == ']';
        });
    }

    std::vector<std::pair<std::string, std::string>> FieldAssignments(lua_State* L, int t, const char* name, const std::string& who)
    {
        std::vector<std::pair<std::string, std::string>> out;
        lua_getfield(L, t, name);
        if (lua_istable(L, -1))
        {
            lua_pushnil(L);
            while (lua_next(L, -2))
            {
                std::string key = lua_type(L, -2) == LUA_TSTRING ? lua_tostring(L, -2) : "";
                std::string value = PascalLiteral(L, -1);
                if (!ValidFieldPath(key) || value.empty())
                    LOG_WARN("[content] %s: %s.%s — bad field or value, skipped", who.c_str(), name, key.c_str());
                else
                    out.push_back({ key, value });
                lua_pop(L, 1);
            }
        }
        lua_pop(L, 1);
        std::sort(out.begin(), out.end()); // порядок не зависит от обхода таблицы
        return out;
    }

    int l_collect(lua_State* L)
    {
        luaL_checktype(L, 1, LUA_TTABLE);
        lua_getfield(L, LUA_REGISTRYINDEX, "ml_defs");
        lua_pushvalue(L, lua_upvalueindex(1)); // вид: "unit" / "nation"
        lua_setfield(L, 1, "__kind");
        lua_pushvalue(L, 1);
        lua_rawseti(L, -2, static_cast<lua_Integer>(lua_rawlen(L, -2)) + 1);
        lua_pop(L, 1);
        return 0;
    }

    void ReadModContent(const Content::ModDir& mod)
    {
        fs::path file = mod.dir / L"content.lua";
        std::error_code ec;
        if (!fs::is_regular_file(file, ec))
            return;
        std::ifstream in(file, std::ios::binary);
        std::stringstream ss;
        ss << in.rdbuf();
        std::string code = ss.str();

        lua_State* L = luaL_newstate();
        for (auto [name, fn] : { std::pair{ LUA_GNAME, luaopen_base }, std::pair{ LUA_STRLIBNAME, luaopen_string },
                                 std::pair{ LUA_TABLIBNAME, luaopen_table }, std::pair{ LUA_MATHLIBNAME, luaopen_math } })
        {
            luaL_requiref(L, name, fn, 1);
            lua_pop(L, 1);
        }
        // Описание — только данные: без файлов, загрузки кода и окружения.
        for (const char* banned : { "dofile", "loadfile", "load", "require", "collectgarbage" })
        {
            lua_pushnil(L);
            lua_setglobal(L, banned);
        }
        lua_newtable(L);
        lua_setfield(L, LUA_REGISTRYINDEX, "ml_defs");
        for (const char* kind : { "unit", "nation" })
        {
            lua_pushstring(L, kind);
            lua_pushcclosure(L, l_collect, 1);
            lua_setglobal(L, kind);
        }

        std::string chunk = "@" + mod.folder + "/content.lua";
        if (luaL_loadbuffer(L, code.data(), code.size(), chunk.c_str()) != LUA_OK || lua_pcall(L, 0, 0, 0) != LUA_OK)
        {
            LOG_ERROR("[content] %s/content.lua: %s", mod.folder.c_str(), lua_tostring(L, -1));
            lua_close(L);
            return;
        }

        lua_getfield(L, LUA_REGISTRYINDEX, "ml_defs");
        int defs = lua_gettop(L);
        for (lua_Integer i = 1; lua_rawgeti(L, defs, i) == LUA_TTABLE; ++i)
        {
            int t = lua_gettop(L);
            std::string kind = FieldString(L, t, "__kind");
            std::string sid = Lower(FieldString(L, t, "sid"));
            std::string from = Lower(FieldString(L, t, "from"));
            std::string who = mod.folder + "/" + kind + " '" + sid + "'";
            if (!ValidSid(sid) || !ValidSid(from))
            {
                LOG_ERROR("[content] %s: sid and from are required (latin lowercase, digits, _)", who.c_str());
                lua_pop(L, 1);
                continue;
            }
            if (kind == "nation")
            {
                if (sid.size() != 3 || from.size() != 3)
                    LOG_ERROR("[content] %s: nation sid and from must be 3 letters", who.c_str());
                else
                    g_nations.push_back({ mod.folder, sid, from, FieldNames(L, t, "name") });
            }
            else
            {
                UnitDef u;
                u.mod = mod.folder;
                u.sid = sid;
                u.from = from;
                for (const std::string& n : FieldList(L, t, "nations"))
                    u.nations.push_back(Lower(n));
                lua_getfield(L, t, "cell");
                if (lua_istable(L, -1))
                {
                    lua_rawgeti(L, -1, 1);
                    lua_rawgeti(L, -2, 2);
                    u.cellX = static_cast<int>(luaL_optinteger(L, -2, -1));
                    u.cellY = static_cast<int>(luaL_optinteger(L, -1, -1));
                    lua_pop(L, 2);
                }
                lua_pop(L, 1);
                u.actor = FieldString(L, t, "actor");
                u.mesh = FieldString(L, t, "mesh");
                u.material = FieldString(L, t, "material");
                u.animations = FieldString(L, t, "animations");
                u.icon = FieldString(L, t, "icon");
                u.base = FieldAssignments(L, t, "base", who);
                u.prop = FieldAssignments(L, t, "prop", who);
                u.name = FieldNames(L, t, "name");
                u.description = FieldNames(L, t, "description");
                if (u.nations.empty())
                    LOG_ERROR("[content] %s: nations = { ... } is required", who.c_str());
                else
                    g_units.push_back(std::move(u));
            }
            lua_pop(L, 1);
        }
        lua_close(L);
    }

    // ---------- генерация ----------

    constexpr int kBaseNations = 24; // gc_MaxCountryCount игры

    std::string Condition(const std::vector<std::string>& nations)
    {
        std::string c;
        for (const std::string& n : nations)
            c += (c.empty() ? "" : " or ") + std::string("(csid='") + n + "')";
        return "(" + c + ")";
    }

    // Строка файла, содержащая needle (первая), без перевода строки. Пусто — нет.
    std::string LineWith(const std::string& text, const std::string& needle, size_t* at = nullptr)
    {
        size_t p = text.find(needle);
        if (p == std::string::npos)
            return {};
        size_t b = text.rfind('\n', p);
        b = b == std::string::npos ? 0 : b + 1;
        size_t e = text.find('\n', p);
        std::string line = text.substr(b, (e == std::string::npos ? text.size() : e) - b);
        if (!line.empty() && line.back() == '\r')
            line.pop_back();
        if (at)
            *at = e == std::string::npos ? text.size() : e + 1;
        return line;
    }

    std::vector<std::string> LinesWith(const std::string& text, const std::string& needle)
    {
        std::vector<std::string> out;
        std::set<std::string> seen;
        size_t from = 0, next = 0;
        while (from < text.size())
        {
            std::string line = LineWith(text.substr(from), needle, &next);
            if (line.empty())
                break;
            if (seen.insert(line).second)
                out.push_back(line);
            from += next;
        }
        return out;
    }

    // "@find\r\n<a>\r\n@with\r\n<a>\r\n<b>\r\n" — вставить строку b после строки a.
    std::string InsertAfter(const std::string& line, const std::string& added)
    {
        return "@find\r\n" + line + "\r\n@with\r\n" + line + "\r\n" + added + "\r\n\r\n";
    }

    std::string ReplaceText(const std::string& from, const std::string& to)
    {
        return "@find\r\n" + from + "\r\n@with\r\n" + to + "\r\n\r\n";
    }

    // Значение ключа "   Key = value" в тексте .prop заменить (только строки, где значение ровно old).
    std::string ReplacePropValue(std::string text, const std::string& key, const std::string& oldValue, const std::string& newValue)
    {
        std::string out;
        std::istringstream in(text);
        std::string line;
        while (std::getline(in, line))
        {
            std::string body = line;
            bool cr = !body.empty() && body.back() == '\r';
            if (cr)
                body.pop_back();
            size_t eq = body.find('=');
            if (eq != std::string::npos)
            {
                std::string k = body.substr(0, eq), v = body.substr(eq + 1);
                k.erase(0, k.find_first_not_of(" \t"));
                k.erase(k.find_last_not_of(" \t") + 1);
                v.erase(0, v.find_first_not_of(" \t"));
                v.erase(v.find_last_not_of(" \t") + 1);
                if (k == key && Lower(v) == Lower(oldValue))
                    body = body.substr(0, body.find_first_not_of(" \t")) + key + " = " + newValue;
            }
            out += body + "\r\n";
        }
        return out;
    }

    std::string PropValue(const std::string& text, const std::string& key)
    {
        std::istringstream in(text);
        std::string line;
        while (std::getline(in, line))
        {
            size_t eq = line.find('=');
            if (eq == std::string::npos)
                continue;
            std::string k = line.substr(0, eq), v = line.substr(eq + 1);
            k.erase(0, k.find_first_not_of(" \t"));
            k.erase(k.find_last_not_of(" \t") + 1);
            v.erase(0, v.find_first_not_of(" \t"));
            v.erase(v.find_last_not_of(" \t\r") + 1);
            if (k == key)
                return v;
        }
        return {};
    }

    // Секция hud.mat с материалом name ("section.begin ... section.end").
    std::string MaterialSection(const std::string& text, const std::string& name)
    {
        size_t p = std::string::npos;
        for (size_t from = 0;;)
        {
            size_t q = text.find("Material.Name = " + name, from);
            if (q == std::string::npos)
                break;
            size_t e = q + 16 + name.size();
            if (e >= text.size() || text[e] == '\r' || text[e] == '\n')
            {
                p = q;
                break;
            }
            from = e;
        }
        if (p == std::string::npos)
            return {};
        size_t b = text.rfind("section.begin", p);
        size_t e = text.find("section.end", p);
        if (b == std::string::npos || e == std::string::npos)
            return {};
        return text.substr(b, e + 11 - b);
    }

    void AddNames(const std::string& key, const Names& names)
    {
        if (!names.empty())
            g_locText[Lower(key)] = names;
    }
}

Content::Result Content::Generate(const std::vector<ModDir>& mods, const std::function<std::string(const std::string&)>& readBase,
                                  const std::function<std::vector<std::string>(const std::string&)>& listGameDir)
{
    g_nations.clear();
    g_units.clear();
    for (const ModDir& m : mods)
        ReadModContent(m);

    Result r;
    if (g_nations.empty() && g_units.empty())
        return r;
    const std::string me = "content";
    std::map<std::string, std::string> patch; // ключ файла -> текст патча
    auto add = [&](const std::string& key, const std::string& text) { patch[key] += text; };

    const std::string kCountry = "data\\scripts\\lib\\country.script";
    const std::string kMap = "data\\scripts\\lib\\map.script";
    const std::string kUnit = "data\\scripts\\lib\\unit.script";
    const std::string kGlobal = "data\\scripts\\dmscript.global";
    const std::string kUnitsObjects = "data\\objects\\units\\units.objects";
    const std::string kBuildingsObjects = "data\\objects\\buildings\\buildings.objects";
    const std::string kHud = "data\\hud\\hud.mat";

    std::string country = readBase(kCountry), mapScript = readBase(kMap), hud = readBase(kHud);

    // ---- нации ----
    std::set<std::string> known = { "aus", "fra", "eng", "spa", "rus", "ukr", "pol", "swe", "pru", "ven", "tur", "alg",
                                     "mis", "net", "den", "por", "pie", "sax", "bav", "hun", "swi", "sco", "tat", "lit" };
    std::vector<NationDef> nations;
    for (NationDef n : g_nations)
    {
        if (known.count(n.sid))
        {
            LOG_ERROR("[content] %s: nation '%s' already exists", n.mod.c_str(), n.sid.c_str());
            continue;
        }
        if (!known.count(n.from) || n.from == "mis")
        {
            LOG_ERROR("[content] %s: nation '%s': unknown template nation '%s'", n.mod.c_str(), n.sid.c_str(), n.from.c_str());
            continue;
        }
        n.id = kBaseNations + static_cast<int>(nations.size());
        known.insert(n.sid);
        nations.push_back(n);
    }
    if (!nations.empty())
    {
        int total = kBaseNations + static_cast<int>(nations.size());
        add(kGlobal, ReplaceText("gc_MaxCountryCount = 24;", "gc_MaxCountryCount = " + std::to_string(total) + ";"));

        std::string idToSid = "23 : sid := 'lit';", sidToId = "'lit' : id := 23;", flags = "_lit : lit := True;";
        std::string available = "'net', 'den' : bPlayable := True;";
        std::string addIdToSid, addSidToId, addFlags, availableList = "'net', 'den'";
        for (const NationDef& n : nations)
        {
            std::string id = std::to_string(n.id);
            addIdToSid += " " + id + " : sid := '" + n.sid + "';";
            addSidToId += " '" + n.sid + "' : id := " + id + ";";
            addFlags += " " + id + " : " + n.from + " := True;"; // новая нация ведёт себя как шаблон
            availableList += ", '" + n.sid + "'";
        }
        for (const auto& [key, text] : { std::pair{ kCountry, &country }, std::pair{ kMap, &mapScript } })
        {
            if (text->find(idToSid) != std::string::npos)
                add(key, ReplaceText(idToSid, idToSid + addIdToSid));
            if (text->find(sidToId) != std::string::npos)
                add(key, ReplaceText(sidToId, sidToId + addSidToId));
            if (text->find(flags) != std::string::npos)
                add(key, ReplaceText(flags, flags + addFlags));
            if (text->find(available) != std::string::npos)
                add(key, ReplaceText(available, availableList + " : bPlayable := True;"));
        }

        // Здания нации: каждое <шаблон>xxx.prop -> <нация>xxx.prop (та же модель, свой sid).
        std::string buildingsObjects = readBase(kBuildingsObjects);
        for (const NationDef& n : nations)
        {
            int count = 0;
            for (const std::string& file : listGameDir("data\\objects\\buildings"))
            {
                std::string lower = Lower(file);
                if (lower.rfind(n.from, 0) != 0 || lower.size() < 9 || lower.compare(lower.size() - 5, 5, ".prop") != 0)
                    continue;
                std::string oldSid = lower.substr(0, lower.size() - 5);
                std::string newSid = n.sid + oldSid.substr(3);
                std::string text = readBase("data\\objects\\buildings\\" + lower);
                text = ReplacePropValue(text, "CustomName", oldSid, newSid);
                text = ReplacePropValue(text, "BaseName", oldSid, newSid);
                r.files.push_back({ "data\\objects\\buildings\\" + newSid + ".prop", n.mod, text });
                std::string entry = "\\data\\objects\\buildings\\" + oldSid + ".prop";
                std::string line = LineWith(buildingsObjects, entry);
                if (!line.empty())
                {
                    std::string added = line;
                    added.replace(added.find(entry), entry.size(), "\\data\\objects\\buildings\\" + newSid + ".prop");
                    add(kBuildingsObjects, InsertAfter(line, added));
                }
                g_locAlias[newSid] = oldSid;
                ++count;
            }
            AddNames(n.sid, n.name);
            if (n.name.empty())
                g_locAlias[n.sid] = n.from;
            LOG_INFO("[content] nation %s (id %d, like %s) from %s: %d building(s)", n.sid.c_str(), n.id, n.from.c_str(),
                     n.mod.c_str(), count);
        }
    }

    g_nations = nations; // с номерами — для .content

    // ---- юниты ----
    std::string unitsObjects = readBase(kUnitsObjects);
    std::string mapping, restore, overrides;
    for (const UnitDef& u : g_units)
    {
        std::string who = u.mod + "/unit '" + u.sid + "'";
        std::string parentProp = readBase("data\\objects\\units\\" + u.from + ".prop");
        if (parentProp.empty())
        {
            LOG_ERROR("[content] %s: parent '%s' not found (data/objects/units/%s.prop)", who.c_str(), u.from.c_str(), u.from.c_str());
            continue;
        }
        bool badNation = false;
        for (const std::string& n : u.nations)
            if (!known.count(n))
            {
                LOG_ERROR("[content] %s: unknown nation '%s'", who.c_str(), n.c_str());
                badNation = true;
            }
        if (badNation)
            continue;

        // .prop — копия родителя со своим sid; модель, материал, анимации — родителя или свои.
        std::string text = parentProp;
        text = ReplacePropValue(text, "CustomName", u.from, u.sid);
        text = ReplacePropValue(text, "BaseName", u.from, u.sid);
        if (!u.actor.empty())
        {
            text = ReplacePropValue(text, "LODActorName", PropValue(parentProp, "LODActorName"), u.actor);
            text = ReplacePropValue(text, "DefaultMeshName", PropValue(parentProp, "DefaultMeshName"), u.mesh.empty() ? u.actor + ".mesh" : u.mesh);
        }
        if (!u.material.empty())
        {
            std::string old = PropValue(parentProp, "Mesh[0].DefaultMaterialName");
            text = ReplacePropValue(text, "Mesh[0].DefaultMaterialName", old, u.material);
            text = ReplacePropValue(text, "Mesh[0].UseableMaterials[0]", old, u.material);
        }
        if (!u.animations.empty())
            text = ReplacePropValue(text, "FrameAnimationCyclesLibName", PropValue(parentProp, "FrameAnimationCyclesLibName"), u.animations);
        r.files.push_back({ "data\\objects\\units\\" + u.sid + ".prop", u.mod, text });

        std::string entry = "\\data\\objects\\units\\" + u.from + ".prop";
        std::string line = LineWith(unitsObjects, entry);
        if (line.empty())
        {
            LOG_ERROR("[content] %s: parent is not in units.objects", who.c_str());
            continue;
        }
        std::string added = line;
        added.replace(added.find(entry), entry.size(), "\\data\\objects\\units\\" + u.sid + ".prop");
        add(kUnitsObjects, InsertAfter(line, added));

        // Иконка кнопки — копия иконки родителя (или указанного материала hud).
        std::string section = MaterialSection(hud, u.icon.empty() ? "icons.unit." + u.from : u.icon);
        if (section.empty())
            LOG_WARN("[content] %s: icon of '%s' not found in hud.mat — the button will have no picture", who.c_str(), u.from.c_str());
        else
        {
            size_t p = section.find("Material.Name = ");
            size_t e = section.find_first_of("\r\n", p);
            section.replace(p, e - p, "Material.Name = icons.unit." + u.sid);
            add(kHud, "@append\r\n" + section + "\r\n\r\n");
        }

        // Член нации: строка родителя _country_AddMember с другим sid и условием по нациям.
        std::string cond = Condition(u.nations);
        std::string memberLine = LineWith(country, "_country_AddMember(country, '" + u.from + "',");
        if (memberLine.empty())
        {
            LOG_ERROR("[content] %s: parent '%s' is not a nation member in country.script", who.c_str(), u.from.c_str());
            continue;
        }
        std::string call = memberLine.substr(memberLine.find("_country_AddMember("));
        call.replace(call.find("'" + u.from + "'"), u.from.size() + 2, "'" + u.sid + "'");
        add(kCountry, InsertAfter(memberLine, "      if " + cond + " then " + call));

        // Найм: везде, где нанимают родителя, — там же (клетка — своя или родителя).
        int produce = 0;
        for (const std::string& fp : LinesWith(country, "member, '" + u.from + "', "))
        {
            size_t c = fp.find("_country_AddFixedProduceWithAccessControl(");
            if (c == std::string::npos)
                continue;
            std::string call = fp.substr(c);
            size_t s = call.find("'" + u.from + "', ");
            std::string rest = call.substr(s + u.from.size() + 4); // "X, Y, ind, ..."
            size_t c1 = rest.find(','), c2 = rest.find(',', c1 + 1);
            std::string x = rest.substr(0, c1), y = rest.substr(c1 + 1, c2 - c1 - 1);
            if (u.cellX >= 0)
                x = std::to_string(u.cellX), y = " " + std::to_string(u.cellY);
            call = call.substr(0, s) + "'" + u.sid + "', " + x + "," + y + rest.substr(c2);
            add(kCountry, InsertAfter(fp, "      if " + cond + " then " + call));
            ++produce;
        }
        if (!produce)
            LOG_WARN("[content] %s: parent '%s' is not produced anywhere — '%s' can only be spawned by scripts", who.c_str(),
                     u.from.c_str(), u.sid.c_str());

        // Характеристики: _unit_InitBase считает новый тип как родителя, потом правки мода.
        mapping += " if (sid='" + u.sid + "') then begin sid := '" + u.from + "'; objprop.sid := sid; end;";
        std::string set;
        for (const auto& [f, v] : u.base)
            set += " objbase." + f + " := " + v + ";";
        for (const auto& [f, v] : u.prop)
            set += " objprop." + f + " := " + v + ";";
        if (!set.empty())
            overrides += "   if (objprop.sid='" + u.sid + "') then begin" + set + " end;\r\n";

        g_locAlias[u.sid] = u.from;
        AddNames(u.sid, u.name);
        AddNames(u.sid + ".ext", u.description);
        LOG_INFO("[content] unit %s (like %s) from %s: nations %zu, produced in %d place(s)", u.sid.c_str(), u.from.c_str(),
                 u.mod.c_str(), u.nations.size(), produce);
    }
    if (!mapping.empty())
    {
        add(kUnit, "@begin _unit_InitBase\r\n   var mlContentSid : String;\r\n\r\n");
        add(kUnit, ReplaceText("      objprop.id := id;", "      objprop.id := id;\r\n      mlContentSid := sid;" + mapping));
        add(kUnit, "@end _unit_InitBase\r\n   if (mlContentSid<>'') and (mlContentSid<>objprop.sid) then begin objprop.sid := mlContentSid; objbase.sid := mlContentSid; end;\r\n" +
                       overrides + "\r\n");
    }

    for (auto& [key, text] : patch)
        r.patches.push_back({ key, me, "@@ generated from content.lua\r\n" + text });
    return r;
}

// ---------- перехват локализации ----------

namespace
{
    // sub_5DE22C(eax = таблицы, edx = id таблицы, ecx = ключ, [esp+4] = var Result, [esp+8] = флаг), ret 8.
    // Её зовут GetLocaleTableListItemByID и сам движок (подсказки, %include%).
    constexpr uintptr_t VaLocaleItem = 0x5DE22C;
    constexpr uintptr_t VaLStrAsg = 0x405454;
    void* oLocaleItem = nullptr;
    void* g_lstrAsg = nullptr;

    struct Decision { int text; const char* value; };
    Decision g_decision;
    std::string g_lang;
    int g_langCheck = 0;

    std::string CurrentLang()
    {
        if (g_lang.empty() || ++g_langCheck % 500 == 0)
        {
            if (const NativeCall::Signature* sig = NativeCall::Find("GetLocaleTableListFileName"))
            {
                NativeCall::Value v;
                std::string error;
                if (NativeCall::Invoke(*sig, {}, &v, &error))
                {
                    std::string p = Lower(v.s);
                    size_t e = p.find_last_of("\\/");
                    size_t b = e == std::string::npos ? std::string::npos : p.find_last_of("\\/", e - 1);
                    if (b != std::string::npos)
                        g_lang = p.substr(b + 1, e - b - 1);
                }
            }
        }
        return g_lang;
    }

    const char* Pick(const std::string& key, const Names& names)
    {
        std::string lang = CurrentLang();
        auto it = names.find(lang);
        if (it == names.end()) it = names.find("*");
        if (it == names.end()) it = names.find("en");
        if (it == names.end()) it = names.begin();
        std::string cacheKey = key + "|" + it->first;
        auto c = g_locCache.find(cacheKey);
        if (c == g_locCache.end())
            c = g_locCache.emplace(cacheKey, GameApi::DelphiString(Text::Utf8ToAnsi(it->second))).first;
        return c->second.get();
    }

    // null — как есть; text=1 — вернуть value; text=0 — искать по ключу value (родитель).
    Decision* __cdecl DecideLocale(const char* table, const char* key)
    {
        if (!key || !*key)
            return nullptr;
        std::lock_guard lock(g_locMutex);
        std::string k = Lower(key);
        if (auto t = g_locText.find(k); t != g_locText.end())
        {
            g_decision = { 1, Pick(k, t->second) };
            return &g_decision;
        }
        // "mlserdiuk" / "mlserdiuk.ext" -> "serdiuk" / "serdiuk.ext"
        size_t dot = k.find('.');
        std::string head = k.substr(0, dot);
        if (auto a = g_locAlias.find(head); a != g_locAlias.end())
        {
            std::string alias = a->second + (dot == std::string::npos ? "" : k.substr(dot));
            auto c = g_locCache.find("@" + alias);
            if (c == g_locCache.end())
                c = g_locCache.emplace("@" + alias, GameApi::DelphiString(alias)).first;
            g_decision = { 0, c->second.get() };
            return &g_decision;
        }
        (void)table;
        return nullptr;
    }

    __declspec(naked) void hkLocaleItem()
    {
        __asm
        {
            push eax
            push edx
            push ecx
            push ecx
            push edx
            call DecideLocale
            add esp, 8
            pop ecx
            pop edx
            test eax, eax
            jz passthrough
            cmp dword ptr [eax], 0
            je alias
            // своя строка: Result := value; ret 8
            mov edx, [eax+4]
            pop eax
            mov eax, [esp+4]
            call g_lstrAsg
            ret 8
        alias:
            mov ecx, [eax+4]
        passthrough:
            pop eax
            jmp oLocaleItem
        }
    }
}

bool Content::InstallLocale()
{
    {
        std::lock_guard lock(g_locMutex);
        if (g_locText.empty() && g_locAlias.empty())
            return true;
    }
    g_lstrAsg = GameApi::Addr(VaLStrAsg);
    return Hooks::CreateRaw("Locale item", GameApi::Addr(VaLocaleItem), reinterpret_cast<void*>(hkLocaleItem), &oLocaleItem);
}

void Content::Print()
{
    if (g_nations.empty() && g_units.empty())
    {
        Console::Print("No content.lua definitions. A mod can add nations and unit types: see MODDING.md");
        return;
    }
    for (const NationDef& n : g_nations)
        Console::Print("  nation %-10s id %-3d like %-4s  (%s)", n.sid.c_str(), n.id, n.from.c_str(), n.mod.c_str());
    for (const UnitDef& u : g_units)
    {
        std::string ns;
        for (const std::string& n : u.nations)
            ns += (ns.empty() ? "" : ",") + n;
        Console::Print("  unit   %-14s like %-14s nations %s  (%s)", u.sid.c_str(), u.from.c_str(), ns.c_str(), u.mod.c_str());
    }
}
