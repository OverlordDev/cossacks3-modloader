#include "pch.h"
#include "Game.h"
#include "Console.h"
#include "Events.h"
#include "NativeCall.h"
#include "ScriptRunner.h"

namespace
{
    bool g_inGame = false;

    enum class Pending { None, Start, Menu };
    Pending g_pending = Pending::None;

    int CallIntNative(const char* name)
    {
        const NativeCall::Signature* sig = NativeCall::Find(name);
        if (!sig || !sig->error.empty())
            return 0;
        NativeCall::Value result;
        std::string error;
        return NativeCall::Invoke(*sig, {}, &result, &error) ? result.i : 0;
    }

    bool EvalInGame()
    {
        std::string result;
        return ScriptRunner::Call("if (gInterface.gamemode = gc_gamemode_game) then ML_RET('1') else ML_RET('0');", "", &result) &&
               result == "1";
    }

    void Leave()
    {
        if (g_pending == Pending::Start)
            g_pending = Pending::None; // партия закрылась, не успев начаться
        if (!g_inGame)
            return;
        g_inGame = false;
        LOG_INFO("\x1b[35m[game]\x1b[0m end");
        Events::Emit("game.end");
    }
}

void Game::Install()
{
    Events::HookGuiState("DoNewGame");
    Events::HookGuiState("DoCreate");
    Events::HookGuiState("DoProgress");
    Events::HookGuiState("DoDestroy");

    Events::Subscribe("gui.DoNewGame", [](const std::string&, const std::string&) {
        Leave();
        Events::Emit("game.prepare");
    });

    // DoCreate срабатывает и при входе в главное меню, и при создании партии после генерации карты.
    // Наша вставка стоит в начале DoCreate — интерфейс ещё не построен (и дальше пересоздаётся), поэтому
    // game.start / game.menu откладываем до первого такта: к нему интерфейс уже готов и моды могут его менять.
    Events::Subscribe("gui.DoCreate", [](const std::string&, const std::string&) {
        if (EvalInGame())
        {
            g_inGame = true;
            g_pending = Pending::Start;
        }
        else
        {
            Leave();
            g_pending = Pending::Menu;
        }
    });

    Events::Subscribe("gui.DoProgress", [](const std::string&, const std::string&) {
        Pending pending = g_pending;
        g_pending = Pending::None;
        if (pending == Pending::Start)
        {
            const char* role = IsAuthority() ? (Mode() == LanMode::Server ? "host" : "offline") : "client";
            LOG_INFO("\x1b[35m[game]\x1b[0m start (%s)", role);
            Events::Emit("game.start");
        }
        else if (pending == Pending::Menu)
            Events::Emit("game.menu");

        if (g_inGame)
            Events::Emit("game.tick");
    });

    Events::Subscribe("gui.DoDestroy", [](const std::string&, const std::string&) { Leave(); });
}

Game::LanMode Game::Mode()
{
    int mode = CallIntNative("GetLanMode");
    return mode >= 2 ? LanMode::Server : mode == 1 ? LanMode::Client : LanMode::Offline;
}

bool Game::IsAuthority()
{
    return Mode() != LanMode::Client;
}

bool Game::InGame()
{
    return g_inGame;
}

int Game::MyLanId()
{
    return Mode() == LanMode::Offline ? 0 : CallIntNative("LanMyInfoID");
}
