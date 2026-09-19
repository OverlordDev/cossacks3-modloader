#pragma once

// Вывод логов игры в консоль: внутренние логгеры движка (LOG/ERR/INFO/NORMAL/ERROR) и скриптовый TimeLog.
namespace ScriptLog
{
    bool Install();
    void PrintBuildVersion();
}
