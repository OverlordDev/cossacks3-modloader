#pragma once

// Строки игры — ANSI (системная кодовая страница), консоль и Lua — UTF-8.
namespace Text
{
    inline std::string Convert(const std::string& s, UINT from, UINT to)
    {
        if (s.empty())
            return {};
        int wlen = MultiByteToWideChar(from, 0, s.data(), static_cast<int>(s.size()), nullptr, 0);
        std::wstring w(wlen, L'\0');
        MultiByteToWideChar(from, 0, s.data(), static_cast<int>(s.size()), w.data(), wlen);
        int len = WideCharToMultiByte(to, 0, w.data(), wlen, nullptr, 0, nullptr, nullptr);
        std::string out(len, '\0');
        WideCharToMultiByte(to, 0, w.data(), wlen, out.data(), len, nullptr, nullptr);
        return out;
    }

    inline std::string AnsiToUtf8(const std::string& s) { return Convert(s, CP_ACP, CP_UTF8); }
    inline std::string Utf8ToAnsi(const std::string& s) { return Convert(s, CP_UTF8, CP_ACP); }
}
