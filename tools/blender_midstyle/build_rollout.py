# Item 12 rollout of the item 11 pass 3 mid-stylized look to the raid props:
#   relay lever (weather station), loot caches, cargo containers, cargo stacks and pallets.
# Reuses the pass 3 helpers in build_midstyle.py (bevelled parts, painted vertex colour,
# box/cylinder UVs, one surface per material). Blender 4.2, meter scale, Z-up, front = -Y
# (the glTF exporter turns that into Godot Y-up with the front on +Z, same as the originals).
# Each prop keeps the original's node names, pivots and outer bounds so the gameplay scripts
# (puzzle_controls.gd, raid_props.gd, cargo_scenery.gd) drive it unchanged.
#   python3 tools/blender_midstyle/make_textures_rollout.py /workspace/settlement_rollout/tex
#   blender -b --factory-startup -P tools/blender_midstyle/build_rollout.py -- [relay] [cache] [container] [stack]
import bpy, bmesh, math, random, os, sys
from mathutils import Vector, Matrix, noise
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_midstyle as B
from build_midstyle import mat, box, cyl, sphere, lathe, tube, sweep_rect, finish, paint, uv_box, uv_cyl, uv_rect, join, obj_from_bm, apply_all, smooth, select_only, fixn, xform
REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
OUT = os.path.join(REPO, "assets", "midstyle_rollout") + "/"
B.TEX = os.environ.get("ROLLOUT_TEX", "/workspace/settlement_rollout/tex/")
BLEND = "/workspace/settlement_rollout/blender/"
TAU = 2 * math.pi
REPORT = {}

def reset(seed=12):
    B.reset(); random.seed(seed)

# ------------------------------------------------------------------ decals
ST_ATLAS = ["relay", "wx", "danger", "supply_w", "supply_s", "cargo_id", "plate", "fragile",
            "arrows", "fuel", "water", "kraft_label", "stack_id", "barcode", "class", "blank"]
def decal(name, material, key, center, normal, w, h, up=(0, 0, 1), off=.0012):
    """One quad (2 triangles) showing a cell of stencil_atlas.png, lifted off the surface."""
    n = Vector(normal).normalized(); upv = Vector(up)
    if abs(n.dot(upv)) > .9: upv = Vector((0, 1, 0)) if abs(n.y) < .9 else Vector((1, 0, 0))
    u = upv.cross(n).normalized() * -1; v = n.cross(u).normalized() * -1
    if u.cross(v).dot(n) < 0: u = -u
    c = Vector(center) + n * off; bm = bmesh.new(); uvl = bm.loops.layers.uv.verify()
    vs = [bm.verts.new(c + u * sx * w / 2 + v * sy * h / 2) for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    f = bm.faces.new(vs)
    i = ST_ATLAS.index(key); col, row = i % 2, i // 2
    for l, (uu, vv) in zip(f.loops, ((0, 0), (1, 0), (1, 1), (0, 1))):
        l[uvl].uv = ((col + uu) / 2, 1 - (row + 1) / 8 + vv / 8)
    ob = obj_from_bm(bm, name, material); paint(ob, .96, 1.0, edge=0, cavity=0, noise_amt=.03)
    return ob

def part(parts, ob, uv=('box', .5, None), **pk):
    pk.setdefault("seed", len(parts) * 1.3); finish(ob, uv, **pk); parts.append(ob); return ob

def tris_of(obs):
    t = 0
    for o in obs:
        o.data.calc_loop_triangles(); t += len(o.data.loop_triangles)
    return t

def root_empty(name):
    e = bpy.data.objects.new(name, None); bpy.context.collection.objects.link(e); return e

def node(objs, name, parent, pivot=(0, 0, 0)):
    if os.environ.get("MIDSTYLE_BREAKDOWN"):
        agg = {}
        for o in objs:
            o.data.calc_loop_triangles(); k = o.name.split('.')[0]; agg[k] = agg.get(k, 0) + len(o.data.loop_triangles)
        print("BREAKDOWN", name, sorted(agg.items(), key=lambda kv: -kv[1]))
    ob = join(objs, name)
    if Vector(pivot).length > 0:
        ob.data.transform(Matrix.Translation(-Vector(pivot))); ob.location = pivot
    ob.parent = parent
    return ob

def write(path, nodes):
    tri = tris_of(nodes); REPORT[path] = tri
    print("ROLLOUT_TRIS", path, tri, "MATERIALS", sorted({m.name for o in nodes for m in o.data.materials}))
    B.export(OUT + path + ".gltf")
    bpy.ops.wm.save_as_mainfile(filepath=BLEND + path + ".blend")

def bolt(name, material, c, axis='-y', r=.012, h=.008, segs=6):
    rot = {'-y': (math.pi / 2, 0, 0), 'y': (math.pi / 2, 0, 0), 'x': (0, math.pi / 2, 0), '-x': (0, math.pi / 2, 0), 'z': (0, 0, 0)}[axis]
    return cyl(name, material, c, r, h, segs, 0, rot=rot)

# ================================================================ relay lever
def build_relay():
    reset(41)
    paint_m = mat("Relay_Green", "paint_relay", .62, .1); trim = mat("Relay_Trim", "trim_dark", .5, .6)
    steel = mat("Relay_Steel", "steel_bare", .38, .85); hz = mat("Relay_Hazard", "hazard", .7)
    dec = mat("Relay_Decals", "stencil_atlas", .75); dialm = mat("Relay_Dial", "dial", .55)
    grip = mat("Relay_Grip", "rubber_red", .75)
    amber = mat("Relay_Indicator_Amber", hexcol="#f9ab50", rough=.28, emit=((1.0, .38, .04), 6.0))
    H = []
    # plinth, hazard kick band, cabinet, rain hood (outer envelope exactly 0.6 x 0.6 x 1.8)
    part(H, box("Plinth", trim, (0, 0, .04), (.6, .6, .08), .012, 1), base=.75)
    part(H, box("Kick", hz, (0, 0, .115), (.56, .56, .07), .006, 1), ('box', .25, None), base=.95, edge=.1)
    part(H, box("Cabinet", paint_m, (0, 0, .905), (.52, .50, 1.51), .022, 2), ('box', .6, 2), base=.86, top=1.04)
    part(H, box("Hood", trim, (0, -.005, 1.70), (.58, .57, .10), .016, 1), ('box', .5, None), base=.8)
    part(H, box("Cap", paint_m, (0, 0, 1.775), (.6, .6, .05), .014, 2), ('box', .6, None), base=.9)
    for x in (-.29, .29):  # drip edge brackets
        part(H, box("HoodRib", trim, (x, -.04, 1.69), (.02, .46, .08), 0, 1), None, base=.8)
    # door: inset panel with bevelled frame, louvres, hinges, handle, stencils
    part(H, box("Door", paint_m, (0, -.2615, .62), (.44, .025, .78), .012, 2), ('box', .6, 2), base=.9, edge=.22)
    part(H, box("DoorField", paint_m, (0, -.276, .52), (.36, .01, .48), .004, 1), ('box', .6, 2), base=.84)
    for k in range(5):
        z = .80 + k * .04
        part(H, box("Louvre", trim, (0, -.277, z), (.30, .012, .03), 0, 1, rot=(math.radians(35), 0, 0)), None, base=.7, cavity=.3)
    for z in (.33, .90):
        part(H, cyl("Hinge", steel, (-.232, -.273, z), .013, .09, 8, 0), ('cyl', (-.232, .273), 2, .2, .013), base=.9)
    hd = [(.17, -.276, .66), (.17, -.29, .66), (.17, -.29, .56), (.17, -.276, .56)]
    part(H, sweep_rect("Handle", steel, hd, .018, .012, up=Vector((1, 0, 0)), bev=0), None, base=.92, edge=.25)
    H.append(decal("RelayStencil", dec, "relay", (0, -.281, .40), (0, -1, 0), .30, .15))
    # control panel: dark steel plate, OFF/ON quadrant dial, axle boss, warning strip, lamp bezel
    part(H, box("ControlPlate", trim, (0, -.265, 1.33), (.46, .035, .50), .01, 1), ('box', .4, None), base=.82, edge=.25)
    dl = cyl("DialFace", dialm, (0, -.288, 1.20), .125, .012, 16, 0, rot=(math.pi / 2, 0, 0))
    uv_cyl(dl, (0, 1.20), 1, .3, .125, True, .125); paint(dl, .95, 1.0, edge=.15, cavity=.1); H.append(dl)
    part(H, cyl("DialRing", steel, (0, -.285, 1.20), .132, .016, 16, .004, bsegs=1, rot=(math.pi / 2, 0, 0)), None, base=.9)
    for x, z in ((-.2, 1.11), (.2, 1.11), (-.2, 1.55), (.2, 1.55)):
        part(H, bolt("PanelBolt", steel, (x, -.285, z)), None, base=.9)
    H.append(decal("PullTag", dec, "wx", (-.13, -.2835, 1.50), (0, -1, 0), .14, .07))
    part(H, cyl("LampBezel", steel, (.16, -.287, 1.62), .036, .02, 12, .003, bsegs=1, rot=(math.pi / 2, 0, 0)), None, base=.85, edge=.25)
    part(H, cyl("LampSocket", trim, (.16, -.27, 1.62), .05, .03, 12, 0, rot=(math.pi / 2, 0, 0)), None, base=.8)
    # side: DANGER plate, cable conduit into a gland box, clamps; earth strap at the plinth
    H.append(decal("Danger", dec, "danger", (.2615, -.02, 1.30), (1, 0, 0), .30, .15))
    cond = [(.272, .13, .08), (.272, .13, 1.30), (.272, .13, 1.38)]
    part(H, tube("Conduit", steel, cond, .02, 8), ('cyl', (.272, .13), 2, .3, .02), base=.85)
    part(H, box("Gland", trim, (.265, .13, 1.42), (.06, .10, .10), .01, 1), None, base=.8)
    for z in (.35, .75, 1.10):
        part(H, box("Clamp", steel, (.272, .13, z), (.05, .06, .025), 0, 1), None, base=.9)
    for x, y in ((-.27, -.27), (.27, -.27), (-.27, .27), (.27, .27)):
        part(H, bolt("AnchorBolt", steel, (x, y, .085), 'z', .016, .014, 6), None, base=.85)
    housing = H
    # lever: drum about X through the original pivot, forked arms, rubber T-grip
    PV = Vector((0, -.4, 1.2)); L = []
    part(L, cyl("Drum", trim, PV, .095, .12, 16, .008, bsegs=1, rot=(0, math.pi / 2, 0)), ('cyl', (-.4, 1.2), 0, .3, .095), base=.8, edge=.25)
    for x in (-.064, .064):
        part(L, cyl("DrumCap", steel, PV + Vector((x, 0, 0)), .06, .012, 12, 0, rot=(0, math.pi / 2, 0)), None, base=.9)
    for x in (-.045, .045):
        part(L, sweep_rect("Arm", steel, [PV + Vector((x, -.01, .06)), PV + Vector((x, -.02, .2))], .016, .026, up=Vector((0, -1, 0)), bev=0), None, base=.88, edge=.3)
    part(L, cyl("Grip", grip, PV + Vector((0, -.022, .213)), .021, .19, 12, .006, rot=(0, math.pi / 2, 0)), ('cyl', (-.422, 1.413), 0, .1, .021), base=.95)
    part(L, box("Index", hz, PV + Vector((0, -.096, 0)), (.03, .004, .05), 0, 1), ('box', .1, None), base=1)
    # amber lamp lens (own single material; puzzle_controls.gd duplicates it per relay)
    lens = lathe("Lens", amber, [(.0001, -.296), (.028, -.296), (.028, -.304), (.024, -.318), (.014, -.328), (.0001, -.331)], 14)
    lens.data.transform(Matrix.Translation((.16, 0, 1.62)) @ Matrix.Rotation(-math.pi / 2, 4, 'X'))
    # (lathe profile is (r, z); the X rotation turns its z axis toward -y)
    paint(lens, 1, 1, noise_amt=0, edge=0, cavity=0)
    root = root_empty("Relay_Root")
    nodes = [node(housing, "Relay_Housing", root), node([lens], "Relay_Indicator", root), node(L, "Relay_Lever", root, tuple(PV))]
    write("relay_lever_weather_station", nodes)

# ================================================================ loot cache
def build_cache(saltflat):
    reset(52 + saltflat)
    suf = "SaltFlat" if saltflat else "Woodland"
    paint_m = mat("Cache_Paint_" + suf, "paint_sand" if saltflat else "paint_olive", .7, .08)
    trim = mat("Cache_Trim_" + suf, "trim_brown" if saltflat else "trim_dark", .55, .6)
    steel = mat("Cache_Steel_" + suf, "steel_bare", .45, .8)
    dec = mat("Cache_Decals_" + suf, "stencil_atlas", .75)
    hz = mat("Cache_Hazard_" + suf, "hazard", .7)
    Bd = []
    part(Bd, box("Shell", paint_m, (0, -.01, .435), (1.40, .90, .79), .028, 2), ('box', .6, 2), base=.82, top=1.04)
    for x in (-.5, .5):
        part(Bd, box("Skid", trim, (x, -.01, .025), (.12, .94, .05), .008, 1), ('box', .4, 1), base=.75)
    part(Bd, box("Rim", trim, (0, -.01, .80), (1.44, .94, .046), .01, 2), ('box', .4, None), base=.8, edge=.25)
    for sx in (-1, 1):
        for y in (-.455, .435):
            part(Bd, box("CornerGuard", steel, (sx * .695, y, .41), (.07, .07, .74), 0, 1), ('box', .3, 2), base=.85, edge=.25)
            for z in (.08, .74):
                part(Bd, box("CornerCap", trim, (sx * .695, y, z), (.085, .085, .1), .012, 1), None, base=.8)
    for x in (-.36, .36):  # pressed steel bands front and back
        for y, s in ((-.463, -1), (.443, 1)):
            part(Bd, box("Band", trim, (x, y, .43), (.07, .012, .74), 0, 1), ('box', .3, 2), base=.8, edge=.2)
            for z in (.18, .68):
                part(Bd, bolt("Rivet", steel, (x, y + s * .007, z), r=.008, h=.006), None, base=.9)
    for sx in (-1, 1):  # side carry handles: bracket + steel bail
        part(Bd, box("HandlePlate", trim, (sx * .705, -.01, .55), (.012, .30, .10), 0, 1), None, base=.8)
        bail = [Vector((sx * (.715 + .03 * math.sin(math.pi * k / 8)), -.01 + .11 * math.cos(math.pi * k / 8), .55 - .05 * math.sin(math.pi * k / 8))) for k in range(9)]
        part(Bd, tube("Bail", steel, bail[::2], .011, 5), None, base=.9)
    part(Bd, box("Staple", steel, (0, -.468, .735), (.05, .02, .05), .005, 1), None, base=.9)
    Bd.append(decal("Stencil", dec, "supply_s" if saltflat else "supply_w", (0, -.4605, .42), (0, -1, 0), .62, .31))
    part(Bd, box("HazardTab", hz, (0, -.462, .12), (.5, .006, .06), .002, 1), ('box', .2, None), base=.95)
    # lid (hinge at the rear seam, same as the original Cache_Lid)
    HG = Vector((0, .484, .85)); Ld = []
    part(Ld, box("LidShell", paint_m, (0, 0, .889), (1.42, .94, .12), .03, 2), ('box', .6, None), base=.86, top=1.05)
    part(Ld, box("LidPanel", paint_m, (0, -.01, .974), (1.20, .72, .052), .022, 2), ('box', .6, None), base=.92, top=1.06, edge=.22)
    part(Ld, box("LidLip", trim, (0, 0, .8205), (1.43, .95, .03), .006, 1), ('box', .4, None), base=.8)
    for sx in (-1, 1):
        for y in (-.43, .43):
            part(Ld, box("LidCorner", steel, (sx * .67, y, .95), (.09, .09, .02), 0, 1), None, base=.88)
    for x in (-.5, 0, .5):
        part(Ld, cyl("Knuckle", steel, (x, .484, .85), .016, .16, 8, 0, rot=(0, math.pi / 2, 0)), None, base=.88)
    Ld.append(decal("LidStencil", dec, "arrows", (-.35, -.01, 1.0), (0, 0, 1), .36, .18))
    Lt = [box("Hasp", steel, (0, -.482, .845), (.07, .012, .17), .004, 1),
          cyl("HaspBarrel", steel, (0, -.478, .935), .012, .09, 8, .002, rot=(0, math.pi / 2, 0)),
          box("HaspPlate", steel, (0, -.474, .965), (.11, .008, .06), .003, 1)]
    for o in Lt: finish(o, None, base=.9, seed=7)
    loop = [Vector((.024 * math.cos(TAU * k / 10), -.50 + .012 * math.sin(TAU * k / 10), .77 + .022 * math.sin(TAU * k / 10) * .0 + .024 * math.sin(TAU * k / 10))) for k in range(10)]
    lp = tube("Padlock", trim, [Vector((.0, -.49, .80)), Vector((.0, -.495, .77)), Vector((.0, -.49, .75))], .006, 6); finish(lp, None, base=.8); Lt.append(lp)
    root = root_empty("Cache_Root")
    body = node(Bd, "Cache_Body", root); lid = node(Ld, "Cache_Lid", root, tuple(HG))
    latch = join(Lt, "Cache_Latch"); latch.data.transform(Matrix.Translation(-HG)); latch.parent = lid; latch.location = (0, 0, 0)
    write("loot_cache_" + suf.lower(), [body, lid, latch])

# ================================================================ cargo containers
def corrugated(name, material, axis_len, along, fixed, z0, z1, pitch, depth, rows=2, flip=1, dent=None, start=None, end=None):
    """Trapezoid corrugated sheet. along: 'x' or 'y' (rib direction across), fixed = plane coordinate.
    The sheet spans [start, end] along the axis, z0..z1 vertically; ribs bulge by depth*flip outward."""
    s0 = -axis_len / 2 if start is None else start; s1 = axis_len / 2 if end is None else end
    n = max(1, round((s1 - s0) / pitch)); pts = []
    for i in range(n):
        a = s0 + (s1 - s0) * i / n; w = (s1 - s0) / n
        pts += [(a, 0), (a + w * .16, depth), (a + w * .50, depth), (a + w * .66, 0)]
    pts.append((s1, 0))
    rows_z = [z0 + (z1 - z0) * r / (rows - 1) for r in range(rows)]
    rings = []
    for z in rows_z:
        ring = []
        for s, d in pts:
            dd = d * flip
            if dent: dd += dent(s, z)
            ring.append((fixed + dd, s, z) if along == 'y' else (s, fixed + dd, z))
        rings.append(ring)
    ob = B.grid(name, material, rings, closed=False)
    bm = bmesh.new(); bm.from_mesh(ob.data); bm.normal_update()
    out = Vector((1, 0, 0)) if along == 'y' else Vector((0, 1, 0)); out *= (1 if fixed >= 0 else -1)
    if sum(f.normal.dot(out) for f in bm.faces) < 0:
        for f in bm.faces: f.normal_flip()
    bm.to_mesh(ob.data); bm.free()
    if along == 'y': uv_box(ob, .8, 2)
    else: uv_box(ob, .8, 2)
    smooth(ob, 25)
    return ob

def build_container(dented, sand):
    reset(63 + 2 * dented + sand)
    pal = "Sand" if sand else "Olive"; kind = "Dented" if dented else "Intact"
    paint_m = mat("Container_Paint_" + pal, "paint_sand" if sand else "paint_olive", .66, .12)
    trim = mat("Container_Trim_" + pal, "trim_brown" if sand else "trim_dark", .5, .65)
    steel = mat("Container_Steel_" + pal, "steel_bare", .42, .85)
    dec = mat("Container_Decals_" + pal, "stencil_atlas", .7)
    P = []
    X, Y, Hh = 1.75, 2.5, 2.4
    rng = random.Random(7 + sand)
    def dent_side(sign):
        if not dented: return None
        cs = [(rng.uniform(-1.8, 1.8), rng.uniform(.5, 1.9), rng.uniform(.25, .5), rng.uniform(.03, .07)) for _ in range(3)]
        def f(s, z):
            d = 0
            for cy, cz, r, amt in cs:
                q = ((s - cy) ** 2 + (z - cz) ** 2) / (r * r)
                d -= amt * math.exp(-q * 1.5)
            return d * 1  # inward (toward the box): negative offset from the outer face
        return f
    rows = 7 if dented else 2
    for sx in (-1, 1):
        f = dent_side(sx)
        dent = (lambda s, z, f=f, sx=sx: f(s, z) * sx) if f else None
        part(P, corrugated("SideWall", paint_m, 4.76, 'y', sx * 1.645, .15, 2.27, .278, .04 * sx, rows, 1, dent), None, base=.86, top=1.04, noise_amt=.06 if dented else .04)
    part(P, corrugated("RearWall", paint_m, 3.26, 'x', 2.395, .15, 2.27, .28, .035, 2), None, base=.84, top=1.02)
    sag = (lambda s, z: 0) if not dented else None
    roof_rings = []
    for y in (-2.38, 2.38):
        roof_rings.append([(x, y, 2.33 + (.018 if (i % 4) in (1, 2) else 0) - (.03 * math.exp(-((x - .4) ** 2 + (y + .6) ** 2) / .5) if dented else 0)) for i, x in enumerate([-1.62 + 3.24 * k / 64 for k in range(65)])])
    rf = B.grid("Roof", paint_m, roof_rings, closed=False); uv_box(rf, .8, 1); smooth(rf, 25)
    bm = bmesh.new(); bm.from_mesh(rf.data); bm.normal_update()
    if sum(f.normal.z for f in bm.faces) < 0:
        for f in bm.faces: f.normal_flip()
    bm.to_mesh(rf.data); bm.free(); part(P, rf, None, base=.9, top=.95)
    part(P, box("Floor", trim, (0, 0, .16), (3.3, 4.8, .02), 0, 1), None, base=.5)
    # frame: corner posts, top and bottom rails, cross members, eight corner castings
    for sx in (-1, 1):
        for sy in (-1, 1):
            part(P, box("CornerPost", trim, (sx * 1.685, sy * 2.435, 1.2), (.13, .13, 2.2), .012, 1), ('box', .6, 2), base=.8, edge=.25)
            for z in (.06, 2.34):
                part(P, box("Casting", trim, (sx * 1.66, sy * 2.41, z), (.18, .18, .12), .012, 1), ('box', .3, None), base=.7, edge=.3)
                for nrm, off in (((sx, 0, 0), (sx * .0905, 0, 0)), ((0, sy, 0), (0, sy * .0905, 0)), ((0, 0, 1 if z > 1 else -1), (0, 0, .0605 if z > 1 else -.0605))):
                    pass
        part(P, box("BottomRail", trim, (sx * 1.69, 0, .09), (.10, 4.66, .16), .01, 1), ('box', .6, 1), base=.78)
        part(P, box("TopRail", trim, (sx * 1.69, 0, 2.325), (.10, 4.66, .11), .01, 1), ('box', .6, 1), base=.82, edge=.25)
    for sy in (-1, 1):
        part(P, box("Sill", trim, (0, sy * 2.43, .09), (3.18, .14, .16), .01, 1), ('box', .6, 0), base=.78)
        part(P, box("Header", trim, (0, sy * 2.43, 2.32), (3.18, .14, .14), .01, 1), ('box', .6, 0), base=.82, edge=.25)
    # front doors: two leaves with vertical corrugation, locking bars, cam keepers and handles
    for sx in (-1, 1):
        x0, x1 = (-1.60, -.012) if sx < 0 else (.012, 1.60)
        part(P, corrugated("DoorLeaf", paint_m, 0, 'x', -2.445, .17, 2.24, .30, -.03, 2, 1, None, x0 + .06, x1 - .06), None, base=.88, top=1.04)
        for (cx, w) in (((x0 + x1) / 2, x1 - x0),):
            part(P, box("DoorFrameTop", paint_m, (cx, -2.452, 2.205), (w, .03, .07), .006, 1), ('box', .6, 0), base=.9, edge=.25)
            part(P, box("DoorFrameBot", paint_m, (cx, -2.452, .205), (w, .03, .07), .006, 1), ('box', .6, 0), base=.82, edge=.25)
            for ex in (x0 + .03, x1 - .03):
                part(P, box("DoorFrameSide", paint_m, (ex, -2.452, 1.205), (.06, .03, 2.0), .006, 1), ('box', .6, 2), base=.88, edge=.25)
        for bx in ((x0 + .32, x1 - .42) if sx < 0 else (x0 + .42, x1 - .32)):
            part(P, cyl("LockBar", steel, (bx, -2.477, 1.2), .022, 2.10, 6, 0), ('cyl', (bx, 2.485), 2, .5, .022), base=.88)
            for z in (.2, 2.2):
                part(P, box("CamKeeper", trim, (bx, -2.475, z), (.09, .04, .07), 0, 1), None, base=.75)
            for z in (.65, 1.75):
                part(P, box("BarGuide", trim, (bx, -2.47, z), (.07, .03, .04), 0, 1), None, base=.78)
            hd = [(bx, -2.47, 1.12), (bx + sx * -.02, -2.483, 1.12), (bx + sx * -.20, -2.483, 1.08), (bx + sx * -.23, -2.47, 1.07)]
            part(P, sweep_rect("Handle", steel, hd, .022, .03, up=Vector((0, 0, 1)), bev=0), None, base=.9, edge=.3)
        for z in (.45, 1.2, 1.95):
            part(P, cyl("DoorHinge", steel, (sx * 1.59, -2.47, z), .025, .12, 6, 0), ('cyl', (sx * 1.59, 2.47), 2, .3, .025), base=.86)
    part(P, box("DoorSeam", trim, (0, -2.448, 1.2), (.024, .02, 2.04), 0, 1), None, base=.35)
    # stencils: owner code on the door and both sides, data plate, class placard
    P.append(decal("DoorID", dec, "cargo_id", (.80, -2.481, 1.95), (0, -1, 0), .9, .45))
    P.append(decal("DataPlate", dec, "plate", (-.80, -2.481, 1.55), (0, -1, 0), .5, .25))
    for sx in (-1, 1):
        P.append(decal("SideID", dec, "cargo_id", (sx * 1.69, sx * 1.6, 2.0), (sx, 0, 0), 1.0, .5))
    P.append(decal("Placard", dec, "class", (-1.69, -1.4, .9), (-1, 0, 0), .5, .25))
    part(P, box("BackPanel", trim, (0, 2.42, 1.21), (3.24, .02, 2.12), 0, 1), None, base=.5)
    name = "Container_%s" % kind
    root = root_empty(name + "_Root")
    body = node(P, name + "_Body", root)
    write("cargo_container_%s_%s" % (kind.lower(), pal.lower()), [body])

# ================================================================ cargo stacks
def pallet(P, wood, X, Y, deck=.145, boards=7):
    """Bevelled stringer pallet: deck boards along Y, three stringers, block feet."""
    bw = X / boards * .82
    for i in range(boards):
        x = -X / 2 + bw / 2 + (X - bw) * i / (boards - 1)
        part(P, box("DeckBoard", wood, (x + (random.uniform(-.004, .004) if 0 < i < boards - 1 else 0), 0, deck - .011), (bw, Y, .022), .005, 1), ('box', .7, 1), base=.82 + random.uniform(-.05, .05), edge=.25)
    for y in (-Y / 2 + .06, 0, Y / 2 - .06):
        part(P, box("Stringer", wood, (0, y, deck - .052), (X, .11, .06), .006, 1), ('box', .7, 0), base=.72)
        for x in (-X / 2 + .07, 0, X / 2 - .07):
            part(P, box("Block", wood, (x, y, .045), (.13, .11, .09), 0, 1), ('box', .3, None), base=.66)

def drum(P, mat_, c, r, h, lab=None, dec=None, yaw=0.0):
    x, y, z = c
    part(P, cyl("Drum", mat_, (x, y, z + h / 2), r, h, 16, .01, bsegs=1), ('cyl', (x, y), 2, .6, r), base=.86, top=1.03)
    for zz in (h * .33, h * .66):
        part(P, cyl("DrumHoop", mat_, (x, y, z + zz), r + .008, .03, 16, 0), ('cyl', (x, y), 2, .6, r), base=.95, edge=.25)
    part(P, cyl("DrumChime", mat_, (x, y, z + h - .01), r + .006, .02, 16, 0), None, base=.92, edge=.3)
    part(P, cyl("Bung", mat_, (x + r * .5, y, z + h + .005), .03, .012, 6, 0), None, base=.8)
    if lab:
        a = yaw; n = Vector((math.cos(a), math.sin(a), 0))
        P.append(decal("DrumLabel", dec, lab, Vector((x, y, z + h * .5)) + n * (r + .002), n, r * 1.1, r * .55))

def carton(P, mat_, c, s, dec=None, lab=None, face=(0, -1, 0), tape=None):
    x, y, z = c
    part(P, box("Carton", mat_, (x, y, z + s[2] / 2), s, .008, 1), ('box', .6, None), base=.86 + random.uniform(-.05, .05), top=1.02)
    if tape: part(P, box("Tape", tape, (x, y, z + s[2] + .0008), (s[0] + .002, .07, .002), 0, 1), ('box', .3, None), base=.95)
    if lab:
        n = Vector(face); fc = Vector((x, y, z + s[2] * .55)) + Vector((n.x * s[0] / 2, n.y * s[1] / 2, 0))
        P.append(decal("CartonLabel", dec, lab, fc, n, min(.36, (s[1] if abs(n.x) > .5 else s[0]) * .7), .16))

def strap_over(P, mat_, x, y0, y1, z_top, z0=.15, w=.05, along='y', soft=None):
    """Ratchet strap: up one side, across the top, down the other (lies on the load)."""
    pts = [(x, y0, z0), (x, y0, z_top - .04), (x, y0 + .03 * (1 if y1 > y0 else -1), z_top), (x, y1 - .03 * (1 if y1 > y0 else -1), z_top), (x, y1, z_top - .04), (x, y1, z0)]
    if along == 'x': pts = [(y, x, z) for x, y, z in pts]
    return part(P, sweep_rect("Strap", mat_, pts, w, .006, up=Vector((0, 0, 1)) if along == 'y' else Vector((0, 0, 1)), bev=0), ('box', .4, None), base=.95, edge=0)

def tarp_bundle(P, mat_, c, s, seed):
    """Canvas-covered bundle: subdivided box with sagging, wrinkled top and tucked skirt."""
    bm = bmesh.new(); bmesh.ops.create_cube(bm, size=1.0); bmesh.ops.scale(bm, vec=Vector(s), verts=bm.verts)
    bmesh.ops.subdivide_edges(bm, edges=bm.edges, cuts=5, use_grid_fill=True)
    for v in bm.verts:
        p = v.co; top = (p.z + s[2] / 2) / s[2]
        n = noise.noise(p * 4 + Vector((seed, 0, 0)))
        n2 = noise.noise(p * 9 + Vector((0, seed, 0)))
        v.co.z += (-.07 * (1 - (2 * p.x / s[0]) ** 2) * (1 - (2 * p.y / s[1]) ** 2) + .03 * n + .012 * n2) * top ** 2
        bulge = 1 + .035 * math.sin(math.pi * min(max(top, 0), 1)) + .025 * n + .01 * n2
        v.co.x *= bulge; v.co.y *= bulge
        v.co.z = min(v.co.z, s[2] / 2)
        if abs(p.x) > s[0] * .49 and abs(p.y) > s[1] * .49: v.co.x *= .97; v.co.y *= .97
    ob = obj_from_bm(bm, "Tarp", mat_); ob.location = c; bevel(ob, .01, 1); apply_all(ob); smooth(ob, 60)
    return part(P, ob, ('box', .7, None), base=.82, top=1.05, cavity=.3)

def bevel(ob, w, s): return B.bevel(ob, w, s)

def build_stack_large(sand):
    reset(81 + sand); pal = "Sand" if sand else "Olive"
    wood = mat("StackLarge_Wood_" + pal, "pallet_pine", .85)
    ply = mat("StackLarge_Crate_" + pal, "plywood", .8)
    steel = mat("StackLarge_Steel_" + pal, "trim_brown" if sand else "trim_dark", .5, .6)
    canvas = mat("StackLarge_Canvas_" + pal, "canvas_sand" if sand else "canvas_olive", .92)
    strap = mat("StackLarge_Strap_" + pal, "strap_orange" if sand else "strap_yellow", .7)
    drm = mat("StackLarge_Drum_" + pal, "drum_red" if sand else "drum_olive", .55, .3)
    dec = mat("StackLarge_Decals_" + pal, "stencil_atlas", .75)
    P = []; X, Y, Z = 2.2, 2.8, 2.2
    pallet(P, wood, X, Y)
    D = .145
    # low steel stillage: corner posts and a rail at drum-hoop height; the tarp top sets the 2.2 m height
    PH = 1.0
    for sx in (-1, 1):
        for sy in (-1, 1):
            part(P, box("Post", steel, (sx * (X / 2 - .03), sy * (Y / 2 - .03), (D + PH) / 2), (.06, .06, PH - D), .006, 1), ('box', .5, 2), base=.85, edge=.3)
        part(P, box("RailY", steel, (sx * (X / 2 - .03), 0, PH - .03), (.05, Y - .06, .04), .005, 1), ('box', .5, 1), base=.88, edge=.3)
    for sy in (-1, 1):
        part(P, box("RailX", steel, (0, sy * (Y / 2 - .03), PH - .03), (X - .06, .05, .04), .005, 1), ('box', .5, 0), base=.88, edge=.3)
    # tier 1: two drums (front), two plywood crates (back); tier 2: tarp bundle + crate
    drum(P, drm, (-.55, -.85, D), .29, .86, "fuel", dec, -math.pi / 2)
    drum(P, mat("StackLarge_DrumB_" + pal, "drum_blue", .55, .3), (.15, -.85, D), .29, .86, "water", dec, -math.pi / 2)
    carton(P, ply, (.70, -.80, D), (.5, .64, .62), dec, "arrows", (0, -1, 0))
    for x, w, lab in ((-.50, .95, "fragile"), (.52, .90, "stack_id")):
        carton(P, ply, (x, .55, D), (w, 1.35, .80), dec, lab, (1, 0, 0) if x > 0 else (-1, 0, 0))
        for yy in (-.55, .55):
            part(P, box("CrateBatten", wood, (x, .55 + yy * 1.0, D + .4), (w + .02, .06, .78), .006, 1), ('box', .7, 2), base=.75)
    TH = Z - (D + .80)
    tarp_bundle(P, canvas, (0, .45, D + .80 + TH / 2), (1.9, 1.6, TH), 3.1)
    carton(P, ply, (-.3, -.85, D + .86), (.9, .62, .55), dec, "kraft_label", (0, -1, 0))
    # tie-downs over the tarp, hooked to the crate tops either side
    for y in (.0, .85):
        strap_over(P, strap, y, -1.035, 1.035, Z - .004, D + .80, .05, along='x')
        part(P, box("Ratchet", steel, (1.045, y, D + 1.05), (.02, .07, .12), .004, 1), None, base=.9)
    root = root_empty("StackLarge_Root")
    write("cargo_stack_large_" + pal.lower(), [node(P, "StackLarge_Body", root)])

def build_stack_pallet(sand):
    reset(91 + sand); pal = "Sand" if sand else "Olive"
    wood = mat("StackPallet_Wood_" + pal, "pallet_pine", .85)
    card = mat("StackPallet_Card_" + pal, "cardboard", .9)
    strap = mat("StackPallet_Strap_" + pal, "strap_orange" if sand else "strap_dark", .7)
    drm = mat("StackPallet_Drum_" + pal, "drum_red" if sand else "drum_olive", .55, .3)
    dec = mat("StackPallet_Decals_" + pal, "stencil_atlas", .75)
    tape = mat("StackPallet_Tape_" + pal, "strap_yellow", .5)
    P = []; X, Y, Z = 1.6, 2.3, 1.5; D = .145
    pallet(P, wood, X, Y, D, 6)
    # cartons in two layers, a drum standing in the front corner, corner boards and straps
    for (x, y, sx, sy, sz, lab, face) in ((-.40, .55, .78, 1.15, .56, "kraft_label", (-1, 0, 0)), (.40, .55, .78, 1.15, .56, "barcode", (1, 0, 0)),
                                         (.40, -.62, .78, 1.0, .56, "fragile", (0, -1, 0))):
        carton(P, card, (x, y, D), (sx, sy, sz), dec, lab, face, tape)
    drum(P, drm, (-.40, -.62, D), .3, .88, "fuel", dec, -math.pi / 2)
    for (x, y, sx, sy, sz, lab, face) in ((-.38, .55, .82, 1.12, .795, "stack_id", (-1, 0, 0)), (.42, .30, .72, .7, .45, "arrows", (1, 0, 0)), (.40, -.50, .78, .9, .5, "kraft_label", (0, -1, 0))):
        carton(P, card, (x, y, D + .56 + (.0 if x > 0 else 0)), (sx, sy, sz), dec, lab, face, tape)
    for sx in (-1, 1):
        for sy in (-1, 1):
            part(P, box("CornerBoard", card, (sx * (X / 2 - .03), sy * (Y / 2 - .03), D + .59), (.06, .06, 1.18), .004, 1), ('box', .5, 2), base=.75)
    strap_over(P, strap, -.38, -.03, 1.13, Z - .0035, D + .02, .045)
    # stretch band right round the load, over the corner boards
    for z in (.42, .62):
        ring = [Vector((sx * .796, sy * 1.146, z)) for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
        part(P, sweep_rect("Band", strap, ring + [ring[0]], .004, .04, up=Vector((0, 0, 1)), bev=0), ('box', .4, None), base=.95, edge=0)
    root = root_empty("StackPallet_Root")
    write("cargo_stack_pallet_" + pal.lower(), [node(P, "StackPallet_Body", root)])

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True); os.makedirs(BLEND, exist_ok=True)
    which = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else ["relay", "cache", "container", "stack"]
    if "relay" in which: build_relay()
    if "cache" in which:
        for s in (False, True): build_cache(s)
    if "container" in which:
        for d in (False, True):
            for s in (False, True): build_container(d, s)
    if "stack" in which:
        for s in (False, True): build_stack_large(s); build_stack_pallet(s)
    print("ROLLOUT_REPORT", REPORT)
