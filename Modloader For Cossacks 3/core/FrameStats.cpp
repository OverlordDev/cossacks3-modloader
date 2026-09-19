#include "pch.h"
#include "FrameStats.h"
#include "Console.h"
#include "Hooks.h"

#include <algorithm>
#include <mutex>

namespace
{
    // Кольцевой буфер моментов конца кадра (QPC). 16k кадров — больше минуты даже на 240 FPS.
    constexpr size_t kCapacity = 16384;
    int64_t g_stamps[kCapacity];
    size_t g_count = 0; // всего записано
    std::mutex g_mutex;

    double g_qpcFreq = 0;
    bool g_auto = false;
    ULONGLONG g_lastAuto = 0;

    using SwapBuffers_t = BOOL(WINAPI*)(HDC);
    SwapBuffers_t oSwapBuffers = nullptr;

    BOOL WINAPI hkSwapBuffers(HDC dc)
    {
        BOOL result = oSwapBuffers(dc);
        LARGE_INTEGER now;
        QueryPerformanceCounter(&now);
        std::lock_guard lock(g_mutex);
        g_stamps[g_count % kCapacity] = now.QuadPart;
        ++g_count;
        return result;
    }
}

bool FrameStats::Install()
{
    LARGE_INTEGER f;
    QueryPerformanceFrequency(&f);
    g_qpcFreq = static_cast<double>(f.QuadPart);
    return Hooks::CreateApi(L"gdi32.dll", "SwapBuffers", &hkSwapBuffers, &oSwapBuffers);
}

void FrameStats::SetAutoReport(bool on)
{
    g_auto = on;
    g_lastAuto = GetTickCount64();
}

void FrameStats::Update()
{
    if (g_auto && GetTickCount64() - g_lastAuto >= 5000)
    {
        g_lastAuto = GetTickCount64();
        Report(5.0);
    }
}

void FrameStats::Report(double seconds)
{
    std::vector<double> frames; // длительности кадров, мс
    {
        LARGE_INTEGER now;
        QueryPerformanceCounter(&now);
        int64_t from = now.QuadPart - static_cast<int64_t>(seconds * g_qpcFreq);

        std::lock_guard lock(g_mutex);
        size_t available = std::min(g_count, kCapacity);
        for (size_t i = 1; i < available; ++i)
        {
            int64_t cur = g_stamps[(g_count - i) % kCapacity];
            int64_t prev = g_stamps[(g_count - i - 1) % kCapacity];
            if (prev < from)
                break;
            frames.push_back((cur - prev) * 1000.0 / g_qpcFreq);
        }
    }

    if (frames.size() < 2)
    {
        Console::Print("  fps: no frames in the last %.0f s (game minimized or not rendering?)", seconds);
        return;
    }

    double total = 0;
    for (double f : frames)
        total += f;
    std::sort(frames.begin(), frames.end());
    double p99 = frames[std::min(frames.size() - 1, static_cast<size_t>(frames.size() * 0.99))];
    double p50 = frames[frames.size() / 2];

    Console::Print("  fps: avg %.1f | frame avg %.2f ms, median %.2f ms | 1%% low %.1f fps (%.2f ms) | worst %.2f ms | %zu frames / %.1f s",
                   frames.size() * 1000.0 / total, total / frames.size(), p50, 1000.0 / p99, p99, frames.back(),
                   frames.size(), total / 1000.0);
}
