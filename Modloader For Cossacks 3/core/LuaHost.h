#pragma once

// Lua-моды: <папка игры>/modloader/mods/<папка мода>/manifest.lua.
// Грузится только то, что перечислено в манифесте (entry + files); у каждого мода своё окружение
// без io/os.execute/load/dofile. Весь Lua работает в главном потоке игры.
namespace LuaHost
{
    void Start();                              // загрузить моды (асинхронно, в главном потоке игры)
    void Reload();                             // закрыть Lua и загрузить моды заново
    void Shutdown();                           // синхронно; вызывать из потока модлоадера перед выгрузкой DLL
    void RunConsole(const std::string& code);  // строка Lua из консоли (UTF-8)
    void PrintMods();

    // Для меню модов (главный поток игры).
    enum class ModStatus { Loaded, Error, Disabled };
    struct ModView
    {
        std::string folder, id, name, version, author, description, error;
        ModStatus status;
    };
    std::vector<ModView> Mods();
    // Вкл/выкл мода: сохраняется в modloader/modstate.txt (манифест не меняется), Lua перезагружается.
    void SetModEnabled(const std::string& id, bool enabled);
}
