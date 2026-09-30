# Cossacks 3 Modloader API for VS Code

Лёгкое расширение VS Code для Lua-модов Cossacks 3 Modloader.

## Что умеет

- автоматически находит `modloader/api` от текущего Lua-файла;
- работает с путём вида `modloader/mods/my_mod/client.lua`;
- читает реальные `.lua` API-модули, а не отдельную вручную поддерживаемую копию;
- показывает completion после `units.`, `abilities.`, `native.` и других namespaces;
- показывает hover-документацию из комментариев API-файлов;
- показывает signature help для функций;
- переходит к определению функции в исходном API-файле;
- автоматически переиндексирует API при изменении `.lua`;
- имеет команду `Modloader: Reload API`;
- показывает найденный путь API в status bar.

## Как устанавливать локально

1. В VS Code откройте каталог `tools/vscode-modloader` как extension development folder или упакуйте его в VSIX.
2. Для проверки можно нажать `F5` в Extension Development Host.
3. Откройте Lua-файл мода из папки:

   `...\\Cossacks 3\\modloader\\mods\\my_mod\\client.lua`

4. Расширение поднимется по каталогам и найдёт:

   `...\\Cossacks 3\\modloader\\api`

Если репозиторий открыт целиком, оно также найдёт `api` в корне workspace.

## Ручной путь

Если автоматическое обнаружение не подходит, укажите в настройках VS Code:

```json
{
  "modloader.apiPath": "C:\\\\Program Files (x86)\\\\Steam\\\\steamapps\\\\common\\\\Cossacks 3\\\\modloader\\\\api"
}
```

Или используйте `${workspaceFolder}`.

## Важно

Расширение индексирует реальные файлы API. Поэтому после добавления нового API-модуля в `modloader/api` подсказки появляются автоматически после изменения файла или команды `Modloader: Reload API`.

На первом этапе extension не подменяет полноценный Lua language server: он добавляет именно Cossacks 3 Modloader API, не выполняет код игры и не вызывает native-функции из VS Code.
