// dllmain.cpp : Точка входа DLL модлоадера.
#include "pch.h"
#include "core/Loader.h"

BOOL APIENTRY DllMain(HMODULE hModule, DWORD reason, LPVOID)
{
    if (reason == DLL_PROCESS_ATTACH)
    {
        DisableThreadLibraryCalls(hModule);
        // В DllMain нельзя делать тяжёлую работу (loader lock) — уходим в отдельный поток.
        if (HANDLE t = CreateThread(nullptr, 0, Loader::MainThread, hModule, 0, nullptr))
            CloseHandle(t);
    }
    return TRUE;
}
