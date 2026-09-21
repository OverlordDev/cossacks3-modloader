#include "pch.h"
#include "CrashHandler.h"
#include "Events.h"
#include "NativeCall.h"
#include "Console.h"
#include "Engine.h"
#include "GameApi.h"
#include "Hooks.h"
#include "ScriptRunner.h"

#include <algorithm>
#include <map>
#include <mutex>

namespace
{
    constexpr char kPrefix[] = "ML:";

    struct Injection
    {
        std::string library; // пусто — интерфейс (menu.aix); иначе файл библиотеки состояний (units\unit.aix)
        std::string state;
        bool atEnd;
        std::string event;
        std::string line;
        // Обёртка вызова: каждую строку с вызовом wrapCall(...) заменить на
        //   begin <line с {0},{1}... = аргументы вызова>; <исходный вызов> end{ML:orig=<исходная строка>}
        // Так событие видит настоящие аргументы, а исходная строка восстанавливается для контрольной суммы.
        std::string wrapCall;
    };

    struct Subscription
    {
        int id;
        std::string event;
        Events::Handler handler;
    };

    struct Counter
    {
        uint64_t total = 0;
        uint64_t lastTotal = 0;
        ULONGLONG lastTick = 0;
    };

    // Всё ниже трогается только из главного потока игры (инъекции и вызовы натива идут там).
    std::vector<Injection> g_injections;
    std::vector<Subscription> g_subs;
    std::map<std::string, Counter> g_counters;
    int g_nextId = 1;
    std::mutex g_mutex; // подписки/счётчики читаются и из потока консоли

    ULONGLONG g_lastMaintain = 0;

    GameApi::LogFn oTrampoline = nullptr;

    void Dispatch(const std::string& event, const std::string& payload)
    {
        CrashHandler::Scope scope("событие " + event + (payload.empty() ? "" : " (" + payload.substr(0, 80) + ")"));
        std::vector<Events::Handler> handlers;
        {
            std::lock_guard lock(g_mutex);
            ++g_counters[event].total;
            for (const auto& s : g_subs)
                if (s.event == event || s.event == "*")
                    handlers.push_back(s.handler);
        }
        for (const auto& h : handlers)
        {
            try
            {
                h(event, payload);
            }
            catch (const std::exception& e)
            {
                LOG_ERROR("Event handler for %s threw: %s", event.c_str(), e.what());
            }
        }
    }

    constexpr char kRetPrefix[] = "ret:";
    bool g_blockRequested = false;
    bool g_capturing = false;
    bool g_captured = false;
    std::string g_capture;

    void __stdcall hkTrampoline(const char* msg)
    {
        if (msg && strncmp(msg, kPrefix, sizeof(kPrefix) - 1) == 0)
        {
            const char* body = msg + sizeof(kPrefix) - 1;
            if (strncmp(body, kRetPrefix, sizeof(kRetPrefix) - 1) == 0)
            {
                if (g_capturing)
                {
                    g_capture = body + sizeof(kRetPrefix) - 1;
                    g_captured = true;
                }
                return;
            }
            // "event|payload" — данные события (например id игрока) после '|'
            const char* bar = strchr(body, '|');
            bool saved = g_blockRequested; // события бывают вложенными
            g_blockRequested = false;
            Dispatch(bar ? std::string(body, bar) : std::string(body), bar ? std::string(bar + 1) : std::string());
            // Ответ для вставки: 'ML:block' — прервать состояние (см. kBlockCheck в Events.h).
            oTrampoline(GameApi::DelphiString(g_blockRequested ? "ML:block" : "").get());
            g_blockRequested = saved;
            return;
        }
        oTrampoline(msg);
    }

    std::string Lower(std::string s)
    {
        std::transform(s.begin(), s.end(), s.begin(), [](unsigned char c) { return static_cast<char>(tolower(c)); });
        return s;
    }

    // Строки "args ..." должны идти первыми в состоянии — вставляем после них (и после пустых/комментариев).
    int BeginInsertIndex(uint8_t* list)
    {
        int count = Engine::ListCount(list);
        int index = 0;
        for (; index < count && index < 32; ++index)
        {
            std::string l = Lower(Engine::ListGet(list, index));
            size_t p = l.find_first_not_of(" \t");
            if (p == std::string::npos || l.compare(p, 2, "//") == 0 || l.compare(p, 5, "args ") == 0)
                continue;
            break;
        }
        return index;
    }

    // Машина состояний библиотеки (юниты, здания...) по имени файла. Движок хранит библиотеки
    // под тем именем, под которым их загрузил, поэтому пробуем несколько написаний пути.
    uint8_t* LibraryStateMachine(const std::string& file)
    {
        static std::map<std::string, std::string> resolved; // файл -> написание, которое сработало
        const NativeCall::Signature* get = NativeCall::Find("StateMachineLibraryGet");
        if (!get)
            return nullptr;

        auto tryName = [&](const std::string& name) -> uint8_t* {
            NativeCall::Value arg, result;
            arg.type = NativeCall::Type::String;
            arg.s = name;
            std::string error;
            if (!NativeCall::Invoke(*get, { arg }, &result, &error))
                return nullptr;
            return reinterpret_cast<uint8_t*>(result.i);
        };

        if (auto it = resolved.find(file); it != resolved.end())
            return tryName(it->second);

        const std::string variants[] = {
            ".\\data\\scripts\\" + file, "data\\scripts\\" + file, ".\\data\\scripts\\" + Lower(file),
            "data/scripts/" + file, file,
        };
        for (const std::string& v : variants)
            if (uint8_t* sm = tryName(v))
            {
                resolved[file] = v;
                LOG_DEV("Events: state library %s found as '%s'", file.c_str(), v.c_str());
                return sm;
            }
        return nullptr;
    }

    // Аргументы вызова name(...) в строке: разбивка по запятым верхнего уровня.
    bool CallArgs(const std::string& line, const std::string& name, std::vector<std::string>* args)
    {
        size_t at = line.find(name + "(");
        if (at == std::string::npos)
            return false;
        size_t i = at + name.size() + 1;
        int depth = 0;
        bool quote = false;
        std::string cur;
        for (; i < line.size(); ++i)
        {
            char c = line[i];
            if (c == '\'')
                quote = !quote;
            if (!quote)
            {
                if (c == '(' || c == '[')
                    ++depth;
                else if (c == ')' || c == ']')
                {
                    if (depth == 0)
                    {
                        args->push_back(cur);
                        return true;
                    }
                    --depth;
                }
                else if (c == ',' && depth == 0)
                {
                    args->push_back(cur);
                    cur.clear();
                    continue;
                }
            }
            cur += c;
        }
        return false;
    }

    std::string Fill(std::string text, const std::vector<std::string>& args)
    {
        for (size_t i = 0; i < args.size(); ++i)
        {
            std::string mark = "{" + std::to_string(i) + "}";
            for (size_t p; (p = text.find(mark)) != std::string::npos;)
                text.replace(p, mark.size(), args[i]);
        }
        return text;
    }

    // Главный поток игры: обернуть вызовы в состоянии. true — обёртки на месте.
    bool ApplyWrap(const Injection& inj, uint8_t* sm, uint8_t* state, bool quiet)
    {
        uint8_t* list = Engine::StateCode(state);
        std::string marker = "'ML:" + inj.line.substr(inj.line.find("'ML:") + 4, inj.line.find('|') - inj.line.find("'ML:") - 4);
        std::vector<std::pair<int, std::string>> replaced; // номер строки -> исходная строка
        int count = Engine::ListCount(list);
        for (int i = 0; i < count; ++i)
        {
            std::string original = Engine::ListGet(list, i);
            if (original.find("{ML:orig=") != std::string::npos && original.find(marker) != std::string::npos)
                return true; // уже обёрнуто
            std::vector<std::string> args;
            if (original.find(inj.wrapCall + "(") == std::string::npos || original.find('}') != std::string::npos ||
                !CallArgs(original, inj.wrapCall, &args))
                continue;
            size_t start = original.find_first_not_of(" \t");
            size_t end = original.find_last_not_of(" \t");
            std::string core = original.substr(start, end - start + 1);
            bool semicolon = !core.empty() && core.back() == ';';
            if (semicolon)
                core.pop_back();
            std::string wrapped = original.substr(0, start) + "begin " + Fill(inj.line, args) + "; " + core + " end" +
                                  (semicolon ? ";" : "") + "{ML:orig=" + original + "}";
            Engine::ListDelete(list, i);
            Engine::ListInsert(list, i, wrapped);
            replaced.push_back({ i, original });
        }
        if (replaced.empty())
        {
            if (!quiet)
                LOG_WARN("Events: no %s( calls in '%s' (%s)", inj.wrapCall.c_str(), inj.state.c_str(), inj.library.c_str());
            return false;
        }
        Engine::StateReset(state);
        if (!Engine::StateCompileSafe(sm, state))
        {
            for (const auto& [i, original] : replaced)
            {
                Engine::ListDelete(list, i);
                Engine::ListInsert(list, i, original);
            }
            Engine::StateReset(state);
            LOG_ERROR("Events: wrapping %s in '%s' broke compilation — reverted", inj.wrapCall.c_str(), inj.state.c_str());
            return false;
        }
        LOG_DEV("Events: %s — wrapped %d call(s) of %s in '%s' (%s)", inj.event.c_str(), static_cast<int>(replaced.size()),
                inj.wrapCall.c_str(), inj.state.c_str(), inj.library.c_str());
        return true;
    }

    // Главный поток игры. true — строка на месте.
    bool Apply(const Injection& inj, bool quiet)
    {
        uint8_t* sm = inj.library.empty() ? Engine::GuiStateMachine() : LibraryStateMachine(inj.library);
        if (!sm)
        {
            if (!quiet)
                LOG_DEV("Events: state library %s is not loaded yet — will retry", inj.library.c_str());
            return false;
        }
        uint8_t* state = Engine::FindState(sm, inj.state);
        if (!state)
        {
            if (!quiet)
                LOG_ERROR("Events: state '%s' not found in %s", inj.state.c_str(),
                          inj.library.empty() ? "GUI" : inj.library.c_str());
            return false;
        }
        if (!inj.wrapCall.empty())
            return ApplyWrap(inj, sm, state, quiet);

        uint8_t* list = Engine::StateCode(state);
        if (Engine::ListIndexOf(list, inj.line) >= 0)
            return true;

        if (Engine::ListCount(list) == 0)
        {
            if (!quiet)
                LOG_WARN("Events: state '%s' has no code loaded, skipping", inj.state.c_str());
            return false;
        }

        int index = inj.atEnd ? Engine::ListCount(list) : BeginInsertIndex(list);
        Engine::ListInsert(list, index, inj.line);
        Engine::StateReset(state);

        // Проверяем сразу: если сломали компиляцию — откатываем, иначе у игры отвалится это состояние.
        if (!Engine::StateCompileSafe(sm, state))
        {
            int at = Engine::ListIndexOf(list, inj.line);
            if (at >= 0)
                Engine::ListDelete(list, at);
            Engine::StateReset(state);
            LOG_ERROR("Events: injecting into '%s' broke compilation — reverted", inj.state.c_str());
            return false;
        }
        LOG_DEV("Events: hooked %s (line %d of state '%s'%s%s)", inj.event.c_str(), index + 1, inj.state.c_str(),
                inj.library.empty() ? "" : " in ", inj.library.c_str());
        return true;
    }

    // Главный поток игры: GUI state machine может перезагрузиться (смена меню/партии) — вставки пропадут.
    void Maintain()
    {
        if (!Engine::GuiStateMachine())
            return;
        for (const auto& inj : g_injections)
            Apply(inj, true);
    }
}

bool Events::Install()
{
    for (const auto& n : GameApi::Natives())
        if (GameApi::NameOf(n.decl) == "DScriptSetgDbgString0")
            return Hooks::Create("Events trampoline", GameApi::Addr(n.va), &hkTrampoline, &oTrampoline);
    LOG_ERROR("Events: DScriptSetgDbgString0 native not found");
    return false;
}

void Events::MaintainNow()
{
    Maintain();
}

void Events::Update()
{
    if (GetTickCount64() - g_lastMaintain < 1000)
        return;
    g_lastMaintain = GetTickCount64();
    ScriptRunner::RunOnGameThread(Maintain);
}

void Events::HookGuiState(const std::string& state, bool atEnd)
{
    std::string event = "gui." + state + (atEnd ? ".end" : "");
    HookGuiStateCode(state, event, "DScriptSetgDbgString0('" + std::string(kPrefix) + event + "');", atEnd);
}

void Events::HookGuiStateCode(const std::string& state, const std::string& key, const std::string& line, bool atEnd)
{
    Injection inj;
    inj.state = state;
    inj.atEnd = atEnd;
    inj.event = key;
    inj.line = line;

    ScriptRunner::RunOnGameThread([inj] {
        for (const auto& existing : g_injections)
            if (existing.event == inj.event)
                return;
        if (Apply(inj, false))
            g_injections.push_back(inj);
    });
}
void Events::HookLibraryStateCode(const std::string& library, const std::string& state, const std::string& key,
                                  const std::string& line, bool atEnd)
{
    Injection inj;
    inj.library = library;
    inj.state = state;
    inj.atEnd = atEnd;
    inj.event = key;
    inj.line = line;

    ScriptRunner::RunOnGameThread([inj] {
        for (const auto& existing : g_injections)
            if (existing.event == inj.event)
                return;
        Apply(inj, false);
        g_injections.push_back(inj); // даже если библиотека ещё не загружена: Maintain довставит
    });
}


void Events::WrapLibraryCalls(const std::string& library, const std::string& state, const std::string& call,
                              const std::string& key, const std::string& line)
{
    Injection inj;
    inj.library = library;
    inj.state = state;
    inj.atEnd = false;
    inj.event = key;
    inj.line = line;
    inj.wrapCall = call;

    ScriptRunner::RunOnGameThread([inj] {
        for (const auto& existing : g_injections)
            if (existing.event == inj.event)
                return;
        Apply(inj, false);
        g_injections.push_back(inj);
    });
}

void Events::Emit(const std::string& event, const std::string& payload)
{
    Dispatch(event, payload);
}

void Events::RequestBlock()
{
    g_blockRequested = true;
}

int Events::Subscribe(const std::string& event, Handler handler)
{
    std::lock_guard lock(g_mutex);
    int id = g_nextId++;
    g_subs.push_back({ id, event, std::move(handler) });
    return id;
}

void Events::Unsubscribe(int id)
{
    std::lock_guard lock(g_mutex);
    std::erase_if(g_subs, [id](const Subscription& s) { return s.id == id; });
}

void Events::SetScriptArg(const std::string& value)
{
    // Оригинал натива просто кладёт строку в глобальную переменную, которую возвращает DScriptGetgDbgString0.
    if (oTrampoline)
        oTrampoline(GameApi::DelphiString(value).get());
}

void Events::BeginCapture()
{
    g_capturing = true;
    g_captured = false;
    g_capture.clear();
}

bool Events::EndCapture(std::string* value)
{
    g_capturing = false;
    if (g_captured && value)
        *value = g_capture;
    return g_captured;
}

void Events::PrintStats()
{
    std::lock_guard lock(g_mutex);
    if (g_counters.empty())
    {
        Console::Print("  no events fired yet");
        return;
    }
    ULONGLONG now = GetTickCount64();
    for (auto& [name, c] : g_counters)
    {
        double rate = c.lastTick ? (c.total - c.lastTotal) * 1000.0 / std::max<ULONGLONG>(1, now - c.lastTick) : 0;
        Console::Print("  %-32s total %8llu   %s%.1f/s since last .events", name.c_str(), c.total,
                       c.lastTick ? "" : "~", rate);
        c.lastTotal = c.total;
        c.lastTick = now;
    }
}
