#include "pch.h"
#include "CrashHandler.h"
#include "DevConsole.h"
#include "Assets.h"
#include "Checksum.h"
#include "Console.h"
#include "WebUi.h"
#include "Engine.h"
#include "Events.h"
#include "FrameStats.h"
#include "GameApi.h"
#include "Profiler.h"
#include "LuaHost.h"
#include "ScriptRunner.h"
#include "Text.h"

#include <algorithm>
#include <atomic>
#include <filesystem>
#include <fstream>
#include <mutex>
#include <set>

namespace fs = std::filesystem;

namespace
{
    // .crashtest av: настоящее нарушение доступа, пойманное здесь же, — проверка отчётов о сбоях
    // без падения игры (обработчик видит исключение раньше, чем этот __except).
    bool TriggerAccessViolation()
    {
        __try
        {
            volatile int* p = reinterpret_cast<volatile int*>(0x24);
            *p = 1;
        }
        __except (EXCEPTION_EXECUTE_HANDLER)
        {
            return true;
        }
        return false;
    }

    std::atomic<DevConsole::ExitRequest> g_exit = DevConsole::ExitRequest::None;

    // Функции библиотеки скриптов игры (data/scripts/lib/*.script) — вызываются из скриптов так же, как нативы.
    struct LibFunc
    {
        std::string file;
        std::string decl;
    };
    std::vector<LibFunc> g_lib;
    std::once_flag g_libOnce;

    using Text::Utf8ToAnsi;

    std::string Lower(std::string s)
    {
        std::transform(s.begin(), s.end(), s.begin(), [](unsigned char c) { return static_cast<char>(tolower(c)); });
        return s;
    }

    std::string Trim(const std::string& s)
    {
        size_t b = s.find_first_not_of(" \t");
        if (b == std::string::npos)
            return {};
        size_t e = s.find_last_not_of(" \t");
        return s.substr(b, e - b + 1);
    }

    void LoadScriptLibrary()
    {
        wchar_t exe[MAX_PATH];
        GetModuleFileNameW(nullptr, exe, MAX_PATH);
        fs::path dir = fs::path(exe).parent_path() / L"data" / L"scripts" / L"lib";

        std::error_code ec;
        std::set<std::string> seen;
        for (const auto& entry : fs::directory_iterator(dir, ec))
        {
            if (entry.path().extension() != L".script")
                continue;
            std::ifstream in(entry.path());
            std::string line;
            while (std::getline(in, line))
            {
                if (!line.empty() && line.back() == '\r')
                    line.pop_back();
                if ((line.rfind("procedure ", 0) == 0 || line.rfind("function ", 0) == 0) && seen.insert(line).second)
                    g_lib.push_back({ entry.path().filename().string(), line });
            }
        }
        LOG_INFO("Script library: %zu functions from %s", g_lib.size(), dir.string().c_str());
    }

    // Ранг совпадения: 0 — имя целиком равно первому слову, 1 — начинается с него, 2 — просто содержит; -1 — нет.
    // Все слова должны встречаться в имени (или во всём объявлении при fullDecl).
    int Rank(std::string_view decl, const std::vector<std::string>& terms, bool fullDecl)
    {
        std::string name = Lower(std::string(GameApi::NameOf(decl)));
        std::string hay = fullDecl ? Lower(std::string(decl)) : name;
        for (const auto& t : terms)
            if (hay.find(t) == std::string::npos)
                return -1;
        if (name == terms[0])
            return 0;
        return name.rfind(terms[0], 0) == 0 ? 1 : 2;
    }

    void Find(const std::string& query)
    {
        std::call_once(g_libOnce, LoadScriptLibrary);

        bool fullDecl = false;
        std::vector<std::string> terms;
        for (size_t pos = 0; pos < query.size();)
        {
            size_t end = query.find(' ', pos);
            if (end == std::string::npos)
                end = query.size();
            std::string t = Lower(query.substr(pos, end - pos));
            if (t == "-d")
                fullDecl = true;
            else if (!t.empty())
                terms.push_back(t);
            pos = end + 1;
        }
        if (terms.empty())
        {
            Console::Print("Usage: .find [-d] <words>   (-d — искать и в параметрах)");
            return;
        }

        struct Hit { int rank; std::string line; };
        std::vector<Hit> natives, scripts;
        char buf[1024];
        for (const auto& n : GameApi::Natives())
            if (int r = Rank(n.decl, terms, fullDecl); r >= 0)
            {
                snprintf(buf, sizeof(buf), "  \x1b[33mnative\x1b[0m %08X      %s", static_cast<unsigned>(n.va), n.decl);
                natives.push_back({ r, buf });
            }
        for (const auto& f : g_lib)
            if (int r = Rank(f.decl, terms, fullDecl); r >= 0)
            {
                snprintf(buf, sizeof(buf), "  \x1b[36mscript\x1b[0m %-14s %s", f.file.c_str(), f.decl.c_str());
                scripts.push_back({ r, buf });
            }

        constexpr size_t kLimit = 40; // на каждую группу
        auto print = [](std::vector<Hit>& hits) {
            std::stable_sort(hits.begin(), hits.end(), [](const Hit& a, const Hit& b) { return a.rank < b.rank; });
            for (size_t i = 0; i < hits.size() && i < kLimit; ++i)
                Console::Print("%s", hits[i].line.c_str());
            if (hits.size() > kLimit)
                Console::Print("  ... ещё %zu, уточни запрос", hits.size() - kLimit);
        };
        print(natives);
        print(scripts);
        Console::Print("  natives: %zu, script library: %zu", natives.size(), scripts.size());
    }

    void Help()
    {
        Console::Print(
            "\x1b[1mDev console\x1b[0m — строка выполняется как код скрипта игры (Pascal/DWScript).\n"
            "  <code>              выполнить код:  gPlayer[0].res[4] := 500;\n"
            "  ? <expr>            вывести строку:  ? GetBuildVersion\n"
            "  ?i / ?f / ?b <expr> вывести Integer / Float / Boolean:  ?i GetPlayerIndexInterfaceIO\n"
            "  /<text>             команда чата игры:  /res all 5000   /cheat fog   /fps\n"
            "  .find <words>       поиск функций по имени (нативы + библиотека скриптов):  .find player res\n"
            "  .find -d <words>    то же, но слова ищутся во всём объявлении, включая параметры\n"
            "  (вставка нескольких строк выполняется одним блоком скрипта; вставленный лог игнорируется)\n"
            "  .fps [сек]          FPS и время кадра за последние N секунд (по умолчанию 5)\n"
            "  .fps on / off       выводить FPS каждые 5 секунд\n"
            "  .prof [сек]         профилировщик главного потока (по умолчанию 10 с), топ функций\n"
            "  .state <Name> [N]   код состояния GUI state machine (menu.aix): флаги и первые N строк\n"
            "  .hook <Name> [end]  событие gui.<Name> в начале (или в конце) состояния GUI\n"
            "  .events             счётчики событий\n"
            "  .checksum           хеш скриптов для лобби: движка, чистый (без модлоадера) и сохранённый игрой\n"
            "  =<lua>              выполнить Lua:  =player().gold   =native.GetBuildVersion()\n"
            "  .mods               Lua-моды (modloader/mods/*/manifest.lua) и их статус\n"
            "  .lua reload         перезагрузить все Lua-моды\n"
            "  .natives            количество нативов\n"
            "  .crashtest [av]     отчёт о сбое вручную / настоящий сбой (пойманный) — проверка modloader\\crashes\n"
            "  .reload             перезагрузить модлоадер из свежей сборки (при инжекте через Cossacks3Loader.dll)\n"
            "  .unload             выгрузить модлоадер\n"
            "  .help               эта справка");
    }

    void RunCode(const std::string& code)
    {
        ScriptRunner::Queue({ Utf8ToAnsi(code) });
    }

    void OnLine(const std::string& raw)
    {
        std::string line = Trim(raw);
        if (line.empty())
            return;

        if (line[0] == '=')
        {
            LuaHost::RunConsole(line.substr(1));
            return;
        }

        if (line[0] == '.')
        {
            std::string cmd = line.substr(1), arg;
            if (size_t sp = cmd.find(' '); sp != std::string::npos)
            {
                arg = Trim(cmd.substr(sp + 1));
                cmd = cmd.substr(0, sp);
            }

            if (cmd == "help")
                Help();
            else if (cmd == "find")
                Find(arg);
            else if (cmd == "fps")
            {
                if (arg == "on" || arg == "off")
                {
                    FrameStats::SetAutoReport(arg == "on");
                    Console::Print("fps auto report: %s", arg.c_str());
                }
                else
                    FrameStats::Report(arg.empty() ? 5.0 : atof(arg.c_str()));
            }
            else if (cmd == "prof")
            {
                if (DWORD tid = ScriptRunner::GameThreadId())
                    Profiler::Start(tid, arg.empty() ? 10 : atoi(arg.c_str()));
                else
                    Console::Print("Game thread unknown yet");
            }
            else if (cmd == "state")
            {
                std::string name = arg;
                int lines = 20;
                if (size_t sp = arg.find(' '); sp != std::string::npos)
                {
                    name = arg.substr(0, sp);
                    lines = atoi(arg.c_str() + sp + 1);
                }
                ScriptRunner::RunOnGameThread([name, lines] { Engine::DumpState(name, lines); });
            }
            else if (cmd == "hook")
            {
                bool atEnd = arg.size() > 4 && arg.compare(arg.size() - 4, 4, " end") == 0;
                std::string state = atEnd ? Trim(arg.substr(0, arg.size() - 4)) : arg;
                if (state.empty())
                    Console::Print("Usage: .hook <GuiState> [end]");
                else
                    Events::HookGuiState(state, atEnd);
            }
            else if (cmd == "events")
                Events::PrintStats();
            else if (cmd == "checksum")
                Checksum::Print();
            else if (cmd == "mods")
                LuaHost::PrintMods();
            else if (cmd == "assets")
                Assets::Print();
            else if (cmd == "crashtest")
            {
                CrashHandler::Scope scope("консоль: .crashtest " + arg);
                if (arg == "av")
                {
                    TriggerAccessViolation();
                    Console::Print("crashtest: access violation raised and caught — see modloader\\crashes");
                }
                else
                    Console::Print("crashtest: report written to %s", CrashHandler::ReportNow("ручной отчёт (.crashtest)").c_str());
            }
            else if (cmd == "web")
            {
                if (arg.empty() || arg == "status")
                    Console::Print("web: %s", WebUi::Status().c_str());
                else if (arg == "close")
                    WebUi::RequestClose();
                else if (arg == "reload")
                    WebUi::RequestReload();
                else
                    WebUi::RequestOpen(arg);
            }
            else if (cmd == "lua")
            {
                if (arg == "reload")
                    LuaHost::Reload();
                else
                    Console::Print("Usage: .lua reload");
            }
            else if (cmd == "natives")
                Console::Print("%zu natives", GameApi::Natives().size());
            else if ((cmd == "unload" || cmd == "reload") && WebUi::Running())
            {
                // CEF нельзя поднять второй раз в том же процессе, а новая сборка модлоадера попробует —
                // и уронит игру. Поэтому после запуска браузера выгрузка закрыта.
                Console::Print(".%s is not available after the browser (CEF) was started: restart the game.\n"
                               "  Lua mods: .lua reload    pages: saved files reload by themselves (dev.txt), or .web reload",
                               cmd.c_str());
            }
            else if (cmd == "unload")
                g_exit = DevConsole::ExitRequest::Unload;
            else if (cmd == "reload")
            {
                if (GetModuleHandleW(L"Cossacks3Loader.dll"))
                    g_exit = DevConsole::ExitRequest::Reload;
                else
                    Console::Print(".reload works only when injected via Cossacks3Loader.dll");
            }
            else
                Console::Print("Unknown command .%s, see .help", cmd.c_str());
            return;
        }

        if (line[0] == '/')
        {
            std::string text = Utf8ToAnsi(line.substr(1));
            std::string escaped;
            for (char c : text)
                escaped += c == '\'' ? std::string("''") : std::string(1, c);
            ScriptRunner::Queue({
                "var modloaderCmd : String = '" + escaped + "';",
                "_misc_ProcessMessage(modloaderCmd);",
            });
            return;
        }

        if (line[0] == '?')
        {
            const char* conv = nullptr;
            size_t skip = 1;
            if (line.size() > 1 && line[1] == 'i') conv = "IntToStr", skip = 2;
            else if (line.size() > 1 && line[1] == 'f') conv = "FloatToStr", skip = 2;
            else if (line.size() > 1 && line[1] == 'b') conv = "BoolToStr", skip = 2;

            std::string expr = Trim(line.substr(skip));
            if (!expr.empty() && expr.back() == ';')
                expr.pop_back();
            RunCode(conv ? "Log('= ' + " + std::string(conv) + "(" + expr + "));" : "Log('= ' + (" + expr + "));");
            return;
        }

        RunCode(line);
    }

    // Похоже на вывод нашей же консоли: "[15:17:11] [INFO] ..." или строки результатов .find.
    bool LooksLikeLogOutput(const std::string& line)
    {
        bool timestamp = line.size() >= 10 && line[0] == '[' && isdigit(static_cast<unsigned char>(line[1])) &&
                         line[3] == ':' && line[6] == ':' && line[9] == ']';
        return timestamp || line.rfind("  native ", 0) == 0 || line.rfind("  script ", 0) == 0;
    }

    void OnLines(const std::vector<std::string>& lines)
    {
        std::vector<std::string> nonEmpty;
        for (const auto& l : lines)
            if (!Trim(l).empty())
                nonEmpty.push_back(l);

        if (nonEmpty.size() <= 1)
        {
            if (!nonEmpty.empty())
                OnLine(nonEmpty[0]);
            return;
        }

        // Вставка нескольких строк.
        size_t logLike = std::count_if(nonEmpty.begin(), nonEmpty.end(), LooksLikeLogOutput);
        if (logLike > 0)
        {
            LOG_WARN("Pasted %zu lines that look like console output — ignored", nonEmpty.size());
            return;
        }

        // Есть команды консоли (. ? /) — это список команд, выполняем по одной.
        bool hasCommands = std::any_of(nonEmpty.begin(), nonEmpty.end(), [](const std::string& l) {
            char c = Trim(l)[0];
            return c == '.' || c == '?' || c == '/' || c == '=';
        });
        if (hasCommands)
        {
            for (const auto& l : nonEmpty)
            {
                Console::Print("> %s", Trim(l).c_str());
                OnLine(l);
            }
            return;
        }
        LOG_INFO("Pasted %zu lines — running as one script block", nonEmpty.size());
        std::vector<std::string> code;
        for (const auto& l : lines)
            code.push_back(Utf8ToAnsi(l));
        ScriptRunner::Queue(std::move(code));
    }
}

void DevConsole::Start()
{
    Console::StartInput(OnLines);
    LOG_INFO("Dev console ready — type .help");
}

void DevConsole::Stop()
{
    Console::StopInput();
}

DevConsole::ExitRequest DevConsole::GetExitRequest()
{
    return g_exit;
}
