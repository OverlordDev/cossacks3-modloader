#include "pch.h"
#include "Ui.h"
#include "Console.h"
#include "Engine.h"
#include "Events.h"
#include "GameApi.h"
#include "ScriptRunner.h"
#include "Text.h"

#include <algorithm>

namespace
{
    constexpr char kPressState[] = "ModLoader.UI";

    Ui::PressHandler g_pressHandler;
    ULONGLONG g_lastMaintain = 0;

    // Переменные, которые игра выставляет обработчику нажатия, — в строку "элемент|press|tag".
    const char kPressPayload[] =
        "IntToStr(GetIntValueByName('ElementHandle'))+'|'+GetValueByName('Press')+'|'+IntToStr(GetIntValueByName('Tag'))";

    // Главный поток игры: состояние ModLoader.UI в GUI state machine (пропадает при перезагрузке интерфейса).
    void EnsurePressState()
    {
        uint8_t* sm = Engine::GuiStateMachine();
        if (!sm || Engine::FindState(sm, kPressState))
            return;
        auto addState = reinterpret_cast<GameApi::StateAddFn>(GameApi::Addr(GameApi::Va::StateMachineStateAdd));
        auto addLine = reinterpret_cast<GameApi::StateAddCodeLineFn>(GameApi::Addr(GameApi::Va::StateMachineStateAddCodeLine));
        GameApi::DelphiString name(kPressState);
        addState(reinterpret_cast<int>(sm), name.get());
        std::string line = "DScriptSetgDbgString0('ML:ui.press|'+" + std::string(kPressPayload) + ");";
        addLine(reinterpret_cast<int>(sm), name.get(), GameApi::DelphiString(line).get());
    }

    // "123|c|5" -> (123, "c", 5)
    void ParsePress(const std::string& payload, int* element, std::string* press, int* tag)
    {
        size_t a = payload.find('|'), b = payload.find('|', a == std::string::npos ? a : a + 1);
        *element = atoi(payload.c_str());
        *press = a != std::string::npos ? payload.substr(a + 1, (b == std::string::npos ? payload.size() : b) - a - 1) : "";
        *tag = b != std::string::npos ? atoi(payload.c_str() + b + 1) : 0;
    }

    std::string Quote(const std::string& s)
    {
        std::string out = "'";
        for (char c : Text::Utf8ToAnsi(s))
            out += c == '\'' ? std::string("''") : std::string(1, c);
        return out + "'";
    }

    std::string ParentExpr(int parent)
    {
        return parent ? std::to_string(parent) : "_gui_GetTop";
    }

    // Код создания выполняется синхронно; имя элемента + bGetUpdate=True — повторный вызов обновляет
    // существующий элемент, а не плодит новый.
    int Run(const std::string& code)
    {
        std::string result;
        if (!ScriptRunner::Call(code, "", &result))
            return 0;
        return atoi(result.c_str());
    }

    // Константы игры (gc_halLeft, gc_font_serif_15) подставляются в код как идентификаторы, не как строки.
    bool ValidConst(const std::string& s)
    {
        return !s.empty() && std::all_of(s.begin(), s.end(), [](unsigned char c) { return isalnum(c) || c == '_'; });
    }

    bool ValidAlign(const Ui::Align& a)
    {
        return ValidConst(a.h) && ValidConst(a.v);
    }

    bool ValidName(const std::string& name)
    {
        // Игра запрещает '.' в именах элементов (иначе не найти их по имени).
        return !name.empty() && name.find('.') == std::string::npos && name.find('\'') == std::string::npos;
    }
}

void Ui::Install()
{
    Events::Subscribe("ui.press", [](const std::string&, const std::string& payload) {
        int element, tag;
        std::string press;
        ParsePress(payload, &element, &press, &tag);
        if (g_pressHandler)
            g_pressHandler(element, press, tag);
    });
    ScriptRunner::RunOnGameThread(EnsurePressState);
}

void Ui::Update()
{
    if (GetTickCount64() - g_lastMaintain < 1000)
        return;
    g_lastMaintain = GetTickCount64();
    ScriptRunner::RunOnGameThread(EnsurePressState);
}

int Ui::CreateGameWindow(const std::string& name, int parent, int x, int y, int w, int h)
{
    if (!ValidName(name))
        return 0;
    return Run("ML_RET(IntToStr(_gui_CreateSkinWindow(" + Quote(name) + ", " + ParentExpr(parent) +
               ", gc_halLeft, gc_valTop, " + std::to_string(x) + ", " + std::to_string(y) + ", " + std::to_string(w) +
               ", " + std::to_string(h) + ", 1, True)));");
}

int Ui::CreateGameText(const std::string& name, int parent, const std::string& text, int x, int y, int w, int h,
                       const std::string& font, const Color& c, const Align& align)
{
    if (!ValidName(name) || !ValidConst(font) || !ValidAlign(align))
        return 0;
    return Run("var color : TColor;\n"
               "_gui_SetupTColorInteger(" + std::to_string(c.r) + ", " + std::to_string(c.g) + ", " + std::to_string(c.b) +
               ", " + std::to_string(c.a) + ", 1, color);\n"
               "var text : String = " + Quote(text) + ";\n"
               "ML_RET(IntToStr(_gui_CreateText(" + Quote(name) + ", " + ParentExpr(parent) + ", text, " + align.h + ", " +
               align.v + ", " + std::to_string(x) + ", " + std::to_string(y) + ", " + std::to_string(w) + ", " +
               std::to_string(h) + ", gc_halLeft, gc_valTop, " + font + ", color, True)));");
}

int Ui::CreateGameButton(const std::string& name, int parent, const std::string& text, int x, int y, int w, int h,
                         const std::string& material, const std::string& hint, int tag, const Align& align)
{
    if (!ValidName(name) || !ValidAlign(align))
        return 0;
    // Как ShowButton в showmenu.inc: кнопка с материалом + текст по центру.
    return Run("var color : TColor;\n"
               "_gui_SetupTColorInteger(255, 220, 170, 255, 0.9, color);\n"
               "var ev : String = '" + std::string(kPressState) + "';\n"
               "var hint : String = " + Quote(hint) + ";\n"
               "var text : String = " + Quote(text) + ";\n"
               "var btn : Integer = _gui_CreateButton(" + Quote(name) + ", " + ParentExpr(parent) + ", " + Quote(material) +
               ", " + align.h + ", " + align.v + ", " + std::to_string(x) + ", " + std::to_string(y) + ", " +
               std::to_string(w) + ", " + std::to_string(h) + ", ev, hint, " +
               std::to_string(tag) + ", True);\n"
               "_gui_CreateText('txtbtn', btn, text, gc_halParentMiddle, gc_valParentMiddle, 0, 0, 0, 0, gc_halLeft, gc_valMiddle, "
               "gc_font_serif_15, color, True);\n"
               "ML_RET(IntToStr(btn));");
}

int Ui::CreateGameImage(const std::string& name, int parent, const std::string& material, int x, int y, int w, int h,
                        const Align& align)
{
    if (!ValidName(name) || !ValidAlign(align))
        return 0;
    // Последний 0 — тэг: картинка событий не получает, тэг ей не нужен.
    return Run("ML_RET(IntToStr(_gui_CreateImage(" + Quote(name) + ", " + ParentExpr(parent) + ", " + Quote(material) +
               ", " + align.h + ", " + align.v + ", " + std::to_string(x) + ", " + std::to_string(y) + ", " +
               std::to_string(w) + ", " + std::to_string(h) + ", 0, True)));");
}

int Ui::CreateGameContainer(const std::string& name, int parent, int x, int y, int w, int h, const Align& align)
{
    if (!ValidName(name) || !ValidAlign(align))
        return 0;
    return Run("ML_RET(IntToStr(_gui_CreateParent(" + Quote(name) + ", " + ParentExpr(parent) + ", " + align.h + ", " +
               align.v + ", " + std::to_string(x) + ", " + std::to_string(y) + ", " + std::to_string(w) + ", " +
               std::to_string(h) + ", True)));");
}

void Ui::ExecuteState(const std::string& state)
{
    Run("GUIExecuteState(" + Quote(state) + ");");
}

void Ui::SendTag(const std::string& state, int tag)
{
    Run("_gui_SendTagToState(" + Quote(state) + ", " + std::to_string(tag) + ");");
}

void Ui::SetPressHandler(PressHandler handler)
{
    g_pressHandler = std::move(handler);
}

void Ui::HookScreen(const std::string& state)
{
    std::string event = "guiscreen." + state;
    // Вставка идёт первой строкой состояния: заблокировав её, мод отменяет весь родной код экрана.
    Events::HookGuiStateCode(state, event,
        "DScriptSetgDbgString0('ML:" + event + "');" + std::string(Events::kBlockCheck));
}

void Ui::HookState(const std::string& state)
{
    std::string event = "guistate." + state;
    Events::HookGuiStateCode(state, event,
        "DScriptSetgDbgString0('ML:" + event + "|'+" + std::string(kPressPayload) + ");" + Events::kBlockCheck);
}
