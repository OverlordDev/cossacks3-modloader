"""Чтение моделей Cossacks 3 (.osm, .oss, .aaf) — по спецификации MODEL_FORMATS.md.

Не конвертер: читает файлы игры и проверяет, что спецификация совпадает с ними байт в байт.

    python tools/formats/c3models.py "C:/Program Files (x86)/Steam/steamapps/common/Cossacks 3"
"""
import glob
import os
import re
import struct
import sys

OSM_HEADER = ("ident version skin_w skin_h frame_size n_skins n_verts n_uv n_tris n_glcmds n_frames "
              "ofs_skins ofs_uv ofs_tris ofs_frames ofs_glcmds ofs_end").split()


def read_osm(path):
    d = open(path, "rb").read()
    h = dict(zip(OSM_HEADER, struct.unpack_from("<4s16i", d, 0)))
    if h["ident"] != b"IDP2" or h["version"] != 8:
        raise ValueError("not IDP2 v8")
    m = {"header": h}
    m["skins"] = [d[h["ofs_skins"] + 64 * i: h["ofs_skins"] + 64 * i + 64].split(b"\0")[0] for i in range(h["n_skins"])]
    m["uv"] = [struct.unpack_from("<2f", d, h["ofs_uv"] + 8 * i) for i in range(h["n_uv"])]
    m["tris"] = [struct.unpack_from("<6I", d, h["ofs_tris"] + 24 * i) for i in range(h["n_tris"])]  # v0 v1 v2 t0 t1 t2
    frames = []
    for f in range(h["n_frames"]):
        o = h["ofs_frames"] + f * h["frame_size"]
        name = d[o:o + 16].split(b"\0")[0]
        verts = [struct.unpack_from("<3fI", d, o + 16 + 16 * i) for i in range(h["n_verts"])]
        frames.append((name, verts))
    m["frames"] = frames
    extra = len(d) - h["ofs_end"]
    m["colors"] = ([struct.unpack_from("<4f", d, h["ofs_end"] + 16 * i) for i in range(h["n_verts"])]
                   if extra == 16 * h["n_verts"] else None)
    m["unparsed"] = extra if m["colors"] is None else 0
    return m


def read_oss(path):
    d = open(path, "rb").read()
    n_frames, fps, n_bones, n_verts, n_tris, n_uv = struct.unpack_from("<6i", d, 0)
    o = 24
    pos = [struct.unpack_from("<3f", d, o + 12 * i) for i in range(n_verts)]; o += 12 * n_verts
    tris = [struct.unpack_from("<3I", d, o + 12 * i) for i in range(n_tris)]; o += 12 * n_tris
    uv = [struct.unpack_from("<2f", d, o + 8 * i) for i in range(n_uv)]; o += 8 * n_uv
    tri_uv = [struct.unpack_from("<3I", d, o + 12 * i) for i in range(n_tris)]; o += 12 * n_tris
    weights = []
    for _ in range(n_verts):
        n = struct.unpack_from("<i", d, o)[0]; o += 4
        weights.append([struct.unpack_from("<if", d, o + 8 * k) for k in range(n)]); o += 8 * n
    frames = [[struct.unpack_from("<7f", d, o + 28 * (f * n_bones + b)) for b in range(n_bones)] for f in range(n_frames)]
    o += 28 * n_frames * n_bones
    return {"n_frames": n_frames, "fps": fps, "n_bones": n_bones, "pos": pos, "tris": tris, "uv": uv,
            "tri_uv": tri_uv, "weights": weights, "frames": frames, "unparsed": len(d) - o}


def read_aaf(path):
    lines = open(path, encoding="latin-1").read().split("\n")
    if lines[0].strip() != "AAF":
        raise ValueError("not AAF")
    count = int(lines[1])
    out = []
    for line in lines[2:2 + count]:
        m = re.match(r'\s*"([^"]*)",\s*(\d+),\s*(\d+),\s*(\w+)', line)
        out.append((m.group(1), int(m.group(2)), int(m.group(3)), m.group(4)))
    return out


def validate(game):
    data = os.path.join(game, "data")
    ok = bad = 0
    for f in glob.glob(os.path.join(data, "**", "*.osm"), recursive=True):
        m = read_osm(f)
        h = m["header"]
        good = (m["unparsed"] == 0 and all(max(t[:3]) < h["n_verts"] and max(t[3:]) < h["n_uv"] for t in m["tris"]))
        ok, bad = (ok + 1, bad) if good else (ok, bad + 1)
    print(f".osm: {ok} ok, {bad} bad")
    ok = bad = 0
    for f in glob.glob(os.path.join(data, "**", "*.oss"), recursive=True):
        m = read_oss(f)
        good = (m["unparsed"] == 0 and all(abs(sum(w for _, w in ws) - 1) < 1e-3 and all(0 <= b < m["n_bones"] for b, _ in ws)
                                             for ws in m["weights"]))
        ok, bad = (ok + 1, bad) if good else (ok, bad + 1)
    print(f".oss: {ok} ok, {bad} bad")
    ok = bad = 0
    for f in glob.glob(os.path.join(data, "**", "*.aaf"), recursive=True):
        try:
            read_aaf(f); ok += 1
        except Exception:
            bad += 1
    print(f".aaf: {ok} ok, {bad} bad")


if __name__ == "__main__":
    validate(sys.argv[1] if len(sys.argv) > 1 else ".")
