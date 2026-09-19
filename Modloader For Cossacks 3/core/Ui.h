#pragma once

#include <functional>

// Штатный интерфейс игры для клиентских модов. Всё — в главном потоке игры.
//
// Свои элементы создаются теми же скриптовыми функциями, что и интерфейс игры (_gui_CreateButton,
// _gui_CreateText, _gui_CreateSkinWindow), поэтому выглядят как родные. Клик по нашей кнопке запускает
// GUI-состояние ModLoader.UI (имя начинается с ModLoader. — не влияет на хеш лобби), которое передаёт
// ElementHandle/Press/Tag в модлоадер. Интерфейс пересоздаётся игрой (меню ↔ партия) — элементы пропадают,
// создавать их заново нужно по событию game.start / game.menu.
namespace Ui
{
    struct Color { int r = 255, g = 220, b = 170, a = 255; };

    void Install();
    void Update(); // из цикла модлоадера: раз в секунду проверяет, что ModLoader.UI на месте

    // 0 при ошибке (движок пишет её в лог). parent 0 — верхний уровень интерфейса.
    int CreateGameWindow(const std::string& name, int parent, int x, int y, int w, int h);
    int CreateGameText(const std::string& name, int parent, const std::string& text, int x, int y, int w, int h,
                       const std::string& font, const Color& color);
    int CreateGameButton(const std::string& name, int parent, const std::string& text, int x, int y,
                         const std::string& material, const std::string& hint, int tag);

    // Нажатия наших кнопок: (элемент, press — 'c' клик и т.п., tag).
    using PressHandler = std::function<void(int element, const std::string& press, int tag)>;
    void SetPressHandler(PressHandler handler);

    // Вставить в GUI-состояние игры событие "guistate.<State>" с payload "элемент|press|tag".
    // Обработчик может вызвать Events::RequestBlock() — игра это нажатие не обработает.
    void HookState(const std::string& state);
}
