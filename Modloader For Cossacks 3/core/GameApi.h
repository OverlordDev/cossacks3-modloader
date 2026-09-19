#pragma once

#include <span>
#include <string_view>

// Нативы скриптового API cossacks.exe (build 2.2.3, 32-bit Delphi, base 0x400000).
// Адреса найдены по регистрации: `mov ecx, offset native` + `mov edx, offset "<объявление>"`.
// Все нативы — __stdcall, аргументы в обычном порядке, String = Delphi AnsiString (char* на данные).
// Полный список — NativesTable.inc (генерируется tools/ida_export_natives.py).
namespace GameApi
{
    constexpr uintptr_t ImageBase = 0x400000;

    inline void* Addr(uintptr_t va)
    {
        return reinterpret_cast<void*>(reinterpret_cast<uintptr_t>(GetModuleHandleW(nullptr)) + (va - ImageBase));
    }

    namespace Va
    {
        constexpr uintptr_t Log                          = 0x60DBD8; // procedure Log(const msg: String)
        constexpr uintptr_t TimeLog                      = 0x60DC98; // procedure TimeLog(const msg: String)
        constexpr uintptr_t GetBuildVersion              = 0x60EADC; // function GetBuildVersion: String
        constexpr uintptr_t StateMachineGetGUISMHandle   = 0x6C4B00; // function StateMachineGetGUISMHandle: Integer
        constexpr uintptr_t StateMachineStateAdd         = 0x6C3A50; // procedure (handle; state: String) — создаёт state без поиска
        constexpr uintptr_t StateMachineStateAddCodeLine = 0x6C3A80; // procedure (handle; state, codeline: String) — создаёт state при отсутствии
        constexpr uintptr_t StateMachineExecuteState     = 0x6C3C08; // procedure (handle; state: String; taghandle: Integer) — компилирует при первом запуске

        // Внутренности скриптового движка (Delphi register: eax, edx, ecx).
        constexpr uintptr_t ScriptEngine        = 0x705944; // TXDMScript singleton -> eax
        constexpr uintptr_t SMStateIndexByName  = 0x863C3C; // (eax = TXStateMachine, edx = name) -> index или -1
        constexpr uintptr_t SMStateByIndex      = 0x863AA0; // (eax = TXStateMachine, edx = index) -> TXDWSState
        constexpr uintptr_t SMExecuteState      = 0x8638E0; // (eax = sm, edx = name) — оригинал: сетевой гейт sub_732414 + запуск

        // Внутренние логгеры движка: Delphi register (eax = msg, edx = var-результат), одинаковой формы.
        constexpr uintptr_t CoreLog    = 0x8CE9BC; // тег LOG    — script Log
        constexpr uintptr_t CoreErr    = 0x8CEA24; // тег ERR    — script ErrorLog
        constexpr uintptr_t CoreInfo   = 0x8CE8D0; // тег INFO
        constexpr uintptr_t CoreNormal = 0x8CEBEC; // тег NORMAL
        constexpr uintptr_t CoreError  = 0x8CECB0; // тег ERROR  — ошибки движка, в т.ч. компиляции скриптов
    }

    namespace Off
    {
        constexpr uintptr_t ScriptCurrentSM = 0x50;  // TXDMScript: исполняемая сейчас state machine
        constexpr uintptr_t ScriptProject   = 0x4C;  // TXDMScript -> TXProject
        constexpr uintptr_t ProjectNetGate  = 0x6C;  // TXProject -> менеджер сети/записи (гейт исполнения)
        constexpr uintptr_t NetGateMode     = 0xF1;  // byte: 0 — офлайн, 1/3 — сеть/запись
        constexpr uintptr_t StateHasErrors  = 0x10;  // TXDWSState: byte, ошибки компиляции
        constexpr uintptr_t StateCompiled   = 0x11;  // TXDWSState: byte, скомпилирован
        constexpr uintptr_t StateVmtExecute = 0x08;  // TXDWSState VMT: Execute (компилирует при необходимости)
    }

    using LogFn               = void(__stdcall*)(const char* msg);
    using GetStringFn         = void(__stdcall*)(char** result); // результат через скрытый var-параметр
    using GetIntFn            = int(__stdcall*)();
    using StateAddFn          = void(__stdcall*)(int handle, const char* state);
    using StateAddCodeLineFn  =void(__stdcall*)(int handle, const char* state, const char* codeline);
    using StateExecuteStateFn = void(__stdcall*)(int handle, const char* state, int taghandle);

    struct Native
    {
        uintptr_t va;
        const char* decl; // "procedure Log(const msg: String)"
    };

    std::span<const Native> Natives();
    std::string_view NameOf(std::string_view decl); // "procedure Log(...)" -> "Log"

    // Строка в формате Delphi AnsiString-литерала (refcount = -1): игра не освобождает её,
    // а при присваивании (LStrAsg) делает свою копию.
    class DelphiString
    {
    public:
        explicit DelphiString(const std::string& s)
        {
            m_buf.resize(8 + s.size() + 1);
            const int32_t hdr[2] = { -1, static_cast<int32_t>(s.size()) };
            memcpy(m_buf.data(), hdr, sizeof(hdr));
            memcpy(m_buf.data() + 8, s.c_str(), s.size() + 1);
        }

        // Пустая строка в Delphi — nil.
        const char* get() const { return m_buf.size() > 9 ? m_buf.data() + 8 : nullptr; }

    private:
        std::vector<char> m_buf;
    };
}
