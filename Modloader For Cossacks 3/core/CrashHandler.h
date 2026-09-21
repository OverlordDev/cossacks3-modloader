#pragma once

#include <string>

// Отчёты о сбоях: нарушение доступа, int3 (CHECK в CEF), деление на ноль, переполнение стека,
// порча кучи — где бы они ни случились (игра, модлоадер, моды, CEF).
//
// Отчёт пишется в <игра>/modloader/crashes/<время>_<код>.txt (+ .dmp для первых трёх за запуск):
// что случилось, где (функция движка по таблице из IDA, наш код — файл:строка из PDB), стек,
// регистры, что модлоадер делал в этот момент (Scope), последние строки лога, моды, браузер.
//
// Ловится первое появление исключения — до того, как игра его обработает. Delphi часто
// перехватывает сбои сам и показывает "External exception ..." вместо вылета: отчёт всё равно
// будет, с пометкой, что игра могла выжить.
namespace CrashHandler
{
    void Install();
    void Uninstall();

    // Что сейчас делает этот поток — попадает в отчёт. Вложенные области складываются в стек:
    //   CrashHandler::Scope s("lua: menu_mod:client event game.start");
    class Scope
    {
    public:
        explicit Scope(std::string what);
        ~Scope();
        Scope(const Scope&) = delete;
        Scope& operator=(const Scope&) = delete;
    };

    // Участок, где сбой ожидаем и обработан (вызов натива под __try): отчёт не нужен.
    class Guard
    {
    public:
        Guard();
        ~Guard();
    };

    // Отчёт вручную, без исключения (например, из консоли: .crashtest).
    std::string ReportNow(const char* reason);
}
