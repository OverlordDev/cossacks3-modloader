#include "pch.h"
#include "Symbols.h"
#include "GameApi.h"

#include <algorithm>
#include <unordered_map>
#include <mutex>

namespace
{
    struct Function
    {
        uint32_t start;
        uint32_t end;
        const char* name;
    };

    const Function kFunctions[] = {
#include "FunctionsTable.inc"
    };

    const uint8_t* ExeBase()
    {
        return reinterpret_cast<const uint8_t*>(GetModuleHandleW(nullptr));
    }

    const IMAGE_NT_HEADERS* NtHeaders(const uint8_t* base)
    {
        return reinterpret_cast<const IMAGE_NT_HEADERS*>(base + reinterpret_cast<const IMAGE_DOS_HEADER*>(base)->e_lfanew);
    }

    // Диапазон исполняемых секций exe.
    struct CodeRange
    {
        uintptr_t lo = 0, hi = 0;
        CodeRange()
        {
            const uint8_t* base = ExeBase();
            const IMAGE_NT_HEADERS* nt = NtHeaders(base);
            const IMAGE_SECTION_HEADER* sec = IMAGE_FIRST_SECTION(nt);
            for (WORD i = 0; i < nt->FileHeader.NumberOfSections; ++i, ++sec)
            {
                if (!(sec->Characteristics & IMAGE_SCN_MEM_EXECUTE))
                    continue;
                uintptr_t s = reinterpret_cast<uintptr_t>(base) + sec->VirtualAddress;
                uintptr_t e = s + sec->Misc.VirtualSize;
                lo = lo ? std::min(lo, s) : s;
                hi = std::max(hi, e);
            }
        }
    };
    const CodeRange g_code;

    const std::unordered_map<uintptr_t, std::string_view>& NativeNames()
    {
        static std::unordered_map<uintptr_t, std::string_view> map;
        static std::once_flag once;
        std::call_once(once, [] {
            for (const auto& n : GameApi::Natives())
                map.emplace(n.va, GameApi::NameOf(n.decl));
        });
        return map;
    }

    // Экспорты модуля, отсортированные по адресу.
    struct Exports
    {
        std::vector<std::pair<uintptr_t, std::string>> list;
    };

    const Exports& ModuleExports(uintptr_t module)
    {
        static std::unordered_map<uintptr_t, Exports> cache;
        static std::mutex mutex;
        std::lock_guard lock(mutex);

        auto [it, inserted] = cache.try_emplace(module);
        if (!inserted)
            return it->second;

        auto base = reinterpret_cast<const uint8_t*>(module);
        const auto& dir = NtHeaders(base)->OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_EXPORT];
        if (!dir.VirtualAddress)
            return it->second;

        auto exp = reinterpret_cast<const IMAGE_EXPORT_DIRECTORY*>(base + dir.VirtualAddress);
        auto funcs = reinterpret_cast<const DWORD*>(base + exp->AddressOfFunctions);
        auto names = reinterpret_cast<const DWORD*>(base + exp->AddressOfNames);
        auto ords = reinterpret_cast<const WORD*>(base + exp->AddressOfNameOrdinals);
        for (DWORD i = 0; i < exp->NumberOfNames; ++i)
        {
            DWORD rva = funcs[ords[i]];
            if (rva >= dir.VirtualAddress && rva < dir.VirtualAddress + dir.Size)
                continue; // форвардер
            it->second.list.emplace_back(module + rva, reinterpret_cast<const char*>(base + names[i]));
        }
        std::sort(it->second.list.begin(), it->second.list.end());
        return it->second;
    }
}

bool Symbols::IsExeCode(uintptr_t address)
{
    return address >= g_code.lo && address < g_code.hi;
}

bool Symbols::IsExeReturnAddress(uintptr_t a)
{
    // Код exe читается свободно; a-7 тоже внутри образа, т.к. секция кода не первая страница.
    if (!IsExeCode(a) || a - 7 < g_code.lo)
        return false;
    auto p = reinterpret_cast<const uint8_t*>(a);
    if (p[-5] == 0xE8) return true;                                                   // call rel32
    if (p[-2] == 0xFF && (p[-1] & 0x38) == 0x10)                                      // FF /2, 2 байта:
    {
        uint8_t mod = p[-1] & 0xC0, rm = p[-1] & 7;
        if (mod == 0xC0 || (mod == 0 && rm != 4 && rm != 5)) return true;              // call reg / call [reg]
    }
    if (p[-3] == 0xFF && (p[-2] & 0xF8) == 0x50 && (p[-2] & 7) != 4) return true;     // call [reg+d8]
    if (p[-3] == 0xFF && p[-2] == 0x14) return true;                                  // call [sib]
    if (p[-4] == 0xFF && p[-3] == 0x54) return true;                                  // call [sib+d8]
    if (p[-6] == 0xFF && (p[-5] == 0x15 || ((p[-5] & 0xF8) == 0x90 && (p[-5] & 7) != 4))) return true; // call [d32] / [reg+d32]
    if (p[-7] == 0xFF && p[-6] == 0x94) return true;                                  // call [sib+d32]
    return false;
}

Symbols::Symbol Symbols::Resolve(uintptr_t address)
{
    static const uintptr_t base = reinterpret_cast<uintptr_t>(ExeBase());
    static const uintptr_t size = NtHeaders(ExeBase())->OptionalHeader.SizeOfImage;

    if (address - base < size)
    {
        uint32_t va = static_cast<uint32_t>(address - base + GameApi::ImageBase);
        auto it = std::upper_bound(std::begin(kFunctions), std::end(kFunctions), va,
                                   [](uint32_t v, const Function& f) { return v < f.start; });
        if (it != std::begin(kFunctions) && va < (it - 1)->end)
            return { (it - 1)->start, 0, true };
        return { va, 0, true }; // вне известных функций
    }

    HMODULE mod = nullptr;
    GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
                       reinterpret_cast<LPCWSTR>(address), &mod);
    auto module = reinterpret_cast<uintptr_t>(mod);
    if (!module)
        return {};

    // Ближайший экспорт снизу; слишком далёкий (> 64 КБ) — скорее внутренняя функция, группируем по модулю.
    const auto& ex = ModuleExports(module).list;
    auto it = std::upper_bound(ex.begin(), ex.end(), address, [](uintptr_t a, const auto& e) { return a < e.first; });
    if (it != ex.begin() && address - (it - 1)->first < 0x10000)
        return { (it - 1)->first, module, false };
    return { module, module, false };
}

std::string Symbols::ModuleName(uintptr_t module)
{
    if (!module)
        return "cossacks.exe";
    wchar_t path[MAX_PATH];
    GetModuleFileNameW(reinterpret_cast<HMODULE>(module), path, MAX_PATH);
    const wchar_t* file = wcsrchr(path, L'\\');
    char buf[MAX_PATH];
    WideCharToMultiByte(CP_UTF8, 0, file ? file + 1 : path, -1, buf, sizeof(buf), nullptr, nullptr);
    return buf;
}

std::string Symbols::Name(const Symbol& sym)
{
    char buf[512];
    if (!sym.inExe)
    {
        if (!sym.module)
            return "<unknown>";
        std::string mod = ModuleName(sym.module);
        if (sym.key == sym.module)
            return "[" + mod + "]";
        const auto& ex = ModuleExports(sym.module).list;
        auto it = std::lower_bound(ex.begin(), ex.end(), sym.key, [](const auto& e, uintptr_t a) { return e.first < a; });
        return "[" + mod + "] " + (it != ex.end() && it->first == sym.key ? it->second : "?");
    }

    const auto& natives = NativeNames();
    if (auto it = natives.find(sym.key); it != natives.end())
        return "native " + std::string(it->second);

    auto it = std::lower_bound(std::begin(kFunctions), std::end(kFunctions), static_cast<uint32_t>(sym.key),
                               [](const Function& f, uint32_t v) { return f.start < v; });
    if (it != std::end(kFunctions) && it->start == sym.key && *it->name)
        return it->name;

    snprintf(buf, sizeof(buf), "sub_%X", static_cast<unsigned>(sym.key));
    return buf;
}
