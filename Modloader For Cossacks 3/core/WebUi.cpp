#include "pch.h"
#include "WebUi.h"
#include "Console.h"
#include "LuaHost.h"
#include "ScriptRunner.h"
#include "Ui.h"

#include <algorithm>
#include <atomic>
#include <filesystem>
#include <mutex>
#include <vector>

#include <windowsx.h>
#include <gl/GL.h>

// windows.h объявляет GetFirstChild/GetNextSibling макросами, а в CEF это методы классов.
#undef GetFirstChild
#undef GetNextSibling
#undef GetPrevSibling
#undef GetNextWindow

#include "include/cef_app.h"
#include "include/cef_client.h"
#include "include/wrapper/cef_library_loader.h"
#include "include/wrapper/cef_message_router.h"

#pragma comment(lib, "opengl32.lib")

namespace fs = std::filesystem;

namespace
{
    constexpr GLenum kBgra = 0x80E1; // GL_BGRA: CEF отдаёт кадр именно в таком порядке байт

    fs::path GameDir()
    {
        wchar_t exe[MAX_PATH];
        GetModuleFileNameW(nullptr, exe, MAX_PATH);
        return fs::path(exe).parent_path();
    }

    fs::path CefDir()       { return GameDir() / L"cef"; }
    fs::path SubProcess()   { return GameDir() / L"Cossacks3Cef.exe"; }
    fs::path ModloaderDir() { return GameDir() / L"modloader"; }

    // ---------- состояние ----------

    enum class State { Off, Running, Failed };

    std::atomic<State> g_state{ State::Off };
    std::atomic<bool> g_shutdownRequested{ false };
    HANDLE g_shutdownDone = nullptr;
    // CEF нельзя поднять второй раз в одном процессе: после остановки браузер доступен только
    // после перезапуска игры.
    bool g_spent = false;

    std::mutex g_cmdMutex;
    std::string g_pendingUrl;
    std::vector<std::string> g_pendingEval;
    bool g_pendingOpen = false;
    bool g_pendingClose = false;
    bool g_pendingReload = false;

    // ---------- кадр браузера ----------

    std::mutex g_frameMutex;
    std::vector<uint8_t> g_pixels;
    int g_frameWidth = 0, g_frameHeight = 0;
    bool g_frameDirty = false;

    GLuint g_texture = 0;
    int g_textureWidth = 0, g_textureHeight = 0;

    // Выпадающие списки <select> CEF рисует отдельным слоем поверх страницы и сообщает,
    // куда его класть. Без этого список раскрывается невидимым.
    std::vector<uint8_t> g_popupPixels;
    int g_popupWidth = 0, g_popupHeight = 0;
    bool g_popupDirty = false;
    bool g_popupVisible = false;
    int g_popupX = 0, g_popupY = 0;
    GLuint g_popupTexture = 0;
    int g_popupTexWidth = 0, g_popupTexHeight = 0;
    int g_viewWidth = 1280, g_viewHeight = 720;

    CefRefPtr<CefBrowser> g_browser;

    // ---------- CEF ----------

    std::atomic<bool> g_reportFrame{ true };
    CefRefPtr<CefMessageRouterBrowserSide> g_router;
    std::atomic<bool> g_pageReady{ false }; // страница догрузилась, в неё можно выполнять код
    DWORD g_cefThread = 0;                  // поток, в котором подняли CEF: только он вправе его дёргать
    bool g_localPage = true; // страница загружена с диска — ей можно доверять Lua

    // Код, который получает страница: обёртка над cefQuery с промисами.
    constexpr char kBridgeJs[] = R"js(
// Значение JS -> литерал Lua. Строки — в длинных скобках, так экранировать ничего не нужно.
function toLua(v) {
  if (v === null || v === undefined) return 'nil';
  if (typeof v === 'boolean') return v ? 'true' : 'false';
  if (typeof v === 'number') return Number.isFinite(v) ? String(v) : 'nil';
  if (typeof v === 'string') {
    let eq = '';
    while (v.includes(']' + eq + ']')) eq += '=';
    return '[' + eq + '[' + String.fromCharCode(10) + v + ']' + eq + ']';
  }
  if (Array.isArray(v)) return '{' + v.map(toLua).join(', ') + '}';
  return '{' + Object.entries(v).map(([k, x]) => '[' + toLua(k) + '] = ' + toLua(x)).join(', ') + '}';
}

window.game = {
  send(request) {
    return new Promise((resolve, reject) => {
      window.cefQuery({
        request: String(request),
        onSuccess: resolve,
        onFailure: (code, message) => reject(new Error(message)),
      });
    });
  },
  // Нажать родную кнопку игры: game.tag('EventMainMenu', 101)
  tag(state, value) { return this.send('tag ' + state + ' ' + value); },
  // Запустить состояние интерфейса игры: game.exec('ShowSettings')
  exec(state) { return this.send('exec ' + state); },
  // Выполнить код мода: game.lua('print(gfx.presets())')
  lua(code) { return this.send('lua ' + code); },
  log(text) { return this.send('log ' + text); },
  // Библиотека api модлоадера: game.api('saves.list'), game.api('profile.set', 'sndmaster', 0.5).
  // Аргументы уходят в Lua как есть, ответ возвращается объектом.
  async api(name, ...args) {
    const text = await this.lua('api_call(' + [name, ...args].map(toLua).join(', ') + ')');
    return JSON.parse(text);
  },
  // Имена файлов в папке рядом со страницей: game.files('../LoadScreen')
  async files(folder) { return JSON.parse(await this.send('files ' + folder)); },
  // Убрать страницу с экрана и вернуть управление игре.
  close() { return this.send('close'); },
};
)js";

    // "tag EventMainMenu 101" -> ("tag", "EventMainMenu 101")
    std::pair<std::string, std::string> SplitCommand(const std::string& request)
    {
        size_t space = request.find(' ');
        if (space == std::string::npos)
            return { request, {} };
        return { request.substr(0, space), request.substr(space + 1) };
    }

    // Ответ считается в потоке игры, а завершать запрос надо в потоке браузера — переносим через очередь.
    struct Answer
    {
        CefRefPtr<CefMessageRouterBrowserSide::Handler::Callback> callback;
        std::string value;
        bool ok;
    };
    std::mutex g_answerMutex;
    std::vector<Answer> g_answers;

    // "file:///C:/Games/x/page.html" -> "C:' + BS + BS + 'Games' + BS + BS + 'x"
    fs::path PageDirectory(const std::string& url)
    {
        const std::string prefix = "file:///";
        if (url.rfind(prefix, 0) != 0)
            return {};
        std::string path;
        for (size_t i = prefix.size(); i < url.size(); ++i)
        {
            if (url[i] == '%' && i + 2 < url.size())
            {
                path += static_cast<char>(strtol(url.substr(i + 1, 2).c_str(), nullptr, 16));
                i += 2;
            }
            else if (url[i] == '?' || url[i] == '#')
                break;
            else
                path += url[i];
        }
        return fs::path(path).parent_path();
    }

    class Bridge : public CefMessageRouterBrowserSide::Handler
    {
    public:
        bool OnQuery(CefRefPtr<CefBrowser>, CefRefPtr<CefFrame> frame, int64_t, const CefString& request,
                     bool, CefRefPtr<Callback> callback) override
        {
            auto [cmd, arg] = SplitCommand(request.ToString());

            // Состояния игры трогаем в её потоке, а не в потоке браузера.
            if (cmd == "tag")
            {
                size_t space = arg.rfind(' ');
                if (space == std::string::npos)
                    return callback->Failure(1, "expected: tag <State> <number>"), true;
                std::string state = arg.substr(0, space);
                int value = atoi(arg.c_str() + space + 1);
                ScriptRunner::RunOnGameThread([state, value] { Ui::SendTag(state, value); });
            }
            else if (cmd == "exec")
            {
                std::string state = arg;
                ScriptRunner::RunOnGameThread([state] { Ui::ExecuteState(state); });
            }
            else if (cmd == "lua")
            {
                // Код мода — только со страниц с диска: у Lua полные права, и пускать туда
                // произвольный сайт нельзя.
                if (!g_localPage)
                    return callback->Failure(2, "lua is only allowed for local pages"), true;
                std::string code = arg;
                ScriptRunner::RunOnGameThread([code, callback] {
                    bool ok = false;
                    std::string value = LuaHost::EvalJson(code, &ok);
                    std::lock_guard lock(g_answerMutex);
                    g_answers.push_back({ callback, value, ok });
                });
                return true; // ответим, когда игра посчитает
            }
            else if (cmd == "files")
            {
                // Имена файлов в папке рядом со страницей: каталог она сама прочитать не может.
                std::error_code ec;
                fs::path dir = fs::weakly_canonical(PageDirectory(frame->GetURL().ToString()) / arg, ec);
                std::string gameDir = fs::weakly_canonical(GameDir(), ec).string();
                if (dir.string().rfind(gameDir, 0) != 0) // не выпускаем за пределы папки игры
                    return callback->Failure(5, "path is outside the game folder"), true;

                std::string json = "[";
                for (const auto& entry : fs::directory_iterator(dir, ec))
                {
                    if (!entry.is_regular_file(ec))
                        continue;
                    if (json.size() > 1)
                        json += ',';
                    json += '"';
                    for (char c : entry.path().filename().string())
                    {
                        if (c == '"' || c == '\\')
                            json += '\\';
                        json += c;
                    }
                    json += '"';
                }
                callback->Success(json + "]");
                return true;
            }
            else if (cmd == "close")
            {
                WebUi::RequestClose(); // страница сама убирает себя с экрана
            }
            else if (cmd == "log")
            {
                LOG_INFO("[36m[web:js][0m %s", arg.c_str());
            }
            else
            {
                return callback->Failure(3, "unknown command: " + cmd), true;
            }

            callback->Success("ok");
            return true;
        }
    };

    Bridge g_bridge;

    class Handler : public CefClient,
                    public CefRenderHandler,
                    public CefLifeSpanHandler,
                    public CefDisplayHandler,
                    public CefLoadHandler,
                    public CefRequestHandler
    {
    public:
        CefRefPtr<CefRenderHandler> GetRenderHandler() override { return this; }
        CefRefPtr<CefLifeSpanHandler> GetLifeSpanHandler() override { return this; }
        CefRefPtr<CefDisplayHandler> GetDisplayHandler() override { return this; }
        CefRefPtr<CefLoadHandler> GetLoadHandler() override { return this; }
        CefRefPtr<CefRequestHandler> GetRequestHandler() override { return this; }

        void OnLoadEnd(CefRefPtr<CefBrowser>, CefRefPtr<CefFrame> frame, int status) override
        {
            if (!frame->IsMain())
                return;
            std::string url = frame->GetURL().ToString();
            g_localPage = url.rfind("file://", 0) == 0;
            LOG_INFO("[web] loaded (%d) %s", status, url.c_str());
            frame->ExecuteJavaScript(kBridgeJs, url, 0); // window.game появляется здесь
            g_pageReady = true;
            g_reportFrame = true;
        }

        // Ответы моста приходят из процесса страницы — их разбирает роутер.
        bool OnProcessMessageReceived(CefRefPtr<CefBrowser> browser, CefRefPtr<CefFrame> frame,
                                      CefProcessId source, CefRefPtr<CefProcessMessage> message) override
        {
            return g_router && g_router->OnProcessMessageReceived(browser, frame, source, message);
        }

        void OnRenderProcessTerminated(CefRefPtr<CefBrowser> browser, TerminationStatus,
                                       int, const CefString&) override
        {
            if (g_router)
                g_router->OnRenderProcessTerminated(browser);
        }

        void OnLoadError(CefRefPtr<CefBrowser>, CefRefPtr<CefFrame> frame, ErrorCode code,
                         const CefString& text, const CefString& url) override
        {
            if (frame->IsMain())
                LOG_ERROR("[web] load failed (%d %s): %s", code, text.ToString().c_str(),
                          url.ToString().c_str());
        }

        void GetViewRect(CefRefPtr<CefBrowser>, CefRect& rect) override
        {
            rect.Set(0, 0, g_viewWidth, g_viewHeight);
        }

        void OnPaint(CefRefPtr<CefBrowser>, PaintElementType type, const RectList&,
                     const void* buffer, int width, int height) override
        {
            std::lock_guard lock(g_frameMutex);
            size_t bytes = static_cast<size_t>(width) * height * 4;
            if (type == PET_POPUP)
            {
                g_popupPixels.resize(bytes);
                memcpy(g_popupPixels.data(), buffer, bytes);
                g_popupWidth = width;
                g_popupHeight = height;
                g_popupDirty = true;
                return;
            }
            g_pixels.resize(bytes);
            memcpy(g_pixels.data(), buffer, bytes);
            g_frameWidth = width;
            g_frameHeight = height;
            g_frameDirty = true;

            if (g_reportFrame.exchange(false))
            {
                // Кадр приходит как BGRA. Смотрим, не сплошная ли это заливка и не пустой ли он.
                const uint8_t* px = g_pixels.data();
                size_t count = g_pixels.size() / 4, opaque = 0, distinct = 0;
                uint32_t first = count ? reinterpret_cast<const uint32_t*>(px)[0] : 0;
                for (size_t i = 0; i < count; ++i)
                {
                    if (px[i * 4 + 3] != 0)
                        ++opaque;
                    if (reinterpret_cast<const uint32_t*>(px)[i] != first)
                        ++distinct;
                }
                size_t mid = count / 2;
                LOG_INFO("[web] frame %dx%d: first BGRA=%02X %02X %02X %02X, middle BGRA=%02X %02X %02X %02X, "
                         "opaque %zu%%, differing pixels %zu%%",
                         width, height, px[0], px[1], px[2], px[3],
                         px[mid * 4], px[mid * 4 + 1], px[mid * 4 + 2], px[mid * 4 + 3],
                         count ? opaque * 100 / count : 0, count ? distinct * 100 / count : 0);
            }
        }

        void OnPopupShow(CefRefPtr<CefBrowser>, bool show) override
        {
            std::lock_guard lock(g_frameMutex);
            g_popupVisible = show;
            if (!show)
            {
                g_popupPixels.clear();
                g_popupWidth = g_popupHeight = 0;
            }
        }

        void OnPopupSize(CefRefPtr<CefBrowser>, const CefRect& rect) override
        {
            std::lock_guard lock(g_frameMutex);
            g_popupX = rect.x;
            g_popupY = rect.y;
        }

        void OnAfterCreated(CefRefPtr<CefBrowser> browser) override
        {
            g_browser = browser;
            LOG_INFO("[web] browser ready");
        }

        void OnBeforeClose(CefRefPtr<CefBrowser> browser) override
        {
            if (g_router)
                g_router->OnBeforeClose(browser);
            g_browser = nullptr;
            std::lock_guard lock(g_frameMutex);
            g_pixels.clear(); // иначе на экране застынет последний кадр
            g_frameDirty = false;
            g_popupPixels.clear();
            g_popupVisible = false;
        }

        // console.log страницы — в консоль модлоадера
        bool OnConsoleMessage(CefRefPtr<CefBrowser>, cef_log_severity_t, const CefString& message,
                              const CefString& source, int line) override
        {
            std::string where = source.ToString();
            size_t slash = where.find_last_of("/\\");
            if (slash != std::string::npos)
                where = where.substr(slash + 1);
            LOG_INFO("\x1b[36m[web:js]\x1b[0m %s (%s:%d)", message.ToString().c_str(), where.c_str(), line);
            return true;
        }

    private:
        IMPLEMENT_REFCOUNTING(Handler);
    };

    class App : public CefApp, public CefBrowserProcessHandler
    {
    public:
        CefRefPtr<CefBrowserProcessHandler> GetBrowserProcessHandler() override { return this; }

        void OnBeforeCommandLineProcessing(const CefString& processType, CefRefPtr<CefCommandLine> cmd) override
        {
            if (!processType.empty())
                return;
            // Софтверная отрисовка: браузер не трогает видеодрайвер игры. Для интерфейса скорости
            // хватает, а совместимость заметно выше — ради неё всё и затевалось.
            cmd->AppendSwitch("disable-gpu");
            cmd->AppendSwitch("disable-gpu-compositing");
            cmd->AppendSwitch("disable-gpu-vsync");
        }

    private:
        IMPLEMENT_REFCOUNTING(App);
    };

    CefRefPtr<Handler> g_handler;
    CefRefPtr<App> g_app;
    CefScopedLibraryLoader* g_loader = nullptr;

    // ---------- запуск ----------

    bool StartCef()
    {
        cef_version_info_t version = {};
        CEF_POPULATE_VERSION_INFO(&version);

        g_loader = new CefScopedLibraryLoader();
        std::wstring dll = (CefDir() / L"libcef.dll").wstring();
        if (!g_loader->LoadInMainAssert(dll.c_str(), nullptr, true, &version))
        {
            LOG_ERROR("[web] libcef.dll failed to load");
            return false;
        }

        std::error_code ec;
        fs::create_directories(ModloaderDir() / L"cefcache", ec);

        CefSettings settings;
        settings.no_sandbox = true;
        settings.windowless_rendering_enabled = true;
        settings.multi_threaded_message_loop = false;
        settings.external_message_pump = false;
        settings.log_severity = LOGSEVERITY_WARNING;
        CefString(&settings.browser_subprocess_path) = SubProcess().wstring();
        CefString(&settings.resources_dir_path) = CefDir().wstring();
        CefString(&settings.locales_dir_path) = (CefDir() / L"locales").wstring();
        CefString(&settings.root_cache_path) = (ModloaderDir() / L"cefcache").wstring();
        CefString(&settings.log_file) = (ModloaderDir() / L"cef.log").wstring();

        CefMainArgs args(GetModuleHandleW(nullptr));
        g_app = new App();
        if (!CefInitialize(args, settings, g_app.get(), nullptr))
        {
            LOG_ERROR("[web] CefInitialize failed — see modloader/cef.log");
            return false;
        }
        CefMessageRouterConfig routerConfig; // в JS это window.cefQuery
        g_router = CefMessageRouterBrowserSide::Create(routerConfig);
        g_router->AddHandler(&g_bridge, false);

        g_cefThread = GetCurrentThreadId();
        LOG_INFO("[web] CEF started (software rendering), thread %lu", g_cefThread);
        return true;
    }

    HWND g_parent = nullptr;       // окно, к которому привязан браузер
    std::string g_reopenUrl;       // страница, которую надо поднять заново в новом окне

    void CreateBrowser(HWND window, const std::string& url)
    {
        g_parent = window;
        RECT rc = {};
        GetClientRect(window, &rc);
        g_viewWidth = (std::max)(16L, rc.right - rc.left);
        g_viewHeight = (std::max)(16L, rc.bottom - rc.top);

        CefWindowInfo info;
        info.SetAsWindowless(window);
        info.shared_texture_enabled = false;

        CefBrowserSettings browser;
        browser.background_color = 0; // прозрачный фон: под страницей видно игру

        g_handler = new Handler();
        CefBrowserHost::CreateBrowser(info, g_handler, url, browser, nullptr, nullptr);
    }

    // ---------- вывод ----------

    // Общая заливка слоя в текстуру: одинаково для страницы и для выпадающего списка.
    void UploadLayer(const std::vector<uint8_t>& pixels, int width, int height, bool& dirty,
                     GLuint& texture, int& texWidth, int& texHeight)
    {
        if (pixels.empty() || width <= 0 || height <= 0)
            return;
        if (!dirty && texture)
            return;
        dirty = false;

        if (!texture)
        {
            glGenTextures(1, &texture);
            glBindTexture(GL_TEXTURE_2D, texture);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP);
            texWidth = texHeight = 0;
        }
        glBindTexture(GL_TEXTURE_2D, texture);
        glPixelStorei(GL_UNPACK_ALIGNMENT, 4);
        if (width != texWidth || height != texHeight)
        {
            glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, kBgra, GL_UNSIGNED_BYTE, pixels.data());
            texWidth = width;
            texHeight = height;
        }
        else
        {
            glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, width, height, kBgra, GL_UNSIGNED_BYTE, pixels.data());
        }
    }

    // ---------- остановка ----------

    void ShutdownOnRenderThread()
    {
        if (g_browser)
        {
            g_browser->GetHost()->CloseBrowser(true);
            for (int i = 0; i < 400 && g_browser; ++i) // до ~2 секунд на закрытие вкладки
            {
                CefDoMessageLoopWork();
                Sleep(5);
            }
        }
        if (g_router)
        {
            g_router->RemoveHandler(&g_bridge);
            g_router = nullptr;
        }
        g_handler = nullptr;
        g_app = nullptr;
        if (g_texture)
        {
            glDeleteTextures(1, &g_texture);
            g_texture = 0;
        }
        if (g_popupTexture)
        {
            glDeleteTextures(1, &g_popupTexture);
            g_popupTexture = 0;
        }
        CefShutdown();
        delete g_loader;
        g_loader = nullptr;
        g_state = State::Off;
        g_spent = true;
        LOG_INFO("[web] CEF stopped");
    }

    // ---------- ввод ----------

    uint32_t Modifiers()
    {
        uint32_t m = 0;
        if (GetKeyState(VK_SHIFT) & 0x8000)   m |= EVENTFLAG_SHIFT_DOWN;
        if (GetKeyState(VK_CONTROL) & 0x8000) m |= EVENTFLAG_CONTROL_DOWN;
        if (GetKeyState(VK_MENU) & 0x8000)    m |= EVENTFLAG_ALT_DOWN;
        if (GetKeyState(VK_LBUTTON) & 0x8000) m |= EVENTFLAG_LEFT_MOUSE_BUTTON;
        if (GetKeyState(VK_RBUTTON) & 0x8000) m |= EVENTFLAG_RIGHT_MOUSE_BUTTON;
        return m;
    }
}

bool WebUi::Available()
{
    std::error_code ec;
    return fs::exists(CefDir() / L"libcef.dll", ec) && fs::exists(SubProcess(), ec);
}

bool WebUi::Running()
{
    return g_state.load() == State::Running;
}

bool WebUi::IsOpen()
{
    return g_state.load() == State::Running && g_browser != nullptr;
}

std::string WebUi::Status()
{
    if (!Available())
        return "not installed, expected " + (CefDir() / L"libcef.dll").string();
    switch (g_state.load())
    {
    case State::Running: return g_browser ? "running" : "starting";
    case State::Failed:  return "failed, see modloader/cef.log";
    default:             return g_spent ? "stopped (restart the game to use it again)" : "not started";
    }
}

namespace
{
    // "test" -> file:///C:/.../modloader/web/test.html. Пробелы и скобки в пути игры ломают URL,
    // поэтому кодируем всё, что не буква и не цифра.
    std::string FileUrl(const fs::path& file)
    {
        std::string path = file.generic_string();
        std::string url = "file:///";
        for (unsigned char c : path)
        {
            if (isalnum(c) || strchr("/-_.~:", c))
                url += static_cast<char>(c);
            else
            {
                char hex[4];
                sprintf_s(hex, "%%%02X", c);
                url += hex;
            }
        }
        return url;
    }
}

void WebUi::RequestOpen(const std::string& name)
{
    std::string url = name;
    if (url.find("://") == std::string::npos)
    {
        // Путь к файлу (мод даёт свой) или короткое имя страницы в modloader/web.
        bool absolute = (name.size() > 1 && name[1] == ':') || (!name.empty() && (name[0] == '/' || name[0] == '\\'));
        fs::path file = absolute ? fs::path(name) : ModloaderDir() / L"web" / name;
        if (!file.has_extension())
            file += L".html";
        url = FileUrl(file);
    }
    std::lock_guard lock(g_cmdMutex);
    g_pendingUrl = url;
    g_pendingOpen = true;
    g_pageReady = false;
}

void WebUi::RequestEval(const std::string& javascript)
{
    std::lock_guard lock(g_cmdMutex);
    g_pendingEval.push_back(javascript);
}

void WebUi::RequestClose()
{
    std::lock_guard lock(g_cmdMutex);
    g_pendingClose = true;
}

void WebUi::RequestReload()
{
    std::lock_guard lock(g_cmdMutex);
    g_pendingReload = true;
}

void WebUi::OnFrame(HWND window)
{
    // CEF обязан жить в одном потоке: где подняли, там и качаем сообщения. Во время загрузки карты
    // игра рисует прогресс-бар отдельным потоком, и кадры могут прийти оттуда — это надо видеть.
    static DWORD s_thread = 0;
    DWORD current = GetCurrentThreadId();
    if (current != s_thread)
    {
        if (s_thread != 0)
            LOG_WARN("[web] frames now come from thread %lu instead of %lu", current, s_thread);
        s_thread = current;
    }

    if (g_shutdownRequested.load())
    {
        if (g_state.load() == State::Running)
            ShutdownOnRenderThread();
        g_shutdownRequested = false;
        if (g_shutdownDone)
            SetEvent(g_shutdownDone);
        return;
    }

    std::string url;
    std::vector<std::string> eval;
    bool open = false, close = false, reload = false;
    {
        std::lock_guard lock(g_cmdMutex);
        url.swap(g_pendingUrl);
        if (g_pageReady.load())
            eval.swap(g_pendingEval);
        open = g_pendingOpen;     g_pendingOpen = false;
        close = g_pendingClose;   g_pendingClose = false;
        reload = g_pendingReload; g_pendingReload = false;
    }

    // Закрыть и тут же открыть — значит открыть. Иначе страница, попросившая себя закрыть,
    // отменяет загрузку той, которую игра запросила следом (ERR_ABORTED).
    if (open)
        close = false;

    if (open && g_state.load() == State::Off)
    {
        open = false;
        if (g_spent)
            LOG_WARN("[web] CEF was already stopped in this process — restart the game");
        else if (!Available())
            LOG_ERROR("[web] CEF is not installed: %s", CefDir().string().c_str());
        else if (StartCef())
        {
            g_state = State::Running;
            LOG_INFO("[web] opening %s", url.c_str());
            CreateBrowser(window, url.empty() ? "about:blank" : url);
        }
        else
            g_state = State::Failed;
    }

    if (g_state.load() != State::Running)
        return;

    // Окно, к которому привязан браузер, игра могла уничтожить (выход из партии пересоздаёт окно
    // рендера). Браузер со мёртвым родителем роняет CEF — закрываем его и открываем ту же страницу
    // в текущем окне.
    if (!IsWindow(window))
        return;
    if (g_browser && g_parent && g_parent != window)
    {
        LOG_INFO("[web] render window changed %p -> %p, reopening page", g_parent, window);
        g_reopenUrl = g_browser->GetMainFrame()->GetURL().ToString();
        g_parent = nullptr;
        g_browser->GetHost()->CloseBrowser(true);
    }
    if (!g_browser && !g_reopenUrl.empty() && !open)
    {
        open = true;
        url = g_reopenUrl;
    }
    if (open)
        g_reopenUrl.clear();

    if (!g_browser && open) // вкладку закрывали, а CEF остался поднятым — открываем заново
    {
        LOG_INFO("[web] opening %s", url.c_str());
        CreateBrowser(window, url);
        return;
    }

    if (g_browser)
    {
        if (open && !url.empty())
        {
            LOG_INFO("[web] opening %s", url.c_str());
            g_browser->GetMainFrame()->LoadURL(url);
        }
        if (reload)
            g_browser->ReloadIgnoreCache();
        for (const std::string& code : eval)
            g_browser->GetMainFrame()->ExecuteJavaScript(code, g_browser->GetMainFrame()->GetURL(), 0);
        if (close)
            g_browser->GetHost()->CloseBrowser(false);

        // Разрешение могли поменять — браузер должен перерисоваться под новый размер.
        RECT rc = {};
        GetClientRect(window, &rc);
        int w = (std::max)(16L, rc.right - rc.left);
        int h = (std::max)(16L, rc.bottom - rc.top);
        if (w != g_viewWidth || h != g_viewHeight)
        {
            g_viewWidth = w;
            g_viewHeight = h;
            g_browser->GetHost()->WasResized();
        }
    }

    // Ответы на запросы страницы, посчитанные в потоке игры.
    std::vector<Answer> answers;
    {
        std::lock_guard lock(g_answerMutex);
        answers.swap(g_answers);
    }
    for (const Answer& a : answers)
    {
        if (a.ok)
            a.callback->Success(a.value);
        else
            a.callback->Failure(4, a.value);
    }

    if (GetCurrentThreadId() == g_cefThread)
        CefDoMessageLoopWork();
}

bool WebUi::HasFrame()
{
    if (g_state.load() != State::Running || !g_browser)
        return false;
    std::lock_guard lock(g_frameMutex);
    return !g_pixels.empty();
}

void WebUi::OnContextLost()
{
    std::lock_guard lock(g_frameMutex);
    g_texture = g_popupTexture = 0; // удалять нечего: они принадлежали старому контексту
    g_frameDirty = g_popupDirty = true;
}

unsigned int WebUi::Present(int* width, int* height)
{
    if (!HasFrame())
        return 0;
    std::lock_guard lock(g_frameMutex);
    UploadLayer(g_pixels, g_frameWidth, g_frameHeight, g_frameDirty, g_texture, g_textureWidth, g_textureHeight);
    if (width)  *width = g_textureWidth;
    if (height) *height = g_textureHeight;
    return g_texture;
}

unsigned int WebUi::PresentPopup(int* x, int* y, int* width, int* height)
{
    if (g_state.load() != State::Running || !g_browser)
        return 0;
    std::lock_guard lock(g_frameMutex);
    if (!g_popupVisible || g_popupPixels.empty())
        return 0;
    UploadLayer(g_popupPixels, g_popupWidth, g_popupHeight, g_popupDirty,
                g_popupTexture, g_popupTexWidth, g_popupTexHeight);
    if (x)      *x = g_popupX;
    if (y)      *y = g_popupY;
    if (width)  *width = g_popupTexWidth;
    if (height) *height = g_popupTexHeight;
    return g_popupTexture;
}

bool WebUi::OnWndProc(HWND window, UINT msg, WPARAM wp, LPARAM lp)
{
    if (g_state.load() != State::Running || !g_browser)
        return false;
    CefRefPtr<CefBrowserHost> host = g_browser->GetHost();

    CefMouseEvent mouse;
    mouse.modifiers = Modifiers();

    switch (msg)
    {
    case WM_MOUSEMOVE:
        mouse.x = GET_X_LPARAM(lp);
        mouse.y = GET_Y_LPARAM(lp);
        host->SendMouseMoveEvent(mouse, false);
        return true;

    case WM_LBUTTONDOWN: case WM_LBUTTONUP:
    case WM_RBUTTONDOWN: case WM_RBUTTONUP:
    case WM_MBUTTONDOWN: case WM_MBUTTONUP:
    {
        mouse.x = GET_X_LPARAM(lp);
        mouse.y = GET_Y_LPARAM(lp);
        bool up = (msg == WM_LBUTTONUP || msg == WM_RBUTTONUP || msg == WM_MBUTTONUP);
        CefBrowserHost::MouseButtonType button =
            (msg == WM_LBUTTONDOWN || msg == WM_LBUTTONUP) ? MBT_LEFT :
            (msg == WM_RBUTTONDOWN || msg == WM_RBUTTONUP) ? MBT_RIGHT : MBT_MIDDLE;
        host->SendMouseClickEvent(mouse, button, up, 1);
        return true;
    }

    case WM_MOUSEWHEEL:
    {
        POINT p = { GET_X_LPARAM(lp), GET_Y_LPARAM(lp) };
        ScreenToClient(window, &p); // у колеса координаты экранные, в отличие от остальных
        mouse.x = p.x;
        mouse.y = p.y;
        host->SendMouseWheelEvent(mouse, 0, GET_WHEEL_DELTA_WPARAM(wp));
        return true;
    }

    case WM_KEYDOWN: case WM_KEYUP: case WM_SYSKEYDOWN: case WM_SYSKEYUP:
    case WM_CHAR: case WM_SYSCHAR:
    {
        CefKeyEvent key;
        key.windows_key_code = static_cast<int>(wp);
        key.native_key_code = static_cast<int>(lp);
        key.is_system_key = (msg == WM_SYSKEYDOWN || msg == WM_SYSKEYUP || msg == WM_SYSCHAR);
        key.modifiers = Modifiers();
        if (msg == WM_CHAR || msg == WM_SYSCHAR)
            key.type = KEYEVENT_CHAR;
        else if (msg == WM_KEYDOWN || msg == WM_SYSKEYDOWN)
            key.type = KEYEVENT_RAWKEYDOWN;
        else
            key.type = KEYEVENT_KEYUP;
        host->SendKeyEvent(key);
        return true;
    }

    case WM_SETCURSOR:
        return true;

    default:
        return false;
    }
}

void WebUi::Shutdown()
{
    if (g_state.load() != State::Running)
        return;

    // CefShutdown обязан отработать в том же потоке, что и CefInitialize, — в потоке рендера.
    g_shutdownDone = CreateEventW(nullptr, TRUE, FALSE, nullptr);
    g_shutdownRequested = true;
    if (WaitForSingleObject(g_shutdownDone, 8000) == WAIT_TIMEOUT)
        LOG_WARN("[web] the game is not rendering — CEF was left running");
    CloseHandle(g_shutdownDone);
    g_shutdownDone = nullptr;
}
