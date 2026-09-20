# Blender addon: Cossacks 3 static mesh (.osm) import/export + one-click game package.
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
# One-click flow ("Cossacks 3 building set"): select meshes named
#   <base>, <base>_1.._4, <base>_death1/2  ->  .osm set + .dds (via texconv)
#   + .actor + .mat snippet + INSTALL.txt, all staged in a folder that mirrors
#   data/. Copy staged files into the game (as admin), back up originals.
#   Needs texconv.exe (DirectXTex, free from Microsoft) for DDS DXT5 + mipmaps.
#
# Import flow: File -> Import -> Cossacks 3 actor (.actor + texture).
#   Pick e.g. data/actors/buildings/commoneur/eurgol.actor, set Game folder
#   (C:\...\Cossacks 3), get the mesh with its .dds on Base Color.
#   The .mat database (data/materials/**/*.mat) resolves mesh name -> texture.
#
# Install: Blender -> Edit -> Preferences -> Add-ons -> Install -> select this file,
# enable "Cossacks 3 OSM static mesh". File -> Import/Export -> Cossacks 3 (...).

bl_info = {
    "name": "Cossacks 3 OSM static mesh",
    "author": "Cossacks 3 Modloader",
    "version": (0, 4, 0),
    "blender": (3, 0, 0),
    "category": "Import-Export",
}

import struct
import pathlib

import bpy
from bpy_extras.io_utils import ExportHelper, ImportHelper
from bpy.props import BoolProperty, EnumProperty, FloatProperty, StringProperty


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
    n_verts, n_tris = len(vtab), len(tris)
    inv_v = {v[0]: v[1] for v in vtab.values()}
    inv_s = {v[0]: v[1] for v in stab.values()}
    # Invariant seen in every shipped file: numST >= numVerts
    # (the engine indexes the ST table by vertex in at least one path).
    # Pad with (0,0) if dedup produced fewer.
    while len(inv_s) < n_verts:
        inv_s[len(inv_s)] = (0.0, 0.0)
    n_st = len(inv_s)
    frame_size = 16 + n_verts * 16
    off_skins, off_st = 68, 132
    off_tris = off_st + n_st * 8
    off_frames = off_tris + n_tris * 24
    end = off_frames + frame_size
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


def mat_section(base_name, mat_subdir):
    return (
        "section.begin {refurl=.\\data\\materials\\ref\\refbuilding.mat}\r\n"
        f"   Material.Name = {base_name}\r\n"
        f"   Material.Texture.image = .\\data\\materials\\buildings\\{mat_subdir}\\{base_name}.dds\r\n"
        "section.end\r\n"
    )


def install_text(base_name, actors_subdir, mat_subdir, osm_files):
    L = [f"Install package '{base_name}' into Cossacks 3 (run file manager as admin):",
         "",
         "1. Back up everything you overwrite!",
         "",
         "2. Meshes + actor -> game actors dir:"]
    for fn in osm_files:
        L.append(f"   {fn}  ->  data\\actors\\{actors_subdir}\\{fn}")
    L.append(f"   {base_name}.actor  ->  data\\actors\\{actors_subdir}\\{base_name}.actor")
    L += ["",
          "3. Texture -> game materials dir:",
          f"   {base_name}.dds  ->  data\\materials\\buildings\\{mat_subdir}\\{base_name}.dds",
          "",
          "4. Material registration: open data\\materials\\buildings\\buildings.mat,",
          "   append the content of mat_add.txt at the end, save.",
          "",
          "5. Register the object in the game (so peasants use it, it has HP, etc.):",
          "   country.script _country_AddMember(...) with the new basename,",
          "   or replace an existing basename to skip this step.",
          ""]
    return "\r\n".join(L)


def convert_png_to_dds(png_path, dds_path, texconv="texconv.exe"):
    """texconv (DirectXTex) -> DDS DXT5 + full mipmap chain. Returns (ok, log)."""
    import shutil
    import subprocess
    exe = texconv if "\\" in texconv or "/" in texconv else (shutil.which(texconv) or texconv)
    try:
        r = subprocess.run([exe, "-f", "DXT5", "-m", "0", "-y",
                            "-o", str(pathlib.Path(dds_path).parent),
                            str(png_path)],
                           capture_output=True, text=True, timeout=120)
    except FileNotFoundError:
        return False, f"texconv not found: {exe}"
    except Exception as e:  # noqa: BLE001
        return False, str(e)
    # texconv names output after the input basename
    produced = pathlib.Path(dds_path).parent / (pathlib.Path(png_path).stem + ".dds")
    if r.returncode != 0 or not produced.exists():
        return False, (r.stdout + r.stderr)[-500:]
    if produced.resolve() != pathlib.Path(dds_path).resolve():
        produced.replace(dds_path)
    return True, f"DXT5 + mipmaps, {pathlib.Path(dds_path).stat().st_size} bytes"


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


def _collect_tris(obj, scale, flip_winding):
    """Returns (tris_data, warnings). tris_data: list of ((x,y,z)*3, (u,v)*3)."""
    from mathutils import Matrix
    warnings = []
    mesh = obj.to_mesh()
    try:
        mesh.calc_loop_triangles()
        uv_layer = mesh.uv_layers.active
        if uv_layer is None:
            warnings.append(f"{obj.name}: no active UV layer, exporting zero UVs")
        M = obj.matrix_world
        det = M.determinant()
        flip = flip_winding ^ (det < 0.0)  # mirrored objects already flip winding
        if det < 0.0:
            warnings.append(f"{obj.name}: negative scale/mirror detected, winding auto-corrected")
        if abs(det) < 1e-9:
            warnings.append(f"{obj.name}: degenerate transform (det=0)")
        if len(mesh.loop_triangles) == 0:
            warnings.append(f"{obj.name}: no triangles")
        tris_data = []
        for tri in mesh.loop_triangles:
            loops = tri.loops
            if flip:
                loops = (loops[2], loops[1], loops[0])
            poss, uvs = [], []
            for li in loops:
                v = mesh.vertices[mesh.loops[li].vertex_index]
                p = M @ v.co
                poss.append((p.x * scale, p.y * scale, p.z * scale))
                if uv_layer is not None:
                    uv = uv_layer.data[li].uv
                    uvs.append((uv.x, uv.y))
                else:
                    uvs.append((0.0, 0.0))
            tris_data.append((poss, uvs))
    finally:
        obj.to_mesh_clear()
    if tris_data:
        xs = [p[0] for t, _ in tris_data for p in t]
        ys = [p[1] for t, _ in tris_data for p in t]
        zs = [p[2] for t, _ in tris_data for p in t]
        size = max(max(xs) - min(xs), max(ys) - min(ys), max(zs) - min(zs))
        if size > 100.0:
            warnings.append(f"{obj.name}: bbox {size:.1f} m is huge, check scale")
        elif size < 0.01:
            warnings.append(f"{obj.name}: bbox {size:.4f} m is tiny, check scale")
    return tris_data, warnings


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
        tris_data, warnings = _collect_tris(obj, self.scale, self.flip_winding)
        if not tris_data:
            self.report({"ERROR"}, "no triangles to export")
            return {"CANCELLED"}
        nv, ns, nt = _write_osm(self.filepath, tris_data)
        for w in warnings:
            self.report({"WARNING"}, w)
        if self.write_actor:
            import os
            base = os.path.splitext(os.path.basename(self.filepath))[0]
            with open(os.path.splitext(self.filepath)[0] + ".actor.txt",
                      "w", encoding="utf-8", newline="") as f:
                f.write(actor_snippet(base, r".\data\actors\buildings\commoneur\\"))
        self.report({"INFO"}, f"wrote {nv} verts, {ns} uvs, {nt} tris")
        return {"FINISHED"}


# Building-set suffixes in game order: base, construction stages, death variants.
SET_SUFFIXES = ("", "_1", "_2", "_3", "_4", "_death1", "_death2")


class C3OSM_ExportSet(bpy.types.Operator, ExportHelper):
    bl_idname = "export_scene.c3_osm_set"
    bl_label = "Export Cossacks 3 building set (.osm + .actor)"
    filename_ext = ".actor"
    filter_glob: StringProperty(default="*.actor", options={"HIDDEN"})
    base_name: StringProperty(name="Base name",
                              description="e.g. mymine -> mymine.osm, mymine_1.osm ... + mymine.actor",
                              default="mymine")
    ref_template: EnumProperty(name="Template",
                               items=[("refbuilding", "Building", ""),
                                      ("refunit", "Unit (static prop)", ""),
                                      ("refobj", "Generic object", "")],
                               default="refbuilding")
    directory: StringProperty(name="Game directory",
                              description="LoadFromFile prefix used in .actor",
                              default=r".\data\actors\buildings\commoneur\\")
    actors_subdir: StringProperty(name="Actors subfolder",
                                  description="data\\actors\\... destination in INSTALL.txt",
                                  default=r"buildings\commoneur")
    mat_subdir: StringProperty(name="Materials subfolder",
                               description="data\\materials\\buildings\\... destination in INSTALL.txt",
                               default="commoneur")
    texture_mode: EnumProperty(name="Texture",
                               items=[("MATERIAL", "Active material image", "take Base Color image from first mesh"),
                                      ("FILE", "PNG file", "use the file below"),
                                      ("SKIP", "Skip", "no .dds, meshes only")],
                               default="MATERIAL")
    texture_file: StringProperty(name="Texture PNG", subtype="FILE_PATH", default="")
    texconv: StringProperty(name="texconv.exe",
                            description="DirectXTex converter (PATH name or full path)",
                            default="texconv.exe")
    scale: FloatProperty(name="Scale", default=1.0)
    flip_winding: BoolProperty(name="Flip winding", default=True)

    @staticmethod
    def _active_image(obj):
        for m in obj.data.materials:
            if m is None or m.node_tree is None:
                continue
            for n in m.node_tree.nodes:
                if n.type == "TEX_IMAGE" and n.image is not None:
                    return n.image
        return None

    def execute(self, context):
        import os
        objs = [o for o in context.selected_objects if o.type == "MESH"]
        if not objs:
            self.report({"ERROR"}, "select MESH objects named <base>, <base>_1.._4, <base>_death1/2")
            return {"CANCELLED"}
        by_name = {o.name: o for o in objs}
        order = []
        for sfx in SET_SUFFIXES:
            nm = self.base_name + sfx if sfx else self.base_name
            if nm in by_name:
                order.append((nm, by_name.pop(nm)))
        extras = sorted(by_name.values(), key=lambda o: o.name)
        outdir = os.path.dirname(self.filepath)
        # .actor always points into the real game tree, not the staging dir
        game_dir = f".\\data\\actors\\{self.actors_subdir}\\\\"
        exported = []
        for nm, o in order + [(o.name, o) for o in extras]:
            tris_data, warnings = _collect_tris(o, self.scale, self.flip_winding)
            for w in warnings:
                self.report({"WARNING"}, w)
            if not tris_data:
                self.report({"ERROR"}, f"{nm}: no triangles, skipped")
                continue
            nv, ns, nt = _write_osm(os.path.join(outdir, nm + ".osm"), tris_data)
            exported.append(nm)
            self.report({"INFO"}, f"{nm}.osm: {nv} verts, {nt} tris")
        # .actor: base mesh first, then stages/deaths in game order, then extras
        L = [f"section.begin {{refurl=.\\data\\actors\\ref\\{self.ref_template}.actor}}"]
        first = True
        for nm, _ in order + [(o.name, o) for o in extras]:
            meshname = nm + ".mesh"
            meshfile = game_dir + nm + ".osm"
            if first:
                L.append(f"   ActorList.Items[0].Name = {meshname}")
                L.append(f"   ActorList.Items[0].LODList.Items[0].MeshObjects.LoadFromFile = {meshfile}")
                first = False
            else:
                L.append(f"   ActorList.Items[*] : struct.begin {{refurl=.\\data\\actors\\ref\\{self.ref_template}.actor; refkey=.ActorList.Items[0]}}")
                L.append(f"      Name = {meshname}")
                L.append(f"      LODList.Items[0].MeshObjects.LoadFromFile = {meshfile}")
                L.append("   struct.end")
        L.append("section.end")
        actor_path = os.path.join(outdir, self.base_name + ".actor")
        with open(actor_path, "w", encoding="utf-8", newline="") as f:
            f.write("\r\n".join(L) + "\r\n")
        self.report({"INFO"}, f"wrote {actor_path} ({len(exported)} meshes)")
        # texture -> DDS DXT5 + mipmaps
        if self.texture_mode != "SKIP":
            png = None
            if self.texture_mode == "FILE" and self.texture_file:
                png = bpy.path.abspath(self.texture_file)
            else:
                img = None
                for _, o in order + [(o.name, o) for o in extras]:
                    img = self._active_image(o)
                    if img is not None:
                        break
                if img is not None:
                    png = os.path.join(outdir, self.base_name + "_tex.png")
                    img.filepath_raw = png
                    img.file_format = "PNG"
                    img.save()
            if png and os.path.exists(png):
                ok, log = convert_png_to_dds(
                    png, os.path.join(outdir, self.base_name + ".dds"), self.texconv)
                self.report({"INFO" if ok else "WARNING"}, f"DDS: {log}")
                if ok and self.texture_mode == "MATERIAL":
                    try:
                        os.remove(png)
                    except OSError:
                        pass
            else:
                self.report({"WARNING"}, "no texture found (need material image or PNG file), .dds skipped")
        # .mat snippet + INSTALL.txt
        with open(os.path.join(outdir, self.base_name + ".mat_add.txt"),
                  "w", encoding="utf-8", newline="") as f:
            f.write(mat_section(self.base_name, self.mat_subdir))
        with open(os.path.join(outdir, "INSTALL_" + self.base_name + ".txt"),
                  "w", encoding="utf-8", newline="") as f:
            f.write(install_text(self.base_name, self.actors_subdir, self.mat_subdir,
                                 [nm + ".osm" for nm, _ in order + [(o.name, o) for o in extras]]))
        self.report({"INFO"}, "package ready: .osm set + .dds + .actor + .mat_add.txt + INSTALL.txt")
        return {"FINISHED"}


_MAT_CACHE = {}  # game_root -> {material_name: image_relpath}


def _game_path(game_root, rel):
    """'.\\data\\materials\\x\\y.dds' -> absolute path under game_root."""
    p = rel.replace("\\", "/").lstrip("./")
    if p.lower().startswith("data/"):
        p = p[5:]
    return pathlib.Path(game_root) / "data" / p


def _load_mat_db(game_root):
    """Scans data/materials/**/*.mat once per game_root: name -> texture relpath."""
    global _MAT_CACHE
    if game_root in _MAT_CACHE:
        return _MAT_CACHE[game_root]
    import re
    db = {}
    matdir = pathlib.Path(game_root) / "data" / "materials"
    if matdir.is_dir():
        for f in sorted(matdir.rglob("*.mat")):
            try:
                txt = f.read_text(encoding="utf-8", errors="replace")
            except OSError:
                continue
            for m in re.finditer(
                    r"Material\.Name\s*=\s*(\S+)\s*\r?\n\s*Material\.Texture\.image\s*=\s*(\S+)",
                    txt):
                db.setdefault(m.group(1), m.group(2))
    _MAT_CACHE[game_root] = db
    return db


def _resolve_texture(game_root, mesh_base):
    """mesh_base like 'eurgol' -> absolute .dds path or None."""
    if not game_root:
        return None
    db = _load_mat_db(game_root)
    rel = db.get(mesh_base)
    if rel is None:
        return None
    p = _game_path(game_root, rel)
    return str(p) if p.is_file() else None


def _apply_texture(obj, dds_path, mat_name):
    """Creates Blender material with the DDS on Base Color. Returns log string."""
    try:
        if dds_path in bpy.data.images:
            img = bpy.data.images[dds_path]
        else:
            img = bpy.data.images.load(dds_path)
        img.name = mat_name
    except Exception as e:  # noqa: BLE001
        return f"texture load failed: {e}"
    mat = bpy.data.materials.get(mat_name) or bpy.data.materials.new(mat_name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.location = (-400, 300)
    if bsdf is not None:
        mat.node_tree.links.new(bsdf.inputs["Base Color"], tex.outputs["Color"])
    if obj.data.materials:
        obj.data.materials[0] = mat
    else:
        obj.data.materials.append(mat)
    return f"texture applied: {dds_path}"


def _parse_actor(actor_path):
    """Returns (mesh_base, mesh_relpath) of the first ActorList item."""
    import re
    txt = pathlib.Path(actor_path).read_text(encoding="utf-8", errors="replace")
    m = re.search(r"Name\s*=\s*(\S+?)\.mesh", txt)
    base = m.group(1) if m else None
    m2 = re.search(r"MeshObjects\.LoadFromFile\s*=\s*(\S+)", txt)
    return base, (m2.group(1) if m2 else None)


def _build_object(context, name, verts, st, tris):
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
    return ob


class C3OSM_Import(bpy.types.Operator, ImportHelper):
    bl_idname = "import_scene.c3_osm"
    bl_label = "Import Cossacks 3 (.osm)"
    filename_ext = ".osm"
    filter_glob: StringProperty(default="*.osm", options={"HIDDEN"})
    game_root: StringProperty(name="Game folder",
                              description="Cossacks 3 folder (the one with data/); enables auto-texture",
                              subtype="DIR_PATH", default="")
    with_texture: BoolProperty(name="Load texture", default=True)

    def execute(self, context):
        import os
        try:
            verts, st, tris = _read_osm(self.filepath)
        except ValueError as e:
            self.report({"ERROR"}, str(e))
            return {"CANCELLED"}
        name = os.path.splitext(os.path.basename(self.filepath))[0]
        ob = _build_object(context, name, verts, st, tris)
        msg = f"imported {len(verts)} verts, {len(tris)} tris"
        if self.with_texture:
            dds = _resolve_texture(bpy.path.abspath(self.game_root), name)
            if dds:
                msg += "; " + _apply_texture(ob, dds, name)
            else:
                msg += "; texture not found (set Game folder)"
        self.report({"INFO"}, msg)
        return {"FINISHED"}


class C3OSM_ImportActor(bpy.types.Operator, ImportHelper):
    bl_idname = "import_scene.c3_actor"
    bl_label = "Import Cossacks 3 actor (.actor + texture)"
    filename_ext = ".actor"
    filter_glob: StringProperty(default="*.actor", options={"HIDDEN"})
    game_root: StringProperty(name="Game folder",
                              description="Cossacks 3 folder (the one with data/)",
                              subtype="DIR_PATH", default="")
    with_texture: BoolProperty(name="Load texture", default=True)

    def execute(self, context):
        import os
        try:
            mesh_base, mesh_rel = _parse_actor(self.filepath)
        except OSError as e:
            self.report({"ERROR"}, f"can't read .actor: {e}")
            return {"CANCELLED"}
        if not mesh_rel:
            self.report({"ERROR"}, "no MeshObjects.LoadFromFile in .actor")
            return {"CANCELLED"}
        root = bpy.path.abspath(self.game_root)
        mesh_path = _game_path(root, mesh_rel) if root else None
        if mesh_path is None or not mesh_path.is_file():
            # fall back: mesh next to the .actor
            mesh_path = pathlib.Path(self.filepath).parent / (pathlib.Path(mesh_rel).name if mesh_rel else "")
        try:
            verts, st, tris = _read_osm(str(mesh_path))
        except (ValueError, OSError) as e:
            self.report({"ERROR"}, f"mesh load failed: {e}")
            return {"CANCELLED"}
        name = mesh_base or os.path.splitext(os.path.basename(str(mesh_path)))[0]
        ob = _build_object(context, name, verts, st, tris)
        msg = f"imported {name}: {len(verts)} verts, {len(tris)} tris"
        if self.with_texture:
            dds = _resolve_texture(root, name)
            if dds:
                msg += "; " + _apply_texture(ob, dds, name)
            else:
                msg += "; texture not found"
        self.report({"INFO"}, msg)
        return {"FINISHED"}


def menu_export(self, context):
    self.layout.operator(C3OSM_Export.bl_idname, text="Cossacks 3 (.osm)")
    self.layout.operator(C3OSM_ExportSet.bl_idname, text="Cossacks 3 building set (.osm + .actor)")


def menu_import(self, context):
    self.layout.operator(C3OSM_Import.bl_idname, text="Cossacks 3 (.osm)")
    self.layout.operator(C3OSM_ImportActor.bl_idname, text="Cossacks 3 actor (.actor + texture)")


def register():
    bpy.utils.register_class(C3OSM_Export)
    bpy.utils.register_class(C3OSM_ExportSet)
    bpy.utils.register_class(C3OSM_Import)
    bpy.utils.register_class(C3OSM_ImportActor)
    bpy.types.TOPBAR_MT_file_export.append(menu_export)
    bpy.types.TOPBAR_MT_file_import.append(menu_import)


def unregister():
    bpy.types.TOPBAR_MT_file_export.remove(menu_export)
    bpy.types.TOPBAR_MT_file_import.remove(menu_import)
    bpy.utils.unregister_class(C3OSM_ImportActor)
    bpy.utils.unregister_class(C3OSM_Import)
    bpy.utils.unregister_class(C3OSM_ExportSet)
    bpy.utils.unregister_class(C3OSM_Export)


if __name__ == "__main__":
    register()
