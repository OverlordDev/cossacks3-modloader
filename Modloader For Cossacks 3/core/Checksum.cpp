#include "pch.h"
#include "Checksum.h"
#include "Console.h"
#include "Engine.h"
#include "GameApi.h"
#include "Hooks.h"
#include "ScriptRunner.h"

namespace
{
    constexpr uintptr_t VaChecksumNative = 0x6C3FF8; // function StateMachineLibraryCodeMD5Checksum(): string
    constexpr uintptr_t VaMd5            = 0x6BE484; // (eax = AnsiString, edx = var hex-результат)
    constexpr uintptr_t VaIsClass        = 0x40470C; // @IsClass(eax = obj, edx = class) -> al
    constexpr uintptr_t VaLStrAsg        = 0x405454; // @LStrAsg(eax = var dest, edx = src)
    constexpr uintptr_t VaTXDWSStateRef  = 0x8625E4; // переменная с классом TXDWSState

    constexpr uintptr_t OffProjectSmList = 0x4C; // TXProject -> список state machine
    constexpr uintptr_t OffEngineExtra   = 0x90; // TXDMScript -> строка, тоже входит в хеш

    using ChecksumFn = void(__stdcall*)(char** result);
    ChecksumFn oChecksum = nullptr;

    std::string Md5(const std::string& text)
    {
        void* fn = GameApi::Addr(VaMd5);
        GameApi::DelphiString src(text);
        const char* p = src.get();
        char* out = nullptr;
        char** pout = &out;
        __asm
        {
            mov eax, p
            mov edx, pout
            call fn
        }
        std::string result = out ? out : "";
        Engine::FreeString(pout);
        return result;
    }

    bool IsDwsState(uint8_t* obj)
    {
        void* fn = GameApi::Addr(VaIsClass);
        void* cls = *reinterpret_cast<void**>(GameApi::Addr(VaTXDWSStateRef));
        bool result;
        __asm
        {
            mov eax, obj
            mov edx, cls
            call fn
            mov result, al
        }
        return result;
    }

    bool IsOurLine(const std::string& line)
    {
        return line.find("'ML:") != std::string::npos; // все наши вставки вызывают DScriptSetgDbgString0('ML:...')
    }

    // Как sub_8646D8: MD5 от склейки MD5 текста (TStrings.GetTextStr: строки через CRLF) каждого состояния.
    // filter = false — точная копия алгоритма движка (для проверки, что реплика совпадает с оригиналом).
    std::string StateMachineHash(uint8_t* sm, bool filter)
    {
        std::string all;
        int count = Engine::StateCount(sm);
        for (int i = 0; i < count; ++i)
        {
            uint8_t* state = Engine::StateByIndex(sm, i);
            if (!state || !IsDwsState(state))
                continue;
            const char* name = *reinterpret_cast<const char**>(state + GameApi::Off::StateName);
            if (filter && name && strncmp(name, "ModLoader.", 10) == 0)
                continue;

            uint8_t* list = Engine::StateCode(state);
            std::string text;
            int lines = Engine::ListCount(list);
            for (int j = 0; j < lines; ++j)
            {
                std::string line = Engine::ListGet(list, j);
                if (!filter || !IsOurLine(line))
                    text += line + "\r\n";
            }
            all += Md5(text);
        }
        return Md5(all);
    }

    // Как sub_718138: MD5 от склейки хешей всех state machine проекта и MD5 строки движка.
    std::string ComputeChecksum(bool filter)
    {
        uint8_t* engine = Engine::ScriptEngine();
        uint8_t* project = *reinterpret_cast<uint8_t**>(engine + GameApi::Off::ScriptProject);
        uint8_t* list = *reinterpret_cast<uint8_t**>(project + OffProjectSmList);
        uint8_t* inner = *reinterpret_cast<uint8_t**>(list + 4);
        int count = *reinterpret_cast<int*>(inner + 0x0C);
        auto items = *reinterpret_cast<uint8_t***>(inner + 0x08);

        std::string all;
        for (int i = 0; i < count; ++i)
            all += StateMachineHash(items[i], filter);
        const char* extra = *reinterpret_cast<const char**>(engine + OffEngineExtra);
        all += Md5(extra ? extra : "");
        return Md5(all);
    }

    void AssignDelphiString(char** dest, const std::string& value)
    {
        void* fn = GameApi::Addr(VaLStrAsg);
        GameApi::DelphiString src(value); // литерал: LStrAsg сделает свою копию
        const char* p = src.get();
        __asm
        {
            mov eax, dest
            mov edx, p
            call fn
        }
    }

    void __stdcall hkChecksum(char** result)
    {
        AssignDelphiString(result, ComputeChecksum(true));
    }

    std::string EngineChecksum()
    {
        char* out = nullptr;
        oChecksum(&out);
        std::string result = out ? out : "";
        Engine::FreeString(&out);
        return result;
    }
}

bool Checksum::Install()
{
    return Hooks::Create("Script checksum", GameApi::Addr(VaChecksumNative), &hkChecksum, &oChecksum);
}

void Checksum::Print()
{
    ScriptRunner::RunOnGameThread([] {
        std::string stored;
        ScriptRunner::Call("ML_RET(gstring_checksumlong);", "", &stored);
        Console::Print("  engine (with modloader changes): %s", EngineChecksum().c_str());
        Console::Print("  replica of engine algorithm:     %s  (must equal the line above)", ComputeChecksum(false).c_str());
        Console::Print("  vanilla (reported to lobby):     %s", ComputeChecksum(true).c_str());
        Console::Print("  stored by game (last menu):      %s", stored.c_str());
    });
}
