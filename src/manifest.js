'use strict';
// Проверка manifest.lua без vscode: чистая функция, чтобы её можно было тестировать в node.
// Манифест — только данные (`return { ... }`), поэтому хватает разбора регулярками.

const KNOWN_KEYS = new Set([
    'id', 'name', 'version', 'author', 'description', 'enabled',
    'client', 'server', 'shared', 'files', 'multiplayer', 'priority', 'requires',
]);

const STRING_KEYS = ['id', 'name', 'version', 'author', 'description', 'client', 'server', 'shared', 'multiplayer'];

/** Заменяет комментарии пробелами, сохраняя длину строк и позиции; строки в кавычках не трогает. */
function stripComments(text) {
    let out = '';
    let i = 0;
    while (i < text.length) {
        const c = text[i];
        if (c === '"' || c === "'") {
            let j = i + 1;
            while (j < text.length && text[j] !== c && text[j] !== '\n') j += text[j] === '\\' ? 2 : 1;
            out += text.slice(i, j + 1);
            i = j + 1;
        } else if (c === '-' && text[i + 1] === '-') {
            const long = /^--\[(=*)\[/.exec(text.slice(i, i + 40));
            let end;
            if (long) {
                const close = ']' + long[1] + ']';
                const at = text.indexOf(close, i);
                end = at < 0 ? text.length : at + close.length;
            } else {
                const at = text.indexOf('\n', i);
                end = at < 0 ? text.length : at;
            }
            out += text.slice(i, end).replace(/[^\n]/g, ' ');
            i = end;
        } else {
            out += c;
            i++;
        }
    }
    return out;
}

function unquote(raw) {
    const body = raw.slice(1, -1);
    return body.replace(/\\(.)/g, '$1');
}

/** Читает поля верхнего уровня: { key, kind: 'string'|'bool'|'number'|'list', value, offset, length }. */
function parseFields(clean) {
    const start = /return\s*\{/.exec(clean);
    if (!start) return null;
    const body = clean.slice(start.index + start[0].length);
    const base = start.index + start[0].length;
    const fields = [];
    const re = /(^|[\s,;])([A-Za-z_]\w*)\s*=\s*("(?:[^"\\\n]|\\.)*"|'(?:[^'\\\n]|\\.)*'|true|false|-?\d+(?:\.\d+)?|\{[^{}]*\})/g;
    let m;
    while ((m = re.exec(body))) {
        const key = m[2];
        const raw = m[3];
        const offset = base + m.index + m[1].length;
        const valueOffset = base + m.index + m[0].length - raw.length;
        let kind, value;
        if (raw[0] === '"' || raw[0] === "'") { kind = 'string'; value = unquote(raw); }
        else if (raw === 'true' || raw === 'false') { kind = 'bool'; value = raw === 'true'; }
        else if (raw[0] === '{') {
            kind = 'list';
            value = [];
            const item = /"(?:[^"\\\n]|\\.)*"|'(?:[^'\\\n]|\\.)*'/g;
            let s;
            while ((s = item.exec(raw))) value.push({ text: unquote(s[0]), offset: valueOffset + s.index, length: s[0].length });
        } else { kind = 'number'; value = Number(raw); }
        fields.push({ key, kind, value, offset, length: key.length, valueOffset, valueLength: raw.length });
    }
    return fields;
}

function positionOf(text, offset) {
    let line = 0, last = 0;
    for (let i = text.indexOf('\n'); i >= 0 && i < offset; i = text.indexOf('\n', i + 1)) { line++; last = i + 1; }
    return { line, col: offset - last };
}

/**
 * @param {string} text содержимое manifest.lua
 * @param {(relPath: string) => boolean} exists есть ли файл/папка относительно папки мода
 * @returns {{line:number, col:number, length:number, severity:'error'|'warning', message:string}[]}
 */
function validateManifest(text, exists) {
    const problems = [];
    const add = (offset, length, severity, message) => {
        const { line, col } = positionOf(text, offset);
        problems.push({ line, col, length, severity, message });
    };

    const clean = stripComments(text);
    const fields = parseFields(clean);
    if (!fields) {
        add(0, 0, 'error', 'manifest.lua должен возвращать таблицу: return { id = "...", ... }');
        return problems;
    }

    const byKey = new Map();
    for (const f of fields) {
        if (!KNOWN_KEYS.has(f.key)) {
            add(f.offset, f.length, 'warning', `Неизвестное поле «${f.key}». Известные: ${[...KNOWN_KEYS].join(', ')}`);
            continue;
        }
        if (byKey.has(f.key)) add(f.offset, f.length, 'warning', `Поле «${f.key}» указано повторно`);
        byKey.set(f.key, f);
    }

    for (const key of STRING_KEYS) {
        const f = byKey.get(key);
        if (f && f.kind !== 'string') add(f.valueOffset, f.valueLength, 'error', `«${key}» должно быть строкой`);
    }

    const id = byKey.get('id');
    if (!id) add(0, 0, 'error', 'Не указан обязательный id (латиница, цифры, _)');
    else if (id.kind === 'string' && !/^[A-Za-z0-9_]+$/.test(id.value)) {
        add(id.valueOffset, id.valueLength, 'error', 'id может содержать только латиницу, цифры и _');
    }

    const enabled = byKey.get('enabled');
    if (enabled && enabled.kind !== 'bool') add(enabled.valueOffset, enabled.valueLength, 'error', '«enabled» — true или false');

    const priority = byKey.get('priority');
    if (priority && (priority.kind !== 'number' || !Number.isInteger(priority.value))) {
        add(priority.valueOffset, priority.valueLength, 'error', '«priority» — целое число');
    }

    const mp = byKey.get('multiplayer');
    if (mp && mp.kind === 'string' && mp.value !== 'required' && mp.value !== 'optional') {
        add(mp.valueOffset, mp.valueLength, 'error', '«multiplayer» — "required" или "optional"');
    }

    const server = byKey.get('server');
    const shared = byKey.get('shared');
    if (server && shared) {
        add(shared.offset, shared.length, 'error', 'Укажите либо server, либо shared — не оба сразу');
    }

    for (const key of ['client', 'server', 'shared']) {
        const f = byKey.get(key);
        if (f && f.kind === 'string') {
            if (!f.value.endsWith('.lua')) add(f.valueOffset, f.valueLength, 'error', 'Скрипт должен быть .lua файлом');
            else if (!exists(f.value)) add(f.valueOffset, f.valueLength, 'error', `Файл «${f.value}» не найден в папке мода`);
        }
    }

    const files = byKey.get('files');
    if (files) {
        if (files.kind !== 'list') add(files.valueOffset, files.valueLength, 'error', '«files» — список строк: { "utils.lua" }');
        else {
            for (const item of files.value) {
                if (!item.text.endsWith('.lua')) add(item.offset, item.length, 'error', 'В files допускаются только .lua модули');
                else if (!exists(item.text)) add(item.offset, item.length, 'error', `Файл «${item.text}» не найден в папке мода`);
            }
        }
    }

    const requires = byKey.get('requires');
    if (requires && requires.kind !== 'string' && requires.kind !== 'list') {
        add(requires.valueOffset, requires.valueLength, 'error', '«requires» — id мода или список id');
    }

    const hasCode = byKey.has('client') || byKey.has('server') || byKey.has('shared');
    if (!hasCode && !exists('assets') && !exists('patches') && !exists('content.lua')) {
        add(0, 0, 'warning', 'В моде нет ни скрипта (client/server/shared), ни assets/, ни patches/, ни content.lua — загружать нечего');
    }

    return problems;
}

module.exports = { validateManifest, stripComments, KNOWN_KEYS };
