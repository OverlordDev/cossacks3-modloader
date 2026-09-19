#pragma once

// Lua-моды: <папка игры>/modloader/mods/<папка мода>/manifest.lua.
// Грузится только то, что перечислено в манифесте (client / server + files).
//
// У мода две стороны со своими окружениями:
//   server — правила игры: ресурсы, характеристики, код игры. Обработчики событий работают только там,
//            где решается игра: в одиночной игре и у хоста. Может рассылать сообщения клиентам.
//   client — у каждого игрока (и у хоста): интерфейс, бинды, эффекты. Только чтение состояния игры,
//            изменения — через сообщение серверу (net.send).
// Весь Lua работает в главном потоке игры.
namespace LuaHost
{
    void Start();                              // загрузить моды (асинхронно, в главном потоке игры)
    void Reload();                             // закрыть Lua и загрузить моды заново
    void Shutdown();                           // синхронно; вызывать из потока модлоадера перед выгрузкой DLL
    void RunConsole(const std::string& code);  // строка Lua из консоли (UTF-8), выполняется с правами server
    void PrintMods();

    // Сообщение мода из сети (Net::Receiver). Главный поток игры.
    void OnNetMessage(char direction, const std::string& mod, const std::string& event, const std::string& data, int from);

    // Нажатие кнопки, созданной через ui.button (Ui::PressHandler). Главный поток игры.
    void OnUiPress(int element, const std::string& press, int tag);

    // Бинды клиентских скриптов; active — окно игры активно и меню модлоадера закрыто. Каждый кадр.
    void PollInput(bool active);

    // Для меню модов (главный поток игры).
    enum class ModStatus { Loaded, Error, Disabled };
    struct ModView
    {
        std::string folder, id, name, version, author, description, error;
        std::string sides;       // "client+server" / "client" / "server"
        std::string multiplayer; // "required" / "optional"
        ModStatus status;
    };
    std::vector<ModView> Mods();
    // Вкл/выкл мода: сохраняется в modloader/modstate.txt (манифест не меняется), Lua перезагружается.
    void SetModEnabled(const std::string& id, bool enabled);
}
