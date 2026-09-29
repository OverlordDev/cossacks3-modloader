#include "pch.h"
#include "MemMap.h"
#include "Console.h"

#include <algorithm>
#include <cstdio>
#include <psapi.h>

#pragma comment(lib, "psapi.lib")

namespace
{
    constexpr uint64_t kMb = 1024 * 1024;
    constexpr uint64_t kWarnFree = 400 * kMb; // меньше — предупреждаем: крупные выделения игры начнут падать

    uint64_t g_minFree = UINT64_MAX; // наименьший запас, который видели за сессию
    uint64_t g_lastPoll = 0, g_lastWarn = 0;
}

MemMap::Stats MemMap::Take()
{
    Stats s;
    SYSTEM_INFO si;
    GetSystemInfo(&si);
    s.limit = reinterpret_cast<uintptr_t>(si.lpMaximumApplicationAddress) + 1;

    uintptr_t addr = reinterpret_cast<uintptr_t>(si.lpMinimumApplicationAddress);
    MEMORY_BASIC_INFORMATION mbi;
    while (addr < s.limit && VirtualQuery(reinterpret_cast<void*>(addr), &mbi, sizeof mbi) == sizeof mbi)
    {
        uint64_t size = mbi.RegionSize;
        if (mbi.State == MEM_FREE)
        {
            s.free += size;
            s.largestFree = std::max<uint64_t>(s.largestFree, size);
        }
        else if (mbi.State == MEM_RESERVE)
            s.reserved += size;
        else if (mbi.Type == MEM_IMAGE)
            s.committedImage += size;
        else if (mbi.Type == MEM_MAPPED)
            s.committedMapped += size;
        else
            s.committedPrivate += size;
        uintptr_t next = reinterpret_cast<uintptr_t>(mbi.BaseAddress) + mbi.RegionSize;
        if (next <= addr)
            break;
        addr = next;
    }
    return s;
}

void MemMap::Summary(char* buf, size_t size)
{
    Stats s = Take();
    snprintf(buf, size,
             "Память:       адресное пространство %llu МБ: private %llu, образы DLL %llu, файлы %llu, "
             "зарезервировано %llu; СВОБОДНО %llu МБ (самый большой кусок %llu МБ)",
             s.limit / kMb, s.committedPrivate / kMb, s.committedImage / kMb, s.committedMapped / kMb,
             s.reserved / kMb, s.free / kMb, s.largestFree / kMb);
}

void MemMap::Print()
{
    Stats s = Take();
    Console::Print("mem: адресное пространство %llu МБ (игра 32-битная; \"out of memory\" — когда оно кончается)", s.limit / kMb);
    Console::Print("  private (куча игры, драйвер): %6llu МБ", s.committedPrivate / kMb);
    Console::Print("  образы DLL/exe:               %6llu МБ", s.committedImage / kMb);
    Console::Print("  отображённые файлы:           %6llu МБ", s.committedMapped / kMb);
    Console::Print("  зарезервировано:              %6llu МБ", s.reserved / kMb);
    Console::Print("  СВОБОДНО:                     %6llu МБ, самый большой непрерывный кусок %llu МБ", s.free / kMb, s.largestFree / kMb);
    if (g_minFree != UINT64_MAX)
        Console::Print("  наименьший запас за сессию:   %6llu МБ", g_minFree / kMb);

    // Самые большие образы: тут видно, сколько отъедают libcef (наш CEF-интерфейс) и драйвер видеокарты.
    struct Mod { char name[64]; uint64_t size; };
    HMODULE mods[512];
    DWORD needed = 0;
    static Mod list[512];
    int n = 0;
    if (EnumProcessModules(GetCurrentProcess(), mods, sizeof mods, &needed))
    {
        for (DWORD i = 0; i < needed / sizeof(HMODULE) && n < 512; ++i)
        {
            MODULEINFO mi;
            wchar_t path[MAX_PATH];
            if (!GetModuleInformation(GetCurrentProcess(), mods[i], &mi, sizeof mi) || !GetModuleFileNameW(mods[i], path, MAX_PATH))
                continue;
            const wchar_t* base = wcsrchr(path, L'\\');
            base = base ? base + 1 : path;
            WideCharToMultiByte(CP_UTF8, 0, base, -1, list[n].name, sizeof list[n].name, nullptr, nullptr);
            list[n].size = mi.SizeOfImage;
            ++n;
        }
        std::sort(list, list + n, [](const Mod& a, const Mod& b) { return a.size > b.size; });
        Console::Print("  самые большие образы:");
        for (int i = 0; i < std::min(n, 8); ++i)
            Console::Print("    %-28s %6.1f МБ", list[i].name, list[i].size / 1048576.0);
    }
}

void MemMap::Poll()
{
    uint64_t now = GetTickCount64();
    if (now - g_lastPoll < 10000)
        return;
    g_lastPoll = now;
    Stats s = Take();
    g_minFree = std::min(g_minFree, s.free);
    if (s.free < kWarnFree && now - g_lastWarn >= 60000)
    {
        g_lastWarn = now;
        Console::Warn("[mem] адресное пространство почти кончилось: свободно %llu МБ (самый большой кусок %llu МБ) — "
                      "игра может упасть с \"out of memory\". Подробности: .mem",
                      s.free / kMb, s.largestFree / kMb);
    }
}
