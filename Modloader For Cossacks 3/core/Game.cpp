#include "pch.h"
#include "Game.h"
#include "Console.h"
#include "Events.h"
#include "NativeCall.h"
#include "ScriptRunner.h"

namespace
{
    bool g_inGame = false;

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
    Events::Subscribe("gui.DoCreate", [](const std::string&, const std::string&) {
        if (EvalInGame())
        {
            g_inGame = true;
            const char* role = IsAuthority() ? (Mode() == LanMode::Server ? "host" : "offline") : "client";
            LOG_INFO("\x1b[35m[game]\x1b[0m start (%s)", role);
            Events::Emit("game.start");
        }
        else
        {
            Leave();
            Events::Emit("game.menu");
        }
    });

    Events::Subscribe("gui.DoProgress", [](const std::string&, const std::string&) {
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
