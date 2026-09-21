// Cossacks3Launcher.exe — запускает игру с уже поднятым модлоадером.
//
// Зачем: часть игры (шейдеры, текстуры, конфиги) читается один раз при старте. Инжект в идущую игру
// для этого поздно. Лаунчер создаёт процесс игры приостановленным, грузит в него Cossacks3Loader.dll
// и только потом отпускает — модлоадер оказывается внутри раньше, чем игра успевает что-либо прочитать.
//
// Как пользоваться (Steam): свойства игры -> параметры запуска:
//     "<путь>\Cossacks3Launcher.exe" %command%
// Steam подставит вместо %command% путь к cossacks.exe со своими аргументами. Рядом с лаунчером должны
// лежать Cossacks3Loader.dll и основная DLL модлоадера.
//
// Без аргументов лаунчер ищет cossacks.exe рядом с собой — так его можно просто положить в папку игры.
#define WIN32_LEAN_AND_MEAN
#include <windows.h>

#include <string>

#include "Splash.h"

namespace
{
    constexpr wchar_t kLoaderDll[] = L"Cossacks3Loader.dll";
    constexpr wchar_t kGameExe[]   = L"cossacks.exe";

    void Fail(const std::wstring& text)
    {
        MessageBoxW(nullptr, text.c_str(), L"Cossacks 3 Modloader", MB_ICONERROR | MB_OK);
    }

    std::wstring SelfPath()
    {
        wchar_t path[MAX_PATH];
        GetModuleFileNameW(nullptr, path, MAX_PATH);
        return path;
    }

    std::wstring LauncherDir()
    {
        wchar_t path[MAX_PATH];
        GetModuleFileNameW(nullptr, path, MAX_PATH);
        std::wstring s = path;
        return s.substr(0, s.find_last_of(L"\\/") + 1);
    }

    std::wstring DirOf(const std::wstring& file)
    {
        size_t slash = file.find_last_of(L"\\/");
        return slash == std::wstring::npos ? std::wstring() : file.substr(0, slash);
    }

    // Команда игры — это наша командная строка без собственного пути (то, во что Steam развернул %command%).
    std::wstring GameCommand()
    {
        const wchar_t* cmd = GetCommandLineW();
        const wchar_t* p = cmd;
        if (*p == L'"')                       // свой путь в кавычках
        {
            for (++p; *p && *p != L'"'; ++p) {}
            if (*p == L'"') ++p;
        }
        else
            for (; *p && *p != L' '; ++p) {}
        while (*p == L' ') ++p;

        std::wstring rest = p;
        if (!rest.empty())
            return rest;
        return L'"' + LauncherDir() + kGameExe + L'"'; // положили лаунчер прямо в папку игры
    }

    // Путь к exe из команды — нужен как рабочая папка: игра ищет data\ относительно себя.
    std::wstring ExePath(const std::wstring& command)
    {
        if (command.empty())
            return {};
        if (command[0] == L'"')
        {
            size_t end = command.find(L'"', 1);
            return end == std::wstring::npos ? command.substr(1) : command.substr(1, end - 1);
        }
        size_t space = command.find(L' ');
        return space == std::wstring::npos ? command : command.substr(0, space);
    }

    // Загрузить нашу DLL в чужой процесс: путь пишем в его память и зовём там LoadLibraryW.
    bool Inject(HANDLE process, const std::wstring& dll)
    {
        size_t bytes = (dll.size() + 1) * sizeof(wchar_t);
        void* remote = VirtualAllocEx(process, nullptr, bytes, MEM_COMMIT | MEM_RESERVE, PAGE_READWRITE);
        if (!remote)
            return false;

        bool ok = WriteProcessMemory(process, remote, dll.c_str(), bytes, nullptr) != FALSE;
        if (ok)
        {
            // kernel32 загружен в каждом процессе по одному адресу, так что адрес из нашего годится.
            auto loadLibrary = reinterpret_cast<LPTHREAD_START_ROUTINE>(
                GetProcAddress(GetModuleHandleW(L"kernel32.dll"), "LoadLibraryW"));
            HANDLE thread = CreateRemoteThread(process, nullptr, 0, loadLibrary, remote, 0, nullptr);
            ok = thread != nullptr;
            if (thread)
            {
                WaitForSingleObject(thread, 30000);
                DWORD module = 0; // LoadLibraryW вернула 0 — DLL не загрузилась
                GetExitCodeThread(thread, &module);
                ok = module != 0;
                CloseHandle(thread);
            }
        }
        VirtualFreeEx(process, remote, 0, MEM_RELEASE);
        return ok;
    }
}

int WINAPI wWinMain(HINSTANCE, HINSTANCE, LPWSTR, int)
{
    std::wstring dll = LauncherDir() + kLoaderDll;
    if (GetFileAttributesW(dll.c_str()) == INVALID_FILE_ATTRIBUTES)
    {
        Fail(L"Не найдена " + std::wstring(kLoaderDll) + L".\nОна должна лежать рядом с лаунчером:\n" + LauncherDir());
        return 1;
    }

    std::wstring command = GameCommand();
    std::wstring exe = ExePath(command);
    if (GetFileAttributesW(exe.c_str()) == INVALID_FILE_ATTRIBUTES)
    {
        Fail(L"Не найдена игра:\n" + exe +
             L"\n\nЛаунчер сам игру не ищет — его запускает Steam."
             L"\nВ свойствах игры, в параметрах запуска, должна быть строка:\n\n\"" + SelfPath() +
             L"\" %command%"
             L"\n\nЛибо положите лаунчер прямо в папку игры, рядом с cossacks.exe.");
        return 1;
    }
    std::wstring workDir = DirOf(exe);

    // Событие создаём до запуска: модлоадер внутри игры откроет его по имени и взведёт,
    // когда дойдёт до главного меню.
    HANDLE ready = Splash::CreateReadyEvent();

    STARTUPINFOW si = { sizeof(si) };
    PROCESS_INFORMATION pi = {};
    std::wstring mutableCommand = command; // CreateProcessW пишет в этот буфер
    if (!CreateProcessW(nullptr, mutableCommand.data(), nullptr, nullptr, FALSE, CREATE_SUSPENDED,
                        nullptr, workDir.empty() ? nullptr : workDir.c_str(), &si, &pi))
    {
        Fail(L"Не удалось запустить игру:\n" + exe);
        return 1;
    }

    // Игра стоит на паузе до первой инструкции — самое раннее место, где можно оказаться внутри.
    if (!Inject(pi.hProcess, dll))
    {
        Fail(L"Не удалось загрузить модлоадер в игру.\nИгра запустится без модов.");
        ResumeThread(pi.hThread);
    }
    else
        ResumeThread(pi.hThread);

    // Экран загрузки: игра стартует долго, и первые секунды у неё нет даже окна.
    Splash::Run(GetModuleHandleW(nullptr), workDir.empty() ? std::wstring() : workDir + L"\\",
                ready, pi.hProcess, 90000);

    // Ждём игру, а не выходим сразу: иначе Steam считает, что игра уже закрыта.
    WaitForSingleObject(pi.hProcess, INFINITE);
    CloseHandle(pi.hThread);
    CloseHandle(pi.hProcess);
    if (ready)
        CloseHandle(ready);
    return 0;
}
