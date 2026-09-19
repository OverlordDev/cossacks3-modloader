#include "pch.h"
#include "Console.h"

#include <cstdarg>
#include <mutex>
#include <atomic>

namespace
{
    FILE* g_out = nullptr;
    FILE* g_err = nullptr;
    bool g_ownsConsole = false;
    std::mutex g_writeMutex; // пишут игровой поток, поток ввода и наш поток

    HANDLE g_inHandle = INVALID_HANDLE_VALUE;
    HANDLE g_inThread = nullptr;
    std::atomic<bool> g_inStop = false;
    std::function<void(const std::vector<std::string>&)> g_onLines;

    // Строки копятся и отдаются пачкой после паузы: вставка из буфера приходит за миллисекунды,
    // а человек так быстро Enter не жмёт — так отличаем вставку нескольких строк от ввода.
    std::mutex g_pendingMutex;
    std::vector<std::string> g_pending;
    ULONGLONG g_lastLineTick = 0;
    constexpr ULONGLONG kPasteGapMs = 120;

    void Write(const char* color, const char* tag, const char* fmt, va_list args)
    {
        if (!g_out)
            return;

        char msg[4096];
        vsnprintf(msg, sizeof(msg), fmt, args);

        std::lock_guard lock(g_writeMutex);
        if (tag)
        {
            SYSTEMTIME t;
            GetLocalTime(&t);
            std::printf("\x1b[90m[%02d:%02d:%02d]\x1b[0m %s[%s]\x1b[0m %s\n", t.wHour, t.wMinute, t.wSecond, color, tag, msg);
        }
        else
        {
            std::printf("%s\n", msg);
        }
        std::fflush(stdout);
    }

    std::string WideToUtf8(const wchar_t* w, int len)
    {
        int n = WideCharToMultiByte(CP_UTF8, 0, w, len, nullptr, 0, nullptr, nullptr);
        std::string out(n, '\0');
        WideCharToMultiByte(CP_UTF8, 0, w, len, out.data(), n, nullptr, nullptr);
        return out;
    }

    DWORD WINAPI InputThread(LPVOID)
    {
        wchar_t buf[2048];
        while (!g_inStop)
        {
            DWORD read = 0;
            if (!ReadConsoleW(g_inHandle, buf, _countof(buf) - 1, &read, nullptr))
                break;
            if (g_inStop)
                break;

            int len = static_cast<int>(read);
            while (len > 0 && (buf[len - 1] == L'\r' || buf[len - 1] == L'\n'))
                --len;

            std::lock_guard lock(g_pendingMutex);
            g_pending.push_back(WideToUtf8(buf, len)); // пустые строки тоже: они часть вставленного блока
            g_lastLineTick = GetTickCount64();
        }
        return 0;
    }
}

bool Console::Init(const wchar_t* title)
{
    g_ownsConsole = AllocConsole() != FALSE;
    if (!g_ownsConsole && !AttachConsole(ATTACH_PARENT_PROCESS) && !GetConsoleWindow())
        return false;

    freopen_s(&g_out, "CONOUT$", "w", stdout);
    freopen_s(&g_err, "CONOUT$", "w", stderr);

    SetConsoleTitleW(title);
    SetConsoleOutputCP(CP_UTF8);

    // Включаем ANSI-цвета.
    HANDLE h = CreateFileW(L"CONOUT$", GENERIC_READ | GENERIC_WRITE, FILE_SHARE_READ | FILE_SHARE_WRITE, nullptr, OPEN_EXISTING, 0, nullptr);
    DWORD mode = 0;
    if (GetConsoleMode(h, &mode))
        SetConsoleMode(h, mode | ENABLE_VIRTUAL_TERMINAL_PROCESSING);
    CloseHandle(h);

    // Закрытие консоли крестиком убило бы процесс игры — убираем пункт "Закрыть".
    if (HWND wnd = GetConsoleWindow())
        if (HMENU menu = GetSystemMenu(wnd, FALSE))
            DeleteMenu(menu, SC_CLOSE, MF_BYCOMMAND);

    return true;
}

void Console::Shutdown()
{
    StopInput();
    std::lock_guard lock(g_writeMutex);
    if (g_out) { fclose(g_out); g_out = nullptr; }
    if (g_err) { fclose(g_err); g_err = nullptr; }
    if (g_ownsConsole)
        FreeConsole();
}

void Console::PollInput()
{
    std::vector<std::string> batch;
    {
        std::lock_guard lock(g_pendingMutex);
        if (g_pending.empty() || GetTickCount64() - g_lastLineTick < kPasteGapMs)
            return;
        batch.swap(g_pending);
    }
    g_onLines(batch);
}

void Console::StartInput(std::function<void(const std::vector<std::string>&)> onLines)
{
    g_onLines = std::move(onLines);
    g_inHandle = CreateFileW(L"CONIN$", GENERIC_READ | GENERIC_WRITE, FILE_SHARE_READ | FILE_SHARE_WRITE, nullptr, OPEN_EXISTING, 0, nullptr);
    if (g_inHandle == INVALID_HANDLE_VALUE)
        return;
    // Quick Edit выключен: выделение текста мышью блокирует вывод, и игровой поток завис бы в логе.
    SetConsoleMode(g_inHandle, ENABLE_LINE_INPUT | ENABLE_ECHO_INPUT | ENABLE_PROCESSED_INPUT |
                               ENABLE_EXTENDED_FLAGS | ENABLE_INSERT_MODE);
    g_inStop = false;
    g_inThread = CreateThread(nullptr, 0, InputThread, nullptr, 0, nullptr);
}

void Console::StopInput()
{
    if (!g_inThread)
        return;

    g_inStop = true;

    // ReadConsoleW ждёт Enter — отправляем его сами, чтобы поток вышел до выгрузки DLL.
    INPUT_RECORD rec[2] = {};
    for (int i = 0; i < 2; ++i)
    {
        rec[i].EventType = KEY_EVENT;
        rec[i].Event.KeyEvent.bKeyDown = i == 0;
        rec[i].Event.KeyEvent.wRepeatCount = 1;
        rec[i].Event.KeyEvent.wVirtualKeyCode = VK_RETURN;
        rec[i].Event.KeyEvent.uChar.UnicodeChar = L'\r';
    }
    DWORD written = 0;
    WriteConsoleInputW(g_inHandle, rec, 2, &written);

    if (WaitForSingleObject(g_inThread, 2000) == WAIT_TIMEOUT)
        TerminateThread(g_inThread, 0);
    CloseHandle(g_inThread);
    g_inThread = nullptr;
    CloseHandle(g_inHandle);
    g_inHandle = INVALID_HANDLE_VALUE;
}

void Console::Info(const char* fmt, ...)
{
    va_list a; va_start(a, fmt); Write("\x1b[32m", "INFO", fmt, a); va_end(a);
}

void Console::Warn(const char* fmt, ...)
{
    va_list a; va_start(a, fmt); Write("\x1b[33m", "WARN", fmt, a); va_end(a);
}

void Console::Error(const char* fmt, ...)
{
    va_list a; va_start(a, fmt); Write("\x1b[31m", "ERROR", fmt, a); va_end(a);
}

void Console::Print(const char* fmt, ...)
{
    va_list a; va_start(a, fmt); Write(nullptr, nullptr, fmt, a); va_end(a);
}
