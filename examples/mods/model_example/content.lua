-- Своя модель: .glb (Blender: File > Export > glTF 2.0, формат glTF Binary) вместо модели игры.
-- Пути osm/texture — из .actor (MeshObjects.LoadFromFile) и .mat (Material.Texture.image) модели.
model {
    file = "models/box.glb",
    osm = "data/actors/buildings/ukr/ukrcen.osm",
    texture = "data/materials/buildings/ukr/ukrcen.dds",
}
