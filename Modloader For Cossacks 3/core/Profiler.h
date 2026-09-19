#pragma once

// Семплирующий профилировщик главного потока игры: ~1000 снимков в секунду (EIP + цепочка EBP),
// в конце — топ функций по exclusive (где поток был) и inclusive (в стеке) времени, плюс разбивка по модулям.
namespace Profiler
{
    void Start(DWORD threadId, int seconds);
    bool IsRunning();
}
