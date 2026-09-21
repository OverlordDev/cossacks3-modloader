#include "pch.h"
#include "Loader.h"
#include "Assets.h"
#include "Checksum.h"
#include "Console.h"
#include "DevConsole.h"
#include "Engine.h"
#include "Events.h"
#include "FrameStats.h"
#include "Game.h"
#include "Hooks.h"
#include "LuaHost.h"
#include "Net.h"
#include "Overlay.h"
#include "Profiler.h"
#include "ScriptRunner.h"
#include "Ui.h"
#include "WebUi.h"

#include <set>

#include "../mods/ExampleMod.h"
#include "../mods/ScriptLog.h"
#include "../mods/Cheats.h"

namespace
{
    bool GameHasFocus()
    {
        DWORD pid = 0;
        GetWindowThreadProcessId(GetForegroundWindow(), &pid);
        return pid == GetCurrentProcessId() && GetForegroundWindow() != GetConsoleWindow();
    }

    // Лаунчер показывает экран загрузки, пока игра стартует, и ждёт от нас сигнала: как только
    // игра дошла до главного меню, картинку можно убирать. Без лаунчера события просто нет.
    void SignalReadyToLauncher()
    {
        if (HANDLE ready = OpenEventW(EVENT_MODIFY_STATE, FALSE, L"Local\Cossacks3Modloader.Ready"))
        {
            SetEvent(ready);
            CloseHandle(ready);
            LOG_INFO("Launcher: splash screen dismissed");
        }
    }

    // Часть модлоадера, которой нужны скрипты игры: вставки в состояния интерфейса и моды.
    // При автозагрузке мы стартуем раньше самой игры, поэтому ставится не сразу, а как только
    // движок скриптов и интерфейс готовы (Engine::Ready). При инжекте в идущую игру это первый же такт.
    void InstallScriptParts()
    {
        if (Events::Install())
        {
            // Отладка: первое срабатывание каждого события — в лог (дальше счётчики в .events).
            Events::Subscribe("*", [](const std::string& event, const std::string&) {
                static std::set<std::string> seen; // только главный поток игры
                if (seen.insert(event).second)
                    LOG_INFO("\x1b[35m[event]\x1b[0m %s fired (first time)", event.c_str());
            });
            Game::Install();
        // Главное меню — момент, когда игру уже можно показывать.
        Events::Subscribe("game.menu", [](const std::string&, const std::string&) {
            static bool once = false;
            if (!once)
            {
                once = true;
                SignalReadyToLauncher();
            }
        });
            Net::Install(LuaHost::OnNetMessage);
            Ui::Install();
            Ui::SetPressHandler(LuaHost::OnUiPress);
        }
        else
            LOG_WARN("Events failed to install");

        if (!ExampleMod::Install())
            LOG_WARN("ExampleMod failed to install");

        ScriptLog::PrintBuildVersion();
        LuaHost::Start();
        LOG_INFO("Ready. F9 - set all resources to 100000, END (in game) or .unload - unload, .reload - reload build.");
    }
}

DWORD WINAPI Loader::MainThread(LPVOID param)
{
    HMODULE self = static_cast<HMODULE>(param);

    Console::Init(L"Cossacks 3 Modloader");
    LOG_INFO("Cossackss 3 Modloader injected");
    LOG_INFO("Game base: %p", GetModuleHandleW(nullptr));

    ScriptRunner::Install();
    ScriptRunner::Update();

    // Перехваты кода ставятся сразу: адреса в exe постоянны, игра к ним ещё не обращалась.
    bool hooks = Hooks::Init();
    if (hooks)
    {
        if (!FrameStats::Install())
            LOG_WARN("FrameStats failed to install");
        if (!Checksum::Install()) // до вставок событий: лобби должно видеть хеш чистой игры
            LOG_WARN("Checksum failed to install — multiplayer lobbies will reject this game");
        if (!Assets::Install()) // как можно раньше: игра читает шейдеры и текстуры на старте
            LOG_WARN("Assets failed to install — mods cannot replace game files");
        if (!ScriptLog::Install())
            LOG_WARN("ScriptLog failed to install");
    }

    DevConsole::Start();
    bool scriptParts = false;
    if (!Engine::Ready())
        LOG_INFO("Waiting for the game to start...");

    // END срабатывает только когда активно окно игры — чтобы не выгрузиться, двигая курсор в консоли.
    DevConsole::ExitRequest exit = DevConsole::ExitRequest::None;
    while (exit == DevConsole::ExitRequest::None)
    {
        ScriptRunner::Update();
        if (hooks && !scriptParts && Engine::Ready() && ScriptRunner::GameThreadId())
        {
            scriptParts = true;
            InstallScriptParts();
        }
        Console::PollInput();
        FrameStats::Update();
        if (scriptParts) // до установки трогать состояния игры нечем и незачем
        {
            Events::Update();
            Ui::Update();
        }
        Cheats::Update();
        Sleep(50);

        exit = DevConsole::GetExitRequest();
        if ((GetAsyncKeyState(VK_END) & 1) && GameHasFocus())
            exit = DevConsole::ExitRequest::Unload;
    }

    bool reload = exit == DevConsole::ExitRequest::Reload;
    LOG_INFO(reload ? "Reloading..." : "Unloading...");
    if (Profiler::IsRunning())
        LOG_INFO("Waiting for the profiler to finish...");
    while (Profiler::IsRunning()) // его поток исполняет код этой DLL
        Sleep(100);
    DevConsole::Stop();
    LuaHost::Shutdown(); // до Uninstall: Lua закрывается в главном потоке игры через нашу оконную процедуру
    WebUi::Shutdown();   // до Overlay: CefShutdown тоже исполняется в хуке SwapBuffers
    Overlay::Shutdown(); // до Hooks::Shutdown: освобождение идёт в хуке SwapBuffers
    ScriptRunner::Uninstall();
    Hooks::Shutdown();
    Sleep(200); // даём потокам выйти из наших detour-функций
    Console::Shutdown(); // консоль загрузчика не закрывается — она его

    // Загружены через Cossacks3Loader.dll — сообщаем ему; он дождётся выгрузки и при reload загрузит свежую копию.
    using OnCoreExit_t = void(__cdecl*)(DWORD, BOOL);
    if (HMODULE loader = GetModuleHandleW(L"Cossacks3Loader.dll"))
        if (auto onExit = reinterpret_cast<OnCoreExit_t>(GetProcAddress(loader, "Loader_OnCoreExit")))
            onExit(GetCurrentThreadId(), reload);

    FreeLibraryAndExitThread(self, 0);
}
