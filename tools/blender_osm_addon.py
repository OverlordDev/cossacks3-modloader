# Blender addon: Cossacks 3 static mesh (.osm) import/export + .actor snippet.
#
# Format (reversed from GSC .osm, MD2 heritage, all little-endian):
#   i32 magic = 0x32504449 ("IDP2"), i32 version = 8
#   i32 skinWidth = 256, skinHeight = 256 (UVs are 0..1 floats, informational)
#   i32 frameSize = 16 + numVerts*16
#   i32 numSkins = 1, numVerts, numST, numTris, numGLCmds = 0, numFrames = 1
#   i32 offsetSkins = 68, offsetST, offsetTris, offsetFrames,
#       offsetGLCmds = filesize, offsetEnd = filesize
#   char skins[1][64] (placeholder, real material comes from .actor -> materials lib)
#   float st[numST][2]              (UV, 0..1)
#   struct tri { i32 v[3]; i32 st[3]; }  (32-bit indices; winding CW = reversed vs Blender)
#   struct frame { byte head[16] (constant stamp); struct vert { float x,y,z; i32 flag=1; } }
#
# Install: Blender -> Edit -> Preferences -> Add-ons -> Install -> select this file,
# enable "Cossacks 3 OSM static mesh". File -> Import/Export -> Cossacks 3 (.osm).
# Test in game: back up the original .osm, drop the exported file under the same name
# into data/actors/..., load a map containing that object. Z is up (as in Blender),
# units are meters. If faces look inside-out, toggle "Flip winding" on export.

bl_info = {
    "name": "Cossacks 3 OSM static mesh",
    "author": "Cossacks 3 Modloader",
    "version": (0, 1, 0),
    "blender": (3, 0, 0),
    "category": "Import-Export",
}

import struct

import bpy
from bpy_extras.io_utils import ExportHelper, ImportHelper
from bpy.props import BoolProperty, FloatProperty, StringProperty


MAGIC = 0x32504449
VERSION = 8
# Constant 16-byte frame stamp, identical in every shipped .osm.
FRAME_HEAD = struct.pack("<4i", 1296126534, 808460357, 774778416, 3026478)
SKIN_PLACEHOLDER = b"SkinBitMap" + b":" * (64 - 10)


def _read_osm(path):
    with open(path, "rb") as f:
        d = f.read()
    h = struct.unpack_from("<17i", d, 0)
    magic, ver = h[0], h[1]
    if magic != MAGIC or ver != VERSION:
        raise ValueError(f"not a Cossacks3 .osm (magic={magic:#x}, ver={ver})")
    _magic, _ver, _sw, _sh, frame_size, _n_skins, n_verts, n_st, n_tris, \
        _n_gl, n_frames, off_skins, off_st, off_tris, off_frames, _off_gl, _off_end = h
    st = [struct.unpack_from("<2f", d, off_st + i * 8) for i in range(n_st)]
    tris = [struct.unpack_from("<6i", d, off_tris + i * 24) for i in range(n_tris)]
    verts = []
    for i in range(n_verts):
        x, y, z, _flag = struct.unpack_from("<3fi", d, off_frames + 16 + i * 16)
        verts.append((x, y, z))
    return verts, st, tris


def _write_osm(path, tris_data):
    """tris_data: list of ((x,y,z)*3, (u,v)*3). Builds split verts/STs, writes file."""
    vtab, stab, tris = {}, {}, []  # key -> [index, original values]
    for (poss, uvs) in tris_data:
        vi, si = [], []
        for p in poss:
            key = (round(p[0], 6), round(p[1], 6), round(p[2], 6))
            if key not in vtab:
                vtab[key] = [len(vtab), (p[0], p[1], p[2])]
            vi.append(vtab[key][0])
        for t in uvs:
            key = (round(t[0], 6), round(t[1], 6))
            if key not in stab:
                stab[key] = [len(stab), (t[0], t[1])]
            si.append(stab[key][0])
        tris.append((vi, si))
    n_verts, n_st, n_tris = len(vtab), len(stab), len(tris)
    frame_size = 16 + n_verts * 16
    off_skins, off_st = 68, 132
    off_tris = off_st + n_st * 8
    off_frames = off_tris + n_tris * 24
    end = off_frames + frame_size
    inv_v = {v[0]: v[1] for v in vtab.values()}
    inv_s = {v[0]: v[1] for v in stab.values()}
    with open(path, "wb") as f:
        f.write(struct.pack("<17i", MAGIC, VERSION, 256, 256, frame_size,
                            1, n_verts, n_st, n_tris, 0, 1,
                            off_skins, off_st, off_tris, off_frames, end, end))
        f.write(SKIN_PLACEHOLDER)
        for i in range(n_st):
            f.write(struct.pack("<2f", *inv_s[i]))
        for (vi, si) in tris:
            f.write(struct.pack("<6i", vi[0], vi[1], vi[2], si[0], si[1], si[2]))
        f.write(FRAME_HEAD)
        for i in range(n_verts):
            f.write(struct.pack("<3fi", *inv_v[i], 1))
    return n_verts, n_st, n_tris


def actor_snippet(base_name, directory, stages=(None, "1", "2", "3", "4"),
                  deaths=("death1", "death2"), ref="refbuilding"):
    """Generates .actor text in the style of eurgol.actor."""
    L = [f"section.begin {{refurl=.\\data\\actors\\ref\\{ref}.actor}}"]
    L.append(f"   ActorList.Items[0].Name = {base_name}.mesh")
    L.append(f"   ActorList.Items[0].LODList.Items[0].MeshObjects.LoadFromFile = {directory}{base_name}.osm")
    for s in stages:
        if s is None:
            continue
        L.append(f"   ActorList.Items[*] : struct.begin {{refurl=.\\data\\actors\\ref\\{ref}.actor; refkey=.ActorList.Items[0]}}")
        L.append(f"      Name = {base_name}{s}.mesh")
        L.append(f"      LODList.Items[0].MeshObjects.LoadFromFile = {directory}{base_name}{s}.osm")
        L.append("   struct.end")
    for s in deaths:
        L.append(f"   ActorList.Items[*] : struct.begin {{refurl=.\\data\\actors\\ref\\{ref}.actor; refkey=.ActorList.Items[0]}}")
        L.append(f"      Name = {base_name}_{s}.mesh")
        L.append(f"      LODList.Items[0].MeshObjects.LoadFromFile = {directory}{base_name}_{s}.osm")
        L.append("   struct.end")
    L.append("section.end")
    return "\r\n".join(L) + "\r\n"


class C3OSM_Export(bpy.types.Operator, ExportHelper):
    bl_idname = "export_scene.c3_osm"
    bl_label = "Export Cossacks 3 (.osm)"
    filename_ext = ".osm"
    filter_glob: StringProperty(default="*.osm", options={"HIDDEN"})
    scale: FloatProperty(name="Scale", default=1.0)
    flip_winding: BoolProperty(name="Flip winding",
                               description="Reverse triangle order (shipped files are CW vs Blender CCW)",
                               default=True)
    write_actor: BoolProperty(name="Write .actor snippet",
                              description="Write a <name>.actor.txt next to the mesh",
                              default=True)

    def execute(self, context):
        obj = context.active_object
        if obj is None or obj.type != "MESH":
            self.report({"ERROR"}, "select a MESH object")
            return {"CANCELLED"}
        mesh = obj.to_mesh()
        try:
            mesh.calc_loop_triangles()
            uv_layer = mesh.uv_layers.active
            M = obj.matrix_world
            tris_data = []
            for tri in mesh.loop_triangles:
                loops = tri.loops
                if self.flip_winding:
                    loops = (loops[2], loops[1], loops[0])
                poss, uvs = [], []
                for li in loops:
                    v = mesh.vertices[mesh.loops[li].vertex_index]
                    p = M @ v.co
                    poss.append((p.x * self.scale, p.y * self.scale, p.z * self.scale))
                    if uv_layer is not None:
                        uv = uv_layer.data[li].uv
                        uvs.append((uv.x, uv.y))
                    else:
                        uvs.append((0.0, 0.0))
                tris_data.append((poss, uvs))
        finally:
            obj.to_mesh_clear()
        nv, ns, nt = _write_osm(self.filepath, tris_data)
        if self.write_actor:
            import os
            base = os.path.splitext(os.path.basename(self.filepath))[0]
            with open(os.path.splitext(self.filepath)[0] + ".actor.txt",
                      "w", encoding="utf-8", newline="") as f:
                f.write(actor_snippet(base, r".\data\actors\buildings\commoneur\\"))
        self.report({"INFO"}, f"wrote {nv} verts, {ns} uvs, {nt} tris")
        return {"FINISHED"}


class C3OSM_Import(bpy.types.Operator, ImportHelper):
    bl_idname = "import_scene.c3_osm"
    bl_label = "Import Cossacks 3 (.osm)"
    filename_ext = ".osm"
    filter_glob: StringProperty(default="*.osm", options={"HIDDEN"})

    def execute(self, context):
        import os
        try:
            verts, st, tris = _read_osm(self.filepath)
        except ValueError as e:
            self.report({"ERROR"}, str(e))
            return {"CANCELLED"}
        name = os.path.splitext(os.path.basename(self.filepath))[0]
        me = bpy.data.meshes.new(name)
        # expand split verts: one mesh vert per tri corner (keeps UV seams exact)
        V, UV, F = [], [], []
        for (v0, v1, v2, s0, s1, s2) in tris:
            base = len(V)
            V += [verts[v0], verts[v1], verts[v2]]
            UV += [st[s0], st[s1], st[s2]]
            F.append((base + 2, base + 1, base))  # un-flip CW back to Blender CCW
        me.from_pydata(V, [], F)
        uv = me.uv_layers.new(name="UVMap")
        for poly in me.polygons:
            for li in poly.loop_indices:
                uv.data[li].uv = UV[li]
        me.update()
        ob = bpy.data.objects.new(name, me)
        context.collection.objects.link(ob)
        self.report({"INFO"}, f"imported {len(verts)} verts, {len(tris)} tris")
        return {"FINISHED"}


def menu_export(self, context):
    self.layout.operator(C3OSM_Export.bl_idname, text="Cossacks 3 (.osm)")


def menu_import(self, context):
    self.layout.operator(C3OSM_Import.bl_idname, text="Cossacks 3 (.osm)")


def register():
    bpy.utils.register_class(C3OSM_Export)
    bpy.utils.register_class(C3OSM_Import)
    bpy.types.TOPBAR_MT_file_export.append(menu_export)
    bpy.types.TOPBAR_MT_file_import.append(menu_import)


def unregister():
    bpy.types.TOPBAR_MT_file_export.remove(menu_export)
    bpy.types.TOPBAR_MT_file_import.remove(menu_import)
    bpy.utils.unregister_class(C3OSM_Import)
    bpy.utils.unregister_class(C3OSM_Export)


if __name__ == "__main__":
    register()
