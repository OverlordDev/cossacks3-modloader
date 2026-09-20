// Cossacks3Cef.exe — подпроцесс браузера.
//
// CEF работает несколькими процессами: рендер, GPU, служебные. Запускать их из cossacks.exe нельзя,
// он на это не рассчитан, поэтому для них отдельный маленький exe. Он не делает ничего своего:
// грузит libcef.dll и отдаёт управление CEF.
//
// Путь к libcef.dll подпроцессу сообщает сам CEF ключом --libcef-path, так что папку cef/ можно
// держать где угодно — этот exe лежит рядом с ней.
#include <windows.h>

#include "include/cef_app.h"
#include "include/wrapper/cef_library_loader.h"

int APIENTRY wWinMain(HINSTANCE instance, HINSTANCE, LPWSTR, int)
{
    cef_version_info_t version = {};
    CEF_POPULATE_VERSION_INFO(&version);

    // Проверяет, что версия libcef.dll совпадает с той, под которую мы собраны.
    CefScopedLibraryLoader loader;
    if (!loader.LoadInSubProcessAssert(&version))
        return 1; // запущен не как подпроцесс CEF

    CefMainArgs args(instance);
    return CefExecuteProcess(args, nullptr, nullptr);
}
