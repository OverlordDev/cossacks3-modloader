# Cossacks 3 Modloader — сайт документации

Готовый статический сайт (ветка публикуется через GitHub Pages: *Settings → Pages → Branch: `docs-site`, папка `/ (root)`*).
Исходников модлоадера здесь нет — только собранные страницы и генератор.

## Обновить сайт

Страницы собираются из папки `api/` и справочников репозитория модлоадера (ветка `master`):

```bash
git clone https://github.com/OverlordDev/cossacks3-modloader.git ../cossacks3-modloader
python generator/gen_docs.py --repo ../cossacks3-modloader --out .
git add -A && git commit -m "Update docs" && git push
```

Зависимостей нет — только Python 3. Стили и скрипт сайта — `generator/docs_site/`.
