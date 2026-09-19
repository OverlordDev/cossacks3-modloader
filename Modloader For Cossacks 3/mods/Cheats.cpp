#include "pch.h"
#include "Cheats.h"
#include "../core/Console.h"
#include "../core/ScriptRunner.h"

namespace
{
    bool GameHasFocus()
    {
        DWORD pid = 0;
        GetWindowThreadProcessId(GetForegroundWindow(), &pid);
        return pid == GetCurrentProcessId() && GetForegroundWindow() != GetConsoleWindow();
    }

    // То же, что ввести текст в чат игры.
    void GameCommand(const std::string& cmd)
    {
        LOG_INFO("Game command: %s", cmd.c_str());
        ScriptRunner::Queue({
            "var modloaderCmd : String = '" + cmd + "';",
            "_misc_ProcessMessage(modloaderCmd);",
        });
    }
}

void Cheats::Update()
{
    bool f9 = GetAsyncKeyState(VK_F9) & 1; // читаем всегда, чтобы сбросить флаг нажатия
    if (f9 && GameHasFocus())
        GameCommand("res all 100000");
}
