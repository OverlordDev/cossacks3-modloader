const vscode = require('vscode');
const fs = require('fs');
const path = require('path');

const LUA_SELECTOR = [{ language: 'lua' }, { language: 'luau' }];

function isDirectory(value) {
  try { return fs.statSync(value).isDirectory(); } catch (_) { return false; }
}

function isFile(value) {
  try { return fs.statSync(value).isFile(); } catch (_) { return false; }
}

function normalizePath(value) {
  return path.normalize(value).replace(/[\\/]$/, '').toLowerCase();
}

function expandSetting(value) {
  if (!value) return '';
  let result = value;
  const folder = vscode.workspace.workspaceFolders && vscode.workspace.workspaceFolders[0];
  if (folder) result = result.replace(/\$\{workspaceFolder\}/g, folder.uri.fsPath);
  return path.normalize(result);
}

function findApiDirectory(fileName) {
  const config = vscode.workspace.getConfiguration('modloader');
  const explicit = expandSetting(config.get('apiPath', ''));
  if (explicit && isDirectory(explicit)) return explicit;
  if (config.get('autoDiscover', true) === false) return '';

  let current = isFile(fileName) ? path.dirname(fileName) : fileName;
  const visited = new Set();
  while (current && !visited.has(normalizePath(current))) {
    visited.add(normalizePath(current));
    const direct = path.join(current, 'api');
    if (isDirectory(direct)) return direct;

    const modloaderApi = path.join(current, 'modloader', 'api');
    if (isDirectory(modloaderApi)) return modloaderApi;

    const name = path.basename(current).toLowerCase();
    if (name === 'mods') {
      const sibling = path.join(path.dirname(current), 'api');
      if (isDirectory(sibling)) return sibling;
    }
    if (name === 'modloader') {
      const sibling = path.join(current, 'api');
      if (isDirectory(sibling)) return sibling;
    }

    const parent = path.dirname(current);
    if (parent === current) break;
    current = parent;
  }

  for (const folder of vscode.workspace.workspaceFolders || []) {
    const candidates = [
      path.join(folder.uri.fsPath, 'api'),
      path.join(folder.uri.fsPath, 'modloader', 'api')
    ];
    for (const candidate of candidates) if (isDirectory(candidate)) return candidate;
  }
  return '';
}

function splitArguments(text) {
  if (!text.trim()) return [];
  const result = [];
  let start = 0;
  let level = 0;
  let quote = '';
  for (let i = 0; i < text.length; i += 1) {
    const ch = text[i];
    if (quote) {
      if (ch === quote && text[i - 1] !== '\\') quote = '';
      continue;
    }
    if (ch === '"' || ch === "'") { quote = ch; continue; }
    if (ch === '{' || ch === '(' || ch === '[') level += 1;
    else if (ch === '}' || ch === ')' || ch === ']') level -= 1;
    else if (ch === ',' && level === 0) {
      result.push(text.slice(start, i).trim());
      start = i + 1;
    }
  }
  result.push(text.slice(start).trim());
  return result.filter(Boolean);
}

function nativeArguments(declaration) {
  const match = declaration.match(/\((.*)\)/);
  if (!match || !match[1].trim()) return [];
  return match[1].split(';').map(part => {
    const value = part.trim().replace(/^(const|var|out|ref)\s+/i, '');
    return value.split(':')[0].trim();
  }).filter(Boolean);
}

function cleanComment(lines) {
  return lines
    .map(line => line.replace(/^\s*--\s?/, '').trimEnd())
    .join('\n')
    .replace(/^\s*\n+|\n+\s*$/g, '')
    .trim();
}

function parseLuaFile(fileName) {
  let source;
  try { source = fs.readFileSync(fileName, 'utf8'); } catch (_) { return []; }
  const lines = source.split(/\r?\n/);
  const symbols = [];
  let comments = [];

  const addSymbol = (name, kind, args, line, doc) => {
    if (!name || name.startsWith('_')) return;
    symbols.push({
      name,
      kind,
      args: args || [],
      line,
      fileName,
      doc: doc || ''
    });
  };

  for (let index = 0; index < lines.length; index += 1) {
    const line = lines[index];
    const trimmed = line.trim();
    if (/^--/.test(trimmed)) {
      comments.push(line);
      continue;
    }
    if (!trimmed || /^--\[/.test(trimmed)) {
      if (!trimmed) comments = [];
      continue;
    }

    const doc = cleanComment(comments);
    comments = [];

    const namespace = line.match(/^\s*(?:local\s+)?([A-Za-z_][\w]*)\s*=\s*(?:\1\s+or\s+)?\{\s*\}/);
    if (namespace) addSymbol(namespace[1], 'namespace', [], index, doc);
    if (/^\s*NATIVE_CATALOG\s*=\s*\{/.test(line)) {
      addSymbol('native', 'namespace', [], index, doc || 'Native functions from the generated Cossacks 3 catalog.');
    }

    const nativeEntry = line.match(/^\s*\["([^"]+)"\]\s*=\s*\{\s*"[^"]*"\s*,\s*"([^"]*)"\s*,\s*"([^"]*)"\s*,\s*"([^"]*)"\s*,\s*"([^"]*)"/);
    if (nativeEntry) {
      const nativeName = nativeEntry[1];
      const declaration = nativeEntry[2];
      const side = nativeEntry[3];
      const risk = nativeEntry[4];
      const category = nativeEntry[5];
      addSymbol(`native.${nativeName}`, 'function', nativeArguments(declaration), index,
        `Native declaration: \`${declaration}\`\n\nSide: \`${side}\`  \nRisk: \`${risk}\`  \nCategory: \`${category}\``);
      continue;
    }

    const func = line.match(/^\s*(?:local\s+)?function\s+([A-Za-z_][\w]*(?:[.:][A-Za-z_][\w]*)*)\s*\(([^)]*)\)/);
    if (func) {
      addSymbol(func[1], 'function', splitArguments(func[2]), index, doc);
      continue;
    }

    const publicAssignment = line.match(/^\s*([A-Za-z_][\w]*(?:\.[A-Za-z_][\w]*)+)\s*=\s*function\s*\(([^)]*)\)/);
    if (publicAssignment) {
      addSymbol(publicAssignment[1], 'function', splitArguments(publicAssignment[2]), index, doc);
    }
  }
  return symbols;
}

class ApiIndex {
  constructor(output) {
    this.output = output;
    this.apiDir = '';
    this.symbols = new Map();
    this.namespaces = new Map();
    this.watcher = undefined;
  }

  disposeWatcher() {
    if (this.watcher) this.watcher.dispose();
    this.watcher = undefined;
  }

  dispose() {
    this.disposeWatcher();
  }

  setDirectory(apiDir) {
    if (!apiDir) return false;
    if (normalizePath(apiDir) === normalizePath(this.apiDir) && this.symbols.size) return false;
    this.apiDir = apiDir;
    this.disposeWatcher();
    this.watcher = vscode.workspace.createFileSystemWatcher(
      new vscode.RelativePattern(apiDir, '*.lua')
    );
    const reload = () => this.load();
    this.watcher.onDidCreate(reload);
    this.watcher.onDidChange(reload);
    this.watcher.onDidDelete(reload);
    return true;
  }

  load() {
    this.symbols.clear();
    this.namespaces.clear();
    if (!this.apiDir || !isDirectory(this.apiDir)) return;
    let files = [];
    try { files = fs.readdirSync(this.apiDir).filter(name => name.endsWith('.lua')); } catch (_) { return; }
    for (const name of files.sort()) {
      const parsed = parseLuaFile(path.join(this.apiDir, name));
      for (const symbol of parsed) {
        if (!this.symbols.has(symbol.name)) this.symbols.set(symbol.name, symbol);
        const root = symbol.name.split(/[.:]/)[0];
        if (symbol.kind === 'namespace') this.namespaces.set(root, symbol);
      }
    }
    this.output.appendLine(`[modloader] indexed ${this.symbols.size} API symbols from ${this.apiDir}`);
  }

  ensureFor(document) {
    const directory = findApiDirectory(document.uri.fsPath);
    if (!directory) return false;
    const changed = this.setDirectory(directory);
    if (changed || this.symbols.size === 0) this.load();
    return true;
  }

  get(name) {
    return this.symbols.get(name) || this.symbols.get(name.replace(/:/g, '.'));
  }

  all() { return [...this.symbols.values()]; }
}

function symbolDocumentation(symbol) {
  const lines = [];
  if (symbol.doc) lines.push(symbol.doc);
  if (symbol.kind === 'function') {
    lines.push('', `\`${symbol.name}(${symbol.args.join(', ')})\``);
  } else if (symbol.kind === 'namespace') {
    lines.push('', `API namespace \`${symbol.name}\``);
  }
  lines.push('', `Source: \`${path.basename(symbol.fileName)}:${symbol.line + 1}\``);
  return lines.join('\n');
}

function symbolAt(document, position) {
  const line = document.lineAt(position.line).text;
  const before = line.slice(0, position.character);
  const match = before.match(/([A-Za-z_][\w.:]*)$/);
  return match ? match[1] : '';
}

function completionItems(index, document, position) {
  const token = symbolAt(document, position);
  const separator = Math.max(token.lastIndexOf('.'), token.lastIndexOf(':'));
  const root = separator >= 0 ? token.slice(0, separator) : '';
  const fragment = separator >= 0 ? token.slice(separator + 1) : token;
  const items = [];
  const seen = new Set();

  for (const symbol of index.all()) {
    const nameSeparator = Math.max(symbol.name.lastIndexOf('.'), symbol.name.lastIndexOf(':'));
    const symbolRoot = nameSeparator >= 0 ? symbol.name.slice(0, nameSeparator) : '';
    const shortName = nameSeparator >= 0 ? symbol.name.slice(nameSeparator + 1) : symbol.name;
    if (root && symbolRoot !== root) continue;
    if (!shortName.toLowerCase().startsWith(fragment.toLowerCase())) continue;
    const key = `${symbolRoot}:${shortName}`;
    if (seen.has(key)) continue;
    seen.add(key);
    const item = new vscode.CompletionItem(shortName, symbol.kind === 'function'
      ? vscode.CompletionItemKind.Function
      : vscode.CompletionItemKind.Module);
    item.detail = symbol.kind === 'function'
      ? `${symbol.name}(${symbol.args.join(', ')})`
      : `Cossacks 3 Modloader API: ${symbol.name}`;
    item.documentation = new vscode.MarkdownString(symbolDocumentation(symbol));
    item.insertText = shortName;
    item.filterText = shortName;
    item.range = new vscode.Range(
      new vscode.Position(position.line, position.character - fragment.length),
      position
    );
    if (symbol.kind === 'function') item.commitCharacters = ['('];
    items.push(item);
  }
  return items;
}

function findCallName(document, position) {
  const line = document.lineAt(position.line).text.slice(0, position.character);
  const match = line.match(/([A-Za-z_][\w.:]*)\([^()]*$/);
  return match ? match[1] : '';
}

function activeArgument(document, position) {
  const line = document.lineAt(position.line).text.slice(0, position.character);
  const open = line.lastIndexOf('(');
  if (open < 0) return 0;
  return splitArguments(line.slice(open + 1)).length - (line.endsWith(',') ? 0 : 1);
}

function activate(context) {
  const output = vscode.window.createOutputChannel('Cossacks 3 Modloader API');
  const index = new ApiIndex(output);
  const status = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Right, 20);
  status.command = 'modloader.showApiPath';
  status.text = '$(symbol-namespace) Modloader API';
  status.tooltip = 'Cossacks 3 Modloader API: click to show the discovered api folder';
  context.subscriptions.push(output, status, index);

  const refresh = () => {
    const editor = vscode.window.activeTextEditor;
    if (!editor || !['lua', 'luau'].includes(editor.document.languageId)) {
      status.hide();
      return;
    }
    if (index.ensureFor(editor.document)) {
      status.show();
      status.tooltip = `Modloader API: ${index.apiDir}`;
    } else {
      status.hide();
    }
  };

  context.subscriptions.push(
    vscode.window.onDidChangeActiveTextEditor(refresh),
    vscode.workspace.onDidOpenTextDocument(refresh),
    vscode.commands.registerCommand('modloader.reloadApi', () => {
      const editor = vscode.window.activeTextEditor;
      if (editor) index.setDirectory(findApiDirectory(editor.document.uri.fsPath));
      index.load();
      vscode.window.showInformationMessage(`Modloader API reloaded: ${index.symbols.size} symbols`);
    }),
    vscode.commands.registerCommand('modloader.showApiPath', () => {
      if (index.apiDir) vscode.window.showInformationMessage(`Modloader API: ${index.apiDir} (${index.symbols.size} symbols)`);
      else vscode.window.showWarningMessage('Modloader API folder was not found');
    })
  );

  context.subscriptions.push(
    vscode.languages.registerCompletionItemProvider(LUA_SELECTOR, {
      provideCompletionItems(document, position) {
        if (!index.ensureFor(document)) return [];
        return completionItems(index, document, position);
      }
    }, '.', ':'),
    vscode.languages.registerHoverProvider(LUA_SELECTOR, {
      provideHover(document, position) {
        if (!index.ensureFor(document)) return undefined;
        const token = symbolAt(document, position);
        const symbol = index.get(token);
        if (!symbol) return undefined;
        return new vscode.Hover(new vscode.MarkdownString(symbolDocumentation(symbol)));
      }
    }),
    vscode.languages.registerSignatureHelpProvider(LUA_SELECTOR, {
      provideSignatureHelp(document, position) {
        if (!index.ensureFor(document)) return undefined;
        const name = findCallName(document, position);
        const symbol = index.get(name);
        if (!symbol || symbol.kind !== 'function') return undefined;
        const signature = new vscode.SignatureInformation(
          `${symbol.name}(${symbol.args.join(', ')})`,
          new vscode.MarkdownString(symbol.doc || `Cossacks 3 Modloader API: ${symbol.name}`)
        );
        signature.parameters = symbol.args.map(arg => new vscode.ParameterInformation(arg));
        const help = new vscode.SignatureHelp();
        help.signatures = [signature];
        help.activeSignature = 0;
        help.activeParameter = Math.max(0, Math.min(activeArgument(document, position), symbol.args.length - 1));
        return help;
      }
    }, '(', ','),
    vscode.languages.registerDefinitionProvider(LUA_SELECTOR, {
      provideDefinition(document, position) {
        if (!index.ensureFor(document)) return undefined;
        const symbol = index.get(symbolAt(document, position));
        if (!symbol) return undefined;
        return new vscode.Location(
          vscode.Uri.file(symbol.fileName),
          new vscode.Position(symbol.line, 0)
        );
      }
    })
  );

  refresh();
}

function deactivate() {}

module.exports = { activate, deactivate };
