#include "pch.h"
#include "LuaHost.h"
#include "Console.h"
#include "Events.h"
#include "Game.h"
#include "GfxApi.h"
#include "NativeCall.h"
#include "Net.h"
#include "PostFx.h"
#include "ScriptRunner.h"
#include "Text.h"
#include "Ui.h"
#include "WebUi.h"

// Lua собран как C++ (исключения вместо longjmp) — заголовки подключаются без extern "C".
#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"

#include <algorithm>
#include <filesystem>
#include <fstream>
#include <map>
#include <sstream>

namespace fs = std::filesystem;

namespace
{
    enum Side { Client = 0, Server = 1 };
    const char* SideName(int side) { return side == Server ? "server" : "client"; }

    struct Env
    {
        int envRef = LUA_NOREF;
        int loadedRef = LUA_NOREF; // кэш require этой стороны
    };

    struct Bind
    {
        std::string key;
        int vk = 0;
        bool ctrl = false, shift = false, alt = false;
        int ref = LUA_NOREF;
        bool wasDown = false;
    };

    struct Mod
    {
        fs::path dir;
        std::string folder; // имя папки
        std::string id, name, version, author, description;
        std::string entry[2];            // client / server
        // Код из shared = "..." грузится в серверное окружение, но работает и у клиента: в сетевой
        // игре обе стороны считают партию сами, и всё, что меняет мир (создание объектов, их
        // перемещение), должно произойти одинаково у всех, иначе расходятся номера объектов.
        bool shared = false;
        std::string multiplayer = "required";
        std::map<std::string, fs::path> files; // имя модуля ("utils", "lib/math") -> путь
        bool enabled = true;
        bool loaded = false;
        std::string error;
        Env env[2];
        std::vector<int> subscriptions;                        // Events ids
        std::map<std::string, std::vector<int>> netHandlers[2]; // event -> refs функций
        std::vector<Bind> binds;                                // client
        std::map<int, int> clickHandlers;                       // client: элемент интерфейса -> ref функции
    };

    lua_State* L = nullptr;
    std::vector<Mod> g_mods;
    Mod g_console; // псевдо-мод для строк из консоли (права server)
    int g_baseEnvRef[2] = { LUA_NOREF, LUA_NOREF };

    // ---------- утилиты ----------

    fs::path ModsDir()
    {
        wchar_t exe[MAX_PATH];
        GetModuleFileNameW(nullptr, exe, MAX_PATH);
        return fs::path(exe).parent_path() / L"modloader" / L"mods";
    }

    // modloader/modstate.txt: строки "id=1" / "id=0" — переопределяют enabled из манифеста.
    fs::path StateFile()
    {
        return ModsDir().parent_path() / L"modstate.txt";
    }

    std::map<std::string, bool> LoadModState()
    {
        std::map<std::string, bool> state;
        std::ifstream in(StateFile());
        std::string line;
        while (std::getline(in, line))
        {
            size_t eq = line.find('=');
            if (eq != std::string::npos && eq > 0 && line[0] != '#')
                state[line.substr(0, eq)] = line.compare(eq + 1, 1, "1") == 0;
        }
        return state;
    }

    void SaveModState(const std::map<std::string, bool>& state)
    {
        std::ofstream out(StateFile(), std::ios::trunc);
        out << "# Cossacks 3 Modloader: mod on/off overrides (id=1 / id=0). Managed by the in-game menu.\n";
        for (const auto& [id, on] : state)
            out << id << '=' << (on ? 1 : 0) << '\n';
    }

    bool ReadFile(const fs::path& path, std::string* out)
    {
        std::ifstream in(path, std::ios::binary);
        if (!in)
            return false;
        std::ostringstream ss;
        ss << in.rdbuf();
        *out = ss.str();
        if (out->size() >= 3 && static_cast<unsigned char>((*out)[0]) == 0xEF) // UTF-8 BOM
            out->erase(0, 3);
        return true;
    }

    std::string Lower(std::string s)
    {
        std::transform(s.begin(), s.end(), s.begin(), [](unsigned char c) { return static_cast<char>(tolower(c)); });
        return s;
    }

    fs::path FromUtf8(const std::string& s)
    {
        return fs::path(std::u8string(s.begin(), s.end()));
    }

    std::string ToUtf8(const fs::path& p)
    {
        std::u8string u = p.u8string();
        return std::string(u.begin(), u.end());
    }

    // Путь из манифеста: только относительный, внутри папки мода, только .lua.
    bool ValidRelativePath(const std::string& p, std::string* why)
    {
        if (p.empty() || p.find(':') != std::string::npos || p[0] == '/' || p[0] == '\\')
            return *why = "must be a relative path", false;
        if (p.find("..") != std::string::npos)
            return *why = "'..' is not allowed", false;
        if (p.size() < 5 || Lower(p.substr(p.size() - 4)) != ".lua")
            return *why = "only .lua files can be listed", false;
        return true;
    }

    std::string ModuleKey(std::string name) // "lib.utils" / "lib/utils.lua" / "lib\\utils" -> "lib/utils"
    {
        name = Lower(name);
        if (name.size() > 4 && name.compare(name.size() - 4, 4, ".lua") == 0)
            name.resize(name.size() - 4);
        std::replace(name.begin(), name.end(), '\\', '/');
        if (name.find('/') == std::string::npos)
            std::replace(name.begin(), name.end(), '.', '/');
        return name;
    }

    std::string Concat(lua_State* L, int first) // аргументы через пробел, как print
    {
        std::string out;
        int n = lua_gettop(L);
        for (int i = first; i <= n; ++i)
        {
            if (i > first)
                out += ' ';
            out += luaL_tolstring(L, i, nullptr);
            lua_pop(L, 1);
        }
        return out;
    }

    int Traceback(lua_State* L)
    {
        const char* msg = lua_tostring(L, 1);
        luaL_traceback(L, L, msg ? msg : "(error object is not a string)", 1);
        return 1;
    }

    // pcall с трассировкой; false — ошибка уже залогирована.
    bool Call(int nargs, int nresults, const std::string& who)
    {
        int base = lua_gettop(L) - nargs;
        lua_pushcfunction(L, Traceback);
        lua_insert(L, base);
        int rc = lua_pcall(L, nargs, nresults, base);
        lua_remove(L, base);
        if (rc != LUA_OK)
        {
            LOG_ERROR("[lua:%s] %s", who.c_str(), lua_tostring(L, -1));
            lua_pop(L, 1);
            return false;
        }
        return true;
    }

    // Загрузить чанк из текста и выставить ему _ENV = env (из реестра).
    bool LoadChunk(const std::string& code, const std::string& chunkName, int envRef, std::string* error)
    {
        if (luaL_loadbufferx(L, code.data(), code.size(), chunkName.c_str(), "t") != LUA_OK)
        {
            *error = lua_tostring(L, -1);
            lua_pop(L, 1);
            return false;
        }
        lua_rawgeti(L, LUA_REGISTRYINDEX, envRef);
        lua_setupvalue(L, -2, 1);
        return true;
    }

    // Замыкания API получают (индекс мода, сторона) в upvalue 1 и 2.
    Mod* ModFromUpvalue(lua_State* L)
    {
        int index = static_cast<int>(lua_tointeger(L, lua_upvalueindex(1)));
        return index < 0 ? &g_console : &g_mods[index];
    }

    int SideFromUpvalue(lua_State* L)
    {
        return static_cast<int>(lua_tointeger(L, lua_upvalueindex(2)));
    }

    std::string Who(const Mod& mod, int side)
    {
        return mod.id + ":" + SideName(side);
    }

    // ---------- сериализация для сети (без load(): из пакета нельзя выполнить код) ----------

    void Encode(lua_State* L, int idx, std::string& out, int depth)
    {
        if (depth > 16)
            luaL_error(L, "net: table is nested too deeply");
        idx = lua_absindex(L, idx);
        switch (lua_type(L, idx))
        {
        case LUA_TNIL: out += 'n'; break;
        case LUA_TBOOLEAN: out += lua_toboolean(L, idx) ? 't' : 'f'; break;
        case LUA_TNUMBER:
        {
            char buf[64];
            if (lua_isinteger(L, idx))
                snprintf(buf, sizeof(buf), "i%lld;", static_cast<long long>(lua_tointeger(L, idx)));
            else
                snprintf(buf, sizeof(buf), "d%.17g;", lua_tonumber(L, idx));
            out += buf;
            break;
        }
        case LUA_TSTRING:
        {
            size_t len;
            const char* s = lua_tolstring(L, idx, &len);
            out += 's' + std::to_string(len) + ':';
            out.append(s, len);
            break;
        }
        case LUA_TTABLE:
            out += '{';
            lua_pushnil(L);
            while (lua_next(L, idx))
            {
                int kt = lua_type(L, -2);
                if (kt != LUA_TSTRING && kt != LUA_TNUMBER && kt != LUA_TBOOLEAN)
                    luaL_error(L, "net: table keys must be strings, numbers or booleans");
                Encode(L, -2, out, depth + 1);
                Encode(L, -1, out, depth + 1);
                lua_pop(L, 1);
            }
            out += '}';
            break;
        default:
            luaL_error(L, "net: cannot send a %s", luaL_typename(L, idx));
        }
    }

    // Кладёт значение на стек; false — данные повреждены.
    bool Decode(lua_State* L, const std::string& s, size_t& pos, int depth)
    {
        if (pos >= s.size() || depth > 16)
            return false;
        char tag = s[pos++];
        auto readUntil = [&](char end, std::string* out) {
            size_t e = s.find(end, pos);
            if (e == std::string::npos)
                return false;
            *out = s.substr(pos, e - pos);
            pos = e + 1;
            return true;
        };
        switch (tag)
        {
        case 'n': lua_pushnil(L); return true;
        case 't': lua_pushboolean(L, 1); return true;
        case 'f': lua_pushboolean(L, 0); return true;
        case 'i':
        {
            std::string num;
            if (!readUntil(';', &num))
                return false;
            lua_pushinteger(L, strtoll(num.c_str(), nullptr, 10));
            return true;
        }
        case 'd':
        {
            std::string num;
            if (!readUntil(';', &num))
                return false;
            lua_pushnumber(L, strtod(num.c_str(), nullptr));
            return true;
        }
        case 's':
        {
            std::string len;
            if (!readUntil(':', &len) || len.empty() || len.size() > 9)
                return false;
            size_t n = strtoul(len.c_str(), nullptr, 10);
            if (pos + n > s.size())
                return false;
            lua_pushlstring(L, s.data() + pos, n);
            pos += n;
            return true;
        }
        case '{':
            lua_newtable(L);
            while (pos < s.size() && s[pos] != '}')
            {
                if (!Decode(L, s, pos, depth + 1))
                    return lua_pop(L, 1), false;
                if (lua_isnil(L, -1) || !Decode(L, s, pos, depth + 1))
                    return lua_pop(L, 2), false;
                lua_rawset(L, -3);
            }
            if (pos >= s.size())
                return lua_pop(L, 1), false;
            ++pos; // '}'
            return true;
        default:
            return false;
        }
    }

    // ---------- API: log / print / require ----------

    int l_log(lua_State* L, int level)
    {
        Mod* mod = ModFromUpvalue(L);
        std::string text = Concat(L, 1);
        std::string who = mod == &g_console ? mod->id : Who(*mod, SideFromUpvalue(L));
        if (level == 0) LOG_INFO("\x1b[34m[%s]\x1b[0m %s", who.c_str(), text.c_str());
        else if (level == 1) LOG_WARN("\x1b[34m[%s]\x1b[0m %s", who.c_str(), text.c_str());
        else LOG_ERROR("\x1b[34m[%s]\x1b[0m %s", who.c_str(), text.c_str());
        return 0;
    }
    int l_logInfo(lua_State* L) { return l_log(L, 0); }
    int l_logWarn(lua_State* L) { return l_log(L, 1); }
    int l_logError(lua_State* L) { return l_log(L, 2); }

    int l_require(lua_State* L)
    {
        Mod* mod = ModFromUpvalue(L);
        int side = SideFromUpvalue(L);
        std::string key = ModuleKey(luaL_checkstring(L, 1));

        lua_rawgeti(L, LUA_REGISTRYINDEX, mod->env[side].loadedRef);
        lua_getfield(L, -1, key.c_str());
        if (!lua_isnil(L, -1))
            return 1;
        lua_pop(L, 1);

        auto it = mod->files.find(key);
        if (it == mod->files.end())
            return luaL_error(L, "module '%s' is not listed in manifest.lua files", key.c_str());

        std::string code, error;
        if (!ReadFile(it->second, &code))
            return luaL_error(L, "cannot read %s", key.c_str());
        if (!LoadChunk(code, "@" + mod->id + "/" + key + ".lua", mod->env[side].envRef, &error))
            return luaL_error(L, "%s", error.c_str());
        lua_call(L, 0, 1);
        if (lua_isnil(L, -1))
        {
            lua_pop(L, 1);
            lua_pushboolean(L, 1);
        }
        lua_pushvalue(L, -1);
        lua_setfield(L, -3, key.c_str()); // loaded[key] = result (у каждой стороны свой экземпляр модуля)
        return 1;
    }

    // ---------- API: game ----------

    std::vector<std::string> SplitLines(const std::string& s)
    {
        std::vector<std::string> lines;
        std::string line;
        std::istringstream in(s);
        while (std::getline(in, line))
        {
            if (!line.empty() && line.back() == '\r')
                line.pop_back();
            lines.push_back(line);
        }
        return lines;
    }

    std::string PascalQuote(const std::string& s)
    {
        std::string out = "'";
        for (char c : s)
            out += c == '\'' ? std::string("''") : std::string(1, c);
        return out + "'";
    }

    // game.run(code) — асинхронно, как строка из консоли. Только server.
    int l_gameRun(lua_State* L)
    {
        ScriptRunner::Queue(SplitLines(Text::Utf8ToAnsi(luaL_checkstring(L, 1))));
        return 0;
    }

    // game.command(text) — как текст в чате игры (res all 5000, cheat fog, ...). Только server.
    int l_gameCommand(lua_State* L)
    {
        std::string text = Text::Utf8ToAnsi(luaL_checkstring(L, 1));
        ScriptRunner::Queue({
            "var modloaderCmd : String = " + PascalQuote(text) + ";",
            "_misc_ProcessMessage(modloaderCmd);",
        });
        return 0;
    }

    // Синхронный вызов скрипта; результат ML_RET(...) — строкой (или nil).
    bool ScriptCall(const std::string& code, const std::string& arg, std::string* result)
    {
        if (!ScriptRunner::Call(Text::Utf8ToAnsi(code), Text::Utf8ToAnsi(arg), result))
            return false;
        *result = Text::AnsiToUtf8(*result);
        return true;
    }

    // game.exec(code [, arg]) -> строка из ML_RET или nil. ML_ARG в коде — это arg. Только server.
    int l_gameExec(lua_State* L)
    {
        std::string code = luaL_checkstring(L, 1);
        std::string arg = luaL_optstring(L, 2, "");
        std::string result;
        if (!ScriptCall(code, arg, &result))
            return luaL_error(L, "game script failed (see [engine] messages above)");
        lua_pushstring(L, result.c_str());
        return 1;
    }

    // wrapper — код с '#' на месте выражения; кладёт результат-строку на стек.
    int EvalAs(lua_State* L, const std::string& wrapper)
    {
        std::string expr = luaL_checkstring(L, 1);
        std::string code = wrapper;
        code.replace(code.find('#'), 1, expr);
        std::string result;
        if (!ScriptCall(code, "", &result))
            return luaL_error(L, "cannot evaluate '%s' (see [engine] messages above)", expr.c_str());
        lua_pushstring(L, result.c_str());
        return 1;
    }

    int l_gameEval(lua_State* L) { return EvalAs(L, "ML_RET(#);"); }

    int l_gameEvalInt(lua_State* L)
    {
        EvalAs(L, "ML_RET(IntToStr(#));");
        lua_Integer v = 0;
        sscanf_s(lua_tostring(L, -1), "%lld", &v);
        lua_pushinteger(L, v);
        return 1;
    }

    int l_gameEvalFloat(lua_State* L)
    {
        EvalAs(L, "ML_RET(FloatToStr(#));");
        std::string s = lua_tostring(L, -1);
        std::replace(s.begin(), s.end(), ',', '.'); // FloatToStr зависит от локали
        lua_pushnumber(L, atof(s.c_str()));
        return 1;
    }

    int l_gameEvalBool(lua_State* L)
    {
        EvalAs(L, "if (#) then ML_RET('1') else ML_RET('0');");
        lua_pushboolean(L, strcmp(lua_tostring(L, -1), "1") == 0);
        return 1;
    }

    // Роль этого компьютера: "offline" / "client" / "host".
    int l_gameMode(lua_State* L)
    {
        Game::LanMode m = Game::Mode();
        lua_pushstring(L, m == Game::LanMode::Server ? "host" : m == Game::LanMode::Client ? "client" : "offline");
        return 1;
    }

    int l_gameIsAuthority(lua_State* L)
    {
        lua_pushboolean(L, Game::IsAuthority());
        return 1;
    }

    // ---------- API: events ----------

    // Обработчик события из Lua (главный поток игры; L — глобальное состояние).
    void CallEventHandler(int ref, int side, bool everywhere, const std::string& who, const std::string& event,
                          const std::string& payload)
    {
        if (!L)
            return;
        if (side == Server && !everywhere && !Game::IsAuthority())
            return; // серверная логика работает только там, где решается игра
        lua_rawgeti(L, LUA_REGISTRYINDEX, ref);
        lua_pushstring(L, event.c_str());
        lua_pushstring(L, Text::AnsiToUtf8(payload).c_str());
        Call(2, 0, who);
    }

    int l_eventsOn(lua_State* L)
    {
        Mod* mod = ModFromUpvalue(L);
        int side = SideFromUpvalue(L);
        std::string event = luaL_checkstring(L, 1);
        luaL_checktype(L, 2, LUA_TFUNCTION);
        lua_pushvalue(L, 2);
        int ref = luaL_ref(L, LUA_REGISTRYINDEX);
        std::string who = Who(*mod, side);

        bool everywhere = mod->shared;
        int id = Events::Subscribe(event, [ref, side, everywhere, who](const std::string& name, const std::string& payload) {
            CallEventHandler(ref, side, everywhere, who, name, payload);
        });
        mod->subscriptions.push_back(id);
        lua_pushinteger(L, id);
        return 1;
    }

    int l_eventsOff(lua_State* L)
    {
        Mod* mod = ModFromUpvalue(L);
        int id = static_cast<int>(luaL_checkinteger(L, 1));
        Events::Unsubscribe(id);
        std::erase(mod->subscriptions, id);
        return 0;
    }

    int l_eventsHook(lua_State* L)
    {
        Events::HookGuiState(luaL_checkstring(L, 1), lua_toboolean(L, 2) != 0);
        return 0;
    }

    // ---------- API: net ----------

    int l_netOn(lua_State* L)
    {
        Mod* mod = ModFromUpvalue(L);
        int side = SideFromUpvalue(L);
        std::string event = luaL_checkstring(L, 1);
        luaL_checktype(L, 2, LUA_TFUNCTION);
        lua_pushvalue(L, 2);
        mod->netHandlers[side][event].push_back(luaL_ref(L, LUA_REGISTRYINDEX));
        return 0;
    }

    std::string EncodeArg(lua_State* L, int idx)
    {
        std::string data;
        if (!lua_isnoneornil(L, idx))
            Encode(L, idx, data, 0);
        return data;
    }

    // client: net.send(event, data) — хосту (в одиночной игре — своему server-скрипту).
    int l_netSend(lua_State* L)
    {
        Mod* mod = ModFromUpvalue(L);
        std::string event = luaL_checkstring(L, 1);
        std::string error;
        if (!Net::SendToServer(mod->id, event, EncodeArg(L, 2), &error))
            return luaL_error(L, "net.send: %s", error.c_str());
        return 0;
    }

    // server: net.broadcast(event, data) — всем клиентам, включая клиентскую сторону хоста.
    int l_netBroadcast(lua_State* L)
    {
        Mod* mod = ModFromUpvalue(L);
        std::string event = luaL_checkstring(L, 1);
        std::string error;
        if (!Net::Broadcast(mod->id, event, EncodeArg(L, 2), &error))
            return luaL_error(L, "net.broadcast: %s", error.c_str());
        return 0;
    }

    // ---------- API: input (client) ----------

    int ParseKey(const std::string& name)
    {
        std::string k = Lower(name);
        if (k.size() == 1 && isalnum(static_cast<unsigned char>(k[0])))
            return toupper(k[0]);
        if (k.size() >= 2 && k[0] == 'f' && isdigit(static_cast<unsigned char>(k[1])))
        {
            int n = atoi(k.c_str() + 1);
            return n >= 1 && n <= 12 ? VK_F1 + n - 1 : 0;
        }
        if (k.rfind("num", 0) == 0 && k.size() == 4 && isdigit(static_cast<unsigned char>(k[3])))
            return VK_NUMPAD0 + (k[3] - '0');
        static const std::map<std::string, int> named = {
            { "space", VK_SPACE }, { "enter", VK_RETURN }, { "tab", VK_TAB }, { "escape", VK_ESCAPE },
            { "backspace", VK_BACK }, { "delete", VK_DELETE }, { "home", VK_HOME }, { "pageup", VK_PRIOR },
            { "pagedown", VK_NEXT }, { "up", VK_UP }, { "down", VK_DOWN }, { "left", VK_LEFT }, { "right", VK_RIGHT },
        };
        auto it = named.find(k);
        return it != named.end() ? it->second : 0;
    }

    // input.bind("Ctrl+F5", function(key) ... end)
    int l_inputBind(lua_State* L)
    {
        Mod* mod = ModFromUpvalue(L);
        std::string spec = luaL_checkstring(L, 1);
        luaL_checktype(L, 2, LUA_TFUNCTION);

        Bind bind;
        bind.key = spec;
        std::string rest = spec;
        for (;;)
        {
            std::string low = Lower(rest);
            if (low.rfind("ctrl+", 0) == 0) { bind.ctrl = true; rest = rest.substr(5); }
            else if (low.rfind("shift+", 0) == 0) { bind.shift = true; rest = rest.substr(6); }
            else if (low.rfind("alt+", 0) == 0) { bind.alt = true; rest = rest.substr(4); }
            else break;
        }
        bind.vk = ParseKey(rest);
        if (!bind.vk)
            return luaL_error(L, "input.bind: unknown key '%s' (F1-F12, A-Z, 0-9, Num0-Num9, Space, Enter, arrows...)", spec.c_str());
        if (!bind.ctrl && !bind.shift && !bind.alt && (bind.vk == VK_F9))
            LOG_WARN("[%s] input.bind: %s is also used by the modloader", mod->id.c_str(), spec.c_str());

        lua_pushvalue(L, 2);
        bind.ref = luaL_ref(L, LUA_REGISTRYINDEX);
        mod->binds.push_back(bind);
        return 0;
    }

    // ---------- API: ui (client) ----------

    Ui::Color ReadColor(lua_State* L, int t)
    {
        Ui::Color c;
        if (lua_getfield(L, t, "color") == LUA_TTABLE)
        {
            int ct = lua_gettop(L);
            auto channel = [&](int i, int def) {
                lua_rawgeti(L, ct, i);
                int v = lua_isinteger(L, -1) ? static_cast<int>(lua_tointeger(L, -1)) : def;
                lua_pop(L, 1);
                return std::clamp(v, 0, 255);
            };
            c = { channel(1, 255), channel(2, 255), channel(3, 255), channel(4, 255) };
        }
        lua_pop(L, 1);
        return c;
    }

    int IntField(lua_State* L, int t, const char* key, int def)
    {
        lua_getfield(L, t, key);
        int v = lua_isnumber(L, -1) ? static_cast<int>(lua_tointeger(L, -1)) : def;
        lua_pop(L, 1);
        return v;
    }

    std::string StrField(lua_State* L, int t, const char* key, const std::string& def = {})
    {
        lua_getfield(L, t, key);
        std::string v = lua_isstring(L, -1) ? lua_tostring(L, -1) : def;
        lua_pop(L, 1);
        return v;
    }

    // align = "middle" / "parentMiddle" / { "parentMiddle", "parentTop" } / { h = ..., v = ... }.
    // Значения — суффиксы констант игры. Их два семейства, и это легко перепутать:
    //   left/middle/right, top/middle/bottom                 — отсчёт от ЭКРАНА;
    //   parentLeft/parentMiddle/..., parentTop/parentBottom  — от родительского элемента.
    // Всё, что лежит внутри контейнера, выравнивают parent*, иначе оно прилипнет к краю экрана.
    Ui::Align ReadAlign(lua_State* L, int t)
    {
        Ui::Align a;
        auto name = [](const char* prefix, const std::string& v) { return std::string(prefix) + char(toupper(v[0])) + v.substr(1); };
        if (lua_getfield(L, t, "align") == LUA_TSTRING)
        {
            std::string v = lua_tostring(L, -1);
            if (!v.empty())
                a = { name("gc_hal", v), name("gc_val", v) };
        }
        else if (lua_type(L, -1) == LUA_TTABLE)
        {
            int at = lua_gettop(L);
            auto part = [&](const char* key, int index) {
                if (lua_getfield(L, at, key) != LUA_TSTRING)
                {
                    lua_pop(L, 1);
                    lua_rawgeti(L, at, index);
                }
                std::string v = lua_isstring(L, -1) ? lua_tostring(L, -1) : "";
                lua_pop(L, 1);
                return v;
            };
            std::string h = part("h", 1), v = part("v", 2);
            if (!h.empty()) a.h = name("gc_hal", h);
            if (!v.empty()) a.v = name("gc_val", v);
        }
        lua_pop(L, 1);
        return a;
    }

    int PushElement(lua_State* L, int handle, const std::string& what, const std::string& name)
    {
        if (!handle)
            return luaL_error(L, "ui.%s '%s' failed (see [engine] messages above)", what.c_str(), name.c_str());
        lua_pushinteger(L, handle);
        return 1;
    }

    // ui.window{ name=, parent=0, x=, y=, w=, h= }
    int l_uiWindow(lua_State* L)
    {
        luaL_checktype(L, 1, LUA_TTABLE);
        std::string name = StrField(L, 1, "name");
        return PushElement(L, Ui::CreateGameWindow(name, IntField(L, 1, "parent", 0), IntField(L, 1, "x", 0), IntField(L, 1, "y", 0),
                                               IntField(L, 1, "w", 200), IntField(L, 1, "h", 100)), "window", name);
    }

    // ui.text{ name=, parent=0, text=, x=, y=, w=0, h=0, font="gc_font_serif_15", color={r,g,b,a} }
    int l_uiText(lua_State* L)
    {
        luaL_checktype(L, 1, LUA_TTABLE);
        std::string name = StrField(L, 1, "name");
        return PushElement(L, Ui::CreateGameText(name, IntField(L, 1, "parent", 0), StrField(L, 1, "text"), IntField(L, 1, "x", 0),
                                             IntField(L, 1, "y", 0), IntField(L, 1, "w", 0), IntField(L, 1, "h", 0),
                                             StrField(L, 1, "font", "gc_font_serif_15"), ReadColor(L, 1), ReadAlign(L, 1)),
                          "text", name);
    }

    // ui.container{ name=, parent=0, x=, y=, w=, h=, align= } — пустой элемент под остальные.
    // Свой экран начинается с него: элемент, созданный прямо под верхним уровнем, движок прячет.
    int l_uiContainer(lua_State* L)
    {
        luaL_checktype(L, 1, LUA_TTABLE);
        std::string name = StrField(L, 1, "name");
        return PushElement(L, Ui::CreateGameContainer(name, IntField(L, 1, "parent", 0), IntField(L, 1, "x", 0),
                                                      IntField(L, 1, "y", 0), IntField(L, 1, "w", 0),
                                                      IntField(L, 1, "h", 0), ReadAlign(L, 1)), "container", name);
    }

    // ui.image{ name=, parent=0, material="mainmenu_art", x=, y=, w=0, h=0, align= }
    // w/h 0 — размер самой текстуры игры.
    int l_uiImage(lua_State* L)
    {
        luaL_checktype(L, 1, LUA_TTABLE);
        std::string name = StrField(L, 1, "name");
        return PushElement(L, Ui::CreateGameImage(name, IntField(L, 1, "parent", 0), StrField(L, 1, "material"),
                                                  IntField(L, 1, "x", 0), IntField(L, 1, "y", 0), IntField(L, 1, "w", 0),
                                                  IntField(L, 1, "h", 0), ReadAlign(L, 1)), "image", name);
    }

    // ui.exec("ShowSettings") — запустить состояние интерфейса игры как есть.
    int l_uiExec(lua_State* L)
    {
        Ui::ExecuteState(luaL_checkstring(L, 1));
        return 0;
    }

    // ui.sendTag("EventMainMenu", 103) — то же, что нажатие родной кнопки с этим тэгом.
    int l_uiSendTag(lua_State* L)
    {
        Ui::SendTag(luaL_checkstring(L, 1), static_cast<int>(luaL_checkinteger(L, 2)));
        return 0;
    }

    // ui.button{ name=, parent=0, text=, x=, y=, w=0, h=0, material="btn.large", hint="", tag=0, align=,
    //            onClick=function(element) end }
    // w/h 0 — размер картинки материала; иначе картинка тянется под заданный размер.
    int l_uiButton(lua_State* L)
    {
        Mod* mod = ModFromUpvalue(L);
        luaL_checktype(L, 1, LUA_TTABLE);
        std::string name = StrField(L, 1, "name");
        int handle = Ui::CreateGameButton(name, IntField(L, 1, "parent", 0), StrField(L, 1, "text"), IntField(L, 1, "x", 0),
                                      IntField(L, 1, "y", 0), IntField(L, 1, "w", 0), IntField(L, 1, "h", 0),
                                      StrField(L, 1, "material", "btn.large"), StrField(L, 1, "hint"),
                                      IntField(L, 1, "tag", 0), ReadAlign(L, 1));
        if (handle && lua_getfield(L, 1, "onClick") == LUA_TFUNCTION)
        {
            auto it = mod->clickHandlers.find(handle);
            if (it != mod->clickHandlers.end())
                luaL_unref(L, LUA_REGISTRYINDEX, it->second); // кнопку пересоздали — старый обработчик не нужен
            mod->clickHandlers[handle] = luaL_ref(L, LUA_REGISTRYINDEX);
        }
        else
            lua_pop(L, 1);
        return PushElement(L, handle, "button", name);
    }

    // ui.onClick(element, function(element) end) — для любой нашей кнопки
    int l_uiOnClick(lua_State* L)
    {
        Mod* mod = ModFromUpvalue(L);
        int handle = static_cast<int>(luaL_checkinteger(L, 1));
        luaL_checktype(L, 2, LUA_TFUNCTION);
        lua_pushvalue(L, 2);
        mod->clickHandlers[handle] = luaL_ref(L, LUA_REGISTRYINDEX);
        return 0;
    }

    // Обработчик ui.hookState (главный поток игры; L — глобальное состояние). payload: "элемент|press|tag".
    void CallStateHook(int ref, const std::string& who, const std::string& payload)
    {
        if (!L)
            return;
        int element = atoi(payload.c_str());
        size_t a = payload.find('|'), b = a == std::string::npos ? a : payload.find('|', a + 1);
        std::string press = a != std::string::npos ? payload.substr(a + 1, (b == std::string::npos ? payload.size() : b) - a - 1) : "";
        int tag = b != std::string::npos ? atoi(payload.c_str() + b + 1) : 0;

        lua_rawgeti(L, LUA_REGISTRYINDEX, ref);
        lua_pushinteger(L, element);
        lua_pushstring(L, press.c_str());
        lua_pushinteger(L, tag);
        if (Call(3, 1, who))
        {
            if (lua_toboolean(L, -1))
                Events::RequestBlock(); // обработчик вернул true — игра это нажатие не обработает
            lua_pop(L, 1);
        }
    }

    // ui.hookState("EventMenu", function(element, press, tag) return true --[[ = игра не обработает ]] end)
    int l_uiHookState(lua_State* L)
    {
        Mod* mod = ModFromUpvalue(L);
        std::string state = luaL_checkstring(L, 1);
        luaL_checktype(L, 2, LUA_TFUNCTION);
        lua_pushvalue(L, 2);
        int ref = luaL_ref(L, LUA_REGISTRYINDEX);
        std::string who = Who(*mod, Client);

        Ui::HookState(state);
        int id = Events::Subscribe("guistate." + state, [ref, who](const std::string&, const std::string& payload) {
            CallStateHook(ref, who, payload);
        });
        mod->subscriptions.push_back(id);
        return 0;
    }

    // Обработчик ui.screen (главный поток игры, внутри перехваченного состояния; L — глобальное состояние).
    void CallScreenHook(int ref, const std::string& who)
    {
        if (!L)
            return;
        lua_rawgeti(L, LUA_REGISTRYINDEX, ref);
        if (!Call(0, 1, who))
            return; // ошибка в моде — блок не ставим, игра нарисует свой экран
        bool keepOriginal = lua_isboolean(L, -1) && !lua_toboolean(L, -1);
        lua_pop(L, 1);
        if (!keepOriginal)
            Events::RequestBlock();
    }

    // ui.screen("MainMenu", function() ... end) — рисовать экран самим.
    // Игра строит экраны состояниями ShowMainMenu / ShowSettings / ShowHud и т.д.; мы перехватываем
    // состояние целиком: родной код не выполняется, вместо него зовётся функция мода, и она создаёт
    // элементы теми же ui.*. Вернуть false — построить своё И оставить родной экран.
    // Ошибка в функции мода тоже оставляет родной экран: без интерфейса игрок не останется.
    int l_uiScreen(lua_State* L)
    {
        Mod* mod = ModFromUpvalue(L);
        std::string screen = luaL_checkstring(L, 1);
        luaL_checktype(L, 2, LUA_TFUNCTION);
        lua_pushvalue(L, 2);
        int ref = luaL_ref(L, LUA_REGISTRYINDEX);
        std::string who = Who(*mod, Client);
        std::string state = screen.rfind("Show", 0) == 0 ? screen : "Show" + screen;

        Ui::HookScreen(state);
        int id = Events::Subscribe("guiscreen." + state, [ref, who](const std::string&, const std::string&) {
            CallScreenHook(ref, who);
        });
        mod->subscriptions.push_back(id);
        return 0;
    }

    // mod.files("LoadScreen") — имена файлов в папке мода. Нужен, чтобы страница могла показать
    // содержимое папки: сама она каталог прочитать не может.
    int l_modFiles(lua_State* L)
    {
        Mod* mod = ModFromUpvalue(L);
        std::string sub = luaL_optstring(L, 1, "");
        // Только внутри мода: ".." и абсолютные пути не пропускаем.
        if (sub.find("..") != std::string::npos || sub.find(':') != std::string::npos)
            return luaL_error(L, "mod.files: only folders inside the mod are allowed");

        fs::path dir = sub.empty() ? mod->dir : mod->dir / fs::path(sub);
        lua_newtable(L);
        std::error_code ec;
        int n = 0;
        for (const auto& entry : fs::directory_iterator(dir, ec))
        {
            if (!entry.is_regular_file(ec))
                continue;
            lua_pushstring(L, entry.path().filename().string().c_str());
            lua_rawseti(L, -2, ++n);
        }
        return 1;
    }

    // ---------- API: web ----------

    // web.open("menu") — страница <папка мода>/web/menu.html. Можно передать и полный адрес.
    int l_webOpen(lua_State* L)
    {
        Mod* mod = ModFromUpvalue(L);
        std::string page = luaL_checkstring(L, 1);
        if (!WebUi::Available())
            return luaL_error(L, "web.open: CEF is not installed (see <game>/cef)");
        if (page.find("://") != std::string::npos)
            WebUi::RequestOpen(page);
        else
            WebUi::RequestOpen((mod->dir / L"web" / page).string());
        return 0;
    }

    int l_webClose(lua_State*)  { WebUi::RequestClose();  return 0; }
    int l_webReload(lua_State*) { WebUi::RequestReload(); return 0; }

    // web.isOpen() — страница уже на экране (экран интерфейса игра строит не один раз).
    int l_webIsOpen(lua_State* L)
    {
        lua_pushboolean(L, WebUi::IsOpen());
        return 1;
    }

    // web.eval("document.title = 'x'") — выполнить код в открытой странице.
    int l_webEval(lua_State* L)
    {
        WebUi::RequestEval(luaL_checkstring(L, 1));
        return 0;
    }

    // Общие функции работы с элементами (базовое окружение клиента).
    const char* kClientPrelude = R"lua(
ui = {}

-- Элемент интерфейса по имени: верхнего уровня или внутри parent. nil — не найден.
function ui.find(name, parent)
    local h = parent and native.GetGUIElementIndexByNameParent(name, parent) or native.GetGUIElementTopIndexByName(name)
    if h == 0 then return nil end
    return h
end
function ui.name(h) return native.GetGUIElementNameByIndex(h) end
function ui.getText(h) return native.GetGUIElementText(h) end
function ui.setText(h, text) native.SetGUIElementText(h, text) end
function ui.isVisible(h) return native.GetGUIElementVisible(h) end
function ui.setVisible(h, visible) native.SetGUIElementVisible(h, visible) end
function ui.getPosition(h) return native.GetGUIElementPositionX(h), native.GetGUIElementPositionY(h) end
function ui.setPosition(h, x, y) native.SetGUIElementPosition(h, x, y) end
function ui.setHint(h, hint) native.SetGUIElementHint(h, hint) end
-- Прозрачность элемента вместе с детьми: 1 — непрозрачный, 0 — невидимый.
function ui.setBlend(h, alpha) native.SetGUIElementUserBlend(h, alpha) end
function ui.remove(h) native.RemoveGUIElement(h) end
-- Размер окна игры: свой экран надо раскладывать от него, разрешение меняется на лету.
function ui.size() return native.GetViewerWidth(), native.GetViewerHeight() end
-- Размер картинки из библиотек интерфейса ('mainmenu_art', 'logo_small').
function ui.imageSize(material) return native.GetGUITextureWidth(material), native.GetGUITextureHeight(material) end
-- Строка из локализации игры: ui.locale('gui', 'menu.btn.exit') — свой экран будет на языке игрока.
function ui.locale(table, key) return native.GetLocaleTableListItemByID(table, key) end
-- Отладка: что движок думает про элемент — имя, родитель, видимость, положение, размер, материал.
function ui.dump(h)
    if not h or h == 0 then return "nil" end
    return string.format("%d '%s' parent=%d vis=%s pos=%d,%d size=%dx%d z=%d mat='%s'",
        h, native.GetGUIElementNameByIndex(h), native.GetGUIElementParentByIndex(h),
        tostring(native.GetGUIElementVisible(h)),
        native.GetGUIElementPositionX(h), native.GetGUIElementPositionY(h),
        native.GetGUIElementWidth(h), native.GetGUIElementHeight(h),
        native.GetGUIElementZOrder(h), native.GetGUIElementMaterial(h))
end
function ui.children(h)
    local list = {}
    for i = 0, native.GetGUIElementChildrenCount(h) - 1 do
        list[#list + 1] = native.GetGUIElementChildrenByIndex(h, i)
    end
    return list
end
)lua";

    // ---------- API: native ----------

    // Клиентским скриптам — нативы, которые ничего не меняют в игре: чтение (Get*, Is*, ...) и интерфейс
    // (*GUI* — меняет только картинку у этого игрока), кроме запуска состояний, которые могут делать что угодно.
    bool IsClientNative(const std::string& name)
    {
        static const char* prefixes[] = { "Get", "Is", "Has", "Can", "Calc", "Check", "Find", "Count" };
        for (const char* p : prefixes)
            if (name.rfind(p, 0) == 0)
                return true;
        bool gui = name.find("GUI") != std::string::npos;
        bool runsStates = name.find("ExecuteState") != std::string::npos || name.find("DelayExecute") != std::string::npos ||
                          name.find("TimeExec") != std::string::npos;
        return gui && !runsStates;
    }

    int l_nativeCall(lua_State* L)
    {
        auto sig = static_cast<const NativeCall::Signature*>(lua_touserdata(L, lua_upvalueindex(1)));
        if (!sig->error.empty())
            return luaL_error(L, "native.%s: %s", sig->name.c_str(), sig->error.c_str());
        if (lua_gettop(L) != sig->inputCount)
            return luaL_error(L, "native.%s expects %d argument(s): %s", sig->name.c_str(),
                              sig->inputCount, sig->decl.c_str());

        // var-параметры не передаются, а возвращаются — берём только обычные.
        std::vector<NativeCall::Type> inputs;
        for (size_t i = 0; i < sig->params.size(); ++i)
            if (!sig->byRef[i])
                inputs.push_back(sig->params[i]);

        std::vector<NativeCall::Value> args(inputs.size());
        for (size_t i = 0; i < inputs.size(); ++i)
        {
            int idx = static_cast<int>(i) + 1;
            NativeCall::Value& v = args[i];
            v.type = inputs[i];
            switch (v.type)
            {
            case NativeCall::Type::Int:    v.i = static_cast<int32_t>(luaL_checkinteger(L, idx)); break;
            case NativeCall::Type::Bool:   v.b = lua_toboolean(L, idx) != 0; break;
            case NativeCall::Type::Float:  v.f = static_cast<float>(luaL_checknumber(L, idx)); break;
            case NativeCall::Type::String: v.s = Text::Utf8ToAnsi(luaL_checkstring(L, idx)); break;
            default: break;
            }
        }

        NativeCall::Value result;
        std::vector<NativeCall::Value> outs;
        std::string error;
        if (!NativeCall::Invoke(*sig, args, &result, &error, &outs))
            return luaL_error(L, "native.%s: %s", sig->name.c_str(), error.c_str());

        int pushed = 0;
        switch (result.type)
        {
        case NativeCall::Type::Int:    lua_pushinteger(L, result.i); ++pushed; break;
        case NativeCall::Type::Bool:   lua_pushboolean(L, result.b); ++pushed; break;
        case NativeCall::Type::Float:  lua_pushnumber(L, result.f); ++pushed; break;
        case NativeCall::Type::String: lua_pushstring(L, Text::AnsiToUtf8(result.s).c_str()); ++pushed; break;
        default: break;
        }
        // Значения var-параметров идут следом: local x, y, z = native.GetCameraPosition()
        for (const NativeCall::Value& v : outs)
        {
            switch (v.type)
            {
            case NativeCall::Type::Bool:  lua_pushboolean(L, v.b); break;
            case NativeCall::Type::Float: lua_pushnumber(L, v.f); break;
            default:                      lua_pushinteger(L, v.i); break;
            }
            ++pushed;
        }
        return pushed;
    }

    int l_nativeServerOnly(lua_State* L)
    {
        return luaL_error(L, "native.%s can change the game — call it from server scripts",
                          lua_tostring(L, lua_upvalueindex(1)));
    }

    // native.<Name> — функция создаётся при первом обращении и кэшируется в таблице. upvalue 1 — сторона.
    int l_nativeIndex(lua_State* L)
    {
        const char* name = luaL_checkstring(L, 2);
        const NativeCall::Signature* sig = NativeCall::Find(name);
        if (!sig)
            return 0; // nil
        if (lua_tointeger(L, lua_upvalueindex(1)) == Client && !IsClientNative(sig->name))
        {
            lua_pushstring(L, sig->name.c_str());
            lua_pushcclosure(L, l_nativeServerOnly, 1);
        }
        else
        {
            lua_pushlightuserdata(L, const_cast<NativeCall::Signature*>(sig));
            lua_pushcclosure(L, l_nativeCall, 1);
        }
        lua_pushvalue(L, -1);
        lua_setfield(L, 1, name);
        return 1;
    }

    // ---------- API: gfx ----------

    // gfx.<Name> — как native.<Name>, но только нативы графики (GfxApi::IsGraphicsNative) и без
    // деления на стороны: картинка у каждого своя, на ход партии не влияет.
    int l_gfxIndex(lua_State* L)
    {
        const char* name = luaL_checkstring(L, 2);
        if (!GfxApi::IsGraphicsNative(name))
            return 0; // nil
        const NativeCall::Signature* sig = NativeCall::Find(name);
        if (!sig)
            return 0;
        lua_pushlightuserdata(L, const_cast<NativeCall::Signature*>(sig));
        lua_pushcclosure(L, l_nativeCall, 1);
        lua_pushvalue(L, -1);
        lua_setfield(L, 1, name);
        return 1;
    }

    // ---------- API: gfx.fx (поля пресета пост-обработки) ----------

    int FxIndex(lua_State* L, int arg)
    {
        return lua_isnoneornil(L, arg) ? -1 : static_cast<int>(luaL_checkinteger(L, arg));
    }

    void PushFxValue(lua_State* L, const PostFx::Value& v)
    {
        switch (v.type)
        {
        case PostFx::Type::Bool:   lua_pushboolean(L, v.boolean); break;
        case PostFx::Type::String: lua_pushstring(L, Text::AnsiToUtf8(v.text).c_str()); break;
        case PostFx::Type::Vector:
            lua_newtable(L);
            for (size_t i = 0; i < v.vector.size(); ++i)
            {
                lua_pushnumber(L, v.vector[i]);
                lua_rawseti(L, -2, static_cast<int>(i) + 1);
            }
            break;
        default: lua_pushnumber(L, v.number); break;
        }
    }

    // gfx.fx.fields() -> { {name=, type=, count=}, ... }
    int l_fxFields(lua_State* L)
    {
        static const char* kTypeName[] = { "float", "int", "bool", "string", "vector" };
        lua_newtable(L);
        int i = 1;
        for (const PostFx::Field& f : PostFx::Fields())
        {
            lua_newtable(L);
            lua_pushstring(L, f.name);                              lua_setfield(L, -2, "name");
            lua_pushstring(L, kTypeName[static_cast<int>(f.type)]); lua_setfield(L, -2, "type");
            lua_pushinteger(L, f.count);                            lua_setfield(L, -2, "count");
            lua_rawseti(L, -2, i++);
        }
        return 1;
    }

    // gfx.fx.info() -> количество, номер текущего, имя текущего
    int l_fxInfo(lua_State* L)
    {
        lua_pushinteger(L, PostFx::Count());
        lua_pushinteger(L, PostFx::Current());
        lua_pushstring(L, Text::AnsiToUtf8(PostFx::Name(-1)).c_str());
        return 3;
    }

    // gfx.fx.name(номер) — имя пресета из posteffects.lib
    int l_fxName(lua_State* L)
    {
        lua_pushstring(L, Text::AnsiToUtf8(PostFx::Name(FxIndex(L, 1))).c_str());
        return 1;
    }

    int l_fxGet(lua_State* L)
    {
        PostFx::Value value;
        std::string error;
        if (!PostFx::Get(FxIndex(L, 2), luaL_checkstring(L, 1), &value, &error))
            return luaL_error(L, "gfx.fx.get: %s", error.c_str());
        PushFxValue(L, value);
        return 1;
    }

    int l_fxSet(lua_State* L)
    {
        const char* name = luaL_checkstring(L, 1);
        PostFx::Value value;
        switch (lua_type(L, 2))
        {
        case LUA_TBOOLEAN:
            value.type = PostFx::Type::Bool;
            value.boolean = lua_toboolean(L, 2) != 0;
            break;
        case LUA_TSTRING:
            value.type = PostFx::Type::String;
            value.text = Text::Utf8ToAnsi(lua_tostring(L, 2));
            break;
        case LUA_TTABLE:
            value.type = PostFx::Type::Vector;
            for (lua_Integer i = 1; i <= luaL_len(L, 2); ++i)
            {
                lua_rawgeti(L, 2, i);
                value.vector.push_back(static_cast<float>(lua_tonumber(L, -1)));
                lua_pop(L, 1);
            }
            break;
        default:
            value.type = PostFx::Type::Float;
            value.number = luaL_checknumber(L, 2);
            break;
        }

        std::string error;
        if (!PostFx::Set(FxIndex(L, 3), name, value, &error))
            return luaL_error(L, "gfx.fx.set: %s", error.c_str());
        return 0;
    }

    int l_fxApply(lua_State* L)
    {
        std::string error;
        if (!PostFx::Apply(FxIndex(L, 1), &error))
            return luaL_error(L, "gfx.fx.apply: %s", error.c_str());
        return 0;
    }

    // Обёртки поверх game/native на Lua (исполняются в базовом окружении каждой стороны).
    const char* kPrelude = R"lua(
local RES = { food = 1, wood = 2, stone = 3, gold = 4, iron = 5, coal = 6 }

local function serverOnly(what)
    error(what .. " can only be changed by server scripts (client: send a request with net.send)", 3)
end

local Player = {}
Player.__index = function(self, key)
    local r = RES[key]
    if r then
        -- ресурсы хранятся инвертированными (not value) — защита игры от сканеров памяти
        return game.evalInt("not gPlayer[" .. rawget(self, "index") .. "].res[" .. r .. "]")
    end
    return Player[key]
end
Player.__newindex = function(self, key, value)
    local r = RES[key]
    if not r then error("player." .. tostring(key) .. " cannot be set", 2) end
    if not game.exec then serverOnly("player." .. key) end
    game.exec("_res_SetResToPlayerByIndex(" .. rawget(self, "index") .. ", " .. r .. ", StrToInt(ML_ARG));",
              tostring(math.floor(value)))
end
function Player:add(res, amount)
    local r = RES[res] or error("unknown resource '" .. tostring(res) .. "'", 2)
    if not game.exec then serverOnly("player resources") end
    game.exec("_res_AddResToPlayerByIndex(" .. self.index .. ", " .. r .. ", StrToInt(ML_ARG));",
              tostring(math.floor(amount)))
end

-- Идёт партия (не меню, не редактор, не наблюдатель) — так же проверяют скрипты игры.
function game.isInGame()
    return game.evalBool("gInterface.gamemode = gc_gamemode_game")
end

-- Индекс игрока по отправителю сетевого сообщения (from в net.on). 0 — этот компьютер вне сети.
-- Серверу нужно определять игрока так, а не верить номеру из данных: иначе клиент попросит за другого.
function game.playerIndexOf(from)
    if from == 0 then return native.GetPlayerIndexInterfaceIO() end
    return game.evalInt("_misc_GetMapPlayerIndexByLanID(" .. math.tointeger(from) .. ")")
end

-- Параметры будущей карты: игра читает их в самом начале создания партии (состояние DoNewGame,
-- data/gui/menu.inc/donewgame.inc), поэтому менять их надо в обработчике события game.prepare —
-- оно приходит ровно перед тем, как игра ими воспользуется.
--   world{ size = 2, mines = 3 }   -- записать (только сервер: это правила партии)
--   world()                        -- прочитать всё
local GEN = {
    size      = "mapsize",       -- 0 = 320, 1 = 480, 2 = 640, 3 = 256 клеток
    season    = "season",        -- 0 лето, 2 зима, 3 пустыня; меньше 0 — игра выберет сама
    terrain   = "terraintype",   -- 0..5, больше — случайный
    relief    = "relieftype",    -- 0..4, больше — случайный
    mines     = "resourcemines", -- плотность шахт
    resources = "resourcestart", -- 0 = 1000, 1 = 4000, 2 = 5000, иначе 1000000 каждого
    seed0     = "randkey0",      -- зерно генератора: одинаковое зерно — одинаковая карта
    seed1     = "randkey1",
}

local function worldRead()
    local out = {}
    for key, field in pairs(GEN) do
        out[key] = game.evalInt("gMap.settings.gen." .. field)
    end
    return out
end

local function worldWrite(values)
    if not game.exec then serverOnly("world settings") end
    for key, value in pairs(values) do
        local field = GEN[key] or error("world: unknown setting '" .. tostring(key) .. "'", 3)
        game.exec("gMap.settings.gen." .. field .. " := StrToInt(ML_ARG);", tostring(math.floor(value)))
    end
end

world = setmetatable({}, { __call = function(_, values)
    if values == nil then return worldRead() end
    worldWrite(values)
end })

-- player() — игрок за этим компьютером, player(i) — по индексу
function player(index)
    if index == nil then
        -- вне партии натив падает (игрока ещё нет) — сообщаем понятно
        if not game.isInGame() then error("player(): no local player outside of a game (check game.isInGame())", 2) end
        index = native.GetPlayerIndexInterfaceIO()
    end
    return setmetatable({ index = index }, Player)
end
)lua";

    // ---------- окружения ----------

    void SetFunc(const char* name, lua_CFunction fn, int modIndex, int side)
    {
        lua_pushinteger(L, modIndex);
        lua_pushinteger(L, side);
        lua_pushcclosure(L, fn, 2);
        lua_setfield(L, -2, name);
    }

    void SetPlain(const char* name, lua_CFunction fn)
    {
        lua_pushcfunction(L, fn);
        lua_setfield(L, -2, name);
    }

    // Базовое окружение стороны: стандартная библиотека (безопасная часть), game, native, player.
    void BuildBaseEnv(int side)
    {
        lua_newtable(L);

        // Без load/dofile/loadfile/io/debug/package.
        static const char* kGlobals[] = { "assert", "error", "ipairs", "next", "pairs", "pcall", "xpcall", "select",
                                          "tonumber", "tostring", "type", "rawequal", "rawget", "rawset", "rawlen",
                                          "setmetatable", "getmetatable", "collectgarbage",
                                          "string", "table", "math", "utf8", "coroutine" };
        for (const char* g : kGlobals)
        {
            lua_getglobal(L, g);
            lua_setfield(L, -2, g);
        }
        lua_newtable(L); // os: только время
        for (const char* f : { "time", "clock", "date", "difftime" })
        {
            lua_getglobal(L, "os");
            lua_getfield(L, -1, f);
            lua_setfield(L, -3, f);
            lua_pop(L, 1);
        }
        lua_setfield(L, -2, "os");

        lua_newtable(L); // game
        SetPlain("eval", l_gameEval);
        SetPlain("evalInt", l_gameEvalInt);
        SetPlain("evalFloat", l_gameEvalFloat);
        SetPlain("evalBool", l_gameEvalBool);
        SetPlain("mode", l_gameMode);
        SetPlain("isAuthority", l_gameIsAuthority);
        if (side == Server)
        {
            SetPlain("run", l_gameRun);
            SetPlain("command", l_gameCommand);
            SetPlain("exec", l_gameExec);
        }
        lua_pushstring(L, SideName(side));
        lua_setfield(L, -2, "side");
        lua_setfield(L, -2, "game");

        lua_newtable(L); // native
        lua_newtable(L);
        lua_pushinteger(L, side);
        lua_pushcclosure(L, l_nativeIndex, 1);
        lua_setfield(L, -2, "__index");
        lua_setmetatable(L, -2);
        lua_setfield(L, -2, "native");

        if (side == Client)
        {
            lua_newtable(L); // gfx
            lua_newtable(L);
            lua_pushcfunction(L, l_gfxIndex);
            lua_setfield(L, -2, "__index");
            lua_setmetatable(L, -2);

            lua_newtable(L); // gfx.fx — поля пресета пост-обработки (не нативы, прямой доступ)
            SetPlain("fields", l_fxFields);
            SetPlain("info", l_fxInfo);
            SetPlain("name", l_fxName);
            SetPlain("get", l_fxGet);
            SetPlain("set", l_fxSet);
            SetPlain("apply", l_fxApply);
            lua_setfield(L, -2, "fx");

            lua_setfield(L, -2, "gfx");
        }

        g_baseEnvRef[side] = luaL_ref(L, LUA_REGISTRYINDEX);

        std::string error;
        if (!LoadChunk(kPrelude, "=prelude", g_baseEnvRef[side], &error))
            LOG_ERROR("[lua] prelude: %s", error.c_str());
        else
            Call(0, 0, "prelude");

        if (side == Client)
        {
            if (!LoadChunk(kClientPrelude, "=prelude.client", g_baseEnvRef[side], &error))
                LOG_ERROR("[lua] client prelude: %s", error.c_str());
            else
                Call(0, 0, "prelude.client");

            if (!LoadChunk(GfxApi::Prelude(), "=prelude.gfx", g_baseEnvRef[side], &error))
                LOG_ERROR("[lua] gfx prelude: %s", error.c_str());
            else
                Call(0, 0, "prelude.gfx");

            lua_rawgeti(L, LUA_REGISTRYINDEX, g_baseEnvRef[side]); // ui.window / ui.text — без привязки к моду
            lua_getfield(L, -1, "ui");
            SetPlain("window", l_uiWindow);
            SetPlain("text", l_uiText);
            SetPlain("image", l_uiImage);
            SetPlain("container", l_uiContainer);
            SetPlain("exec", l_uiExec);
            SetPlain("sendTag", l_uiSendTag);
            lua_pop(L, 2);
        }
    }

    // Окружение стороны мода: свои log/print/require/events/net/(input)/mod, остальное — из базового.
    void CreateEnv(Mod& mod, int modIndex, int side)
    {
        lua_newtable(L);

        lua_newtable(L); // log
        SetFunc("info", l_logInfo, modIndex, side);
        SetFunc("warn", l_logWarn, modIndex, side);
        SetFunc("error", l_logError, modIndex, side);
        lua_setfield(L, -2, "log");
        SetFunc("print", l_logInfo, modIndex, side);
        SetFunc("require", l_require, modIndex, side);

        lua_newtable(L); // events (подписки привязаны к моду — снимаются при выгрузке)
        SetFunc("on", l_eventsOn, modIndex, side);
        SetFunc("off", l_eventsOff, modIndex, side);
        SetPlain("hook", l_eventsHook);
        lua_setfield(L, -2, "events");

        lua_newtable(L); // net
        SetFunc("on", l_netOn, modIndex, side);
        if (side == Server)
            SetFunc("broadcast", l_netBroadcast, modIndex, side);
        else
            SetFunc("send", l_netSend, modIndex, side);
        lua_setfield(L, -2, "net");

        if (side == Client)
        {
            lua_newtable(L); // input
            SetFunc("bind", l_inputBind, modIndex, side);
            lua_setfield(L, -2, "input");

            lua_newtable(L); // web — страницы мода в браузере
            SetFunc("open", l_webOpen, modIndex, side);
            SetPlain("close", l_webClose);
            SetPlain("reload", l_webReload);
            SetPlain("isOpen", l_webIsOpen);
            SetPlain("eval", l_webEval);
            lua_setfield(L, -2, "web");

            lua_newtable(L); // ui: своё (кнопки, клики, перехват) + общее из базового окружения через __index
            SetFunc("button", l_uiButton, modIndex, side);
            SetFunc("onClick", l_uiOnClick, modIndex, side);
            SetFunc("hookState", l_uiHookState, modIndex, side);
            SetFunc("screen", l_uiScreen, modIndex, side);
            lua_newtable(L);
            lua_rawgeti(L, LUA_REGISTRYINDEX, g_baseEnvRef[Client]);
            lua_getfield(L, -1, "ui");
            lua_setfield(L, -3, "__index");
            lua_pop(L, 1);
            lua_setmetatable(L, -2);
            lua_setfield(L, -2, "ui");
        }

        lua_newtable(L); // mod — информация о себе и свои файлы
        SetFunc("files", l_modFiles, modIndex, side);
        lua_pushstring(L, mod.id.c_str());      lua_setfield(L, -2, "id");
        lua_pushstring(L, mod.name.c_str());    lua_setfield(L, -2, "name");
        lua_pushstring(L, mod.version.c_str()); lua_setfield(L, -2, "version");
        lua_pushstring(L, SideName(side));      lua_setfield(L, -2, "side");
        lua_setfield(L, -2, "mod");

        lua_pushvalue(L, -1);
        lua_setfield(L, -2, "_G");

        lua_newtable(L); // метатаблица: __index = base env стороны
        lua_rawgeti(L, LUA_REGISTRYINDEX, g_baseEnvRef[side]);
        lua_setfield(L, -2, "__index");
        lua_setmetatable(L, -2);

        lua_newtable(L);
        mod.env[side].loadedRef = luaL_ref(L, LUA_REGISTRYINDEX);
        mod.env[side].envRef = luaL_ref(L, LUA_REGISTRYINDEX);
    }

    // ---------- манифест ----------

    std::string GetStringField(int table, const char* key, const std::string& def = {})
    {
        lua_getfield(L, table, key);
        std::string v = lua_type(L, -1) == LUA_TSTRING ? lua_tostring(L, -1) : def;
        lua_pop(L, 1);
        return v;
    }

    bool ReadManifest(Mod& mod)
    {
        fs::path manifest = mod.dir / L"manifest.lua";
        std::string code;
        if (!ReadFile(manifest, &code))
            return mod.error = "manifest.lua not found", false;

        // Манифест исполняется в пустом окружении: только данные, никаких функций.
        lua_newtable(L);
        int emptyEnv = luaL_ref(L, LUA_REGISTRYINDEX);
        std::string error;
        bool ok = LoadChunk(code, "@" + mod.folder + "/manifest.lua", emptyEnv, &error);
        luaL_unref(L, LUA_REGISTRYINDEX, emptyEnv);
        if (!ok)
            return mod.error = error, false;

        lua_pushcfunction(L, Traceback);
        lua_insert(L, -2);
        if (lua_pcall(L, 0, 1, -2) != LUA_OK)
        {
            mod.error = lua_tostring(L, -1);
            lua_pop(L, 2);
            return false;
        }
        lua_remove(L, -2);
        if (!lua_istable(L, -1))
        {
            lua_pop(L, 1);
            return mod.error = "manifest.lua must return a table", false;
        }
        int t = lua_gettop(L);

        mod.id = GetStringField(t, "id");
        mod.name = GetStringField(t, "name", mod.id);
        mod.version = GetStringField(t, "version", "0.0.0");
        mod.author = GetStringField(t, "author");
        mod.description = GetStringField(t, "description");
        mod.entry[Client] = GetStringField(t, "client");
        mod.entry[Server] = GetStringField(t, "server");
        std::string sharedEntry = GetStringField(t, "shared");
        mod.multiplayer = GetStringField(t, "multiplayer", "required");
        std::string legacyEntry = GetStringField(t, "entry");
        lua_getfield(L, t, "enabled");
        mod.enabled = lua_isnil(L, -1) || lua_toboolean(L, -1);
        lua_pop(L, 1);

        std::vector<std::string> files;
        lua_getfield(L, t, "files");
        if (lua_istable(L, -1))
        {
            for (lua_Integer i = 1; lua_rawgeti(L, -1, i) == LUA_TSTRING; ++i)
            {
                files.push_back(lua_tostring(L, -1));
                lua_pop(L, 1);
            }
            lua_pop(L, 1);
        }
        lua_pop(L, 2); // files, manifest

        if (mod.id.empty() || !std::all_of(mod.id.begin(), mod.id.end(), [](unsigned char c) { return isalnum(c) || c == '_'; }))
            return mod.error = "id is required: latin letters, digits and _", false;
        if (!legacyEntry.empty())
            return mod.error = "'entry' was replaced: use client = \"client.lua\" and/or server = \"server.lua\"", false;
        if (!sharedEntry.empty())
        {
            if (!mod.entry[Server].empty())
                return mod.error = "use either server = \"...\" or shared = \"...\", not both", false;
            mod.entry[Server] = sharedEntry;
            mod.shared = true;
        }
        if (mod.entry[Client].empty() && mod.entry[Server].empty())
            return mod.error = "set client = \"...\" and/or server = \"...\"", false;
        if (mod.multiplayer != "required" && mod.multiplayer != "optional")
            return mod.error = "multiplayer must be \"required\" or \"optional\"", false;

        for (int side : { Client, Server })
            if (!mod.entry[side].empty())
                files.push_back(mod.entry[side]);
        for (const auto& f : files)
        {
            std::string why;
            if (!ValidRelativePath(f, &why))
                return mod.error = "file '" + f + "': " + why, false;
            fs::path full = mod.dir / FromUtf8(f);
            if (!fs::is_regular_file(full))
                return mod.error = "file '" + f + "' listed in manifest does not exist", false;
            mod.files[ModuleKey(f)] = full;
        }
        return true;
    }

    // ---------- жизненный цикл ----------

    void OpenLibs()
    {
        static const luaL_Reg libs[] = {
            { LUA_GNAME, luaopen_base }, { LUA_TABLIBNAME, luaopen_table }, { LUA_STRLIBNAME, luaopen_string },
            { LUA_MATHLIBNAME, luaopen_math }, { LUA_UTF8LIBNAME, luaopen_utf8 }, { LUA_COLIBNAME, luaopen_coroutine },
            { LUA_OSLIBNAME, luaopen_os },
        };
        for (const auto& lib : libs)
        {
            luaL_requiref(L, lib.name, lib.func, 1);
            lua_pop(L, 1);
        }
    }

    // Снять всё, что мод зарегистрировал (при ошибке одной из сторон или выгрузке).
    void Detach(Mod& mod)
    {
        for (int id : mod.subscriptions)
            Events::Unsubscribe(id);
        mod.subscriptions.clear();
        for (auto& handlers : mod.netHandlers)
            handlers.clear();
        mod.binds.clear();
        mod.clickHandlers.clear();
    }

    void Close()
    {
        if (!L)
            return;
        for (auto& mod : g_mods)
            Detach(mod);
        Detach(g_console);
        g_mods.clear();
        g_console = {};
        lua_close(L);
        L = nullptr;
    }

    bool RunEntry(Mod& mod, int modIndex, int side)
    {
        CreateEnv(mod, modIndex, side);
        std::string code, error;
        ReadFile(mod.files[ModuleKey(mod.entry[side])], &code);
        if (!LoadChunk(code, "@" + mod.id + "/" + mod.entry[side], mod.env[side].envRef, &error))
        {
            mod.error = error;
            LOG_ERROR("[lua] %s", error.c_str());
            return false;
        }
        if (!Call(0, 0, Who(mod, side)))
        {
            mod.error = std::string(SideName(side)) + " script failed (see above)";
            return false;
        }
        return true;
    }

    void LoadAll()
    {
        Close();
        L = luaL_newstate();
        OpenLibs();
        BuildBaseEnv(Client);
        BuildBaseEnv(Server);

        g_console.id = "console";
        CreateEnv(g_console, -1, Server);
        // Консоли — ещё и клиентские таблицы: интерфейс (ui.find/setText/window…) и графика (gfx).
        lua_rawgeti(L, LUA_REGISTRYINDEX, g_console.env[Server].envRef);
        lua_rawgeti(L, LUA_REGISTRYINDEX, g_baseEnvRef[Client]);
        for (const char* table : { "ui", "gfx" })
        {
            lua_getfield(L, -1, table);
            lua_setfield(L, -3, table);
        }
        lua_pop(L, 2);

        fs::path root = ModsDir();
        std::error_code ec;
        fs::create_directories(root, ec);

        std::vector<fs::path> dirs;
        for (const auto& e : fs::directory_iterator(root, ec))
            if (e.is_directory())
                dirs.push_back(e.path());
        std::sort(dirs.begin(), dirs.end()); // порядок загрузки — по имени папки

        auto modState = LoadModState();
        g_mods.reserve(dirs.size());
        for (const auto& dir : dirs)
        {
            Mod mod;
            mod.dir = dir;
            mod.folder = ToUtf8(dir.filename());
            if (!ReadManifest(mod))
            {
                LOG_ERROR("[lua] mod '%s' skipped: %s", mod.folder.c_str(), mod.error.c_str());
                g_mods.push_back(std::move(mod));
                continue;
            }
            if (auto it = modState.find(mod.id); it != modState.end())
                mod.enabled = it->second;
            bool duplicate = std::any_of(g_mods.begin(), g_mods.end(), [&](const Mod& m) { return m.error.empty() && m.id == mod.id; });
            if (duplicate)
            {
                mod.error = "duplicate id";
                LOG_ERROR("[lua] mod '%s' skipped: id '%s' is already used", mod.folder.c_str(), mod.id.c_str());
            }
            g_mods.push_back(std::move(mod));
        }

        for (size_t i = 0; i < g_mods.size(); ++i)
        {
            Mod& mod = g_mods[i];
            if (!mod.error.empty() || !mod.enabled)
                continue;

            // Сначала server — он регистрирует правила, затем client.
            bool ok = true;
            for (int side : { Server, Client })
                if (ok && !mod.entry[side].empty())
                    ok = RunEntry(mod, static_cast<int>(i), side);

            mod.loaded = ok;
            if (!ok)
                Detach(mod);
            else
                LOG_INFO("[lua] loaded %s %s (%s) [%s]", mod.id.c_str(), mod.version.c_str(), mod.name.c_str(),
                         mod.shared ? "shared" : mod.entry[Client].empty() ? "server" : mod.entry[Server].empty() ? "client" : "client+server");
        }

        size_t loaded = std::count_if(g_mods.begin(), g_mods.end(), [](const Mod& m) { return m.loaded; });
        LOG_INFO("[lua] %zu of %zu mod(s) loaded from %s", loaded, g_mods.size(), ToUtf8(root).c_str());
    }

    bool ModifiersMatch(const Bind& b)
    {
        auto down = [](int vk) { return (GetAsyncKeyState(vk) & 0x8000) != 0; };
        return down(VK_CONTROL) == b.ctrl && down(VK_SHIFT) == b.shift && down(VK_MENU) == b.alt;
    }
}

void LuaHost::Start()
{
    ScriptRunner::RunOnGameThread(LoadAll);
}

void LuaHost::Reload()
{
    ScriptRunner::RunOnGameThread(LoadAll);
}

void LuaHost::Shutdown()
{
    HANDLE done = CreateEventW(nullptr, TRUE, FALSE, nullptr);
    ScriptRunner::RunOnGameThread([done] {
        Close();
        SetEvent(done);
    });
    if (WaitForSingleObject(done, 3000) == WAIT_TIMEOUT)
        LOG_WARN("[lua] game thread did not respond — Lua state left open");
    CloseHandle(done);
}

void LuaHost::OnNetMessage(char direction, const std::string& modId, const std::string& event, const std::string& data, int from)
{
    if (!L)
        return;
    int side = direction == 's' ? Server : Client;

    for (auto& mod : g_mods)
    {
        if (!mod.loaded || mod.id != modId)
            continue;
        // Серверная логика работает только там, где решается игра; shared-моды считают у всех.
        if (side == Server && !mod.shared && !Game::IsAuthority())
            return;
        auto it = mod.netHandlers[side].find(event);
        if (it == mod.netHandlers[side].end())
        {
            LOG_WARN("[%s] net message '%s' has no %s handler", Who(mod, side).c_str(), event.c_str(), SideName(side));
            return;
        }
        std::vector<int> refs = it->second; // обработчик может добавить новые
        for (int ref : refs)
        {
            lua_rawgeti(L, LUA_REGISTRYINDEX, ref);
            if (data.empty())
                lua_pushnil(L);
            else
            {
                size_t pos = 0;
                if (!Decode(L, data, pos, 0) || pos != data.size())
                {
                    lua_pop(L, 1);
                    LOG_WARN("[%s] net message '%s' from %d is malformed", Who(mod, side).c_str(), event.c_str(), from);
                    return;
                }
            }
            lua_pushinteger(L, from);
            Call(2, 0, Who(mod, side));
        }
        return;
    }
    LOG_WARN("[lua] net message for mod '%s' which is not loaded here", modId.c_str());
}

void LuaHost::OnUiPress(int element, const std::string& press, int tag)
{
    if (!L || press != "c") // onClick — только щелчок
        return;
    for (auto& mod : g_mods)
    {
        if (!mod.loaded)
            continue;
        auto it = mod.clickHandlers.find(element);
        if (it == mod.clickHandlers.end())
            continue;
        lua_rawgeti(L, LUA_REGISTRYINDEX, it->second);
        lua_pushinteger(L, element);
        lua_pushinteger(L, tag);
        Call(2, 0, Who(mod, Client));
        return;
    }
}

void LuaHost::PollInput(bool active)
{
    if (!L)
        return;
    for (auto& mod : g_mods)
    {
        if (!mod.loaded)
            continue;
        for (size_t i = 0; i < mod.binds.size(); ++i)
        {
            Bind& b = mod.binds[i];
            bool down = active && (GetAsyncKeyState(b.vk) & 0x8000) != 0 && ModifiersMatch(b);
            if (down && !b.wasDown)
            {
                b.wasDown = true;
                lua_rawgeti(L, LUA_REGISTRYINDEX, b.ref);
                lua_pushstring(L, b.key.c_str());
                Call(1, 0, Who(mod, Client));
                if (i >= mod.binds.size())
                    break; // обработчик мог перезагрузить моды
            }
            else if (!down)
                b.wasDown = false;
        }
    }
}

namespace
{
    // Значение Lua -> JSON. Таблица с ключами 1..n становится массивом, остальные — объектом.
    void ToJson(lua_State* L, int idx, std::string& out, int depth)
    {
        idx = lua_absindex(L, idx);
        if (depth > 12)
            return out.append("null"), void();

        switch (lua_type(L, idx))
        {
        case LUA_TNIL:
        case LUA_TNONE:
            out += "null";
            return;
        case LUA_TBOOLEAN:
            out += lua_toboolean(L, idx) ? "true" : "false";
            return;
        case LUA_TNUMBER:
        {
            char buf[40];
            if (lua_isinteger(L, idx))
                sprintf_s(buf, "%lld", static_cast<long long>(lua_tointeger(L, idx)));
            else
                sprintf_s(buf, "%.14g", lua_tonumber(L, idx));
            out += buf;
            return;
        }
        case LUA_TSTRING:
        {
            size_t len = 0;
            const char* str = lua_tolstring(L, idx, &len);
            out += '"';
            for (size_t i = 0; i < len; ++i)
            {
                unsigned char c = static_cast<unsigned char>(str[i]);
                if (c == '"' || c == '\\')
                {
                    out += '\\';
                    out += static_cast<char>(c);
                }
                else if (c == '\n') out += "\\n";
                else if (c == '\r') out += "\\r";
                else if (c == '\t') out += "\\t";
                else if (c < 0x20)
                {
                    char esc[8];
                    sprintf_s(esc, "\\u%04X", c);
                    out += esc;
                }
                else
                    out += static_cast<char>(c);
            }
            out += '"';
            return;
        }
        case LUA_TTABLE:
        {
            lua_Integer count = luaL_len(L, idx);
            bool array = count > 0;
            out += array ? '[' : '{';
            if (array)
            {
                for (lua_Integer i = 1; i <= count; ++i)
                {
                    if (i > 1)
                        out += ',';
                    lua_geti(L, idx, i);
                    ToJson(L, -1, out, depth + 1);
                    lua_pop(L, 1);
                }
            }
            else
            {
                bool first = true;
                lua_pushnil(L);
                while (lua_next(L, idx))
                {
                    if (lua_type(L, -2) == LUA_TSTRING)
                    {
                        if (!first)
                            out += ',';
                        first = false;
                        ToJson(L, -2, out, depth + 1);
                        out += ':';
                        ToJson(L, -1, out, depth + 1);
                    }
                    lua_pop(L, 1);
                }
            }
            out += array ? ']' : '}';
            return;
        }
        default:
            out += '"';
            out += lua_typename(L, lua_type(L, idx));
            out += '"';
            return;
        }
    }
}

std::string LuaHost::EvalJson(const std::string& code, bool* ok)
{
    if (ok)
        *ok = false;
    if (!L)
        return "lua is not started";

    std::string error;
    int top = lua_gettop(L);
    int env = g_console.env[Server].envRef;
    // Как в консоли: сначала как выражение, потом как оператор.
    if (!LoadChunk("return " + code, "=web", env, &error) && !LoadChunk(code, "=web", env, &error))
        return error;
    if (!Call(0, 1, "web"))
        return "error while running the code, see the log";

    std::string json;
    ToJson(L, -1, json, 0);
    lua_settop(L, top);
    if (ok)
        *ok = true;
    return json;
}

void LuaHost::RunConsole(const std::string& code)
{
    ScriptRunner::RunOnGameThread([code] {
        if (!L)
        {
            LOG_WARN("[lua] not started");
            return;
        }
        // Как REPL: сначала пробуем как выражение ("= 1 + 2"), потом как оператор.
        std::string error;
        int top = lua_gettop(L);
        int env = g_console.env[Server].envRef;
        if (!LoadChunk("return " + code, "=console", env, &error) && !LoadChunk(code, "=console", env, &error))
        {
            LOG_ERROR("[lua] %s", error.c_str());
            return;
        }
        if (!Call(0, LUA_MULTRET, "console"))
            return;
        int n = lua_gettop(L) - top;
        if (n > 0)
        {
            std::string out = Concat(L, top + 1);
            Console::Print("= %s", out.c_str());
        }
        lua_settop(L, top);
    });
}

std::vector<LuaHost::ModView> LuaHost::Mods()
{
    std::vector<ModView> out;
    for (const auto& m : g_mods)
    {
        ModStatus status = m.loaded ? ModStatus::Loaded : !m.error.empty() ? ModStatus::Error : ModStatus::Disabled;
        std::string sides = !m.entry[Client].empty() && !m.entry[Server].empty() ? "client+server"
                          : !m.entry[Server].empty() ? "server" : !m.entry[Client].empty() ? "client" : "";
        out.push_back({ m.folder, m.id, m.name, m.version, m.author, m.description, m.error, sides, m.multiplayer, status });
    }
    return out;
}

void LuaHost::SetModEnabled(const std::string& id, bool enabled)
{
    auto state = LoadModState();
    state[id] = enabled;
    SaveModState(state);
    LOG_INFO("[lua] mod '%s' %s — reloading Lua mods", id.c_str(), enabled ? "enabled" : "disabled");
    Reload();
}

void LuaHost::PrintMods()
{
    ScriptRunner::RunOnGameThread([] {
        if (g_mods.empty())
            Console::Print("  no mods in %s", ToUtf8(ModsDir()).c_str());
        for (const auto& v : Mods())
        {
            const char* status = v.status == ModStatus::Loaded ? "\x1b[32mloaded\x1b[0m"
                               : v.status == ModStatus::Error ? "\x1b[31merror\x1b[0m" : "disabled";
            Console::Print("  %-20s %-10s %-8s %-14s %s%s%s", v.id.empty() ? v.folder.c_str() : v.id.c_str(), v.version.c_str(),
                           status, v.sides.c_str(), v.name.c_str(), v.error.empty() ? "" : " — ", v.error.c_str());
        }
    });
}
