# Gear art wave E1-A (TASKS item 22, gear_tiers_plan.md section 7b / E1 batch plan): the T1 vest
# ("Padded Vest", gear_body_armor_t1) and the T1 helmet ("Shell Cap", gear_helmet_t1) as
# mid-to-high poly, original-design PBR models SKINNED to the Appearance-Proof rig, worn over the
# default outfit. Same pipeline as build_gear_e0.py / build_outfit.py (Blender 4.2, metres,
# transforms applied before bevels, n-gons triangulated, LOD1 ~40%, external T1 texture set from
# tools/gear_art_pbr/make_textures_t1.py, GLTF_SEPARATE so Godot imports the jpgs VRAM-compressed).
#   * Padded Vest: a soft quilted canvas wrap vest. Its body is an OFFSET SHELL of the ProofBody
#     torso (like the outfit garments) cut at the hem, arm holes and neckline, pushed out to clear
#     the outfit shirt, smoothed (stiff padding bridges hollows) and puffed between horizontal
#     quilting lines (outward only, so clearance never drops). Canvas binding on every edge,
#     front placket with snaps, chest pocket + flap, hand-warmer welts, side cinch straps with
#     roller buckles, back carry loop, stencil + care tag decals. Weights: ProofBody torso bones.
#   * Shell Cap: a thin canvas-covered bump-cap shell (superellipsoid fitted 8 mm over head +
#     short02 hair), six gore seams + top button, stitched front peak, vent grommets, rim binding,
#     cotton chin strap laid on the OUTERMOST hair surface (radial rays + 3 deg cone lift),
#     slider buckle, woven label. Rigid on the head bone; worn with the short helmet hair.
#   python3 tools/gear_art_pbr/make_textures_t1.py
#   blender -b --factory-startup -P tools/blender_midstyle/build_gear_e1.py   (GEAR_E1_ONLY=vest|helmet)
import bpy, bmesh, math, os, json, sys, importlib.util
from mathutils import Vector
from mathutils.kdtree import KDTree

HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location("outfit_build", os.path.join(HERE, "build_outfit.py"))
O = importlib.util.module_from_spec(_spec); _spec.loader.exec_module(O)
E = O.E                                   # build_gear_e0 helpers (one shared module instance)
ROOT = E.ROOT
E.OUT = os.path.join(ROOT, "raid", "assets", "gear", "t1")
E.TEX = os.path.join(E.OUT, "textures")
E.TMP = os.environ.get("GEAR_E1_TMP", "/tmp/gear_e1_export")
E.TILE = {"t1_canvas": 0.40, "t1_webbing": 0.10, "t1_steel": 0.06, "t1_decals": 1.0}
E.OUTFIT = os.path.join(ROOT, "raid", "assets", "outfit", "default_outfit.gltf")
Surf, sweep, rrect, sel, tris = E.Surf, E.sweep, E.rrect, E.sel, E.tris
MATN = {"t1_canvas": "T1_Canvas", "t1_webbing": "T1_Webbing", "t1_steel": "T1_Steel", "outfit_cord": "T1_Webbing"}

def mat(tex):
    name = MATN.get(tex, tex); t = "t1_webbing" if tex == "outfit_cord" else tex
    m = E.pbr(name, t)
    if name == "T1_Canvas": m.use_backface_culling = False   # single-layer padded shell: liner side visible in the arm holes
    return m
O.mat = mat

# ================================================================== T1 VEST: Padded Vest
HEM = 0.945                       # rides above the outfit belt (waistband top z 0.932), like the T3 carrier
ARM_YC, ARM_ZC, ARM_RY, ARM_RZ, ARM_X = -0.012, 1.205, 0.072, 0.118, 0.100
NECK_X = 0.062
def zf(x): return 1.19 + 0.11 * (x / NECK_X) ** 2         # front V/scoop
def zb(x): return 1.262 + 0.045 * (x / NECK_X) ** 2       # back neckline (under the shirt collar rib)
def arm_x(z):
    """Arm-hole edge (skin x): full side panel below 1.00, a deep rounded scoop up to the shoulder
    strap so the hanging / swinging arms (avatar 32 deg + sprint swing) clear the padded sides."""
    if z <= 1.00: return 0.148
    t = min(1.0, (z - 1.00) / 0.09); return ARM_X + (0.148 - ARM_X) * (1 - t) ** 2
def arm_e(p): return ((p.y - ARM_YC) / ARM_RY) ** 2 + ((p.z - ARM_ZC) / ARM_RZ) ** 2
SKIP = ("upperarm", "lowerarm", "hand", "thumb", "index", "middle", "ring", "pinky", "thigh", "calf", "foot", "ball", "neck", "head")

def torso_vert(p, d):
    """Torso skin incl. the shoulder tops / neck base (those verts are partly neck/upperarm weighted)."""
    if abs(p.x) < 0.110 and 1.2 < p.z < 1.37 and not d.startswith(("head", "hand")): return True
    return not d.startswith(SKIP)

def vest_keep(p, d):
    if not torso_vert(p, d) or p.z < HEM or p.z > 1.37: return False
    if abs(p.x) > arm_x(p.z): return False
    if abs(p.x) < NECK_X:
        if p.y < -0.02 and p.z > zf(p.x): return False
        if p.y >= -0.02 and p.z > zb(p.x): return False
    return True

def vest_snap(v):
    p = v.co
    if abs(p.z - HEM) < 0.025: p.z = HEM; return
    if p.z > 1.0 and abs(abs(p.x) - arm_x(p.z)) < 0.02:
        p.x = math.copysign(arm_x(p.z), p.x); return
    if abs(p.x) < NECK_X + 0.012:
        if p.y < -0.02 and abs(p.z - zf(p.x)) < 0.03: p.z = zf(p.x)
        elif p.y >= -0.02 and abs(p.z - zb(p.x)) < 0.03: p.z = zb(p.x)

def vest_want(p):
    if p.y < -0.04 and p.z > 1.15 and abs(p.x) < 0.075: return 0.031   # over the henley placket / collar
    if abs(p.x) > 0.105 and p.z > 1.04: return 0.028           # arm-hole bottom: over the shirt's underarm flare
    return 0.026                                                # clears the shirt (<= 17 mm at the bloused waist)

def torso_surf(body, dom):
    t = body.copy(); t.data = body.data.copy(); t.name = "TorsoProxy"
    bpy.context.scene.collection.objects.link(t)
    if t.data.shape_keys: t.shape_key_clear()
    for md in list(t.modifiers): t.modifiers.remove(md)
    bm = bmesh.new(); bm.from_mesh(t.data); bm.verts.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not torso_vert(body.matrix_world @ v.co, dom[v.index]) or (body.matrix_world @ v.co).z < 0.85], context="VERTS")
    bm.to_mesh(t.data); bm.free(); t.data.update()
    sf = Surf(t); bpy.data.objects.remove(t); return sf

def vest_shell(body, dom, bsurf):
    o = body.copy(); o.data = body.data.copy(); o.name = "VestShell"; o.data.name = "VestShell"
    bpy.context.scene.collection.objects.link(o)
    if o.data.shape_keys: o.shape_key_clear()
    for md in list(o.modifiers): o.modifiers.remove(md)
    o.vertex_groups.clear()
    # The ProofBody torso is sparse (~2 cm edges): cut a generous region, subdivide once, then
    # make the exact cut so the shoulder straps keep 3-4 rows of quads.
    bm = bmesh.new(); bm.from_mesh(o.data); bm.verts.ensure_lookup_table()
    rough = [torso_vert(body.matrix_world @ v.co, dom[v.index]) and HEM - 0.04 < (body.matrix_world @ v.co).z < 1.38 for v in bm.verts]
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not rough[v.index]], context="VERTS")
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=1, use_grid_fill=True, smooth=0.0)
    tsurf = torso_surf(body, dom)   # offsets are measured from the torso only (no arm normals in the armpit)
    for v in bm.verts:   # subdivision midpoints cut corners: put them back on the skin
        loc, nor = tsurf.nearest(v.co)
        if loc is not None: v.co = loc
    bsurf = tsurf
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not vest_keep(v.co, "")], context="VERTS")
    for _ in range(3):
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if len(v.link_faces) < 2], context="VERTS")
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-5)
    # Keep only the largest connected piece (drops stray islands near the arm holes).
    bm.verts.ensure_lookup_table(); seen = set(); parts = []
    for v in bm.verts:
        if v in seen: continue
        stack = [v]; comp = []; seen.add(v)
        while stack:
            a = stack.pop(); comp.append(a)
            for e in a.link_edges:
                b = e.other_vert(a)
                if b not in seen: seen.add(b); stack.append(b)
        parts.append(comp)
    parts.sort(key=len)
    for comp in parts[:-1]: bmesh.ops.delete(bm, geom=comp, context="VERTS")
    bnd = lambda: [v for v in bm.verts if v.is_boundary]
    for v in bnd(): vest_snap(v)
    def push(floor=None):
        for v in bm.verts:
            loc, nor = bsurf.nearest(v.co)
            if loc is None: continue
            want = vest_want(v.co) if floor is None else min(vest_want(v.co), floor)
            s = (v.co - loc).dot(nor)
            if s < want: v.co += nor * (want - s)
    push()
    inner = [v for v in bm.verts if not v.is_boundary]
    for it in range(26):   # stiff padding: bridge the sternum / under-bust / spine hollows
        bmesh.ops.smooth_vert(bm, verts=inner, factor=0.5, use_axis_x=True, use_axis_y=True, use_axis_z=True)
        for v in bnd(): vest_snap(v)
        push(0.020)
    for it in range(4):
        push(); bmesh.ops.smooth_vert(bm, verts=inner, factor=0.4, use_axis_x=True, use_axis_y=True, use_axis_z=True)
        for v in bnd(): vest_snap(v)
    push()
    # Quilting: puffed horizontal channels between stitch lines (outward only), none on the
    # front placket, fading out at the bound edges.
    bco = [v.co.copy() for v in bnd()]; kd = KDTree(len(bco))
    for i, c in enumerate(bco): kd.insert(c, i)
    kd.balance()
    CH = 0.056
    for v in bm.verts:
        if v.is_boundary: continue
        p = v.co; loc, nor = bsurf.nearest(p)
        if loc is None: continue
        if p.z > 1.24: amp = 0.0040                       # shoulders: lighter padding
        elif abs(p.x) > 0.105: amp = 0.0030               # side panels
        else: amp = 0.0065
        if p.y < 0 and abs(p.x) < 0.030: amp *= max(0.0, (abs(p.x) - 0.018) / 0.012)   # placket
        _, _, dist = kd.find(p); amp *= min(1.0, max(0.0, (dist - 0.006) / 0.016))
        puff = amp * math.sin(math.pi * (p.z - HEM) / CH) ** 2
        n = (p - loc).normalized() if (p - loc).length > 1e-6 else nor
        v.co = p + n * puff
    bm.to_mesh(o.data); bm.free(); o.data.update()
    E.set_mats(o, [mat("t1_canvas")])
    sel(o); bpy.ops.object.shade_smooth()
    E.uv_world(o)
    return o

def around(surf, z, a0, a1, n, sgn, lift):
    """Points round the torso side at height z: angle a (deg) 0 = side (sgn*x), -90 front, +90 back."""
    pts = []; nors = []
    for i in range(n + 1):
        a = math.radians(a0 + (a1 - a0) * i / n)
        d = Vector((sgn * math.cos(a), math.sin(a), 0))
        c = Vector((0, -0.02, z))
        loc, nor = surf.ray(c + d * 0.5, -d)
        if loc is None: continue
        pts.append(loc + nor * lift); nors.append(nor)
    return pts, nors

def stitched(name, surf, c, right, up, w, h, off, thick, r):
    """Patch + perimeter stitch: the stitch follows the open patch edge, then the patch is thickened."""
    p = O.patch(name, surf, c, right, up, w, h, off, "t1_canvas", thick=0.0, r=r)
    loop = O.edge_loop_of(p); st = None
    if loop:
        path = O.on_surf(Surf(p), O.resample(O.smooth_path(loop, 3), 0.007), thick + 0.0004)
        st = O.tube(name + "Stitch", path + [path[0]], 0.0008, "outfit_cord", seg=4)
    s = p.modifiers.new("Solid", "SOLIDIFY"); s.thickness = thick; s.offset = 1.0; E.apply_all(p)
    return [p] + ([st] if st else [])

def padded_vest():
    E.reset()
    rig = bpy.data.objects["AppearanceProofRig"]; body = bpy.data.objects["ProofBody"]
    gname = {g.index: g.name for g in body.vertex_groups}
    dom = [gname[max(v.groups, key=lambda g: g.weight).group] if v.groups else "" for v in body.data.vertices]
    bsurf = Surf(body)
    shirt = E.outfit_shirt()
    canvas, web, steel = mat("t1_canvas"), mat("t1_webbing"), mat("t1_steel")
    dec = E.pbr("T1_Decals", "t1_decals", 0.6)
    shell = vest_shell(body, dom, bsurf)
    ss = Surf(shell); parts = [shell]
    # Binding tape over every edge (hem, arm holes, neckline + front V).
    for i, loop in enumerate(O.boundary_loops(shell)):
        path = O.resample(O.smooth_path(loop, 4), 0.011); nn = [ss.nearest(p)[1] for p in path]
        prof = [(-0.0012, -0.011), (0.0024, -0.0095), (0.0036, 0.0), (0.0024, 0.0095), (-0.0012, 0.011)]
        b = sweep("Binding%d" % i, path, nn, prof, closed=True, cap=False); E.finish(b, [web], smooth_angle=70)
        parts.append(b)
    # Front placket (closure strip) with five snaps.
    path = []; nors = []
    for k in range(25):
        z = HEM + 0.004 + (zf(0.0) - HEM - 0.010) * k / 24
        loc, nor = ss.ray(Vector((0, -0.5, z)), Vector((0, 1, 0)))
        if loc is None: continue
        path.append(loc + nor * 0.0006); nors.append(nor)
    pl = sweep("Placket", path, nors, [(0, -0.019), (0.0038, -0.018), (0.0042, 0.0), (0.0038, 0.018), (0, 0.019)])
    E.finish(pl, [canvas], smooth_angle=50); parts.append(pl)
    psf = Surf(pl)
    for k in range(5):
        z = HEM + 0.030 + k * (zf(0.0) - HEM - 0.060) / 4
        parts.append(O.cyl_on("Snap%d" % k, psf, Vector((0, -0.3, z)), 0.0062, 0.0032, "t1_steel", off=0.0002))
    # Chest pocket (wearer's left = +X) with flap and snap; hand-warmer welts.
    cp = stitched("ChestPocket", ss, Vector((0.068, -0.2, 1.085)), Vector((1, 0, 0)), Vector((0, 0, 1)), 0.088, 0.100, 0.0012, 0.0035, 0.010)
    parts += cp; cp = cp[0]
    flap = O.patch("ChestFlap", Surf(cp), Vector((0.068, -0.2, 1.124)), Vector((1, 0, 0)), Vector((0, 0, 1)), 0.094, 0.034, 0.0012, "t1_canvas", thick=0.003, r=0.008)
    parts.append(flap); parts.append(O.cyl_on("FlapSnap", Surf(flap), Vector((0.068, -0.3, 1.118)), 0.0055, 0.003, "t1_steel", off=0.0002))
    for s in (1, -1):
        parts += stitched("Welt", ss, Vector((s * 0.072, -0.2, 0.990)), Vector((1, 0, -0.35 * s)), Vector((0.35 * s, 0, 1)), 0.110, 0.020, 0.0010, 0.0035, 0.006)
    # Side cinch strap (one per side) with roller buckles at the front end.
    for s in (1, -1):
        for z in (0.984,):   # below the arm-hole scoop (starts at 1.00)
            pts, nn = around(ss, z, -42, 58, 20, s, 0.0012)
            st = sweep("Cinch", pts, nn, rrect(0.0028, 0.024, 0.0010, 1)); E.finish(st, [web], smooth_angle=60); parts.append(st)
            p0, n0 = pts[1], nn[1]
            bpy.ops.mesh.primitive_torus_add(major_radius=0.016, minor_radius=0.0022, major_segments=16, minor_segments=6, location=(0, 0, 0), rotation=(math.pi / 2, 0, 0))
            bk = bpy.context.active_object; bk.name = "RollerBuckle"; bk.scale = (0.75, 1, 1.0); E.finish(bk, [steel])
            bar = E.cyl(0.0026, 0.026, (0, 0, 0), rot=(0, 0, 0), verts=12, name="Roller"); E.finish(bar, [steel], bevel=0.0006, segs=1)
            g = E.join([bk, bar], "Buckle"); E.orient(g, p0 + n0 * 0.0045, n0); parts.append(g)
    # Back: carry loop at the neck, stencil, care tag at the front left hip.
    hp = []; hn = []
    for k, x in enumerate((-0.035, -0.028, 0.0, 0.028, 0.035)):
        z = (1.248, 1.268, 1.278, 1.268, 1.248)[k]
        loc, nor = ss.ray(Vector((x, 0.5, z)), Vector((0, -1, 0)))
        if loc is None: continue
        hp.append(loc + nor * (0.003 if k in (0, 4) else 0.011)); hn.append(Vector((0, 1, 0)))
    dh = sweep("CarryLoop", hp, hn, rrect(0.0030, 0.020, 0.0012, 2)); E.finish(dh, [web], smooth_angle=60); parts.append(dh)
    sten = O.patch("BackStencil", ss, Vector((0, 0.3, 1.165)), Vector((-1, 0, 0)), Vector((0, 0, 1)), 0.150, 0.0285, 0.0009, "t1_canvas", thick=0.0, res=0.006, r=0.002)
    E.set_mats(sten, [dec]); E.decal_uv(sten, (0, 0, 1024, 192), Vector((-1, 0, 0)), Vector((0, 0, 1))); parts.append(sten)
    tag = O.patch("CareTag", ss, Vector((0.105, -0.2, 0.975)), Vector((0.6, -0.8, 0)), Vector((0, 0, 1)), 0.048, 0.030, 0.0016, "t1_canvas", thick=0.0, res=0.006, r=0.002)
    E.set_mats(tag, [dec]); E.decal_uv(tag, (512, 192, 1024, 512), Vector((0.6, -0.8, 0)), Vector((0, 0, 1))); parts.append(tag)
    parts = [p for p in parts if p]
    print("PARTS", sorted(((tris(p), p.name) for p in parts), reverse=True)[:12])
    vest = E.join(parts, "PaddedVest"); E.merge_duplicate_slots(vest)
    sel(vest); bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    t = vest.modifiers.new("Tri", "TRIANGULATE"); sel(vest); bpy.ops.object.modifier_apply(modifier="Tri")
    report = {"lod0_tris": tris(vest), "materials": [m.name for m in vest.data.materials]}
    report["clearance_m"], report["verts_inside_skin"] = E.clearance(vest, [body])
    report["shirt_clearance_m"], report["verts_inside_shirt"] = E.layer_clearance(vest, shirt, body)
    if os.environ.get("GEAR_E1_DEBUG"):
        sb, su = Surf(body), Surf(shirt)
        for v in vest.data.vertices:
            q, _ = su.nearest(v.co)
            if q is None or (q - v.co).length > 0.03: continue
            h = lambda p: (p - sb.nearest(p)[0]).dot(sb.nearest(p)[1])
            if h(v.co) - h(q) < 0: print("SHIRT_IN", tuple(round(x, 3) for x in v.co), round(h(v.co) - h(q), 4), vest.data.materials[0].name)
    bpy.data.objects.remove(shirt)
    E.transfer_weights(vest, body, {"pelvis", "spine_01", "spine_02", "spine_03", "clavicle_l", "clavicle_r"})
    E.bind(vest, rig, None)
    lod = E.make_lod1(vest, E.LOD1_RATIO); lod.parent = rig
    report["lod1_tris"] = tris(lod); report["bones"] = sorted(g.name for g in vest.vertex_groups)
    report.update(E.export("gear_body_armor_t1", [vest, lod], rig))
    return report

# ================================================================== T1 HELMET: Shell Cap
def shell_cap():
    E.reset()
    rig = bpy.data.objects["AppearanceProofRig"]; body = bpy.data.objects["ProofBody"]
    hair = [bpy.data.objects["hair_short02_v1"]]
    head = E.proxy_from([body], "HeadProxy", keep=lambda c: c.z > 1.33 and abs(c.x) < 0.12)
    hb = E.proxy_from([body] + hair, "HeadHair", keep=lambda c: c.z > 1.33 and abs(c.x) < 0.13)
    canvas, web, steel = mat("t1_canvas"), mat("t1_webbing"), mat("t1_steel")
    strap_m = E.pbr("T1_Strap", "t1_webbing", 0.9); dec = E.pbr("T1_Decals", "t1_decals", 0.6)
    C = Vector((0.0, -0.048, 1.452)); EX = 2.3
    def sgnpow(v, p): return math.copysign(abs(v) ** p, v)
    def rim_z(theta):   # 0 = front; sits a little higher than the T3 helmet (cap, not a combat shell)
        a = abs(math.degrees(theta))
        keys = [(0, 1.506), (30, 1.504), (55, 1.495), (72, 1.483), (100, 1.477), (130, 1.459), (155, 1.441), (180, 1.433)]
        for (a0, z0), (a1, z1) in zip(keys, keys[1:]):
            if a <= a1:
                t = (a - a0) / (a1 - a0); t = t * t * (3 - 2 * t); return z0 + (z1 - z0) * t
        return keys[-1][1]
    R = Vector((0.095, 0.106, 0.104))
    hpts = [v for v in Surf(hb).v if v.z > 1.40]
    def f(p, R):
        d = p - C; return abs(d.x / R.x) ** EX + abs(d.y / R.y) ** EX + abs(d.z / R.z) ** EX
    for _ in range(40):
        worst = max(f(p + (p - C).normalized() * 0.008, R) for p in hpts if p.z > rim_z(math.atan2(p.x, -p.y)) - 0.01)
        if worst <= 1.0: break
        R = R * (worst ** (1 / EX)) ** 0.5
    NS, NR = 48, 12
    def surf_pt(theta, phi):
        n = Vector((math.sin(phi) * math.sin(theta), -math.sin(phi) * math.cos(theta), math.cos(phi)))
        return C + Vector((R.x * sgnpow(n.x, 2 / EX), R.y * sgnpow(n.y, 2 / EX), R.z * sgnpow(n.z, 2 / EX)))
    def phi_rim(theta):
        zc = (rim_z(theta) - C.z) / R.z; return math.acos(max(-1, min(1, sgnpow(zc, EX / 2))))
    verts = [tuple(C + Vector((0, 0, R.z)))]; faces = []
    for r in range(1, NR + 1):
        t = r / NR
        for s in range(NS):
            th = -math.pi + 2 * math.pi * s / NS; verts.append(tuple(surf_pt(th, phi_rim(th) * t)))
    for s in range(NS): faces.append((0, 1 + s, 1 + (s + 1) % NS))
    for r in range(NR - 1):
        for s in range(NS):
            a = 1 + r * NS + s; b = 1 + r * NS + (s + 1) % NS; faces.append((a, a + NS, b + NS, b))
    shell = E.mesh_obj("CapShell", verts, faces)
    sel(shell); bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.select_all(action="SELECT"); bpy.ops.mesh.normals_make_consistent(inside=False); bpy.ops.object.mode_set(mode="OBJECT")
    E.set_mats(shell, [canvas, web, canvas])
    so = shell.modifiers.new("Solid", "SOLIDIFY"); so.thickness = 0.0045; so.offset = -1.0; so.use_even_offset = True
    so.use_rim = True; so.material_offset = 1; so.material_offset_rim = 2
    E.apply_all(shell); E.finish(shell, None, bevel=0.0010, segs=2, smooth_angle=50)
    ss = Surf(shell); parts = [shell]
    def on_shell(theta, z, off):
        d = Vector((math.sin(theta), -math.cos(theta), 0))
        loc, nor = ss.ray(Vector((C.x, C.y, z)) + d * 0.4, -d)
        return loc + nor * off, nor
    # Six gore seams (raised felled seams) crown -> rim, and the top button.
    for g in range(6):
        th = -math.pi + math.pi / 6 + g * math.pi / 3
        path = []; nn = []
        for k in range(1, 15):
            p = surf_pt(th, phi_rim(th) * k / 14); loc, nor = ss.nearest(p)
            path.append(loc + nor * 0.0002); nn.append(nor)
        sm = sweep("Gore", path, nn, [(-0.0003, -0.0030), (0.0006, -0.0020), (0.0009, 0.0), (0.0006, 0.0020), (-0.0003, 0.0030)])
        E.finish(sm, [canvas], smooth_angle=60); parts.append(sm)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, radius=0.0085, location=(0, 0, 0))
    btn = bpy.context.active_object; btn.scale = (1, 1, 0.42); E.finish(btn, [canvas])
    loc, nor = ss.ray(Vector((C.x, C.y, 1.8)), Vector((0, 0, -1))); E.orient(btn, loc + nor * 0.0015, nor, up=Vector((0, 1, 0))); parts.append(btn)
    # Rim binding.
    rim = []; rn = []
    for s in range(NS * 2):
        th = -math.pi + 2 * math.pi * s / (NS * 2); p = surf_pt(th, phi_rim(th))
        h = Vector((p.x - C.x, p.y - C.y, 0)).normalized(); rim.append(p - Vector((0, 0, 0.0008))); rn.append(h)
    prof = [(0.0040 * math.cos(2 * math.pi * k / 8) - 0.0018, 0.0048 * math.sin(2 * math.pi * k / 8)) for k in range(8)]
    rb = sweep("RimBinding", rim, rn, prof, closed=True, cap=False); E.finish(rb, [web], smooth_angle=70); parts.append(rb)
    # Front peak: stiffened canvas, gently down-curved, with three rows of stitching.
    NA, NL = 20, 6; PK = 42.0; LEN = 0.044
    def peak_pt(i, j):
        th = math.radians(-PK + 2 * PK * i / NA); p = surf_pt(th, phi_rim(th))
        h = Vector((p.x - C.x, p.y - C.y, 0)).normalized()
        L = LEN * math.cos(math.radians(90 * (abs(math.degrees(th)) / PK))) ** 0.55
        r = L * j / NL
        return p + h * (r + 0.002) - Vector((0, 0, 0.16 * r + 0.22 * r * r / max(LEN, 1e-6))) - Vector((0, 0, 0.0015))
    pv = []; pf = []
    for i in range(NA + 1):
        for j in range(NL + 1): pv.append(peak_pt(i, j))
    for i in range(NA):
        for j in range(NL):
            a = i * (NL + 1) + j; pf.append((a, a + NL + 1, a + NL + 2, a + 1))
    pk = E.mesh_obj("Peak", pv, pf)
    bm = bmesh.new(); bm.from_mesh(pk.data); bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=0.0006)
    bmesh.ops.dissolve_degenerate(bm, dist=0.0006, edges=bm.edges[:]); bm.to_mesh(pk.data); bm.free()
    sel(pk); bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.select_all(action="SELECT"); bpy.ops.mesh.normals_make_consistent(inside=False); bpy.ops.object.mode_set(mode="OBJECT")
    if sum(p.normal.z for p in pk.data.polygons) < 0:
        sel(pk); bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.select_all(action="SELECT"); bpy.ops.mesh.flip_normals(); bpy.ops.object.mode_set(mode="OBJECT")
    E.set_mats(pk, [canvas])
    so = pk.modifiers.new("Solid", "SOLIDIFY"); so.thickness = 0.004; so.offset = -1.0; E.apply_all(pk)
    E.finish(pk, None, bevel=0.0012, segs=2, smooth_angle=40); parts.append(pk)
    for row in (0.35, 0.6, 0.85):
        pts = []
        for i in range(1, NA):
            th = math.radians(-PK + 2 * PK * i / NA)
            if abs(math.degrees(th)) > PK * 0.92: continue
            q = peak_pt(i, NL * row); pts.append(q + Vector((0, 0, 0.0007)))
        if len(pts) > 3: parts.append(O.tube("PeakStitch", pts, 0.0007, "outfit_cord", seg=4))
    # Vent grommets (two per side).
    for sgn in (-1, 1):
        for deg, dz in ((72, 0.030), (108, 0.026)):
            th = sgn * math.radians(deg); p, n = on_shell(th, rim_z(th) + dz, 0.0)
            bpy.ops.mesh.primitive_torus_add(major_radius=0.0052, minor_radius=0.0016, major_segments=16, minor_segments=6, location=(0, 0, 0), rotation=(math.pi / 2, 0, 0))
            gr = bpy.context.active_object; gr.name = "Grommet"; E.finish(gr, [steel])
            E.orient(gr, p + n * 0.0008, n); parts.append(gr)
    # Woven label at the back.
    lab = O.patch("CapLabel", ss, Vector((0, C.y + 0.2, rim_z(math.pi) + 0.024)), Vector((-1, 0, 0)), Vector((0, 0, 1)), 0.040, 0.026, 0.0008, "t1_canvas", thick=0.0, res=0.005, r=0.003)
    E.set_mats(lab, [dec]); E.decal_uv(lab, (0, 192, 512, 512), Vector((-1, 0, 0)), Vector((0, 0, 1))); parts.append(lab)
    # Chin strap over the OUTERMOST head/hair surface (see build_gear_e0.warden_helm).
    import numpy as np
    sh_head = Surf(hb); HC = Vector((0.0, -0.035, 1.425))
    strap_pts, strap_edges = [], []
    hv = np.array([tuple(hb.matrix_world @ v.co) for v in hb.data.vertices]) - np.array(tuple(HC))
    hr = np.linalg.norm(hv, axis=1); hd = hv / hr[:, None]; ccos = math.cos(math.radians(3.0))
    def cone_r(q):
        d = np.array(tuple((q - HC).normalized())); m = hd @ d > ccos
        return float(hr[m].max()) if m.any() else 0.0
    def outer(p, off):
        d = (p - HC).normalized(); loc, nor = sh_head.ray(HC + d * 0.4, -d)
        if loc is None: loc, nor = sh_head.nearest(p)
        n = nor if nor.dot(d) > 0 else -nor
        return loc + d * off, n.lerp(d, 0.5).normalized()
    def skin_path(raw, off, n=6, half_w=0.007):
        path = []; nors = []
        for i in range(len(raw) - 1):
            for s in range(n):
                q, m = outer(raw[i].lerp(raw[i + 1], s / n), off); path.append(q); nors.append(m)
        q, m = outer(raw[-1], off); path.append(q); nors.append(m)
        sm = E.smooth_pts(path); out = []
        for p0 in sm:
            q, m = outer(p0, off); out.append(q if (q - HC).length > (p0 - HC).length else p0)
        for i in range(len(out)):
            t = (out[min(i + 1, len(out) - 1)] - out[max(i - 1, 0)]).normalized(); side = t.cross(nors[i]).normalized()
            dr = (out[i] - HC).normalized(); lift = 0.0
            for e in (-half_w, 0.0, half_w):
                q = out[i] + side * e; h, _ = outer(q, 0.0)
                lift = max(lift, (h - HC).length + 0.0015 - (q - HC).length, cone_r(q) + 0.0012 - (q - HC).length)
            if lift > 0.0: out[i] = out[i] + dr * lift
            strap_edges.extend([out[i] - side * half_w, out[i] + side * half_w])
        strap_pts.extend(out); return out, nors
    sprof = [(0, -0.007), (0.0016, -0.007), (0.0016, 0.007), (0, 0.007)]
    for sgn in (-1, 1):
        th = sgn * math.radians(96); a = surf_pt(th, phi_rim(th)) - Vector((0, 0, 0.003))
        j = Vector((sgn * 0.071, -0.094, 1.386))
        raw = [a, a.lerp(j, 0.5) + Vector((sgn * 0.008, 0, 0)), j, Vector((sgn * 0.044, -0.134, 1.352)), Vector((0.0, -0.149, 1.345))]
        path, nors = skin_path(raw, 0.004)
        s = sweep("ChinStrap", path, nors, sprof); s.data.materials.append(strap_m); E.finish(s, None, smooth_angle=60); parts.append(s)
        # Strap end tab sewn under the rim + a steel rivet.
        p0, n0 = path[0], nors[0]
        rv = E.cyl(0.0035, 0.0022, (0, 0, 0), rot=(math.pi / 2, 0, 0), verts=12, name="Rivet"); E.finish(rv, [steel], bevel=0.0006, segs=1)
        E.orient(rv, p0 + n0 * 0.0028, n0); parts.append(rv)
        if sgn > 0:   # slider buckle on the wearer's left jaw
            k = len(path) // 2 + 2; pb, nb = path[k], nors[k]; tb = (path[k + 1] - path[k - 1]).normalized()
            bpy.ops.mesh.primitive_torus_add(major_radius=0.010, minor_radius=0.0018, major_segments=20, minor_segments=6, location=(0, 0, 0), rotation=(math.pi / 2, 0, 0))
            sb = bpy.context.active_object; sb.name = "Slider"; sb.scale = (1.0, 1, 0.62); E.finish(sb, [steel])
            bar = E.box((0.017, 0.0024, 0.0022), (0, 0, 0), name="SliderBar"); E.finish(bar, [steel], bevel=0.0005, segs=1)
            g = E.join([sb, bar], "Slider"); E.orient(g, pb + nb * 0.0032, nb, up=tb); parts.append(g)
    parts = [p for p in parts if p]
    cap = E.join(parts, "ShellCap"); E.merge_duplicate_slots(cap)
    sel(cap); bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    t = cap.modifiers.new("Tri", "TRIANGULATE"); sel(cap); bpy.ops.object.modifier_apply(modifier="Tri")
    report = {"lod0_tris": tris(cap), "materials": [m.name for m in cap.data.materials], "radii_m": [round(x, 4) for x in R]}
    report["clearance_m"], report["verts_inside_skin"] = E.clearance(cap, [hb])
    buried = 0
    for p, tol in [(q, 0.002) for q in strap_pts] + [(q, 0.0005) for q in strap_edges]:
        d = (p - HC).normalized(); loc, nor = sh_head.ray(HC + d * 0.4, -d)
        if loc is not None and (loc - HC).length > (p - HC).length - tol: buried += 1
    report["strap_points"] = len(strap_pts) + len(strap_edges); report["strap_points_in_hair"] = buried
    for o in (head, hb): bpy.data.objects.remove(o)
    E.rigid_weights(cap, "head"); E.bind(cap, rig, None)
    lod = E.make_lod1(cap, E.LOD1_RATIO); lod.parent = rig
    report["lod1_tris"] = tris(lod); report["bones"] = ["head"]
    report.update(E.export("gear_helmet_t1", [cap, lod], rig))
    return report

if __name__ == "__main__":
    which = os.environ.get("GEAR_E1_ONLY", "")
    report = {}
    if which in ("", "vest"): report["gear_body_armor_t1"] = padded_vest()
    if which in ("", "helmet"): report["gear_helmet_t1"] = shell_cap()
    for k in report: report[k]["tool"] = "tools/blender_midstyle/build_gear_e1.py (gear art E1-A)"
    print("GEAR_E1", json.dumps(report))
    rp = os.path.join(E.OUT, "BUILD-REPORT.json")
    old = json.load(open(rp)) if os.path.exists(rp) else {}
    old.update(report); json.dump(old, open(rp, "w"), indent=1)
