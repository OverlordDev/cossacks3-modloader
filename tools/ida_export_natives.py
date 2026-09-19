# IDAPython: экспорт всех нативов скриптового API cossacks.exe в C++-таблицу.
# Регистрация нативов: `mov ecx, offset <native>` + `mov edx, offset "<объявление>"` + `call [esi+30h]`.
#
# Запуск (на копии .i64, чтобы не трогать оригинал):
#   idat.exe -A -S"ida_export_natives.py <путь>/NativesTable.inc" cossacks_copy.i64
import idc, idautils

rows = {}
for s in idautils.Strings():
    decl = str(s).strip()
    if not (decl.startswith('procedure ') or decl.startswith('function ')):
        continue
    for r in idautils.XrefsTo(s.ea):
        ins = r.frm
        if idc.print_insn_mnem(ins) != 'mov' or idc.print_operand(ins, 0) != 'edx':
            continue
        prev = idc.prev_head(ins)
        if idc.print_insn_mnem(prev) == 'mov' and idc.print_operand(prev, 0) == 'ecx':
            rows[decl] = idc.get_operand_value(prev, 1)

def esc(t):
    return t.replace(chr(92), chr(92) * 2).replace('"', chr(92) + '"')

with open(idc.ARGV[1], 'w', encoding='utf-8', newline='\r\n') as out:
    out.write('// Сгенерировано tools/ida_export_natives.py — не редактировать вручную.\n')
    out.write('// Нативы скриптового API cossacks.exe (VA при базе 0x400000): { адрес, объявление }.\n')
    for decl, va in sorted(rows.items(), key=lambda kv: kv[1]):
        out.write('{ 0x%08X, "%s" },\n' % (va, esc(decl)))
idc.qexit(0)
