#include "pch.h"
#include "Hooks.h"
#include "Console.h"

bool Hooks::Init()
{
    MH_STATUS s = MH_Initialize();
    if (s != MH_OK)
    {
        LOG_ERROR("MH_Initialize failed: %s", MH_StatusToString(s));
        return false;
    }
    LOG_INFO("MinHook initialized");
    return true;
}

void Hooks::Shutdown()
{
    MH_DisableHook(MH_ALL_HOOKS);
    MH_Uninitialize();
}

bool Hooks::CreateRaw(const char* name, void* target, void* detour, void** original)
{
    MH_STATUS s = MH_CreateHook(target, detour, original);
    if (s != MH_OK)
    {
        LOG_ERROR("Hook '%s' create failed: %s", name, MH_StatusToString(s));
        return false;
    }
    s = MH_EnableHook(target);
    if (s != MH_OK)
    {
        LOG_ERROR("Hook '%s' enable failed: %s", name, MH_StatusToString(s));
        return false;
    }
    LOG_INFO("Hook '%s' installed at %p", name, target);
    return true;
}
