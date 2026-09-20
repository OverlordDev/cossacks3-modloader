// Cossacks3Cef.exe — подпроцесс браузера.
//
// CEF работает несколькими процессами: рендер, GPU, служебные. Запускать их из cossacks.exe нельзя,
// он на это не рассчитан, поэтому для них отдельный маленький exe. Своей логики тут почти нет:
// грузится libcef.dll и поднимается половина моста в игру.
//
// Мост двусторонний и живёт в двух процессах: в этом (со стороны страницы) он регистрирует в JS
// функцию cefQuery, а в игре её разбирает WebUi. Без этой половины window.cefQuery просто не
// появится в странице.
//
// Путь к libcef.dll подпроцессу сообщает сам CEF ключом --libcef-path, так что папку cef/ можно
// держать где угодно — этот exe лежит рядом с ней.
#include <windows.h>

#include "include/cef_app.h"
#include "include/cef_render_process_handler.h"
#include "include/wrapper/cef_library_loader.h"
#include "include/wrapper/cef_message_router.h"

namespace
{
    class SubApp : public CefApp, public CefRenderProcessHandler
    {
    public:
        CefRefPtr<CefRenderProcessHandler> GetRenderProcessHandler() override { return this; }

        void OnWebKitInitialized() override
        {
            CefMessageRouterConfig config; // имена по умолчанию: cefQuery и cefQueryCancel
            m_router = CefMessageRouterRendererSide::Create(config);
        }

        void OnContextCreated(CefRefPtr<CefBrowser> browser, CefRefPtr<CefFrame> frame,
                              CefRefPtr<CefV8Context> context) override
        {
            if (m_router)
                m_router->OnContextCreated(browser, frame, context);
        }

        void OnContextReleased(CefRefPtr<CefBrowser> browser, CefRefPtr<CefFrame> frame,
                               CefRefPtr<CefV8Context> context) override
        {
            if (m_router)
                m_router->OnContextReleased(browser, frame, context);
        }

        bool OnProcessMessageReceived(CefRefPtr<CefBrowser> browser, CefRefPtr<CefFrame> frame,
                                      CefProcessId source, CefRefPtr<CefProcessMessage> message) override
        {
            return m_router && m_router->OnProcessMessageReceived(browser, frame, source, message);
        }

    private:
        CefRefPtr<CefMessageRouterRendererSide> m_router;
        IMPLEMENT_REFCOUNTING(SubApp);
    };
}

int APIENTRY wWinMain(HINSTANCE instance, HINSTANCE, LPWSTR, int)
{
    cef_version_info_t version = {};
    CEF_POPULATE_VERSION_INFO(&version);

    // Проверяет заодно, что версия libcef.dll совпадает с той, под которую мы собраны.
    CefScopedLibraryLoader loader;
    if (!loader.LoadInSubProcessAssert(&version))
        return 1; // запущен не как подпроцесс CEF

    CefMainArgs args(instance);
    return CefExecuteProcess(args, new SubApp(), nullptr);
}
