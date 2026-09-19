#include "pch.h"
#include "Loader.h"
#include "Console.h"
#include "DevConsole.h"
#include "Events.h"
#include "FrameStats.h"
#include "Hooks.h"
#include "LuaHost.h"
#include "Overlay.h"
#include "Profiler.h"
#include "ScriptRunner.h"

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
}

DWORD WINAPI Loader::MainThread(LPVOID param)
{
    HMODULE self = static_cast<HMODULE>(param);

    Console::Init(L"Cossacks 3 Modloader");
    LOG_INFO("Cossackss 3 Modloader injected");
    LOG_INFO("Game base: %p", GetModuleHandleW(nullptr));

    ScriptRunner::Install();
    ScriptRunner::Update();

    if (Hooks::Init())
    {
        if (!FrameStats::Install())
            LOG_WARN("FrameStats failed to install");
        if (Events::Install())
        {
            // Отладка: первое срабатывание каждого события — в лог (дальше счётчики в .events).
            Events::Subscribe("*", [](const std::string& event) {
                static std::set<std::string> seen; // только главный поток игры
                if (seen.insert(event).second)
                    LOG_INFO("\x1b[35m[event]\x1b[0m %s fired (first time)", event.c_str());
            });
        }
        else
            LOG_WARN("Events failed to install");

        // Регистрация модов.
        if (!ExampleMod::Install())
            LOG_WARN("ExampleMod failed to install");
        if (!ScriptLog::Install())
            LOG_WARN("ScriptLog failed to install");
    }

    ScriptLog::PrintBuildVersion();
    DevConsole::Start();
    LuaHost::Start();
    LOG_INFO("Ready. F9 - set all resources to 100000, END (in game) or .unload - unload, .reload - reload build.");

    // END срабатывает только когда активно окно игры — чтобы не выгрузиться, двигая курсор в консоли.
    DevConsole::ExitRequest exit = DevConsole::ExitRequest::None;
    while (exit == DevConsole::ExitRequest::None)
    {
        ScriptRunner::Update();
        Console::PollInput();
        FrameStats::Update();
        Events::Update();
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
