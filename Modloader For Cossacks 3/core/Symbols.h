#pragma once

// Адрес -> функция: cossacks.exe по таблице из IDA (FunctionsTable.inc) + имена нативов,
// остальные модули — по ближайшему экспорту ("win32u!NtGdiDdDDIPresent").
namespace Symbols
{
    struct Symbol
    {
        uintptr_t key = 0;    // exe: начало функции (VA при базе 0x400000); иначе: адрес экспорта или база модуля
        uintptr_t module = 0; // база модуля (для exe — 0)
        bool inExe = false;
    };

    // Для чужих модулей строит кэш экспортов (аллокации) — не вызывать при замороженном потоке игры.
    Symbol Resolve(uintptr_t address);
    std::string Name(const Symbol& sym);
    std::string ModuleName(uintptr_t module);

    // Без аллокаций: можно звать, пока поток игры заморожен.
    bool IsExeCode(uintptr_t address);
    bool IsExeReturnAddress(uintptr_t address); // в коде exe и сразу после инструкции call
}
