#include "pch.h"
#include "CrashHandler.h"
#include "Console.h"
#include "GameApi.h"
#include "LuaHost.h"
#include "ScriptRunner.h"
#include "Symbols.h"
#include "WebUi.h"

#include <DbgHelp.h>
#include <TlHelp32.h>
#include <atomic>
#include <filesystem>
#include <fstream>
#include <mutex>
#include <set>
#include <sstream>
#include <vector>

#pragma comment(lib, "dbghelp.lib")

namespace fs = std::filesystem;

namespace
{
    PVOID g_veh = nullptr;
    LPTOP_LEVEL_EXCEPTION_FILTER g_prevFilter = nullptr;
    std::mutex g_reportMutex;
    std::set<uintptr_t> g_reported; // адреса, по которым отчёт уже есть (одно и то же место — один отчёт)
    std::atomic<int> g_reports = 0;
    std::atomic<int> g_dumps = 0;
    constexpr int kMaxReports = 12; // за запуск: сбой в цикле не должен забить диск
    constexpr int kMaxDumps = 3;
    bool g_symbolsReady = false;

    thread_local std::vector<std::string> t_scopes;
    thread_local int t_guard = 0;
    thread_local bool t_inHandler = false;

    // ---------- что за исключение ----------

    struct Known
    {
        DWORD code;
        const char* name;
        const char* hint;
    };

    const Known kKnown[] = {
        { EXCEPTION_ACCESS_VIOLATION, "ACCESS_VIOLATION",
          "обращение к памяти, которой нет (чаще всего — удалённый объект или неверный указатель)" },
        { EXCEPTION_BREAKPOINT, "BREAKPOINT (int3)",
          "сработала проверка: так падает CEF/Chromium при нарушении своих правил (поток, повторный запуск), "
          "либо встроенный assert" },
        { EXCEPTION_ILLEGAL_INSTRUCTION, "ILLEGAL_INSTRUCTION", "исполнение мусора: прыжок по испорченному адресу" },
        { EXCEPTION_PRIV_INSTRUCTION, "PRIVILEGED_INSTRUCTION", "исполнение мусора: прыжок по испорченному адресу" },
        { EXCEPTION_INT_DIVIDE_BY_ZERO, "INT_DIVIDE_BY_ZERO", "целочисленное деление на ноль" },
        { EXCEPTION_INT_OVERFLOW, "INT_OVERFLOW", "переполнение при целочисленной операции" },
        { EXCEPTION_STACK_OVERFLOW, "STACK_OVERFLOW", "переполнение стека: бесконечная рекурсия или огромный массив в стеке" },
        { EXCEPTION_IN_PAGE_ERROR, "IN_PAGE_ERROR", "не удалось подгрузить страницу памяти (диск, сетевой путь)" },
        { EXCEPTION_DATATYPE_MISALIGNMENT, "DATATYPE_MISALIGNMENT", "невыровненный доступ" },
        { 0xC0000374, "HEAP_CORRUPTION", "куча испорчена: запись за границу буфера или двойное освобождение" },
        { 0xC0000409, "STACK_BUFFER_OVERRUN", "запись за границу буфера в стеке (/GS) или fail-fast" },
        { 0xC0000602, "FAIL_FAST", "программа сама аварийно завершилась (fail-fast)" },
    };

    const Known* Find(DWORD code)
    {
        for (const Known& k : kKnown)
            if (k.code == code)
                return &k;
        return nullptr;
    }

    // ---------- пути и время ----------

    fs::path GameDir()
    {
        wchar_t exe[MAX_PATH];
        GetModuleFileNameW(nullptr, exe, MAX_PATH);
        return fs::path(exe).parent_path();
    }

    fs::path CrashDir()
    {
        fs::path dir = GameDir() / L"modloader" / L"crashes";
        std::error_code ec;
        fs::create_directories(dir, ec);
        return dir;
    }

    std::string Stamp(const char* fmt)
    {
        SYSTEMTIME t;
        GetLocalTime(&t);
        char buf[64];
        snprintf(buf, sizeof(buf), fmt, t.wYear, t.wMonth, t.wDay, t.wHour, t.wMinute, t.wSecond);
        return buf;
    }

    HMODULE SelfModule()
    {
        HMODULE self = nullptr;
        GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
                           reinterpret_cast<LPCWSTR>(&SelfModule), &self);
        return self;
    }

    // ---------- символы ----------

    // PDB модлоадера лежит рядом с DLL: для нашего кода будут имя функции, файл и строка.
    void InitSymbols()
    {
        if (g_symbolsReady)
            return;
        wchar_t dll[MAX_PATH];
        GetModuleFileNameW(SelfModule(), dll, MAX_PATH);
        std::string search = fs::path(dll).parent_path().string() + ";" + GameDir().string();
        SymSetOptions(SYMOPT_UNDNAME | SYMOPT_DEFERRED_LOADS | SYMOPT_LOAD_LINES | SYMOPT_FAIL_CRITICAL_ERRORS);
        g_symbolsReady = SymInitialize(GetCurrentProcess(), search.c_str(), TRUE) != FALSE;
    }

    std::string ModuleOf(uintptr_t address, uintptr_t* base)
    {
        HMODULE mod = nullptr;
        GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
                           reinterpret_cast<LPCWSTR>(address), &mod);
        *base = reinterpret_cast<uintptr_t>(mod);
        if (!mod)
            return "?";
        wchar_t path[MAX_PATH];
        GetModuleFileNameW(mod, path, MAX_PATH);
        return fs::path(path).filename().string();
    }

    // "cossacks.exe  sub_8638E0+0x1A  (engine)" / "Modloader For Cossacks 3.dll  LuaHost::Call+0x2C  core\LuaHost.cpp:195"
    std::string Describe(uintptr_t address)
    {
        char line[1024];
        uintptr_t base = 0;
        std::string module = ModuleOf(address, &base);

        if (Symbols::IsExeCode(address))
        {
            Symbols::Symbol sym = Symbols::Resolve(address);
            uintptr_t start = sym.key - GameApi::ImageBase + reinterpret_cast<uintptr_t>(GetModuleHandleW(nullptr));
            snprintf(line, sizeof(line), "%08X  %-14s %s+0x%X", static_cast<unsigned>(address), module.c_str(),
                     Symbols::Name(sym).c_str(), static_cast<unsigned>(address - start));
            return line;
        }

        if (g_symbolsReady)
        {
            alignas(SYMBOL_INFO) char buf[sizeof(SYMBOL_INFO) + 512];
            auto* info = reinterpret_cast<SYMBOL_INFO*>(buf);
            info->SizeOfStruct = sizeof(SYMBOL_INFO);
            info->MaxNameLen = 511;
            DWORD64 disp = 0;
            if (SymFromAddr(GetCurrentProcess(), address, &disp, info))
            {
                IMAGEHLP_LINE64 src = { sizeof(src) };
                DWORD lineDisp = 0;
                std::string where;
                if (SymGetLineFromAddr64(GetCurrentProcess(), address, &lineDisp, &src))
                {
                    std::string file = src.FileName;
                    size_t cut = file.find("core\\");
                    if (cut == std::string::npos)
                        cut = file.find("mods\\");
                    if (cut != std::string::npos)
                        file = file.substr(cut);
                    where = "  " + file + ":" + std::to_string(src.LineNumber);
                }
                snprintf(line, sizeof(line), "%08X  %-14s %s+0x%X%s", static_cast<unsigned>(address), module.c_str(),
                         info->Name, static_cast<unsigned>(disp), where.c_str());
                return line;
            }
        }

        Symbols::Symbol sym = Symbols::Resolve(address);
        snprintf(line, sizeof(line), "%08X  %-14s %s (+0x%X от начала модуля)", static_cast<unsigned>(address),
                 module.c_str(), sym.module ? Symbols::Name(sym).c_str() : "?", static_cast<unsigned>(address - base));
        return line;
    }

    // ---------- стек ----------

    std::vector<uintptr_t> Walk(const CONTEXT& ctx)
    {
        std::vector<uintptr_t> frames;
        CONTEXT copy = ctx;
        STACKFRAME64 frame = {};
        frame.AddrPC.Offset = ctx.Eip;
        frame.AddrPC.Mode = AddrModeFlat;
        frame.AddrFrame.Offset = ctx.Ebp;
        frame.AddrFrame.Mode = AddrModeFlat;
        frame.AddrStack.Offset = ctx.Esp;
        frame.AddrStack.Mode = AddrModeFlat;
        HANDLE process = GetCurrentProcess(), thread = GetCurrentThread();
        for (int i = 0; i < 64; ++i)
        {
            if (!StackWalk64(IMAGE_FILE_MACHINE_I386, process, thread, &frame, &copy, nullptr,
                             SymFunctionTableAccess64, SymGetModuleBase64, nullptr))
                break;
            if (!frame.AddrPC.Offset)
                break;
            frames.push_back(static_cast<uintptr_t>(frame.AddrPC.Offset));
        }
        return frames;
    }

    // Запасной путь: адреса возврата в коде игры, найденные прямо в стеке. Delphi-код не всегда
    // строит кадры, и честный обход может оборваться — а эти адреса показывают, откуда шли.
    std::vector<uintptr_t> ScanStack(const CONTEXT& ctx)
    {
        std::vector<uintptr_t> found;
        NT_TIB* tib = reinterpret_cast<NT_TIB*>(NtCurrentTeb());
        uintptr_t lo = ctx.Esp, hi = reinterpret_cast<uintptr_t>(tib->StackBase);
        if (lo < reinterpret_cast<uintptr_t>(tib->StackLimit) || lo >= hi)
            return found;
        for (uintptr_t slot = lo; slot + 4 <= hi && found.size() < 40; slot += 4)
        {
            uintptr_t value = *reinterpret_cast<uintptr_t*>(slot);
            if (Symbols::IsExeReturnAddress(value))
                found.push_back(value);
        }
        return found;
    }

    // ---------- части отчёта ----------

    bool CopyMemorySafe(void* dst, const void* src, size_t n)
    {
        __try
        {
            memcpy(dst, src, n);
            return true;
        }
        __except (EXCEPTION_EXECUTE_HANDLER)
        {
            return false;
        }
    }

    std::string Hex(const void* p, size_t n)
    {
        uint8_t bytes[64];
        n = (std::min)(n, sizeof(bytes));
        if (!CopyMemorySafe(bytes, p, n))
            return "(память недоступна)";
        std::string out;
        char b[4];
        for (size_t i = 0; i < n; ++i)
        {
            snprintf(b, sizeof(b), "%02X ", bytes[i]);
            out += b;
        }
        return out;
    }

    std::string ThreadName()
    {
        DWORD id = GetCurrentThreadId();
        if (id == ScriptRunner::GameThreadId())
            return "главный поток игры (скрипты, отрисовка, модлоадер, Lua, CEF)";
        PWSTR desc = nullptr;
        std::string name;
        if (SUCCEEDED(GetThreadDescription(GetCurrentThread(), &desc)) && desc && *desc)
        {
            int n = WideCharToMultiByte(CP_UTF8, 0, desc, -1, nullptr, 0, nullptr, nullptr);
            name.resize(n > 0 ? n - 1 : 0);
            WideCharToMultiByte(CP_UTF8, 0, desc, -1, name.data(), n, nullptr, nullptr);
        }
        if (desc)
            LocalFree(desc);
        return name.empty() ? "другой поток" : "поток \"" + name + "\"";
    }

    std::string AccessDetail(const EXCEPTION_RECORD& rec)
    {
        if (rec.ExceptionCode != EXCEPTION_ACCESS_VIOLATION || rec.NumberParameters < 2)
            return "";
        const char* op = rec.ExceptionInformation[0] == 0 ? "чтение" : rec.ExceptionInformation[0] == 1 ? "запись" : "исполнение";
        uintptr_t target = rec.ExceptionInformation[1];
        char buf[256];
        snprintf(buf, sizeof(buf), "%s по адресу %08X", op, static_cast<unsigned>(target));
        std::string out = buf;
        if (target < 0x10000)
        {
            snprintf(buf, sizeof(buf), "  <- почти ноль: обращение через пустой указатель (nil/nullptr), "
                                       "поле со смещением 0x%X", static_cast<unsigned>(target));
            out += buf;
        }
        return out;
    }

    void WriteDump(const fs::path& file, EXCEPTION_POINTERS* info)
    {
        HANDLE h = CreateFileW(file.c_str(), GENERIC_WRITE, 0, nullptr, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
        if (h == INVALID_HANDLE_VALUE)
            return;
        MINIDUMP_EXCEPTION_INFORMATION mei = { GetCurrentThreadId(), info, FALSE };
        MiniDumpWriteDump(GetCurrentProcess(), GetCurrentProcessId(), h,
                          static_cast<MINIDUMP_TYPE>(MiniDumpWithIndirectlyReferencedMemory | MiniDumpWithThreadInfo |
                                                     MiniDumpWithUnloadedModules | MiniDumpWithProcessThreadData),
                          info ? &mei : nullptr, nullptr, nullptr);
        CloseHandle(h);
    }

    // ---------- отчёт ----------

    std::string BuildReport(EXCEPTION_POINTERS* info, const char* reason, bool unhandled)
    {
        std::ostringstream r;
        r << "=== Cossacks 3 Modloader — отчёт о сбое ===\n";
        r << "Время:        " << Stamp("%04d-%02d-%02d %02d:%02d:%02d") << "\n";
        r << "Сборка:       " << __DATE__ << " " << __TIME__ << "\n";
        r << "Поток:        " << GetCurrentThreadId() << " — " << ThreadName() << "\n";

        if (info)
        {
            const EXCEPTION_RECORD& rec = *info->ExceptionRecord;
            const CONTEXT& ctx = *info->ContextRecord;
            const Known* k = Find(rec.ExceptionCode);
            char code[32];
            snprintf(code, sizeof(code), "%08X", static_cast<unsigned>(rec.ExceptionCode));
            r << "Исключение:   " << code << " " << (k ? k->name : "") << "\n";
            if (k)
                r << "Что это:      " << k->hint << "\n";
            if (std::string d = AccessDetail(rec); !d.empty())
                r << "Доступ:       " << d << "\n";
            r << "Где:          " << Describe(reinterpret_cast<uintptr_t>(rec.ExceptionAddress)) << "\n";
            r << (unhandled ? "Итог:         НЕ ОБРАБОТАНО — процесс завершается\n"
                            : "Итог:         первое появление; игра (Delphi) может перехватить его сама и продолжить,\n"
                              "              тогда на экране будет окно \"External exception\"/\"Access violation\"\n");

            r << "\n--- Что делал модлоадер в этом потоке (снаружи внутрь) ---\n";
            if (t_scopes.empty())
                r << "  (ничего из отмеченного — сбой в коде игры или стороннего модуля)\n";
            for (const std::string& s : t_scopes)
                r << "  > " << s << "\n";

            r << "\n--- Стек вызовов ---\n";
            int i = 0;
            for (uintptr_t pc : Walk(ctx))
                r << "  #" << (i < 10 ? "0" : "") << i++ << "  " << Describe(pc) << "\n";
            if (i == 0)
                r << "  (обход стека не удался)\n";

            r << "\n--- Адреса возврата в коде игры, найденные в стеке (если обход выше оборвался) ---\n";
            for (uintptr_t pc : ScanStack(ctx))
                r << "      " << Describe(pc) << "\n";

            char regs[512];
            snprintf(regs, sizeof(regs),
                     "  EAX=%08X EBX=%08X ECX=%08X EDX=%08X\n  ESI=%08X EDI=%08X EBP=%08X ESP=%08X\n  EIP=%08X EFLAGS=%08X\n",
                     static_cast<unsigned>(ctx.Eax), static_cast<unsigned>(ctx.Ebx), static_cast<unsigned>(ctx.Ecx),
                     static_cast<unsigned>(ctx.Edx), static_cast<unsigned>(ctx.Esi), static_cast<unsigned>(ctx.Edi),
                     static_cast<unsigned>(ctx.Ebp), static_cast<unsigned>(ctx.Esp), static_cast<unsigned>(ctx.Eip),
                     static_cast<unsigned>(ctx.EFlags));
            r << "\n--- Регистры ---\n" << regs;
            r << "  код у EIP:  " << Hex(reinterpret_cast<void*>(ctx.Eip), 16) << "\n";
        }
        else
        {
            r << "Причина:      " << (reason ? reason : "?") << "\n";
            r << "\n--- Что делал модлоадер в этом потоке ---\n";
            for (const std::string& s : t_scopes)
                r << "  > " << s << "\n";
        }

        r << "\n--- Моды ---\n";
        for (const auto& m : LuaHost::Mods())
        {
            const char* st = m.status == LuaHost::ModStatus::Loaded ? "загружен" :
                             m.status == LuaHost::ModStatus::Error ? "ОШИБКА" : "выключен";
            r << "  " << m.id << " " << m.version << " [" << m.sides << "] " << st;
            if (!m.error.empty())
                r << " — " << m.error;
            r << "\n";
        }

        r << "\n--- Браузер (CEF) ---\n  " << WebUi::Status() << "\n";

        r << "\n--- Последние строки лога ---\n";
        std::vector<std::string> recent = Console::Recent(60);
        if (recent.empty())
            r << "  (лог занят в момент сбоя — смотрите modloader.log)\n";
        for (const std::string& line : recent)
            r << "  " << line << "\n";

        r << "\n--- Модули ---\n";
        HANDLE snap = CreateToolhelp32Snapshot(TH32CS_SNAPMODULE, GetCurrentProcessId());
        if (snap != INVALID_HANDLE_VALUE)
        {
            MODULEENTRY32W me = { sizeof(me) };
            for (BOOL ok = Module32FirstW(snap, &me); ok; ok = Module32NextW(snap, &me))
            {
                char line[400];
                snprintf(line, sizeof(line), "  %08X-%08X  %ls\n", static_cast<unsigned>(reinterpret_cast<uintptr_t>(me.modBaseAddr)),
                         static_cast<unsigned>(reinterpret_cast<uintptr_t>(me.modBaseAddr) + me.modBaseSize), me.szModule);
                r << line;
            }
            CloseHandle(snap);
        }
        return r.str();
    }

    // Что считаем сбоем. Остальное (исключения Delphi 0EEDFADE, C++ E06D7363, отладочный вывод,
    // имена потоков) — нормальная работа программы, их кидают и ловят постоянно.
    bool IsFailure(DWORD code)
    {
        return Find(code) != nullptr;
    }

    std::string Report(EXCEPTION_POINTERS* info, const char* reason, bool unhandled)
    {
        std::lock_guard lock(g_reportMutex);
        InitSymbols();

        std::string codeName = "manual";
        if (info)
        {
            char c[16];
            snprintf(c, sizeof(c), "%08X", static_cast<unsigned>(info->ExceptionRecord->ExceptionCode));
            codeName = c;
        }
        std::string base = Stamp("%04d-%02d-%02d_%02d-%02d-%02d") + "_" + codeName;
        fs::path dir = CrashDir();
        fs::path txt = dir / (base + ".txt");

        std::string text = BuildReport(info, reason, unhandled);
        if (info && g_dumps < kMaxDumps)
        {
            ++g_dumps;
            fs::path dmp = dir / (base + ".dmp");
            WriteDump(dmp, info);
            text += "\nМинидамп: " + dmp.string() + " (открыть в Visual Studio / WinDbg вместе с PDB модлоадера)\n";
        }
        std::ofstream(txt, std::ios::binary) << text;
        return txt.string();
    }

    LONG CALLBACK OnException(EXCEPTION_POINTERS* info)
    {
        DWORD code = info->ExceptionRecord->ExceptionCode;
        if (!IsFailure(code) || t_inHandler)
            return EXCEPTION_CONTINUE_SEARCH;

        // Сбой внутри вызова натива под __try (NativeCall): ожидаем и обработан — Lua получит ошибку.
        if (t_guard > 0)
            return EXCEPTION_CONTINUE_SEARCH;

        uintptr_t where = reinterpret_cast<uintptr_t>(info->ExceptionRecord->ExceptionAddress);
        {
            std::lock_guard lock(g_reportMutex);
            if (g_reports >= kMaxReports || !g_reported.insert(where).second)
                return EXCEPTION_CONTINUE_SEARCH;
            ++g_reports;
        }

        t_inHandler = true;
        std::string path = Report(info, nullptr, false);
        const Known* k = Find(code);
        LOG_ERROR("CRASH %08X %s at %s — report: %s", static_cast<unsigned>(code), k ? k->name : "",
                  Describe(where).c_str(), path.c_str());
        t_inHandler = false;
        return EXCEPTION_CONTINUE_SEARCH; // решать, выживет ли игра, — не нам: пусть обработчики идут дальше
    }

    LONG WINAPI OnUnhandled(EXCEPTION_POINTERS* info)
    {
        if (!t_inHandler)
        {
            t_inHandler = true;
            std::string path = Report(info, nullptr, true);
            LOG_ERROR("FATAL %08X — the game is closing, report: %s",
                      static_cast<unsigned>(info->ExceptionRecord->ExceptionCode), path.c_str());
            t_inHandler = false;
        }
        return g_prevFilter ? g_prevFilter(info) : EXCEPTION_CONTINUE_SEARCH;
    }
}

void CrashHandler::Install()
{
    if (g_veh)
        return;
    g_veh = AddVectoredExceptionHandler(1, OnException);
    g_prevFilter = SetUnhandledExceptionFilter(OnUnhandled);
    LOG_INFO("Crash reports: %s", CrashDir().string().c_str());
}

void CrashHandler::Uninstall()
{
    if (g_veh)
    {
        RemoveVectoredExceptionHandler(g_veh);
        g_veh = nullptr;
    }
    SetUnhandledExceptionFilter(g_prevFilter);
    if (g_symbolsReady)
    {
        SymCleanup(GetCurrentProcess());
        g_symbolsReady = false;
    }
}

CrashHandler::Scope::Scope(std::string what)
{
    t_scopes.push_back(std::move(what));
}

CrashHandler::Scope::~Scope()
{
    if (!t_scopes.empty())
        t_scopes.pop_back();
}

CrashHandler::Guard::Guard() { ++t_guard; }
CrashHandler::Guard::~Guard() { --t_guard; }

std::string CrashHandler::ReportNow(const char* reason)
{
    return Report(nullptr, reason, false);
}
