#include "pch.h"
#include "CrashHandler.h"
#include "Events.h"
#include "NativeCall.h"
#include "Console.h"
#include "Engine.h"
#include "GameApi.h"
#include "Hooks.h"
#include "ScriptRunner.h"

#include <algorithm>
#include <map>
#include <set>
#include <mutex>

namespace
{
    constexpr char kPrefix[] = "ML:";

    struct Injection
    {
        std::string library; // пусто — интерфейс (menu.aix); иначе файл библиотеки состояний (units\unit.aix)
        std::string state;
        bool atEnd;
        std::string event;
        std::string line;
        // Обёртка вызова: каждую строку с вызовом wrapCall(...) заменить на
        //   begin <line с {0},{1}... = аргументы вызова>; <исходный вызов> end{ML:orig=<исходная строка>}
        // Так событие видит настоящие аргументы, а исходная строка восстанавливается для контрольной суммы.
        std::string wrapCall;
        // Обёртка с отменой: begin <line>; if <ответ не ML:block> then <вызов> end — обработчик может
        // вернуть true, и вызов не выполнится.
        bool blockable = false;
    };

    struct Subscription
    {
        int id;
        std::string event;
        Events::Handler handler;
    };

    struct Counter
    {
        uint64_t total = 0;
        uint64_t lastTotal = 0;
        ULONGLONG lastTick = 0;
    };

    // Всё ниже трогается только из главного потока игры (инъекции и вызовы натива идут там).
    std::vector<Injection> g_injections;
    std::vector<Subscription> g_subs;
    std::map<std::string, Counter> g_counters;
    int g_nextId = 1;
    std::mutex g_mutex; // подписки/счётчики читаются и из потока консоли

    ULONGLONG g_lastMaintain = 0;

    GameApi::LogFn oTrampoline = nullptr;

    void Dispatch(const std::string& event, const std::string& payload)
    {
        CrashHandler::Scope scope("событие " + event + (payload.empty() ? "" : " (" + payload.substr(0, 80) + ")"));
        std::vector<Events::Handler> handlers;
        {
            std::lock_guard lock(g_mutex);
            ++g_counters[event].total;
            for (const auto& s : g_subs)
                if (s.event == event || s.event == "*")
                    handlers.push_back(s.handler);
        }
        for (const auto& h : handlers)
        {
            try
            {
                h(event, payload);
            }
            catch (const std::exception& e)
            {
                LOG_ERROR("Event handler for %s threw: %s", event.c_str(), e.what());
            }
        }
    }

    constexpr char kRetPrefix[] = "ret:";
    // Состояние захвата/ответа — на поток: трамплин дёргают и главный поток игры,
    // и OnLanEvent/сеть. На глобалах параллельный вызов портил чужое событие
    // (блок/ответ уходил не тому). Подписки и счётчики — общие, они под g_mutex.
    thread_local bool g_blockRequested = false;
    thread_local bool g_capturing = false;
    thread_local bool g_captured = false;
    thread_local std::string g_capture;
    struct CaptureFrame { bool capturing, captured; std::string value; };
    thread_local std::vector<CaptureFrame> g_captureStack; // game.eval внутри обработчика события внутри game.eval

    void __stdcall hkTrampoline(const char* msg)
    {
        Hooks::InFlight inFlight;
        if (msg && strncmp(msg, kPrefix, sizeof(kPrefix) - 1) == 0)
        {
            const char* body = msg + sizeof(kPrefix) - 1;
            if (strncmp(body, kRetPrefix, sizeof(kRetPrefix) - 1) == 0)
            {
                if (g_capturing)
                {
                    g_capture = body + sizeof(kRetPrefix) - 1;
                    g_captured = true;
                }
                return;
            }
            // "event|payload" — данные события (например id игрока) после '|'
            const char* bar = strchr(body, '|');
            bool saved = g_blockRequested; // события бывают вложенными
            g_blockRequested = false;
            Dispatch(bar ? std::string(body, bar) : std::string(body), bar ? std::string(bar + 1) : std::string());
            // Ответ для вставки: 'ML:block' — прервать состояние (см. kBlockCheck в Events.h).
            oTrampoline(GameApi::DelphiString(g_blockRequested ? "ML:block" : "").get());
            g_blockRequested = saved;
            return;
        }
        oTrampoline(msg);
    }

    std::string Lower(std::string s)
    {
        std::transform(s.begin(), s.end(), s.begin(), [](unsigned char c) { return static_cast<char>(tolower(c)); });
        return s;
    }

    // Строки "args ..." должны идти первыми в состоянии — вставляем после них (и после пустых/комментариев).
    int BeginInsertIndex(uint8_t* list)
    {
        int count = Engine::ListCount(list);
        int index = 0;
        for (; index < count && index < 32; ++index)
        {
            std::string l = Lower(Engine::ListGet(list, index));
            size_t p = l.find_first_not_of(" \t");
            if (p == std::string::npos || l.compare(p, 2, "//") == 0 || l.compare(p, 5, "args ") == 0)
                continue;
            break;
        }
        return index;
    }

    // Машина состояний библиотеки (юниты, здания...) по имени файла. Движок хранит библиотеки
    // под тем именем, под которым их загрузил, поэтому пробуем несколько написаний пути.
    uint8_t* LibraryStateMachine(const std::string& file)
    {
        static std::map<std::string, std::string> resolved; // файл -> написание, которое сработало
        const NativeCall::Signature* get = NativeCall::Find("StateMachineLibraryGet");
        if (!get)
            return nullptr;

        auto tryName = [&](const std::string& name) -> uint8_t* {
            NativeCall::Value arg, result;
            arg.type = NativeCall::Type::String;
            arg.s = name;
            std::string error;
            if (!NativeCall::Invoke(*get, { arg }, &result, &error))
                return nullptr;
            return reinterpret_cast<uint8_t*>(result.i);
        };

        if (auto it = resolved.find(file); it != resolved.end())
            return tryName(it->second);

        const std::string variants[] = {
            ".\\data\\scripts\\" + file, "data\\scripts\\" + file, ".\\data\\scripts\\" + Lower(file),
            "data/scripts/" + file, file,
        };
        for (const std::string& v : variants)
            if (uint8_t* sm = tryName(v))
            {
                resolved[file] = v;
                LOG_DEV("Events: state library %s found as '%s'", file.c_str(), v.c_str());
                return sm;
            }
        return nullptr;
    }

    // Аргументы вызова name(...) в строке: разбивка по запятым верхнего уровня.
    bool CallArgs(const std::string& line, const std::string& name, std::vector<std::string>* args)
    {
        size_t at = line.find(name + "(");
        if (at == std::string::npos)
            return false;
        size_t i = at + name.size() + 1;
        int depth = 0;
        bool quote = false;
        std::string cur;
        for (; i < line.size(); ++i)
        {
            char c = line[i];
            if (c == '\'')
                quote = !quote;
            if (!quote)
            {
                if (c == '(' || c == '[')
                    ++depth;
                else if (c == ')' || c == ']')
                {
                    if (depth == 0)
                    {
                        args->push_back(cur);
                        return true;
                    }
                    --depth;
                }
                else if (c == ',' && depth == 0)
                {
                    args->push_back(cur);
                    cur.clear();
                    continue;
                }
            }
            cur += c;
        }
        return false;
    }

    std::string Fill(std::string text, const std::vector<std::string>& args)
    {
        for (size_t i = 0; i < args.size(); ++i)
        {
            std::string mark = "{" + std::to_string(i) + "}";
            for (size_t p; (p = text.find(mark)) != std::string::npos;)
                text.replace(p, mark.size(), args[i]);
        }
        return text;
    }

    // Главный поток игры: обернуть вызовы в состоянии. true — обёртки на месте.
    // Вставки, которые сломали компиляцию: больше не пробуем (иначе Maintain повторяет раз в секунду).
    std::set<std::string> g_failed;
    // Строки, которые не компилируются обёрнутыми: ключ вставки -> исходные строки. Их не трогаем
    // больше никогда — проверка вставок идёт раз в секунду, и без этого каждая порождала бы ошибку.
    std::map<std::string, std::set<std::string>> g_badLines;

    // Главный поток игры: обернуть вызовы в состоянии. Каждый вызов — отдельно, со своей проверкой
    // компиляции: строка, которая не компилируется обёрнутой, остаётся как есть, остальные работают.
    bool ApplyWrap(const Injection& inj, uint8_t* sm, uint8_t* state, bool quiet, bool retry = false)
    {
        std::vector<std::string> skippedNow;
        uint8_t* list = Engine::StateCode(state);
        size_t m = inj.line.find("'ML:");
        std::string marker = inj.line.substr(m, inj.line.find('|', m) - m);
        int wrapped = 0, skipped = 0, fresh = 0;
        std::set<std::string>& bad = g_badLines[inj.event];
        // Строка события отдельно перед вызовом — запасной путь, когда обёртка не компилируется.
        std::string lone = inj.line + ";";
        bool loneAbove = false; // строка выше — наша отдельная вставка: вызов под ней уже обработан
        int count = Engine::ListCount(list);

        // ПРОГРЕВ: скомпилировать состояние, ничего не меняя.
        //
        // Пробная компиляция после StateReset может провалиться сама по себе —
        // тогда вину заберёт та строка, которую пробовали ПЕРВОЙ, а она ни при
        // чём. Именно так в 'OnMouseDown' годами не оборачивался первый из двух
        // вызовов _player_OrderUnitsToAttack: строки и окружение у них совпадают
        // побуквенно (data/gui/menu.inc/onmousedown.inc:493-498 и 693-698), а
        // «не компилируется» получал всегда первый. Часть приказов атаки из-за
        // этого не давала события player.order.
        //
        // Прогрев снимает эту разницу: дальше каждый отказ относится к своей
        // строке. Если не компилируется само нетронутое состояние — это важный
        // факт сам по себе, и о нём надо сказать, а не молча портить обёртки.
        Engine::StateReset(state);
        if (!Engine::StateCompileSafe(sm, state) && !quiet)
            LOG_WARN("Events: %s: состояние '%s' не компилируется ДО наших правок — "
                     "отказы обёрток ниже могут быть не про них",
                     inj.event.c_str(), inj.state.c_str());
        for (int i = 0; i < count; ++i)
        {
            std::string original = Engine::ListGet(list, i);
            bool above = loneAbove;
            loneAbove = false;
            if (original.find(marker) != std::string::npos)
            {
                ++wrapped; // уже обёрнуто или вставлено отдельно
                loneAbove = original.find("{ML:orig=") == std::string::npos;
                continue;
            }
            std::vector<std::string> args;
            size_t start = original.find_first_not_of(" 	");
            if (above || start == std::string::npos || original.compare(start, 2, "//") == 0 ||
                original.compare(start, 10, "procedure ") == 0 || original.compare(start, 9, "function ") == 0 ||
                original.find(inj.wrapCall + "(") == std::string::npos || original.find('}') != std::string::npos ||
                original.find("//") != std::string::npos || bad.count(original) || !CallArgs(original, inj.wrapCall, &args))
                continue;
            size_t end = original.find_last_not_of(" 	");
            std::string core = original.substr(start, end - start + 1);
            bool semicolon = !core.empty() && core.back() == ';';
            if (semicolon)
                core.pop_back();
            std::string guard = inj.blockable ? std::string("if (DScriptGetgDbgString0<>'ML:block') then ") : "";
            std::string text = original.substr(0, start) + "begin " + Fill(inj.line, args) + "; " + guard + core + " end" +
                               (semicolon ? ";" : "") + "{ML:orig=" + original + "}";
            Engine::ListDelete(list, i);
            Engine::ListInsert(list, i, text);
            Engine::StateReset(state);
            // Вторая попытка с той же строкой: компиляция сразу после сброса
            // иногда отказывает не из-за содержимого (см. прогрев выше). Объявлять
            // строку негодной с одного раза — как раз то, из-за чего обёртка
            // приказа атаки терялась навсегда: отказ запоминается ПО ТЕКСТУ, а у
            // обоих вызовов он одинаковый, так что второй вызов потом даже не
            // пробовали.
            if (Engine::StateCompileSafe(sm, state) ||
                (Engine::StateReset(state), Engine::StateCompileSafe(sm, state)))
            {
                ++wrapped;
                ++fresh;
                // Удачные тоже в лог: без них не с чем сравнивать отказавшую
                // строку, а в 'OnMouseDown' два одинаковых вызова ведут себя
                // по-разному.
                LOG_DEV("Events: %s: строка %d состояния '%s' обёрнута, длина %zu",
                        inj.event.c_str(), i + 1, inj.state.c_str(), text.size());
                continue;
            }
            Engine::ListDelete(list, i);
            Engine::ListInsert(list, i, original);

            // Отдельной строкой — только внутри блока (выше begin или законченный оператор), иначе
            // после then/else/do она заберёт себе условие у вызова.
            //
            // ЭТОТ ПУТЬ ГОДИТСЯ И ДЛЯ БЛОКИРУЕМЫХ СОБЫТИЙ — с честной оговоркой:
            // событие придёт, а отменить вызов через него нельзя (строка стоит
            // перед вызовом и ничего не решает). Раньше для блокируемых он был
            // запрещён совсем, и вызов оставался вообще без события.
            //
            // Ради чего: в 'OnMouseDown' один из двух ПОБУКВЕННО ОДИНАКОВЫХ
            // вызовов _player_OrderUnitsToAttack не оборачивается ничем. Замеры
            // 2026-09-28 исключили и длину, и содержимое: `begin <вызов> end;`
            // длиной 150 символов там не компилируется, а полная обёртка в 469
            // символов на соседнем таком же вызове — компилируется. Причина
            // синтаксическая и привязана к месту; починить её мы не можем, а
            // потерять половину приказов атаки — можем. Лучше событие без отмены,
            // чем молчание.
            bool inserted = false;
            {
                std::string prev;
                for (int k = i - 1; k >= 0 && prev.empty(); --k)
                {
                    prev = Engine::ListGet(list, k);
                    if (size_t c = prev.find("//"); c != std::string::npos)
                        prev.erase(c);
                    prev.erase(prev.find_last_not_of(" 	") + 1);
                    prev.erase(0, prev.find_first_not_of(" 	") == std::string::npos ? prev.size() : prev.find_first_not_of(" 	"));
                }
                std::string low = Lower(prev);
                bool block = (!low.empty() && low.back() == ';') ||
                             (low.size() >= 5 && low.compare(low.size() - 5, 5, "begin") == 0 &&
                              (low.size() == 5 || !isalnum(static_cast<unsigned char>(low[low.size() - 6]))));
                if (block)
                {
                    Engine::ListInsert(list, i, original.substr(0, start) + Fill(lone, args));
                    Engine::StateReset(state);
                    if (Engine::StateCompileSafe(sm, state))
                    {
                        inserted = true;
                        ++wrapped;
                        ++fresh;
                        ++count;
                        ++i; // вызов теперь ниже вставки
                        // Про потерю отмены говорим вслух: мод, который ждёт, что
                        // сможет отменить этот вызов, иначе будет думать, что всё
                        // в порядке.
                        if (inj.blockable && !quiet)
                            LOG_WARN("Events: %s: строка %d состояния '%s' не оборачивается — "
                                     "событие будет приходить, но ОТМЕНИТЬ этот вызов нельзя",
                                     inj.event.c_str(), i + 1, inj.state.c_str());
                        LOG_DEV("Events: %s: line %d of '%s' — event inserted as a separate line", inj.event.c_str(),
                                i + 1, inj.state.c_str());
                    }
                    else
                        Engine::ListDelete(list, i);
                }
            }
            if (inserted)
                continue;
            // ПОЧЕМУ не скомпилировалось. Движок сообщает только имя состояния,
            // без строки и причины, поэтому выясняем перебором: подставляем
            // упрощённые формы той же обёртки и смотрим, какая пройдёт. Каждая
            // проба возвращает строку на место, поведение не меняется.
            //
            // Это нужно, потому что в 'OnMouseDown' из двух ПОБУКВЕННО
            // ОДИНАКОВЫХ вызовов _player_OrderUnitsToAttack первый не
            // оборачивается, а второй оборачивается. Ни текст строки, ни
            // условие над ней (199 и 202 символа, отличие лишь в отступе) не
            // объясняют разницу.
            if (!quiet)
            {
                struct Probe { const char* what; std::string text; };
                std::string head = original.substr(0, start);
                const Probe probes[] = {
                    // Без хвостового комментария с исходной строкой — он длинный.
                    { "без {ML:orig}", head + "begin " + Fill(inj.line, args) + "; " + guard + core +
                                       " end" + (semicolon ? ";" : "") },
                    // Без проверки блокировки — короче и без вложенного if.
                    { "без guard", head + "begin " + Fill(inj.line, args) + "; " + core + " end" +
                                   (semicolon ? ";" : "") },
                    // Только строка события вместо вызова: компилируется ли сам текст
                    // события в этом месте (вызов при этом временно пропадает —
                    // проба тут же возвращает строку на место).
                    { "только событие", head + Fill(inj.line, args) + ";" },
                    // Вложенный begin с КОРОТКИМ содержимым вместо события. Это
                    // разводит две оставшиеся версии: если проходит — мешает длина
                    // или содержимое строки события, если нет — сама вложенность
                    // begin..end в этом месте.
                    { "короткий begin", head + "begin " + core + " end" + (semicolon ? ";" : "") },
                };
                std::string verdict;
                for (const Probe& p : probes)
                {
                    Engine::ListDelete(list, i);
                    Engine::ListInsert(list, i, p.text);
                    Engine::StateReset(state);
                    bool ok = Engine::StateCompileSafe(sm, state);
                    // Длину пишем рядом: без неё нельзя отличить «мешает длина» от
                    // «мешает содержимое».
                    verdict += std::string(verdict.empty() ? "" : ", ") + p.what + "(" +
                               std::to_string(p.text.size()) + ")" + (ok ? "=ОК" : "=нет");
                    Engine::ListDelete(list, i);
                    Engine::ListInsert(list, i, original);
                    Engine::StateReset(state);
                }
                LOG_DEV("Events: %s: строка %d состояния '%s' — длина обёртки %zu; пробы: %s",
                        inj.event.c_str(), i + 1, inj.state.c_str(), text.size(), verdict.c_str());
                for (int k = i - 2; k <= i + 2; ++k)
                    if (k >= 0 && k < count && k != i)
                        LOG_DEV("Events:   соседняя %d: %s", k + 1, Engine::ListGet(list, k).c_str());
            }

            // В «негодные» — только ПОСЛЕ прохода (см. ниже). Если пометить сразу,
            // то вторая такая же строка в этом же состоянии будет пропущена по
            // совпадению текста, хотя её никто не пробовал: у двух вызовов
            // _player_OrderUnitsToAttack в 'OnMouseDown' текст побуквенно
            // одинаковый.
            skippedNow.push_back(original);
            Engine::StateReset(state);
            ++skipped;
            LOG_DEV("Events: %s: line %d of '%s' does not compile wrapped, left as is: %s", inj.event.c_str(), i + 1,
                    inj.state.c_str(), original.c_str());
        }
        // Теперь, когда все вхождения в этом состоянии опробованы, запоминаем
        // негодные — чтобы не бить по ним на следующих перехватах.
        for (const std::string& line : skippedNow)
            bad.insert(line);
        if (skipped)
            Engine::StateCompileSafe(sm, state); // вернуть состояние в рабочий (скомпилированный) вид
        // Первая компиляция состояния иногда падает не из-за нашей строки (в OnMouseDown отказывала
        // первая из двух одинаковых строк атаки). Если другие обёртки легли — ещё одна попытка.
        if (skipped && fresh && !retry)
        {
            for (const std::string& line : skippedNow)
                bad.erase(line);
            return ApplyWrap(inj, sm, state, quiet, true);
        }
        if (wrapped == 0 && skipped == 0 && fresh == 0 && !bad.empty())
            return false; // всё, что было, уже известно как непригодное — молча
        if (wrapped == 0)
        {
            g_failed.insert(inj.event);
            if (!quiet)
                LOG_WARN("Events: %s — no %s( calls could be wrapped in '%s' (%s)%s", inj.event.c_str(),
                         inj.wrapCall.c_str(), inj.state.c_str(), inj.library.c_str(),
                         skipped ? ", they do not compile wrapped" : "");
            return false;
        }
        if (fresh == 0 && skipped == 0)
            return true; // уже было обёрнуто — ничего нового
        LOG_DEV("Events: %s — %d call(s) of %s wrapped in '%s' (%s)%s", inj.event.c_str(), wrapped,
                inj.wrapCall.c_str(), inj.state.c_str(), inj.library.c_str(),
                skipped ? (", " + std::to_string(skipped) + " skipped").c_str() : "");
        return true;
    }

    // Главный поток игры. true — строка на месте.
    bool Apply(const Injection& inj, bool quiet)
    {
        if (g_failed.count(inj.event))
            return false;
        uint8_t* sm = inj.library.empty() ? Engine::GuiStateMachine() : LibraryStateMachine(inj.library);
        if (!sm)
        {
            if (!quiet)
                LOG_DEV("Events: state library %s is not loaded yet — will retry", inj.library.c_str());
            return false;
        }
        uint8_t* state = Engine::FindState(sm, inj.state);
        if (!state)
        {
            if (!quiet)
                LOG_ERROR("Events: state '%s' not found in %s", inj.state.c_str(),
                          inj.library.empty() ? "GUI" : inj.library.c_str());
            return false;
        }
        if (!inj.wrapCall.empty())
            return ApplyWrap(inj, sm, state, quiet);

        uint8_t* list = Engine::StateCode(state);
        if (Engine::ListIndexOf(list, inj.line) >= 0)
            return true;

        if (Engine::ListCount(list) == 0)
        {
            if (!quiet)
                LOG_WARN("Events: state '%s' has no code loaded, skipping", inj.state.c_str());
            return false;
        }

        int index = inj.atEnd ? Engine::ListCount(list) : BeginInsertIndex(list);
        Engine::ListInsert(list, index, inj.line);
        Engine::StateReset(state);

        // Проверяем сразу: если сломали компиляцию — откатываем, иначе у игры отвалится это состояние.
        if (!Engine::StateCompileSafe(sm, state))
        {
            int at = Engine::ListIndexOf(list, inj.line);
            if (at >= 0)
                Engine::ListDelete(list, at);
            Engine::StateReset(state);
            g_failed.insert(inj.event);
            LOG_ERROR("Events: injecting into '%s' broke compilation — reverted, will not retry", inj.state.c_str());
            return false;
        }
        LOG_DEV("Events: hooked %s (line %d of state '%s'%s%s)", inj.event.c_str(), index + 1, inj.state.c_str(),
                inj.library.empty() ? "" : " in ", inj.library.c_str());
        return true;
    }

    // Главный поток игры: GUI state machine может перезагрузиться (смена меню/партии) — вставки пропадут.
    void Maintain()
    {
        if (!Engine::GuiStateMachine())
            return;
        for (const auto& inj : g_injections)
            Apply(inj, true);
    }
}

bool Events::Install()
{
    for (const auto& n : GameApi::Natives())
        if (GameApi::NameOf(n.decl) == "DScriptSetgDbgString0")
            return Hooks::Create("Events trampoline", GameApi::Addr(n.va), &hkTrampoline, &oTrampoline);
    LOG_ERROR("Events: DScriptSetgDbgString0 native not found");
    return false;
}

void Events::MaintainNow()
{
    Maintain();
}

void Events::Update()
{
    if (GetTickCount64() - g_lastMaintain < 1000)
        return;
    g_lastMaintain = GetTickCount64();
    ScriptRunner::RunOnGameThread(Maintain);
}

void Events::HookGuiState(const std::string& state, bool atEnd)
{
    std::string event = "gui." + state + (atEnd ? ".end" : "");
    HookGuiStateCode(state, event, "DScriptSetgDbgString0('" + std::string(kPrefix) + event + "');", atEnd);
}

void Events::HookGuiStateCode(const std::string& state, const std::string& key, const std::string& line, bool atEnd)
{
    Injection inj;
    inj.state = state;
    inj.atEnd = atEnd;
    inj.event = key;
    inj.line = line;

    ScriptRunner::RunOnGameThread([inj] {
        for (const auto& existing : g_injections)
            if (existing.event == inj.event)
                return;
        if (Apply(inj, false))
            g_injections.push_back(inj);
    });
}
void Events::HookLibraryStateCode(const std::string& library, const std::string& state, const std::string& key,
                                  const std::string& line, bool atEnd)
{
    Injection inj;
    inj.library = library;
    inj.state = state;
    inj.atEnd = atEnd;
    inj.event = key;
    inj.line = line;

    ScriptRunner::RunOnGameThread([inj] {
        for (const auto& existing : g_injections)
            if (existing.event == inj.event)
                return;
        Apply(inj, false);
        g_injections.push_back(inj); // даже если библиотека ещё не загружена: Maintain довставит
    });
}


void Events::WrapLibraryCalls(const std::string& library, const std::string& state, const std::string& call,
                              const std::string& key, const std::string& line, bool blockable)
{
    Injection inj;
    inj.library = library;
    inj.state = state;
    inj.atEnd = false;
    inj.event = key;
    inj.line = line;
    inj.wrapCall = call;
    inj.blockable = blockable;

    ScriptRunner::RunOnGameThread([inj] {
        for (const auto& existing : g_injections)
            if (existing.event == inj.event)
                return;
        Apply(inj, false);
        g_injections.push_back(inj);
    });
}

void Events::Emit(const std::string& event, const std::string& payload)
{
    Dispatch(event, payload);
}

void Events::RequestBlock()
{
    g_blockRequested = true;
}

int Events::Subscribe(const std::string& event, Handler handler)
{
    std::lock_guard lock(g_mutex);
    int id = g_nextId++;
    g_subs.push_back({ id, event, std::move(handler) });
    return id;
}

void Events::Unsubscribe(int id)
{
    std::lock_guard lock(g_mutex);
    std::erase_if(g_subs, [id](const Subscription& s) { return s.id == id; });
}

void Events::SetScriptArg(const std::string& value)
{
    // Оригинал натива просто кладёт строку в глобальную переменную, которую возвращает DScriptGetgDbgString0.
    if (oTrampoline)
        oTrampoline(GameApi::DelphiString(value).get());
}

void Events::BeginCapture()
{
    g_captureStack.push_back({ g_capturing, g_captured, std::move(g_capture) });
    g_capturing = true;
    g_captured = false;
    g_capture.clear();
}

bool Events::EndCapture(std::string* value)
{
    bool captured = g_captured;
    if (captured && value)
        *value = g_capture;
    if (!g_captureStack.empty())
    {
        g_capturing = g_captureStack.back().capturing;
        g_captured = g_captureStack.back().captured;
        g_capture = std::move(g_captureStack.back().value);
        g_captureStack.pop_back();
    }
    else
        g_capturing = g_captured = false;
    return captured;
}

void Events::PrintStats()
{
    std::lock_guard lock(g_mutex);
    if (g_counters.empty())
    {
        Console::Print("  no events fired yet");
        return;
    }
    ULONGLONG now = GetTickCount64();
    for (auto& [name, c] : g_counters)
    {
        double rate = c.lastTick ? (c.total - c.lastTotal) * 1000.0 / std::max<ULONGLONG>(1, now - c.lastTick) : 0;
        Console::Print("  %-32s total %8llu   %s%.1f/s since last .events", name.c_str(), c.total,
                       c.lastTick ? "" : "~", rate);
        c.lastTotal = c.total;
        c.lastTick = now;
    }
}
