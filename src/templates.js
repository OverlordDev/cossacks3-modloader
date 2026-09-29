'use strict';
// Генератор мода: собирает набор файлов по выбранным компонентам.
// modFiles(opts) возвращает { относительный путь: содержимое }, ничего не пишет на диск.

/** Готовые наборы для быстрого старта. Поле `parts` — какие компоненты включить. */
const PRESETS = [
    {
        id: 'hud',
        label: '$(browser) Интерфейс / HUD',
        detail: 'client + HTML-страница поверх игры. Можно играть в сети без мода у других.',
        parts: { client: true, web: true },
    },
    {
        id: 'balance',
        label: '$(law) Баланс и правила',
        detail: 'shared: меняет статы юнитов и логику одинаково у всех. В сети нужен у всех игроков.',
        parts: { side: 'shared' },
    },
    {
        id: 'net',
        label: '$(broadcast) Сетевой мод (клиент + хост)',
        detail: 'client + server: клиент просит, хост решает и отвечает всем.',
        parts: { client: true, side: 'server' },
    },
    {
        id: 'content',
        label: '$(person-add) Новые нации и юниты',
        detail: 'content.lua: только данные — nation{}, unit{}, battle{}. Без кода.',
        parts: { content: true },
    },
    {
        id: 'graphics',
        label: '$(paintcan) Графика и ассеты',
        detail: 'client + папка assets/ для замены текстур, шейдеров, конфигов.',
        parts: { client: true, assets: true },
    },
    {
        id: 'custom',
        label: '$(settings-gear) Свой набор…',
        detail: 'Самому отметить, какие скрипты и папки создать.',
        parts: null,
    },
];

/** Компоненты для ручного выбора. server и shared взаимоисключающие — см. `sideChoice`. */
const PARTS = [
    { key: 'client', label: 'client.lua', detail: 'Скрипт у каждого игрока: клавиши, HUD, чтение состояния', picked: true },
    { key: 'server', label: 'server.lua', detail: 'Решения хоста / одиночной игры (не вместе с shared)' },
    { key: 'shared', label: 'shared.lua', detail: 'Меняет мир одинаково у всех: баланс, правила (не вместе с server)' },
    { key: 'content', label: 'content.lua', detail: 'Данные: новые нации, юниты, исторические сражения' },
    { key: 'web', label: 'web/hud.html', detail: 'HTML-страница для HUD или меню (нужен client.lua — добавится сам)' },
    { key: 'utils', label: 'utils.lua', detail: 'Общий модуль: подключается через require("utils"), прописан в files' },
    { key: 'assets', label: 'assets/', detail: 'Замена файлов игры: текстуры, шейдеры, конфиги' },
    { key: 'patches', label: 'patches/', detail: 'Правка скриптов игры по кусочкам (*.patch)' },
];

const quote = (s) => JSON.stringify(String(s));

/**
 * Приводит выбор к согласованному виду:
 *  - web без client → добавляется client (страницу открывает клиентский скрипт);
 *  - server и shared вместе невозможны — остаётся shared;
 *  - multiplayer "required", если мод что-то меняет в игре (server/shared/content/patches).
 */
function normalize(parts) {
    const p = {
        client: !!parts.client,
        side: parts.side || null,
        content: !!parts.content,
        web: !!parts.web,
        utils: !!parts.utils,
        assets: !!parts.assets,
        patches: !!parts.patches,
    };
    if (parts.server && !p.side) p.side = 'server';
    if (parts.shared) p.side = 'shared';
    if (p.web) p.client = true;
    p.changesWorld = !!(p.side || p.content || p.patches);
    return p;
}

function manifest(o, p) {
    const lines = [
        '-- manifest.lua — паспорт мода: только данные, без вызовов функций.',
        'return {',
        `    id = ${quote(o.id)},`,
        `    name = ${quote(o.name)},`,
        '    version = "0.1.0",',
        `    author = ${quote(o.author || '')},`,
        `    description = ${quote(o.description || '')},`,
        '    enabled = true,',
        '',
    ];
    if (p.client) lines.push('    client = "client.lua",       -- у каждого игрока');
    if (p.side === 'server') lines.push('    server = "server.lua",       -- только у хоста / в одиночной игре');
    if (p.side === 'shared') lines.push('    shared = "shared.lua",       -- у всех одинаково');
    if (p.utils) lines.push('    files = { "utils.lua" },     -- модули для require("utils")');
    lines.push(
        '',
        p.changesWorld
            ? '    multiplayer = "required",    -- мод меняет игру: в сети он нужен у всех'
            : '    multiplayer = "optional",    -- мод ничего не меняет в мире: другим он не нужен',
        '    -- priority = 0,             -- больше — грузится позже и перекрывает других',
        '    -- requires = { "base_mod" }, -- без этих модов не загрузится',
        '}',
        '',
    );
    return lines.join('\n');
}

function client(o, p) {
    const out = [
        '-- Клиентский скрипт: работает у каждого игрока. Читать состояние и показывать можно, менять мир — нет.',
        '-- Наведи курсор на функцию или начни печатать (events., input., web., ui., objects. ...) — будут подсказки.',
        '',
    ];
    if (p.utils) out.push('local utils = require("utils")', '');
    if (p.web) {
        out.push(
            'events.on("game.start", function()',
            '    web.open("hud.html")',
            '    web.passthrough(true) -- прозрачные места страницы пропускают клики в игру',
            'end)',
            'events.on("game.end", function() web.close() end)',
            '',
        );
    }
    out.push(
        'input.bind("F7", function()',
        '    if not game.isInGame() then return end',
        '    local me = native.GetPlayerIndexInterfaceIO()',
        '    local total, count = 0, 0',
        '    for _, h in ipairs(objects.list(me)) do',
        '        local o = objects.read(h)',
        '        if o and not o.bdead then total, count = total + o.hp, count + 1 end',
        '    end',
        p.utils
            ? '    log.info(utils.format_report(count, total))'
            : '    log.info(string.format("объектов: %d, HP всего: %d", count, total))',
        'end)',
        '',
    );
    if (p.side === 'server') {
        out.push(
            '-- Связь с хостом: просим через net.send, ответ приходит через net.on.',
            'input.bind("F6", function() net.send("ping", { text = "привет" }) end)',
            'net.on("pong", function(data) log.info("хост ответил игроку", data.player) end)',
            '',
        );
    }
    return out.join('\n');
}

function server() {
    return [
        '-- Серверный скрипт: работает только у хоста (или в одиночной игре).',
        '-- Клиент просит через net.send, хост решает и отвечает через net.broadcast.',
        '',
        'net.on("ping", function(data, from)',
        '    local who = game.playerIndexOf(from) -- игрока определяем так, данным клиента не доверяем',
        '    log.info("ping от игрока", who, data and data.text)',
        '    net.broadcast("pong", { player = who })',
        'end)',
        '',
    ].join('\n');
}

function shared() {
    return [
        '-- Shared-скрипт: выполняется у ВСЕХ игроков одинаково, поэтому может менять баланс и правила.',
        '-- Статы типов игра заполняет в начале партии — меняем их в game.start.',
        '',
        'events.on("game.start", function()',
        '    -- balance.setHP("musketeer18", 200)',
        '    -- balance.setDamage("musketeer18", 40, 1)     -- оружие 1 — выстрел',
        '    -- balance.set("musketeer18", "price[3]", 30)  -- цена в золоте',
        '    log.info("мод загружен, партия началась")',
        'end)',
        '',
    ].join('\n');
}

const CONTENT = `-- content.lua — только данные: nation{}, unit{}, battle{}. Выполняется при запуске игры, до Lua-модов.
-- Раскомментируй и поправь: юнит на основе существующего.

-- unit {
--     sid = "my_unit", from = "musketeer18",
--     nations = { "ukr" },
--     base = { maxhp = 150, speed = 1.2, ["price[3]"] = 20 },
--     name = { ru = "Мой юнит", en = "My unit" },
--     description = { ru = "Описание", en = "Description" },
-- }
`;

const UTILS = `-- Общий модуль. Подключается: local utils = require("utils"). Имя файла должно быть в manifest.files.
local M = {}

function M.format_report(count, total)
    return string.format("объектов: %d, HP всего: %d", count, total)
end

return M
`;

const HUD = `<!doctype html>
<html>
<head>
<meta charset="utf-8">
<!-- Фон обязательно прозрачный: иначе страница перехватит все клики мимо игры. -->
<style>
  html, body { margin: 0; background: transparent; }
  #box { position: absolute; right: 16px; bottom: 16px; padding: 8px 12px;
         background: rgba(0, 0, 0, .7); color: #fc6; font: 14px sans-serif; border-radius: 4px; }
</style>
</head>
<body>
<div id="box">HUD загружается…</div>
<script>
// window.game появляется после загрузки страницы — ждём его.
const wait = setInterval(() => {
  if (typeof window.game !== 'object') return;
  clearInterval(wait);
  setInterval(async () => {
    const h = await game.api('buildings.selected');
    document.getElementById('box').textContent = h ? 'Выделено здание #' + h : 'Ничего не выделено';
  }, 500);
}, 50);
</script>
</body>
</html>
`;

const ASSETS_README = `Сюда кладутся файлы, заменяющие файлы игры. Путь внутри assets/ повторяет путь в игре:
  assets/data/shaders/tone/tonecont.frag
Нужен перезапуск игры. При конфликте побеждает мод с большим priority (manifest.lua).
Список загруженных замен — команда .assets в консоли модлоадера.
`;

const PATCHES_README = `Сюда кладутся правки скриптов игры: patches/<путь в игре>.patch, например
  patches/data/scripts/lib/unit.script.patch
Формат (@replace / @begin / @end / @before / @after / @append / @find + @with) — в MODDING.md и
AI_MODDING_REFERENCE.md, раздел «Патчи скриптов игры». Итог смотри в modloader/cache/<путь>.
Патч меняет правила игры, поэтому в manifest.lua должно быть multiplayer = "required".
`;

/**
 * @param {{id:string, name:string, author?:string, description?:string,
 *          parts:{client?:boolean, server?:boolean, shared?:boolean, side?:'server'|'shared', content?:boolean,
 *                 web?:boolean, utils?:boolean, assets?:boolean, patches?:boolean}}} opts
 * @returns {Record<string,string>}
 */
function modFiles(opts) {
    const p = normalize(opts.parts || {});
    const files = { 'manifest.lua': manifest(opts, p) };
    if (p.client) files['client.lua'] = client(opts, p);
    if (p.side === 'server') files['server.lua'] = server();
    if (p.side === 'shared') files['shared.lua'] = shared();
    if (p.content) files['content.lua'] = CONTENT;
    if (p.utils) files['utils.lua'] = UTILS;
    if (p.web) files['web/hud.html'] = HUD;
    if (p.assets) files['assets/README.txt'] = ASSETS_README;
    if (p.patches) files['patches/README.txt'] = PATCHES_README;
    return files;
}

/** Файл, который стоит открыть после создания. */
function mainFile(files) {
    return ['client.lua', 'shared.lua', 'server.lua', 'content.lua', 'manifest.lua'].find((f) => f in files);
}

module.exports = { PRESETS, PARTS, modFiles, mainFile, normalize };
