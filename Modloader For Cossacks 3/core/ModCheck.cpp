#include "pch.h"
#include "ModCheck.h"
#include "Console.h"
#include "Events.h"
#include "Game.h"
#include "LuaHost.h"
#include "NativeCall.h"
#include "Net.h"

#include <map>
#include <set>
#include <sstream>

namespace
{
    constexpr ULONGLONG kAnswerMs = 6000;  // сколько ждать ответа клиента
    constexpr ULONGLONG kAskEveryMs = 1500; // как часто переспрашивать, пока не ответил
    constexpr ULONGLONG kCheckEveryMs = 1000;

    struct Client
    {
        ULONGLONG firstSeen = 0;
        ULONGLONG lastAsked = 0;
        bool verified = false;
        bool kicked = false;
    };

    std::map<int, Client> g_clients; // хост: lan id -> состояние проверки
    ULONGLONG g_lastCheck = 0;
    bool g_hostAsked = false;        // клиент: хост нас спрашивал
    ULONGLONG g_joinedAt = 0;        // клиент: когда оказались в комнате
    bool g_warnedNoHost = false;

    // ---------- нативы ----------

    NativeCall::Value Int(int v) { NativeCall::Value x; x.type = NativeCall::Type::Int; x.i = v; return x; }

    NativeCall::Value Call(const char* name, const std::vector<NativeCall::Value>& args = {})
    {
        NativeCall::Value r;
        if (const NativeCall::Signature* sig = NativeCall::Find(name))
        {
            std::string error;
            NativeCall::Invoke(*sig, args, &r, &error);
        }
        return r;
    }

    std::string ClientName(int id)
    {
        int count = Call("LanGetClientsCount").i;
        for (int i = 0; i < count; ++i)
            if (Call("LanGetClientIDByIndex", { Int(i) }).i == id)
                return Call("LanGetClientNameByIndex", { Int(i) }).s;
        return "#" + std::to_string(id);
    }

    // ---------- отпечаток ----------

    // "id version hash;..." — по порядку id; пусто, если модов, влияющих на партию, нет.
    // Отпечаток читает файлы модов с диска — не чаще раза в 10 секунд (моды правят редко).
    std::string Fingerprint()
    {
        static std::string cached;
        static ULONGLONG at = 0;
        if (at && GetTickCount64() - at < 10000)
            return cached;
        at = GetTickCount64();
        std::ostringstream out;
        for (const LuaHost::MultiplayerMod& m : LuaHost::MultiplayerMods())
            out << m.id << ' ' << m.version << ' ' << m.hash << ';';
        cached = out.str();
        return cached;
    }

    std::map<std::string, std::string> Parse(const std::string& fp) // id -> "version hash"
    {
        std::map<std::string, std::string> out;
        std::istringstream in(fp);
        std::string item;
        while (std::getline(in, item, ';'))
        {
            size_t sp = item.find(' ');
            if (sp != std::string::npos)
                out[item.substr(0, sp)] = item.substr(sp + 1);
        }
        return out;
    }

    // Понятное объяснение разницы: чего не хватает, что лишнее, что другой версии.
    std::string Explain(const std::string& host, const std::string& client)
    {
        auto h = Parse(host), c = Parse(client);
        std::string missing, extra, differ;
        for (const auto& [id, v] : h)
        {
            auto it = c.find(id);
            if (it == c.end())
                missing += (missing.empty() ? "" : ", ") + id;
            else if (it->second != v)
                differ += (differ.empty() ? "" : ", ") + id;
        }
        for (const auto& [id, v] : c)
            if (!h.count(id))
                extra += (extra.empty() ? "" : ", ") + id;
        std::string out;
        if (!missing.empty()) out += "нет модов: " + missing + ". ";
        if (!extra.empty()) out += "лишние моды: " + extra + ". ";
        if (!differ.empty()) out += "другая версия или файлы: " + differ + ". ";
        return out.empty() ? "наборы модов различаются" : out;
    }

    void Send(char direction, const std::string& event, const std::string& data)
    {
        std::string error;
        bool ok = direction == 's' ? Net::SendToServer(ModCheck::kModId, event, data, &error)
                                   : Net::Broadcast(ModCheck::kModId, event, data, &error);
        if (!ok)
            LOG_WARN("[modcheck] cannot send %s: %s", event.c_str(), error.c_str());
    }

    void Kick(int id, Client& c, const std::string& reason)
    {
        c.kicked = true;
        std::string name = ClientName(id);
        LOG_WARN("[modcheck] %s не пущен в комнату: %s", name.c_str(), reason.c_str());
        Send('c', "modcheck.kick", std::to_string(id) + "|" + reason); // модлоадер у клиента покажет причину
        Call("LanKillClient", { Int(id) });
    }

    // ---------- хост ----------

    void HostTick()
    {
        ULONGLONG now = GetTickCount64();
        int me = Game::MyLanId();
        std::set<int> present;
        int count = Call("LanGetClientsCount").i;
        for (int i = 0; i < count; ++i)
        {
            int id = Call("LanGetClientIDByIndex", { Int(i) }).i;
            if (id == 0 || id == me)
                continue;
            present.insert(id);
            Client& c = g_clients[id];
            if (!c.firstSeen)
            {
                c.firstSeen = now;
                LOG_INFO("[modcheck] в комнату зашёл %s — сверяю моды", ClientName(id).c_str());
            }
            if (c.verified || c.kicked)
                continue;
            // Без модов, влияющих на партию, играть можно и с чистой игрой — выгоняем за молчание,
            // только если моды у нас есть.
            if (now - c.firstSeen > kAnswerMs && !Fingerprint().empty())
            {
                Kick(id, c, "нет ответа — у игрока нет модлоадера (чистая игра), а в комнате нужны моды");
                continue;
            }
            if (now - c.lastAsked >= kAskEveryMs)
            {
                c.lastAsked = now;
                Send('c', "modcheck.req", std::to_string(id));
            }
        }
        std::erase_if(g_clients, [&](const auto& kv) { return !present.count(kv.first); });
    }

    // ---------- клиент ----------

    void ClientTick()
    {
        ULONGLONG now = GetTickCount64();
        if (!g_joinedAt)
            g_joinedAt = now;
        // Хост нас так и не спросил — у него нет модлоадера. Играть можно, но моды, меняющие
        // партию, разойдутся с ним: предупреждаем один раз.
        if (!g_hostAsked && !g_warnedNoHost && now - g_joinedAt > kAnswerMs + 2000 && !Fingerprint().empty())
        {
            g_warnedNoHost = true;
            LOG_WARN("[modcheck] хост не проверяет моды — похоже, у него нет модлоадера. "
                     "Моды, меняющие партию, у вас не совпадут: будет рассинхрон.");
        }
    }

    void OnTick(const std::string&, const std::string&)
    {
        ULONGLONG now = GetTickCount64();
        if (now - g_lastCheck < kCheckEveryMs)
            return;
        g_lastCheck = now;

        // Проверяем только в комнате, до начала партии.
        Game::LanMode mode = Game::Mode();
        if (Game::InGame() || mode == Game::LanMode::Offline)
        {
            g_clients.clear();
            g_hostAsked = false;
            g_joinedAt = 0;
            g_warnedNoHost = false;
            return;
        }
        if (mode == Game::LanMode::Server)
            HostTick();
        else
            ClientTick();
    }
}

void ModCheck::Install()
{
    Events::Subscribe("gui.DoProgress", OnTick);
}

void ModCheck::OnMessage(char direction, const std::string& event, const std::string& data, int from)
{
    Game::LanMode mode = Game::Mode();

    // Клиент: хост спрашивает про моды — отвечаем отпечатком.
    if (direction == 'c' && event == "modcheck.req" && mode == Game::LanMode::Client)
    {
        if (atoi(data.c_str()) != Game::MyLanId())
            return;
        g_hostAsked = true;
        Send('s', "modcheck.ack", Fingerprint());
        return;
    }

    // Клиент: хост не пустил — показываем, почему.
    if (direction == 'c' && event == "modcheck.kick" && mode == Game::LanMode::Client)
    {
        size_t bar = data.find('|');
        if (bar == std::string::npos || atoi(data.c_str()) != Game::MyLanId())
            return;
        LOG_ERROR("[modcheck] хост не пустил в комнату: %s", data.substr(bar + 1).c_str());
        return;
    }

    // Хост: ответ клиента.
    if (direction == 's' && event == "modcheck.ack" && mode == Game::LanMode::Server)
    {
        auto it = g_clients.find(from);
        if (it == g_clients.end())
        {
            LOG_WARN("[modcheck] answer from %d, who is not in the room list — ids differ?", from);
            return;
        }
        if (it->second.kicked)
            return;
        std::string mine = Fingerprint();
        if (data == mine)
        {
            it->second.verified = true;
            LOG_INFO("[modcheck] %s: моды совпадают", ClientName(from).c_str());
        }
        else
            Kick(from, it->second, Explain(mine, data));
    }
}

void ModCheck::Print()
{
    auto mods = LuaHost::MultiplayerMods();
    Console::Print("modcheck: %zu mod(s) must match in multiplayer (client-only mods are ignored)", mods.size());
    for (const auto& m : mods)
        Console::Print("  %s %s  %s", m.id.c_str(), m.version.c_str(), m.hash.c_str());
}
