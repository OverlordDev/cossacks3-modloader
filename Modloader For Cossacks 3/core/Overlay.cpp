#include "pch.h"
#include "Overlay.h"
#include "GraphicsTab.h"
#include "Console.h"
#include "FrameStats.h"
#include "LuaHost.h"
#include "WebUi.h"

#include "imgui.h"
#include "imgui_impl_opengl2.h"
#include "imgui_impl_win32.h"

#include <GL/gl.h>
#include <atomic>
#include <filesystem>

#pragma comment(lib, "opengl32.lib")

extern IMGUI_IMPL_API LRESULT ImGui_ImplWin32_WndProcHandler(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam);

namespace
{
    // Расширения GL, которые движок может оставить включёнными к концу кадра.
    constexpr GLenum kCurrentProgram = 0x8B8D, kArrayBuffer = 0x8892, kElementArrayBuffer = 0x8893;
    constexpr GLenum kArrayBufferBinding = 0x8894, kElementArrayBufferBinding = 0x8895;
    constexpr GLenum kFramebuffer = 0x8D40, kFramebufferBinding = 0x8CA6;
    constexpr GLenum kTexture0 = 0x84C0, kActiveTexture = 0x84E0, kClientActiveTexture = 0x84E1;
    constexpr GLenum kTexture3D = 0x806F, kTextureCubeMap = 0x8513;

    using UseProgram_t = void(APIENTRY*)(GLuint);
    using BindBuffer_t = void(APIENTRY*)(GLenum, GLuint);
    using ActiveTexture_t = void(APIENTRY*)(GLenum);

    UseProgram_t glUseProgram_ = nullptr;
    BindBuffer_t glBindBuffer_ = nullptr;
    BindBuffer_t glBindFramebuffer_ = nullptr;
    ActiveTexture_t glActiveTexture_ = nullptr;
    ActiveTexture_t glClientActiveTexture_ = nullptr;

    bool g_initialized = false;
    bool g_open = false;
    std::atomic<HWND> g_hwnd = nullptr; // читается из потока модлоадера (RenderWindow)
    WNDPROC g_origProc = nullptr;
    bool g_unicode = false;
    std::string g_iniPath;

    std::atomic<bool> g_shutdownRequested = false;
    HANDLE g_shutdownDone = nullptr;

    // ---------- ввод ----------

    bool IsMouseMessage(UINT msg)
    {
        return (msg >= WM_MOUSEFIRST && msg <= WM_MOUSELAST) || msg == WM_SETCURSOR;
    }

    bool IsKeyboardMessage(UINT msg)
    {
        return msg == WM_KEYDOWN || msg == WM_KEYUP || msg == WM_CHAR || msg == WM_SYSKEYDOWN || msg == WM_SYSKEYUP;
    }

    LRESULT CALLBACK WndProc(HWND wnd, UINT msg, WPARAM wp, LPARAM lp)
    {
        // Пока открыт веб-интерфейс, ввод достаётся ему, а не игре. Меню модлоадера важнее обоих.
        if (!g_open && WebUi::OnWndProc(wnd, msg, wp, lp))
            return msg == WM_SETCURSOR ? TRUE : 0;

        if (g_open && g_initialized)
        {
            ImGui_ImplWin32_WndProcHandler(wnd, msg, wp, lp);
            // Пока меню открыто, мышь не доходит до игры; клавиатура — только если ImGui её забрал (поле ввода).
            if (IsMouseMessage(msg) || (IsKeyboardMessage(msg) && ImGui::GetIO().WantCaptureKeyboard))
                return msg == WM_SETCURSOR ? TRUE : 0;
        }
        return g_unicode ? CallWindowProcW(g_origProc, wnd, msg, wp, lp) : CallWindowProcA(g_origProc, wnd, msg, wp, lp);
    }

    void RestoreWndProc()
    {
        if (!g_hwnd.load() || !g_origProc)
            return;
        if (g_unicode)
            SetWindowLongW(g_hwnd.load(), GWL_WNDPROC, reinterpret_cast<LONG>(g_origProc));
        else
            SetWindowLongA(g_hwnd.load(), GWL_WNDPROC, reinterpret_cast<LONG>(g_origProc));
        g_origProc = nullptr;
    }

    bool GameInForeground()
    {
        DWORD pid = 0;
        HWND fg = GetForegroundWindow();
        GetWindowThreadProcessId(fg, &pid);
        return pid == GetCurrentProcessId() && fg != GetConsoleWindow();
    }

    // ---------- инициализация ----------

    std::filesystem::path ModloaderDir()
    {
        wchar_t exe[MAX_PATH];
        GetModuleFileNameW(nullptr, exe, MAX_PATH);
        return std::filesystem::path(exe).parent_path() / L"modloader";
    }

    void Init(HWND hwnd)
    {
        glUseProgram_ = reinterpret_cast<UseProgram_t>(wglGetProcAddress("glUseProgram"));
        glBindBuffer_ = reinterpret_cast<BindBuffer_t>(wglGetProcAddress("glBindBuffer"));
        glBindFramebuffer_ = reinterpret_cast<BindBuffer_t>(wglGetProcAddress("glBindFramebuffer"));
        glActiveTexture_ = reinterpret_cast<ActiveTexture_t>(wglGetProcAddress("glActiveTexture"));
        glClientActiveTexture_ = reinterpret_cast<ActiveTexture_t>(wglGetProcAddress("glClientActiveTexture"));

        IMGUI_CHECKVERSION();
        ImGui::CreateContext();
        ImGuiIO& io = ImGui::GetIO();
        std::error_code ec;
        std::filesystem::create_directories(ModloaderDir(), ec);
        g_iniPath = (ModloaderDir() / L"imgui.ini").string();
        io.IniFilename = g_iniPath.c_str(); // положение окон — в папке модлоадера, не в корне игры

        // Шрифт с кириллицей (описания модов на русском). Атлас в 1.92 динамический — диапазоны не нужны.
        wchar_t windir[MAX_PATH];
        GetWindowsDirectoryW(windir, MAX_PATH);
        auto font = std::filesystem::path(windir) / L"Fonts" / L"segoeui.ttf";
        if (!std::filesystem::exists(font) || !io.Fonts->AddFontFromFileTTF(font.string().c_str(), 18.0f))
            io.Fonts->AddFontDefault();

        ImGui::StyleColorsDark();
        ImGuiStyle& style = ImGui::GetStyle();
        style.WindowRounding = 6.0f;
        style.FrameRounding = 4.0f;

        ImGui_ImplWin32_Init(hwnd);
        ImGui_ImplOpenGL2_Init();

        g_hwnd = hwnd;
        g_unicode = IsWindowUnicode(hwnd) != FALSE;
        g_origProc = reinterpret_cast<WNDPROC>(g_unicode
            ? SetWindowLongW(hwnd, GWL_WNDPROC, reinterpret_cast<LONG>(WndProc))
            : SetWindowLongA(hwnd, GWL_WNDPROC, reinterpret_cast<LONG>(WndProc)));
        g_initialized = true;
        LOG_INFO("Overlay: ready on render window %p — press Insert in game to open the menu", hwnd);
    }

    void ShutdownOnRenderThread()
    {
        RestoreWndProc();
        if (g_initialized)
        {
            ImGui_ImplOpenGL2_Shutdown();
            ImGui_ImplWin32_Shutdown();
            ImGui::DestroyContext();
            g_initialized = false;
        }
    }

    // ---------- интерфейс ----------

    ImVec4 StatusColor(LuaHost::ModStatus s)
    {
        switch (s)
        {
        case LuaHost::ModStatus::Loaded: return ImVec4(0.4f, 0.9f, 0.4f, 1.0f);
        case LuaHost::ModStatus::Error:  return ImVec4(1.0f, 0.4f, 0.4f, 1.0f);
        default:                         return ImVec4(0.6f, 0.6f, 0.6f, 1.0f);
        }
    }

    const char* StatusText(LuaHost::ModStatus s)
    {
        switch (s)
        {
        case LuaHost::ModStatus::Loaded: return "loaded";
        case LuaHost::ModStatus::Error:  return "error";
        default:                         return "disabled";
        }
    }

    void DrawModsTab()
    {
        auto mods = LuaHost::Mods();

        if (ImGui::Button("Reload Lua mods"))
            LuaHost::Reload();
        ImGui::SameLine();
        ImGui::TextDisabled("modloader\\mods\\<folder>\\manifest.lua");

        static std::string selected;
        ImGuiTableFlags flags = ImGuiTableFlags_RowBg | ImGuiTableFlags_BordersInnerH | ImGuiTableFlags_ScrollY |
                                ImGuiTableFlags_SizingStretchProp;
        float tableHeight = ImGui::GetContentRegionAvail().y * 0.6f;
        if (ImGui::BeginTable("mods", 5, flags, ImVec2(0, tableHeight)))
        {
            ImGui::TableSetupScrollFreeze(0, 1);
            ImGui::TableSetupColumn("On", ImGuiTableColumnFlags_WidthFixed, 32.0f);
            ImGui::TableSetupColumn("Mod", ImGuiTableColumnFlags_WidthStretch, 3.0f);
            ImGui::TableSetupColumn("Version", ImGuiTableColumnFlags_WidthStretch, 1.0f);
            ImGui::TableSetupColumn("Author", ImGuiTableColumnFlags_WidthStretch, 1.5f);
            ImGui::TableSetupColumn("Status", ImGuiTableColumnFlags_WidthStretch, 1.0f);
            ImGui::TableHeadersRow();

            for (const auto& m : mods)
            {
                std::string key = m.id.empty() ? m.folder : m.id;
                ImGui::PushID(key.c_str());
                ImGui::TableNextRow();

                ImGui::TableNextColumn();
                bool on = m.status != LuaHost::ModStatus::Disabled;
                if (m.id.empty())
                    ImGui::BeginDisabled(); // манифест не прочитался — переключать нечего
                if (ImGui::Checkbox("##on", &on))
                    LuaHost::SetModEnabled(m.id, on);
                if (m.id.empty())
                    ImGui::EndDisabled();

                ImGui::TableNextColumn();
                std::string label = (m.name.empty() ? m.folder : m.name) + "##sel";
                if (ImGui::Selectable(label.c_str(), selected == key))
                    selected = key;

                ImGui::TableNextColumn();
                ImGui::TextUnformatted(m.version.c_str());
                ImGui::TableNextColumn();
                ImGui::TextUnformatted(m.author.c_str());
                ImGui::TableNextColumn();
                ImGui::TextColored(StatusColor(m.status), "%s", StatusText(m.status));
                ImGui::PopID();
            }
            ImGui::EndTable();
        }

        if (mods.empty())
            ImGui::TextDisabled("No mods found. Put a mod folder with manifest.lua into modloader\\mods.");

        for (const auto& m : mods)
        {
            if ((m.id.empty() ? m.folder : m.id) != selected)
                continue;
            ImGui::SeparatorText((m.name.empty() ? m.folder : m.name).c_str());
            ImGui::Text("id: %s    folder: %s", m.id.c_str(), m.folder.c_str());
            ImGui::Text("scripts: %s    multiplayer: %s", m.sides.c_str(), m.multiplayer.c_str());
            if (!m.description.empty())
                ImGui::TextWrapped("%s", m.description.c_str());
            if (!m.error.empty())
                ImGui::TextColored(StatusColor(LuaHost::ModStatus::Error), "Error: %s", m.error.c_str());
        }
    }

    void DrawUi()
    {
        ImGui::SetNextWindowSize(ImVec2(680, 460), ImGuiCond_FirstUseEver);
        ImGui::SetNextWindowPos(ImVec2(60, 60), ImGuiCond_FirstUseEver);
        if (ImGui::Begin("Cossacks 3 Modloader", &g_open))
        {
            ImGui::TextDisabled("Insert - close menu   |   %.0f FPS", ImGui::GetIO().Framerate);
            if (ImGui::BeginTabBar("tabs"))
            {
                if (ImGui::BeginTabItem("Mods"))
                {
                    DrawModsTab();
                    ImGui::EndTabItem();
                }
                if (ImGui::BeginTabItem("Graphics"))
                {
                    GraphicsTab::Draw();
                    ImGui::EndTabItem();
                }
                ImGui::EndTabBar();
            }
        }
        ImGui::End();
    }

    // ---------- отрисовка ----------

    void RenderFrame()
    {
        // Сохраняем и нейтрализуем то, что движок мог оставить к концу кадра (шейдер, VBO, FBO, доп. текстурные
        // блоки, туман, матрицу текстуры) — бэкенд OpenGL2 рассчитан на чистый фиксированный конвейер.
        GLint program = 0, arrayBuffer = 0, elementBuffer = 0, framebuffer = 0;
        GLint activeTexture = kTexture0, clientActiveTexture = kTexture0;
        if (glUseProgram_) glGetIntegerv(kCurrentProgram, &program);
        if (glBindBuffer_)
        {
            glGetIntegerv(kArrayBufferBinding, &arrayBuffer);
            glGetIntegerv(kElementArrayBufferBinding, &elementBuffer);
        }
        if (glBindFramebuffer_) glGetIntegerv(kFramebufferBinding, &framebuffer);
        if (glActiveTexture_) glGetIntegerv(kActiveTexture, &activeTexture);
        if (glClientActiveTexture_) glGetIntegerv(kClientActiveTexture, &clientActiveTexture);

        glPushAttrib(GL_ALL_ATTRIB_BITS);
        glPushClientAttrib(GL_CLIENT_ALL_ATTRIB_BITS);

        if (glUseProgram_) glUseProgram_(0);
        if (glBindBuffer_)
        {
            glBindBuffer_(kArrayBuffer, 0);
            glBindBuffer_(kElementArrayBuffer, 0);
        }
        if (glBindFramebuffer_) glBindFramebuffer_(kFramebuffer, 0);
        if (glActiveTexture_)
        {
            for (GLenum unit = 1; unit < 4; ++unit)
            {
                glActiveTexture_(kTexture0 + unit);
                glDisable(GL_TEXTURE_1D);
                glDisable(GL_TEXTURE_2D);
                glDisable(kTexture3D);
                glDisable(kTextureCubeMap);
            }
            glActiveTexture_(kTexture0);
        }
        if (glClientActiveTexture_) glClientActiveTexture_(kTexture0);
        glDisable(GL_FOG);
        glDisable(GL_ALPHA_TEST);
        glDisable(GL_TEXTURE_GEN_S);
        glDisable(GL_TEXTURE_GEN_T);
        glDisable(GL_TEXTURE_GEN_R);
        glDisable(GL_TEXTURE_GEN_Q);
        glColorMask(GL_TRUE, GL_TRUE, GL_TRUE, GL_TRUE);
        glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_MODULATE);
        glMatrixMode(GL_TEXTURE);
        glPushMatrix();
        glLoadIdentity();
        glMatrixMode(GL_MODELVIEW);

        ImGui_ImplOpenGL2_NewFrame();
        ImGui_ImplWin32_NewFrame();
        ImGui::NewFrame();
        ImGui::GetIO().MouseDrawCursor = true; // курсор игры может быть своим/скрытым

        // Кадр браузера — в самый низ списка отрисовки, под меню модлоадера. Рисуем его здесь,
        // а не своим кодом: тут состояние OpenGL уже приведено в порядок и будет восстановлено.
        int webW = 0, webH = 0;
        if (unsigned int tex = WebUi::Present(&webW, &webH))
        {
            ImVec2 size = ImGui::GetIO().DisplaySize;
            ImDrawList* layer = ImGui::GetBackgroundDrawList();
            layer->AddImage(static_cast<ImTextureID>(tex), ImVec2(0, 0), size);

            // Выпадающий список страницы — отдельным слоем поверх неё, в точке, которую назвал CEF.
            int px = 0, py = 0, pw = 0, ph = 0;
            if (unsigned int popup = WebUi::PresentPopup(&px, &py, &pw, &ph))
            {
                ImVec2 at(static_cast<float>(px), static_cast<float>(py));
                layer->AddImage(static_cast<ImTextureID>(popup), at,
                                ImVec2(at.x + static_cast<float>(pw), at.y + static_cast<float>(ph)));
            }
        }

        if (g_open)
            DrawUi();
        ImGui::Render();
        ImGui_ImplOpenGL2_RenderDrawData(ImGui::GetDrawData());

        glMatrixMode(GL_TEXTURE);
        glPopMatrix();
        glMatrixMode(GL_MODELVIEW);

        glPopClientAttrib();
        glPopAttrib();
        if (glActiveTexture_) glActiveTexture_(activeTexture);
        if (glClientActiveTexture_) glClientActiveTexture_(clientActiveTexture);
        if (glBindFramebuffer_) glBindFramebuffer_(kFramebuffer, framebuffer);
        if (glBindBuffer_)
        {
            glBindBuffer_(kArrayBuffer, arrayBuffer);
            glBindBuffer_(kElementArrayBuffer, elementBuffer);
        }
        if (glUseProgram_) glUseProgram_(program);
    }
}

void Overlay::OnSwapBuffers(HDC dc)
{
    if (g_shutdownRequested)
    {
        ShutdownOnRenderThread();
        if (g_shutdownDone)
            SetEvent(g_shutdownDone);
        return;
    }

    if (!g_initialized)
    {
        HWND hwnd = WindowFromDC(dc);
        if (!hwnd)
            return;
        Init(hwnd);
    }

    // Игра может пересоздать контекст OpenGL (при загрузке партии — новый DC и контекст).
    // Текстуры ImGui и страницы остались в старом: без пересоздания слой просто не виден.
    static HGLRC lastContext = nullptr;
    HGLRC context = wglGetCurrentContext();
    if (lastContext && context != lastContext)
    {
        for (ImTextureData* tex : ImGui::GetPlatformIO().Textures)
        {
            if (tex->Status == ImTextureStatus_Destroyed)
                continue;
            tex->SetTexID(ImTextureID_Invalid);
            tex->SetStatus(ImTextureStatus_WantCreate);
        }
        WebUi::OnContextLost();
        LOG_INFO("Overlay: OpenGL context changed (%p -> %p), textures recreated", lastContext, context);
    }
    lastContext = context;

    // Игра может рисовать в другое окно (при загрузке партии — новый DC). ImGui берёт размер экрана
    // и ввод из окна, с которым его запустили: со старым окном слой получает нулевой размер.
    HWND window = WindowFromDC(dc);
    if (window && window != g_hwnd.load())
    {
        HWND old = g_hwnd.load();
        RestoreWndProc();
        ImGui_ImplWin32_Shutdown();
        ImGui_ImplWin32_Init(window);
        g_hwnd = window;
        g_unicode = IsWindowUnicode(window) != FALSE;
        g_origProc = reinterpret_cast<WNDPROC>(g_unicode
            ? SetWindowLongW(window, GWL_WNDPROC, reinterpret_cast<LONG>(WndProc))
            : SetWindowLongA(window, GWL_WNDPROC, reinterpret_cast<LONG>(WndProc)));
        LOG_INFO("Overlay: render window changed %p -> %p", old, window);
    }

    GraphicsTab::Tick();

    // Веб-слой рисуется под меню модлоадера: оно должно оставаться сверху.
    WebUi::OnFrame(g_hwnd.load());

    // Insert — открыть/закрыть (опрос, т.к. фокус клавиатуры может быть не у окна рендера).
    static bool insertWasDown = false;
    bool insertDown = (GetAsyncKeyState(VK_INSERT) & 0x8000) != 0;
    if (insertDown && !insertWasDown && GameInForeground())
        g_open = !g_open;
    insertWasDown = insertDown;

    // Бинды клиентских Lua-скриптов: только когда играют, а не работают с меню.
    LuaHost::PollInput(!g_open && GameInForeground());

    bool draw = g_open || WebUi::HasFrame();
    if (draw)
        RenderFrame();

    // Диагностика веб-слоя: пока страница открыта, раз в 3 с — сколько кадров игра показала и
    // сколько из них мы накрыли страницей. Так видно, когда игра рисует мимо нашего хука.
    static ULONGLONG lastReport = 0;
    static int swaps = 0, drawn = 0;
    static HDC lastDc = nullptr;
    ++swaps;
    drawn += draw ? 1 : 0;
    ULONGLONG now = GetTickCount64();
    if (now - lastReport >= 3000)
    {
        if (WebUi::IsOpen() || dc != lastDc)
        {
            GLint viewport[4] = {}, drawBuffer = 0, fbo = 0;
            glGetIntegerv(GL_VIEWPORT, viewport);
            glGetIntegerv(GL_DRAW_BUFFER, &drawBuffer);
            if (glBindFramebuffer_) glGetIntegerv(kFramebufferBinding, &fbo);
            ImVec2 size = ImGui::GetIO().DisplaySize;
            LOG_INFO("[web] overlay: %d swap(s), %d drawn, page frame %s, dc %p%s, wnd %p, display %.0fx%.0f, "
                     "viewport %dx%d, drawbuf %X, fbo %d, thread %lu", swaps, drawn,
                     WebUi::HasFrame() ? "yes" : "no", dc, dc != lastDc ? " (new)" : "", WindowFromDC(dc),
                     size.x, size.y, viewport[2], viewport[3], drawBuffer, fbo, GetCurrentThreadId());
        }
        lastDc = dc;
        lastReport = now;
        swaps = drawn = 0;
    }
}

void Overlay::Shutdown()
{
    if (!g_initialized)
        return;
    g_shutdownDone = CreateEventW(nullptr, TRUE, FALSE, nullptr);
    g_shutdownRequested = true;
    if (WaitForSingleObject(g_shutdownDone, 1500) == WAIT_TIMEOUT)
    {
        // Игра не рисует кадры (свёрнута) — GL-ресурсы освободить негде, оставляем их; главное — вернуть WndProc.
        RestoreWndProc();
        LOG_WARN("Overlay: game is not rendering — GL resources of the menu were left allocated");
    }
    CloseHandle(g_shutdownDone);
    g_shutdownDone = nullptr;
}

HWND Overlay::RenderWindow()
{
    return g_hwnd.load();
}
