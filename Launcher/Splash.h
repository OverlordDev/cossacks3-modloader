#pragma once

#include <windows.h>
#include <string>

// Экран загрузки лаунчера: показывается, пока игра стартует, и уходит по сигналу модлоадера.
namespace Splash
{
    // Имя события, которым модлоадер сообщает «игра дошла до меню».
    inline constexpr wchar_t kReadyEventName[] = L"Local\Cossacks3Modloader.Ready";

    // Создать событие до запуска игры, чтобы модлоадер внутри неё смог его открыть.
    HANDLE CreateReadyEvent();

    // Показать окно и крутить его сообщения, пока не придёт сигнал, не закроется игра
    // или не выйдет время.
    void Run(HINSTANCE instance, const std::wstring& gameDir, HANDLE ready, HANDLE process,
             DWORD timeoutMs);
}
