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

    // Режим разработчика: подробная диагностика (кадры браузера, окна, вставки в скрипты).
    // Включён, если есть файл <игра>/modloader/dev.txt. Всё, что выводится, заодно пишется в
    // <игра>/modloader/modloader.log (перезаписывается при каждом запуске) — лог с чужого ПК.
    bool Dev();
    void Dev(const char* fmt, ...);

    // Ввод из консоли в отдельном потоке. Строки (UTF-8) отдаются пачкой в PollInput:
    // одна строка — обычный ввод, несколько — вставка из буфера обмена.
    void StartInput(std::function<void(const std::vector<std::string>&)> onLines);
    void PollInput(); // из цикла модлоадера
    void StopInput();
}

#define LOG_INFO(...)  Console::Info(__VA_ARGS__)
#define LOG_WARN(...)  Console::Warn(__VA_ARGS__)
#define LOG_ERROR(...) Console::Error(__VA_ARGS__)
#define LOG_DEV(...)   do { if (Console::Dev()) Console::Dev(__VA_ARGS__); } while (0)
