#include "pch.h"
#include "Engine.h"
#include "Console.h"
#include "GameApi.h"

namespace
{
    constexpr uintptr_t VaLStrClr = 0x405400; // @LStrClr(var S) — eax = &S

    // TStringList VMT (Delphi 7 Classes): смещения виртуальных методов.
    constexpr uintptr_t VmtListGet     = 0x0C; // (eax = self, edx = index, ecx = &result)
    constexpr uintptr_t VmtListCount   = 0x14; // (eax = self) -> eax
    constexpr uintptr_t VmtListDelete  = 0x48; // (eax = self, edx = index)
    constexpr uintptr_t VmtListIndexOf = 0x54; // (eax = self, edx = S) -> eax
    constexpr uintptr_t VmtListInsert  = 0x60; // (eax = self, edx = index, ecx = S)

    // TXDWSState VMT.
    constexpr uintptr_t VmtStateReset   = 0x1C; // освободить скомпилированную программу, сбросить флаги
    constexpr uintptr_t VmtStateCompile = 0x20;
    constexpr uintptr_t StateCodeList   = 0x20; // поле: TStringList с кодом

    void* Virtual(void* obj, uintptr_t offset)
    {
        return *reinterpret_cast<void**>(*reinterpret_cast<uint8_t**>(obj) + offset);
    }

    void FreeDelphiString(char** s)
    {
        void* fn = GameApi::Addr(VaLStrClr);
        __asm
        {
            mov eax, s
            call fn
        }
    }
}

uint8_t* Engine::ScriptEngine()
{
    void* fn = GameApi::Addr(GameApi::Va::ScriptEngine);
    uint8_t* result;
    __asm
    {
        call fn
        mov result, eax
    }
    return result;
}

uint8_t* Engine::ScriptEngineIfCreated()
{
    return *reinterpret_cast<uint8_t**>(GameApi::Addr(GameApi::Va::ScriptEngineVar));
}

bool Engine::Ready()
{
    uint8_t* engine = ScriptEngineIfCreated();
    return engine && *reinterpret_cast<uint8_t**>(engine + GameApi::Off::ScriptProject);
}

uint8_t* Engine::GuiStateMachine()
{
    auto getGuiSm = reinterpret_cast<GameApi::GetIntFn>(GameApi::Addr(GameApi::Va::StateMachineGetGUISMHandle));
    return reinterpret_cast<uint8_t*>(getGuiSm());
}

int Engine::StateIndex(uint8_t* sm, const char* delphiName)
{
    void* fn = GameApi::Addr(GameApi::Va::SMStateIndexByName);
    int result;
    __asm
    {
        mov eax, sm
        mov edx, delphiName
        call fn
        mov result, eax
    }
    return result;
}

uint8_t* Engine::StateByIndex(uint8_t* sm, int index)
{
    void* fn = GameApi::Addr(GameApi::Va::SMStateByIndex);
    uint8_t* result;
    __asm
    {
        mov eax, sm
        mov edx, index
        call fn
        mov result, eax
    }
    return result;
}

int Engine::StateCount(uint8_t* sm)
{
    void* fn = GameApi::Addr(GameApi::Va::SMStateCount);
    int result;
    __asm
    {
        mov eax, sm
        call fn
        mov result, eax
    }
    return result;
}

// Свой перебор вместо движкового IndexOfState: тот пишет в лог ошибку, если состояния нет,
// а нам «нет» — нормальный ответ (например, кэш после перезагрузки GUI).
uint8_t* Engine::FindState(uint8_t* sm, const std::string& name)
{
    if (!sm)
        return nullptr;
    int count = StateCount(sm);
    for (int i = 0; i < count; ++i)
    {
        uint8_t* state = StateByIndex(sm, i);
        const char* stateName = state ? *reinterpret_cast<const char**>(state + GameApi::Off::StateName) : nullptr;
        if (stateName && _stricmp(stateName, name.c_str()) == 0)
            return state;
    }
    return nullptr;
}

void Engine::StateReset(uint8_t* state)
{
    void* fn = Virtual(state, VmtStateReset);
    __asm
    {
        mov eax, state
        call fn
    }
}

namespace
{
    bool CompileSeh(uint8_t** currentSm, uint8_t* sm, uint8_t* state)
    {
        void* fn = Virtual(state, VmtStateCompile);
        uint8_t* saved = *currentSm;
        bool ok = false;
        __try
        {
            *currentSm = sm;
            __asm
            {
                mov eax, state
                call fn
            }
            ok = true;
        }
        __except (EXCEPTION_EXECUTE_HANDLER)
        {
        }
        *currentSm = saved;
        return ok;
    }
}

bool Engine::StateCompileSafe(uint8_t* sm, uint8_t* state)
{
    auto currentSm = reinterpret_cast<uint8_t**>(ScriptEngine() + GameApi::Off::ScriptCurrentSM);
    return CompileSeh(currentSm, sm, state) && !state[GameApi::Off::StateHasErrors];
}

void Engine::DumpState(const std::string& name, int maxLines)
{
    uint8_t* state = FindState(GuiStateMachine(), name);
    if (!state)
    {
        Console::Print("  GUI state '%s' not found", name.c_str());
        return;
    }
    uint8_t* list = StateCode(state);
    int count = ListCount(list);
    Console::Print("  state '%s' @%p: %d lines, compiled=%d, errors=%d", name.c_str(), state, count,
                   state[GameApi::Off::StateCompiled], state[GameApi::Off::StateHasErrors]);
    for (int i = 0; i < count && i < maxLines; ++i)
        Console::Print("  %4d | %s", i + 1, ListGet(list, i).c_str());
    if (count > maxLines)
        Console::Print("  ... %d more lines", count - maxLines);
}

uint8_t* Engine::StateCode(uint8_t* state)
{
    return *reinterpret_cast<uint8_t**>(state + StateCodeList);
}

int Engine::ListCount(uint8_t* list)
{
    void* fn = Virtual(list, VmtListCount);
    int result;
    __asm
    {
        mov eax, list
        call fn
        mov result, eax
    }
    return result;
}

std::string Engine::ListGet(uint8_t* list, int index)
{
    void* fn = Virtual(list, VmtListGet);
    char* s = nullptr;
    char** ps = &s;
    __asm
    {
        mov eax, list
        mov edx, index
        mov ecx, ps
        call fn
    }
    std::string result = s ? s : "";
    FreeDelphiString(ps);
    return result;
}

void Engine::FreeString(char** s)
{
    FreeDelphiString(s);
}

int Engine::ListIndexOf(uint8_t* list, const std::string& s)
{
    void* fn = Virtual(list, VmtListIndexOf);
    GameApi::DelphiString ds(s);
    const char* p = ds.get();
    int result;
    __asm
    {
        mov eax, list
        mov edx, p
        call fn
        mov result, eax
    }
    return result;
}

void Engine::ListInsert(uint8_t* list, int index, const std::string& s)
{
    void* fn = Virtual(list, VmtListInsert);
    GameApi::DelphiString ds(s); // литерал (refcount -1) — список сделает свою копию
    const char* p = ds.get();
    __asm
    {
        mov eax, list
        mov edx, index
        mov ecx, p
        call fn
    }
}

void Engine::ListDelete(uint8_t* list, int index)
{
    void* fn = Virtual(list, VmtListDelete);
    __asm
    {
        mov eax, list
        mov edx, index
        call fn
    }
}
