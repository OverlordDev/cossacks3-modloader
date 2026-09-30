#include "pch.h"
#include "ScriptLog.h"
#include "../core/Console.h"
#include "../core/GameApi.h"
#include "../core/Hooks.h"
#include "../core/Text.h"

#include <mutex>
#include <string>
#include <unordered_map>

namespace
{
    enum class Level { Log, Err, Info, Normal, Error };

    std::string AnsiToUtf8(const char* s)
    {
        return s ? Text::AnsiToUtf8(s) : std::string();
    }

    // ─── Уровень сообщений движка ────────────────────────────────────────────
    //
    // Канал ERROR движка используется им и для штатных отчётов, поэтому «ERROR» в
    // нашем логе перестал значить «что-то сломалось»: в разборе лога 2026-09-28 из
    // 58 строк ERROR 47 были одним и тем же периодическим отчётом. Отчёт тестера с
    // таким логом бесполезен — настоящую ошибку в нём не найти.
    //
    // Поэтому известные штатные сообщения печатаются как INFO с пояснением, а всё
    // остальное остаётся ERROR. Из лога они НЕ исчезают: молча глотать сообщения
    // движка нельзя, иначе диагностика станет врать в другую сторону. Уровень DEV
    // для этого не годится — он привязан к наличию dev.txt, и у тестера строки
    // просто не появились бы.
    //
    // Список явный, и каждая строка в нём обоснована.
    struct KnownEngineMessage
    {
        const char* fragment;   // подстрока, по которой узнаём
        const char* why;        // почему это не ошибка — попадает в лог рядом
    };
    const KnownEngineMessage kKnownEngine[] = {
        // Периодический отчёт LAN-клиента об отправленной чексумме: формат
        // "RecordManager: PublicSrvSendChecksum(%s)" лежит в cossacks.exe рядом с
        // TXLanCl. Идёт раз в ~5 с всю сетевую партию, на исправной сборке тоже.
        { "RecordManager: PublicSrvSendChecksum(", "периодический отчёт LAN-клиента, не сбой" },
        // Движок щупает SDK GOG. В сборке из Steam его нет и быть не должно.
        { "FileStreamExists: galaxy.dll", "GOG SDK, в Steam-сборке отсутствует штатно" },
        // Маркер восстановления списка модов: его нет, если восстанавливать нечего.
        { "mods.restore", "маркер восстановления, обычно отсутствует" },
    };

    // ─── Сворачивание повторов ──────────────────────────────────────────────
    //
    // Если одно и то же сообщение движка идёт потоком, лог забивается им, даже
    // когда сообщение настоящее. Первые печатаем как есть, дальше — на отметках с
    // растущим шагом, и каждый раз с числом повторов.
    //
    // ШАГ РАСТЁТ, А НЕ ФИКСИРОВАН. С «раз в 50» поток из 47 строк напечатался бы
    // трижды, а итог не показался бы вообще: 50-я отметка не наступает. Отчёт о
    // чексумме в логе 2026-09-28 шёл ровно 47 раз — то есть именно этот случай.
    constexpr int kRepeatsBeforeCollapse = 3;
    const int kMarks[] = { 10, 30, 100, 300, 1000, 3000, 10000, 30000 };

    std::mutex g_repeatMx;
    std::unordered_map<std::string, int> g_repeats;

    // Сколько раз это сообщение уже было; 0 — впервые. Считаем по тексту целиком.
    int SeenBefore(const std::string& text)
    {
        std::lock_guard<std::mutex> lock(g_repeatMx);
        return g_repeats[text]++;
    }

    // Печатать ли этот повтор. count — сколько уже было, включая текущий.
    bool WorthPrinting(int count)
    {
        if (count <= kRepeatsBeforeCollapse)
            return true;
        for (int mark : kMarks)
            if (count == mark)
                return true;
        return false;
    }

    void __cdecl OnCoreLog(Level level, const char* msg)
    {
        std::string text = AnsiToUtf8(msg);
        const char* tag = (level == Level::Log || level == Level::Err)
                              ? "\x1b[36m[script]\x1b[0m" : "\x1b[35m[engine]\x1b[0m";
        bool isError = (level == Level::Err || level == Level::Error);

        if (isError)
        {
            // Штатное сообщение, которое движок шлёт в канал ошибок: печатаем как
            // INFO и объясняем, почему это не сбой.
            const char* why = nullptr;
            for (const KnownEngineMessage& known : kKnownEngine)
            {
                if (text.find(known.fragment) != std::string::npos)
                {
                    why = known.why;
                    break;
                }
            }

            // Сворачивание — и для штатных, и для настоящих: поток одинаковых
            // строк забивает лог в любом случае (тот самый отчёт о чексумме шёл
            // 47 раз за партию).
            int count = SeenBefore(text) + 1;
            if (!WorthPrinting(count))
                return;
            std::string suffix;
            if (count > kRepeatsBeforeCollapse)
                suffix = "  (повторено " + std::to_string(count) + " раз)";
            else if (why)
                suffix = std::string("  (") + why + ")";

            if (why)
                Console::Info("%s %s%s", tag, text.c_str(), suffix.c_str());
            else
                Console::Error("%s %s%s", tag, text.c_str(), suffix.c_str());
            return;
        }

        Console::Info("%s %s", tag, text.c_str());
    }

    // Логгеры движка — Delphi register: eax = сообщение. Сохраняем регистры, логируем, прыгаем в оригинал.
#define CORE_LOG_HOOK(NAME, LEVEL)                  \
    void* o##NAME = nullptr;                        \
    __declspec(naked) void hk##NAME()               \
    {                                               \
        __asm pushad                                \
        __asm push eax                              \
        __asm push LEVEL                            \
        __asm call OnCoreLog                        \
        __asm add esp, 8                            \
        __asm popad                                 \
        __asm jmp dword ptr [o##NAME]               \
    }

    CORE_LOG_HOOK(CoreLog, 0)
    CORE_LOG_HOOK(CoreErr, 1)
    CORE_LOG_HOOK(CoreInfo, 2)
    CORE_LOG_HOOK(CoreNormal, 3)
    CORE_LOG_HOOK(CoreError, 4)

    GameApi::LogFn oTimeLog = nullptr;

    // TimeLog пишет через отдельный логгер TIM другой формы — перехватываем скриптовую обёртку.
    void __stdcall hkTimeLog(const char* msg)
    {
        Console::Info("\x1b[36m[script:time]\x1b[0m %s", AnsiToUtf8(msg).c_str());
        oTimeLog(msg);
    }

    bool HookCore(const char* name, uintptr_t va, void (*detour)(), void** original)
    {
        return Hooks::CreateRaw(name, GameApi::Addr(va), reinterpret_cast<void*>(detour), original);
    }
}

bool ScriptLog::Install()
{
    bool ok = HookCore("Core LOG", GameApi::Va::CoreLog, hkCoreLog, &oCoreLog);
    ok &= HookCore("Core ERR", GameApi::Va::CoreErr, hkCoreErr, &oCoreErr);
    ok &= HookCore("Core INFO", GameApi::Va::CoreInfo, hkCoreInfo, &oCoreInfo);
    ok &= HookCore("Core NORMAL", GameApi::Va::CoreNormal, hkCoreNormal, &oCoreNormal);
    ok &= HookCore("Core ERROR", GameApi::Va::CoreError, hkCoreError, &oCoreError);
    ok &= Hooks::Create("Script TimeLog", GameApi::Addr(GameApi::Va::TimeLog), &hkTimeLog, &oTimeLog);
    return ok;
}

void ScriptLog::PrintBuildVersion()
{
    auto getBuildVersion = reinterpret_cast<GameApi::GetStringFn>(GameApi::Addr(GameApi::Va::GetBuildVersion));
    char* ver = nullptr; // строку выделяет менеджер памяти Delphi; не освобождаем — мелкая утечка один раз
    getBuildVersion(&ver);
    LOG_INFO("Game build version: %s", ver && *ver ? ver : "(empty — script engine not initialized yet)");
}
