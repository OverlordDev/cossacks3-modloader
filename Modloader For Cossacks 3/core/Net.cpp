#include "pch.h"
#include "Net.h"
#include "Console.h"
#include "Events.h"
#include "Game.h"
#include "NativeCall.h"
#include "ScriptRunner.h"

namespace
{
    constexpr char kParserName[] = "ModLoader.Net";
    constexpr size_t kMaxData = 8 * 1024;

    Net::Receiver g_receiver;

    // ---------- вызовы нативов ----------

    bool Invoke(const char* name, const std::vector<NativeCall::Value>& args, NativeCall::Value* result = nullptr)
    {
        const NativeCall::Signature* sig = NativeCall::Find(name);
        if (!sig || !sig->error.empty())
        {
            LOG_ERROR("Net: native %s unavailable", name);
            return false;
        }
        NativeCall::Value r;
        std::string error;
        if (!NativeCall::Invoke(*sig, args, result ? result : &r, &error))
        {
            LOG_ERROR("Net: %s: %s", name, error.c_str());
            return false;
        }
        return true;
    }

    NativeCall::Value Int(int v) { NativeCall::Value x; x.type = NativeCall::Type::Int; x.i = v; return x; }
    NativeCall::Value Str(const std::string& v) { NativeCall::Value x; x.type = NativeCall::Type::String; x.s = v; return x; }

    int CallInt(const char* name)
    {
        NativeCall::Value r;
        return Invoke(name, {}, &r) ? r.i : 0;
    }

    // ---------- кодирование: значение парсера — строка без \0, пробелов по краям и переводов строк ----------

    std::string Escape(const std::string& s)
    {
        static const char hex[] = "0123456789ABCDEF";
        std::string out;
        for (unsigned char c : s)
        {
            if (c <= 0x20 || c == '%' || c >= 0x7F)
            {
                out += '%';
                out += hex[c >> 4];
                out += hex[c & 15];
            }
            else
                out += static_cast<char>(c);
        }
        return out;
    }

    std::string Unescape(const std::string& s)
    {
        std::string out;
        for (size_t i = 0; i < s.size(); ++i)
        {
            if (s[i] == '%' && i + 2 < s.size() && isxdigit(static_cast<unsigned char>(s[i + 1])) &&
                isxdigit(static_cast<unsigned char>(s[i + 2])))
            {
                out += static_cast<char>(std::stoi(s.substr(i + 1, 2), nullptr, 16));
                i += 2;
            }
            else
                out += s[i];
        }
        return out;
    }

    // ---------- отправка ----------

    bool SendPacket(char direction, const std::string& mod, const std::string& event, const std::string& data)
    {
        NativeCall::Value handle;
        if (!Invoke("ParserSelectByKey", { Str(kParserName) }, &handle))
            return false;
        if (handle.i == 0 && !Invoke("ParserCreate", { Str(kParserName) }, &handle))
            return false;
        if (handle.i == 0)
            return false;

        Invoke("ParserClearByHandle", { Int(handle.i) });
        const std::pair<const char*, std::string> fields[] = {
            { "v", "1" }, { "k", std::string(1, direction) }, { "m", Escape(mod) }, { "e", Escape(event) }, { "d", Escape(data) },
        };
        for (const auto& [key, value] : fields)
            Invoke("ParserSetValueByKeyByHandle", { Int(handle.i), Str(key), Str(value) });
        return Invoke("LanSendParser", { Int(Net::kPacketType), Int(handle.i) });
    }

    // Локальная доставка — в следующем такте, как если бы пакет пришёл по сети.
    void DeliverLocal(char direction, const std::string& mod, const std::string& event, const std::string& data)
    {
        int from = Game::MyLanId();
        ScriptRunner::RunOnGameThread([=] {
            if (g_receiver)
                g_receiver(direction, mod, event, data, from);
        });
    }

    bool CheckSize(const std::string& data, std::string* error)
    {
        if (data.size() <= kMaxData)
            return true;
        *error = "message is too large (" + std::to_string(data.size()) + " bytes, max " + std::to_string(kMaxData) + ")";
        return false;
    }

    // ---------- приём ----------

    void OnPacket(const std::string&, const std::string&)
    {
        NativeCall::Value handle;
        if (!Invoke("LanSelectParser", {}, &handle) || handle.i == 0)
            return;

        auto get = [&](const char* key) {
            NativeCall::Value v;
            Invoke("ParserGetValueByKeyByHandle", { Int(handle.i), Str(key) }, &v);
            return v.s;
        };
        std::string version = get("v"), direction = get("k");
        int from = CallInt("LanPublicServerGetRegIDFrom");
        if (version != "1" || direction.size() != 1)
        {
            LOG_WARN("Net: malformed mod packet from %d", from);
            return;
        }
        if (from != 0 && from == Game::MyLanId())
            return; // своё же сообщение, уже доставлено локально

        // 's' обрабатывает только хост, 'c' — только клиенты (хост свои доставил себе сам).
        Game::LanMode mode = Game::Mode();
        if ((direction[0] == 's' && mode != Game::LanMode::Server) || (direction[0] == 'c' && mode != Game::LanMode::Client))
            return;

        if (g_receiver)
            g_receiver(direction[0], Unescape(get("m")), Unescape(get("e")), Unescape(get("d")), from);
    }
}

void Net::Install(Receiver receiver)
{
    g_receiver = std::move(receiver);

    // Наш тип пакета: сообщаем модлоадеру и выходим, чтобы игра не обрабатывала его сама.
    Events::HookGuiStateCode("OnLanEvent", "net.msg",
        "if ((gLanEvent=leParser) or (gLanEvent=leSessionParser)) and (LanGetParserID=" + std::to_string(kPacketType) +
        ") then begin DScriptSetgDbgString0('ML:net.msg'); exit; end;");
    Events::HookGuiStateCode("OnLanEvent", "net.connect",
        "if (gLanEvent=leConnect) then DScriptSetgDbgString0('ML:net.connect|'+IntToStr(GetIntValueByName('Tag')));");
    Events::HookGuiStateCode("OnLanEvent", "net.disconnect",
        "if (gLanEvent=leDisconnect) then DScriptSetgDbgString0('ML:net.disconnect|'+IntToStr(GetIntValueByName('Tag')));");

    Events::Subscribe("net.msg", OnPacket);
}

bool Net::SendToServer(const std::string& mod, const std::string& event, const std::string& data, std::string* error)
{
    if (!CheckSize(data, error))
        return false;
    if (Game::Mode() == Game::LanMode::Client)
        return SendPacket('s', mod, event, data) || (*error = "LanSendParser failed", false);
    DeliverLocal('s', mod, event, data); // одиночная игра или хост: сервер — это мы
    return true;
}

bool Net::Broadcast(const std::string& mod, const std::string& event, const std::string& data, std::string* error)
{
    if (!CheckSize(data, error))
        return false;
    Game::LanMode mode = Game::Mode();
    if (mode == Game::LanMode::Client)
        return *error = "only the host can broadcast", false;
    if (mode == Game::LanMode::Server && !SendPacket('c', mod, event, data))
        return *error = "LanSendParser failed", false;
    DeliverLocal('c', mod, event, data); // клиентские скрипты хоста / одиночной игры
    return true;
}
