// Экран загрузки на время запуска игры.
//
// Игра стартует долго, и первые секунд десять-пятнадцать у неё нет даже окна — рисовать внутри
// игры в это время нечем. Поэтому картинку показывает лаунчер: он живёт с самого начала.
//
// Убирается экран не по таймеру, а по сигналу: модлоадер, дойдя до главного меню, взводит
// именованное событие. Если модлоадер не поднялся, срабатывает запасной таймаут.
#include "Splash.h"

#include <gdiplus.h>
#include <string>

#pragma comment(lib, "gdiplus.lib")

namespace
{
    constexpr wchar_t kClassName[] = L"Cossacks3ModloaderSplash";
    constexpr int kWidth = 720;
    constexpr int kHeight = 405; // 16:9 под обычную иллюстрацию
    constexpr UINT_PTR kTimerId = 1;
    constexpr UINT kTickMs = 120;

    ULONG_PTR g_gdiplus = 0;
    Gdiplus::Image* g_image = nullptr;
    HWND g_window = nullptr;
    HANDLE g_ready = nullptr;
    DWORD g_started = 0;
    DWORD g_timeoutMs = 90000;
    HANDLE g_process = nullptr;
    int g_frame = 0;

    // Картинку берём из папки модлоадера; нет — обойдёмся тёмным фоном.
    Gdiplus::Image* LoadSplashImage(const std::wstring& gameDir)
    {
        for (const wchar_t* name : { L"modloader\\splash.png", L"modloader\\splash.jpg" })
        {
            std::wstring path = gameDir + name;
            if (GetFileAttributesW(path.c_str()) == INVALID_FILE_ATTRIBUTES)
                continue;
            auto* image = Gdiplus::Image::FromFile(path.c_str());
            if (image && image->GetLastStatus() == Gdiplus::Ok)
                return image;
            delete image;
        }
        return nullptr;
    }

    void Paint(HWND window)
    {
        PAINTSTRUCT ps;
        HDC dc = BeginPaint(window, &ps);

        RECT rc;
        GetClientRect(window, &rc);

        // Рисуем в память: иначе мигает при каждой смене точек.
        HDC memDc = CreateCompatibleDC(dc);
        HBITMAP bitmap = CreateCompatibleBitmap(dc, rc.right, rc.bottom);
        HGDIOBJ old = SelectObject(memDc, bitmap);

        Gdiplus::Graphics g(memDc);
        g.SetInterpolationMode(Gdiplus::InterpolationModeHighQualityBicubic);
        g.SetTextRenderingHint(Gdiplus::TextRenderingHintAntiAlias);

        Gdiplus::SolidBrush back(Gdiplus::Color(255, 16, 14, 11));
        g.FillRectangle(&back, 0, 0, rc.right, rc.bottom);

        if (g_image)
        {
            // Заполняем окно целиком, лишнее по краям обрезаем — без искажения пропорций.
            float scale = max(static_cast<float>(rc.right) / g_image->GetWidth(),
                              static_cast<float>(rc.bottom) / g_image->GetHeight());
            float w = g_image->GetWidth() * scale;
            float h = g_image->GetHeight() * scale;
            g.DrawImage(g_image, (rc.right - w) / 2, (rc.bottom - h) / 2, w, h);
        }

        // Затемнение снизу, чтобы текст читался на любой картинке.
        Gdiplus::LinearGradientBrush shade(
            Gdiplus::Rect(0, rc.bottom - 110, rc.right, 110),
            Gdiplus::Color(0, 0, 0, 0), Gdiplus::Color(215, 0, 0, 0),
            Gdiplus::LinearGradientModeVertical);
        g.FillRectangle(&shade, 0, rc.bottom - 110, rc.right, 110);

        std::wstring dots(1 + (g_frame / 4) % 3, L'.');
        std::wstring text = L"Загрузка" + dots;

        Gdiplus::FontFamily family(L"Georgia");
        Gdiplus::Font font(&family, 20, Gdiplus::FontStyleRegular, Gdiplus::UnitPixel);
        Gdiplus::SolidBrush gold(Gdiplus::Color(255, 255, 220, 170));
        Gdiplus::SolidBrush shadow(Gdiplus::Color(200, 0, 0, 0));
        Gdiplus::PointF at(34.0f, static_cast<float>(rc.bottom) - 56.0f);

        g.DrawString(text.c_str(), -1, &font, Gdiplus::PointF(at.X + 1, at.Y + 1), &shadow);
        g.DrawString(text.c_str(), -1, &font, at, &gold);

        // Рамка.
        Gdiplus::Pen edge(Gdiplus::Color(255, 107, 86, 54), 2);
        g.DrawRectangle(&edge, 1, 1, rc.right - 2, rc.bottom - 2);

        BitBlt(dc, 0, 0, rc.right, rc.bottom, memDc, 0, 0, SRCCOPY);
        SelectObject(memDc, old);
        DeleteObject(bitmap);
        DeleteDC(memDc);
        EndPaint(window, &ps);
    }

    bool ShouldClose()
    {
        if (g_ready && WaitForSingleObject(g_ready, 0) == WAIT_OBJECT_0)
            return true; // модлоадер дошёл до меню
        if (g_process && WaitForSingleObject(g_process, 0) == WAIT_OBJECT_0)
            return true; // игра закрылась, не дойдя до меню
        return GetTickCount() - g_started > g_timeoutMs;
    }

    LRESULT CALLBACK WndProc(HWND window, UINT msg, WPARAM wp, LPARAM lp)
    {
        switch (msg)
        {
        case WM_PAINT:
            Paint(window);
            return 0;
        case WM_TIMER:
            if (wp == kTimerId)
            {
                ++g_frame;
                if (ShouldClose())
                    DestroyWindow(window);
                else
                    InvalidateRect(window, nullptr, FALSE);
            }
            return 0;
        case WM_ERASEBKGND:
            return 1; // фон рисуем сами
        case WM_DESTROY:
            PostQuitMessage(0);
            return 0;
        default:
            return DefWindowProcW(window, msg, wp, lp);
        }
    }
}

HANDLE Splash::CreateReadyEvent()
{
    // Создаём до запуска игры: модлоадер внутри неё откроет событие по этому же имени.
    return CreateEventW(nullptr, TRUE, FALSE, Splash::kReadyEventName);
}

void Splash::Run(HINSTANCE instance, const std::wstring& gameDir, HANDLE ready, HANDLE process,
                 DWORD timeoutMs)
{
    g_ready = ready;
    g_process = process;
    g_timeoutMs = timeoutMs;
    g_started = GetTickCount();
    g_frame = 0;

    Gdiplus::GdiplusStartupInput input;
    if (Gdiplus::GdiplusStartup(&g_gdiplus, &input, nullptr) != Gdiplus::Ok)
        return;
    g_image = LoadSplashImage(gameDir);

    WNDCLASSEXW wc = { sizeof(wc) };
    wc.lpfnWndProc = WndProc;
    wc.hInstance = instance;
    wc.lpszClassName = kClassName;
    wc.hCursor = LoadCursorW(nullptr, IDC_WAIT);
    RegisterClassExW(&wc);

    int x = (GetSystemMetrics(SM_CXSCREEN) - kWidth) / 2;
    int y = (GetSystemMetrics(SM_CYSCREEN) - kHeight) / 2;
    g_window = CreateWindowExW(WS_EX_TOOLWINDOW | WS_EX_TOPMOST, kClassName, L"Cossacks 3",
                               WS_POPUP, x, y, kWidth, kHeight, nullptr, nullptr, instance, nullptr);
    if (!g_window)
        return;

    ShowWindow(g_window, SW_SHOW);
    UpdateWindow(g_window);
    SetTimer(g_window, kTimerId, kTickMs, nullptr);

    MSG msg;
    while (GetMessageW(&msg, nullptr, 0, 0) > 0)
    {
        TranslateMessage(&msg);
        DispatchMessageW(&msg);
    }

    delete g_image;
    g_image = nullptr;
    Gdiplus::GdiplusShutdown(g_gdiplus);
    UnregisterClassW(kClassName, instance);
    g_window = nullptr;
}
