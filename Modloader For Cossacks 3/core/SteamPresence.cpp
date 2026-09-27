#include "pch.h"
#include "CrashHandler.h"
#include "Console.h"
#include "SteamPresence.h"

#include <windows.h>
#include <atomic>

// Проверенные exports steam_api.dll игры (dumpbin, 32-bit):
//   SteamAPI_ISteamFriends_SetRichPresence / ClearRichPresence / SetPlayedWith,
//   SteamAPI_ISteamUser_GetSteamID, SteamInternal_CreateInterface.
// Версионированных SteamAPI_SteamFriends_vXXX в этой сборке НЕТ.
//
// ВАЖНО (проверено 2026-09-26):
// - маршрут ISteamClient + pipe игры + GetISteamFriends падает в steamclient — УДАЛЁН;
// - фабрика steam_api игры НЕ знает Friends (строк версий нет в бинарнике) —
//   CreateInterface берём из steamclient.dll (там есть SteamFriends018).
// Каждый вызов Steam идёт под CrashHandler::Guard (тихо для VEH) + __try,
// после ПЕРВОГО сбоя мост навсегда отключается (g_dead): игра важнее статуса.
//
// Правило MSVC: __try нельзя в функции с деструкторами (C2712) — поэтому весь
// SEH живёт в статических C-хелперах без объектов, а Guard — снаружи.

namespace
{
    using CreateInterfaceFn = void*(__cdecl*)(const char* version);
    using GetHandleFn = int(__cdecl*)();
    using GetFriendsFn = void*(__cdecl*)(void* client, int user, int pipe);
    using SetPresenceFn = bool(__cdecl*)(void* friends, const char* key, const char* value);
    using ClearPresenceFn = void(__cdecl*)(void* friends);
    using PlayedWithFn = bool(__cdecl*)(void* friends, unsigned long long steamId);
    using GetSteamIdFn = unsigned long long(__cdecl*)(void* user);

    std::atomic<bool> g_dead{ false };   // Steam тронули и он упал — больше не трогаем
    void* g_friends = nullptr;           // закэшированный ISteamFriends (синглтон версии)
    void* g_user = nullptr;              // закэшированный ISteamUser (SteamUser019)
    bool g_probed = false;

    HMODULE Dll()
    {
        return GetModuleHandleW(L"steam_api.dll"); // без LoadLibrary: DLL уже у игры
    }

    template <typename T>
    T Proc(HMODULE dll, const char* name)
    {
        return dll ? reinterpret_cast<T>(GetProcAddress(dll, name)) : nullptr;
    }

    // Фабрика интерфейсов: сначала steamclient.dll (там есть SteamFriends018,
    // в steam_api игры строк версий Friends нет вообще — проверено 2026-09-26),
    // затем фабрика steam_api (запасной путь). Только GetModuleHandle, без LoadLibrary.
    CreateInterfaceFn Factory()
    {
        static CreateInterfaceFn cached = nullptr;
        static bool done = false;
        if (done)
            return cached;
        done = true;
        for (const wchar_t* dll : { L"steamclient.dll", L"steam_api.dll", L"steamclient64.dll" })
        {
            HMODULE mod = GetModuleHandleW(dll);
            auto create = Proc<CreateInterfaceFn>(mod, "CreateInterface");
            if (!create)
                continue;
            // Фабрика должна хотя бы отвечать (тихий вызов без аргументов версии
            // делать нельзя — сразу пробуем целевой интерфейс ниже).
            cached = create;
            break;
        }
        return cached;
    }

    // --- тихие SEH-хелперы (никаких объектов C++ внутри!) ---

    static void* TryCreate(CreateInterfaceFn create, const char* version)
    {
        void* p = nullptr;
        __try { p = create(version); }
        __except (EXCEPTION_EXECUTE_HANDLER) { p = nullptr; }
        return p;
    }

    static bool TrySet(SetPresenceFn fn, void* friends, const char* key, const char* value)
    {
        bool ok = false;
        __try { ok = fn(friends, key, value); }
        __except (EXCEPTION_EXECUTE_HANDLER) { ok = false; }
        return ok;
    }

    static void TryClear(ClearPresenceFn fn, void* friends)
    {
        __try { fn(friends); }
        __except (EXCEPTION_EXECUTE_HANDLER) { }
    }

    static bool TryPlayedWith(PlayedWithFn fn, void* friends, unsigned long long id)
    {
        bool ok = false;
        __try { ok = fn(friends, id); }
        __except (EXCEPTION_EXECUTE_HANDLER) { ok = false; }
        return ok;
    }

    static unsigned long long TryGetId(GetSteamIdFn fn, void* user)
    {
        unsigned long long id = 0;
        __try { id = fn(user); }
        __except (EXCEPTION_EXECUTE_HANDLER) { id = 0; }
        return id;
    }

    static void TryHandles(GetHandleFn getUser, GetHandleFn getPipe, int* user, int* pipe)
    {
        __try { *user = getUser(); *pipe = getPipe(); }
        __except (EXCEPTION_EXECUTE_HANDLER) { *user = *pipe = 0; }
    }

    static void* TryGetFriends(GetFriendsFn fn, void* client, int a, int b)
    {
        void* p = nullptr;
        __try { p = fn(client, a, b); }
        __except (EXCEPTION_EXECUTE_HANDLER) { p = nullptr; }
        return p;
    }

    // Однократный тихий пробник: найти рабочую версию Friends/User.
    // Вызывать только из главного потока игры.
    void Probe()
    {
        if (g_probed || g_dead.load())
            return;
        g_probed = true;
        CrashHandler::Guard guard; // сбой здесь — ожидаем: без отчёта в crashes/
        HMODULE dll = Dll();
        if (!dll)
            return;
        auto create = Factory();
        auto setFn = Proc<SetPresenceFn>(dll, "SteamAPI_ISteamFriends_SetRichPresence");
        auto clearFn = Proc<ClearPresenceFn>(dll, "SteamAPI_ISteamFriends_ClearRichPresence");
        if (!create || !setFn || !clearFn)
        {
            LOG_WARN("[steam] probe: missing exports (create=%d set=%d clear=%d)",
                     create != nullptr, setFn != nullptr, clearFn != nullptr);
            return;
        }
        // 018 есть в steamclient.dll, 015-017 — классика. Порядок: новые первые.
        static const char* kVersions[] = { "SteamFriends018", "SteamFriends017",
                                           "SteamFriends016", "SteamFriends015" };
        for (const char* v : kVersions)
        {
            void* friends = TryCreate(create, v);
            if (!friends)
            {
                LOG_INFO("[steam] probe: %s not registered", v);
                continue;
            }
            if (TrySet(setFn, friends, "ml_probe", "1"))
            {
                TryClear(clearFn, friends);
                g_friends = friends;
                LOG_INFO("[steam] Rich Presence ready (%s, direct)", v);
                break;
            }
            LOG_WARN("[steam] probe: %s object ok, SetRichPresence refused", v);
        }
        if (g_friends)
            return;
        // Прямых нет — матрица ISteamClient: версии 017..023 x порядок (user,pipe).
        // Пайп принадлежит сессии игры; версия её клиента неизвестна, перебираем тихо.
        auto getUser = Proc<GetHandleFn>(dll, "SteamAPI_GetHSteamUser");
        auto getPipe = Proc<GetHandleFn>(dll, "SteamAPI_GetHSteamPipe");
        auto getFriends = Proc<GetFriendsFn>(dll, "SteamAPI_ISteamClient_GetISteamFriends");
        if (!getUser || !getPipe || !getFriends)
        {
            LOG_INFO("[steam] probe: no client-route exports");
        }
        else
        {
            static const char* kClients[] = { "SteamClient023", "SteamClient022", "SteamClient021",
                                              "SteamClient020", "SteamClient019", "SteamClient018",
                                              "SteamClient017" };
            for (const char* cv : kClients)
            {
                if (g_friends)
                    break;
                void* client = TryCreate(create, cv);
                if (!client)
                    continue;
                // user/pipe читаем один раз (тихо): 0 = Steam не готов — дальше не идём.
                int user = 0, pipe = 0;
                TryHandles(getUser, getPipe, &user, &pipe);
                if (!user || !pipe)
                {
                    LOG_INFO("[steam] probe: steam handles not ready");
                    break;
                }
                for (int swap = 0; swap < 2 && !g_friends; ++swap)
                {
                    void* friends = TryGetFriends(getFriends, client,
                                                  swap ? pipe : user, swap ? user : pipe);
                    if (friends && TrySet(setFn, friends, "ml_probe", "1"))
                    {
                        TryClear(clearFn, friends);
                        g_friends = friends;
                        LOG_INFO("[steam] Rich Presence ready (%s friends via %s, %s)",
                                 "direct", cv, swap ? "swapped" : "ordered");
                    }
                }
            }
            if (!g_friends)
                LOG_INFO("[steam] probe: client matrix exhausted, no match");
        }
        if (!g_friends)
        {
            g_dead.store(true); // тихий отказ: дальше только unavailable, без касаний Steam
            LOG_WARN("[steam] no working ISteamFriends — presence disabled (game is fine)");
            return;
        }
        // SteamUser019 есть в бинарнике — свой SteamID тем же тихим путём.
        g_user = TryCreate(create, "SteamUser019");
    }

    // false от Steam (лимиты, оффлайн) — мягко, без dead: каждый вызов и так
    // тихий (Guard + __try), игра продолжает работать.
}

namespace SteamPresence
{
    std::string Status()
    {
        if (g_dead.load())
            return "unavailable";
        if (!Dll())
            return "no_dll";
        Probe();
        return g_friends ? "ok" : "no_friends";
    }

    bool Available()
    {
        if (g_dead.load() || !Dll())
            return false;
        Probe();
        return g_friends != nullptr;
    }

    bool Set(const std::string& key, const std::string& value)
    {
        if (key.empty() || key.size() > 256 || value.size() > 1024)
            return false;
        if (!Available())
            return false;
        auto fn = Proc<SetPresenceFn>(Dll(), "SteamAPI_ISteamFriends_SetRichPresence");
        if (!fn || !g_friends)
            return false;
        CrashHandler::Guard guard;
        return TrySet(fn, g_friends, key.c_str(), value.c_str());
    }

    bool Clear()
    {
        auto fn = Proc<ClearPresenceFn>(Dll(), "SteamAPI_ISteamFriends_ClearRichPresence");
        if (!fn || !Available() || !g_friends)
            return false;
        CrashHandler::Guard guard;
        TryClear(fn, g_friends);
        return true;
    }

    bool PlayedWith(unsigned long long steamId)
    {
        if (!steamId)
            return false;
        auto fn = Proc<PlayedWithFn>(Dll(), "SteamAPI_ISteamFriends_SetPlayedWith");
        if (!fn || !Available() || !g_friends)
            return false;
        CrashHandler::Guard guard;
        return TryPlayedWith(fn, g_friends, steamId);
    }

    std::string MyId()
    {
        auto getIdFn = Proc<GetSteamIdFn>(Dll(), "SteamAPI_ISteamUser_GetSteamID");
        if (!getIdFn || !Available() || !g_user)
            return {};
        CrashHandler::Guard guard;
        unsigned long long id = TryGetId(getIdFn, g_user);
        return id ? std::to_string(id) : std::string{};
    }

    void Shutdown()
    {
        // Best-effort уборка статуса. DLL НЕ выгружаем — она игры.
        if (!g_dead.load() && g_friends)
            Clear();
        g_friends = nullptr;
        g_user = nullptr;
    }
}
