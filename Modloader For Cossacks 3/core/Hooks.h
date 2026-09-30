#pragma once

// Тонкая обёртка над MinHook.
#include <atomic>

namespace Hooks
{
    bool Init();
    void Shutdown();

    // Счётчик потоков, выполняющих сейчас наш detour-код. MinHook при DisableHook
    // не ждёт уже вошедших: выгрузка DLL раньше их выхода = use-after-free
    // (SwapBuffers, WndProc, файловые хуки). Ставим Hooks::InFlight guard первой
    // строкой каждого detour, а при выгрузке ждём WaitForZero вместо Sleep(200).
    inline std::atomic<long> g_inFlight{ 0 };

    class InFlight
    {
    public:
        InFlight() { ++g_inFlight; }
        ~InFlight() { --g_inFlight; }
    };

    // Ждать обнуления счётчика (новые вызовы после Shutdown невозможны — хуки сняты).
    // Возвращает false по таймауту (тогда выгрузка всё равно идёт дальше, но с варнингом).
    inline bool WaitForZero(DWORD timeoutMs)
    {
        DWORD waited = 0;
        while (g_inFlight.load() != 0 && waited < timeoutMs)
        {
            Sleep(10);
            waited += 10;
        }
        return g_inFlight.load() == 0;
    }

    // Создаёт и сразу включает хук. original получит трамплин на оригинальную функцию.
    bool CreateRaw(const char* name, void* target, void* detour, void** original);

    template <typename Fn>
    bool Create(const char* name, void* target, Fn detour, Fn* original)
    {
        return CreateRaw(name, target, reinterpret_cast<void*>(detour), reinterpret_cast<void**>(original));
    }

    // Хук экспортируемой функции модуля (например, user32.dll!MessageBoxW).
    template <typename Fn>
    bool CreateApi(const wchar_t* module, const char* proc, Fn detour, Fn* original)
    {
        HMODULE mod = GetModuleHandleW(module);
        if (!mod)
            mod = LoadLibraryW(module);
        void* target = mod ? reinterpret_cast<void*>(GetProcAddress(mod, proc)) : nullptr;
        return target && Create(proc, target, detour, original);
    }

    // Адрес внутри exe игры по RVA (смещение от базы модуля).
    inline void* FromRva(uintptr_t rva)
    {
        return reinterpret_cast<void*>(reinterpret_cast<uintptr_t>(GetModuleHandleW(nullptr)) + rva);
    }
}
