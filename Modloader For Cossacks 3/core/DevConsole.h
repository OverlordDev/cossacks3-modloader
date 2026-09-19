#pragma once

// Интерактивная консоль: ввод строк скрипта игры, поиск функций API, команды чата.
namespace DevConsole
{
    enum class ExitRequest { None, Unload, Reload };

    void Start();
    void Stop();
    ExitRequest GetExitRequest();
}
