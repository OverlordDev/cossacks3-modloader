#pragma once

// Меню модлоадера поверх игры (Dear ImGui, Win32 + OpenGL2). Открывается клавишей Insert.
// Рисуется в хуке SwapBuffers (главный поток игры, GL-контекст текущий).
namespace Overlay
{
    void OnSwapBuffers(HDC dc); // из хука SwapBuffers, перед оригиналом
    void Shutdown();            // из потока модлоадера перед выгрузкой: освобождение идёт в следующем кадре

    // Окно, в котором игра рисует (из SwapBuffers). nullptr, пока не нарисован первый кадр.
    // Это же окно качает очередь сообщений игры — на него опирается ScriptRunner.
    HWND RenderWindow();
}
