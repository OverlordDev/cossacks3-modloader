#include "pch.h"
#include "LuaHost.h"
#include "Console.h"
#include "Events.h"
#include "NativeCall.h"
#include "ScriptRunner.h"
#include "Text.h"

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
    struct Mod
    {
        fs::path dir;
        std::string folder; // имя папки
        std::string id, name, version, author, description;
        std::string entry;
        std::map<std::string, fs::path> files; // имя модуля ("utils", "lib/math") -> путь
        bool enabled = true;
        bool loaded = false;
        std::string error;
        int envRef = LUA_NOREF;
        int loadedRef = LUA_NOREF; // кэш require
        std::vector<int> subscriptions; // Events ids
    };

    lua_State* L = nullptr;
    std::vector<Mod> g_mods;
    Mod g_console; // псевдо-мод для строк из консоли
    int g_baseEnvRef = LUA_NOREF;

    // ---------- утилиты ----------

    fs::path ModsDir()
    {
        wchar_t exe[MAX_PATH];
        GetModuleFileNameW(nullptr, exe, MAX_PATH);
        return fs::path(exe).parent_path() / L"modloader" / L"mods";
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

    Mod* ModFromUpvalue(lua_State* L)
    {
        int index = static_cast<int>(lua_tointeger(L, lua_upvalueindex(1)));
        return index < 0 ? &g_console : &g_mods[index];
    }

    // ---------- API: log / print / require ----------

    int l_log(lua_State* L, int level)
    {
        Mod* mod = ModFromUpvalue(L);
        std::string text = Concat(L, 1);
        const char* id = mod->id.c_str();
        if (level == 0) LOG_INFO("\x1b[34m[%s]\x1b[0m %s", id, text.c_str());
        else if (level == 1) LOG_WARN("\x1b[34m[%s]\x1b[0m %s", id, text.c_str());
        else LOG_ERROR("\x1b[34m[%s]\x1b[0m %s", id, text.c_str());
        return 0;
    }
    int l_logInfo(lua_State* L) { return l_log(L, 0); }
    int l_logWarn(lua_State* L) { return l_log(L, 1); }
    int l_logError(lua_State* L) { return l_log(L, 2); }

    int l_require(lua_State* L)
    {
        Mod* mod = ModFromUpvalue(L);
        std::string key = ModuleKey(luaL_checkstring(L, 1));

        lua_rawgeti(L, LUA_REGISTRYINDEX, mod->loadedRef);
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
        if (!LoadChunk(code, "@" + mod->id + "/" + key + ".lua", mod->envRef, &error))
            return luaL_error(L, "%s", error.c_str());
        lua_call(L, 0, 1);
        if (lua_isnil(L, -1))
        {
            lua_pop(L, 1);
            lua_pushboolean(L, 1);
        }
        lua_pushvalue(L, -1);
        lua_setfield(L, -3, key.c_str()); // loaded[key] = result
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

    // game.run(code) — асинхронно, как строка из консоли.
    int l_gameRun(lua_State* L)
    {
        ScriptRunner::Queue(SplitLines(Text::Utf8ToAnsi(luaL_checkstring(L, 1))));
        return 0;
    }

    // game.command(text) — как текст в чате игры (res all 5000, cheat fog, ...).
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
    bool ScriptCall(lua_State* L, const std::string& code, const std::string& arg, std::string* result)
    {
        if (!ScriptRunner::Call(Text::Utf8ToAnsi(code), Text::Utf8ToAnsi(arg), result))
            return false;
        *result = Text::AnsiToUtf8(*result);
        return true;
    }

    // game.exec(code [, arg]) -> строка из ML_RET или nil. ML_ARG в коде — это arg.
    int l_gameExec(lua_State* L)
    {
        std::string code = luaL_checkstring(L, 1);
        std::string arg = luaL_optstring(L, 2, "");
        std::string result;
        if (!ScriptCall(L, code, arg, &result))
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
        if (!ScriptCall(L, code, "", &result))
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

    // ---------- API: events ----------

    // Обработчик события из Lua (главный поток игры; L — глобальное состояние).
    void CallEventHandler(int ref, const std::string& who, const std::string& event)
    {
        if (!L)
            return;
        lua_rawgeti(L, LUA_REGISTRYINDEX, ref);
        lua_pushstring(L, event.c_str());
        Call(1, 0, who);
    }

    int l_eventsOn(lua_State* L)
    {
        Mod* mod = ModFromUpvalue(L);
        std::string event = luaL_checkstring(L, 1);
        luaL_checktype(L, 2, LUA_TFUNCTION);
        lua_pushvalue(L, 2);
        int ref = luaL_ref(L, LUA_REGISTRYINDEX);
        std::string who = mod->id;

        int id = Events::Subscribe(event, [ref, who](const std::string& name) { CallEventHandler(ref, who, name); });
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

    // ---------- API: native ----------

    int l_nativeCall(lua_State* L)
    {
        auto sig = static_cast<const NativeCall::Signature*>(lua_touserdata(L, lua_upvalueindex(1)));
        if (!sig->error.empty())
            return luaL_error(L, "native.%s: %s", sig->name.c_str(), sig->error.c_str());
        if (lua_gettop(L) != static_cast<int>(sig->params.size()))
            return luaL_error(L, "native.%s expects %d argument(s): %s", sig->name.c_str(),
                              static_cast<int>(sig->params.size()), sig->decl.c_str());

        std::vector<NativeCall::Value> args(sig->params.size());
        for (size_t i = 0; i < sig->params.size(); ++i)
        {
            int idx = static_cast<int>(i) + 1;
            NativeCall::Value& v = args[i];
            v.type = sig->params[i];
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
        std::string error;
        if (!NativeCall::Invoke(*sig, args, &result, &error))
            return luaL_error(L, "native.%s: %s", sig->name.c_str(), error.c_str());

        switch (result.type)
        {
        case NativeCall::Type::Int:    lua_pushinteger(L, result.i); return 1;
        case NativeCall::Type::Bool:   lua_pushboolean(L, result.b); return 1;
        case NativeCall::Type::Float:  lua_pushnumber(L, result.f); return 1;
        case NativeCall::Type::String: lua_pushstring(L, Text::AnsiToUtf8(result.s).c_str()); return 1;
        default: return 0;
        }
    }

    // native.<Name> — функция создаётся при первом обращении и кэшируется в таблице.
    int l_nativeIndex(lua_State* L)
    {
        const char* name = luaL_checkstring(L, 2);
        const NativeCall::Signature* sig = NativeCall::Find(name);
        if (!sig)
            return 0; // nil
        lua_pushlightuserdata(L, const_cast<NativeCall::Signature*>(sig));
        lua_pushcclosure(L, l_nativeCall, 1);
        lua_pushvalue(L, -1);
        lua_setfield(L, 1, name);
        return 1;
    }

    // Обёртки поверх game/native на Lua (исполняются в базовом окружении).
    const char* kPrelude = R"lua(
local RES = { food = 1, wood = 2, stone = 3, gold = 4, iron = 5, coal = 6 }

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
    game.exec("_res_SetResToPlayerByIndex(" .. rawget(self, "index") .. ", " .. r .. ", StrToInt(ML_ARG));",
              tostring(math.floor(value)))
end
function Player:add(res, amount)
    local r = RES[res] or error("unknown resource '" .. tostring(res) .. "'", 2)
    game.exec("_res_AddResToPlayerByIndex(" .. self.index .. ", " .. r .. ", StrToInt(ML_ARG));",
              tostring(math.floor(amount)))
end

-- Идёт партия (не меню, не редактор, не наблюдатель) — так же проверяют скрипты игры.
function game.isInGame()
    return game.evalBool("gInterface.gamemode = gc_gamemode_game")
end

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

    void SetFunc(const char* name, lua_CFunction fn, int modIndex)
    {
        lua_pushinteger(L, modIndex);
        lua_pushcclosure(L, fn, 1);
        lua_setfield(L, -2, name);
    }

    void BuildBaseEnv()
    {
        lua_newtable(L); // base env

        // Безопасное подмножество стандартной библиотеки (без load/dofile/loadfile/io/debug/package).
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
        lua_pushcfunction(L, l_gameRun);       lua_setfield(L, -2, "run");
        lua_pushcfunction(L, l_gameCommand);   lua_setfield(L, -2, "command");
        lua_pushcfunction(L, l_gameExec);      lua_setfield(L, -2, "exec");
        lua_pushcfunction(L, l_gameEval);      lua_setfield(L, -2, "eval");
        lua_pushcfunction(L, l_gameEvalInt);   lua_setfield(L, -2, "evalInt");
        lua_pushcfunction(L, l_gameEvalFloat); lua_setfield(L, -2, "evalFloat");
        lua_pushcfunction(L, l_gameEvalBool);  lua_setfield(L, -2, "evalBool");
        lua_setfield(L, -2, "game");

        lua_newtable(L); // native
        lua_newtable(L);
        lua_pushcfunction(L, l_nativeIndex);
        lua_setfield(L, -2, "__index");
        lua_setmetatable(L, -2);
        lua_setfield(L, -2, "native");

        g_baseEnvRef = luaL_ref(L, LUA_REGISTRYINDEX);

        std::string error;
        if (!LoadChunk(kPrelude, "=prelude", g_baseEnvRef, &error))
            LOG_ERROR("[lua] prelude: %s", error.c_str());
        else
            Call(0, 0, "prelude");
    }

    // Окружение мода: свои log/print/require/events/mod, остальное — из базового через __index.
    int CreateModEnv(Mod& mod, int modIndex)
    {
        lua_newtable(L);

        lua_newtable(L); // log
        SetFunc("info", l_logInfo, modIndex);
        SetFunc("warn", l_logWarn, modIndex);
        SetFunc("error", l_logError, modIndex);
        lua_setfield(L, -2, "log");
        SetFunc("print", l_logInfo, modIndex);
        SetFunc("require", l_require, modIndex);

        lua_newtable(L); // events (подписки привязаны к моду — снимаются при выгрузке)
        SetFunc("on", l_eventsOn, modIndex);
        SetFunc("off", l_eventsOff, modIndex);
        lua_pushcfunction(L, l_eventsHook);
        lua_setfield(L, -2, "hook");
        lua_setfield(L, -2, "events");

        lua_newtable(L); // mod — информация о себе
        lua_pushstring(L, mod.id.c_str());      lua_setfield(L, -2, "id");
        lua_pushstring(L, mod.name.c_str());    lua_setfield(L, -2, "name");
        lua_pushstring(L, mod.version.c_str()); lua_setfield(L, -2, "version");
        lua_setfield(L, -2, "mod");

        lua_pushvalue(L, -1);
        lua_setfield(L, -2, "_G");

        lua_newtable(L); // метатаблица: __index = base env
        lua_rawgeti(L, LUA_REGISTRYINDEX, g_baseEnvRef);
        lua_setfield(L, -2, "__index");
        lua_setmetatable(L, -2);

        lua_newtable(L);
        mod.loadedRef = luaL_ref(L, LUA_REGISTRYINDEX);
        return luaL_ref(L, LUA_REGISTRYINDEX);
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
        mod.entry = GetStringField(t, "entry");
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
        if (mod.entry.empty())
            return mod.error = "entry is required (e.g. entry = \"main.lua\")", false;

        files.push_back(mod.entry);
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

    void Close()
    {
        if (!L)
            return;
        for (auto& mod : g_mods)
            for (int id : mod.subscriptions)
                Events::Unsubscribe(id);
        for (int id : g_console.subscriptions)
            Events::Unsubscribe(id);
        g_mods.clear();
        g_console = {};
        lua_close(L);
        L = nullptr;
    }

    void LoadAll()
    {
        Close();
        L = luaL_newstate();
        OpenLibs();
        BuildBaseEnv();

        g_console.id = "console";
        g_console.envRef = CreateModEnv(g_console, -1);

        fs::path root = ModsDir();
        std::error_code ec;
        fs::create_directories(root, ec);

        std::vector<fs::path> dirs;
        for (const auto& e : fs::directory_iterator(root, ec))
            if (e.is_directory())
                dirs.push_back(e.path());
        std::sort(dirs.begin(), dirs.end()); // порядок загрузки — по имени папки

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
            bool duplicate = std::any_of(g_mods.begin(), g_mods.end(), [&](const Mod& m) { return m.loaded && m.id == mod.id; });
            if (duplicate)
            {
                mod.error = "duplicate id";
                LOG_ERROR("[lua] mod '%s' skipped: id '%s' is already used", mod.folder.c_str(), mod.id.c_str());
                g_mods.push_back(std::move(mod));
                continue;
            }
            g_mods.push_back(std::move(mod));
        }

        for (size_t i = 0; i < g_mods.size(); ++i)
        {
            Mod& mod = g_mods[i];
            if (!mod.error.empty() || !mod.enabled)
                continue;

            mod.envRef = CreateModEnv(mod, static_cast<int>(i));
            std::string code, error;
            ReadFile(mod.files[ModuleKey(mod.entry)], &code);
            if (!LoadChunk(code, "@" + mod.id + "/" + mod.entry, mod.envRef, &error))
            {
                mod.error = error;
                LOG_ERROR("[lua] %s", error.c_str());
                continue;
            }
            mod.loaded = Call(0, 0, mod.id);
            if (!mod.loaded)
                mod.error = "entry failed (see above)";
            else
                LOG_INFO("[lua] loaded %s %s (%s)", mod.id.c_str(), mod.version.c_str(), mod.name.c_str());
        }

        size_t loaded = std::count_if(g_mods.begin(), g_mods.end(), [](const Mod& m) { return m.loaded; });
        LOG_INFO("[lua] %zu of %zu mod(s) loaded from %s", loaded, g_mods.size(), ToUtf8(root).c_str());
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
        if (!LoadChunk("return " + code, "=console", g_console.envRef, &error) &&
            !LoadChunk(code, "=console", g_console.envRef, &error))
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

void LuaHost::PrintMods()
{
    ScriptRunner::RunOnGameThread([] {
        if (g_mods.empty())
            Console::Print("  no mods in %s", ToUtf8(ModsDir()).c_str());
        for (const auto& m : g_mods)
        {
            const char* status = m.loaded ? "\x1b[32mloaded\x1b[0m" : !m.error.empty() ? "\x1b[31merror\x1b[0m" : "disabled";
            Console::Print("  %-20s %-10s %-8s %s%s%s", m.id.empty() ? m.folder.c_str() : m.id.c_str(), m.version.c_str(),
                           status, m.name.c_str(), m.error.empty() ? "" : " — ", m.error.c_str());
        }
    });
}
