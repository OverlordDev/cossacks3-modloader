#include "pch.h"
#include "ScriptLog.h"
#include "../core/Console.h"
#include "../core/GameApi.h"
#include "../core/Hooks.h"
#include "../core/Text.h"

namespace
{
    enum class Level { Log, Err, Info, Normal, Error };

    std::string AnsiToUtf8(const char* s)
    {
        return s ? Text::AnsiToUtf8(s) : std::string();
    }

    void __cdecl OnCoreLog(Level level, const char* msg)
    {
        std::string text = AnsiToUtf8(msg);
        switch (level)
        {
        case Level::Log:    Console::Info("\x1b[36m[script]\x1b[0m %s", text.c_str()); break;
        case Level::Err:    Console::Error("\x1b[36m[script]\x1b[0m %s", text.c_str()); break;
        case Level::Info:   Console::Info("\x1b[35m[engine]\x1b[0m %s", text.c_str()); break;
        case Level::Normal: Console::Info("\x1b[35m[engine]\x1b[0m %s", text.c_str()); break;
        case Level::Error:  Console::Error("\x1b[35m[engine]\x1b[0m %s", text.c_str()); break;
        }
    }

    // Логгеры движка — Delphi register: eax = сообщение. Сохраняем регистры, логируем, прыгаем в оригинал.
#define CORE_LOG_HOOK(NAME, LEVEL)                  \
    void* o##NAME = nullptr;                        \
    __declspec(naked) void hk##NAME()               \
    {                                               \
        __asm pushad                                \
        __asm push eax                              \
        __asm push LEVEL                            \
        __asm call OnCoreLog                        \
        __asm add esp, 8                            \
        __asm popad                                 \
        __asm jmp dword ptr [o##NAME]               \
    }

    CORE_LOG_HOOK(CoreLog, 0)
    CORE_LOG_HOOK(CoreErr, 1)
    CORE_LOG_HOOK(CoreInfo, 2)
    CORE_LOG_HOOK(CoreNormal, 3)
    CORE_LOG_HOOK(CoreError, 4)

    GameApi::LogFn oTimeLog = nullptr;

    // TimeLog пишет через отдельный логгер TIM другой формы — перехватываем скриптовую обёртку.
    void __stdcall hkTimeLog(const char* msg)
    {
        Console::Info("\x1b[36m[script:time]\x1b[0m %s", AnsiToUtf8(msg).c_str());
        oTimeLog(msg);
    }

    bool HookCore(const char* name, uintptr_t va, void (*detour)(), void** original)
    {
        return Hooks::CreateRaw(name, GameApi::Addr(va), reinterpret_cast<void*>(detour), original);
    }
}

bool ScriptLog::Install()
{
    bool ok = HookCore("Core LOG", GameApi::Va::CoreLog, hkCoreLog, &oCoreLog);
    ok &= HookCore("Core ERR", GameApi::Va::CoreErr, hkCoreErr, &oCoreErr);
    ok &= HookCore("Core INFO", GameApi::Va::CoreInfo, hkCoreInfo, &oCoreInfo);
    ok &= HookCore("Core NORMAL", GameApi::Va::CoreNormal, hkCoreNormal, &oCoreNormal);
    ok &= HookCore("Core ERROR", GameApi::Va::CoreError, hkCoreError, &oCoreError);
    ok &= Hooks::Create("Script TimeLog", GameApi::Addr(GameApi::Va::TimeLog), &hkTimeLog, &oTimeLog);
    return ok;
}

void ScriptLog::PrintBuildVersion()
{
    auto getBuildVersion = reinterpret_cast<GameApi::GetStringFn>(GameApi::Addr(GameApi::Va::GetBuildVersion));
    char* ver = nullptr; // строку выделяет менеджер памяти Delphi; не освобождаем — мелкая утечка один раз
    getBuildVersion(&ver);
    LOG_INFO("Game build version: %s", ver && *ver ? ver : "(empty — script engine not initialized yet)");
}
