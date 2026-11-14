# Item 11 style test: mid-stylized dress form + Rook counter stock.
# Blender 4.2, meter scale, Z-up (glTF exporter converts to Godot Y-up).
# Every object has transforms applied before export.
import bpy, bmesh, math, random
from mathutils import Vector, Matrix, noise

OUT = "/workspace/settlement_midstyle/repo/assets/midstyle_test/"
random.seed(11)

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.unit_settings.system = 'METRIC'
    bpy.context.scene.unit_settings.scale_length = 1.0

MATS = {}
def mat(name, hexcol, rough=0.8, metal=0.0):
    if name in MATS: return MATS[name]
    m = bpy.data.materials.new(name); m.use_nodes = True
    nt = m.node_tree; bsdf = nt.nodes["Principled BSDF"]
    h = hexcol.lstrip('#'); c = [int(h[i:i+2], 16) / 255 for i in (0, 2, 4)]
    c = [x ** 2.2 for x in c]
    bsdf.inputs["Base Color"].default_value = (*c, 1)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    m.diffuse_color = (*c, 1)
    # Multiply by the painted colour attribute so the exporter writes COLOR_0.
    attr = nt.nodes.new("ShaderNodeVertexColor"); attr.layer_name = "Col"
    mix = nt.nodes.new("ShaderNodeMix"); mix.data_type = 'RGBA'; mix.blend_type = 'MULTIPLY'
    mix.inputs["Factor"].default_value = 1.0
    mix.inputs[6].default_value = (*c, 1)
    nt.links.new(attr.outputs["Color"], mix.inputs[7])
    nt.links.new(mix.outputs[2], bsdf.inputs["Base Color"])
    MATS[name] = m
    return m

def obj_from_bm(bm, name, material):
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    ob = bpy.data.objects.new(name, me); bpy.context.collection.objects.link(ob)
    me.materials.append(material)
    return ob

def select_only(ob):
    bpy.ops.object.select_all(action='DESELECT'); ob.select_set(True)
    bpy.context.view_layer.objects.active = ob

def bevel(ob, width, segs=2, angle=40):
    mod = ob.modifiers.new("Bevel", 'BEVEL'); mod.width = width; mod.segments = segs
    mod.limit_method = 'ANGLE'; mod.angle_limit = math.radians(angle); mod.harden_normals = False
    return mod

def apply_all(ob):
    select_only(ob)
    for mod in list(ob.modifiers): bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

def smooth(ob, angle=35):
    select_only(ob)
    bpy.ops.object.shade_smooth_by_angle(angle=math.radians(angle))

def box(name, material, center, size, bev=0.01, segs=2, rot=(0, 0, 0)):
    bm = bmesh.new(); bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
    ob = obj_from_bm(bm, name, material)
    ob.rotation_euler = rot; ob.location = center
    if bev > 0: bevel(ob, bev, segs)
    apply_all(ob); smooth(ob)
    return ob

def cyl(name, material, center, r, h, segs=24, bev=0.006, rot=(0, 0, 0), r2=None):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=segs, radius1=r, radius2=(r if r2 is None else r2), depth=h)
    ob = obj_from_bm(bm, name, material); ob.rotation_euler = rot; ob.location = center
    if bev > 0: bevel(ob, bev, 2)
    apply_all(ob); smooth(ob)
    return ob

def lathe(name, material, profile, segs=28, center=(0, 0, 0)):
    """profile: list of (radius, z) from bottom to top; capped ends."""
    bm = bmesh.new(); rings = []
    for r, z in profile:
        ring = [bm.verts.new((r * math.cos(2 * math.pi * i / segs), r * math.sin(2 * math.pi * i / segs), z)) for i in range(segs)]
        rings.append(ring)
    for a, b in zip(rings, rings[1:]):
        for i in range(segs):
            j = (i + 1) % segs
            bm.faces.new((a[i], a[j], b[j], b[i]))
    bm.faces.new(list(reversed(rings[0]))); bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = obj_from_bm(bm, name, material); ob.location = center
    apply_all(ob); smooth(ob, 50)
    return ob

def loft(name, material, rings_spec, segs=32, power=2.6, cap_bottom=True, cap_top=True):
    """rings_spec: (z, half_width_x, half_depth_front, half_depth_back, y_offset)."""
    bm = bmesh.new(); rings = []
    for z, hx, hf, hb, yo in rings_spec:
        ring = []
        for i in range(segs):
            t = 2 * math.pi * i / segs
            c, s = math.cos(t), math.sin(t)
            # Superellipse gives a soft "chunky" section rather than a pure ellipse.
            x = hx * math.copysign(abs(c) ** (2 / power), c)
            hy = hf if s < 0 else hb
            y = hy * math.copysign(abs(s) ** (2 / power), s) + yo
            ring.append(bm.verts.new((x, y, z)))
        rings.append(ring)
    for a, b in zip(rings, rings[1:]):
        for i in range(segs):
            j = (i + 1) % segs
            bm.faces.new((a[i], a[j], b[j], b[i]))
    if cap_bottom: bm.faces.new(list(reversed(rings[0])))
    if cap_top: bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return obj_from_bm(bm, name, material)

def paint(ob, base=0.80, top=1.06, axis=2, noise_amt=0.06, edge_boost=0.10, seed=0.0):
    """Hand-painted style vertex colour: vertical value ramp, soft noise, lit edges."""
    me = ob.data
    if "Col" not in me.color_attributes:
        me.color_attributes.new("Col", 'BYTE_COLOR', 'CORNER')
    col = me.color_attributes["Col"]
    zs = [v.co[axis] for v in me.vertices]; lo, hi = min(zs), max(zs); span = max(hi - lo, 1e-4)
    for poly in me.polygons:
        for li in poly.loop_indices:
            v = me.vertices[me.loops[li].vertex_index]
            t = (v.co[axis] - lo) / span
            n = noise.noise(v.co * 9.0 + Vector((seed, seed, seed)))
            up = max(0.0, v.normal.z) * edge_boost
            k = base + (top - base) * t + n * noise_amt + up
            col.data[li].color = (k, k, k, 1.0)

def join(objs, name):
    select_only(objs[0])
    for o in objs[1:]: o.select_set(True)
    bpy.ops.object.join(); ob = bpy.context.active_object; ob.name = name
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return ob

def export(path):
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=True,
                              export_apply=True, export_yup=True, export_vertex_color='MATERIAL',
                              export_all_vertex_colors=False, export_normals=True, export_materials='EXPORT')

def tri_count():
    dg = bpy.context.evaluated_depsgraph_get(); t = 0
    for ob in bpy.context.scene.objects:
        if ob.type == 'MESH':
            me = ob.evaluated_get(dg).to_mesh(); me.calc_loop_triangles(); t += len(me.loop_triangles)
    return t

# ---------------------------------------------------------------- dress form
def ring_params(spec, z):
    for a, b in zip(spec, spec[1:]):
        if a[0] <= z <= b[0]:
            t = (z - a[0]) / (b[0] - a[0])
            return [a[i] + (b[i] - a[i]) * t for i in range(5)]
    return list(spec[0] if z < spec[0][0] else spec[-1])

def front_y(spec, x, z, power=2.6, pad=0.0):
    _, hx, hf, hb, yo = ring_params(spec, z)
    hx += pad; hf += pad
    u = min(abs(x) / hx, 0.999)
    return -(hf * (1 - u ** power) ** (1 / power)) + yo

TORSO = [
    (1.08, .150, .100, .100, 0), (1.10, .205, .135, .135, 0), (1.16, .225, .150, .145, 0),
    (1.26, .205, .135, .135, 0), (1.36, .165, .112, .115, 0), (1.44, .172, .125, .118, 0),
    (1.53, .200, .150, .128, 0), (1.62, .210, .140, .128, 0), (1.70, .215, .118, .118, .004),
    (1.75, .198, .100, .100, .004), (1.79, .150, .080, .080, 0), (1.815, .085, .060, .060, 0),
    (1.835, .060, .050, .050, 0), (1.90, .054, .047, .047, 0)]

def build_dress_form():
    reset(); MATS.clear()
    walnut = mat("DressFormWalnut", "#5a4330", .7)
    bronze = mat("DressFormBronze", "#a47c45", .45, .6)
    cream = mat("DressFormLinen", "#d9ccab", .9)
    indigo = mat("DressFormIndigo", "#46557c", .85)
    lapel_m = mat("DressFormLapel", "#e6dabd", .85)
    tape_m = mat("DressFormTape", "#d8b24c", .7)
    parts = []
    base = lathe("Base", walnut, [(.300, .060), (.312, .072), (.312, .098), (.296, .118), (.215, .145), (.130, .180), (.078, .208), (.062, .232)], 32)
    paint(base, .78, 1.02, seed=1); parts.append(base)
    for i in range(3):  # small levelling feet
        a = 2 * math.pi * i / 3 + .5
        f = cyl("Foot", bronze, (math.cos(a) * .26, math.sin(a) * .26, .045), .035, .03, 16, .006)
        paint(f, .85, 1.05, seed=2); parts.append(f)
    pole = lathe("Pole", bronze, [(.040, .228), (.046, .245), (.032, .268), (.026, .930), (.034, .960), (.050, .990), (.050, 1.030), (.034, 1.055), (.024, 1.080)], 20)
    paint(pole, .8, 1.08, seed=3); parts.append(pole)
    plate = lathe("HipPlate", walnut, [(.120, 1.066), (.142, 1.074), (.142, 1.088), (.120, 1.094)], 32)
    paint(plate, .8, 1.0, seed=4); parts.append(plate)
    torso = loft("Torso", cream, TORSO, 28)
    sub = torso.modifiers.new("Sub", 'SUBSURF'); sub.levels = 1; sub.render_levels = 1
    apply_all(torso); smooth(torso, 60); paint(torso, .80, 1.04, noise_amt=.05, seed=5); parts.append(torso)
    cap = lathe("NeckCap", walnut, [(.058, 1.895), (.072, 1.905), (.072, 1.928), (.052, 1.948), (.022, 1.952), (.036, 1.982), (.046, 2.022), (.036, 2.062), (.014, 2.084), (.004, 2.088)], 24)
    paint(cap, .78, 1.08, seed=6); parts.append(cap)
    # Waistcoat: a shell of the same loft, opened into a V-neck and armholes.
    vest_spec = [(z, hx + .008, hf + .010, hb + .008, yo) for z, hx, hf, hb, yo in TORSO if 1.15 <= z <= 1.76]
    vest_spec = [(1.17,) + tuple(ring_params(TORSO, 1.17)[1:])] + vest_spec
    vest_spec = [(s[0], s[1] + (.008 if s[0] == 1.17 else 0), s[2] + (.010 if s[0] == 1.17 else 0), s[3] + (.008 if s[0] == 1.17 else 0), s[4]) for s in vest_spec]
    vest = loft("Waistcoat", indigo, vest_spec, 28, cap_bottom=False, cap_top=False)
    bm = bmesh.new(); bm.from_mesh(vest.data)
    kill = []
    for f in bm.faces:
        c = f.calc_center_median()
        v_open = c.y < -0.02 and c.z > 1.40 and abs(c.x) < .018 + (c.z - 1.40) * .36
        arm = abs(c.x) > .178 and c.z > 1.58 and abs(c.y) < .095
        top = c.z > 1.735 and abs(c.x) < .14
        if v_open or arm or top: kill.append(f)
    bmesh.ops.delete(bm, geom=kill, context='FACES'); bm.to_mesh(vest.data); bm.free()
    sub = vest.modifiers.new("Sub", 'SUBSURF'); sub.levels = 1
    sol = vest.modifiers.new("Sol", 'SOLIDIFY'); sol.thickness = .010; sol.offset = 1; sol.use_rim_only = False
    apply_all(vest); smooth(vest, 60); paint(vest, .78, 1.05, noise_amt=.07, seed=7); parts.append(vest)
    # Lapels follow the V edge, sitting just proud of the waistcoat.
    for side in (-1, 1):
        bm = bmesh.new(); prev = None; n = 10
        for i in range(n + 1):
            z = 1.40 + .33 * i / n
            xi = side * (.018 + (z - 1.40) * .36)
            w = .012 + .026 * math.sin(math.pi * (i / n) ** .8) * (1 - .4 * i / n)
            xo = xi + side * w
            yi = front_y(TORSO, xi, z, pad=.022); yo2 = front_y(TORSO, xo, z, pad=.022)
            ring = [bm.verts.new((xi, yi, z)), bm.verts.new((xo, yo2, z))]
            if prev: bm.faces.new((prev[0], prev[1], ring[1], ring[0]) if side > 0 else (prev[1], prev[0], ring[0], ring[1]))
            prev = ring
        lap = obj_from_bm(bm, "Lapel", lapel_m)
        sol = lap.modifiers.new("Sol", 'SOLIDIFY'); sol.thickness = .008
        bevel(lap, .002, 1, 50); apply_all(lap); smooth(lap, 50); paint(lap, .88, 1.04, seed=8); parts.append(lap)
    for i, z in enumerate((1.215, 1.285, 1.355)):
        y = front_y(TORSO, 0, z, pad=.024)
        b = cyl("Button", bronze, (0, y, z), .013, .008, 14, .002, rot=(math.pi / 2, 0, 0))
        paint(b, .9, 1.1, seed=9 + i); parts.append(b)
    for side in (-1, 1):
        z = 1.265; x = side * .11
        w = box("PocketWelt", lapel_m, (x, front_y(TORSO, x, z, pad=.022) + .002, z), (.075, .006, .013), .002, 1, rot=(0, 0, -side * .25))
        paint(w, .9, 1.0, seed=12); parts.append(w)
    # Tape measure draped over the shoulders: a flat ribbon swept along a path.
    path = []; normals = []
    R = .088; z_top = 1.795
    fl = (-.07, front_y(TORSO, -.07, z_top, pad=.03)); fr = (.07, front_y(TORSO, .07, z_top, pad=.03))
    a0 = math.atan2(fl[1], fl[0]); a1 = math.atan2(fr[1], fr[0]) - 2 * math.pi
    for i in range(9):  # up the left front
        u = i / 8; z = 1.47 + (z_top - 1.47) * u; x = -.10 + (fl[0] + .10) * u
        path.append((x, front_y(TORSO, x, z, pad=.03), z)); normals.append(Vector((0, -1, 0)).lerp(Vector((0, 0, 1)), u * u * .6))
    for i in range(1, 16):  # around the back of the neck, lying on the shoulders
        u = i / 16; a = a0 + (a1 - a0) * u
        rr = math.hypot(*fl) + (R - math.hypot(*fl)) * math.sin(math.pi * u)
        path.append((rr * math.cos(a), rr * math.sin(a), z_top + .012 * math.sin(math.pi * u))); normals.append(Vector((0, 0, 1)))
    for i in range(9):  # down the right front, hanging a little lower
        u = i / 8; z = z_top - (z_top - 1.43) * u; x = fr[0] + (.105 - fr[0]) * u
        path.append((x, front_y(TORSO, x, z, pad=.03), z)); normals.append(Vector((0, 0, 1)).lerp(Vector((0, -1, 0)), 1 - (1 - u) ** 2 * .6 if u > 0 else .4))
    bm = bmesh.new(); prev = None
    for i, p in enumerate(path):
        p = Vector(p); nxt = Vector(path[min(i + 1, len(path) - 1)]); prv = Vector(path[max(i - 1, 0)])
        tan = (nxt - prv).normalized(); side_v = tan.cross(normals[i]).normalized() * .009
        ring = [bm.verts.new(p - side_v), bm.verts.new(p + side_v)]
        if prev: bm.faces.new((prev[0], prev[1], ring[1], ring[0]))
        prev = ring
    tape = obj_from_bm(bm, "TapeMeasure", tape_m)
    sol = tape.modifiers.new("Sol", 'SOLIDIFY'); sol.thickness = .003
    apply_all(tape); smooth(tape, 60); paint(tape, .9, 1.05, seed=13); parts.append(tape)
    print("DRESS_FORM_TRIS", tri_count())
    export(OUT + "tailor_dress_form.glb")
    bpy.ops.wm.save_as_mainfile(filepath="/workspace/settlement_midstyle/blender/tailor_dress_form.blend")

# ---------------------------------------------------------- Rook counter set
# Authored in RookReferenceArt-local space so the glb drops in at the art origin.
# Godot (x, y, z) == Blender (x, -y, z) after the glTF Y-up conversion.
TOP = 1.15  # counter dressed-stone top surface (Godot y)
def G(x, y, z): return (x, -z, y)

def rock(name, material, center, size, seed, subdiv=2):
    bm = bmesh.new(); bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=.5)
    for v in bm.verts:
        n = noise.noise(v.co * 2.3 + Vector((seed, seed * .7, seed * 1.3)))
        v.co *= 1 + .22 * n
        # Flat-ish chiselled facets: quantise the radius a little for a hand-cut read.
    bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
    ob = obj_from_bm(bm, name, material); ob.location = center
    apply_all(ob); smooth(ob, 38)
    return ob

def build_rook_counter():
    reset(); MATS.clear()
    teal = mat("RookLedgerTeal", "#426964", .75)
    pages = mat("RookPages", "#e2d5b2", .9)
    bronze = mat("RookBronze", "#aa8043", .5, .6)
    walnut = mat("RookTrayWalnut", "#5c412c", .75)
    plank_a = mat("RookTimberLight", "#9b7550", .8)
    plank_b = mat("RookTimberMid", "#7d5a3c", .8)
    twine = mat("RookTwine", "#bba57a", .9)
    stone = mat("RookStone", "#a49c8c", .85)
    iron = mat("RookScrap", "#6f777c", .55, .55)
    paper = mat("RookPlanPaper", "#ded0ae", .9)
    paper_core = mat("RookPlanCore", "#b7a47c", .9)
    ribbon = mat("RookRibbon", "#aa5a3a", .8)
    ink = mat("RookInk", "#2f2d29", .4)
    parts = []
    # --- Ledger: bound book with rounded spine, bronze corners and a ribbon marker.
    lx, lz, rot = -1.25, -1.45, math.radians(-7)
    led = []
    for i, y in enumerate((TOP + .007, TOP + .069)):
        led.append(box("LedgerBoard", teal, G(lx, y, lz), (.41, .32, .013), .005, 2))
    led.append(box("LedgerPages", pages, G(lx + .005, TOP + .038, lz + .006), (.39, .30, .050), .006, 2))
    led.append(cyl("LedgerSpine", teal, G(lx, TOP + .038, lz - .16), .038, .41, 16, .004, rot=(0, math.pi / 2, 0)))
    for x in (-.17, .17):
        led.append(cyl("SpineBand", bronze, G(lx + x, TOP + .038, lz - .16), .041, .018, 16, .003, rot=(0, math.pi / 2, 0)))
    for x in (-.185, .185):
        for y in (TOP + .007, TOP + .069):
            led.append(box("LedgerCorner", bronze, G(lx + x, y, lz + .14), (.045, .045, .017), .004, 1))
    led.append(box("LedgerRibbon", ribbon, G(lx + .06, TOP + .02, lz + .175), (.022, .07, .004), .001, 1, rot=(math.radians(-70), 0, 0)))
    ledger = join(led, "Ledger")
    for p in ledger.data.vertices: pass
    ledger.rotation_euler = (0, 0, rot); 
    # rotate around the ledger centre
    piv = Vector(G(lx, 0, lz)); ledger.location = (0, 0, 0)
    ledger.data.transform(Matrix.Translation(-piv)); ledger.data.transform(Matrix.Rotation(rot, 4, 'Z')); ledger.data.transform(Matrix.Translation(piv))
    ledger.rotation_euler = (0, 0, 0)
    paint(ledger, .8, 1.05, noise_amt=.05, seed=21); parts.append(ledger)
    # Inkwell + quill beside the ledger.
    well = lathe("Inkwell", ink, [(.032, TOP), (.040, TOP + .010), (.040, TOP + .040), (.022, TOP + .058), (.018, TOP + .070), (.022, TOP + .074)], 20, center=(0, 0, 0))
    well.data.transform(Matrix.Translation(Vector((-.93, 1.38, 0)))); paint(well, .8, 1.1, seed=22); parts.append(well)
    collar = cyl("InkCollar", bronze, (-.93, 1.38, TOP + .060), .026, .010, 18, .002); paint(collar, .9, 1.1, seed=23); parts.append(collar)
    quill = cyl("Quill", pages, (-.93 + .03, 1.38 - .02, TOP + .14), .006, .20, 8, 0, rot=(math.radians(18), math.radians(-22), 0), r2=.002)
    vane = box("QuillVane", pages, (-.93 + .055, 1.38 - .035, TOP + .19), (.026, .004, .11), .002, 1, rot=(math.radians(18), math.radians(-22), 0))
    q = join([quill, vane], "Quill"); paint(q, .9, 1.05, seed=24); parts.append(q)
    # --- Sample tray: timber bundle, stone chunk and scrap offcut (the three stock families).
    tx, tz = .98, -1.40
    tray = [box("TrayFloor", walnut, G(tx, TOP + .008, tz), (.62, .30, .016), .004, 1)]
    for dz in (-.14, .14): tray.append(box("TrayRim", walnut, G(tx, TOP + .028, tz + dz), (.62, .022, .04), .006, 2))
    for dx in (-.30, .30): tray.append(box("TrayEnd", walnut, G(tx + dx, TOP + .028, tz), (.022, .30, .04), .006, 2))
    trayo = join(tray, "SampleTray"); paint(trayo, .78, 1.05, seed=25); parts.append(trayo)
    base_y = TOP + .016
    planks = []
    for i, (dx, dy, m_) in enumerate(((-.03, 0, plank_a), (.03, 0, plank_b), (0, .036, plank_b))):
        planks.append(box("Plank", m_, G(tx - .19 + dx, base_y + .018 + dy, tz), (.056, .23, .034), .006, 2, rot=(0, 0, math.radians((i - 1) * 2.5))))
    for dz in (-.065, .065):
        band = bpy.data.objects.new("x", None)
        bm = bmesh.new()
        # Twine loop: a rounded rectangle tube around the bundle.
        pts = []; cx, cy = tx - .19, base_y + .036
        for k in range(20):
            a = 2 * math.pi * k / 20
            pts.append(Vector((cx + .064 * math.copysign(abs(math.cos(a)) ** .35, math.cos(a)), -(tz + dz), cy + .040 * math.copysign(abs(math.sin(a)) ** .35, math.sin(a)))))
        rings = []
        for k, p in enumerate(pts):
            t = (pts[(k + 1) % 20] - pts[k - 1]).normalized(); n1 = Vector((0, 1, 0)); n2 = t.cross(n1)
            rings.append([bm.verts.new(p + (n1 * math.cos(2 * math.pi * j / 6) + n2 * math.sin(2 * math.pi * j / 6)) * .006) for j in range(6)])
        for k in range(20):
            a_, b_ = rings[k], rings[(k + 1) % 20]
            for j in range(6): bm.faces.new((a_[j], a_[(j + 1) % 6], b_[(j + 1) % 6], b_[j]))
        tw = obj_from_bm(bm, "Twine", twine); bmesh.ops.recalc_face_normals
        smooth(tw, 80); planks.append(tw)
    bundle = join(planks, "TimberBundle"); paint(bundle, .8, 1.06, noise_amt=.07, seed=26); parts.append(bundle)
    r1 = rock("StoneChunk", stone, G(tx + .005, base_y + .045, tz - .01), (.15, .12, .095), 3.1)
    r2 = rock("StonePebble", stone, G(tx + .075, base_y + .025, tz + .075), (.07, .06, .05), 7.7, 1)
    stones = join([r1, r2], "StoneSample"); paint(stones, .74, 1.08, noise_amt=.10, seed=27); parts.append(stones)
    plate = box("ScrapPlate", iron, G(tx + .19, base_y + .030, tz), (.17, .20, .012), .003, 1, rot=(math.radians(14), math.radians(-18), math.radians(12)))
    bent = box("ScrapAngle", iron, G(tx + .21, base_y + .016, tz + .07), (.12, .03, .03), .003, 1, rot=(0, 0, math.radians(30)))
    bolt = cyl("ScrapBolt", iron, G(tx + .15, base_y + .012, tz - .08), .012, .05, 10, .002, rot=(0, math.pi / 2, 0))
    nut = cyl("ScrapNut", bronze, G(tx + .17, base_y + .012, tz - .08), .018, .012, 6, .002, rot=(0, math.pi / 2, 0))
    scrap = join([plate, bent, bolt, nut], "ScrapSample"); paint(scrap, .78, 1.1, noise_amt=.08, seed=28); parts.append(scrap)
    # --- Two rolled work plans with a curled outer lip and a ribbon tie.
    for i in range(2):
        x = .30 + i * .03; y = TOP + .055; z = -1.63 + i * .115
        ax = (0, math.pi / 2, 0)
        roll = cyl("PlanRoll", paper, G(x, y, z), .052, .46, 22, .004, rot=ax)
        core = cyl("PlanCore", paper_core, G(x, y, z), .030, .468, 16, .002, rot=ax)
        tie = cyl("PlanTie", ribbon, G(x, y, z), .055, .03, 22, .003, rot=ax)
        r = join([roll, core, tie], "PlanRoll%d" % i)
        paint(r, .84, 1.04, seed=29 + i); parts.append(r)
    print("ROOK_COUNTER_TRIS", tri_count())
    export(OUT + "rook_counter_stock.glb")
    bpy.ops.wm.save_as_mainfile(filepath="/workspace/settlement_midstyle/blender/rook_counter_stock.blend")

if __name__ == "__main__":
    import os, sys
    os.makedirs(OUT, exist_ok=True)
    which = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else ["dress", "rook"]
    if "dress" in which: build_dress_form()
    if "rook" in which: build_rook_counter()
