'use strict';
const assert = require('assert');
const { PRESETS, PARTS, modFiles, mainFile, normalize } = require('../src/templates');
const { validateManifest } = require('../src/manifest');

let count = 0;
function test(name, fn) { fn(); count++; console.log('ok', name); }

const opts = (parts) => ({ id: 'gen_mod', name: 'Gen Mod', author: 'me', description: 'd "q"', parts });
const problems = (files) => validateManifest(files['manifest.lua'], (p) => p in files || Object.keys(files).some((f) => f.startsWith(p + '/')));

for (const preset of PRESETS.filter((p) => p.parts)) {
    test(`пресет «${preset.id}» даёт валидный манифест`, () => {
        const files = modFiles(opts(preset.parts));
        assert.deepStrictEqual(problems(files), []);
        assert.ok(mainFile(files));
    });
}

test('все компоненты сразу: манифест валиден, server и shared не вместе', () => {
    const all = Object.fromEntries(PARTS.map((p) => [p.key, true]));
    const files = modFiles(opts(all));
    assert.deepStrictEqual(problems(files), []);
    assert.ok('shared.lua' in files && !('server.lua' in files));
    for (const f of ['client.lua', 'content.lua', 'utils.lua', 'web/hud.html', 'assets/README.txt', 'patches/README.txt']) assert.ok(f in files, f);
});

test('web без client добавляет client', () => {
    const files = modFiles(opts({ web: true }));
    assert.ok('client.lua' in files);
    assert.ok(files['client.lua'].includes('web.open("hud.html")'));
});

test('multiplayer: optional для клиента, required для правил мира', () => {
    assert.ok(modFiles(opts({ client: true }))['manifest.lua'].includes('multiplayer = "optional"'));
    assert.ok(modFiles(opts({ shared: true }))['manifest.lua'].includes('multiplayer = "required"'));
    assert.ok(modFiles(opts({ content: true }))['manifest.lua'].includes('multiplayer = "required"'));
    assert.ok(modFiles(opts({ patches: true }))['manifest.lua'].includes('multiplayer = "required"'));
});

test('client+server: клиент шлёт ping, хост отвечает pong', () => {
    const files = modFiles(opts({ client: true, side: 'server' }));
    assert.ok(files['client.lua'].includes('net.send("ping"'));
    assert.ok(files['server.lua'].includes('net.on("ping"'));
    assert.ok(files['server.lua'].includes('net.broadcast("pong"'));
});

test('utils: подключён в manifest.files и в client через require', () => {
    const files = modFiles(opts({ client: true, utils: true }));
    assert.ok(files['manifest.lua'].includes('files = { "utils.lua" }'));
    assert.ok(files['client.lua'].includes('require("utils")'));
});

test('нормализация: server+shared → shared', () => {
    assert.strictEqual(normalize({ server: true, shared: true }).side, 'shared');
});

test('кавычки в описании экранируются', () => {
    assert.deepStrictEqual(problems(modFiles(opts({ client: true }))), []);
});

console.log(`\n${count} tests passed`);
