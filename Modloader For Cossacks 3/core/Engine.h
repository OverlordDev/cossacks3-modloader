#pragma once

// Вызовы внутренних функций движка (Delphi register: eax, edx, ecx) и работа с его объектами.
// Всё — только из главного потока игры.
namespace Engine
{
    uint8_t* ScriptEngine();                                // TXDMScript singleton
    uint8_t* GuiStateMachine();                             // TXStateMachine главного меню/интерфейса (menu.aix)

    int StateIndex(uint8_t* sm, const char* delphiName);    // -1, если нет
    uint8_t* StateByIndex(uint8_t* sm, int index);
    int StateCount(uint8_t* sm);
    uint8_t* FindState(uint8_t* sm, const std::string& name); // nullptr, если нет
    void StateReset(uint8_t* state);                        // сбросить компиляцию — пересоберётся при запуске
    // Скомпилировать сейчас (как при запуске: текущая state machine = sm), с защитой от исключений.
    // false — ошибки компиляции (движок пишет их в лог) или исключение.
    bool StateCompileSafe(uint8_t* sm, uint8_t* state);
    uint8_t* StateCode(uint8_t* state);                     // TStringList с кодом
    void DumpState(const std::string& name, int maxLines);  // в консоль: флаги и первые строки кода

    void FreeString(char** s); // освободить Delphi AnsiString, выделенную игрой (@LStrClr)

    // TStringList
    int ListCount(uint8_t* list);
    std::string ListGet(uint8_t* list, int index);
    int ListIndexOf(uint8_t* list, const std::string& s);
    void ListInsert(uint8_t* list, int index, const std::string& s);
    void ListDelete(uint8_t* list, int index);
}
