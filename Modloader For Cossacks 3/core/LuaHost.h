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
}
