# Default settler outfit: shirt, work pants, boots for the bare Appearance-Proof body
# (models/Appearance-Proof.glb). Original, mid-stylized, mid-to-high poly, PBR (tools/outfit_pbr).
# Pipeline as build_gear_e0.py (Blender 4.2, metres, transforms applied, n-gons triangulated):
#   * each garment's main surface is an OFFSET SHELL of the ProofBody region it covers: the body
#     vertices are copied (so every garment vertex keeps the exact skin weights of the body vertex
#     under it), cut at clean hem planes, smoothed (fabric drape, no anatomy) and pushed out to a
#     per-region minimum clearance from the rest-pose skin;
#   * hems/collar/cuffs/waistband/boot collar are swept bands; pockets, placket, belt, loops,
#     knee panels, sole, toe cap, heel counter, eyelets and laces are separate parts that take
#     weights transferred from ProofBody;
#   * a body mask (ProofBody UV, alpha 0 where a garment covers the skin, 2 vertex rings inside
#     each hem) is written for every on/off combination so the skin never pokes through;
#   * LOD1 (collapse 40%) per garment for the Psy mannequin; textures stay EXTERNAL (GLTF_SEPARATE).
#   python3 tools/outfit_pbr/make_textures.py
#   blender -b --factory-startup -P tools/blender_midstyle/build_outfit.py
import bpy, bmesh, math, os, json, sys, importlib.util
from mathutils import Vector, Matrix, geometry
from mathutils.bvhtree import BVHTree

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("e0", os.path.join(HERE, "build_gear_e0.py"))
E = importlib.util.module_from_spec(spec); spec.loader.exec_module(E)
ROOT = E.ROOT
E.OUT = os.path.join(ROOT, "raid", "assets", "outfit")
E.TEX = os.path.join(E.OUT, "textures")
E.TMP = os.environ.get("OUTFIT_TMP", "/tmp/outfit_export")
E.TILE = {"outfit_knit": 0.22, "outfit_rib": 0.10, "outfit_twill": 0.45, "outfit_leather": 0.30,
          "outfit_belt": 0.20, "outfit_rubber": 0.20, "outfit_cord": 0.04, "outfit_brass": 0.05}
sel, tris, mesh_obj, sweep, rrect, Surf = E.sel, E.tris, E.mesh_obj, E.sweep, E.rrect, E.Surf
ARMS = ("lowerarm", "hand", "thumb", "index", "middle", "ring", "pinky")
LEGS = ("thigh", "calf", "foot", "ball")
HEM_Z = 0.886; WAIST_Z = 0.915; PANT_Z = 0.130; BOOT_Z = 0.205; SLEEVE_T = 0.56

def mat(name): return E.pbr(name, name)

# ------------------------------------------------------------------ body data
def body_data():
    body = bpy.data.objects["ProofBody"]; rig = body.parent
    me = body.data
    gname = {g.index: g.name for g in body.vertex_groups}
    dom = []
    for v in me.vertices:
        best = max(v.groups, key=lambda g: g.weight) if v.groups else None
        dom.append(gname[best.group] if best else "")
    bones = {b.name: (rig.matrix_world @ b.head_local, rig.matrix_world @ b.tail_local) for b in rig.data.bones}
    return body, rig, dom, bones

def arm_plane(bones, side):
    h, t = bones["upperarm_" + side]; d = (t - h).normalized()
    return h + (t - h) * SLEEVE_T, d

COLLAR_C = Vector((0, 0, 1.302)); COLLAR_N = Vector((0, -0.38, 1)).normalized()

def region(name, p, dom, bones):
    is_arm = any(dom.startswith(a) for a in ARMS)
    if name == "shirt":
        if is_arm or any(dom.startswith(l) for l in LEGS) or dom == "head": return False
        if p.z < HEM_Z or (p - COLLAR_C).dot(COLLAR_N) > 0: return False
        if dom.startswith("upperarm"):
            P, d = arm_plane(bones, dom[-1])
            return (p - P).dot(d) < 0
        return True
    if name == "pants":
        if is_arm or dom.startswith("upperarm") or dom in ("head", "neck_01"): return False
        return PANT_Z < p.z < WAIST_Z
    if name == "boots":
        return p.z < BOOT_Z and any(dom.startswith(l) for l in ("calf", "foot", "ball"))
    return False

def planes_for(name, bones):
    if name == "shirt":
        out = [(Vector((0, 0, HEM_Z)), Vector((0, 0, -1))), (COLLAR_C, COLLAR_N)]
        for s in ("l", "r"): out.append(arm_plane(bones, s))
        return out
    if name == "pants": return [(Vector((0, 0, WAIST_Z)), Vector((0, 0, 1))), (Vector((0, 0, PANT_Z)), Vector((0, 0, -1)))]
    return [(Vector((0, 0, BOOT_Z)), Vector((0, 0, 1)))]

DRAPE_FLOOR = {"shirt": 0.0065, "pants": 0.0095}

def _lerp_z(z, pts):
    """Piecewise-linear profile over z: pts = [(z0, v0), (z1, v1), ...] with z descending."""
    if z >= pts[0][0]: return pts[0][1]
    for (za, va), (zb, vb) in zip(pts, pts[1:]):
        if z >= zb: return va + (vb - va) * (za - z) / (za - zb)
    return pts[-1][1]

# Cargo cut: extra ease over the skin-tight base (0.0105) by height. Seat/hips stay close so the
# waistband, belt and shirt tuck are unchanged; thighs and knees get real volume; the shin tapers
# and the hem stays tucked inside the boot shaft (0.0195) with a little bunching above it.
PANTS_EASE = [(0.84, 0.0), (0.74, 0.016), (0.62, 0.024), (0.44, 0.026), (0.32, 0.020), (0.27, 0.013), (0.235, 0.004), (0.0, 0.004)]

def pants_ease(p, nor):
    e = _lerp_z(p.z, PANTS_EASE)
    if nor is not None and p.z < 0.80:
        # Inner leg (normal facing the other leg) keeps the base clearance where the legs are close.
        inward = max(0.0, -math.copysign(1.0, p.x) * nor.x)
        w = _lerp_z(p.z, [(0.62, 1.0), (0.44, 0.5), (0.0, 0.3)])
        e *= 1.0 - inward * w
    return e

def offset_for(name, p, nor=None):
    if name == "shirt":
        if p.z < 0.905: return 0.004
        if p.z < 0.935: return 0.004 + (p.z - 0.905) / 0.03 * 0.013
        if p.z < 0.985: return 0.017
        return 0.0125 if abs(p.x) < 0.17 else 0.015
    if name == "pants":
        # Front rise: the canvas bridges the crotch instead of following it.
        if abs(p.x) < 0.08 and 0.72 < p.z < 0.88 and p.y < 0.0:
            return 0.0105 + 0.012 * (1 - abs(p.x) / 0.08) * min(1.0, (p.z - 0.72) / 0.05, (0.88 - p.z) / 0.05)
        return 0.0105 + pants_ease(p, nor)
    if name == "boots":
        return 0.0195 if p.z > 0.115 else 0.011
    return 0.01

def pants_folds(bm, body_surf):
    """Outward-only fabric folds on the loose legs: diagonal drape folds on the thighs, horizontal
    bunching at the back/front of the knee and stacked folds above the boot. Never reduces clearance."""
    for v in bm.verts:
        if v.is_boundary: continue
        p = v.co
        if p.z > 0.78 or p.z < 0.22: continue
        loc, nor = body_surf.nearest(p)
        if loc is None: continue
        sx = math.copysign(1.0, p.x)
        ang = math.atan2(p.y + 0.01, (p.x - sx * 0.095) * sx)      # around the leg
        d = 0.0
        if 0.50 < p.z < 0.78:   # thigh: long diagonal folds, strongest at the front/outer side
            env = min(1.0, (p.z - 0.50) / 0.06, (0.78 - p.z) / 0.08)
            d += 0.0036 * env * (0.5 + 0.5 * math.sin(5.0 * ang + p.z * 38.0))
        if 0.34 < p.z < 0.52:   # knee: horizontal bunching, front and back
            env = min(1.0, (p.z - 0.34) / 0.04, (0.52 - p.z) / 0.04) * (0.55 + 0.45 * abs(math.sin(ang)))
            d += 0.0042 * env * (0.5 + 0.5 * math.sin(p.z / 0.042 * 2 * math.pi + 1.3 * math.sin(2 * ang)))
        if 0.22 < p.z < 0.33:   # stacked folds above the boot
            env = min(1.0, (p.z - 0.235) / 0.02 if p.z > 0.235 else 0.0, (0.33 - p.z) / 0.04)
            d += 0.0046 * max(0.0, env) * (0.5 + 0.5 * math.sin(p.z / 0.024 * 2 * math.pi + 2.0 * math.sin(3 * ang)))
        if d > 0.0:
            n = (p - loc).normalized() if (p - loc).length > 1e-6 else nor
            v.co = p + n * d

# ------------------------------------------------------------------ shells
def shell(name, body, dom, bones, body_surf, smooth_iter, smooth_fac):
    o = body.copy(); o.data = body.data.copy(); o.name = name; o.data.name = name
    bpy.context.scene.collection.objects.link(o)
    if o.data.shape_keys: o.shape_key_clear()
    bm = bmesh.new(); bm.from_mesh(o.data); bm.verts.ensure_lookup_table()
    keep = [region(name, body.matrix_world @ v.co, dom[v.index], bones) for v in bm.verts]
    covered = [i for i, k in enumerate(keep) if k]
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not keep[v.index]], context="VERTS")
    # Drop slivers: faces with a vertex that has only boundary neighbours (keeps hems clean).
    for _ in range(2):
        lone = [v for v in bm.verts if len(v.link_faces) < 2]
        bmesh.ops.delete(bm, geom=lone, context="VERTS")
    # glTF import splits vertices along UV seams; weld them so the shell is one closed surface.
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-5)
    # One subdivision step: the garment carries its own folds and smoothing at roughly twice body density.
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=1, use_grid_fill=True, smooth=0.0)
    planes = planes_for(name, bones)
    def snap(v):
        best = min(planes, key=lambda pl: abs((v.co - pl[0]).dot(pl[1])))
        dd = (v.co - best[0]).dot(best[1])
        if abs(dd) < 0.03: v.co -= best[1] * dd
    bnd = lambda: [v for v in bm.verts if v.is_boundary]
    for v in bnd(): snap(v)
    def push(floor=None):
        for v in bm.verts:
            loc, nor = body_surf.nearest(v.co)
            if loc is None: continue
            want = offset_for(name, v.co, nor)
            if floor is not None: want = min(want, floor)
            s = (v.co - loc).dot(nor)
            if s < want: v.co += nor * (want - s)
    push()
    inner = [v for v in bm.verts if not v.is_boundary]
    for it in range(smooth_iter):
        bmesh.ops.smooth_vert(bm, verts=inner, factor=smooth_fac, use_axis_x=True, use_axis_y=True, use_axis_z=True)
        b = bnd()
        for v in b: snap(v)
        # Keep only a thin floor while smoothing so the cloth bridges hollows instead of hugging every muscle.
        push(DRAPE_FLOOR.get(name))
    if name == "pants":
        # Restore the full cargo ease that smoothing shrank, relax, then add fabric folds.
        for it in range(4):
            push()
            bmesh.ops.smooth_vert(bm, verts=inner, factor=0.4, use_axis_x=True, use_axis_y=True, use_axis_z=True)
            for v in bnd(): snap(v)
        push()
        pants_folds(bm, body_surf)
    if name == "boots":
        for v in bm.verts:
            if v.co.z < 0.018: v.co.z = 0.018   # foot bottom tucks into the sole slab
    bm.to_mesh(o.data); bm.free(); o.data.update()
    for md in list(o.modifiers):
        if md.type != "ARMATURE": o.modifiers.remove(md)
    E.set_mats(o, [mat({"shirt": "outfit_knit", "pants": "outfit_twill", "boots": "outfit_leather"}[name])])
    sel(o); bpy.ops.object.shade_smooth()
    E.uv_world(o)
    return o, covered

def boundary_loops(obj):
    bm = bmesh.new(); bm.from_mesh(obj.data)
    edges = [e for e in bm.edges if e.is_boundary]
    adj = {}
    for e in edges:
        a, b = e.verts; adj.setdefault(a.index, []).append(b.index); adj.setdefault(b.index, []).append(a.index)
    co = {v.index: obj.matrix_world @ v.co.copy() for v in bm.verts}
    seen = set(); loops = []
    for start in adj:
        if start in seen: continue
        loop = [start]; seen.add(start); prev = None; cur = start
        while True:
            nxt = [n for n in adj[cur] if n != prev and n not in seen]
            if not nxt: break
            prev, cur = cur, nxt[0]; loop.append(cur); seen.add(cur)
        if len(loop) > 8: loops.append([co[i] for i in loop])
    print("LOOPS", obj.name, len(edges), [len(l) for l in loops], [(round(min(p.z for p in l),3), round(max(p.z for p in l),3), round(min(p.x for p in l),3), round(max(p.x for p in l),3)) for l in loops], "deg>2:", sum(1 for k in adj if len(adj[k]) > 2))
    bm.free(); return loops

def smooth_path(pts, it=3, closed=True):
    for _ in range(it):
        n = len(pts); pts = [(pts[(i - 1) % n] + pts[i] * 2 + pts[(i + 1) % n]) / 4 if closed or 0 < i < n - 1 else pts[i] for i in range(n)]
    return pts

def resample(pts, step, closed=True):
    seg = pts + ([pts[0]] if closed else []); out = [seg[0]]; acc = 0.0
    for a, b in zip(seg, seg[1:]):
        L = (b - a).length; t = step - acc
        while t <= L:
            out.append(a.lerp(b, t / L)); t += step
        acc = (acc + L) % step
    return out[:-1] if closed and len(out) > 2 else out

def band(name, loop, surf, matname, thick, height, lift=0.0, closed=True, step=0.006):
    path = resample(smooth_path(loop, 4, closed), step, closed)
    normals = []; pts = []
    for p in path:
        loc, nor = surf.nearest(p)
        normals.append(nor); pts.append(p + nor * lift)
    prof = [(a - thick * 0.35, b) for (a, b) in rrect(thick, height, min(thick, height) * 0.45, 2)]
    o = sweep(name, pts, normals, prof, closed=closed, cap=not closed)
    E.finish(o, [mat(matname)], smooth_angle=60)
    return o

def patch(name, surf, center, right, up, w, h, off, matname, thick=0.0025, res=0.008, r=0.012):
    """Rounded rectangle patch projected onto a surface (nearest point + off), with thickness."""
    nx = max(3, int(w / res)); ny = max(3, int(h / res))
    right = right.normalized(); up = (up - right * up.dot(right)).normalized(); nrm = right.cross(up)
    verts = []; faces = []
    for j in range(ny + 1):
        for i in range(nx + 1):
            u = (i / nx - 0.5) * w; v = (j / ny - 0.5) * h
            # round the corners by pulling grid points inside the corner radius
            cu = max(abs(u) - (w / 2 - r), 0); cv = max(abs(v) - (h / 2 - r), 0)
            if cu > 0 and cv > 0:
                k = r / max(math.hypot(cu, cv), 1e-6)
                if k < 1: u = math.copysign(w / 2 - r + cu * k, u); v = math.copysign(h / 2 - r + cv * k, v)
            p = center + right * u + up * v
            loc, nor = surf.ray(p + nrm * 0.25, -nrm)
            if loc is None: loc, nor = surf.nearest(p)
            verts.append(loc + nor * off)
    for j in range(ny):
        for i in range(nx):
            a = j * (nx + 1) + i; faces.append((a, a + 1, a + nx + 2, a + nx + 1))
    o = mesh_obj(name, verts, faces)
    # Corner rounding stacks grid points; weld them and drop the degenerate faces before thickening.
    bm = bmesh.new(); bm.from_mesh(o.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=0.0004)
    bmesh.ops.dissolve_degenerate(bm, dist=0.0004, edges=bm.edges[:])
    bm.to_mesh(o.data); bm.free(); o.data.update()
    sel(o); bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.normals_make_consistent(inside=False); bpy.ops.object.mode_set(mode="OBJECT")
    # Face outward: compare with the surface normal at the centre.
    if o.data.polygons and o.data.polygons[len(o.data.polygons) // 2].normal.dot(nrm) < 0:
        sel(o); bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.select_all(action="SELECT"); bpy.ops.mesh.flip_normals(); bpy.ops.object.mode_set(mode="OBJECT")
    if thick > 0:
        s = o.modifiers.new("Solid", "SOLIDIFY"); s.thickness = thick; s.offset = 1.0; s.use_even_offset = False; s.use_quality_normals = True
    E.finish(o, [mat(matname)], smooth_angle=50)
    return o

def edge_loop_of(obj):
    loops = boundary_loops(obj); return max(loops, key=len) if loops else []

def tube(name, pts, radius, matname, closed=False, seg=6):
    prof = [(radius * math.cos(2 * math.pi * k / seg), radius * math.sin(2 * math.pi * k / seg)) for k in range(seg)]
    normals = []
    for i, p in enumerate(pts):
        t = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        n = t.cross(Vector((0, 0, 1)))
        if n.length < 1e-3: n = t.cross(Vector((1, 0, 0)))
        normals.append(n.normalized())
    o = sweep(name, pts, normals, prof, closed=closed, cap=not closed)
    E.finish(o, [mat(matname)], smooth_angle=70)
    return o

def on_surf(surf, pts, off):
    out = []
    for p in pts:
        loc, nor = surf.nearest(p); out.append(loc + nor * off)
    return out

def stitch_round(name, obj, surf, off=0.0016, r=0.0011):
    loop = edge_loop_of(obj)
    if not loop: return None
    path = on_surf(surf, resample(smooth_path(loop, 3), 0.004), off)
    return tube(name, path + [path[0]], r, "outfit_cord", closed=False, seg=5)

def cyl_on(name, surf, p, r, h, matname, verts=16, off=0.0):
    loc, nor = surf.nearest(p)
    o = E.cyl(r, h, (0, 0, 0), rot=(math.pi / 2, 0, 0), verts=verts, name=name)
    E.orient(o, loc + nor * (off + h * 0.5), nor)
    E.finish(o, [mat(matname)], bevel=min(r, h) * 0.3, segs=2, smooth_angle=40)
    return o

# ------------------------------------------------------------------ garments
def build_shirt(body, dom, bones, bsurf):
    sh, cov = shell("shirt", body, dom, bones, bsurf, 24, 0.5)
    ss = Surf(sh); parts = [sh]
    for i, loop in enumerate(boundary_loops(sh)):
        c = sum(loop, Vector()) / len(loop)
        if c.z > 1.2 and abs(c.x) < 0.1: parts.append(band("ShirtCollar", loop, ss, "outfit_rib", 0.006, 0.018, 0.0015))
        elif abs(c.x) > 0.15: parts.append(band("ShirtCuff", loop, ss, "outfit_rib", 0.005, 0.022, 0.001))
    # Henley placket + 3 buttons, chest pocket (left chest = +X... Blender +X is the rig's left).
    fwd = Vector((0, -1, 0)); up = Vector((0, 0, 1)); right = Vector((1, 0, 0))
    pk = patch("ShirtPlacket", ss, Vector((0, -0.12, 1.215)), right, up, 0.030, 0.13, 0.0008, "outfit_knit", thick=0.0018, r=0.006)
    parts += [pk, stitch_round("PlacketStitch", pk, Surf(pk))]
    ps = Surf(pk)
    for k, z in enumerate((1.255, 1.215, 1.175)):
        parts.append(cyl_on("ShirtButton", ps, Vector((0, -0.14, z)), 0.0055, 0.003, "outfit_brass", off=0.0004))
    pocket = patch("ShirtPocket", ss, Vector((0.075, -0.14, 1.165)), right, up, 0.085, 0.095, 0.0008, "outfit_knit", thick=0.002, r=0.01)
    parts += [pocket, stitch_round("PocketStitch", pocket, Surf(pocket))]
    flap = patch("ShirtPocketFlap", Surf(pocket), Vector((0.075, -0.15, 1.200)), right, up, 0.089, 0.03, 0.0012, "outfit_knit", thick=0.002, r=0.008)
    parts.append(flap)
    return [p for p in parts if p], cov

def build_pants(body, dom, bones, bsurf):
    pa, cov = shell("pants", body, dom, bones, bsurf, 18, 0.5)
    ps = Surf(pa); parts = [pa]
    loops = boundary_loops(pa)
    top = max(loops, key=lambda l: sum(p.z for p in l) / len(l))
    parts.append(band("Waistband", top, ps, "outfit_twill", 0.006, 0.034, 0.0012))
    belt_loop = [p - Vector((0, 0, 0.004)) for p in top]
    belt = band("Belt", belt_loop, ps, "outfit_belt", 0.0105, 0.024, 0.0042)
    parts.append(belt)
    bs = Surf(belt)
    # Buckle: frame + prong, front centre.
    loc, nor = bs.nearest(Vector((0, -0.2, WAIST_Z - 0.021)))
    frame = sweep("BuckleFrame", [Vector((-0.024, 0, -0.017)), Vector((0.024, 0, -0.017)), Vector((0.024, 0, 0.017)), Vector((-0.024, 0, 0.017))],
                  [Vector((0, -1, 0))] * 4, [(a, b) for (a, b) in rrect(0.004, 0.005, 0.0015, 2)], closed=True, cap=False)
    E.orient(frame, loc + nor * 0.0025, nor); E.finish(frame, [mat("outfit_brass")], smooth_angle=50); parts.append(frame)
    prong = E.box((0.04, 0.003, 0.003), (0, 0, 0), name="BuckleProng"); E.orient(prong, loc + nor * 0.004, nor)
    E.finish(prong, [mat("outfit_brass")], bevel=0.0008); parts.append(prong)
    # Belt loops round the waist.
    ws = Surf(parts[1])
    for ang in (-150, -100, -38, 38, 100, 150, 180):
        a = math.radians(ang); p = Vector((math.sin(a) * 0.25, -math.cos(a) * 0.25, WAIST_Z - 0.018))
        lp = patch("BeltLoop", bs, p, Vector((math.cos(a), math.sin(a), 0)), Vector((0, 0, 1)), 0.012, 0.042, 0.0012, "outfit_twill", thick=0.0022, r=0.003, res=0.004)
        parts.append(lp)
    # Fly placket with stitch, front pocket openings, back patch pockets, knee panels, cargo pockets.
    fly = patch("Fly", ps, Vector((0.012, -0.14, 0.835)), Vector((1, 0, 0)), Vector((0, 0, 1)), 0.032, 0.12, 0.0006, "outfit_twill", thick=0.0015, r=0.01)
    parts += [fly, stitch_round("FlyStitch", fly, Surf(fly))]
    for s in (1, -1):
        curve = [Vector((s * (0.07 + 0.06 * t), -0.16, WAIST_Z - 0.03 - 0.10 * t * t)) for t in [i / 10 for i in range(11)]]
        parts.append(tube("PocketEdge", on_surf(ps, curve, 0.0012), 0.0018, "outfit_twill"))
        bp = patch("BackPocket", ps, Vector((s * 0.075, 0.12, 0.80)), Vector((-1, 0, 0)), Vector((0, 0, 1)), 0.12, 0.13, 0.0008, "outfit_twill", thick=0.0022, r=0.012)
        parts += [bp, stitch_round("BackPocketStitch", bp, Surf(bp))]
        # Knee panel (front of the knee), cargo pocket + flap on the outer thigh.
        kh, kt = bones["calf_" + ("l" if s > 0 else "r")]
        kp = patch("KneePanel", ps, kh + Vector((0, -0.05, 0.0)), Vector((1, 0, 0)), Vector((0, 0, 1)), 0.10, 0.15, 0.0008, "outfit_twill", thick=0.0018, r=0.02)
        parts += [kp, stitch_round("KneeStitch", kp, Surf(kp))]
        th, tt = bones["thigh_" + ("l" if s > 0 else "r")]
        mid = th.lerp(tt, 0.55)
        cp = patch("CargoPocket", ps, mid + Vector((s * 0.07, -0.01, 0)), Vector((0, s, 0)), Vector((0, 0, 1)), 0.12, 0.15, 0.0012, "outfit_twill", thick=0.006, r=0.012)
        parts += [cp, stitch_round("CargoStitch", cp, Surf(cp))]
        flap = patch("CargoFlap", Surf(cp), mid + Vector((s * 0.07, -0.01, 0.063)), Vector((0, s, 0)), Vector((0, 0, 1)), 0.125, 0.045, 0.0012, "outfit_twill", thick=0.003, r=0.008)
        parts.append(flap)
        parts.append(cyl_on("CargoSnap", Surf(flap), mid + Vector((s * 0.12, -0.01, 0.055)), 0.006, 0.0035, "outfit_brass", off=0.0005))
    return [p for p in parts if p], cov

def build_boots(body, dom, bones, bsurf):
    bo, cov = shell("boots", body, dom, bones, bsurf, 26, 0.6)
    bsf = Surf(bo); parts = [bo]
    for loop in boundary_loops(bo):
        parts.append(band("BootCollar", loop, bsf, "outfit_leather", 0.011, 0.022, 0.002))
    for side, s in (("l", 1), ("r", -1)):
        fh, ft = bones["foot_" + side]; bh, bt = bones["ball_" + side]
        # Sole slab: rounded hull of the foot footprint, 2.6 cm tall (rubber), heel block.
        foot = [Vector((v.x, v.y)) for v in (bo.matrix_world @ w.co for w in bo.data.vertices) if v.z < 0.06 and v.x * s > 0]
        hull = [foot[i] for i in geometry.convex_hull_2d(foot)]
        cen = sum(hull, Vector((0, 0))) / len(hull)
        ring = [cen + (p - cen) * 1.0 + (p - cen).normalized() * 0.006 for p in hull]
        ring = [Vector((p.x, p.y, 0)) for p in resample([Vector((q.x, q.y, 0)) for q in ring], 0.008)]
        ring = smooth_path(ring, 3)
        vs = [Vector((p.x, p.y, -0.003)) for p in ring] + [Vector((p.x, p.y, 0.024)) for p in ring]
        n = len(ring)
        faces = [tuple(range(n))[::-1], tuple(range(n, 2 * n))] + [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
        sole = mesh_obj("Sole", vs, faces)
        sel(sole); bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.mesh.normals_make_consistent(inside=False); bpy.ops.object.mode_set(mode="OBJECT")
        E.finish(sole, [mat("outfit_rubber")], bevel=0.003, segs=2, smooth_angle=40)
        parts.append(sole)
        # Toe cap + heel counter overlays (darker oiled leather via the same set), stitched.
        toe_c = bh.lerp(bt, 0.55) + Vector((0, -0.01, 0.03))
        tc = patch("ToeCap", bsf, toe_c, Vector((-1, 0, 0)), Vector((0, -1, 0.25)), 0.10, 0.10, 0.0009, "outfit_leather", thick=0.002, r=0.03)
        heel = fh + Vector((0, 0.07, -0.02))
        hc = patch("HeelCounter", bsf, heel, Vector((-1, 0, 0)), Vector((0, 0, 1)), 0.10, 0.075, 0.0009, "outfit_leather", thick=0.002, r=0.02)
        parts += [tc, hc, stitch_round("ToeStitch", tc, Surf(tc)), stitch_round("HeelStitch", hc, Surf(hc))]
        # Tongue strip + 5 eyelet pairs + criss-cross laces + bow.
        a = Vector((fh.x + 0.002 * s, -0.055, 0.175)); b = Vector((bh.x, bh.y + 0.02, 0.075))
        d = (b - a); upv = d.normalized()
        tg = patch("Tongue", bsf, a.lerp(b, 0.45), Vector((-1, 0, 0)), upv, 0.040, d.length + 0.03, 0.0012, "outfit_leather", thick=0.003, r=0.012)
        parts.append(tg)
        eye = []
        for k in range(5):
            t = 0.04 + k * 0.15
            c = a.lerp(b, t)
            row = []
            for sgn in (-1, 1):
                p = c + Vector((sgn * 0.027, -0.06, 0.03))
                loc, nor = bsf.nearest(p)
                e = E.cyl(0.0042, 0.0028, (0, 0, 0), rot=(math.pi / 2, 0, 0), verts=14, name="Eyelet")
                E.orient(e, loc + nor * 0.0016, nor); E.finish(e, [mat("outfit_brass")], bevel=0.0007, segs=1)
                parts.append(e); row.append(loc + nor * 0.0045)
            eye.append(row)
        for k in range(4):
            for (i0, i1) in ((0, 1), (1, 0)):
                p0, p1 = eye[k][i0], eye[k + 1][i1]
                mid = (p0 + p1) / 2
                loc, nor = Surf(tg).nearest(mid)
                arc = [p0.lerp(p1, t) + nor * (0.004 * math.sin(math.pi * t) + 0.001) for t in [i / 8 for i in range(9)]]
                parts.append(tube("Lace", arc, 0.0016, "outfit_cord"))
        top = eye[0]; c0 = (top[0] + top[1]) / 2
        loc, nor = bsf.nearest(c0)
        for sgn in (-1, 1):
            loop = [c0 + nor * 0.006 + Vector((sgn * (0.012 + 0.01 * math.cos(t * 2 * math.pi)), -0.002, 0.01 * math.sin(t * 2 * math.pi))) for t in [i / 12 for i in range(13)]]
            parts.append(tube("LaceBow", loop, 0.0016, "outfit_cord"))
    return [p for p in parts if p], cov

# ------------------------------------------------------------------ body mask
def rings_inside(body, covered, rings=2):
    """Body verts covered by a garment and at least `rings` edges inside its hem."""
    me = body.data; cov = set(covered)
    # Weld UV-seam duplicates by position so seams do not read as hems.
    key = {}; canon = []
    for v in me.vertices:
        k = (round(v.co.x, 5), round(v.co.y, 5), round(v.co.z, 5)); canon.append(key.setdefault(k, v.index))
    nb = {i: set() for i in range(len(me.vertices))}
    for e in me.edges:
        a, b = canon[e.vertices[0]], canon[e.vertices[1]]; nb[a].add(b); nb[b].add(a)
    cov = {canon[i] for i in cov}
    inner = set(cov)
    for _ in range(rings):
        edge = {i for i in inner if any(n not in inner for n in nb[i])}
        inner -= edge
    return {i for i in range(len(me.vertices)) if canon[i] in inner}

def raster(me, uv, polys, size, tol=0.02):
    """Pixel indices covered by the UV triangles of `polys`."""
    out = set()
    for p in polys:
        pts = [uv[i].uv for i in p.loop_indices]
        for k in range(1, len(pts) - 1):
            tri = (pts[0], pts[k], pts[k + 1])
            (ax, ay), (bx, by), (cx, cy) = [(q.x * size, q.y * size) for q in tri]
            x0, x1 = max(int(min(ax, bx, cx)), 0), min(int(max(ax, bx, cx)) + 1, size - 1)
            y0, y1 = max(int(min(ay, by, cy)), 0), min(int(max(ay, by, cy)) + 1, size - 1)
            den = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
            if abs(den) < 1e-9: continue
            for y in range(y0, y1 + 1):
                for x in range(x0, x1 + 1):
                    X, Y = x + 0.5, y + 0.5
                    l1 = ((by - cy) * (X - cx) + (cx - bx) * (Y - cy)) / den
                    l2 = ((cy - ay) * (X - cx) + (ax - cx) * (Y - cy)) / den
                    if l1 >= -tol and l2 >= -tol and 1 - l1 - l2 >= -tol: out.add(y * size + x)
    return out

def write_masks(body, cover_sets, size=1024):
    me = body.data; uv = me.uv_layers.active.data
    names = list(cover_sets)
    import itertools
    out = {}
    for combo in itertools.product((0, 1), repeat=len(names)):
        raw = set()
        for k, on in zip(names, combo):
            if on: raw |= cover_sets[k]
        hide = rings_inside(body, raw) if raw else set()
        px = [1.0] * (size * size)
        hid = raster(me, uv, [p for p in me.polygons if all(v in hide for v in p.vertices)], size)
        keep = raster(me, uv, [p for p in me.polygons if not all(v in hide for v in p.vertices)], size, tol=0.0) if hid else set()
        # Grow the cut-out a few texels into empty atlas space (never into skin that stays
        # visible) so filtering / mips at UV-island borders cannot open seams of skin.
        front = set(hid)
        for _ in range(4):
            nxt = set()
            for i in front:
                x, y = i % size, i // size
                for j in ((i - 1) if x > 0 else -1, (i + 1) if x < size - 1 else -1, i - size, i + size):
                    if 0 <= j < size * size and j not in hid and j not in keep: nxt.add(j)
            hid |= nxt; front = nxt
        for i in hid - keep: px[i] = 0.0
        tag = "".join(str(c) for c in combo)
        img = bpy.data.images.new("body_mask_" + tag, size, size, alpha=True)
        flat = []
        for a in px: flat += (1.0, 1.0, 1.0, a)
        img.pixels = flat
        path = os.path.join(E.TEX, "body_mask_%s.png" % tag)
        img.filepath_raw = path; img.file_format = "PNG"; img.save()
        out[tag] = os.path.relpath(path, ROOT)
        print("MASK", tag, sum(1 for a in px if a == 0.0))
    return out, names

# ------------------------------------------------------------------ main
def clearance(obj, surf, max_d, min_z):
    """Min signed distance of garment verts from the rest-pose skin (negative = inside), above min_z."""
    worst = 1.0; inside = 0
    for v in obj.data.vertices:
        p = obj.matrix_world @ v.co
        if p.z < min_z: continue
        loc, nor = surf.nearest(p)
        if loc is None or (p - loc).length > max_d: continue
        sd = (p - loc).length * (1 if (p - loc).dot(nor) >= 0 else -1)
        worst = min(worst, sd); inside += sd < 0
    return round(worst, 4), inside

def finish_garment(name, parts, rig, body):
    keep_shell = parts[0]
    details = parts[1:]
    for d in parts:
        far = [d.matrix_world @ v.co for v in d.data.vertices if (lambda q: q[0] is None or (q[0] - (d.matrix_world @ v.co)).length > 0.07)(BSURF.nearest(d.matrix_world @ v.co))]
        if far: print("FAR", name, d.name, len(far), len(d.data.vertices), [tuple(round(c, 3) for c in f) for f in far[:3]])
    print("PARTS", name, sorted(((sum(len(pl.vertices) - 2 for pl in d.data.polygons), d.name) for d in parts), reverse=True)[:8])
    if details:
        det = E.join(details, name + "_detail")
        allowed = {g.name for g in body.vertex_groups}
        E.transfer_weights(det, body, allowed, smooth=1)
        E.bind(det, rig, None)
        for md in list(det.modifiers):
            if md.type == "ARMATURE" and md.object is None: det.modifiers.remove(md)
        sel(keep_shell)
        g = E.join([keep_shell, det], name)
    else:
        g = keep_shell; g.name = name
    E.merge_duplicate_slots(g)
    t = g.modifiers.new("Tri", "TRIANGULATE")
    sel(g); bpy.ops.object.modifier_apply(modifier="Tri")
    g.parent = rig
    if not any(m.type == "ARMATURE" for m in g.modifiers): E.bind(g, rig, None)
    for md in g.modifiers:
        if md.type == "ARMATURE": md.object = rig
    sel(g); bpy.ops.object.mode_set(mode="WEIGHT_PAINT")
    bpy.ops.object.vertex_group_limit_total(group_select_mode="ALL", limit=4)
    bpy.ops.object.vertex_group_normalize_all(group_select_mode="ALL", lock_active=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    return g

if __name__ == "__main__":
    E.reset()
    body, rig, dom, bones = body_data()
    bsurf = Surf(body); BSURF = bsurf
    report = {"tool": "tools/blender_midstyle/build_outfit.py (default outfit)"}
    built = {}; covers = {}
    for name, fn, mesh in (("shirt", build_shirt, "OutfitShirt"), ("pants", build_pants, "OutfitPants"), ("boots", build_boots, "OutfitBoots")):
        parts, cov = fn(body, dom, bones, bsurf)
        g = finish_garment(mesh, parts, rig, body)
        built[name] = g; covers[name] = set(cov)
        if name == "boots":   # the sole slab closes the boot: the whole foot below the shaft is covered
            covers[name] |= {v.index for v in body.data.vertices if (body.matrix_world @ v.co).z < BOOT_Z - 0.04}
        report[name] = {"mesh": mesh, "lod0_tris": tris(g), "materials": [m.name for m in g.data.materials],
                        "clearance_m": None}
        report[name]["clearance_m"], report[name]["verts_inside_skin"] = clearance(g, bsurf, 0.05, 0.03 if name == "boots" else -1.0)
        if name == "pants":   # cargo looseness: median clearance of the leg over the thigh/knee band
            ds = sorted((lambda q: (q[0] - w).length if q[0] is not None else 0.0)(bsurf.nearest(w))
                        for w in (g.matrix_world @ v.co for v in g.data.vertices) if 0.40 < w.z < 0.70)
            report[name]["leg_ease_median_m"] = round(ds[len(ds) // 2], 4)
        if name == "boots":
            report[name]["clearance_note"] = "verts below z 0.03 skipped: the sole slab wraps the masked foot sole by design"
        print("BUILT", name, report[name])
    objs = []
    for name, g in built.items():
        lod = E.make_lod1(g, E.LOD1_RATIO); lod.parent = rig
        report[name]["lod1_tris"] = tris(lod); objs += [g, lod]
    masks, order = write_masks(body, covers)
    report["body_masks"] = masks; report["mask_order"] = order
    report.update(E.export("default_outfit", objs, rig))
    json.dump(report, open(os.path.join(E.OUT, "BUILD-REPORT.json"), "w"), indent=1)
    print("OUTFIT", json.dumps({k: v for k, v in report.items() if k != "images"}))
