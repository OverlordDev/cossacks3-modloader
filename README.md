# Cossacks 3 Modding

Расширение для VS Code — инструменты для мододелов [Cossacks 3 Modloader](https://github.com/OverlordDev/cossacks3-modloader).

## Что умеет

- **Автодополнение и подсказки по всему API модлоадера** — `events.`, `units.`, `buildings.`, `balance.`, `objects.`, `ui.`, `web.`, `gfx.` и так далее.
  Подсказки берутся **прямо из папки `modloader/api` вашей игры**, поэтому после обновления модлоадера
  расширение обновлять не нужно — оно всегда совпадает с установленной версией.
- **Проверка `manifest.lua`**: обязательный `id`, `server` и `shared` не вместе, значения `multiplayer`,
  несуществующие файлы скриптов, опечатки в названиях полей.
- **Генератор мода** — команда `Cossacks 3: Создать мод`. Выбираете готовый шаблон (HUD, баланс, сетевой мод,
  новые нации и юниты, графика) или отмечаете нужное сами: `client.lua`, `server.lua` / `shared.lua`,
  `content.lua`, `web/hud.html`, общий модуль `utils.lua`, папки `assets/` и `patches/`. Манифест собирается
  под выбор: прописаны нужные скрипты и `files`, `multiplayer` выставляется сам (`optional`, если мод ничего не
  меняет в мире; `required` — если меняет). Внутри — рабочие примеры: клавиша, HUD, связка клиент → хост.
- **Сниппеты** — `cs3manifest`, `cs3event`, `cs3bind`, `cs3balance`, `cs3net`, `cs3hud`, `cs3button`,
  `cs3objects`, `cs3unit`, `cs3nation`.
- **modloader.log** одной командой, кнопка статуса `CS3 API` в нижней панели.

## Как пользоваться

1. Установите расширение (вместе с ним поставится Lua Language Server от sumneko).
2. Откройте в VS Code папку `<игра>/modloader/mods/<ваш мод>` или всю папку `<игра>/modloader`.
3. Пишите код. Внизу слева должно быть `✓ CS3 API` — значит, папка `api` найдена.

Расширение ищет `modloader/api` само: поднимается вверх от открытого файла. Если папка мода лежит в другом
месте, выполните `Cossacks 3: Указать папку modloader` или задайте `cossacks3.modloaderPath` в настройках.

## Настройки

| настройка | что делает |
|---|---|
| `cossacks3.modloaderPath` | путь к папке `modloader` (пусто — искать автоматически) |
| `cossacks3.validateManifest` | проверять `manifest.lua` |
| `cossacks3.configureLuaServer` | сам подключать `api` к Lua Language Server (пишет в `.vscode/settings.json` рабочей области) |

## Как это работает

Расширение прописывает в `Lua.workspace.library` две папки: `<игра>/modloader/api` (живой код API — типы и
функции выводятся из него) и собственные описания того, что создаёт сама DLL (`events`, `game`, `net`,
`input`, `web`, `ui`, `gfx`, `savedata`, `native`, `player`, `world`). Ваши собственные записи в
`Lua.workspace.library` не затрагиваются.

Описания функций из C++ поставляются с расширением. Если в модлоадере появится новая такая функция,
подсказка для неё появится с обновлением расширения; функции из `api/*.lua` подхватываются сразу.

## Ссылки

- [Быстрый старт для мододела](https://github.com/OverlordDev/cossacks3-modloader/blob/main/MODDING.md)
- [Полная документация](https://github.com/OverlordDev/cossacks3-modloader/blob/main/DOCUMENTATION.md)
