#include "pch.h"
#include "ExampleMod.h"
#include "../core/Console.h"
#include "../core/Hooks.h"

namespace
{
    // 1. Сигнатура оригинальной функции.
    using SetWindowTextW_t = BOOL(WINAPI*)(HWND, LPCWSTR);
    // 2. Указатель на оригинал (заполнит MinHook).
    SetWindowTextW_t oSetWindowTextW = nullptr;

    // 3. Наша замена.
    BOOL WINAPI hkSetWindowTextW(HWND wnd, LPCWSTR text)
    {
        LOG_INFO("SetWindowTextW called");
        return oSetWindowTextW(wnd, text);
    }

    // Пример хука функции самой игры по RVA:
    // using GameFunc_t = void(__fastcall*)(void* self);
    // GameFunc_t oGameFunc = nullptr;
    // void __fastcall hkGameFunc(void* self) { oGameFunc(self); }
}

bool ExampleMod::Install()
{
    return Hooks::CreateApi(L"user32.dll", "SetWindowTextW", &hkSetWindowTextW, &oSetWindowTextW);
    // Hooks::Create("GameFunc", Hooks::FromRva(0x123456), &hkGameFunc, &oGameFunc);
}
