#pragma once

// Состояние партии и роль этого компьютера в сети. Всё — в главном потоке игры.
//
// События (Events):
//   game.menu     — главное меню
//   game.prepare  — подготовка новой партии (DoNewGame)
//   game.start    — партия создана, игроки есть (DoCreate в режиме игры)
//   game.tick     — каждый такт интерфейса во время партии (DoProgress)
//   game.end      — выход из партии
namespace Game
{
    enum class LanMode { Offline = 0, Client = 1, Server = 2 };

    void Install();

    LanMode Mode();        // GetLanMode: 0 — не в сети, 1 — клиент, 2 — хост
    bool IsAuthority();    // решает за игру: одиночная игра или хост
    bool InGame();         // идёт партия (обновляется на DoCreate / выходе)
    int MyLanId();         // LanMyInfoID (0 вне сети)
}
