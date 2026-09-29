'use strict';
// Поиск папки modloader (той, где лежат api/ и mods/). Без vscode — чтобы тестировать в node.

const fs = require('fs');
const path = require('path');

/** Папка считается модлоадером, если в ней есть api/01_state.lua. */
function isModloaderRoot(dir) {
    try {
        return fs.statSync(path.join(dir, 'api', '01_state.lua')).isFile();
    } catch {
        return false;
    }
}

/**
 * Идём вверх от start: мод лежит в modloader/mods/<мод>, поэтому корень — на 2 уровня выше;
 * заодно поддерживаем открытую папку игры (<игра>/modloader) и клон репозитория (api/ в корне).
 */
function findModloaderRoot(start) {
    if (!start) return null;
    let dir = path.resolve(start);
    try {
        if (fs.statSync(dir).isFile()) dir = path.dirname(dir);
    } catch {
        // путь мог ещё не существовать — идём вверх как есть
    }
    for (;;) {
        if (isModloaderRoot(dir)) return dir;
        const nested = path.join(dir, 'modloader');
        if (isModloaderRoot(nested)) return nested;
        const parent = path.dirname(dir);
        if (parent === dir) return null;
        dir = parent;
    }
}

/** Папка, куда класть новые моды, для найденного корня. */
function modsDirOf(root) {
    const candidates = [path.join(root, 'mods'), path.join(root, 'examples', 'mods')];
    return candidates.find((c) => fs.existsSync(c)) || candidates[0];
}

module.exports = { isModloaderRoot, findModloaderRoot, modsDirOf };
