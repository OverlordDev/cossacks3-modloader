# IDAPython: экспорт границ всех функций cossacks.exe в C++-таблицу для профилировщика.
# Безымянные (sub_XXXX) пишутся с пустым именем — профилировщик покажет адрес.
#
# Запуск (на копии .i64):
#   idat.exe -A -S"ida_export_functions.py <путь>/FunctionsTable.inc" cossacks_copy.i64
import idc, idautils, ida_funcs

def esc(t):
    return t.replace(chr(92), chr(92) * 2).replace('"', chr(92) + '"')

with open(idc.ARGV[1], 'w', encoding='utf-8', newline='\r\n') as out:
    out.write('// Сгенерировано tools/ida_export_functions.py — не редактировать вручную.\n')
    out.write('// Функции cossacks.exe (VA при базе 0x400000), отсортированы: { начало, конец, имя }.\n')
    for ea in idautils.Functions():
        f = ida_funcs.get_func(ea)
        name = idc.get_func_name(ea)
        if name.startswith(('sub_', 'nullsub_', 'unknown_')):
            name = ''
        out.write('{ 0x%08X, 0x%08X, "%s" },\n' % (f.start_ea, f.end_ea, esc(name)))
idc.qexit(0)
