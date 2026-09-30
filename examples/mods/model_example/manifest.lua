-- Пример своей модели: ратуша Украины заменяется кубом 10x10x10 в клетку (models/box.glb).
-- Проверка конвертера .glb -> .osm/.dds. Нужен перезапуск игры.
return {
    id = "model_example",
    name = "Model Example",
    version = "0.1.0",
    author = "Illia",
    description = "Ратуша Украины становится кубом в красно-белую клетку: проверка своих моделей из Blender (.glb).",
    enabled = true,
    multiplayer = "optional", -- только внешний вид, партию не меняет
}
