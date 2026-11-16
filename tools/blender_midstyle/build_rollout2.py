# Item 12 rollout 2: mid-to-high poly remodels of the launchpad ship (item 12 #6)
# and the plaza request board (item 12 #16). Reuses pass 3 helpers in build_midstyle.py.
# Blender 4.2, meter scale, Z-up, front = -Y (glTF export_yup -> Godot Y-up, front +Z).
# Transforms are applied before export. Each export is one mesh per material.
# The original launchpad_ship.glb is not edited (import/scn are pinned); these are
# runtime visual swaps. The hull stays inside the original silhouette (r <= 5.5 m
# for the body, pad r = 8 m, ramp to Godot z = 18.8 m) so collision and takeoff
# construction details still sit correctly.
#
#   blender -b --factory-startup -P tools/blender_midstyle/build_rollout2.py -- [pad] [hull] [board]
import bpy, bmesh, math, random, os, sys
from mathutils import Vector, Matrix, noise
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_midstyle as B
from build_midstyle import mat, box, cyl, sphere, lathe, tube, sweep_rect, finish, paint, uv_box, uv_cyl, uv_rect, join, obj_from_bm, apply_all, smooth, select_only, fixn, xform, bevel

REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
OUT = os.environ.get("ROLLOUT2_OUT", os.path.join(REPO, "assets", "midstyle_rollout2"))
if not OUT.endswith("/"):
    OUT += "/"
B.TEX = os.environ.get("ROLLOUT2_TEX", "/workspace/settlement_rollout2/tex/")
B.OUT = OUT
BLEND = os.environ.get("ROLLOUT2_BLEND", "/workspace/settlement_rollout2/blender/")
os.makedirs(OUT, exist_ok=True)
os.makedirs(BLEND, exist_ok=True)
TAU = 2 * math.pi
REPORT = {}

def reset(seed=16):
    B.reset(); random.seed(seed)

def tris_of(obs):
    t = 0
    for o in obs:
        if o is None or o.type != 'MESH':
            continue
        o.data.calc_loop_triangles(); t += len(o.data.loop_triangles)
    return t

def part(parts, ob, uv=('box', .5, None), **pk):
    pk.setdefault("seed", len(parts) * 1.17)
    finish(ob, uv, **pk); parts.append(ob); return ob

def G(x, y, z):
    """Godot (Y-up, front +Z) -> Blender (Z-up, front -Y)."""
    return Vector((x, -z, y))

def write(path, nodes):
    # Only export the listed mesh nodes (hide everything else).
    bpy.ops.object.select_all(action='DESELECT')
    meshes = [o for o in nodes if o is not None and o.type == 'MESH']
    # Join by material so Godot gets one surface per material.
    by_mat = {}
    for o in meshes:
        m = o.data.materials[0].name if o.data.materials else "None"
        by_mat.setdefault(m, []).append(o)
    joined = []
    for name, group in by_mat.items():
        joined.append(join(group, name) if len(group) > 1 else group[0])
    tri = tris_of(joined)
    REPORT[path] = tri
    print("ROLLOUT2_TRIS", path, tri, "MATERIALS", sorted(by_mat.keys()), "SURFACES", len(joined))
    bpy.ops.object.select_all(action='DESELECT')
    for o in joined:
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=OUT + path + ".gltf", export_format='GLTF_SEPARATE',
                              export_texture_dir="textures", use_selection=True, export_apply=True,
                              export_yup=True, export_vertex_color='MATERIAL',
                              export_all_vertex_colors=False, export_normals=True,
                              export_materials='EXPORT', export_image_format='JPEG',
                              export_jpeg_quality=90)
    bpy.ops.wm.save_as_mainfile(filepath=BLEND + path + ".blend")
    return tri

# ------------------------------------------------------------------ materials
def mats_ship():
    return {
        "ivory": mat("IvoryHull", "hull_ivory", .86, .08),
        "ochre": mat("OchreLivery", "hull_ochre", .84, .06),
        "alloy": mat("ExposedAlloy", "steel_bare", .42, .72),
        "graphite": mat("GraphiteMetal", "trim_dark", .48, .65),
        "bronze": mat("OxidizedBronze", "bronze", .55, .55),
        "glass": mat("CockpitGlass", "glass_cockpit", .12, .18, emit=((0.035, 0.09, 0.10), 0.28)),
        "stone": mat("PadStone", "pad_concrete", .92, 0.0),
        "inlay": mat("DeckInlay", "deck_inlay", .88, 0.0),
        "amber": mat("AmberBeacon", "glass_amber", .28, .1, emit=((1.0, 0.55, 0.12), 1.6)),
        "cyan": mat("CyanMarker", "glass_green", .25, .1, emit=((0.15, 0.85, 0.9), 1.1)),
        "rubber": mat("GearRubber", "rubber_black" if os.path.exists(B.TEX + "rubber_black.png") else "trim_dark", .7, .05),
    }

def mats_board():
    return {
        "oak": mat("BoardTimber", "oak", .82, 0.0),
        "walnut": mat("BoardWalnut", "walnut", .84, 0.0),
        "bronze": mat("BoardBronze", "bronze", .5, .55),
        "paper": mat("NoticePaper", "notice_paper", .9, 0.0),
        "ink": mat("NoticeInk", "ink_black", .7, 0.05),
        "wax": mat("WaxSeal", "terracotta", .55, 0.0),
        "cream": mat("HeaderLettering", "wool_cream", .55, .15),
        "iron": mat("BoardIron", "iron", .48, .6),
    }

# ================================================================== PAD + RAMP
def build_pad():
    reset(16)
    M = mats_ship(); P = []
    stone, inlay, bronze, graphite, amber = M["stone"], M["inlay"], M["bronze"], M["graphite"], M["amber"]
    # Pedestal: stacked bevelled rings so the 1.28 m deck reads as stone courses, not a cylinder.
    for i, (r0, r1, z0, z1, bev) in enumerate((
        (7.55, 8.00, -0.055, 0.18, 0.02),
        (7.40, 7.92, 0.16, 0.62, 0.015),
        (7.28, 7.85, 0.60, 1.10, 0.015),
        (7.18, 7.72, 1.08, 1.28, 0.012),
    )):
        bm = bmesh.new()
        segs = 96
        rings = []
        for r, z in ((r0, z0), (r1, z0), (r1, z1), (r0, z1)):
            ring = [bm.verts.new((math.cos(TAU * k / segs) * r, math.sin(TAU * k / segs) * r, z)) for k in range(segs)]
            rings.append(ring)
        # sides
        for a, b in ((0, 1), (1, 2), (2, 3), (3, 0)):
            ra, rb = rings[a], rings[b]
            for k in range(segs):
                n = (k + 1) % segs
                bm.faces.new((ra[k], ra[n], rb[n], rb[k]))
        # caps: only top of the last course and bottom of the first
        if i == 0:
            bm.faces.new(list(reversed(rings[0])))  # bottom
        if i == 3:
            bm.faces.new(rings[2])  # top outer lip; inner filled by deck
        ob = obj_from_bm(bm, f"PadCourse{i}", stone)
        bevel(ob, bev, 2, 50); apply_all(ob); smooth(ob, 40)
        part(P, ob, ('cyl', (0, 0), 2, 2.4, (r0 + r1) / 2), seed=10 + i, edge=.12, cavity=.18)

    # Main deck disc, r=7.22, y=1.279, with a hole? No, full disc; inlay sits on top as a ring.
    deck = cyl("PadDeck", stone, (0, 0, 1.268), 7.22, 0.022, 96, 0.006)
    part(P, deck, ('cyl', (0, 0), 2, 2.0, 7.22), seed=20, edge=.08, cavity=.12)

    # Radial grout seams (thin inset boxes) for tile read.
    for k in range(16):
        a = TAU * k / 16
        # skip the ramp opening roughly +Z in Godot => -Y in Blender, around a = -pi/2? 
        # Godot +Z is Blender -Y, angle in XY blender: atan2(y,x); ramp is godot z>6 => blender y < -6.
        # We'll still score the deck; the ramp cut is a separate opening later.
        sx, sy = math.cos(a), math.sin(a)
        mid = Vector((sx * 3.6, sy * 3.6, 1.280))
        seam = box("DeckSeam", stone, mid, (0.028, 7.15, 0.008), bev=0.002, segs=1, rot=(0, 0, a))
        part(P, seam, ('box', .8, None), seed=30 + k, edge=0, cavity=.05, noise_amt=.02)
    for r in (2.4, 4.4, 6.2):
        # ring seam as a thin torus-like flattened ring
        bm = bmesh.new()
        segs = 80
        w, h = 0.028, 0.007
        inner, outer = r - w / 2, r + w / 2
        v_in = [bm.verts.new((math.cos(TAU * k / segs) * inner, math.sin(TAU * k / segs) * inner, 1.280)) for k in range(segs)]
        v_out = [bm.verts.new((math.cos(TAU * k / segs) * outer, math.sin(TAU * k / segs) * outer, 1.280)) for k in range(segs)]
        v_in2 = [bm.verts.new((math.cos(TAU * k / segs) * inner, math.sin(TAU * k / segs) * inner, 1.280 + h)) for k in range(segs)]
        v_out2 = [bm.verts.new((math.cos(TAU * k / segs) * outer, math.sin(TAU * k / segs) * outer, 1.280 + h)) for k in range(segs)]
        for k in range(segs):
            n = (k + 1) % segs
            bm.faces.new((v_in[k], v_out[k], v_out[n], v_in[n]))
            bm.faces.new((v_in2[n], v_out2[n], v_out2[k], v_in2[k]))
            bm.faces.new((v_in[k], v_in[n], v_in2[n], v_in2[k]))
            bm.faces.new((v_out[n], v_out[k], v_out2[k], v_out2[n]))
        ob = obj_from_bm(bm, f"DeckRing{r}", stone)
        apply_all(ob); smooth(ob, 50)
        part(P, ob, ('cyl', (0, 0), 2, 1.6, r), seed=40 + int(r), edge=0, cavity=.04)

    # Cream inlay ring 5.80–7.23 at deck height.
    bm = bmesh.new(); segs = 96
    z0, z1 = 1.2795, 1.288
    r0, r1 = 5.80, 7.23
    def ring(r, z):
        return [bm.verts.new((math.cos(TAU * k / segs) * r, math.sin(TAU * k / segs) * r, z)) for k in range(segs)]
    a, b, c, d = ring(r0, z0), ring(r1, z0), ring(r1, z1), ring(r0, z1)
    for k in range(segs):
        n = (k + 1) % segs
        bm.faces.new((a[k], b[k], b[n], a[n]))
        bm.faces.new((d[n], c[n], c[k], d[k]))
        bm.faces.new((a[k], a[n], d[n], d[k]))
        bm.faces.new((b[n], b[k], c[k], c[n]))
    inl = obj_from_bm(bm, "DeckInlay", inlay)
    bevel(inl, 0.004, 2, 40); apply_all(inl); smooth(inl, 40)
    part(P, inl, ('cyl', (0, 0), 2, 1.8, 6.5), seed=50, edge=.1, cavity=.1)

    # Ramp: Godot +Z is Blender -Y. Deck edge at |y|=~7.2, ramp to y=-18.8, width ~3.2 m (X).
    # Slope from z=1.28 at y=-7.25 to z=0.02 at y=-16.3, then a short ground apron to y=-18.8.
    def ramp_y_to_z(y):
        # y is blender Y (negative along the ramp)
        if y >= -7.25:
            return 1.28
        if y >= -16.3:
            t = (-y - 7.25) / (16.3 - 7.25)
            return 1.28 * (1 - t) + 0.02 * t
        return 0.02
    # Ramp slab as a grid.
    bm = bmesh.new()
    xs = [i / 10 * 1.55 for i in range(-10, 11)]  # half-width 1.55 at start; widens slightly
    ys = [-(7.20 + i * 0.35) for i in range(0, 34)]  # 7.20 -> 18.75
    gridv = []
    for yi, y in enumerate(ys):
        # widen toward the foot: 1.55 -> 1.70
        t = yi / (len(ys) - 1)
        scale = 1.0 + 0.10 * t
        row = []
        for x in xs:
            z = ramp_y_to_z(y)
            # thickness 0.09
            row.append(bm.verts.new((x * scale, y, z)))
        gridv.append(row)
    # top faces
    for i in range(len(ys) - 1):
        for j in range(len(xs) - 1):
            bm.faces.new((gridv[i][j], gridv[i][j + 1], gridv[i + 1][j + 1], gridv[i + 1][j]))
    # underside
    under = []
    for yi, y in enumerate(ys):
        t = yi / (len(ys) - 1)
        scale = 1.0 + 0.10 * t
        row = []
        for x in xs:
            z = ramp_y_to_z(y) - 0.10
            row.append(bm.verts.new((x * scale, y, z)))
        under.append(row)
    for i in range(len(ys) - 1):
        for j in range(len(xs) - 1):
            bm.faces.new((under[i][j + 1], under[i][j], under[i + 1][j], under[i + 1][j + 1]))
    # sides
    for i in range(len(ys) - 1):
        bm.faces.new((gridv[i][0], under[i][0], under[i + 1][0], gridv[i + 1][0]))
        bm.faces.new((under[i][-1], gridv[i][-1], gridv[i + 1][-1], under[i + 1][-1]))
    # ends
    for j in range(len(xs) - 1):
        bm.faces.new((gridv[0][j + 1], gridv[0][j], under[0][j], under[0][j + 1]))
        bm.faces.new((gridv[-1][j], gridv[-1][j + 1], under[-1][j + 1], under[-1][j]))
    ramp = obj_from_bm(bm, "RampDeck", stone)
    bevel(ramp, 0.012, 2, 50); apply_all(ramp); smooth(ramp, 35)
    part(P, ramp, ('box', 1.6, None), seed=60, edge=.1, cavity=.14)

    # Ramp side rails (match collision x=±1.56, z 7.4..13.8 godot => blender y -7.4..-13.8).
    for sign in (-1, 1):
        pts = []
        for y in [-(7.4 + i * 0.4) for i in range(0, 17)]:  # to -13.8
            z = ramp_y_to_z(y) + 0.55
            pts.append((sign * 1.56, y, z))
        rail = tube("RampRail", bronze, pts, 0.028, sides=8)
        part(P, rail, ('cyl', (0, 0), 2, 0.4, 0.03), seed=70 + sign, edge=.1)
        # posts every 0.8 m
        for y in [-(7.4 + i * 0.8) for i in range(0, 9)]:
            z0 = ramp_y_to_to_z if False else ramp_y_to_z(y)
            post = box("RampPost", bronze, (sign * 1.56, y, z0 + 0.55), (0.055, 0.055, 1.10), bev=0.006, segs=2)
            part(P, post, ('box', .3, None), seed=80 + int(-y), edge=.12)
            cap = cyl("RampCap", bronze, (sign * 1.56, y, z0 + 1.12), 0.04, 0.03, 10, 0.004)
            part(P, cap, ('cyl', (0, 0), 2, 0.2, 0.04), seed=81)

    # Perimeter bronze rail on the pad, r=7.65, height 1.28..2.35, gap at the ramp (godot +Z / blender -Y).
    # Gap where sin(blender angle) is most negative: a around 3*pi/2, i.e. a in (pi+0.35, 2pi-0.35) wait.
    # blender (x,y) = (godot x, -godot z). Ramp at godot z>0 => blender y<0. Angle atan2(y,x) ≈ -pi/2 ± gap.
    posts = []
    for i in range(32):
        if i in (23, 24):  # same skip as the collision rails
            continue
        a = TAU * i / 32
        # collision uses a = TAU*i/32 with point (cos(a)*7.65, 1.80, -sin(a)*7.65) in GODOT.
        # Godot (x,z) = (cos a * 7.65, -sin a * 7.65); blender (x,y) = (godot x, -godot z) = (cos a * 7.65, sin a * 7.65)
        px, py = math.cos(a) * 7.65, math.sin(a) * 7.65
        posts.append((px, py, a))
        post = box("RailPost", bronze, (px, py, 1.80), (0.07, 0.07, 1.05), bev=0.008, segs=2, rot=(0, 0, a))
        part(P, post, ('box', .25, None), seed=90 + i, edge=.14)
        # kick / top rails as short segments between this and next kept post — handled below
    # Upper and mid rail tubes through kept posts, skipping the gap.
    def rail_ring(z, radius=7.65, skip=None):
        pts = []
        for i in range(32):
            if i in (23, 24):
                if pts:
                    yield pts
                    pts = []
                continue
            a = TAU * i / 32
            pts.append((math.cos(a) * radius, math.sin(a) * radius, z))
        if pts:
            yield pts
    for z in (1.40, 1.85, 2.28):
        for pts in rail_ring(z):
            if len(pts) < 2:
                continue
            rail = tube("PadRail", bronze, pts, 0.026, sides=8)
            part(P, rail, ('cyl', (0, 0), 2, 0.35, 0.03), seed=100 + int(z * 10), edge=.1)

    # Amber beacons on the rail (original r 7.58-7.72, y 2.32-2.46). Skip the ramp gap.
    for i in range(16):
        if i in (11, 12):
            continue
        a = TAU * i / 16
        px, py = math.cos(a) * 7.65, math.sin(a) * 7.65
        base = cyl("BeaconBase", graphite, (px, py, 2.32), 0.055, 0.05, 12, 0.004)
        part(P, base, ('cyl', (0, 0), 2, 0.2, 0.055), seed=110 + i)
        lamp = sphere("BeaconLens", amber, (px, py, 2.40), 0.055, 12, 8)
        part(P, lamp, None, seed=111 + i, edge=0, cavity=0, noise_amt=.02)

    # Four landing-shoe pads on the deck (under the gear). Positions from pad finish contacts.
    for x, z_g in ((-2.58, -1.8), (-2.58, 1.8), (2.82, -1.8), (2.82, 1.8)):
        p = G(x, 1.286, z_g)
        shoe = box("ShoePad", graphite, p, (1.14, 0.69, 0.02), bev=0.01, segs=2)
        part(P, shoe, ('box', .5, None), seed=120, edge=.1, cavity=.1)

    return write("launchpad_pad", P)

# typo guard — ramp_y_to_to_z was referenced in a dead branch; left for readability.

# ================================================================== HULL
def _station(x):
    """half_w, y0, y1 in Godot metres for the fuselage at length x (nose -5.5, tail +4.8)."""
    keys = [
        (-5.55, 0.04, 3.09, 3.13),
        (-5.50, 0.18, 3.00, 3.22),
        (-5.20, 0.48, 2.96, 3.42),
        (-4.80, 0.95, 2.90, 3.62),
        (-4.30, 1.48, 2.85, 3.75),
        (-3.60, 1.90, 2.74, 4.15),
        (-2.50, 2.15, 2.65, 4.40),
        (-1.20, 2.20, 2.64, 4.46),
        ( 0.10, 2.28, 2.63, 4.48),
        ( 1.30, 2.22, 2.65, 4.50),
        ( 2.40, 2.26, 2.70, 4.36),
        ( 3.40, 2.32, 2.80, 4.24),
        ( 4.13, 2.40, 2.76, 4.20),
        ( 4.55, 2.15, 2.88, 4.00),
        ( 4.90, 1.35, 3.00, 3.80),
    ]
    if x <= keys[0][0]:
        return keys[0][1], keys[0][2], keys[0][3]
    if x >= keys[-1][0]:
        return keys[-1][1], keys[-1][2], keys[-1][3]
    for a, b in zip(keys, keys[1:]):
        if a[0] <= x <= b[0]:
            t = (x - a[0]) / (b[0] - a[0])
            s = t * t * (3 - 2 * t)
            return (a[1] + (b[1] - a[1]) * s,
                    a[2] + (b[2] - a[2]) * s,
                    a[3] + (b[3] - a[3]) * s)
    return keys[-1][1], keys[-1][2], keys[-1][3]

def _cross(x, segs=48):
    """Rounded-rect / squircle ring in Godot, returned as Blender verts (x,y,z)."""
    hw, y0, y1 = _station(x)
    cy = (y0 + y1) / 2
    hh = (y1 - y0) / 2
    exp = 0.65  # slightly boxed shuttle section, rounded corners
    pts = []
    for i in range(segs):
        a = TAU * i / segs
        # 0 rad = +Z godot (right), going around
        cz = math.copysign(abs(math.cos(a)) ** exp, math.cos(a))
        cyu = math.copysign(abs(math.sin(a)) ** exp, math.sin(a))
        gz = cz * hw
        gy = cy + cyu * hh
        pts.append(G(x, gy, gz))
    return pts

def build_hull():
    reset(17)
    M = mats_ship(); P = []
    ivory, ochre, alloy, graphite, bronze = M["ivory"], M["ochre"], M["alloy"], M["graphite"], M["bronze"]
    glass, cyan, rubber = M["glass"], M["cyan"], M["rubber"]

    # ---- main fuselage loft, 28 stations x 48 segs
    xs = [ -5.55 + i * (4.90 + 5.55) / 27 for i in range(28) ]
    segs = 48
    bm = bmesh.new()
    rings = []
    for x in xs:
        ring = [bm.verts.new(p) for p in _cross(x, segs)]
        rings.append(ring)
    for i in range(len(rings) - 1):
        for k in range(segs):
            n = (k + 1) % segs
            bm.faces.new((rings[i][k], rings[i][n], rings[i + 1][n], rings[i + 1][k]))
    # nose cap
    tip = bm.verts.new(G(-5.58, 3.11, 0.0))
    for k in range(segs):
        n = (k + 1) % segs
        bm.faces.new((tip, rings[0][n], rings[0][k]))
    # tail cap (slightly inset; engines sit here)
    tail = bm.verts.new(G(4.95, 3.35, 0.0))
    for k in range(segs):
        n = (k + 1) % segs
        bm.faces.new((tail, rings[-1][k], rings[-1][n]))
    hull = obj_from_bm(bm, "Fuselage", ivory)
    # mid-weight bevel so panel edges catch the light
    bevel(hull, 0.018, 2, 35); apply_all(hull); smooth(hull, 28)
    part(P, hull, ('box', 5.5, None), seed=1, edge=.14, cavity=.16, noise_amt=.045)

    # ---- recessed panel plates on the flanks (real secondary forms)
    for xi, x in enumerate([ -4.4, -3.3, -2.2, -1.1, 0.0, 1.1, 2.2, 3.2 ]):
        hw, y0, y1 = _station(x)
        for side in (-1, 1):
            # mid-height flank plate
            z = side * (hw - 0.04)
            cy = (y0 + y1) * 0.5
            # plate size varies
            sx, sy = 0.92, 0.72 + 0.08 * (xi % 3)
            # rotate so the plate is tangent: facing ±Z godot => Blender ±Y, so rot around Z? 
            # Godot plate faces ±Z: normal is (0,0,side). Blender normal = (0, -side, 0) i.e. along ±Y.
            # A box's thin axis is Z in local (we use size z as thickness). Default box faces Z.
            # Rotate to face ±Y: rot x=0,y=0,z = ±pi/2
            pl = box("HullPanel", ivory, G(x, cy, z), (sx, sy, 0.045), bev=0.012, segs=2,
                     rot=(0, 0, -side * math.pi / 2))
            part(P, pl, ('box', .7, None), seed=200 + xi * 2 + (side > 0), edge=.18, cavity=.12)
            # rivet row along the long edges
            for dx in (-0.38, -0.13, 0.13, 0.38):
                for dy in (-sy / 2 + 0.06, sy / 2 - 0.06):
                    rv = cyl("Rivet", graphite, G(x + dx, cy + dy, z + side * 0.028), 0.012, 0.012, 8, 0.002,
                             rot=(math.pi / 2, 0, 0) if side > 0 else (-math.pi / 2, 0, 0))
                    # wait: rivet should stick out along ±Z godot = ∓Y blender. cyl default is Z-up.
                    # rot (pi/2, 0, 0) aims the axis along -Y? rotate X 90: Z -> -Y. Yes for side=+1 if we want -Y... 
                    # Godot +Z is Blender -Y. side=+1 is +Z godot = -Y blender. Axis should be (0,-1,0) blender.
                    part(P, rv, ('cyl', (0, 0), 2, 0.08, 0.012), seed=210, edge=.05, cavity=0)

    # Belly and spine longerons
    for z_off, y_frac in ((0.0, 0.08), (0.0, 0.92)):
        pts = []
        for x in xs[2:-2]:
            hw, y0, y1 = _station(x)
            y = y0 + (y1 - y0) * y_frac
            pts.append(G(x, y, 0.0 if abs(y_frac - 0.5) > 0.2 else 0.0))
        # push off the surface a hair
        if y_frac < 0.5:
            pts = [G(xs[i+2], _station(xs[i+2])[1] - 0.02, 0) for i in range(len(xs) - 4)]
        else:
            pts = [G(xs[i+2], _station(xs[i+2])[2] + 0.02, 0) for i in range(len(xs) - 4)]
        rail = tube("Longeron", graphite, pts, 0.03, sides=6)
        part(P, rail, ('cyl', (0, 0), 2, 0.5, 0.03), seed=250, edge=.1)

    # Ochre livery bands along the chine (both sides)
    for side in (-1, 1):
        pts = []
        for x in xs[3:-3]:
            hw, y0, y1 = _station(x)
            y = y0 + (y1 - y0) * 0.35
            pts.append(G(x, y, side * (hw + 0.02)))
        band = sweep_rect("Livery", ochre, pts, 0.22, 0.05, bev=0.006)
        part(P, band, ('box', .6, None), seed=260 + (side > 0), edge=.12, cavity=.1)
        # a second thinner stripe
        pts2 = []
        for x in xs[4:-4]:
            hw, y0, y1 = _station(x)
            y = y0 + (y1 - y0) * 0.55
            pts2.append(G(x, y, side * (hw + 0.018)))
        band2 = sweep_rect("LiveryThin", ochre, pts2, 0.08, 0.03, bev=0.004)
        part(P, band2, ('box', .4, None), seed=270, edge=.1)

    # ---- cockpit canopy (Godot x -4.15..-1.30, y 3.63..4.49, z ±1.86)
    # Frame first, then glass.
    # Canopy sits on the upper nose. Build a slightly domed glass and a graphite frame.
    cxs = [-4.10, -3.40, -2.60, -1.85, -1.35]
    csegs = 16
    bm = bmesh.new()
    crings = []
    for i, x in enumerate(cxs):
        hw, y0, y1 = _station(x)
        # canopy half-width tapers
        t = i / (len(cxs) - 1)
        chw = 1.15 + 0.55 * math.sin(t * math.pi)  # bulge in the middle, ~1.7
        chw = min(chw, hw - 0.08)
        y_base = y1 - 0.05
        y_top = 4.48 - 0.12 * abs(x + 2.6) / 1.5
        ring = []
        for k in range(csegs + 1):  # 0..csegs inclusive: a = 0..pi (upper half only, in godot Z)
            a = math.pi * k / csegs  # 0 = +Z, pi = -Z
            gz = math.cos(a) * chw
            gy = y_base + math.sin(a) * (y_top - y_base)
            ring.append(bm.verts.new(G(x, gy, gz)))
        crings.append(ring)
    for i in range(len(crings) - 1):
        for k in range(csegs):
            bm.faces.new((crings[i][k], crings[i][k + 1], crings[i + 1][k + 1], crings[i + 1][k]))
    # close the front and back with a mid point? leave open at the hull join — add front/back caps
    for ring, flip in ((crings[0], True), (crings[-1], False)):
        # fan to a center on the hull roof
        mid = Vector((0, 0, 0))
        for v in ring:
            mid += v.co
        mid /= len(ring)
        mid.z -= 0.04  # pull slightly down (blender Z = up)
        c = bm.verts.new(mid)
        for k in range(csegs):
            if flip:
                bm.faces.new((c, ring[k + 1], ring[k]))
            else:
                bm.faces.new((c, ring[k], ring[k + 1]))
    can = obj_from_bm(bm, "CanopyGlass", glass)
    apply_all(can); smooth(can, 25)
    part(P, can, ('box', 1.2, None), seed=300, edge=0, cavity=.06, noise_amt=.02)

    # Canopy frame ribs
    for x in cxs:
        hw, y0, y1 = _station(x)
        chw = min(1.15 + 0.55 * math.sin(((x + 4.10) / 2.75) * math.pi), hw - 0.08)
        y_base = y1 - 0.05
        y_top = 4.48 - 0.12 * abs(x + 2.6) / 1.5
        pts = [G(x, y_base + math.sin(math.pi * k / 12) * (y_top - y_base), math.cos(math.pi * k / 12) * chw) for k in range(13)]
        rib = tube("CanopyRib", graphite, pts, 0.022, sides=6)
        part(P, rib, ('cyl', (0, 0), 2, 0.3, 0.022), seed=310, edge=.08)
    # sills along the sides
    for side in (-1, 1):
        pts = []
        for x in cxs:
            hw, y0, y1 = _station(x)
            chw = min(1.15 + 0.55 * math.sin(((x + 4.10) / 2.75) * math.pi), hw - 0.08)
            pts.append(G(x, y1 - 0.04, side * chw))
        sill = tube("CanopySill", graphite, pts, 0.028, sides=6)
        part(P, sill, ('cyl', (0, 0), 2, 0.4, 0.028), seed=320, edge=.08)

    # ---- boarding door on the +Z (ramp-facing) side, around x=-0.2
    # Godot +Z = blender -Y
    hw, y0, y1 = _station(-0.2)
    door_c = G(-0.2, 3.35, hw - 0.02)
    door = box("Door", ivory, door_c, (0.95, 1.15, 0.05), bev=0.02, segs=2, rot=(0, 0, math.pi / 2))
    part(P, door, ('box', .5, None), seed=330, edge=.16, cavity=.14)
    frame = box("DoorFrame", graphite, door_c + Vector((0, 0.0, 0)), (1.08, 1.28, 0.04), bev=0.01, segs=2, rot=(0, 0, math.pi / 2))
    # offset frame slightly out
    # actually rebuild with a slight outward nudge along -Y blender
    # leave as is; add a handle
    handle = cyl("DoorHandle", bronze, G(-0.55, 3.35, hw + 0.04), 0.018, 0.12, 10, 0.003, rot=(0, math.pi / 2, 0))
    part(P, frame, ('box', .4, None), seed=331, edge=.12)
    part(P, handle, ('cyl', (0, 0), 1, 0.15, 0.02), seed=332)

    # ---- vents / greebles on the rear flanks
    for side in (-1, 1):
        for i, x in enumerate((3.0, 3.35, 3.70)):
            hw, y0, y1 = _station(x)
            v = box("Vent", alloy, G(x, 3.15, side * (hw + 0.03)), (0.28, 0.22, 0.06), bev=0.008, segs=2,
                    rot=(0, 0, -side * math.pi / 2))
            part(P, v, ('box', .3, None), seed=340 + i, edge=.1, cavity=.2)
            # slats
            for k in range(3):
                sl = box("VentSlat", graphite, G(x - 0.08 + k * 0.08, 3.15, side * (hw + 0.055)),
                         (0.03, 0.18, 0.012), bev=0.002, segs=1, rot=(0, 0, -side * math.pi / 2))
                part(P, sl, ('box', .2, None), seed=345, edge=0, cavity=.05)

    # Antenna / sensor mast on the spine
    mast = cyl("Mast", graphite, G(1.6, 4.72, 0.0), 0.025, 0.48, 10, 0.003)
    part(P, mast, ('cyl', (0, 0), 2, 0.2, 0.025), seed=350)
    dish = cyl("Sensor", alloy, G(1.6, 4.98, 0.0), 0.09, 0.04, 16, 0.006, r2=0.02)
    part(P, dish, ('cyl', (0, 0), 2, 0.15, 0.09), seed=351)
    # nav lights
    for pos, col in ((G(-5.35, 3.22, 0.0), cyan), (G(4.70, 5.50, 2.20), cyan), (G(4.70, 5.50, -2.20), cyan)):
        lamp = sphere("NavLight", col, pos, 0.045, 10, 7)
        part(P, lamp, None, seed=360, edge=0, cavity=0, noise_amt=.02)

    # Cyan marker strip on the spine (original cyan markers around y=3.87, z±1.58, x -0.9..0.2)
    # Those look like formation lights on the sides, mid body.
    for side in (-1, 1):
        hw, y0, y1 = _station(-0.3)
        light = box("FormationLight", cyan, G(-0.3, 3.87, side * (hw + 0.03)), (0.55, 0.06, 0.04), bev=0.008, segs=2,
                    rot=(0, 0, -side * math.pi / 2))
        part(P, light, ('box', .3, None), seed=370, edge=0, cavity=0)

    # ---- twin engines at Godot (4.76, 3.08, ±2.15), opening toward +X (rear)
    for side in (-1, 1):
        c = G(4.76, 3.08, side * 2.15)
        # housing / shroud
        shroud = cyl("EngineShroud", alloy, c, 0.62, 0.85, 32, 0.02, rot=(0, math.pi / 2, 0))
        # default cyl axis is Z; rot Y 90: axis -> X. Center is mid of the cylinder.
        # We want the bell opening at x≈4.95 (rear) and the attach at x≈4.4.
        # Move: blender X is godot X. Cyl along X, length 0.85, so it spans 4.76±0.425.
        part(P, shroud, ('cyl', (0, 0), 0, 0.6, 0.62), seed=400, edge=.12, cavity=.18)
        # inner bell (wider at the rear)
        bell = cyl("EngineBell", graphite, G(5.05, 3.08, side * 2.15), 0.50, 0.55, 28, 0.012,
                   rot=(0, math.pi / 2, 0), r2=0.28)
        # r1 at +X side after rot? create_cone radius1 at -Z, radius2 at +Z, then rot Y 90:
        # -Z -> -X, +Z -> +X. So r2=0.28 at the rear (+X) would be the small end — we want the opposite.
        # Swap: r1=0.28 (front/-X after rot? wait -Z after rot Y90 is -X which is toward the nose).
        # rot Y +90: X' = Z, Z' = -X. Hmm let me think...
        # I'll just add a second wider lip at the rear.
        part(P, bell, ('cyl', (0, 0), 0, 0.5, 0.5), seed=401, edge=.1, cavity=.2)
        lip = cyl("EngineLip", alloy, G(5.28, 3.08, side * 2.15), 0.58, 0.08, 28, 0.01, rot=(0, math.pi / 2, 0))
        part(P, lip, ('cyl', (0, 0), 0, 0.3, 0.58), seed=402, edge=.14)
        # inner core
        core = cyl("EngineCore", graphite, G(4.70, 3.08, side * 2.15), 0.18, 0.7, 16, 0.006, rot=(0, math.pi / 2, 0))
        part(P, core, ('cyl', (0, 0), 0, 0.3, 0.18), seed=403)
        # petal / flange bolts
        for k in range(10):
            a = TAU * k / 10
            # around the shroud, in the YZ blender plane at this engine (blender y = -godot z)
            # center blender = G(4.76, 3.08, side*2.15) = (4.76, -side*2.15, 3.08)
            cb = G(4.76, 3.08, side * 2.15)
            off = Vector((0, math.cos(a) * 0.62, math.sin(a) * 0.62))
            bolt = cyl("EngineBolt", bronze, cb + off, 0.025, 0.06, 8, 0.002, rot=(0, math.pi / 2, 0))
            part(P, bolt, ('cyl', (0, 0), 0, 0.1, 0.025), seed=410 + k, edge=.05)
        # heat-stain ochre ring
        ring = cyl("HeatRing", ochre, G(4.55, 3.08, side * 2.15), 0.66, 0.10, 24, 0.008, rot=(0, math.pi / 2, 0))
        part(P, ring, ('cyl', (0, 0), 0, 0.3, 0.66), seed=420, edge=.08)

    # ---- twin vertical tails above the engines (x 4.1..4.8, y up to 5.65, z ±2.25)
    for side in (-1, 1):
        # fin as a tapered box, bevelled, slightly swept
        # root at y=4.20, tip at y=5.65, chord 0.9 at root, 0.45 at tip, thickness 0.08..0.05
        # use a simple lofted fin
        bm = bmesh.new()
        def fin_pt(x, y, thick):
            return bm.verts.new(G(x, y, side * 2.22 + thick))
        # 4-corner each side: root front, root back, tip front, tip back
        # Root the fin on the nacelle (engine at y=3.08, shroud r≈0.62, top ≈3.70)
        # so the tails do not hover in a gap above the engines.
        rf = fin_pt(4.12, 3.72, 0.07); rb = fin_pt(4.92, 3.76, 0.07)
        tf = fin_pt(4.35, 5.65, 0.03); tb = fin_pt(4.82, 5.62, 0.03)
        lf = fin_pt(4.12, 3.72, -0.07); lb = fin_pt(4.92, 3.76, -0.07)
        sf = fin_pt(4.35, 5.65, -0.03); sb = fin_pt(4.82, 5.62, -0.03)
        bm.faces.new((rf, rb, tb, tf))
        bm.faces.new((lf, sf, sb, lb))
        bm.faces.new((rf, tf, sf, lf))
        bm.faces.new((rb, lb, sb, tb))
        bm.faces.new((tf, tb, sb, sf))
        bm.faces.new((rf, lf, lb, rb))
        fin = obj_from_bm(bm, "TailFin", ivory)
        bevel(fin, 0.016, 2, 30); apply_all(fin); smooth(fin, 30)
        part(P, fin, ('box', .8, None), seed=430 + (side > 0), edge=.15, cavity=.12)
        # ochre tip
        tip = box("FinTip", ochre, G(4.62, 5.55, side * 2.22), (0.42, 0.18, 0.07), bev=0.01, segs=2)
        part(P, tip, ('box', .3, None), seed=435, edge=.1)
        fair = box("FinFairing", ivory, G(4.52, 3.78, side * 2.18), (0.70, 0.22, 0.16), bev=0.03, segs=2)
        part(P, fair, ('box', .6, None), seed=436 + (side > 0), edge=.12, cavity=.1)

    # modest wing / chine flares near x=0.85 and a smaller one aft at x=3.6, halfw 3.8
    for x0, chord, drop in ((0.90, 1.8, 0.15), (3.55, 1.3, 0.10)):
        for side in (-1, 1):
            hw, y0, y1 = _station(x0)
            # wing: from body side out to z=±3.75, thickness 0.14, y around 3.1
            root_z = hw - 0.05
            tip_z = 3.78
            y = 3.05
            bm = bmesh.new()
            def wp(x, y, z):
                return bm.verts.new(G(x, y, z))
            # root front/back top/bot, tip front/back top/bot
            hf, hb = chord * 0.45, chord * 0.55
            verts = [
                wp(x0 - hf, y + 0.08, side * root_z), wp(x0 + hb, y + 0.07, side * root_z),
                wp(x0 + hb, y - 0.07, side * root_z), wp(x0 - hf, y - 0.07, side * root_z),
                wp(x0 - hf * 0.4, y + 0.04, side * tip_z), wp(x0 + hb * 0.55, y + 0.03, side * tip_z),
                wp(x0 + hb * 0.55, y - 0.03, side * tip_z), wp(x0 - hf * 0.4, y - 0.03, side * tip_z),
            ]
            rft, rbt, rbb, rfb, tft, tbt, tbb, tfb = verts
            bm.faces.new((rft, rbt, tbt, tft))
            bm.faces.new((rfb, tfb, tbb, rbb))
            bm.faces.new((rft, tft, tfb, rfb))
            bm.faces.new((rbt, rbb, tbb, tbt))
            bm.faces.new((tft, tbt, tbb, tfb))
            bm.faces.new((rft, rfb, rbb, rbt))
            wing = obj_from_bm(bm, "Chine", ivory)
            bevel(wing, 0.02, 2, 30); apply_all(wing); smooth(wing, 28)
            part(P, wing, ('box', 1.0, None), seed=440, edge=.14, cavity=.12)
            # ochre leading edge
            # skip; the livery bands already read

    # ---- landing gear (4 shoes). Contacts at x in [-2.58, 2.82], z in [-1.8, 1.8], deck y=1.285
    # Gear hangs from the belly (y0 ~ 2.65) down to y=1.47 (shoe).
    for gx, gz in ((-2.58, -1.8), (-2.58, 1.8), (2.82, -1.8), (2.82, 1.8)):
        hw, y0, y1 = _station(gx)
        # strut from belly to shoe
        top = G(gx, y0 - 0.02, gz)
        shoe_p = G(gx, 1.52, gz)
        direction = shoe_p - top
        mid = (top + shoe_p) / 2
        quat = direction.to_track_quat('Z', 'Y')
        def oriented_cyl(name, material, center, r, h, segs=12, bev=0.008):
            # Build at the origin, then rotate/translate once so apply_all does not
            # spin an already-applied mesh around the world origin.
            bm = bmesh.new()
            bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=segs, radius1=r, radius2=r, depth=h)
            ob = obj_from_bm(bm, name, material)
            ob.rotation_euler = quat.to_euler()
            ob.location = center
            if bev > 0:
                bevel(ob, bev, 2)
            apply_all(ob); smooth(ob)
            return ob
        strut = oriented_cyl("GearStrut", alloy, mid, 0.07, direction.length)
        part(P, strut, ('cyl', (0, 0), 2, 0.3, 0.07), seed=450, edge=.1, cavity=.1)
        oleo = oriented_cyl("Oleo", graphite, mid + direction * 0.15, 0.095, direction.length * 0.35)
        part(P, oleo, ('cyl', (0, 0), 2, 0.25, 0.095), seed=451, edge=.1)
        # foot / shoe
        shoe = box("GearShoe", graphite, shoe_p, (0.55, 0.38, 0.10), bev=0.02, segs=2)
        part(P, shoe, ('box', .4, None), seed=452, edge=.12, cavity=.1)
        pad = box("GearPad", rubber, shoe_p + Vector((0, 0, -0.06)), (0.50, 0.34, 0.04), bev=0.01, segs=1)
        part(P, pad, ('box', .3, None), seed=453, edge=0, cavity=.05)
        # scissors link
        sc = box("GearScissor", alloy, mid + Vector((0.12, 0, 0)), (0.18, 0.05, 0.28), bev=0.008, segs=2)
        part(P, sc, ('box', .25, None), seed=454, edge=.08)

    # Belly access panels (alloy)
    for x in (-1.6, 0.8, 2.6):
        hw, y0, y1 = _station(x)
        pan = box("BellyPanel", alloy, G(x, y0 - 0.02, 0.0), (0.85, 0.05, 0.70), bev=0.012, segs=2)
        part(P, pan, ('box', .5, None), seed=460, edge=.12, cavity=.14)

    return write("launchpad_hull", P)


# ================================================================== REQUEST BOARD
def build_board():
    reset(18)
    M = mats_board(); P = []
    oak, walnut, bronze, paper = M["oak"], M["walnut"], M["bronze"], M["paper"]
    ink, wax, cream, iron = M["ink"], M["wax"], M["cream"], M["iron"]

    # Posts at x=±0.70, from y=0 to ~1.7, original 0.12 x 1.6 x 0.20. Tapered, bevelled, with feet.
    for side in (-1, 1):
        x = side * 0.70
        # foot plate
        foot = box("PostFoot", iron, (x, 0, 0.04), (0.28, 0.22, 0.06), bev=0.01, segs=2)
        # wait: board is in Godot; posts along Y up, face +Z. In Blender Z-up, face -Y, so:
        # Godot (x, y, z) -> Blender (x, -z, y)
        # I'll build the board in Blender directly with Z up, Y front negative, matching export.
        # Post at godot (x, 0.8, 0) size (0.12, 1.6, 0.20) -> blender center (x, 0, 0.8), size (0.12, 0.20, 1.6)
        pass
    # Restart posts correctly in Blender space.
    P.clear()
    # After reset the materials still exist. Rebuild parts list only — objects from the loop above remain.
    # Clean those two foot boxes if created. Safer to reset fully.
    reset(18)
    M = mats_board(); P = []
    oak, walnut, bronze, paper = M["oak"], M["walnut"], M["bronze"], M["paper"]
    ink, wax, cream, iron = M["ink"], M["wax"], M["cream"], M["iron"]

    def BG(x, y, z):
        return (x, -z, y)

    for side in (-1, 1):
        x = side * 0.70
        foot = box("PostFoot", iron, BG(x, 0.03, 0.0), (0.30, 0.26, 0.06), bev=0.01, segs=2)
        part(P, foot, ('box', .4, None), seed=1, edge=.12)
        # post slightly thicker than the original 0.12 x 0.20, chamfered
        post = box("Post", oak, BG(x, 0.82, 0.0), (0.15, 0.22, 1.64), bev=0.018, segs=3)
        part(P, post, ('box', 0.35, 'z'), seed=2 + side, edge=.14, cavity=.12)
        cap = box("PostCap", bronze, BG(x, 1.66, 0.0), (0.18, 0.24, 0.06), bev=0.008, segs=2)
        part(P, cap, ('box', .25, None), seed=4, edge=.15)
        # lag bolts
        for y in (0.25, 1.05, 1.50):
            bolt = cyl("PostBolt", bronze, BG(x, y, 0.12), 0.016, 0.03, 8, 0.002, rot=(math.pi / 2, 0, 0))
            part(P, bolt, ('cyl', (0, 0), 2, 0.1, 0.016), seed=5, edge=.05)

    # Main panel: original 1.8 x 1.5 x 0.15 at (0, 1.35, 0). Backing + moulded frame.
    back = box("BoardBack", walnut, BG(0, 1.35, -0.02), (1.84, 0.12, 1.54), bev=0.012, segs=2)
    part(P, back, ('box', 0.55, 'x'), seed=10, edge=.1, cavity=.12)
    # front planks (three horizontal courses) — more wooden than a single slab
    for i, y in enumerate((0.92, 1.35, 1.78)):
        plank = box("BoardPlank", oak, BG(0, y, 0.045), (1.72, 0.055, 0.42), bev=0.008, segs=2)
        part(P, plank, ('box', 0.45, 'x'), seed=11 + i, edge=.12, cavity=.1)
    # moulded frame
    # top, bottom, left, right
    frame_specs = [
        ("FrameTop", BG(0, 2.08, 0.06), (1.88, 0.10, 0.10)),
        ("FrameBot", BG(0, 0.62, 0.06), (1.88, 0.10, 0.10)),
        ("FrameL", BG(-0.89, 1.35, 0.06), (0.10, 0.10, 1.56)),
        ("FrameR", BG(0.89, 1.35, 0.06), (0.10, 0.10, 1.56)),
    ]
    for name, c, s in frame_specs:
        fr = box(name, oak, c, s, bev=0.014, segs=3)
        part(P, fr, ('box', 0.4, None), seed=20, edge=.16, cavity=.1)
    # inner bronze bead
    bead_specs = [
        BG(0, 2.00, 0.10), BG(0, 0.70, 0.10)
    ]
    for i, c in enumerate(bead_specs):
        bead = box("FrameBead", bronze, c, (1.68, 0.025, 0.025), bev=0.004, segs=1)
        part(P, bead, ('box', .2, None), seed=21, edge=.1)
    for x in (-0.81, 0.81):
        bead = box("FrameBeadV", bronze, BG(x, 1.35, 0.10), (0.025, 0.025, 1.28), bev=0.004, segs=1)
        part(P, bead, ('box', .2, None), seed=22, edge=.1)

    # Small roof cap / drip edge
    cap = box("DripCap", oak, BG(0, 2.16, 0.02), (1.98, 0.18, 0.07), bev=0.012, segs=2)
    part(P, cap, ('box', 0.5, None), seed=25, edge=.14)
    capb = box("DripCapBronze", bronze, BG(0, 2.20, 0.08), (2.02, 0.06, 0.025), bev=0.006, segs=2)
    part(P, capb, ('box', .25, None), seed=26, edge=.12)

    # Header plaque: "REQUESTS" — timber plaque with bronze edge, 3D lettering.
    # Original header at (0, 1.83, 0.125), size ~1.65 x 0.38
    plaque = box("HeaderPlaque", walnut, BG(0, 1.92, 0.11), (1.62, 0.06, 0.36), bev=0.012, segs=2)
    part(P, plaque, ('box', 0.5, 'x'), seed=30, edge=.12, cavity=.1)
    # bronze surround
    for name, c, s in (
        ("HdrTop", BG(0, 2.10, 0.13), (1.68, 0.04, 0.04)),
        ("HdrBot", BG(0, 1.74, 0.13), (1.68, 0.04, 0.04)),
        ("HdrL", BG(-0.82, 1.92, 0.13), (0.04, 0.04, 0.36)),
        ("HdrR", BG(0.82, 1.92, 0.13), (0.04, 0.04, 0.36)),
    ):
        b = box(name, bronze, c, s, bev=0.006, segs=2)
        part(P, b, ('box', .2, None), seed=31, edge=.12)
    # corner rivets
    for x in (-0.80, 0.80):
        for y in (1.76, 2.08):
            riv = cyl("HdrRivet", cream, BG(x, y, 0.155), 0.018, 0.016, 10, 0.002, rot=(math.pi / 2, 0, 0))
            part(P, riv, ('cyl', (0, 0), 2, 0.1, 0.018), seed=32, edge=.08)

    # 3D "REQUESTS" lettering
    font_path = "/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf"
    bpy.ops.object.text_add(location=BG(0, 1.92, 0.155))
    txt = bpy.context.active_object
    txt.data.body = "REQUESTS"
    txt.data.font = bpy.data.fonts.load(font_path)
    txt.data.extrude = 0.012
    txt.data.bevel_depth = 0.0018
    txt.data.bevel_resolution = 2
    txt.data.size = 0.20
    txt.data.align_x = 'CENTER'
    txt.data.align_y = 'CENTER'
    txt.data.materials.append(cream)
    # Face +Z godot = -Y blender: rotate the text (default faces +X? actually text faces +Y in Blender by default? )
    # Blender text is in XY plane, facing +Z. We need it in XZ plane facing -Y (front).
    # rotate X by +90: Y -> -Z? rot X 90: (x,y,z)->(x,-z,y) so the XY glyph ends up on XZ facing -Y. Yes.
    txt.rotation_euler = (math.pi / 2, 0, 0)
    select_only(txt)
    bpy.ops.object.convert(target='MESH')
    txt = bpy.context.active_object
    txt.name = "RequestsLettering"
    if not txt.data.materials:
        txt.data.materials.append(cream)
    else:
        txt.data.materials[0] = cream
    apply_all(txt); smooth(txt, 30)
    part(P, txt, ('box', 0.3, None), seed=40, edge=.18, cavity=.08, noise_amt=.02)

    # Three curled notices. Original at x = -0.51, 0, 0.51, y=1.18, z=0.125, size ~0.42 x 0.62
    rng = random.Random(18)
    for i, x in enumerate((-0.51, 0.00, 0.51)):
        rot_z = [0.04, -0.035, 0.025][i]
        # paper as a curled grid (solid, thin)
        bm = bmesh.new()
        nx, ny = 10, 14
        w, h, t = 0.42, 0.62, 0.012
        curl = 0.035 + 0.01 * (i - 1)
        # bottom corners curl toward the viewer? actually papers curl at corners off the board (toward +Z godot = -Y blender)
        def paper_pt(u, v, side):
            # u,v in [0,1], origin center
            px = (u - 0.5) * w
            py = (v - 0.5) * h
            # curl amount grows toward the bottom corners
            edge = (abs(u - 0.5) * 2) ** 2 * ((1 - v) ** 1.4)
            pz = side * t / 2 + edge * curl
            # slight overall wave
            pz += 0.008 * math.sin(u * math.pi) * math.sin(v * math.pi * 1.2)
            return Vector((px, pz, py))
        # We'll place this local mesh at the notice origin and rotate.
        front = [[bm.verts.new(paper_pt(i_ / (nx - 1), j / (ny - 1), 1)) for i_ in range(nx)] for j in range(ny)]
        back = [[bm.verts.new(paper_pt(i_ / (nx - 1), j / (ny - 1), -1)) for i_ in range(nx)] for j in range(ny)]
        for j in range(ny - 1):
            for i_ in range(nx - 1):
                bm.faces.new((front[j][i_], front[j][i_ + 1], front[j + 1][i_ + 1], front[j + 1][i_]))
                bm.faces.new((back[j][i_ + 1], back[j][i_], back[j + 1][i_], back[j + 1][i_ + 1]))
        for j in range(ny - 1):
            bm.faces.new((front[j][0], front[j + 1][0], back[j + 1][0], back[j][0]))
            bm.faces.new((front[j + 1][-1], front[j][-1], back[j][-1], back[j + 1][-1]))
        for i_ in range(nx - 1):
            bm.faces.new((front[0][i_ + 1], front[0][i_], back[0][i_], back[0][i_ + 1]))
            bm.faces.new((front[-1][i_], front[-1][i_ + 1], back[-1][i_ + 1], back[-1][i_]))
        sheet = obj_from_bm(bm, f"Notice{i}", paper)
        # local mesh is already in a frame where +Y is thickness (front), +Z is up the page, +X is right.
        # We want: board face +Z godot = -Y blender (front), up = +Z blender.
        # Local (px, pz_thick, py_up) -- I used Vector((px, pz, py)) with pz = thickness.
        # So local X = right, Y = toward camera (board front, -Y world if we don't rotate?), Z = up.
        # If I just translate to BG(x, 1.18, 0.145) without rotation, local Y (front) is world +Y, but we need world -Y.
        # Rotate 180 around Z: (x,y,z)->(-x,-y,z). Then local front +Y becomes -Y. Good. Also flips X, so letters/pin stay ok if we account for it.
        sheet.rotation_euler = (0, 0, math.pi + rot_z)
        sheet.location = Vector(BG(x, 1.18, 0.145))
        apply_all(sheet); smooth(sheet, 40)
        part(P, sheet, ('box', 0.55, None), seed=50 + i, edge=.06, cavity=.08, noise_amt=.04)
        # ink lines
        for line in range(5):
            ly = 0.18 - line * 0.075
            lw = 0.27 if line < 4 else 0.16
            ln = box("InkLine", ink, BG(x - 0.02, 1.18 + ly, 0.165), (lw, 0.010, 0.012), bev=0.002, segs=1,
                     rot=(0, 0, rot_z))
            part(P, ln, ('box', .2, None), seed=60, edge=0, cavity=0, noise_amt=.02)
        # pin at the top
        pin = cyl("Pin", bronze, BG(x, 1.18 + 0.26, 0.175), 0.016, 0.03, 10, 0.002, rot=(math.pi / 2, 0, 0))
        part(P, pin, ('cyl', (0, 0), 2, 0.1, 0.016), seed=61, edge=.1)
        head = sphere("PinHead", bronze, BG(x, 1.18 + 0.26, 0.192), 0.018, 10, 7)
        part(P, head, None, seed=62, edge=.08, cavity=0)
        # wax seal lower right
        seal = cyl("Wax", wax, BG(x + 0.10, 1.18 - 0.20, 0.172), 0.038, 0.012, 16, 0.003, rot=(math.pi / 2, 0, 0))
        part(P, seal, ('cyl', (0, 0), 2, 0.15, 0.038), seed=63 + i, edge=.1, cavity=.15)

    # Small iron hooks under the board
    for x in (-0.45, 0.45):
        hook = tube("Hook", iron, [BG(x, 0.58, 0.08), BG(x, 0.50, 0.08), BG(x, 0.46, 0.14)], 0.008, sides=6)
        part(P, hook, ('cyl', (0, 0), 2, 0.1, 0.008), seed=70, edge=.08)

    return write("request_board", P)


# ================================================================== main
if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else ["pad", "hull", "board"]
    if not argv:
        argv = ["pad", "hull", "board"]
    builders = {"pad": build_pad, "hull": build_hull, "board": build_board}
    for key in argv:
        if key not in builders:
            raise SystemExit("unknown target %s (pad|hull|board)" % key)
        print("BUILDING", key)
        builders[key]()
    print("ROLLOUT2_REPORT", REPORT)
