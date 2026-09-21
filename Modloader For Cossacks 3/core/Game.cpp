#include "pch.h"
#include "Game.h"
#include "Console.h"
#include "Events.h"
#include "NativeCall.h"
#include "ScriptRunner.h"

namespace
{
    bool g_inGame = false;

    enum class Pending { None, Resolve, Start, Menu };
    Pending g_pending = Pending::None;
    int g_resolveTries = 0;

    int CallIntNative(const char* name)
    {
        const NativeCall::Signature* sig = NativeCall::Find(name);
        if (!sig || !sig->error.empty())
            return 0;
        NativeCall::Value result;
        std::string error;
        return NativeCall::Invoke(*sig, {}, &result, &error) ? result.i : 0;
    }

    // *ok — удалось ли вообще спросить игру. Во время создания карты скриптовый вызов может не
    // пройти, и принимать это за «мы в меню» нельзя: партия тогда начнётся без game.start,
    // и моды молча ничего не сделают.
    bool EvalInGame(bool* ok)
    {
        std::string result;
        *ok = ScriptRunner::Call("if (gInterface.gamemode = gc_gamemode_game) then ML_RET('1') else ML_RET('0');", "", &result);
        return *ok && result == "1";
    }

    void Leave()
    {
        if (g_pending == Pending::Start || g_pending == Pending::Resolve)
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

    // Жизнь объектов: вставки в библиотеки состояний юнитов и зданий. Данные: "хендл|тип".
    struct ObjectHook { const char* library; const char* kind; const char* state; const char* event; };
    const ObjectHook objectHooks[] = {
        { "units\\unit.aix",     "unit",     "Initial",   "spawn" },
        { "units\\unit.aix",     "unit",     "OnDeath",   "death" },
        { "units\\unit.aix",     "unit",     "OnDestroy", "destroy" },
        { "units\\building.aix", "building", "Initial",   "spawn" },
        { "units\\building.aix", "building", "OnDeath",   "death" },
        { "units\\building.aix", "building", "OnDestroy", "destroy" },
    };
    // Урон: каждый вызов _misc_DoDamage(кто, кого, урон, ...) в состояниях юнитов, зданий, снарядов.
    struct DamageHook { const char* library; const char* state; };
    const DamageHook damageHooks[] = {
        { "units\\unit.aix", "OnAclAnimationReachedAttack" }, // ближний бой и выстрел пехоты
        { "units\\unit.aix", "OnTagStates" },
        { "units\\building.aix", "OnTagStates" },             // башни, форты
        { "misc\\projectile.aix", "DoExplode" },              // ядра, снаряды
        { "misc\\projectile.aix", "DoExplodeCustom" },
    };
    for (const DamageHook& d : damageHooks)
        Events::WrapLibraryCalls(d.library, d.state, "_misc_DoDamage", std::string("damage@") + d.library + "/" + d.state,
            "DScriptSetgDbgString0('ML:unit.damage|'+IntToStr({0})+'|'+IntToStr({1})+'|'+IntToStr({2}))");

    for (const ObjectHook& h : objectHooks)
    {
        std::string event = std::string(h.kind) + "." + h.event;
        Events::HookLibraryStateCode(h.library, h.state, event,
            "DScriptSetgDbgString0('ML:" + event + "|'+IntToStr(GetGameObjectMyHandle)+'|'+GetGameObjectMyBaseName);");
    }

    Events::Subscribe("gui.DoNewGame", [](const std::string&, const std::string&) {
        Leave();
        Events::Emit("game.prepare");
    });

    // DoCreate срабатывает и при входе в главное меню, и при создании партии после генерации карты.
    // Наша вставка стоит в начале DoCreate — интерфейс ещё не построен (и дальше пересоздаётся), поэтому
    // game.start / game.menu откладываем до первого такта: к нему интерфейс уже готов и моды могут его менять.
    Events::Subscribe("gui.DoCreate", [](const std::string&, const std::string&) {
        Events::MaintainNow(); // перехваты экранов (ShowMainMenu...) — до того, как игра их построит
        g_pending = Pending::Resolve; // спросим на первом такте, когда игра уже отвечает
        g_resolveTries = 0;
    });

    Events::Subscribe("gui.DoProgress", [](const std::string&, const std::string&) {
        if (g_pending == Pending::Resolve)
        {
            bool ok = false;
            bool inGame = EvalInGame(&ok);
            if (!ok && ++g_resolveTries < 60)
                return; // игра ещё грузится — спросим на следующем такте
            if (inGame)
            {
                g_inGame = true;
                g_pending = Pending::Start;
            }
            else
            {
                Leave();
                g_pending = Pending::Menu;
            }
        }

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
