#pragma once

// Тонкая обёртка над MinHook.
namespace Hooks
{
    bool Init();
    void Shutdown();

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
