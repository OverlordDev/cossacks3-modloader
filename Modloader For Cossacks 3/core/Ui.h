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

    // Выравнивание — константа игры: gc_halLeft/gc_halMiddle/gc_halParentMiddle/gc_halParentRight...,
    // gc_valTop/gc_valMiddle/gc_valParentTop/gc_valParentBottom... Координаты считаются от точки привязки.
    struct Align { std::string h = "gc_halLeft", v = "gc_valTop"; };

    // 0 при ошибке (движок пишет её в лог). parent 0 — верхний уровень интерфейса.
    int CreateGameWindow(const std::string& name, int parent, int x, int y, int w, int h);
    int CreateGameText(const std::string& name, int parent, const std::string& text, int x, int y, int w, int h,
                       const std::string& font, const Color& color, const Align& align = {});
    // w/h 0 — размер берётся из картинки материала (<material>.normal); иначе картинка тянется под них.
    int CreateGameButton(const std::string& name, int parent, const std::string& text, int x, int y, int w, int h,
                         const std::string& material, const std::string& hint, int tag, const Align& align = {});
    // Контейнер — пустой элемент, к которому крепится всё остальное. Элемент, созданный прямо под
    // верхним уровнем интерфейса, приходит от движка скрытым, поэтому контейнер ещё и показывает себя
    // (так же делает _gui_CreateParent в data/scripts/lib/gui.script).
    int CreateGameContainer(const std::string& name, int parent, int x, int y, int w, int h, const Align& align = {});
    // material — имя из библиотек интерфейса игры ('mainmenu_art', 'logo_small', 'btn.large'...).
    // w/h 0 — взять размер самой текстуры.
    int CreateGameImage(const std::string& name, int parent, const std::string& material, int x, int y, int w, int h,
                        const Align& align = {});

    // Нажатия наших кнопок: (элемент, press — 'c' клик и т.п., tag).
    using PressHandler = std::function<void(int element, const std::string& press, int tag)>;
    void SetPressHandler(PressHandler handler);

    // Вставить в GUI-состояние игры событие "guistate.<State>" с payload "элемент|press|tag".
    // Обработчик может вызвать Events::RequestBlock() — игра это нажатие не обработает.
    void HookState(const std::string& state);

    // Перехватить построение экрана интерфейса (ShowMainMenu, ShowSettings, ShowHud...): в начале
    // состояния возникает событие "guiscreen.<State>", и если обработчик вызовет Events::RequestBlock(),
    // свой код игра не выполнит — экран целиком рисует мод. Игра перестраивает экраны сама
    // (смена разрешения, меню <-> партия), поэтому обработчик вызывается каждый раз заново.
    void HookScreen(const std::string& state);

    // Запустить состояние интерфейса игры и передать ему тэг — как нажатие родной кнопки
    // (EventMainMenu + 103 = "мультиплеер"): своя кнопка делает то же, что оригинальная.
    void ExecuteState(const std::string& state);
    void SendTag(const std::string& state, int tag);
}
