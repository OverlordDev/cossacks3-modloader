#pragma once

// Время кадра: хук gdi32!SwapBuffers (конец кадра игры).
namespace FrameStats
{
    bool Install();
    void Update();             // из цикла модлоадера: авто-вывод раз в 5 с, если включён
    void SetAutoReport(bool on);
    void Report(double seconds); // статистика за последние N секунд
}
