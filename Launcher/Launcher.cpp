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
#include <TlHelp32.h>

#include <cstring>
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

    // Адрес LoadLibraryW В ЧУЖОМ процессе: база его kernel32 (Toolhelp) + разбор
    // export table чтением из его памяти. Адрес из нашего процесса больше не
    // используется: совпадение баз системных DLL — лишь обычное, но не
    // гарантированное поведение ASLR (другая сессия/патч — и инъекция ломалась).
    void* GetRemoteProcAddress(HANDLE process, const wchar_t* module, const char* proc)
    {
        DWORD pid = GetProcessId(process);
        HANDLE snap = CreateToolhelp32Snapshot(TH32CS_SNAPMODULE | TH32CS_SNAPMODULE32, pid);
        if (snap == INVALID_HANDLE_VALUE)
            return nullptr;
        ULONGLONG base = 0;
        MODULEENTRY32W me;
        me.dwSize = sizeof(me);
        for (BOOL ok = Module32FirstW(snap, &me); ok; ok = Module32NextW(snap, &me))
        {
            if (_wcsicmp(me.szModule, module) == 0)
            {
                base = reinterpret_cast<ULONGLONG>(me.modBaseAddr);
                break;
            }
        }
        CloseHandle(snap);
        if (!base || base > 0xFFFFFFFFULL)
            return nullptr; // 32-битный процесс: база обязана влезать в 32 бита
        auto read = [&](ULONGLONG addr, void* buf, size_t n) {
            SIZE_T done = 0;
            return ReadProcessMemory(process, reinterpret_cast<LPCVOID>(addr), buf, n, &done) &&
                   done == n;
        };
        IMAGE_DOS_HEADER dos{};
        if (!read(base, &dos, sizeof(dos)) || dos.e_magic != IMAGE_DOS_SIGNATURE)
            return nullptr;
        IMAGE_NT_HEADERS32 nt{};
        if (!read(base + dos.e_lfanew, &nt, sizeof(nt)) || nt.Signature != IMAGE_NT_SIGNATURE)
            return nullptr;
        const auto& expDir = nt.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_EXPORT];
        if (!expDir.VirtualAddress || !expDir.Size)
            return nullptr;
        // Заголовки целиком читать не будем — тянем таблицу точечно, с проверками границ.
        auto inRange = [&](ULONGLONG addr, size_t n) {
            return addr >= base + expDir.VirtualAddress &&
                   addr + n <= base + expDir.VirtualAddress + expDir.Size;
        };
        DWORD namesRva = 0, funcsRva = 0, ordsRva = 0, count = 0;
        // IMAGE_EXPORT_DIRECTORY: NumberOfNames+20, AddressOfFunctions+28, Names+32, Ordinals+36.
        if (!read(base + expDir.VirtualAddress + 24, &count, 4))
            return nullptr;
        if (count == 0 || count > 100000)
            return nullptr;
        if (!read(base + expDir.VirtualAddress + 28, &funcsRva, 4) ||
            !read(base + expDir.VirtualAddress + 32, &namesRva, 4) ||
            !read(base + expDir.VirtualAddress + 36, &ordsRva, 4))
            return nullptr;
        size_t want = strlen(proc);
        char name[256];
        for (DWORD i = 0; i < count; ++i)
        {
            DWORD nameRva = 0;
            ULONGLONG nameAddr = base + namesRva + static_cast<ULONGLONG>(i) * 4;
            if (!inRange(nameAddr, 4) || !read(nameAddr, &nameRva, 4))
                return nullptr;
            ULONGLONG strAddr = base + nameRva;
            if (strAddr < base || strAddr + want + 1 >= base + 0x10000000ULL)
                continue;
            if (!read(strAddr, name, want + 1))
                continue;
            if (memcmp(name, proc, want + 1) != 0)
                continue;
            WORD ord = 0;
            ULONGLONG ordAddr = base + ordsRva + static_cast<ULONGLONG>(i) * 2;
            if (!inRange(ordAddr, 2) || !read(ordAddr, &ord, 2))
                return nullptr;
            DWORD funcRva = 0;
            ULONGLONG funcAddr = base + funcsRva + static_cast<ULONGLONG>(ord) * 4;
            if (!inRange(funcAddr, 4) || !read(funcAddr, &funcRva, 4) || !funcRva)
                return nullptr;
            // Форварды (RVA внутри export directory) не поддерживаем — такого у LoadLibraryW нет.
            if (funcRva >= expDir.VirtualAddress && funcRva < expDir.VirtualAddress + expDir.Size)
                return nullptr;
            return reinterpret_cast<void*>(base + funcRva);
        }
        return nullptr;
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
            auto loadLibrary = reinterpret_cast<LPTHREAD_START_ROUTINE>(
                GetRemoteProcAddress(process, L"kernel32.dll", "LoadLibraryW"));
            // На части Windows kernel32!LoadLibraryW — forwarder в KernelBase.
            // GetRemoteProcAddress намеренно не исполняет forwarder-строки, поэтому
            // пробуем реальный экспорт KernelBase напрямую.
            if (!loadLibrary)
                loadLibrary = reinterpret_cast<LPTHREAD_START_ROUTINE>(
                    GetRemoteProcAddress(process, L"KernelBase.dll", "LoadLibraryW"));
            // Последний fallback для старых/нестандартных систем: у 32-битной
            // игры системные DLL обычно разделяют адрес, а старый путь через
            // локальный kernel32 уже был рабочим. Это сохраняет запуск даже если
            // Toolhelp/ReadProcessMemory временно не отдаёт таблицу экспорта.
            if (!loadLibrary)
                loadLibrary = reinterpret_cast<LPTHREAD_START_ROUTINE>(
                    GetProcAddress(GetModuleHandleW(L"kernel32.dll"), "LoadLibraryW"));
            if (!loadLibrary)
            {
                VirtualFreeEx(process, remote, 0, MEM_RELEASE);
                return false;
            }
            HANDLE thread = CreateRemoteThread(process, nullptr, 0, loadLibrary, remote, 0, nullptr);
            ok = thread != nullptr;
            if (thread)
            {
                if (WaitForSingleObject(thread, 30000) != WAIT_OBJECT_0)
                {
                    // Поток ещё читает путь из remote — освобождать память под ним нельзя.
                    CloseHandle(thread);
                    return false;
                }
                DWORD module = 0; // LoadLibraryW вернула 0 — DLL не загрузилась
                GetExitCodeThread(thread, &module);
                ok = module != 0 && module != STILL_ACTIVE;
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
