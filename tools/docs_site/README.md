# Сайт документации (React)

Статический сайт по всему Lua API + каталог нативов + гайды (`*.md`).

```bash
cd tools/docs_site/app
npm install

# 1. Данные из репозитория (api/*.lua, *.md, NativesTable.inc):
cd ../.. && python tools/gen_native_catalog.py && python tools/docs_site/gen.py

# 2. Разработка / сборка:
cd tools/docs_site/app
npm run dev      # http://localhost:5173
npm run build    # статика в app/dist (index.html + data/*.json)
npm run preview  # проверка сборки
```

Библиотеки: `react`, `react-dom`, `react-markdown` (рендер гайдов и шапок
модулей). Роутинг — hash (`#/module/camera`, `#/guide/MODDING`, `#/natives`),
поиск и фильтры — на клиенте, тяжёлые `guides.json`/`natives.json` грузятся
fetch'ем по требованию.

После правок `api/*.lua` или `*.md` — прогони пункт 1 и пересобери.
