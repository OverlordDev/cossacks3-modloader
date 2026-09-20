#include "pch.h"
#include "ScriptRunner.h"
#include "GameApi.h"
#include "Console.h"
#include "Engine.h"
#include "Events.h"
#include "Overlay.h"

#include <mutex>
#include <atomic>
#include <unordered_map>

namespace
{
    // Задание для главного потока игры: строки скрипта или C++-функция.
    struct Job
    {
        std::vector<std::string> lines;
        std::function<void()> fn;
    };

    std::mutex g_mutex;
    std::vector<Job> g_queue;
    std::atomic<DWORD> g_scriptThread = 0;
    bool g_running = false; // трогается только из потока скриптов
    int g_counter = 0;

    void CallStateExecute(uint8_t* state)
    {
        __asm
        {
            mov eax, state
            mov edx, [eax]
            call dword ptr [edx + 8] // GameApi::Off::StateVmtExecute
        }
    }

    // Повторяет движковый sub_8638E0, но без сетевого гейта sub_732414: в сетевом режиме (лобби, онлайн, повтор)
    // он пропускает state без флагов LanClientExecute — наш код молча не исполнялся бы.
    // Исключение из скрипта не должно пролететь через наш хук в игру — ловим SEH.
    bool ExecuteStateRaw(uint8_t* sm, const char* name, uint8_t** outState, DWORD* outCode)
    {
        auto currentSm = reinterpret_cast<uint8_t**>(Engine::ScriptEngine() + GameApi::Off::ScriptCurrentSM);
        uint8_t* saved = *currentSm;
        bool ok = false;
        __try
        {
            int index = Engine::StateIndex(sm, name);
            if (index >= 0)
            {
                *currentSm = sm;
                *outState = Engine::StateByIndex(sm, index);
                CallStateExecute(*outState);
                ok = true;
            }
        }
        __except (*outCode = GetExceptionCode(), EXCEPTION_EXECUTE_HANDLER)
        {
        }
        *currentSm = saved;
        return ok;
    }

    uint8_t NetGateMode()
    {
        uint8_t* engine = Engine::ScriptEngine();
        uint8_t* project = *reinterpret_cast<uint8_t**>(engine + GameApi::Off::ScriptProject);
        uint8_t* gate = project ? *reinterpret_cast<uint8_t**>(project + GameApi::Off::ProjectNetGate) : nullptr;
        return gate ? gate[GameApi::Off::NetGateMode] : 0;
    }

    void Execute(const std::vector<std::string>& lines)
    {
        auto addState = reinterpret_cast<GameApi::StateAddFn>(GameApi::Addr(GameApi::Va::StateMachineStateAdd));
        auto addLine  = reinterpret_cast<GameApi::StateAddCodeLineFn>(GameApi::Addr(GameApi::Va::StateMachineStateAddCodeLine));

        uint8_t* sm = Engine::GuiStateMachine();
        if (!sm)
        {
            LOG_WARN("ScriptRunner: GUI state machine not ready");
            return;
        }

        // Режим гейта: 0 — вне сети/записи; в партии с ботами тоже бывает ненулевым (запись повтора).
        static int lastMode = -1;
        if (int mode = NetGateMode(); mode != lastMode)
        {
            lastMode = mode;
            LOG_INFO("ScriptRunner: engine net/record mode = %d (execution gate bypassed)", mode);
        }

        // Каждый вызов — новый state, т.к. AddCodeLine дописывает строки в конец существующего.
        // Создаём его явно: иначе AddCodeLine сначала ищет state и движок логирует ошибку "StateByName".
        GameApi::DelphiString name("ModLoader.Exec." + std::to_string(++g_counter));
        addState(reinterpret_cast<int>(sm), name.get());
        for (const auto& line : lines)
            addLine(reinterpret_cast<int>(sm), name.get(), GameApi::DelphiString(line).get());

        uint8_t* state = nullptr;
        DWORD code = 0;
        if (!ExecuteStateRaw(sm, name.get(), &state, &code))
        {
            if (code)
                LOG_ERROR("ScriptRunner: exception 0x%08lX while executing script", code);
            else
                LOG_ERROR("ScriptRunner: state not found after adding code");
            return;
        }
        if (state && state[GameApi::Off::StateHasErrors])
            LOG_ERROR("ScriptRunner: compile error (see [engine] messages above)");
    }

    void Pump()
    {
        if (g_running)
            return; // исполняемый код мог сам вызвать Log — не заходим повторно

        std::vector<Job> batch;
        {
            std::lock_guard lock(g_mutex);
            batch.swap(g_queue);
        }
        if (batch.empty())
            return;

        g_running = true;
        for (const auto& job : batch)
        {
            if (job.fn)
                job.fn();
            else
                Execute(job.lines);
        }
        g_running = false;
    }

    // Код исполняется в главном VCL-потоке игры (там же работают скрипты): подменяем оконную процедуру
    // главного окна и будим её своим сообщением. Сообщения обрабатываются и когда игра в фоне и не рисует кадры.
    HWND g_wnd = nullptr;
    WNDPROC g_origProc = nullptr;
    bool g_unicode = false;
    UINT g_pumpMsg = 0;

    LRESULT CALLBACK WndProc(HWND wnd, UINT msg, WPARAM wp, LPARAM lp)
    {
        if (msg == g_pumpMsg)
        {
            Pump();
            return 0;
        }
        return g_unicode ? CallWindowProcW(g_origProc, wnd, msg, wp, lp) : CallWindowProcA(g_origProc, wnd, msg, wp, lp);
    }

    BOOL CALLBACK FindGameWindow(HWND wnd, LPARAM out)
    {
        DWORD pid = 0;
        GetWindowThreadProcessId(wnd, &pid);
        if (pid != GetCurrentProcessId() || wnd == GetConsoleWindow() || !IsWindowVisible(wnd))
            return TRUE;
        RECT rc;
        if (!GetWindowRect(wnd, &rc) || rc.right - rc.left < 200 || rc.bottom - rc.top < 200)
            return TRUE; // пропускаем служебные/крошечные окна
        *reinterpret_cast<HWND*>(out) = wnd;
        return FALSE;
    }
}

void ScriptRunner::Install()
{
    g_pumpMsg = RegisterWindowMessageW(L"Cossacks3ModLoader.Pump");
}

namespace
{
    WNDPROC CurrentProc(HWND wnd, bool unicode)
    {
        return reinterpret_cast<WNDPROC>(unicode ? GetWindowLongW(wnd, GWL_WNDPROC) : GetWindowLongA(wnd, GWL_WNDPROC));
    }

    void Detach()
    {
        if (!g_wnd)
            return;
        if (CurrentProc(g_wnd, g_unicode) == WndProc) // поверх нас никто не встал — снимаем аккуратно
        {
            if (g_unicode)
                SetWindowLongW(g_wnd, GWL_WNDPROC, reinterpret_cast<LONG>(g_origProc));
            else
                SetWindowLongA(g_wnd, GWL_WNDPROC, reinterpret_cast<LONG>(g_origProc));
        }
        g_wnd = nullptr;
        g_origProc = nullptr;
    }

    void Attach(HWND wnd)
    {
        g_unicode = IsWindowUnicode(wnd) != FALSE;
        g_scriptThread = GetWindowThreadProcessId(wnd, nullptr);
        g_origProc = reinterpret_cast<WNDPROC>(g_unicode
            ? SetWindowLongW(wnd, GWL_WNDPROC, reinterpret_cast<LONG>(WndProc))
            : SetWindowLongA(wnd, GWL_WNDPROC, reinterpret_cast<LONG>(WndProc)));
        g_wnd = wnd;
        LOG_INFO("ScriptRunner: attached to game window %p, script thread = %lu", wnd, g_scriptThread.load());

        std::lock_guard lock(g_mutex);
        if (!g_queue.empty())
            PostMessageW(g_wnd, g_pumpMsg, 0, 0);
    }
}

// Окно игры может смениться: при автозагрузке мы стартуем раньше игры и поначалу видим только
// служебные окна, а настоящее окно рендера появляется позже. Поэтому на каждом такте сверяемся
// с тем, в котором игра рисует, и перевешиваемся, если это другое окно или игра поставила свою
// оконную процедуру поверх нашей.
void ScriptRunner::Update()
{
    // Обычно идём за окном, в котором игра рисует. Если отрисовку не трогаем вовсе
    // (settings.txt: render = 0) или кадров ещё не было, ищем окно по признакам — и продолжаем
    // искать каждый раз, потому что в начале запуска подходящим выглядит и служебное окно.
    HWND want = Overlay::RenderWindow();
    if (!want)
        EnumWindows(FindGameWindow, reinterpret_cast<LPARAM>(&want));
    if (!want || !IsWindow(want))
        return;

    if (g_wnd == want)
    {
        if (CurrentProc(g_wnd, g_unicode) == WndProc)
            return; // всё на месте
        LOG_WARN("ScriptRunner: the game replaced the window procedure — reattaching");
        g_wnd = nullptr;
    }
    else if (g_wnd)
    {
        LOG_INFO("ScriptRunner: game window changed %p -> %p", g_wnd, want);
        Detach();
    }
    Attach(want);
}

void ScriptRunner::Uninstall()
{
    Detach();
}

DWORD ScriptRunner::GameThreadId()
{
    return g_scriptThread;
}

namespace
{
    void Push(Job job)
    {
        std::lock_guard lock(g_mutex);
        g_queue.push_back(std::move(job));
        if (g_wnd)
            PostMessageW(g_wnd, g_pumpMsg, 0, 0);
        else
            LOG_WARN("ScriptRunner: game window not found yet, job will run once it is");
    }
}

bool ScriptRunner::IsGameThread()
{
    return GetCurrentThreadId() == g_scriptThread;
}

namespace
{
    std::string ReplaceAll(std::string s, const std::string& from, const std::string& to)
    {
        for (size_t pos = 0; (pos = s.find(from, pos)) != std::string::npos; pos += to.size())
            s.replace(pos, from.size(), to);
        return s;
    }

    // Код -> имя закэшированного state в GUI state machine (живёт, пока жива эта state machine).
    std::unordered_map<std::string, std::string> g_callCache;
    uint8_t* g_callCacheSm = nullptr;
    int g_callCounter = 0;
}

bool ScriptRunner::Call(const std::string& code, const std::string& arg, std::string* result)
{
    uint8_t* sm = Engine::GuiStateMachine();
    if (!sm)
        return false;
    if (sm != g_callCacheSm) // GUI перезагрузился — старые state пропали
    {
        g_callCache.clear();
        g_callCacheSm = sm;
    }

    auto it = g_callCache.find(code);
    if (it == g_callCache.end() || !Engine::FindState(sm, it->second))
    {
        auto addState = reinterpret_cast<GameApi::StateAddFn>(GameApi::Addr(GameApi::Va::StateMachineStateAdd));
        auto addLine  = reinterpret_cast<GameApi::StateAddCodeLineFn>(GameApi::Addr(GameApi::Va::StateMachineStateAddCodeLine));

        std::string name = "ModLoader.Call." + std::to_string(++g_callCounter);
        if (g_callCounter % 500 == 0)
            LOG_WARN("ScriptRunner: %d cached script calls — pass changing values via arg, not in the code text", g_callCounter);

        std::string text = ReplaceAll(code, "ML_ARG", "DScriptGetgDbgString0");
        text = ReplaceAll(text, "ML_RET(", "DScriptSetgDbgString0('ML:ret:' + ");

        GameApi::DelphiString dname(name);
        addState(reinterpret_cast<int>(sm), dname.get());
        for (size_t pos = 0; pos <= text.size();)
        {
            size_t end = text.find('\n', pos);
            if (end == std::string::npos)
                end = text.size();
            addLine(reinterpret_cast<int>(sm), dname.get(), GameApi::DelphiString(text.substr(pos, end - pos)).get());
            pos = end + 1;
        }
        it = g_callCache.insert_or_assign(code, name).first;
    }

    Events::SetScriptArg(arg);
    Events::BeginCapture();

    GameApi::DelphiString dname(it->second);
    uint8_t* state = nullptr;
    DWORD exc = 0;
    bool ok = ExecuteStateRaw(sm, dname.get(), &state, &exc);

    std::string value;
    bool returned = Events::EndCapture(&value);
    if (!ok)
    {
        LOG_ERROR("ScriptRunner::Call: %s", exc ? "exception while executing script" : "state not found");
        return false;
    }
    if (state && state[GameApi::Off::StateHasErrors])
        return false; // движок уже написал ошибку компиляции
    if (result)
        *result = returned ? value : std::string();
    return true;
}

void ScriptRunner::Queue(std::vector<std::string> lines)
{
    Push({ std::move(lines), nullptr });
}

void ScriptRunner::RunOnGameThread(std::function<void()> fn)
{
    Push({ {}, std::move(fn) });
}
