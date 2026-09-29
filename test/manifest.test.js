'use strict';
const assert = require('assert');
const { validateManifest, stripComments } = require('../src/manifest');

const files = new Set(['client.lua', 'utils.lua', 'assets']);
const exists = (p) => files.has(p);
const messages = (text) => validateManifest(text, exists).map((p) => `${p.severity}:${p.message}`);

let count = 0;
function test(name, fn) { fn(); count++; console.log('ok', name); }

test('корректный манифест без замечаний', () => {
    assert.deepStrictEqual(messages(`return {
        id = "my_mod", name = "My Mod", version = "1.0.0",
        client = "client.lua", files = { "utils.lua" },
        multiplayer = "optional", priority = 5, enabled = true, requires = { "base" },
    }`), []);
});

test('комментарии не считаются полями', () => {
    assert.deepStrictEqual(messages(`return {
        id = "a", -- server = "nope.lua"
        --[[ shared = "x.lua" ]]
        client = "client.lua",
    }`), []);
});

test('нет id', () => {
    assert.ok(messages('return { client = "client.lua" }').some((m) => m.includes('id')));
});

test('плохой id', () => {
    assert.ok(messages('return { id = "my-mod", client = "client.lua" }').some((m) => m.includes('латиниц')));
});

test('server и shared вместе', () => {
    const m = messages('return { id = "a", server = "client.lua", shared = "client.lua" }');
    assert.ok(m.some((x) => x.includes('server, либо shared')));
});

test('файл не найден', () => {
    assert.ok(messages('return { id = "a", client = "missing.lua" }').some((m) => m.includes('missing.lua')));
    assert.ok(messages('return { id = "a", client = "client.lua", files = { "nope.lua" } }').some((m) => m.includes('nope.lua')));
});

test('плохое значение multiplayer', () => {
    assert.ok(messages('return { id = "a", client = "client.lua", multiplayer = "yes" }').some((m) => m.includes('multiplayer')));
});

test('неизвестное поле — предупреждение', () => {
    const m = messages('return { id = "a", client = "client.lua", cliet = "x" }');
    assert.ok(m.some((x) => x.startsWith('warning:') && x.includes('cliet')));
});

test('мод только из assets допустим', () => {
    assert.deepStrictEqual(messages('return { id = "a" }'), []);
});

test('пустой мод — предупреждение', () => {
    const local = new Set();
    const m = validateManifest('return { id = "a" }', (p) => local.has(p));
    assert.ok(m.some((p) => p.severity === 'warning'));
});

test('не таблица', () => {
    assert.ok(messages('local x = 1').some((m) => m.startsWith('error:')));
});

test('позиция ошибки указывает на значение', () => {
    const text = 'return {\n  id = "a",\n  client = "missing.lua",\n}';
    const [p] = validateManifest(text, exists);
    assert.strictEqual(p.line, 2);
    assert.strictEqual(text.split('\n')[p.line].slice(p.col, p.col + p.length), '"missing.lua"');
});

test('stripComments сохраняет длину и строки в кавычках', () => {
    const src = 'a = "x -- y" -- tail\nb = 1';
    const out = stripComments(src);
    assert.strictEqual(out.length, src.length);
    assert.ok(out.includes('"x -- y"'));
    assert.ok(!out.includes('tail'));
});

console.log(`\n${count} tests passed`);
