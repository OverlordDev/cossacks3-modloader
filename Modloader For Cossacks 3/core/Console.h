#pragma once

#include <functional>

// Отладочная консоль модлоадера.
namespace Console
{
    bool Init(const wchar_t* title);
    void Shutdown();

    void Info(const char* fmt, ...);
    void Warn(const char* fmt, ...);
    void Error(const char* fmt, ...);
    void Print(const char* fmt, ...); // без времени и тега

    // Ввод из консоли в отдельном потоке. Строки (UTF-8) отдаются пачкой в PollInput:
    // одна строка — обычный ввод, несколько — вставка из буфера обмена.
    void StartInput(std::function<void(const std::vector<std::string>&)> onLines);
    void PollInput(); // из цикла модлоадера
    void StopInput();
}

#define LOG_INFO(...)  Console::Info(__VA_ARGS__)
#define LOG_WARN(...)  Console::Warn(__VA_ARGS__)
#define LOG_ERROR(...) Console::Error(__VA_ARGS__)
