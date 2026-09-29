'use strict';
// Заготовки для команды «Создать мод». Возвращают { относительный путь: содержимое }.

const KINDS = [
    { id: 'client', label: 'Интерфейс / клавиши (client)', detail: 'Скрипт у каждого игрока: клавиши, HUD, чтение состояния. Можно играть в сети без мода у других.' },
    { id: 'shared', label: 'Баланс и правила (shared)', detail: 'Меняет мир одинаково у всех: статы юнитов, логика. В сети нужен у всех игроков.' },
    { id: 'server', label: 'Решения хоста (server)', detail: 'Работает только у хоста / в одиночной игре: выдача ресурсов, наказания.' },
    { id: 'content', label: 'Новые нации и юниты (content.lua)', detail: 'Только данные: nation{...}, unit{...}, battle{...}, без кода.' },
];

function quote(s) {
    return JSON.stringify(String(s));
}

function manifest({ id, name, author, kind }) {
    const lines = [
        'return {',
        `    id = ${quote(id)},`,
        `    name = ${quote(name)},`,
        '    version = "0.1.0",',
        `    author = ${quote(author || '')},`,
        '    description = "",',
    ];
    if (kind === 'client') lines.push('    client = "client.lua",', '    multiplayer = "optional",');
    if (kind === 'shared') lines.push('    shared = "shared.lua",', '    multiplayer = "required",');
    if (kind === 'server') lines.push('    server = "server.lua",', '    multiplayer = "required",');
    if (kind === 'content') lines.push('    multiplayer = "required",');
    lines.push('}', '');
    return lines.join('\n');
}

const CLIENT = `-- Клиентский мод: работает у каждого игрока. Мир менять нельзя — только читать и показывать.
-- Подсказки по функциям: наведи курсор или начни печатать (events., input., web., ui., objects. ...).

input.bind("F7", function()
    if not game.isInGame() then return end
    local me = native.GetPlayerIndexInterfaceIO()
    local total, count = 0, 0
    for _, h in ipairs(objects.list(me)) do
        local o = objects.read(h)
        if o and not o.bdead then total, count = total + o.hp, count + 1 end
    end
    log.info(string.format("объектов: %d, HP всего: %d", count, total))
end)
`;

const SHARED = `-- Shared-мод: выполняется у ВСЕХ игроков одинаково, поэтому может менять баланс и правила.
-- Статы типов игра заполняет в начале партии — меняем в game.start.

events.on("game.start", function()
    -- balance.setHP("musketeer18", 200)
    -- balance.setDamage("musketeer18", 40, 1)     -- оружие 1 — выстрел
    -- balance.set("musketeer18", "price[3]", 30)  -- цена в золоте
    log.info("мод загружен, партия началась")
end)
`;

const SERVER = `-- Server-мод: работает только у хоста (или в одиночной игре).
-- Клиент просит через net.send, хост решает и отвечает через net.broadcast.

net.on("hello", function(data, from)
    local who = game.playerIndexOf(from) -- игрока определяем так, данным клиента не доверяем
    log.info("привет от игрока", who)
    net.broadcast("hello_reply", { player = who })
end)
`;

const CONTENT = `-- content.lua — только данные: nation{}, unit{}, battle{}. Вызывается при запуске игры, до Lua-модов.
-- Пример: юнит на основе существующего.

-- unit {
--     sid = "my_unit", from = "musketeer18",
--     nations = { "ukr" },
--     base = { maxhp = 150, speed = 1.2, ["price[3]"] = 20 },
--     name = { ru = "Мой юнит", en = "My unit" },
--     description = { ru = "Описание", en = "Description" },
-- }
`;

function modFiles(opts) {
    const files = { 'manifest.lua': manifest(opts) };
    if (opts.kind === 'client') files['client.lua'] = CLIENT;
    if (opts.kind === 'shared') files['shared.lua'] = SHARED;
    if (opts.kind === 'server') files['server.lua'] = SERVER;
    if (opts.kind === 'content') files['content.lua'] = CONTENT;
    return files;
}

module.exports = { KINDS, modFiles };
