# Item 11 DETAIL PASS: mid-stylized dress form, Rook counter stock and hall reception desk.
# Blender 4.2, meter scale, Z-up (the glTF exporter converts to Godot Y-up).
# Every object has its modifiers and transforms applied before export, and each prop is
# joined into ONE mesh (one surface per material) to keep draw calls low.
#   python3 tools/blender_midstyle/make_textures.py /workspace/settlement_midstyle/tex
#   blender -b --factory-startup -P tools/blender_midstyle/build_midstyle.py -- [dress] [rook] [desk]
# The previous (style test) builder is in git history at 0ba385f.
import bpy, bmesh, math, random, os
from mathutils import Vector, Matrix, noise

OUT = "/workspace/settlement_midstyle/repo/assets/midstyle_test/"
TEX = os.environ.get("MIDSTYLE_TEX", "/workspace/settlement_midstyle/tex/")
BLEND = "/workspace/settlement_midstyle/blender/"
TAU = 2 * math.pi

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.unit_settings.system = 'METRIC'
    bpy.context.scene.unit_settings.scale_length = 1.0
    MATS.clear(); random.seed(11)

# ------------------------------------------------------------------ materials
MATS = {}
def mat(name, tex=None, rough=0.8, metal=0.0, hexcol="#ffffff", emit=None):
    """Base colour = texture (tint baked in) x painted vertex colour 'Col'."""
    if name in MATS: return MATS[name]
    m = bpy.data.materials.new(name); m.use_nodes = True; m.use_backface_culling = True
    nt = m.node_tree; bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    attr = nt.nodes.new("ShaderNodeVertexColor"); attr.layer_name = "Col"
    mix = nt.nodes.new("ShaderNodeMix"); mix.data_type = 'RGBA'; mix.blend_type = 'MULTIPLY'
    mix.inputs["Factor"].default_value = 1.0
    if tex:
        img = nt.nodes.new("ShaderNodeTexImage")
        img.image = bpy.data.images.load(TEX + tex + ".png", check_existing=True)
        nt.links.new(img.outputs["Color"], mix.inputs[6])
    else:
        h = hexcol.lstrip('#'); c = [(int(h[i:i + 2], 16) / 255) ** 2.2 for i in (0, 2, 4)]
        mix.inputs[6].default_value = (*c, 1); m.diffuse_color = (*c, 1)
    nt.links.new(attr.outputs["Color"], mix.inputs[7])
    nt.links.new(mix.outputs[2], bsdf.inputs["Base Color"])
    if emit:
        bsdf.inputs["Emission Color"].default_value = (*emit[0], 1)
        bsdf.inputs["Emission Strength"].default_value = emit[1]
    MATS[name] = m
    return m

# ------------------------------------------------------------------ mesh helpers
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
    mod.limit_method = 'ANGLE'; mod.angle_limit = math.radians(angle)
    return mod

def apply_all(ob):
    select_only(ob)
    for mod in list(ob.modifiers): bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

def smooth(ob, angle=35):
    select_only(ob); bpy.ops.object.shade_smooth_by_angle(angle=math.radians(angle))

def box(name, material, center, size, bev=0.01, segs=2, rot=(0, 0, 0)):
    bm = bmesh.new(); bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
    ob = obj_from_bm(bm, name, material); ob.rotation_euler = rot; ob.location = center
    if bev > 0: bevel(ob, bev, segs)
    apply_all(ob); smooth(ob)
    return ob

def cyl(name, material, center, r, h, segs=24, bev=0.006, rot=(0, 0, 0), r2=None, bsegs=2):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=segs, radius1=r, radius2=(r if r2 is None else r2), depth=h)
    ob = obj_from_bm(bm, name, material); ob.rotation_euler = rot; ob.location = center
    if bev > 0: bevel(ob, bev, bsegs)
    apply_all(ob); smooth(ob)
    return ob

def sphere(name, material, center, r, segs=10, rings=7, scale=(1, 1, 1)):
    bm = bmesh.new(); bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=rings, radius=r)
    bmesh.ops.scale(bm, vec=Vector(scale), verts=bm.verts)
    ob = obj_from_bm(bm, name, material); ob.location = center; apply_all(ob); smooth(ob, 80)
    return ob

def lathe(name, material, profile, segs=28, center=(0, 0, 0), wobble=0.0, lobes=0, lobe_amt=0.0):
    """profile: (radius, z) bottom->top; capped ends. Optional lobes (tomato/sack)."""
    bm = bmesh.new(); rings = []
    for r, z in profile:
        ring = []
        for i in range(segs):
            a = TAU * i / segs; rr = r
            if lobes: rr *= 1 + lobe_amt * math.cos(lobes * a)
            if wobble: rr *= 1 + wobble * noise.noise(Vector((math.cos(a) * 2, math.sin(a) * 2, z * 9)))
            ring.append(bm.verts.new((rr * math.cos(a), rr * math.sin(a), z)))
        rings.append(ring)
    for a, b in zip(rings, rings[1:]):
        for i in range(segs):
            j = (i + 1) % segs; bm.faces.new((a[i], a[j], b[j], b[i]))
    if profile[0][0] > 1e-4: bm.faces.new(list(reversed(rings[0])))
    if profile[-1][0] > 1e-4: bm.faces.new(rings[-1])
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = obj_from_bm(bm, name, material); ob.location = center
    apply_all(ob); smooth(ob, 50)
    return ob

def grid(name, material, rings, closed=True, cap_bottom=False, cap_top=False):
    """rings: list of lists of points (bottom->top)."""
    bm = bmesh.new(); vr = [[bm.verts.new(p) for p in ring] for ring in rings]
    n = len(rings[0])
    for a, b in zip(vr, vr[1:]):
        for i in range(n if closed else n - 1):
            j = (i + 1) % n; bm.faces.new((a[i], a[j], b[j], b[i]))
    if cap_bottom: bm.faces.new(list(reversed(vr[0])))
    if cap_top: bm.faces.new(vr[-1])
    return obj_from_bm(bm, name, material)

def frame_for(tan, up=Vector((0, 0, 1))):
    tan = tan.normalized(); side = tan.cross(up)
    if side.length < 1e-4: side = tan.cross(Vector((1, 0, 0)))
    side.normalize(); nup = side.cross(tan).normalized()
    return side, nup

def tube(name, material, pts, r, sides=6, closed=False, up=None, taper=None):
    pts = [Vector(p) for p in pts]; n = len(pts); bm = bmesh.new(); rings = []
    for i, p in enumerate(pts):
        if closed: tan = pts[(i + 1) % n] - pts[i - 1]
        else: tan = pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]
        side, nup = frame_for(tan, up if up is not None else Vector((0, 0, 1)))
        rr = r * (taper(i / max(n - 1, 1)) if taper else 1)
        rings.append([bm.verts.new(p + (side * math.cos(TAU * k / sides) + nup * math.sin(TAU * k / sides)) * rr) for k in range(sides)])
    for i in range(n if closed else n - 1):
        a, b = rings[i], rings[(i + 1) % n]
        for k in range(sides): bm.faces.new((a[k], a[(k + 1) % sides], b[(k + 1) % sides], b[k]))
    if not closed:
        bm.faces.new(list(reversed(rings[0]))); bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = obj_from_bm(bm, name, material); smooth(ob, 70)
    return ob

def sweep_rect(name, material, pts, w, h, up=Vector((0, 0, 1)), taper=None, bev=.004):
    """Rectangular section swept along a polyline (legs, handles)."""
    pts = [Vector(p) for p in pts]; n = len(pts); bm = bmesh.new(); rings = []
    for i, p in enumerate(pts):
        tan = pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]
        side, nup = frame_for(tan, up); s = taper(i / (n - 1)) if taper else 1
        rings.append([bm.verts.new(p + side * sx * w * s / 2 + nup * sy * h * s / 2) for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))])
    for a, b in zip(rings, rings[1:]):
        for k in range(4): bm.faces.new((a[k], a[(k + 1) % 4], b[(k + 1) % 4], b[k]))
    bm.faces.new(list(reversed(rings[0]))); bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = obj_from_bm(bm, name, material)
    if bev: bevel(ob, bev, 2, 50)
    apply_all(ob); smooth(ob, 40)
    return ob

def dashes(name, material, pts, normals, spacing=.016, length=.009, width=.0026, height=.0016):
    """Top-stitching: short thread dashes along a polyline lying on a surface."""
    pts = [Vector(p) for p in pts]; bm = bmesh.new()
    seglen = [(pts[i + 1] - pts[i]).length for i in range(len(pts) - 1)]
    total = sum(seglen); d = spacing * .5
    while d < total - spacing * .3:
        acc = 0
        for i, L in enumerate(seglen):
            if acc + L >= d:
                u = (d - acc) / max(L, 1e-9); p = pts[i].lerp(pts[i + 1], u)
                nrm = Vector(normals[i]).lerp(Vector(normals[i + 1]), u).normalized()
                tan = (pts[i + 1] - pts[i]).normalized(); side = tan.cross(nrm).normalized()
                c0 = p + nrm * height * .2; h = tan * length / 2; w = side * width / 2
                a0, a1 = bm.verts.new(c0 - h - w), bm.verts.new(c0 + h - w)
                r0, r1 = bm.verts.new(c0 - h * .8 + nrm * height), bm.verts.new(c0 + h * .8 + nrm * height)
                b0, b1 = bm.verts.new(c0 - h + w), bm.verts.new(c0 + h + w)
                bm.faces.new((r0, r1, a1, a0)); bm.faces.new((b0, b1, r1, r0))
                break
            acc += L
        d += spacing
    return obj_from_bm(bm, name, material)

def fixn(ob):
    """Recalculate outward normals (closed shells made by solidify)."""
    bm = bmesh.new(); bm.from_mesh(ob.data); bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(ob.data); bm.free(); return ob

def xform(ob, loc=(0, 0, 0), yaw=0.0, pitch=0.0, roll=0.0, pivot=(0, 0, 0)):
    M = Matrix.Translation(Vector(loc)) @ Matrix.Rotation(yaw, 4, 'Z') @ Matrix.Rotation(pitch, 4, 'Y') @ Matrix.Rotation(roll, 4, 'X') @ Matrix.Translation(-Vector(pivot))
    ob.data.transform(M); ob.data.update(); return ob

# ------------------------------------------------------------------ UVs
def uv_box(ob, tile=.5, grain=None):
    bm = bmesh.new(); bm.from_mesh(ob.data); uvl = bm.loops.layers.uv.verify()
    o1, o2 = random.random() * 3, random.random() * 3
    for f in bm.faces:
        n = f.normal; a = max(range(3), key=lambda i: abs(n[i])); axes = [i for i in range(3) if i != a]
        if grain is not None and grain in axes: ua = grain; va = axes[0] if axes[1] == grain else axes[1]
        else: ua, va = axes
        for l in f.loops: l[uvl].uv = (l.vert.co[ua] / tile + o1, l.vert.co[va] / tile + o2)
    bm.to_mesh(ob.data); bm.free(); return ob

def uv_cyl(ob, c=(0, 0), axis=2, tile=.3, radius=.05, cap_tex_full=False, cap_r=None):
    """Cylindrical projection around an axis; caps get planar (or 0..1 'end' mapping)."""
    bm = bmesh.new(); bm.from_mesh(ob.data); uvl = bm.loops.layers.uv.verify()
    a1, a2 = [i for i in range(3) if i != axis]
    for f in bm.faces:
        if abs(f.normal[axis]) > .75:
            for l in f.loops:
                co = l.vert.co
                if cap_tex_full:
                    rr = cap_r or radius
                    l[uvl].uv = ((co[a1] - c[0]) / (2 * rr) + .5, (co[a2] - c[1]) / (2 * rr) + .5)
                else: l[uvl].uv = (co[a1] / tile, co[a2] / tile)
            continue
        angs = [math.atan2(l.vert.co[a2] - c[1], l.vert.co[a1] - c[0]) for l in f.loops]
        if max(angs) - min(angs) > math.pi: angs = [x + TAU if x < 0 else x for x in angs]
        for l, an in zip(f.loops, angs): l[uvl].uv = (l.vert.co[axis] / tile, an * radius / tile)
    bm.to_mesh(ob.data); bm.free(); return ob

def uv_rect(ob, origin, udir, vdir, usize, vsize):
    bm = bmesh.new(); bm.from_mesh(ob.data); uvl = bm.loops.layers.uv.verify()
    o, u, v = Vector(origin), Vector(udir).normalized(), Vector(vdir).normalized()
    for f in bm.faces:
        for l in f.loops:
            d = l.vert.co - o; l[uvl].uv = (d.dot(u) / usize + .5, d.dot(v) / vsize + .5)
    bm.to_mesh(ob.data); bm.free(); return ob

ATLAS = ["nails", "linseed", "timber", "rook", "ledger", "guests", "spirit", "hinge"]
def atlas_uv(ob, key):
    """Remap 0..1 UVs into this label's cell of labels_atlas.png (2 x 4 cells)."""
    i = ATLAS.index(key); col, row = i % 2, i // 2
    for d in ob.data.uv_layers.active.data:
        u, v = d.uv; d.uv = ((col + min(max(u, 0), 1)) / 2, 1 - (row + 1) / 4 + min(max(v, 0), 1) / 4)
    return ob

# ------------------------------------------------------------------ vertex paint
def paint(ob, base=.84, top=1.03, axis=2, noise_amt=.05, edge=.16, cavity=.16, seed=0.0, jitter=.035, small=4e-4):
    """Hand-painted vertex colour: value ramp, soft dirt noise, lit worn edges, dark creases.
    Edge light only goes on small faces (bevels, rims) so it reads as a painted highlight."""
    me = ob.data
    if "Col" not in me.color_attributes: me.color_attributes.new("Col", 'BYTE_COLOR', 'CORNER')
    col = me.color_attributes["Col"]
    nv = len(me.vertices); conv = [0.0] * nv; cnt = [0] * nv
    for e in me.edges:
        a, b = e.vertices; va, vb = me.vertices[a], me.vertices[b]; d = va.co - vb.co; L = d.length
        if L < 1e-7: continue
        d /= L; conv[a] += va.normal.dot(d); conv[b] -= vb.normal.dot(d); cnt[a] += 1; cnt[b] += 1
    conv = [conv[i] / cnt[i] if cnt[i] else 0 for i in range(nv)]
    zs = [v.co[axis] for v in me.vertices] or [0]; lo, hi = min(zs), max(zs); span = max(hi - lo, 1e-4)
    jit = (random.random() - .5) * 2 * jitter
    for poly in me.polygons:
        is_small = poly.area < small
        for li in poly.loop_indices:
            v = me.vertices[me.loops[li].vertex_index]
            t = (v.co[axis] - lo) / span
            n = noise.noise(v.co * 7.0 + Vector((seed, seed * .3, seed * .7)))
            c = conv[v.index] * 3.0
            k = base + (top - base) * t + n * noise_amt + jit
            if c > 0 and is_small: k += edge * min(1.0, c)
            elif c < 0: k += cavity * max(-1.0, c)
            k = max(.25, min(1.25, k))
            col.data[li].color = (k, k, k, 1.0)
    return ob

def finish(ob, uv=None, **pk):
    """UV + paint one part. uv: ('box', tile, grain) | ('cyl', c, axis, tile, r) | None."""
    if uv is not None:
        if uv[0] == 'box': uv_box(ob, *uv[1:])
        elif uv[0] == 'cyl': uv_cyl(ob, *uv[1:])
    paint(ob, **pk); return ob

def join(objs, name):
    select_only(objs[0])
    for o in objs[1:]: o.select_set(True)
    bpy.ops.object.join(); ob = bpy.context.active_object; ob.name = name
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return ob

def join_scene(name):
    obs = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    for o in obs:  # every part needs the same UV layer name for a clean join
        if not o.data.uv_layers: uv_box(o, .5)
    return join(obs, name)

def export(path):
    bpy.ops.object.select_all(action='SELECT')
    # glTF + .bin with JPEG textures in a shared textures/ folder: Godot imports each texture
    # once (VRAM-compressed) and props that share a material texture share the file.
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLTF_SEPARATE', export_texture_dir="textures",
                              use_selection=True, export_apply=True, export_yup=True, export_vertex_color='MATERIAL',
                              export_all_vertex_colors=False, export_normals=True, export_materials='EXPORT',
                              export_image_format='JPEG', export_jpeg_quality=90)

def tri_count():
    dg = bpy.context.evaluated_depsgraph_get(); t = 0
    for ob in bpy.context.scene.objects:
        if ob.type == 'MESH':
            me = ob.evaluated_get(dg).to_mesh(); me.calc_loop_triangles(); t += len(me.loop_triangles)
    return t

def report(tag, path):
    if os.environ.get("MIDSTYLE_BREAKDOWN"):
        agg = {}
        for o in bpy.context.scene.objects:
            if o.type == 'MESH':
                o.data.calc_loop_triangles(); k = o.name.split('.')[0]; agg[k] = agg.get(k, 0) + len(o.data.loop_triangles)
        print("BREAKDOWN", sorted(agg.items(), key=lambda kv: -kv[1]))
    ob = join_scene(tag)
    print(tag + "_TRIS", tri_count(), "MATERIALS", len(ob.data.materials))
    export(OUT + path + ".gltf")
    bpy.ops.wm.save_as_mainfile(filepath=BLEND + path + ".blend")

# ================================================================ dress form
P = 2.6
TORSO = [
    (1.08, .150, .100, .100, 0), (1.10, .205, .135, .135, 0), (1.16, .225, .150, .145, 0),
    (1.26, .205, .135, .135, 0), (1.36, .165, .112, .115, 0), (1.44, .172, .125, .118, 0),
    (1.53, .200, .150, .128, 0), (1.62, .210, .140, .128, 0), (1.70, .215, .118, .118, .004),
    (1.75, .198, .100, .100, .004), (1.79, .150, .080, .080, 0), (1.815, .085, .060, .060, 0),
    (1.835, .060, .050, .050, 0), (1.90, .054, .047, .047, 0)]

def cr(spec, z):
    zs = [s[0] for s in spec]
    if z <= zs[0]: return list(spec[0][1:])
    if z >= zs[-1]: return list(spec[-1][1:])
    i = max(k for k in range(len(zs) - 1) if zs[k] <= z)
    Pk = lambda k: spec[max(0, min(len(spec) - 1, k))]
    z0, z1 = zs[i], zs[i + 1]; t = (z - z0) / (z1 - z0); out = []
    for c in range(1, 5):
        p0, p1, p2, p3 = Pk(i - 1)[c], Pk(i)[c], Pk(i + 1)[c], Pk(i + 2)[c]
        m1 = (p2 - p0) / max(z1 - Pk(i - 1)[0], 1e-6) * (z1 - z0) * .8
        m2 = (p3 - p1) / max(Pk(i + 2)[0] - z0, 1e-6) * (z1 - z0) * .8
        out.append((2 * t ** 3 - 3 * t ** 2 + 1) * p1 + (t ** 3 - 2 * t ** 2 + t) * m1 + (-2 * t ** 3 + 3 * t ** 2) * p2 + (t ** 3 - t ** 2) * m2)
    return out

def sp(v, e): return math.copysign(abs(v) ** e, v)

def surf(t, z, pad=0.0):
    hx, hf, hb, yo = cr(TORSO, z); c, s = math.cos(t), math.sin(t)
    return Vector(((hx + pad) * sp(c, 2 / P), ((hf if s < 0 else hb) + pad) * sp(s, 2 / P) + yo, z))

def surf_n(t, z, pad=0.0):
    a = surf(t + .01, z, pad) - surf(t - .01, z, pad); b = surf(t, z + .01, pad) - surf(t, z - .01, pad)
    return a.cross(b).normalized()

def t_front(x, z, pad=0.0):
    hx = cr(TORSO, z)[0] + pad; c = min(abs(x) / hx, .999) ** (P / 2)
    return (TAU - math.acos(c)) if x >= 0 else (math.pi + math.acos(c))

def t_back(x, z, pad=0.0):
    hx = cr(TORSO, z)[0] + pad; c = min(abs(x) / hx, .999) ** (P / 2)
    return math.acos(c) if x >= 0 else (math.pi - math.acos(c))

VEST_PAD, VEST_TOP, VEST_BOT = .012, 1.785, 1.17
def v_gap(z):  # half-width of the front opening (V-neck above 1.40, cut-away points below 1.20)
    if z > 1.40: return .018 + (z - 1.40) * .36
    if z < 1.20: return .003 + (1.20 - z) * .55
    return .003
def hem_drop(t):
    ph = abs(((t - 1.5 * math.pi + math.pi) % TAU) - math.pi)  # angle from front centre
    return .055 * max(0.0, 1 - ph / 1.0) ** 1.6

def vest_point(i, j, NI, NJ, pad=VEST_PAD):
    s = j / NJ; zn = VEST_BOT + (VEST_TOP - VEST_BOT) * s
    g = v_gap(zn); t0 = t_front(g, zn, pad); t1 = t_front(-g, zn, pad) + TAU
    t = t0 + (t1 - t0) * i / NI
    z = zn - hem_drop(t) * (1 - s) ** 1.3
    return t, z

def place_on(ob, p, nrm):
    ob.data.transform(Matrix.Translation(p) @ nrm.to_track_quat('Z', 'Y').to_matrix().to_4x4()); return ob

def build_dress_form():
    reset()
    walnut = mat("FormWalnut", "walnut", .62); walnut_d = mat("FormWalnutDark", "walnut_dark", .65)
    bronze = mat("FormBronze", "bronze", .42, .65); linen = mat("FormLinen", "linen", .92)
    indigo = mat("FormWoolIndigo", "wool_indigo", .88); cream = mat("FormWoolCream", "wool_cream", .85)
    tape_m = mat("FormTape", "tape", .7); thread = mat("FormThread", "thread_gold", .7)
    tomato = mat("FormCushion", "tomato", .85); leaf = mat("FormCushionLeaf", "leaf_green", .85)
    pinred = mat("FormPinHeadRed", hexcol="#c23a2c", rough=.35); pinblue = mat("FormPinHeadBlue", hexcol="#3b62b0", rough=.35)
    steel = mat("FormPinSteel", hexcol="#c9cdd0", rough=.3, metal=.9); chalk = mat("FormChalk", "chalk_blue", .95)

    # --- tripod base with curved walnut legs, bronze ferrules and casters
    hub = lathe("Hub", walnut, [(.050, .170), (.075, .185), (.082, .215), (.070, .245), (.058, .262), (.062, .278), (.045, .300)], 24)
    finish(hub, ('cyl', (0, 0), 2, .25, .07), base=.8, top=1.0, seed=1)
    for i in range(3):
        a = TAU * i / 3 + math.pi / 2
        d = Vector((math.cos(a), math.sin(a), 0)); pts = []
        for k in range(9):
            u = k / 8; r = .05 + .22 * u; z = .235 - .16 * math.sin(u * math.pi / 2) ** 1.4 - .01 * u
            pts.append(d * r + Vector((0, 0, z)))
        leg = sweep_rect("Leg", walnut, pts, .046, .040, taper=lambda u: 1 - .3 * u, bev=.006)
        finish(leg, ('box', .35, None), base=.8, top=1.0, seed=2 + i)
        tip = d * .272 + Vector((0, 0, .064))
        fer = cyl("Ferrule", bronze, tip, .019, .03, 10, .002, bsegs=1); finish(fer, None, base=.9, top=1.05, seed=5)
        fork = box("CasterFork", bronze, tip - Vector((0, 0, .028)), (.012, .03, .03), .003, 1, rot=(0, 0, a)); finish(fork, ('box', .2), base=.85, seed=6)
        wheel = cyl("Caster", walnut_d, tip - Vector((0, 0, .042)), .022, .014, 10, .002, rot=(math.pi / 2, 0, a), bsegs=1); finish(wheel, ('box', .2), base=.7, top=.9, seed=7)
    pole = lathe("Pole", bronze, [(.034, .295), (.040, .310), (.026, .330), (.022, .900), (.030, .915), (.036, .935), (.036, .975), (.030, .990), (.022, 1.005), (.020, 1.062)], 18)
    finish(pole, ('cyl', (0, 0), 2, .3, .03), base=.82, top=1.05, seed=8)
    knob_stem = cyl("WingStem", bronze, (0, -.050, .955), .007, .04, 8, .0, rot=(math.pi / 2, 0, 0)); finish(knob_stem, None, base=.9, seed=9)
    wing = box("WingScrew", bronze, (0, -.074, .955), (.045, .008, .022), .004, 2); finish(wing, ('box', .2), base=.9, seed=10)
    plate = lathe("HipPlate", walnut, [(.050, 1.050), (.118, 1.058), (.142, 1.066), (.146, 1.076), (.142, 1.086), (.120, 1.094)], 32)
    finish(plate, ('cyl', (0, 0), 2, .3, .13), base=.8, top=1.02, seed=11)
    trim = lathe("HipTrim", bronze, [(.146, 1.069), (.149, 1.072), (.149, 1.080), (.146, 1.083)], 32); finish(trim, None, base=.9, seed=12)

    # --- torso: smooth Catmull-Rom loft of the old profile, linen weave texture
    NS = 32; rings = []; zs = []
    z = 1.08
    while z < 1.90: zs.append(z); z += .019 if z < 1.70 else .01
    zs.append(1.90)
    for z in zs: rings.append([surf(TAU * i / NS, z) for i in range(NS)])
    torso = grid("Torso", linen, rings, cap_bottom=True, cap_top=True); smooth(torso, 70)
    finish(torso, ('cyl', (0, 0), 2, .25, .18), base=.84, top=1.02, noise_amt=.04, seed=13)
    # princess seams (front + back) and side seams as piped cords
    for side in (-1, 1):
        for back in (False, True):
            pts = []; z = 1.09
            while z <= 1.80:
                hx = cr(TORSO, z)[0]; x = side * hx * (.40 + .12 * math.sin((z - 1.09) / .71 * math.pi))
                t = t_back(x, z) if back else t_front(x, z); pts.append(surf(t, z, .0015)); z += .03
            s = tube("PrincessSeam", linen, pts, .0028, 4); finish(s, ('box', .2), base=.74, top=.9, edge=0, seed=14)
        pts = [surf(0 if side > 0 else math.pi, z, .0015) for z in [1.09 + k * .03 for k in range(23)]]
        s = tube("SideSeam", linen, pts, .0026, 4); finish(s, ('box', .2), base=.74, top=.9, edge=0, seed=15)
    neck_pts = [surf(TAU * k / 28, 1.80, .0012) for k in range(28)]
    s = tube("NeckSeam", linen, neck_pts, .003, 5, closed=True); finish(s, ('box', .2), base=.74, top=.9, edge=0, seed=16)
    # shoulder arm plates (walnut rim, linen face)
    for side in (-1, 1):
        x = side * (cr(TORSO, 1.665)[0] - .004)
        S = Matrix.Translation((x, -.008, 1.665)) @ Matrix.Scale(1.25, 4, (0, 0, 1)) @ Matrix.Translation((-x, .008, -1.665))
        rim = cyl("ArmPlateRim", walnut, (x, -.008, 1.665), .052, .012, 18, .003, rot=(0, math.pi / 2, 0)); rim.data.transform(S)
        finish(rim, ('cyl', (0, 0), 0, .2, .06), base=.8, seed=17)
        face = cyl("ArmPlate", linen, (x + side * .007, -.008, 1.665), .044, .003, 18, 0, rot=(0, math.pi / 2, 0)); face.data.transform(S)
        finish(face, ('box', .2), base=.9, seed=18)
    cap = lathe("NeckCap", walnut, [(.052, 1.892), (.068, 1.900), (.072, 1.912), (.066, 1.920), (.072, 1.928), (.060, 1.944), (.024, 1.952),
                                    (.020, 1.962), (.034, 1.976), (.046, 2.010), (.046, 2.024), (.034, 2.052), (.016, 2.072), (.022, 2.080), (.014, 2.092), (.003, 2.096)], 24)
    finish(cap, ('cyl', (0, 0), 2, .2, .05), base=.8, top=1.05, seed=19)
    ring = lathe("NeckRing", bronze, [(.069, 1.913), (.074, 1.915), (.074, 1.925), (.069, 1.927)], 24); finish(ring, None, base=.95, seed=20)

    # --- waistcoat: exact V-neck, pointed fronts, oval armholes; wool twill
    NI, NJ = 38, 24
    bm = bmesh.new(); vg = {}
    for j in range(NJ + 1):
        for i in range(NI + 1):
            t, z = vest_point(i, j, NI, NJ); vg[i, j] = bm.verts.new(surf(t, z, VEST_PAD))
    for j in range(NJ):
        for i in range(NI):
            t, z = vest_point(i + .5, j + .5, NI, NJ)
            dside = min(abs(((t + math.pi) % TAU) - math.pi), abs((t % TAU) - math.pi))  # angle to the side (t=0 or pi)
            if (dside / .62) ** 2 + ((z - 1.745) / .175) ** 2 < 1: continue
            bm.faces.new((vg[i, j], vg[i + 1, j], vg[i + 1, j + 1], vg[i, j + 1]))
    loose = [v for v in bm.verts if not v.link_faces]; bmesh.ops.delete(bm, geom=loose, context='VERTS')
    tz = {}
    for (i, j), v in vg.items():
        if v.is_valid: tz[v] = vest_point(i, j, NI, NJ)
    for v in list(tz):
        if not v.is_boundary: continue
        t, z = tz[v]; tw = t % TAU
        ts = 0.0 if (tw < math.pi / 2 or tw > 1.5 * math.pi) else math.pi
        d = ((tw - ts + math.pi) % TAU) - math.pi; dz = z - 1.745
        e = math.sqrt((d / .62) ** 2 + (dz / .175) ** 2)
        if 1e-6 < e < 1.45 and abs(d) < .9: v.co = surf(ts + d / e, 1.745 + dz / e, VEST_PAD)
    bnd = [e for e in bm.edges if e.is_boundary]; adj = {}
    for e in bnd:
        a, b = e.verts; adj.setdefault(a, []).append(b); adj.setdefault(b, []).append(a)
    loops = []; seen = set()
    for start in adj:
        if start in seen: continue
        loop = [start]; seen.add(start); prev = None; cur = start
        while True:
            nxt = [v for v in adj[cur] if v is not prev and v not in seen]
            if not nxt: break
            prev, cur = cur, nxt[0]; loop.append(cur); seen.add(cur)
        loops.append([v.co.copy() for v in loop])
    vest = obj_from_bm(bm, "Waistcoat", indigo)
    sol = vest.modifiers.new("Sol", 'SOLIDIFY'); sol.thickness = .006; sol.offset = -1
    bevel(vest, .0015, 1, 50); apply_all(vest); fixn(vest); smooth(vest, 60)
    finish(vest, ('cyl', (0, 0), 2, .2, .18), base=.80, top=1.02, noise_amt=.06, seed=21)
    for k, lp in enumerate(loops):
        if len(lp) < 6: continue
        pts = [p * (1 - .003 / max(Vector((p.x, p.y, 0)).length, .01)) if False else p for p in lp[::2]]
        cord = tube("Binding", indigo, pts, .0042, 5, closed=True); finish(cord, ('box', .1), base=.62, top=.8, edge=.1, seed=22 + k)
    hem_pts = []; hem_n = []
    for i in range(0, NI + 1):
        t, z = vest_point(i, .45, NI, NJ); hem_pts.append(surf(t, z, VEST_PAD)); hem_n.append(surf_n(t, z, VEST_PAD))
    st = dashes("HemStitch", thread, hem_pts, hem_n); finish(st, None, base=.95, top=1.0, edge=0, seed=30)

    # --- lapels with a gorge notch, cream twill, stitched edge
    LW = [(0, .010), (.25, .024), (.55, .036), (.72, .041), (.76, .022), (.80, .021), (.83, .036), (1.0, .020)]
    def lw(u):
        for (u0, w0), (u1, w1) in zip(LW, LW[1:]):
            if u0 <= u <= u1: return w0 + (w1 - w0) * (u - u0) / (u1 - u0)
        return LW[-1][1]
    for side in (-1, 1):
        rows = []; spts = []; snrm = []; n = 18
        for r in range(n + 1):
            u = r / n; z = 1.40 + .335 * u; xi = side * (v_gap(z) - .002); w = lw(u)
            row = []
            for c in range(4):
                x = xi + side * w * c / 3; t = t_front(x, z, .0135); row.append(surf(t, z, .0135))
            rows.append(row if side > 0 else list(reversed(row)))
            xs = xi + side * (w - .0055); ts = t_front(xs, z, .0175); spts.append(surf(ts, z, .0172)); snrm.append(surf_n(ts, z, .0172))
        lap = grid("Lapel", cream, rows, closed=False)
        sol = lap.modifiers.new("Sol", 'SOLIDIFY'); sol.thickness = .004; sol.offset = 1
        bevel(lap, .0015, 1, 50); apply_all(lap); fixn(lap); smooth(lap, 50)
        finish(lap, ('box', .15, 2), base=.86, top=1.02, seed=31 + side)
        st = dashes("LapelStitch", thread, spts, snrm, spacing=.013, length=.0075); finish(st, None, base=.75, top=.85, edge=0, seed=33)
    for k, z in enumerate((1.205, 1.255, 1.305, 1.355)):
        t = t_front(0.0, z, VEST_PAD); p = surf(t, z, VEST_PAD + .002); nrm = surf_n(t, z, VEST_PAD)
        b = lathe("Button", bronze, [(.0001, 0), (.0115, 0), (.0125, .002), (.011, .004), (.007, .0028), (.0001, .0028)], 10)
        place_on(b, p, nrm); finish(b, None, base=.92, top=1.08, axis=1, seed=40 + k)
    for (xc, zc, w, h, tilt) in ((.112, 1.262, .082, .030, .10), (-.112, 1.262, .082, .030, -.10), (-.150, 1.545, .066, .016, -.18)):
        rows = []; spts = []; snrm = []
        for r in range(3):
            zz = zc + h * (r / 2 - .5); row = []
            for c in range(9):
                x = xc + w * (c / 8 - .5); z2 = zz + tilt * (x - xc); t = t_front(x, z2, .0145)
                row.append(surf(t, z2, .0145 + .0012 * math.sin(math.pi * c / 8)))
            rows.append(row)
        for c in range(9):
            x = xc + w * (c / 8 - .5) * .9; z2 = zc - h * .32 + tilt * (x - xc); t = t_front(x, z2, .0185)
            spts.append(surf(t, z2, .0185)); snrm.append(surf_n(t, z2, .0185))
        fl = grid("PocketFlap", indigo, rows, closed=False)
        sol = fl.modifiers.new("Sol", 'SOLIDIFY'); sol.thickness = .004; sol.offset = 1
        bevel(fl, .0015, 1, 50); apply_all(fl); fixn(fl); smooth(fl, 50); finish(fl, ('box', .1), base=.78, top=.95, seed=50 + xc)
        st = dashes("PocketStitch", thread, spts, snrm, spacing=.011, length=.006); finish(st, None, base=.95, edge=0, seed=51)

    # --- tape measure draped round the neck: printed ribbon + brass end tabs
    path = []
    for k in range(10):
        u = k / 9; z = 1.47 + (1.785 - 1.47) * u; x = -.105 + .03 * u; path.append((t_front(x, z, .02), z, .02))
    ta, tb = t_front(-.075, 1.798, .007), t_front(.075, 1.798, .007) - TAU
    for k in range(1, 18):
        u = k / 18; path.append((ta + (tb - ta) * u, 1.798 + .014 * math.sin(math.pi * u), .007))
    for k in range(10):
        u = k / 9; z = 1.785 - (1.785 - 1.42) * u; x = .075 + .03 * u; path.append((t_front(x, z, .02), z, .02))
    P3 = [surf(*q) for q in path]; N3 = [surf_n(*q) for q in path]
    bm = bmesh.new(); uvl = bm.loops.layers.uv.verify(); acc = 0.0; vrows = []
    for i, p in enumerate(P3):
        tan = (P3[min(i + 1, len(P3) - 1)] - P3[max(i - 1, 0)]).normalized()
        side_v = tan.cross(N3[i]).normalized() * .0095
        if i: acc += (p - P3[i - 1]).length
        vrows.append((bm.verts.new(p - side_v), bm.verts.new(p + side_v), acc))
    for (a0, a1, u0), (b0, b1, u1) in zip(vrows, vrows[1:]):
        f = bm.faces.new((a0, a1, b1, b0))
        for l, uv in zip(f.loops, ((u0 / .1, 0), (u0 / .1, 1), (u1 / .1, 1), (u1 / .1, 0))): l[uvl].uv = uv
    tape = obj_from_bm(bm, "TapeMeasure", tape_m)
    sol = tape.modifiers.new("Sol", 'SOLIDIFY'); sol.thickness = .0018
    apply_all(tape); fixn(tape); smooth(tape, 60); paint(tape, .95, 1.02, edge=0, cavity=.05, seed=60)
    for (p, q, nrm) in ((P3[0], P3[1], N3[0]), (P3[-1], P3[-2], N3[-1])):
        tab = box("TapeTab", bronze, (0, 0, 0), (.021, .022, .004), .001, 1)
        place_on(tab, p + (p - q).normalized() * .008 + nrm * .001, nrm); finish(tab, None, base=.95, seed=61)

    # --- tomato pin cushion on the right shoulder, pins in it and in the waistcoat
    cush = lathe("PinCushion", tomato, [(.0001, 0), (.022, .002), (.033, .010), (.036, .018), (.031, .027), (.018, .033), (.0001, .035)], 16, lobes=8, lobe_amt=.09)
    finish(cush, None, base=.82, top=1.05, edge=.08, seed=70)
    extra = []
    for k in range(5):
        a = TAU * k / 5
        lf = box("Leaf", leaf, (math.cos(a) * .012, math.sin(a) * .012, .036), (.022, .008, .003), .001, 1, rot=(0, -.25, a))
        finish(lf, None, base=.9, seed=71); extra.append(lf)
    stem = cyl("Stem", leaf, (0, 0, .042), .003, .012, 6, 0); finish(stem, None, base=.8, seed=72); extra.append(stem)
    for k in range(7):
        a = TAU * k / 7 + .3; el = .45 + .25 * (k % 3) / 2
        d = Vector((math.cos(a) * math.cos(el), math.sin(a) * math.cos(el), math.sin(el)))
        bp = Vector((d.x * .030, d.y * .030, .018 + d.z * .016))
        sh = cyl("PinShank", steel, (0, 0, .008), .0011, .018, 5, 0); place_on(sh, bp, d)
        hd = sphere("PinHead", pinred if k % 2 else pinblue, (0, 0, .018), .0042, 6, 4); place_on(hd, bp, d)
        finish(sh, None, base=1, edge=0, seed=73); finish(hd, None, base=.95, edge=0, seed=74); extra += [sh, hd]
    group = join([cush] + extra, "Cushion")
    q = (t_front(-.128, 1.786), 1.786, -.002); place_on(group, surf(*q), (surf_n(*q) + Vector((0, 0, .9))).normalized())
    for k, (x, z, head) in enumerate(((-.150, 1.625, pinred), (-.162, 1.598, pinblue), (-.140, 1.660, pinred), (.150, 1.205, pinblue), (.165, 1.235, pinred))):
        t = t_front(x, z, VEST_PAD); p = surf(t, z, VEST_PAD); nrm = surf_n(t, z, VEST_PAD)
        d = (nrm + Vector((0, 0, .5 if k % 2 else -.3)) + Vector((.3, 0, 0))).normalized()
        sh = cyl("PinShank", steel, (0, 0, .004), .0011, .016, 5, 0); hd = sphere("PinHead", head, (0, 0, .013), .0042, 6, 4)
        for o in (sh, hd): place_on(o, p, d); finish(o, None, base=.95, edge=0, seed=80 + k)
    report("DRESS_FORM", "tailor_dress_form")

# ================================================================ Rook counter set
# Authored in RookReferenceArt-local space so the glb drops in at the art origin.
# Godot (x, y, z) == Blender (x, -z, y) after the glTF Y-up conversion.
TOP = 1.15
def G(x, y, z): return (x, -z, y)

def rock(name, material, size, seed, subdiv=2):
    bm = bmesh.new(); bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=.5)
    for v in bm.verts:
        v.co *= 1 + .22 * noise.noise(v.co * 2.3 + Vector((seed, seed * .7, seed * 1.3)))
        if v.co.z < -.25: v.co.z = -.25 - (v.co.z + .25) * .25  # flat-ish underside so it sits
    bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
    ob = obj_from_bm(bm, name, material); apply_all(ob); smooth(ob, 28)
    return ob

def label(name, material, key, center, w, h, normal_axis='-y', thick=.0015, rot=(0, 0, 0)):
    """Paper label: thin box whose front face shows the whole label texture."""
    sz = {'-y': (w, thick, h), 'z': (w, h, thick)}[normal_axis]
    ob = box(name, material, (0, 0, 0), sz, 0, 1)
    if normal_axis == '-y': uv_rect(ob, (0, 0, 0), (1, 0, 0), (0, 0, 1), w, h)
    else: uv_rect(ob, (0, 0, 0), (1, 0, 0), (0, 1, 0), w, h)
    atlas_uv(ob, key); paint(ob, .95, 1.0, edge=0, cavity=0, noise_amt=.02)
    M = Matrix.Translation(Vector(center)) @ Matrix.Rotation(rot[2], 4, 'Z') @ Matrix.Rotation(rot[1], 4, 'Y') @ Matrix.Rotation(rot[0], 4, 'X')
    ob.data.transform(M); return ob

def nail(name, iron, p, d, length=.045):
    d = Vector(d).normalized(); R = d.to_track_quat('Z', 'Y').to_matrix().to_4x4()
    sh = cyl(name, iron, (0, 0, length / 2), .0018, length, 5, 0, r2=.0008)
    hd = cyl(name + "Head", iron, (0, 0, length + .001), .0045, .002, 8, 0)
    for o in (sh, hd): o.data.transform(Matrix.Translation(Vector(p)) @ R); finish(o, None, base=.85, edge=.1, seed=random.random() * 9)
    return [sh, hd]

def build_rook_counter():
    reset()
    teal = mat("RookBookcloth", "bookcloth_teal", .8); pages = mat("RookPageEdge", "page_edge", .9)
    bronze = mat("RookBronze", "bronze", .45, .65); walnut = mat("RookWalnut", "walnut", .7)
    pine = mat("RookCratePine", "crate_pine", .85); plank_a = mat("RookTimberLight", "timber_light", .8)
    plank_b = mat("RookTimberMid", "timber_mid", .8); endg = mat("RookEndGrain", "end_grain", .85)
    twine = mat("RookTwine", "twine", .95); stone = mat("RookStone", "stone", .9)
    iron = mat("RookIron", "iron", .6, .5); paper = mat("RookPlanPaper", "plan_paper", .9)
    plan_end = mat("RookPlanEnd", "plan_end", .9); ribbon = mat("RookRibbon", "ribbon_red", .8)
    ink = mat("RookInk", "ink_black", .35); glass_g = mat("RookGlassGreen", "glass_green", .15, .1)
    glass_a = mat("RookGlassAmber", "glass_amber", .15, .1); cork = mat("RookCork", "cork", .9)
    burlap = mat("RookBurlap", "burlap", .95); quill_m = mat("RookQuill", "paper", .8)
    labels = mat("RookLabels", "labels_atlas", .9)

    # --- Ledger: bevelled boards, page block with page lines, round spine with raised bands,
    #     bronze corners and clasp, framed cover label, ribbon marker. Built at origin, placed.
    led = []
    for z in (.0065, .0715):
        b = box("Board", teal, (0, 0, z), (.41, .32, .013), .005, 2); finish(b, ('box', .3), base=.8, top=1.0, seed=z * 99); led.append(b)
    pb = box("PageBlock", pages, (.006, .004, .039), (.392, .304, .052), .004, 2)
    uv_box(pb, .5); bm = bmesh.new(); bm.from_mesh(pb.data); uvl = bm.loops.layers.uv.verify()
    for f in bm.faces:  # page lines run horizontally on the three exposed edges
        if abs(f.normal.z) < .5:
            for l in f.loops: l[uvl].uv = ((l.vert.co.x + l.vert.co.y) * 2, l.vert.co.z * 3.2)
    bm.to_mesh(pb.data); bm.free(); paint(pb, .86, 1.0, edge=.05, seed=3); led.append(pb)
    sp_ = cyl("Spine", teal, (0, .16, .039), .040, .41, 18, .004, rot=(0, math.pi / 2, 0)); finish(sp_, ('box', .3), base=.78, seed=4); led.append(sp_)
    for x in (-.15, -.05, .05, .15):
        bd = cyl("SpineBand", teal, (x, .16, .039), .0445, .012, 18, .003, rot=(0, math.pi / 2, 0)); finish(bd, ('box', .3), base=.72, edge=.25, seed=5 + x); led.append(bd)
    for x in (-1, 1):
        for z in (.0065, .0715):
            bm = bmesh.new()
            v = [bm.verts.new(p) for p in ((x * .207, -.162, 0), (x * .207 - x * .055, -.162, 0), (x * .207, -.162 + .055, 0))]
            bm.faces.new(v)
            cn = obj_from_bm(bm, "Corner", bronze); sol = cn.modifiers.new("S", 'SOLIDIFY'); sol.thickness = .017; sol.offset = 0
            bevel(cn, .002, 1, 50); apply_all(cn); fixn(cn); smooth(cn, 30); cn.data.transform(Matrix.Translation((0, 0, z))); finish(cn, None, base=.9, edge=.25, seed=6)
            led.append(cn)
    clasp = box("ClaspStrap", teal, (0, -.172, .045), (.05, .03, .07), .004, 2); finish(clasp, ('box', .2), base=.7, seed=7); led.append(clasp)
    cb = box("ClaspPlate", bronze, (0, -.188, .045), (.034, .004, .03), .002, 1); finish(cb, None, base=.95, seed=8); led.append(cb)
    led.append(label("CoverLabel", labels, "ledger", (0, -.02, .0790), .14, .07, 'z'))
    lp = box("CoverPlateFrame", bronze, (0, -.02, .0782), (.152, .082, .0012), .0004, 1); finish(lp, None, base=.9, seed=9); led.append(lp)
    rb = sweep_rect("Ribbon", ribbon, [(.06, -.14, .045), (.062, -.158, .045), (.065, -.168, .032), (.068, -.172, .012), (.071, -.19, .002), (.075, -.235, .0015)], .012, .0016, up=Vector((0, -1, 1)).normalized(), bev=0)
    finish(rb, ('box', .1), base=.85, edge=0, seed=10); led.append(rb)
    ledger = join(led, "Ledger"); xform(ledger, G(-1.25, TOP, -1.45), yaw=math.radians(-7))

    # --- inkstand: walnut tray, faceted glass well with brass lid, quill + spare pen
    st = []
    tr = box("InkTray", walnut, (0, 0, .008), (.20, .12, .016), .004, 2); finish(tr, ('box', .3, 0), base=.8, seed=11); st.append(tr)
    for y in (-.05, .05):
        gr = box("PenRail", walnut, (0, y, .018), (.18, .012, .006), .002, 1); finish(gr, ('box', .3, 0), base=.7, seed=12); st.append(gr)
    well = lathe("Inkwell", glass_g, [(.030, .016), (.036, .020), (.038, .050), (.030, .062), (.016, .070), (.016, .078)], 8)
    well.data.transform(Matrix.Translation((.045, 0, 0))); finish(well, None, base=.85, top=1.1, edge=.25, small=2e-3, seed=13); st.append(well)
    lid = lathe("Lid", bronze, [(.019, .077), (.021, .081), (.018, .087), (.008, .091), (.004, .097), (.0001, .098)], 12)
    lid.data.transform(Matrix.Translation((.045, 0, 0))); finish(lid, None, base=.92, seed=15); st.append(lid)
    q0 = Vector((.03, -.012, .07)); qd = Vector((-.35, -.25, 1)).normalized()
    shaft = cyl("QuillShaft", quill_m, (0, 0, .11), .0028, .22, 6, 0, r2=.0012); place_on(shaft, q0, qd)
    finish(shaft, None, base=.95, seed=17); st.append(shaft)
    bm = bmesh.new(); side_d = qd.cross(Vector((0, 0, 1))).normalized(); prev = None
    for k in range(13):
        u = k / 12; c = q0 + qd * (.07 + .15 * u); w = .024 * math.sin(math.pi * min(1, u * 1.15)) ** .8 * (.82 if k % 3 == 1 else 1)
        curl = side_d * (.004 * math.sin(u * math.pi))
        row = [bm.verts.new(c + curl), bm.verts.new(c + curl + side_d * w + Vector((0, 0, .003)))]
        if prev: bm.faces.new((prev[0], prev[1], row[1], row[0]))
        prev = row
    vane = obj_from_bm(bm, "QuillVane", quill_m); sol = vane.modifiers.new("S", 'SOLIDIFY'); sol.thickness = .0015
    apply_all(vane); fixn(vane); smooth(vane, 60); finish(vane, ('box', .1), base=.92, top=1.02, edge=0, seed=18); st.append(vane)
    pen = cyl("SparePen", walnut, (-.02, .05, .026), .004, .16, 8, .001, rot=(0, math.pi / 2, 0)); finish(pen, ('box', .2, 0), base=.6, seed=19); st.append(pen)
    nib = cyl("Nib", bronze, (0, 0, .01), .004, .02, 8, 0, r2=.0008); place_on(nib, Vector((-.10, .05, .026)), Vector((-1, 0, 0))); finish(nib, None, base=.95, seed=20); st.append(nib)
    stand = join(st, "Inkstand"); xform(stand, G(-.90, TOP, -1.36), yaw=math.radians(8))

    # --- two bottles (linseed oil, lamp spirit) with corks, neck twine and wrapped labels
    for k, (gm, lb, x, z, h, r) in enumerate(((glass_a, "linseed", -.56, -1.66, .20, .036), (glass_g, "spirit", -.43, -1.73, .15, .030))):
        prof = [(r * .8, 0), (r, .006), (r, h * .55), (r * .92, h * .62), (r * .42, h * .74), (r * .32, h * .78), (r * .32, h * .92), (r * .38, h * .94), (r * .38, h * .97), (r * .3, h * .98)]
        b = lathe("Bottle", gm, prof, 16); finish(b, ('cyl', (0, 0), 2, .2, r), base=.85, top=1.12, edge=.3, small=1e-3, seed=21 + k)
        ck = cyl("Cork", cork, (0, 0, h + .006), r * .3, .022, 10, .002, r2=r * .34); finish(ck, ('box', .05), base=.9, seed=23)
        rows = [[Vector((math.cos(a) * (r + .001), math.sin(a) * (r + .001), zz)) for a in [-math.pi / 2 - .9 + 1.8 * i / 8 for i in range(9)]] for zz in (h * .16, h * .46)]
        lbl = grid("Label", labels, rows, closed=False)
        bm = bmesh.new(); bm.from_mesh(lbl.data); uvl = bm.loops.layers.uv.verify()
        for f in bm.faces:
            for l in f.loops:
                a = math.atan2(l.vert.co.y, l.vert.co.x); l[uvl].uv = (1 - (a + math.pi / 2 + .9) / 1.8, (l.vert.co.z - h * .16) / (h * .30))
        bm.to_mesh(lbl.data); bm.free(); atlas_uv(lbl, lb)
        sol = lbl.modifiers.new("S", 'SOLIDIFY'); sol.thickness = .0008; sol.offset = 1; apply_all(lbl); fixn(lbl)
        paint(lbl, .95, 1, edge=0, cavity=0)
        twn = tube("NeckTwine", twine, [Vector((math.cos(TAU * i / 12) * r * .36, math.sin(TAU * i / 12) * r * .36, h * .80)) for i in range(12)], .0022, 4, closed=True)
        finish(twn, ('box', .1), base=.9, seed=24)
        bt = join([b, ck, lbl, twn], "Bottle%d" % k); xform(bt, G(x, TOP, z), yaw=math.radians(15 + 30 * k))

    # --- two rolled work plans: printed outer sheet, spiral ends, twine tie with a bow, curled lip
    for i in range(2):
        rp = []; L = .46; R = .052
        roll = cyl("PlanRoll", paper, (0, 0, 0), R, L, 24, .004, rot=(0, math.pi / 2, 0))
        uv_cyl(roll, (0, 0), 0, .45, R, cap_tex_full=True, cap_r=R)
        roll.data.materials.append(plan_end)
        for f in roll.data.polygons:
            if abs(f.normal.x) > .75: f.material_index = 1
        paint(roll, .86, 1.0, axis=2, edge=.12, seed=30 + i); rp.append(roll)
        bm = bmesh.new(); vr = []
        for c in range(7):
            a = -math.pi / 2 - .2 + c * .16; rr = R + .0012 + .006 * (c / 6) ** 2
            vr.append([bm.verts.new((x, math.cos(a) * rr, math.sin(a) * rr)) for x in (-L / 2 + .012, L / 2 - .012)])
        for a, b in zip(vr, vr[1:]): bm.faces.new((a[0], a[1], b[1], b[0]))
        lip = obj_from_bm(bm, "Lip", paper); sol = lip.modifiers.new("S", 'SOLIDIFY'); sol.thickness = .0012
        apply_all(lip); fixn(lip); smooth(lip, 60); finish(lip, ('box', .4, 0), base=.95, edge=0, seed=32); rp.append(lip)
        tie = tube("Tie", twine, [Vector((.07, math.cos(TAU * k / 18) * (R + .003), math.sin(TAU * k / 18) * (R + .003))) for k in range(18)], .0032, 5, closed=True, up=Vector((1, 0, 0)))
        finish(tie, ('box', .1), base=.92, seed=33); rp.append(tie)
        K = Vector((.07, 0, R + .006))
        for s_ in (-1, 1):
            loop = tube("Bow", twine, [K + Vector((s_ * .024 * (1 - math.cos(TAU * k / 12)) / 2, .012 * math.sin(TAU * k / 12), .002 * math.sin(math.pi * k / 12))) for k in range(12)], .0026, 4, closed=True)
            finish(loop, ('box', .1), base=.9, seed=34); rp.append(loop)
            tail = [Vector((.07 + s_ * .007 * k, -(R + .004) * math.cos(math.radians(90 - 24 * k)), (R + .004) * math.sin(math.radians(90 - 24 * k)))) for k in range(4)]
            tl = tube("BowTail", twine, tail, .0024, 4); finish(tl, ('box', .1), base=.88, seed=35); rp.append(tl)
        kn = sphere("Knot", twine, K, .006, 8, 5); finish(kn, None, base=.85, seed=36); rp.append(kn)
        r = join(rp, "PlanRoll%d" % i); xform(r, G(.30 + i * .03, TOP + .053, -1.63 + i * .115), yaw=math.radians(2 - 4 * i))

    # --- sample crate (replaces the tray, same .62 x .30 footprint): slatted pine, corner posts,
    #     nail heads, rope handles, tacked label. Contents: timber bundle, stone, scrap, hinge, nails.
    cr_ = []; W, D = .62, .30
    for k, yy in enumerate((-.1, 0, .1)):
        fb = box("Floor", pine, (0, yy, .008), (W - .01, .094, .016), .003, 1); finish(fb, ('box', .4, 0), base=.78, top=.95, seed=40 + k); cr_.append(fb)
    for sy in (-1, 1):
        for k, zz in enumerate((.031,)):
            s = box("Slat", pine, (0, sy * (D / 2 - .009), zz), (W, .016, .03), .003, 1); finish(s, ('box', .4, 0), base=.8, seed=43 + k + sy); cr_.append(s)
    for sx in (-1, 1):
        for k, zz in enumerate((.031,)):
            s = box("EndSlat", pine, (sx * (W / 2 - .009), 0, zz), (.016, D - .036, .03), .003, 1); finish(s, ('box', .4, 1), base=.8, seed=47 + k + sx); cr_.append(s)
        handle = tube("RopeHandle", twine, [(sx * (W / 2 + .006), -.05 + .1 * k / 8, .036 + .022 * math.sin(math.pi * k / 8)) for k in range(9)], .0045, 6)
        finish(handle, ('box', .1), base=.9, seed=49); cr_.append(handle)
        for yy in (-.05, .05):
            kn = sphere("RopeKnot", twine, (sx * (W / 2 + .006), yy, .036), .008, 8, 5); finish(kn, None, base=.85, seed=50); cr_.append(kn)
    for sx in (-1, 1):
        for sy in (-1, 1):
            pst = box("Post", pine, (sx * (W / 2 - .02), sy * (D / 2 - .02), .032), (.024, .024, .062), .003, 1); finish(pst, ('box', .3, 2), base=.72, seed=51); cr_.append(pst)
            for zz in (.031,):
                for p_, ax in (((sx * (W / 2 - .02), sy * (D / 2 + .0005), zz), 'y'), ((sx * (W / 2 + .0005), sy * (D / 2 - .02), zz), 'x')):
                    nh = cyl("NailHead", iron, p_, .0042, .002, 8, 0, rot=(math.pi / 2, 0, 0) if ax == 'y' else (0, math.pi / 2, 0)); finish(nh, None, base=.8, edge=.2, seed=52); cr_.append(nh)
    cr_.append(label("CrateLabel", labels, "rook", (-.14, -D / 2 - .0014, .032), .09, .045, '-y'))
    for xx in (-.18, -.10):
        tk = cyl("Tack", iron, (xx, -D / 2 - .003, .05), .0028, .002, 6, 0, rot=(math.pi / 2, 0, 0)); finish(tk, None, base=.85, seed=53); cr_.append(tk)
    for k, (dx, dz, m_, rz) in enumerate(((-.03, 0, plank_a, -.03), (.03, 0, plank_b, .02), (0, .036, plank_a, .04))):
        cx_ = -.17 + dx
        pl = box("Plank", m_, (cx_, 0, .034 + dz), (.056, .23, .034), .005, 2, rot=(0, 0, rz)); uv_box(pl, .4, 1)
        pl.data.materials.append(endg)
        for f in pl.data.polygons:
            if abs(f.normal.y) > .8: f.material_index = 1
        bm = bmesh.new(); bm.from_mesh(pl.data); uvl = bm.loops.layers.uv.verify()
        for f in bm.faces:
            if abs(f.normal.y) > .8:
                for l in f.loops: l[uvl].uv = ((l.vert.co.x - cx_) / .07 + .5, (l.vert.co.z - .034 - dz) / .07 + .5)
        bm.to_mesh(pl.data); bm.free(); paint(pl, .8, 1.04, noise_amt=.06, seed=54 + k); cr_.append(pl)
    for yy in (-.07, .07):
        pts = [Vector((-.17 + .064 * sp(math.cos(TAU * k / 20), .35), yy, .052 + .042 * sp(math.sin(TAU * k / 20), .35))) for k in range(20)]
        tw = tube("Twine", twine, pts, .0045, 6, closed=True, up=Vector((0, 1, 0))); finish(tw, ('box', .1), base=.9, seed=57); cr_.append(tw)
    s1 = rock("StoneChunk", stone, (.15, .12, .10), 3.1); s1.data.transform(Matrix.Translation((.005, .01, .058))); finish(s1, ('box', .2), base=.78, top=1.06, noise_amt=.08, edge=.2, small=2e-3, seed=58); cr_.append(s1)
    s2 = rock("StonePebble", stone, (.07, .06, .05), 7.7, 1); s2.data.transform(Matrix.Translation((.07, -.085, .036))); finish(s2, ('box', .2), base=.78, top=1.06, edge=.2, small=2e-3, seed=59); cr_.append(s2)
    bm = bmesh.new(); prof = [(0, 0), (.035, 0), (.035, .005), (.005, .005), (.005, .035), (0, .035)]
    lo = [bm.verts.new((-.06, px, pz)) for px, pz in prof]; hi = [bm.verts.new((.06, px, pz)) for px, pz in prof]
    for k in range(6): bm.faces.new((lo[k], lo[(k + 1) % 6], hi[(k + 1) % 6], hi[k]))
    bm.faces.new(list(reversed(lo))); bm.faces.new(hi); bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ang = obj_from_bm(bm, "AngleIron", iron); bevel(ang, .0012, 1, 50); apply_all(ang); smooth(ang, 30)
    ang.data.transform(Matrix.Translation((.20, .06, .017)) @ Matrix.Rotation(.5, 4, 'Z')); finish(ang, ('box', .15, 0), base=.8, edge=.25, seed=60); cr_.append(ang)
    BM = Matrix.Translation((.17, -.085, .03)) @ Matrix.Rotation(.3, 4, 'Z') @ Matrix.Rotation(math.pi / 2, 4, 'Y')
    for nm, r_, h_, sg, zo in (("Bolt", .007, .07, 10, 0), ("BoltHead", .012, .008, 6, -.037), ("Nut", .012, .009, 6, .02), ("Washer", .014, .002, 14, .0135)):
        o = cyl(nm, iron, (0, 0, zo), r_, h_, sg, .001 if sg != 14 else 0, bsegs=1); o.data.transform(BM); finish(o, None, base=.85, edge=.25, seed=61); cr_.append(o)
    hg = []
    for s_ in (-1, 1):
        lf = box("HingeLeaf", bronze, (s_ * .026, 0, 0), (.046, .06, .0025), .001, 1); finish(lf, None, base=.92, edge=.2, seed=65); hg.append(lf)
        for yy in (-.018, .018):
            sc = cyl("Screw", bronze, (s_ * .03, yy, .0018), .0045, .0015, 8, 0); finish(sc, None, base=.72, seed=66); hg.append(sc)
            sl = box("ScrewSlot", ink, (s_ * .03, yy, .0027), (.007, .0012, .0006), 0, 1); finish(sl, None, base=1, edge=0, seed=66); hg.append(sl)
    kn = cyl("Knuckle", bronze, (0, 0, .0015), .0045, .06, 10, .0008, rot=(math.pi / 2, 0, 0)); finish(kn, None, base=.95, edge=.2, seed=67); hg.append(kn)
    hj = join(hg, "Hinge"); xform(hj, (.215, -.03, .03), yaw=.4, roll=-.25); cr_.append(hj)
    for k, (x, y, a) in enumerate(((.115, .035, .4), (.13, .07, 1.9), (.255, -.10, 2.6), (.25, .115, .9))):
        cr_ += nail("Nail", iron, (x, y, .02), (math.cos(a), math.sin(a), .04))
    crate = join(cr_, "SampleCrate"); xform(crate, G(.98, TOP, -1.40))

    # --- burlap sack of nails: drawstring neck, nails poking out, tied tag; spilled nails
    sk = []
    prof = [(.0001, 0), (.075, .004), (.098, .03), (.104, .07), (.095, .11), (.070, .14), (.042, .158), (.036, .166), (.046, .178), (.062, .196), (.066, .204)]
    sack = lathe("Sack", burlap, prof, 22, wobble=.12, lobes=5, lobe_amt=.05)
    finish(sack, ('cyl', (0, 0), 2, .25, .1), base=.78, top=1.05, noise_amt=.07, edge=.08, seed=70); sk.append(sack)
    fill = cyl("NailFill", iron, (0, 0, .192), .058, .012, 16, .002); finish(fill, ('box', .05), base=.55, top=.65, seed=71); sk.append(fill)
    for k in range(9):
        a = TAU * k / 9 + .2; r = .015 + .03 * ((k * 37) % 10) / 10
        sk += nail("SackNail", iron, (math.cos(a) * r, math.sin(a) * r, .185), (math.cos(a) * .5, math.sin(a) * .5, 1), .04)
    dr = tube("Drawstring", twine, [Vector((math.cos(TAU * k / 16) * .041, math.sin(TAU * k / 16) * .041, .164)) for k in range(16)], .004, 5, closed=True); finish(dr, ('box', .1), base=.9, seed=72); sk.append(dr)
    tail = tube("StringTail", twine, [(.026, -.034, .164), (.04, -.06, .14), (.05, -.075, .115)], .003, 4); finish(tail, ('box', .1), base=.88, seed=73); sk.append(tail)
    sk.append(label("SackTag", labels, "nails", (.05, -.09, .10), .07, .035, '-y', rot=(0, .25, .35)))
    sack_g = join(sk, "NailSack"); xform(sack_g, G(1.58, TOP, -1.38), yaw=.5)
    for k, (x, z, a) in enumerate(((1.45, -1.22, .3), (1.49, -1.19, 2.0), (1.70, -1.22, 4.1))):
        nail("SpilledNail", iron, Vector(G(x, TOP, z)) + Vector((0, 0, .0025)), (math.cos(a), math.sin(a), .03))
    # --- small lidded hinge box with brass hinges and a label
    hb = []
    bx = box("HingeBox", walnut, (0, 0, .03), (.15, .09, .06), .004, 2); finish(bx, ('box', .3, 0), base=.78, seed=80); hb.append(bx)
    lid2 = box("HingeBoxLid", walnut, (0, 0, .066), (.156, .096, .014), .004, 2); finish(lid2, ('box', .3, 0), base=.85, seed=81); hb.append(lid2)
    for xx in (-.045, .045):
        hl = box("BoxHinge", bronze, (xx, .0485, .058), (.022, .002, .02), .0006, 1); finish(hl, None, base=.92, seed=82); hb.append(hl)
    hb.append(label("BoxLabel", labels, "hinge", (0, -.0458, .03), .09, .045, '-y'))
    hbo = join(hb, "HingeBox"); xform(hbo, G(1.66, TOP, -1.74), yaw=-.25)
    report("ROOK_COUNTER", "rook_counter_stock")

# ================================================================ Hall reception desk
# Desk-local space: origin at the desk centre on the hall floor plane (Godot y=0),
# customer front faces Godot +z. Placed at HallReceptionAssemblyV098 (0, 0, -22).
# Envelope matches the kept collider: 2.4 x 1.16 x 1.2 m, floor y=.24, top y=1.40.
# The front lines up with the hall's own bronze bindings (x = +-.52, +-1.04) and
# dressed edges (y = .34, 1.29), which stay in the scene.
def build_reception_desk():
    reset()
    teal = mat("DeskPaintTeal", "teal_paint", .8); teal_l = mat("DeskPanelTeal", "teal_panel", .8)
    oak = mat("DeskOak", "oak", .6); dark = mat("DeskWalnutDark", "walnut_dark", .75)
    brass = mat("DeskBrass", "brass", .4, .7); paper = mat("DeskPaper", "paper", .9)
    ruled = mat("DeskRuled", "ruled", .9); leather = mat("DeskLeather", "leather_rust", .7)
    ink = mat("DeskInk", "ink_black", .35); glass_g = mat("DeskGlassGreen", "glass_green", .15, .1)
    glow = mat("DeskLanternGlow", hexcol="#ffe2a6", rough=.3, emit=((1.0, .78, .42), 2.0))
    labels = mat("DeskLabels", "labels_atlas", .9)
    F, T = .24, 1.40; fz = .555
    parts = []
    def add(ob, uv=('box', .5, 0), **pk):
        pk.setdefault("seed", len(parts) * 1.7); finish(ob, uv, **pk); parts.append(ob); return ob
    # plinth with a stepped cap, painted carcass
    add(box("Plinth", dark, G(0, F + .055, -.03), (2.30, 1.06, .11), .012, 2), base=.75)
    add(box("PlinthCap", dark, G(0, F + .118, -.025), (2.34, 1.10, .022), .008, 2), base=.85)
    add(box("Carcass", teal, G(0, (F + .13 + T - .072) / 2, -.03), (2.30, 1.06, T - .072 - F - .13), .02, 2), ('box', .6, 2))
    # front frame: rails + stiles
    for y0, y1 in ((.30, .40), (1.06, 1.115), (1.27, T - .072)):
        add(box("Rail", teal, G(0, (y0 + y1) / 2, fz), (2.26, .045, y1 - y0), .010, 2), ('box', .6, 0))
    for x, w in ((-1.07, .12), (-.52, .10), (.52, .10), (1.07, .12)):
        add(box("Stile", teal, G(x, (.30 + T - .072) / 2, fz), (w, .046, T - .072 - .30), .010, 2), ('box', .6, 2))
    for x0, x1 in ((-1.01, -.57), (-.47, .47), (.57, 1.01)):
        cx, w = (x0 + x1) / 2, x1 - x0
        # flat back panel, chamfered raised field, applied oak moulding frame
        add(box("PanelBack", teal_l, G(cx, .73, fz - .012), (w, .02, .66), 0, 1), ('box', .6, 0), base=.78)
        add(box("RaisedField", teal_l, G(cx, .73, fz + .004), (w - .09, .03, .55), .028, 1), ('box', .6, 2), edge=.2)
        for y in (.405, 1.055):
            add(box("Moulding", oak, G(cx, y, fz + .026), (w, .016, .016), .006, 2), ('box', .4, 0))
        for x in (x0 + .008, x1 - .008):
            add(box("Moulding", oak, G(x, .73, fz + .026), (.016, .016, .66), .006, 2), ('box', .4, 2))
        # frieze drawers (the centre bay gets two so the pulls clear the hanging banner)
        for d0, d1 in (((x0, x1),) if w < .6 else ((x0, -.015), (.015, x1))):
            dc, dw = (d0 + d1) / 2, d1 - d0
            add(box("DrawerFront", oak, G(dc, 1.192, fz + .012), (dw - .02, .03, .14), .008, 2), ('box', .4, 0), edge=.22)
            add(box("DrawerBead", oak, G(dc, 1.192, fz + .028), (dw - .07, .006, .10), .003, 1), ('box', .4, 0), base=.75, edge=0)
            px = dc if w < .6 else (dc - .06 if dc < 0 else dc + .06)
            for s_ in (-1, 1):
                add(cyl("PullPost", brass, G(px + s_ * .045, 1.20, fz + .036), .006, .02, 8, .001, rot=(math.pi / 2, 0, 0), bsegs=1), None, base=.95)
            bail = [Vector(G(px + .045 * math.cos(math.pi * k / 10), 1.20 - .028 * math.sin(math.pi * k / 10), fz + .047)) for k in range(11)]
            add(tube("Bail", brass, bail, .0035, 6, up=Vector((0, -1, 0))), None, base=.95, edge=.25)
            add(box("PullPlate", brass, G(px, 1.20, fz + .029), (.11, .022, .004), .0015, 1), None, base=.9)
            esc = lathe("Escutcheon", brass, [(.0001, 0), (.014, 0), (.013, .003), (.0001, .004)], 12)
            esc.data.transform(Matrix.Translation(Vector(G(px, 1.152, fz + .027))) @ Matrix.Rotation(math.pi / 2, 4, 'X'))
            add(esc, None, base=.92)
            add(box("Keyhole", ink, G(px, 1.150, fz + .0315), (.004, .002, .012), 0, 1), None, base=1, edge=0)
    # corner posts: chamfered oak with capital, base block and brass collars; end panels
    for side in (-1, 1):
        x = side * 1.18
        add(box("Post", oak, G(x, (F + T - .072) / 2 + .05, .53), (.11, .11, T - .072 - F - .1), .016, 1), ('box', .5, 2), edge=.22)
        add(box("PostBase", oak, G(x, F + .07, .53), (.135, .135, .14), .012, 2), ('box', .5, 2))
        add(box("PostCapital", oak, G(x, T - .105, .53), (.13, .13, .05), .012, 2), ('box', .5, 2))
        for y in (F + .15, T - .135):
            add(cyl("PostCollar", brass, G(x, y, .53), .067, .02, 20, .004), ('cyl', (x, -.53), 2, .2, .067), base=.92, edge=.25)
        add(box("EndPanel", teal, G(side * 1.16, (F + T) / 2, -.04), (.05, 1.02, T - F - .30), .012, 2), ('box', .6, 2))
        add(box("EndField", teal_l, G(side * 1.19, (F + T) / 2 - .02, -.05), (.03, .80, .62), .026, 1), ('box', .6, 2), edge=.2)
        for z in (-.46, .36):
            add(box("EndMould", oak, G(side * 1.205, (F + T) / 2 - .02, z), (.016, .016, .70), .006, 2), ('box', .4, 2))
        for y in (.48, 1.12):
            add(box("EndMould", oak, G(side * 1.205, y, -.05), (.016, .84, .016), .006, 2), ('box', .4, 1))
    # top: rounded oak slab over a stepped sub-board; staff-side shelf
    add(box("Top", oak, G(0, T - .026, .02), (2.50, 1.26, .052), .02, 3), ('box', .6, 0), base=.86, top=1.02, edge=.12)
    add(box("TopStep", oak, G(0, T - .062, .02), (2.44, 1.20, .022), .007, 2), ('box', .6, 0), base=.8)
    add(box("StaffShelf", oak, G(0, .80, -.50), (2.10, .26, .04), .008, 2), ('box', .6, 0))
    # brass desk lantern, back-left: footed base, glass with ribs, vented cap and ring handle
    lx, lz = -.92, -.30
    def at(ob, x=lx, z=lz): ob.data.transform(Matrix.Translation(Vector(G(x, 0, z)))); return ob
    add(at(lathe("LanternBase", brass, [(.078, T + .006), (.082, T + .014), (.070, T + .021), (.060, T + .032), (.048, T + .042)], 20)), None, base=.9)
    for a in range(4):
        ang = a * math.pi / 2 + math.pi / 4
        add(sphere("LanternFoot", brass, G(lx + math.cos(ang) * .066, T + .006, lz + math.sin(ang) * .066), .008, 8, 5), None, base=.85)
    add(cyl("LanternGlass", glow, G(lx, T + .127, lz), .042, .17, 16, .004), None, base=1, top=1, noise_amt=0, edge=0, cavity=0)
    for a in range(4):
        ang = a * math.pi / 2 + math.pi / 4
        add(cyl("LanternRib", brass, G(lx + math.cos(ang) * .047, T + .127, lz + math.sin(ang) * .047), .006, .18, 6, 0), None, base=.9)
    add(at(lathe("LanternCap", brass, [(.058, T + .207), (.062, T + .216), (.050, T + .228), (.040, T + .242), (.022, T + .258), (.012, T + .264), (.016, T + .274), (.004, T + .284)], 20)), None, base=.9, edge=.25)
    ring_pts = [Vector(G(lx, T + .302 + .018 * math.sin(TAU * k / 16), lz + .018 * math.cos(TAU * k / 16))) for k in range(16)]
    add(tube("LanternRing", brass, ring_pts, .0028, 6, closed=True, up=Vector((1, 0, 0))), None, base=.92)
    # service bell, front left of the WELCOME plaque
    bx, bz = -.30, .40
    add(at(lathe("BellBase", dark, [(.052, T), (.055, T + .006), (.052, T + .016), (.046, T + .018)], 20), bx, bz), ('cyl', (bx, -bz), 2, .2, .05), base=.8)
    add(at(lathe("BellDome", brass, [(.044, T + .018), (.045, T + .022), (.040, T + .040), (.030, T + .056), (.016, T + .066), (.0001, T + .069)], 20), bx, bz), None, base=.92, top=1.1, edge=.2)
    add(at(lathe("BellPlunger", brass, [(.004, T + .066), (.004, T + .078), (.008, T + .080), (.009, T + .086), (.0001, T + .089)], 10), bx, bz), None, base=.95)
    # open guest register: leather covers, curved ruled pages, tab label, ribbon, pen
    g = []
    for s_ in (-1, 1):
        cv = box("RegCover", leather, (s_ * .105, 0, .004), (.215, .29, .008), .003, 1); finish(cv, ('box', .3), base=.8, seed=90 + s_); g.append(cv)
        rows = []
        for yy in (-.135, .135):
            row = [Vector((s_ * (.006 + .19 * k / 8), yy, .009 + .016 * math.sin(math.pi * min(1, k / 8 * 1.1)) ** .6 * (1 - .3 * k / 8))) for k in range(9)]
            rows.append(row if s_ > 0 else list(reversed(row)))
        pg = grid("RegPages", ruled, rows, closed=False)
        uv_rect(pg, (s_ * .1, 0, 0), (1, 0, 0), (0, 1, 0), .2, .27)
        sol = pg.modifiers.new("S", 'SOLIDIFY'); sol.thickness = .008; sol.offset = -1
        apply_all(pg); fixn(pg); smooth(pg, 50); paint(pg, .9, 1.02, edge=0, cavity=.1, seed=92); g.append(pg)
    g.append(label("RegTab", labels, "guests", (0, .152, .0095), .09, .028, 'z'))
    rb = sweep_rect("RegRibbon", leather, [(.01, .12, .019), (.015, .145, .017), (.022, .16, .006), (.03, .19, .001)], .01, .0015, up=Vector((0, -1, 1)).normalized(), bev=0)
    finish(rb, ('box', .1), base=.6, seed=93); g.append(rb)
    pen = cyl("Pen", dark, (.12, -.02, .031), .0045, .15, 8, .001, rot=(0, math.pi / 2, .5)); finish(pen, ('box', .2, 0), base=.7, seed=94); g.append(pen)
    pn = cyl("PenNib", brass, (0, 0, .01), .0045, .02, 8, 0, r2=.001)
    place_on(pn, Vector((.12, -.02, .031)) - Vector((math.cos(.5), math.sin(.5), 0)) * .075, -Vector((math.cos(.5), math.sin(.5), 0))); finish(pn, None, base=.95, seed=95); g.append(pn)
    reg = join(g, "GuestRegister"); xform(reg, G(-.60, T, .14), yaw=math.radians(8)); parts.append(reg)
    # loose papers: four sheets fanned slightly, ruled top sheet
    for k in range(4):
        sh = box("Paper", ruled if k == 3 else paper, (0, 0, .0012 + k * .0016), (.21, .297, .0012), 0, 1)
        uv_rect(sh, (0, 0, 0), (1, 0, 0), (0, 1, 0), .21, .297); paint(sh, .9, 1.0, edge=0, cavity=0, seed=96 + k)
        xform(sh, G(-.98 + .012 * k, T, .30 - .008 * k), yaw=math.radians(-12 + 7 * k)); parts.append(sh)
    # inkwell + pen tray behind the register
    it = []
    tray = box("PenTray", dark, (0, 0, .006), (.18, .07, .012), .003, 2); finish(tray, ('box', .3, 0), base=.8, seed=100); it.append(tray)
    w = lathe("Inkwell", glass_g, [(.024, .012), (.028, .015), (.029, .040), (.020, .050), (.012, .056), (.012, .062)], 8)
    w.data.transform(Matrix.Translation((.05, 0, 0))); finish(w, None, base=.85, top=1.1, edge=.25, small=2e-3, seed=101); it.append(w)
    lid = lathe("InkLid", brass, [(.014, .061), (.016, .065), (.012, .071), (.0001, .075)], 12); lid.data.transform(Matrix.Translation((.05, 0, 0))); finish(lid, None, base=.92, seed=102); it.append(lid)
    pn2 = cyl("TrayPen", dark, (-.03, 0, .017), .004, .12, 8, .001, rot=(0, math.pi / 2, 0)); finish(pn2, ('box', .2, 0), base=.65, seed=103); it.append(pn2)
    ink_g = join(it, "Inkstand"); xform(ink_g, G(-.45, T, -.26), yaw=math.radians(-6)); parts.append(ink_g)
    report("RECEPTION_DESK", "hall_reception_desk")

if __name__ == "__main__":
    import sys
    os.makedirs(OUT, exist_ok=True); os.makedirs(BLEND, exist_ok=True)
    which = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else ["dress", "rook", "desk"]
    if "dress" in which: build_dress_form()
    if "rook" in which: build_rook_counter()
    if "desk" in which: build_reception_desk()
