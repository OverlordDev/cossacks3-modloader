#include "pch.h"
#include "Profiler.h"
#include "Console.h"
#include "FrameStats.h"
#include "Symbols.h"

#include <algorithm>
#include <atomic>
#include <map>
#include <unordered_map>
#include <unordered_set>

#include <timeapi.h>
#pragma comment(lib, "winmm.lib")

namespace
{
    constexpr int kDepth = 48;

    struct Sample
    {
        uint32_t count;
        uint32_t pc[kDepth]; // [0] — EIP, дальше адреса возврата
    };

    std::atomic<bool> g_running = false;
    DWORD g_threadId = 0;
    int g_seconds = 0;

    constexpr uintptr_t kStackSpan = 8 * 1024 * 1024;

    // Цепочка EBP (Delphi почти везде строит кадры push ebp / mov ebp, esp).
    void WalkEbp(uintptr_t frame, uintptr_t lo, uintptr_t hi, Sample& s)
    {
        while (s.count < kDepth && frame >= lo && frame < hi && !(frame & 3))
        {
            uintptr_t next = *reinterpret_cast<uintptr_t*>(frame);
            uintptr_t ret = *reinterpret_cast<uintptr_t*>(frame + 4);
            if (!ret)
                break;
            s.pc[s.count++] = static_cast<uint32_t>(ret);
            if (next <= frame)
                break;
            frame = next;
        }
    }

    // Никаких аллокаций и блокировок: поток игры в этот момент заморожен.
    void Walk(const CONTEXT& ctx, Sample& s)
    {
        s.pc[0] = ctx.Eip;
        s.count = 1;
        const uintptr_t hi = ctx.Esp + kStackSpan;
        __try
        {
            if (Symbols::IsExeCode(ctx.Eip))
            {
                WalkEbp(ctx.Ebp, ctx.Esp, hi, s);
                return;
            }

            // Поток в системе/драйвере: там нет EBP-кадров. Ищем в стеке ближайший адрес возврата в exe...
            uintptr_t slot = ctx.Esp;
            for (; slot < ctx.Esp + 64 * 1024; slot += 4)
                if (Symbols::IsExeReturnAddress(*reinterpret_cast<uintptr_t*>(slot)))
                    break;
            if (slot >= ctx.Esp + 64 * 1024)
                return;
            s.pc[s.count++] = *reinterpret_cast<uint32_t*>(slot);

            // ...а дальше — цепочка EBP, если EBP указывает в стек выше найденного слота (драйвер его сохранил).
            if (ctx.Ebp > slot && ctx.Ebp < hi)
            {
                WalkEbp(ctx.Ebp, slot, hi, s);
                return;
            }
            // Иначе продолжаем сканированием (возможны устаревшие адреса в стеке).
            for (slot += 4; s.count < kDepth && slot < ctx.Esp + 256 * 1024; slot += 4)
                if (Symbols::IsExeReturnAddress(*reinterpret_cast<uintptr_t*>(slot)))
                    s.pc[s.count++] = *reinterpret_cast<uint32_t*>(slot);
        }
        __except (EXCEPTION_EXECUTE_HANDLER)
        {
        }
    }

    struct Stat
    {
        Symbols::Symbol sym;
        uint32_t exclusive = 0;
        uint32_t inclusive = 0;
    };

    void PrintTop(const char* title, std::vector<Stat*>& stats, uint32_t Stat::*field, size_t total, size_t limit)
    {
        std::sort(stats.begin(), stats.end(), [&](Stat* a, Stat* b) { return a->*field > b->*field; });
        Console::Print("\x1b[1m%s\x1b[0m", title);
        for (size_t i = 0; i < stats.size() && i < limit && stats[i]->*field; ++i)
            Console::Print("  %5.1f%%  %6u  %s", 100.0 * (stats[i]->*field) / total, stats[i]->*field,
                           Symbols::Name(stats[i]->sym).c_str());
    }

    void Report(const std::vector<Sample>& samples, double seconds)
    {
        std::unordered_map<uint64_t, Stat> stats;
        auto keyOf = [](const Symbols::Symbol& s) { return (static_cast<uint64_t>(s.inExe) << 32) | s.key; };

        std::unordered_map<uintptr_t, uint32_t> modules; // exclusive по модулям (exe = 0)
        // Поток вне exe: (что вызвано снаружи, какая функция игры туда привела) -> семплы.
        std::map<std::pair<uint64_t, uint64_t>, uint32_t> entries;
        std::unordered_set<uint64_t> seen;
        for (const auto& s : samples)
        {
            seen.clear();
            uint64_t leafKey = 0;
            bool foreignLeaf = false, entryFound = false;
            for (uint32_t i = 0; i < s.count; ++i)
            {
                Symbols::Symbol sym = Symbols::Resolve(s.pc[i]);
                uint64_t key = keyOf(sym);
                Stat& st = stats[key];
                st.sym = sym;
                if (i == 0)
                {
                    ++st.exclusive;
                    ++modules[sym.module];
                    leafKey = key;
                    foreignLeaf = !sym.inExe;
                }
                else if (foreignLeaf && !entryFound && sym.inExe)
                {
                    ++entries[{ leafKey, key }];
                    entryFound = true;
                }
                if (seen.insert(key).second) // рекурсия не считается дважды
                    ++st.inclusive;
            }
            if (foreignLeaf && !entryFound)
                ++entries[{ leafKey, 0 }];
        }

        size_t total = samples.size();
        Console::Print("\x1b[1m=== Profile: %zu samples over %.1f s (%.0f/s) ===\x1b[0m", total, seconds, total / seconds);
        FrameStats::Report(seconds);

        std::vector<std::pair<uintptr_t, uint32_t>> mods(modules.begin(), modules.end());
        std::sort(mods.begin(), mods.end(), [](auto& a, auto& b) { return a.second > b.second; });
        Console::Print("\x1b[1mBy module (where the game thread was):\x1b[0m");
        for (size_t i = 0; i < mods.size() && i < 10; ++i)
            Console::Print("  %5.1f%%  %s", 100.0 * mods[i].second / total, Symbols::ModuleName(mods[i].first).c_str());

        std::vector<Stat*> list;
        for (auto& [k, st] : stats)
            list.push_back(&st);
        PrintTop("Top exclusive (the function itself was running):", list, &Stat::exclusive, total, 30);

        // Кто из игры привёл поток в систему/драйвер.
        std::vector<std::pair<std::pair<uint64_t, uint64_t>, uint32_t>> ent(entries.begin(), entries.end());
        std::sort(ent.begin(), ent.end(), [](auto& a, auto& b) { return a.second > b.second; });
        Console::Print("\x1b[1mOutside cossacks.exe: what was running <- game function that called it:\x1b[0m");
        for (size_t i = 0; i < ent.size() && i < 25; ++i)
        {
            const auto& [leaf, caller] = ent[i].first;
            std::string callerName = caller ? Symbols::Name(stats[caller].sym) : "<not found>";
            Console::Print("  %5.1f%%  %6u  %s  <-  %s", 100.0 * ent[i].second / total, ent[i].second,
                           Symbols::Name(stats[leaf].sym).c_str(), callerName.c_str());
        }

        // В inclusive оставляем только функции exe: у системных DLL стек без EBP-кадров неинформативен.
        std::vector<Stat*> exeOnly;
        for (Stat* st : list)
            if (st->sym.inExe)
                exeOnly.push_back(st);
        PrintTop("Top inclusive in cossacks.exe (function or its callees):", exeOnly, &Stat::inclusive, total, 40);
    }

    DWORD WINAPI ProfilerThread(LPVOID)
    {
        HANDLE thread = OpenThread(THREAD_SUSPEND_RESUME | THREAD_GET_CONTEXT | THREAD_QUERY_INFORMATION, FALSE, g_threadId);
        if (!thread)
        {
            LOG_ERROR("Profiler: cannot open game thread %lu", g_threadId);
            g_running = false;
            return 0;
        }

        std::vector<Sample> samples;
        samples.reserve(static_cast<size_t>(g_seconds) * 1200 + 100); // без реаллокаций во время семплинга

        timeBeginPeriod(1);
        LARGE_INTEGER freq, start, now;
        QueryPerformanceFrequency(&freq);
        QueryPerformanceCounter(&start);
        const int64_t end = start.QuadPart + freq.QuadPart * g_seconds;

        do
        {
            if (samples.size() < samples.capacity() && SuspendThread(thread) != static_cast<DWORD>(-1))
            {
                CONTEXT ctx{};
                ctx.ContextFlags = CONTEXT_CONTROL | CONTEXT_INTEGER;
                Sample s;
                bool ok = GetThreadContext(thread, &ctx) != FALSE;
                if (ok)
                    Walk(ctx, s);
                ResumeThread(thread);
                if (ok)
                    samples.push_back(s);
            }
            Sleep(1);
            QueryPerformanceCounter(&now);
        } while (now.QuadPart < end);
        timeEndPeriod(1);
        CloseHandle(thread);

        Report(samples, static_cast<double>(now.QuadPart - start.QuadPart) / freq.QuadPart);
        g_running = false;
        return 0;
    }
}

void Profiler::Start(DWORD threadId, int seconds)
{
    if (g_running.exchange(true))
    {
        Console::Print("Profiler is already running");
        return;
    }
    g_threadId = threadId;
    g_seconds = std::clamp(seconds, 1, 120);
    LOG_INFO("Profiler: sampling game thread %lu for %d s...", threadId, g_seconds);
    if (HANDLE t = CreateThread(nullptr, 0, ProfilerThread, nullptr, 0, nullptr))
        CloseHandle(t);
    else
        g_running = false;
}

bool Profiler::IsRunning()
{
    return g_running;
}
