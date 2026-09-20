// Cossacks3Loader.dll — маленький загрузчик, который инжектится один раз.
// Копирует основную DLL модлоадера во %TEMP% и загружает копию: оригинал не блокируется,
// его можно пересобирать, а команда .reload в консоли подгружает новую сборку без перезапуска игры.
#define WIN32_LEAN_AND_MEAN
#include <windows.h>

#include <string>

namespace
{
    constexpr wchar_t kCoreDllName[] = L"Modloader For Cossacks 3.dll";

    HMODULE g_self = nullptr;
    HANDLE g_event = nullptr;       // сигнал от основной DLL: "я выгружаюсь"
    volatile DWORD g_coreThread = 0; // её поток — ждём его завершения
    volatile BOOL g_reload = FALSE;
    bool g_ownsConsole = false;

    std::wstring g_copyPath;

    void Log(const char* text)
    {
        HANDLE out = CreateFileW(L"CONOUT$", GENERIC_WRITE, FILE_SHARE_READ | FILE_SHARE_WRITE, nullptr, OPEN_EXISTING, 0, nullptr);
        if (out == INVALID_HANDLE_VALUE)
            return;
        std::string line = std::string("\x1b[90m[loader]\x1b[0m ") + text + "\n";
        DWORD written = 0;
        WriteFile(out, line.data(), static_cast<DWORD>(line.size()), &written, nullptr);
        CloseHandle(out);
    }

    std::wstring ModuleDir(HMODULE mod)
    {
        wchar_t path[MAX_PATH];
        GetModuleFileNameW(mod, path, MAX_PATH);
        std::wstring s = path;
        return s.substr(0, s.find_last_of(L"\\/") + 1);
    }

    std::wstring TempDir()
    {
        wchar_t tmp[MAX_PATH];
        GetTempPathW(MAX_PATH, tmp);
        std::wstring dir = std::wstring(tmp) + L"Cossacks3ModLoader\\";
        CreateDirectoryW(dir.c_str(), nullptr);
        return dir;
    }

    // Копии от прошлых запусков (после вылета игры) — удаляем; занятые просто не удалятся.
    void CleanOldCopies()
    {
        std::wstring dir = TempDir();
        WIN32_FIND_DATAW fd;
        HANDLE find = FindFirstFileW((dir + L"core_*.dll").c_str(), &fd);
        if (find == INVALID_HANDLE_VALUE)
            return;
        do
            DeleteFileW((dir + fd.cFileName).c_str());
        while (FindNextFileW(find, &fd));
        FindClose(find);
    }

    bool LoadCore()
    {
        std::wstring src = ModuleDir(g_self) + kCoreDllName;
        g_copyPath = TempDir() + L"core_" + std::to_wstring(GetTickCount64()) + L".dll";

        if (!CopyFileW(src.c_str(), g_copyPath.c_str(), FALSE))
        {
            Log("failed to copy core DLL (is it built? is the build still running?)");
            return false;
        }
        if (!LoadLibraryW(g_copyPath.c_str()))
        {
            Log("LoadLibrary of core DLL copy failed");
            DeleteFileW(g_copyPath.c_str());
            return false;
        }
        return true;
    }

    // Ждём, пока основная DLL полностью выгрузится: её поток завершается в FreeLibraryAndExitThread.
    void WaitCoreGone()
    {
        if (HANDLE thread = OpenThread(SYNCHRONIZE, FALSE, g_coreThread))
        {
            WaitForSingleObject(thread, 10000);
            CloseHandle(thread);
        }
        for (int i = 0; i < 50 && GetModuleHandleW(g_copyPath.c_str()); ++i)
            Sleep(100);
        DeleteFileW(g_copyPath.c_str());
    }

    // console = 0 в <игра>\modloader\settings.txt — окно консоли не открывать.
    // Консоль создаёт загрузчик, поэтому настройку приходится читать и здесь.
    bool ConsoleWanted()
    {
        wchar_t exe[MAX_PATH];
        GetModuleFileNameW(nullptr, exe, MAX_PATH);
        std::wstring path = exe;
        path = path.substr(0, path.find_last_of(L"\/") + 1) + L"modloader\settings.txt";

        HANDLE file = CreateFileW(path.c_str(), GENERIC_READ, FILE_SHARE_READ, nullptr, OPEN_EXISTING, 0, nullptr);
        if (file == INVALID_HANDLE_VALUE)
            return true;
        char text[4096] = {};
        DWORD read = 0;
        ReadFile(file, text, sizeof(text) - 1, &read, nullptr);
        CloseHandle(file);

        std::string data(text, read);
        for (char& c : data)
            c = static_cast<char>(tolower(static_cast<unsigned char>(c)));
        // Ищем строку console = 0, не считая закомментированных.
        for (size_t pos = 0; pos < data.size();)
        {
            size_t end = data.find('\n', pos);
            if (end == std::string::npos)
                end = data.size();
            std::string line = data.substr(pos, end - pos);
            pos = end + 1;
            size_t first = line.find_first_not_of(" \t");
            if (first == std::string::npos || line[first] == '#' || line[first] == ';')
                continue;
            if (line.find("console") != std::string::npos && line.find('=') != std::string::npos &&
                (line.find('0') != std::string::npos || line.find("false") != std::string::npos ||
                 line.find("off") != std::string::npos || line.find("no") != std::string::npos))
                return false;
        }
        return true;
    }

    DWORD WINAPI BootThread(LPVOID)
    {
        // Консоль принадлежит загрузчику — переживает перезагрузки основной DLL.
        g_ownsConsole = ConsoleWanted() && AllocConsole() != FALSE;
        Log("Cossacks3Loader started");

        CleanOldCopies();
        bool loaded = LoadCore();

        for (;;)
        {
            if (!loaded)
            {
                // Основная DLL не загрузилась (не собрана или сборка ещё идёт) — пробуем снова.
                Log("retrying in 3 s...");
                Sleep(3000);
                loaded = LoadCore();
                continue;
            }

            WaitForSingleObject(g_event, INFINITE);
            WaitCoreGone();

            if (!g_reload)
                break;

            Log("reloading core DLL...");
            loaded = LoadCore();
        }

        Log("Cossacks3Loader unloaded");
        CloseHandle(g_event);
        if (g_ownsConsole)
            FreeConsole();
        FreeLibraryAndExitThread(g_self, 0);
    }
}

// Вызывается основной DLL прямо перед FreeLibraryAndExitThread.
extern "C" __declspec(dllexport) void __cdecl Loader_OnCoreExit(DWORD coreThreadId, BOOL reload)
{
    g_coreThread = coreThreadId;
    g_reload = reload;
    SetEvent(g_event);
}

BOOL APIENTRY DllMain(HMODULE module, DWORD reason, LPVOID)
{
    if (reason == DLL_PROCESS_ATTACH)
    {
        g_self = module;
        DisableThreadLibraryCalls(module);
        g_event = CreateEventW(nullptr, FALSE, FALSE, nullptr);
        if (HANDLE t = CreateThread(nullptr, 0, BootThread, nullptr, 0, nullptr))
            CloseHandle(t);
    }
    return TRUE;
}
