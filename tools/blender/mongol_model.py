"""Монгольский конный лучник для Cossacks 3 — модель, скелет, текстура и экспорт в .oss/.aaf.

Запуск (нужен Blender 3.x–5.x или `pip install bpy`):

    blender -b -P tools/blender/mongol_model.py -- <папка вывода>
    python  tools/blender/mongol_model.py <папка вывода>

Что получится в папке вывода:
    mongol.blend  — сцена: меш + арматура (13 костей, одна кость на вершину) + материал с текстурой
    mongol.png    — текстура 512x512, альфа = маска цвета игрока (см. MODEL_FORMATS.md §6)
    mongol.oss    — меш со скелетной анимацией в формате игры (§2)
    mongol.aaf    — имена анимаций -> диапазоны кадров (§4)
    preview.png   — рендер для проверки

Модель по правилам MODEL_FORMATS.md §8: Z вверх, лицом к -Y, рост ≈ 2, ступни на Z = 0,
UV: v = 0 внизу, скелет <= 42 костей, вес 1.0 на кость, кадры — матрицы скиннинга.
"""
import math
import os
import struct
import sys

import bpy
import bmesh
import numpy as np
from mathutils import Euler, Matrix, Vector

OUT = os.path.abspath((sys.argv[sys.argv.index("--") + 1:] or [None])[0] if "--" in sys.argv
                      else (sys.argv[1] if len(sys.argv) > 1 else "mongol_out"))
os.makedirs(OUT, exist_ok=True)

# ---------------------------------------------------------------- скелет
# имя: (родитель, шарнир, конец кости). Шарнир — точка вращения в позе привязки (пространство модели).
LEG_X, ARM_X = 0.11, 0.32
BONES = {
    "root":       (None,        (0, 0, 0.0),           (0, 0, 0.25)),
    "pelvis":     ("root",      (0, 0, 0.95),          (0, 0, 1.10)),
    "spine":      ("pelvis",    (0, 0, 1.10),          (0, 0, 1.50)),
    "head":       ("spine",     (0, 0, 1.55),          (0, 0, 2.05)),
    "upperarm.L": ("spine",     (ARM_X, 0, 1.47),      (0.38, -0.10, 1.22)),
    "forearm.L":  ("upperarm.L", (0.38, -0.10, 1.22),  (0.30, -0.50, 1.32)),
    "upperarm.R": ("spine",     (-ARM_X, 0, 1.47),     (-0.38, 0.0, 1.22)),
    "forearm.R":  ("upperarm.R", (-0.38, 0.0, 1.22),   (-0.36, -0.10, 0.98)),
    "thigh.L":    ("pelvis",    (LEG_X, 0, 0.98),      (0.12, -0.02, 0.52)),
    "shin.L":     ("thigh.L",   (0.12, -0.02, 0.52),   (0.12, 0, 0.10)),
    "thigh.R":    ("pelvis",    (-LEG_X, 0, 0.98),     (-0.12, -0.02, 0.52)),
    "shin.R":     ("thigh.R",   (-0.12, -0.02, 0.52),  (-0.12, 0, 0.10)),
}
BONE_NAMES = list(BONES)

# ---------------------------------------------------------------- текстурный атлас 4x4 клеток по 128 px
CELLS = {
    # имя: (индекс, RGB, альфа-маска цвета игрока)
    "skin":    (0, (214, 160, 120), 0),
    "deel":    (1, (150, 150, 160), 255),    # халат/шапка: окрашивается цветом игрока
    "fur":     (2, (92, 66, 46), 0),
    "leather": (3, (66, 44, 30), 0),
    "hair":    (4, (24, 20, 18), 0),
    "wood":    (5, (140, 96, 52), 0),
    "armor":   (6, (118, 118, 126), 0),
    "sash":    (7, (160, 34, 30), 0),
    "cream":   (8, (226, 214, 188), 0),
    "gold":    (9, (208, 166, 52), 0),
}
TEX = 512
CELL_PX = TEX // 4


# ---------------------------------------------------------------- построение меша
bm = bmesh.new()
L_BONE = bm.verts.layers.int.new("bone")
L_CELL = bm.faces.layers.int.new("cell")


def _finish(verts, bone, cell):
    bi = BONE_NAMES.index(bone)
    fs = set()
    for v in verts:
        v[L_BONE] = bi
        fs.update(v.link_faces)
    for f in fs:
        f[L_CELL] = CELLS[cell][0]


def sphere(bone, cell, c, rx, ry, rz, seg=8, rings=6):
    r = bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=rings, radius=1.0)
    for v in r["verts"]:
        v.co = Vector((c[0] + v.co.x * rx, c[1] + v.co.y * ry, c[2] + v.co.z * rz))
    _finish(r["verts"], bone, cell)


def box(bone, cell, c, size, rot=None):
    r = bmesh.ops.create_cube(bm, size=1.0)
    m = (rot or Euler((0, 0, 0))).to_matrix()
    for v in r["verts"]:
        p = m @ Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]))
        v.co = p + Vector(c)
    _finish(r["verts"], bone, cell)


def tube(bone, cell, p0, p1, r0, r1, seg=8, ea=1.0, eb=1.0, cap0=True, cap1=True):
    """Усечённый конус между p0 и p1; ea/eb — растяжение сечения по осям a (≈X) и b."""
    p0, p1 = Vector(p0), Vector(p1)
    d = (p1 - p0).normalized()
    ref = Vector((1, 0, 0)) if abs(d.x) < 0.9 else Vector((0, 1, 0))
    a = (ref - d * ref.dot(d)).normalized()
    b = d.cross(a)
    rings = []
    for p, r in ((p0, r0), (p1, r1)):
        rings.append([bm.verts.new(p + a * (math.cos(2 * math.pi * i / seg) * r * ea)
                                   + b * (math.sin(2 * math.pi * i / seg) * r * eb)) for i in range(seg)])
    for i in range(seg):
        j = (i + 1) % seg
        bm.faces.new((rings[0][i], rings[0][j], rings[1][j], rings[1][i]))
    if cap0:
        bm.faces.new(rings[0][::-1])
    if cap1:
        bm.faces.new(rings[1])
    verts = rings[0] + rings[1]
    _finish(verts, bone, cell)
    bmesh.ops.recalc_face_normals(bm, faces=list({f for v in verts for f in v.link_faces}))


def chain(bone, cell, pts, r, seg=5):
    for p, q in zip(pts, pts[1:]):
        tube(bone, cell, p, q, r, r, seg)


def build_mesh():
    # --- ноги: сапоги с загнутым носком
    for s, sg in (("L", 1), ("R", -1)):
        x = LEG_X * sg
        tube(f"thigh.{s}", "deel", (x, 0, 0.98), (x * 1.1, -0.02, 0.52), 0.115, 0.085, 8)
        tube(f"shin.{s}", "leather", (x * 1.1, -0.02, 0.56), (x * 1.1, 0.0, 0.16), 0.095, 0.075, 8)
        tube(f"shin.{s}", "fur", (x * 1.1, -0.02, 0.58), (x * 1.1, -0.02, 0.52), 0.105, 0.105, 8)   # отворот сапога
        box(f"shin.{s}", "leather", (x * 1.1, -0.08, 0.05), (0.14, 0.26, 0.10))
        sphere(f"shin.{s}", "leather", (x * 1.1, -0.20, 0.09), 0.07, 0.11, 0.07, 6, 4)             # носок
        sphere(f"shin.{s}", "leather", (x * 1.1, -0.27, 0.13), 0.05, 0.06, 0.05, 6, 4)             # загнут вверх

    # --- таз, юбка халата (дэли), пояс
    tube("pelvis", "deel", (0, 0, 0.96), (0, 0, 0.48), 0.20, 0.28, 12, 1.05, 0.85, cap0=False)
    tube("pelvis", "sash", (0, 0, 0.93), (0, 0, 1.04), 0.215, 0.215, 12, 1.05, 0.85)
    box("pelvis", "gold", (0, -0.19, 0.985), (0.09, 0.03, 0.09))                                  # пряжка

    # --- торс
    tube("spine", "deel", (0, 0, 1.03), (0, 0, 1.52), 0.205, 0.235, 12, 1.05, 0.78)
    tube("spine", "armor", (0, 0, 1.08), (0, 0, 1.46), 0.215, 0.245, 12, 1.05, 0.80, cap0=False, cap1=False)  # ламелляр
    tube("spine", "fur", (0, 0, 1.50), (0, 0, 1.56), 0.115, 0.10, 8)                              # шея-воротник

    # --- колчан и стрелы на спине
    tube("spine", "leather", (-0.06, 0.20, 1.05), (-0.14, 0.24, 1.62), 0.075, 0.08, 8)
    for k, (dx, dz) in enumerate(((-0.02, 0), (-0.10, 0.02), (-0.17, 0.0))):
        tube("spine", "cream", (-0.09 + dx * 0.4, 0.23, 1.62 + dz), (-0.15 + dx * 0.4, 0.25, 1.80 + dz), 0.012, 0.012, 4)
        sphere("spine", "sash", (-0.15 + dx * 0.4, 0.25, 1.82 + dz), 0.025, 0.025, 0.05, 5, 3)

    # --- голова: лицо, скулы, нос, усы, косы
    sphere("head", "skin", (0, 0, 1.735), 0.105, 0.115, 0.125, 10, 8)
    sphere("head", "skin", (0, -0.115, 1.72), 0.022, 0.03, 0.03, 5, 4)                             # нос
    box("head", "hair", (-0.04, -0.105, 1.675), (0.075, 0.03, 0.014), Euler((0, 0, 0.35)))         # усы
    box("head", "hair", (0.04, -0.105, 1.675), (0.075, 0.03, 0.014), Euler((0, 0, -0.35)))
    box("head", "hair", (0, -0.11, 1.585), (0.04, 0.03, 0.09))                                     # бородка
    for sg in (1, -1):
        box("head", "hair", (0.055 * sg, -0.098, 1.765), (0.05, 0.02, 0.014))                      # брови
        chain("head", "hair", [(0.11 * sg, 0.03, 1.69), (0.125 * sg, 0.055, 1.55), (0.12 * sg, 0.06, 1.42)], 0.018)
    # --- шапка: меховой околыш, суконный конус (цвет игрока), кисточка
    tube("head", "fur", (0, 0, 1.80), (0, 0, 1.90), 0.135, 0.15, 12, 1.0, 1.05)
    tube("head", "deel", (0, 0, 1.90), (0, 0, 2.04), 0.13, 0.03, 12, 1.0, 1.05, cap0=False)
    sphere("head", "gold", (0, 0, 2.06), 0.03, 0.03, 0.035, 6, 4)
    for sg in (1, -1):
        box("head", "fur", (0.13 * sg, 0.02, 1.76), (0.05, 0.12, 0.12))                            # наушники

    # --- руки: рукава дэли, кисти
    for s, sg in (("L", 1), ("R", -1)):
        ua, fa = BONES[f"upperarm.{s}"], BONES[f"forearm.{s}"]
        sphere(f"upperarm.{s}", "deel", ua[1], 0.105, 0.10, 0.105, 8, 5)                           # плечо
        tube(f"upperarm.{s}", "deel", ua[1], ua[2], 0.085, 0.07, 8)
        tube(f"forearm.{s}", "deel", fa[1], fa[2], 0.07, 0.055, 8, cap0=False)
        sphere(f"forearm.{s}", "skin", fa[2], 0.05, 0.05, 0.05, 6, 4)

    # --- составной лук в левой руке (кость forearm.L), тетива
    hand = Vector(BONES["forearm.L"][2])
    pts = []
    for i in range(9):
        t = (i - 4) / 4.0                           # -1..1 вдоль лука
        z = hand.z + t * 0.50
        y = hand.y + 0.16 * t * t - (0.10 * max(0.0, abs(t) - 0.7) / 0.3) ** 2 * 1.2   # изгиб + загнутые концы
        pts.append((hand.x, y - 0.0, z))
    chain("forearm.L", "wood", pts, 0.02, 5)
    tube("forearm.L", "cream", pts[0], pts[-1], 0.005, 0.005, 3)                                    # тетива


build_mesh()
bm.verts.ensure_lookup_table()
bm.faces.ensure_lookup_table()

# --- UV: проекция по доминирующей оси грани в клетку атласа (v = 0 внизу)
uv = bm.loops.layers.uv.new("UVMap")
PAD = 0.012
for f in bm.faces:
    cell = f[L_CELL]
    n = f.normal
    ax = max(range(3), key=lambda i: abs(n[i]))
    ia, ib = [i for i in range(3) if i != ax]
    pts = [(l.vert.co[ia], l.vert.co[ib]) for l in f.loops]
    lo = [min(p[k] for p in pts) for k in (0, 1)]
    span = [max(max(p[k] for p in pts) - lo[k], 1e-6) for k in (0, 1)]
    u0, v0 = (cell % 4) / 4 + PAD, (cell // 4) / 4 + PAD
    size = 0.25 - 2 * PAD
    for l, p in zip(f.loops, pts):
        l[uv].uv = (u0 + (p[0] - lo[0]) / span[0] * size, v0 + (p[1] - lo[1]) / span[1] * size)

vert_bone = [v[L_BONE] for v in bm.verts]
mesh = bpy.data.meshes.new("MongolMesh")
bm.to_mesh(mesh)
bm.free()
for p in mesh.polygons:
    p.use_smooth = False

# ---------------------------------------------------------------- текстура
rng = np.random.default_rng(3)
tex = np.zeros((TEX, TEX, 4), np.float32)
for name, (idx, rgb, alpha) in CELLS.items():
    x0, y0 = (idx % 4) * CELL_PX, (idx // 4) * CELL_PX
    yy, xx = np.mgrid[0:CELL_PX, 0:CELL_PX]
    base = np.array(rgb, np.float32) / 255.0
    noise = rng.normal(0, 0.035, (CELL_PX, CELL_PX, 1)).astype(np.float32)
    img = np.clip(base + noise, 0, 1)
    if name == "armor":                                   # ламелляр: ряды пластин
        img *= (0.78 + 0.22 * ((xx // 8 + yy // 12) % 2))[..., None]
        img *= (1 - 0.35 * ((yy % 12) == 0))[..., None]
    elif name == "deel":                                  # ткань с ромбовидным узором; альфа-маска не трогает узор
        img *= (0.9 + 0.1 * (((xx + yy) // 10 + (xx - yy) // 10) % 2))[..., None]
    elif name == "fur":
        img *= (0.75 + 0.25 * rng.random((CELL_PX, CELL_PX, 1))).astype(np.float32)
    elif name == "wood":
        img *= (0.85 + 0.15 * np.sin(yy / 3.0))[..., None]
    tex[y0:y0 + CELL_PX, x0:x0 + CELL_PX, :3] = img
    tex[y0:y0 + CELL_PX, x0:x0 + CELL_PX, 3] = alpha / 255.0
image = bpy.data.images.new("mongol", TEX, TEX, alpha=True)
image.pixels = tex.ravel()          # строки снизу вверх — как v = 0 внизу
image.alpha_mode = "CHANNEL_PACKED"   # цвет не умножается на альфу-маску
image.filepath_raw = os.path.join(OUT, "mongol.png")
image.file_format = "PNG"
image.save()

# ---------------------------------------------------------------- объект, материал, арматура
scene = bpy.context.scene
for o in list(scene.objects):
    bpy.data.objects.remove(o, do_unlink=True)
obj = bpy.data.objects.new("Mongol", mesh)
scene.collection.objects.link(obj)

mat = bpy.data.materials.new("mongol")
mat.use_nodes = True
nt = mat.node_tree
bsdf = nt.nodes["Principled BSDF"]
tn = nt.nodes.new("ShaderNodeTexImage")
tn.image = image
tn.interpolation = "Closest"
nt.links.new(tn.outputs["Color"], bsdf.inputs["Base Color"])
bsdf.inputs["Roughness"].default_value = 0.85
mesh.materials.append(mat)

arm_data = bpy.data.armatures.new("MongolRig")
arm = bpy.data.objects.new("MongolRig", arm_data)
scene.collection.objects.link(arm)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="EDIT")
eb = {}
for name, (parent, head, tail) in BONES.items():
    e = arm_data.edit_bones.new(name)
    e.head, e.tail = Vector(head), Vector(tail)
    if (e.tail - e.head).length < 0.05:
        e.tail = e.head + Vector((0, 0, 0.1))
    eb[name] = e
    if parent:
        e.parent = eb[parent]
bpy.ops.object.mode_set(mode="OBJECT")
for name in BONE_NAMES:
    obj.vertex_groups.new(name=name)
for vi, bi in enumerate(vert_bone):
    obj.vertex_groups[bi].add([vi], 1.0, "REPLACE")
obj.parent = arm
mod = obj.modifiers.new("Armature", "ARMATURE")
mod.object = arm

# ---------------------------------------------------------------- анимации (процедурно, в терминах матриц скиннинга)
def smooth(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


def pose_walk(f, n=24):
    p = 2 * math.pi * f / n
    return {
        "thigh.L": (-0.55 * math.sin(p), 0, 0), "thigh.R": (0.55 * math.sin(p), 0, 0),
        "shin.L": (0.85 * max(0, math.cos(p)), 0, 0), "shin.R": (0.85 * max(0, -math.cos(p)), 0, 0),
        "upperarm.R": (-0.45 * math.sin(p), 0, 0), "forearm.R": (-0.25 - 0.2 * math.sin(p), 0, 0),
        "upperarm.L": (0.05 * math.sin(p), 0, 0),
        "spine": (0, 0, 0.08 * math.sin(p)), "head": (0, 0, -0.06 * math.sin(p)),
        "pelvis": (0, 0, -0.06 * math.sin(p)),
    }, {"pelvis": (0, 0, 0.03 * math.cos(2 * p))}


def pose_idle(f, n=48):
    p = 2 * math.pi * f / n
    return {
        "spine": (0.02 * math.sin(p), 0, 0), "head": (0.02 * math.sin(p + 0.5), 0, 0.07 * math.sin(p)),
        "upperarm.R": (0.04 * math.sin(p), 0, 0), "upperarm.L": (0.02 * math.sin(p), 0, 0),
    }, {"pelvis": (0, 0, 0.006 * math.sin(2 * p))}


def pose_attack(f, n=28):
    t = f / (n - 1)
    draw = smooth(t / 0.4) * (1 - smooth((t - 0.6) / 0.15))          # натянуть -> удержать -> отпустить
    return {
        "upperarm.R": (-1.35 * draw, 0, -0.45 * draw), "forearm.R": (-0.9 * draw, 0, 0),
        "spine": (0, 0, 0.18 * draw), "head": (0, 0, -0.2 * draw),
    }, {}


def pose_death(f, n=30):
    t = smooth(f / (n - 1))
    return {
        "root": (-math.pi / 2 * t, 0, 0),
        "thigh.L": (-0.5 * t, 0, 0), "thigh.R": (-0.3 * t, 0, 0), "shin.L": (0.9 * t, 0, 0), "shin.R": (0.6 * t, 0, 0),
        "upperarm.L": (0.5 * t, 0, 0.6 * t), "upperarm.R": (0.4 * t, 0, -0.5 * t), "head": (0.2 * t, 0, 0.3 * t),
    }, {"root": (0, 0, 0.22 * t)}


ANIMS = [("walk", 24, pose_walk), ("idle", 48, pose_idle), ("attack0", 28, pose_attack), ("death", 30, pose_death)]


def skin_matrices(rot, trans):
    """Матрица скиннинга каждой кости: M_parent · T(t) · T(p)·R·T(-p) (поза привязки — единичная)."""
    out = {}
    for name in BONE_NAMES:
        parent, piv, _ = BONES[name]
        piv = Vector(piv)
        r = Euler(rot.get(name, (0, 0, 0)), "XYZ").to_matrix().to_4x4()
        m = Matrix.Translation(Vector(trans.get(name, (0, 0, 0)))) @ Matrix.Translation(piv) @ r @ Matrix.Translation(-piv)
        out[name] = (out[parent] @ m) if parent else m
    return out


# ---------------------------------------------------------------- экспорт .oss / .aaf
def export_oss(path_oss, path_aaf):
    me = obj.data
    me.calc_loop_triangles()
    pos = [tuple(v.co) for v in me.vertices]
    uvl = me.uv_layers["UVMap"].data
    uv_list, uv_idx = [], {}
    tris, tri_uv = [], []
    for lt in me.loop_triangles:
        tris.append(tuple(lt.vertices))
        ids = []
        for li in lt.loops:
            key = (round(uvl[li].uv[0], 6), round(uvl[li].uv[1], 6))
            if key not in uv_idx:
                uv_idx[key] = len(uv_list)
                uv_list.append(key)
            ids.append(uv_idx[key])
        tri_uv.append(tuple(ids))
    frames, ranges = [], []
    for name, n, fn in ANIMS:
        start = len(frames)
        for f in range(n):
            sm = skin_matrices(*fn(f, n))
            row = []
            for bn in BONE_NAMES:
                m = sm[bn]
                q = m.to_quaternion()                       # (w, x, y, z)
                t = m.translation
                row.append((t.x, t.y, t.z, q.x, q.y, q.z, q.w))
            frames.append(row)
        ranges.append((name, start, len(frames) - 1))
    nb = len(BONE_NAMES)
    with open(path_oss, "wb") as fh:
        fh.write(struct.pack("<6i", len(frames), 30, nb, len(pos), len(tris), len(uv_list)))
        for p in pos:
            fh.write(struct.pack("<3f", *p))
        for t in tris:
            fh.write(struct.pack("<3I", *t))
        for u in uv_list:
            fh.write(struct.pack("<2f", *u))
        for t in tri_uv:
            fh.write(struct.pack("<3I", *t))
        for bi in vert_bone:
            fh.write(struct.pack("<iif", 1, bi, 1.0))
        for row in frames:
            for rec in row:
                fh.write(struct.pack("<7f", *rec))
    with open(path_aaf, "w", newline="\n") as fh:
        fh.write("AAF\n%d\n" % len(ranges))
        for name, a, b in ranges:
            fh.write('"%s",%d,%d,morph\n' % (name, a, b))
    return len(pos), len(tris), len(frames)


nv, nt_, nf = export_oss(os.path.join(OUT, "mongol.oss"), os.path.join(OUT, "mongol.aaf"))
print("mongol.oss: %d вершин, %d треугольников, %d костей, %d кадров" % (nv, nt_, len(BONE_NAMES), nf))

# ---------------------------------------------------------------- сцена и рендер
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "mongol.blend"))

if os.environ.get("MONGOL_NO_RENDER") != "1":
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.62, 0.7, 1)
    scene.world = world
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 3.5
    sun.rotation_euler = (math.radians(50), 0, math.radians(-35))
    scene.collection.objects.link(sun)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    scene.collection.objects.link(cam)
    scene.camera = cam
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 24
    scene.cycles.device = "CPU"
    scene.render.resolution_x, scene.render.resolution_y = 480, 640
    for name, loc in (("front", (0.0, -4.6, 1.15)), ("side", (4.6, 0.0, 1.15)), ("back", (2.6, 3.6, 1.4))):
        cam.location = Vector(loc)
        direction = Vector((0, 0, 1.0)) - cam.location
        cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(OUT, "preview_%s.png" % name)
        bpy.ops.render.render(write_still=True)
