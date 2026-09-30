#pragma once

#include <string>

// Steam Rich Presence: мост к уже загруженной игре steam_api.dll.
//
// Правила (не ломать):
// - НЕ вызываем SteamAPI_Init / SteamAPI_Shutdown / SteamwrapFree / SteamAPPUnload.
//   Steam инициализирует сама игра; мы только пользуемся её pipe/user.
// - НЕ делаем LoadLibrary/FreeLibrary: только GetModuleHandleW (счётчик не трогаем).
// - ISteamFriends — только прямым CreateInterface("SteamFriends017/016/015").
//   Маршрут через ISteamClient + pipe игры на этой сборке падает в steamclient
//   (проверено 2026-09-26) и удалён: безопасность игры важнее статуса.
// - Все вызовы — только из главного потока игры (проверяет LuaHost).
// - Каждый вызов Steam обёрнут в SEH: чужая DLL не должна ронять игру.
// - Строки — UTF-8 как есть (имена на русском не перекодируем).
namespace SteamPresence
{
    // Статус моста: "ok" | "no_dll" | "no_user" | "no_friends" | "call_failed".
    std::string Status();

    // true — DLL, pipe/user и ISteamFriends на месте.
    bool Available();

    // Поставить пару key/value. false — Steam недоступен или вызов не удался.
    bool Set(const std::string& key, const std::string& value);

    // Убрать весь Rich Presence локального пользователя.
    bool Clear();

    // Отметить совместную игру (uint64 SteamID строкой из Lua).
    bool PlayedWith(unsigned long long steamId);

    // Свой SteamID64 строкой ("" — недоступен).
    std::string MyId();

    // Выгрузка модлоадера: убрать статус, забыть указатели (steam_api.dll не трогаем).
    void Shutdown();
}
