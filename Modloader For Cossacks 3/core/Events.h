#pragma once

#include <functional>

// События игры для модов. Механизм: в код состояния игры (например DoProgress в menu.aix) вставляется строка
//   DScriptSetgDbgString0('ML:gui.DoProgress');
// Этот отладочный натив игрой не используется — мы его перехватываем и превращаем вызов в событие.
// Файлы игры не меняются: строка живёт только в памяти, после вставки состояние перекомпилируется.
namespace Events
{
    using Handler = std::function<void(const std::string& event)>;

    bool Install(); // хук натива-трамплина
    void Update();  // из цикла модлоадера: раз в секунду проверяет, что вставки на месте

    // Событие "gui.<State>" (в начале состояния) или "gui.<State>.end" (в конце; не сработает, если состояние
    // вышло раньше через exit). Вставка выполняется асинхронно в главном потоке игры.
    void HookGuiState(const std::string& state, bool atEnd = false);

    int Subscribe(const std::string& event, Handler handler); // event = "*" — все события
    void Unsubscribe(int id);

    void PrintStats(); // счётчики срабатываний

    // Обмен значениями со скриптом (главный поток игры):
    //   аргумент для скрипта — читается в нём через DScriptGetgDbgString0;
    //   результат из скрипта — DScriptSetgDbgString0('ML:ret:' + значение) попадает в захват.
    void SetScriptArg(const std::string& value);
    void BeginCapture();
    bool EndCapture(std::string* value); // false — скрипт ничего не вернул
}
