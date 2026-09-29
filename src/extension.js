'use strict';
const fs = require('fs');
const path = require('path');
const vscode = require('vscode');
const { findModloaderRoot, modsDirOf } = require('./locate');
const { validateManifest } = require('./manifest');
const { PRESETS, PARTS, modFiles, mainFile } = require('./templates');

const DOCS_URL = 'https://github.com/OverlordDev/cossacks3-modloader/blob/main/MODDING.md';
const OWNED_KEY = 'cossacks3.libraryEntries';

/** @type {vscode.StatusBarItem} */
let status;
/** @type {vscode.DiagnosticCollection} */
let diagnostics;
/** @type {vscode.FileSystemWatcher | undefined} */
let apiWatcher;
let currentRoot = null;
let lastApiChange = null;

const cfg = () => vscode.workspace.getConfiguration('cossacks3');

function activate(context) {
    status = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Left, 0);
    status.command = 'cossacks3.selectModloader';
    diagnostics = vscode.languages.createDiagnosticCollection('cossacks3');
    context.subscriptions.push(status, diagnostics);

    context.subscriptions.push(
        vscode.commands.registerCommand('cossacks3.newMod', () => newMod(context)),
        vscode.commands.registerCommand('cossacks3.selectModloader', selectModloader),
        vscode.commands.registerCommand('cossacks3.openLog', openLog),
        vscode.commands.registerCommand('cossacks3.openDocs', () => vscode.env.openExternal(vscode.Uri.parse(DOCS_URL))),
        vscode.window.onDidChangeActiveTextEditor(() => refresh(context)),
        vscode.workspace.onDidChangeWorkspaceFolders(() => refresh(context)),
        vscode.workspace.onDidChangeConfiguration((e) => {
            if (e.affectsConfiguration('cossacks3')) refresh(context);
        }),
        vscode.workspace.onDidOpenTextDocument(checkManifest),
        vscode.workspace.onDidChangeTextDocument((e) => checkManifest(e.document)),
        vscode.workspace.onDidSaveTextDocument(checkManifest),
        vscode.workspace.onDidCloseTextDocument((doc) => diagnostics.delete(doc.uri)),
    );

    vscode.workspace.textDocuments.forEach(checkManifest);
    refresh(context);
}

function deactivate() {
    if (apiWatcher) apiWatcher.dispose();
}

// ---------------------------------------------------------------------------------------------------
// Поиск modloader и настройка Lua Language Server
// ---------------------------------------------------------------------------------------------------

function detectRoot() {
    const manual = cfg().get('modloaderPath');
    if (manual) return findModloaderRoot(manual);

    const starts = [];
    const editor = vscode.window.activeTextEditor;
    if (editor && editor.document.uri.scheme === 'file') starts.push(editor.document.uri.fsPath);
    for (const folder of vscode.workspace.workspaceFolders || []) starts.push(folder.uri.fsPath);
    for (const start of starts) {
        const root = findModloaderRoot(start);
        if (root) return root;
    }
    return null;
}

function refresh(context) {
    const root = detectRoot() || (cfg().get('modloaderPath') ? null : currentRoot);
    if (root !== currentRoot) {
        currentRoot = root;
        watchApi(root);
    }
    updateStatus(root);
    if (root && cfg().get('configureLuaServer')) configureLuaServer(context, root);
    vscode.workspace.textDocuments.forEach(checkManifest);
}

function watchApi(root) {
    if (apiWatcher) apiWatcher.dispose();
    apiWatcher = undefined;
    if (!root) return;
    apiWatcher = vscode.workspace.createFileSystemWatcher(new vscode.RelativePattern(root, 'api/*.lua'));
    const touched = () => {
        lastApiChange = new Date();
        updateStatus(currentRoot);
    };
    apiWatcher.onDidChange(touched);
    apiWatcher.onDidCreate(touched);
    apiWatcher.onDidDelete(touched);
}

function updateStatus(root) {
    if (root) {
        status.text = '$(check) CS3 API';
        const when = lastApiChange ? `\nAPI обновлён в ${lastApiChange.toLocaleTimeString()}` : '';
        status.tooltip = `Cossacks 3 Modding: подсказки берутся из\n${path.join(root, 'api')}${when}\n\nНажмите, чтобы выбрать другую папку`;
        status.backgroundColor = undefined;
    } else {
        status.text = '$(warning) CS3 API не найден';
        status.tooltip = 'Не найдена папка modloader (с api/ внутри). Нажмите, чтобы указать её.';
        status.backgroundColor = new vscode.ThemeColor('statusBarItem.warningBackground');
    }
    status.show();
}

async function configureLuaServer(context, root) {
    if (!vscode.workspace.workspaceFolders) return; // настройки рабочей области некуда писать

    const lua = vscode.workspace.getConfiguration('Lua');
    const ours = [path.join(root, 'api'), path.join(context.extensionPath, 'meta')];
    const previous = context.workspaceState.get(OWNED_KEY, []);

    const inspected = lua.inspect('workspace.library');
    const current = (inspected && inspected.workspaceValue) || [];
    // Свои прежние записи (старая версия плагина, другая копия игры) заменяем, чужие не трогаем.
    const kept = current.filter((entry) => !previous.includes(entry) && !ours.includes(entry));
    const wanted = [...kept, ...ours];

    try {
        if (JSON.stringify(wanted) !== JSON.stringify(current)) {
            await lua.update('workspace.library', wanted, vscode.ConfigurationTarget.Workspace);
        }
        const runtime = lua.inspect('runtime.version');
        if (!runtime || (runtime.workspaceValue === undefined && runtime.globalValue === undefined)) {
            await lua.update('runtime.version', 'Lua 5.4', vscode.ConfigurationTarget.Workspace);
        }
        await context.workspaceState.update(OWNED_KEY, ours);
    } catch (err) {
        vscode.window.showWarningMessage(`Cossacks 3: не удалось настроить Lua Language Server: ${err.message}`);
    }
}

async function selectModloader() {
    const picked = await vscode.window.showOpenDialog({
        canSelectFiles: false,
        canSelectFolders: true,
        canSelectMany: false,
        openLabel: 'Выбрать папку modloader',
        title: 'Папка modloader игры (в ней лежат api и mods)',
    });
    if (!picked || !picked.length) return;
    const root = findModloaderRoot(picked[0].fsPath);
    if (!root) {
        vscode.window.showErrorMessage('В выбранной папке нет api/01_state.lua — это не папка modloader. Выберите <игра>/modloader.');
        return;
    }
    await cfg().update('modloaderPath', root, vscode.workspace.workspaceFolders ? vscode.ConfigurationTarget.Workspace : vscode.ConfigurationTarget.Global);
    vscode.window.showInformationMessage(`Cossacks 3: используется ${root}`);
}

// ---------------------------------------------------------------------------------------------------
// Проверка manifest.lua
// ---------------------------------------------------------------------------------------------------

function checkManifest(doc) {
    if (doc.languageId !== 'lua' || path.basename(doc.uri.fsPath) !== 'manifest.lua' || doc.uri.scheme !== 'file') return;
    if (!cfg().get('validateManifest')) {
        diagnostics.delete(doc.uri);
        return;
    }
    const dir = path.dirname(doc.uri.fsPath);
    const exists = (rel) => fs.existsSync(path.join(dir, rel));
    const found = validateManifest(doc.getText(), exists).map((p) => {
        const range = new vscode.Range(p.line, p.col, p.line, p.col + Math.max(p.length, 1));
        const d = new vscode.Diagnostic(range, p.message, p.severity === 'error' ? vscode.DiagnosticSeverity.Error : vscode.DiagnosticSeverity.Warning);
        d.source = 'Cossacks 3';
        return d;
    });
    diagnostics.set(doc.uri, found);
}

// ---------------------------------------------------------------------------------------------------
// Команды
// ---------------------------------------------------------------------------------------------------

async function newMod(context) {
    let root = currentRoot || detectRoot();
    if (!root) {
        await selectModloader();
        root = detectRoot();
        if (!root) return;
    }
    const modsDir = modsDirOf(root);

    // 1. Набор: готовый шаблон или свой выбор.
    const preset = await vscode.window.showQuickPick(
        PRESETS.map((p) => ({ label: p.label, detail: p.detail, preset: p })),
        { title: 'Новый мод (1/3): что делаем?', matchOnDetail: true },
    );
    if (!preset) return;

    let parts = preset.preset.parts;
    if (!parts) {
        const picked = await vscode.window.showQuickPick(
            PARTS.map((p) => ({ label: p.label, detail: p.detail, picked: !!p.picked, key: p.key })),
            { title: 'Новый мод (2/3): что создать?', canPickMany: true, matchOnDetail: true },
        );
        if (!picked) return;
        parts = {};
        for (const item of picked) parts[item.key] = true;
        if (parts.server && parts.shared) {
            const side = await vscode.window.showQuickPick(
                [
                    { label: 'shared.lua', detail: 'Выполняется у всех одинаково (баланс, правила)', side: 'shared' },
                    { label: 'server.lua', detail: 'Только у хоста / в одиночной игре', side: 'server' },
                ],
                { title: 'В манифесте можно указать только одно: server или shared', placeHolder: 'Что оставить?' },
            );
            if (!side) return;
            parts.server = side.side === 'server';
            parts.shared = side.side === 'shared';
        }
        if (parts.web && !parts.client) {
            vscode.window.showInformationMessage('Страницу открывает клиентский скрипт — client.lua добавлен автоматически.');
        }
    }

    // 2. Описание мода.
    const id = await vscode.window.showInputBox({
        title: 'Новый мод (3/3): идентификатор',
        prompt: 'Латиница, цифры и _ (станет именем папки)',
        placeHolder: 'my_mod',
        validateInput: (value) => {
            if (!/^[A-Za-z0-9_]+$/.test(value)) return 'Только латиница, цифры и _';
            if (fs.existsSync(path.join(modsDir, value))) return 'Мод с таким id уже есть';
            return undefined;
        },
    });
    if (!id) return;

    const name = await vscode.window.showInputBox({ title: 'Название мода', value: id });
    if (name === undefined) return;

    const description = await vscode.window.showInputBox({ title: 'Описание (можно пропустить)', prompt: 'Одна строка: что делает мод' });
    if (description === undefined) return;

    const author = await vscode.window.showInputBox({
        title: 'Автор',
        value: context.globalState.get('cossacks3.author', ''),
    });
    if (author === undefined) return;
    await context.globalState.update('cossacks3.author', author);

    const dir = path.join(modsDir, id);
    const files = modFiles({ id, name: name || id, author, description, parts });
    for (const [rel, content] of Object.entries(files)) {
        const target = path.join(dir, rel);
        fs.mkdirSync(path.dirname(target), { recursive: true });
        fs.writeFileSync(target, content, 'utf8');
    }

    const doc = await vscode.workspace.openTextDocument(path.join(dir, mainFile(files)));
    await vscode.window.showTextDocument(doc);
    const created = Object.keys(files).join(', ');
    vscode.window.showInformationMessage(`Мод «${id}» создан в ${dir}: ${created}`);
}

async function openLog() {
    const root = currentRoot || detectRoot();
    const logPath = root && path.join(root, 'modloader.log');
    if (!logPath || !fs.existsSync(logPath)) {
        vscode.window.showWarningMessage('modloader.log не найден: запустите игру через Cossacks3Launcher.exe или укажите папку modloader.');
        return;
    }
    const doc = await vscode.workspace.openTextDocument(logPath);
    const editor = await vscode.window.showTextDocument(doc, { preview: false });
    const last = Math.max(doc.lineCount - 1, 0);
    editor.revealRange(new vscode.Range(last, 0, last, 0), vscode.TextEditorRevealType.Default);
}

module.exports = { activate, deactivate };
