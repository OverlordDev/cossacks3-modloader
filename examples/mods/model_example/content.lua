-- Своя модель: .glb (Blender: File > Export > glTF 2.0, формат glTF Binary) вместо модели игры.
-- В box.glb кроме куба ("house") есть объекты stage1..stage4 и death1/death2 — стадии стройки и руины:
-- модлоадер делает из них ukrcen1..4.osm и ukrcen_death1/2.osm (кубы пониже).
-- Пути osm/texture — из .actor (MeshObjects.LoadFromFile) и .mat (Material.Texture.image) модели.
model {
    file = "models/box.glb",
    osm = "data/actors/buildings/ukr/ukrcen.osm",
    texture = "data/materials/buildings/ukr/ukrcen.dds",
}
