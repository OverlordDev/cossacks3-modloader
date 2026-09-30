-- Своя модель: .glb (Blender: File > Export > glTF 2.0, формат glTF Binary) вместо модели игры.
-- В box.glb кроме куба ("house") есть объекты stage1..stage4 и death1/death2 — стадии стройки и руины:
-- модлоадер делает из них ukrcen1..4.osm и ukrcen_death1/2.osm (кубы пониже).
-- Текстура берётся из .glb (картинки материалов) и сама встаёт на место текстуры этой модели в игре
-- (материал ukrcen). Путь osm — из .actor модели (MeshObjects.LoadFromFile).
model {
    file = "models/box.glb",
    osm = "data/actors/buildings/ukr/ukrcen.osm",
}
