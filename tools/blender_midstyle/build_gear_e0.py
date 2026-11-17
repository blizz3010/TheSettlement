# Gear art E0 pilot (TASKS item 22, gear_tiers_plan.md section 7b): the T3 helmet ("Warden Helm",
# gear_helmet_t3) and the T3 vest ("Bulwark Carrier", gear_body_armor_t3) as mid-to-high poly,
# original-design, PBR models SKINNED to the Appearance-Proof rig (models/Appearance-Proof.glb).
# Pipeline follows PR #23 / PR F (Blender 4.2, metres, transforms applied before bevels, n-gons
# triangulated) with three differences for worn, in-world gear:
#   * fitted to the rig's own ProofBody/hair (rest pose) and auto-checked for clearance;
#   * skinned: the vest takes weights transferred from ProofBody, limited to torso bones and
#     smoothed (so plates ride the spine/clavicles instead of stretching with the arms); the
#     helmet is rigid on the head bone;
#   * textures are the SHARED T3 set in raid/assets/gear/t3/textures (tools/gear_art_pbr), kept
#     EXTERNAL (.gltf + .bin + jpg, GLTF_SEPARATE) so Godot imports them VRAM-compressed once.
# Each model ships LOD0 and an explicit LOD1 (collapse-decimated to ~40%) for the Psy mannequin.
# UVs: smart-project unwrap per part, rescaled to a fixed texel density (tileable sets); decal
# patches get explicit UVs into the t3_decals sheet.
#   python3 tools/gear_art_pbr/make_textures.py
#   blender -b --factory-startup -P tools/blender_midstyle/build_gear_e0.py
import bpy, bmesh, math, os, json, shutil
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
RIG = os.path.join(ROOT, "models", "Appearance-Proof.glb")
OUT = os.path.join(ROOT, "raid", "assets", "gear", "t3")
TEX = os.path.join(OUT, "textures")
TMP = os.environ.get("GEAR_E0_TMP", "/tmp/gear_e0_export")
LOD1_RATIO = 0.40
MATS = {}
TILE = {"t3_cordura": 0.35, "t3_shell": 0.30, "t3_webbing": 0.10, "t3_polymer": 0.12, "t3_steel": 0.08, "t3_loop": 0.15}

# ------------------------------------------------------------------ scene + materials
def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.unit_settings.system = "METRIC"
    MATS.clear()
    bpy.ops.import_scene.gltf(filepath=RIG)

def _img(name, non_color):
    img = bpy.data.images.load(os.path.join(TEX, name + ".jpg"), check_existing=True)
    if non_color: img.colorspace_settings.name = "Non-Color"
    return img

def _gltf_output_group():
    g = bpy.data.node_groups.get("glTF Material Output")
    if g: return g
    g = bpy.data.node_groups.new("glTF Material Output", "ShaderNodeTree")
    g.interface.new_socket("Occlusion", in_out="INPUT", socket_type="NodeSocketFloat")
    return g

def pbr(name, tex, normal_strength=1.0):
    """Principled BSDF fed by base / ORM (R AO via glTF output, G rough, B metal) / normal."""
    if name in MATS: return MATS[name]
    m = bpy.data.materials.new(name); m.use_nodes = True; m.use_backface_culling = True
    nt = m.node_tree; b = nt.nodes["Principled BSDF"]
    base = nt.nodes.new("ShaderNodeTexImage"); base.image = _img(tex + "_base", False)
    nt.links.new(base.outputs["Color"], b.inputs["Base Color"])
    orm = nt.nodes.new("ShaderNodeTexImage"); orm.image = _img(tex + "_orm", True)
    sep = nt.nodes.new("ShaderNodeSeparateColor"); nt.links.new(orm.outputs["Color"], sep.inputs["Color"])
    nt.links.new(sep.outputs["Green"], b.inputs["Roughness"]); nt.links.new(sep.outputs["Blue"], b.inputs["Metallic"])
    out = nt.nodes.new("ShaderNodeGroup"); out.node_tree = _gltf_output_group()
    nt.links.new(sep.outputs["Red"], out.inputs["Occlusion"])
    nor = nt.nodes.new("ShaderNodeTexImage"); nor.image = _img(tex + "_normal", True)
    nm = nt.nodes.new("ShaderNodeNormalMap"); nm.inputs["Strength"].default_value = normal_strength
    nt.links.new(nor.outputs["Color"], nm.inputs["Color"]); nt.links.new(nm.outputs["Normal"], b.inputs["Normal"])
    MATS[name] = m; m["tex"] = tex; return m

def sel(obj):
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = obj; obj.select_set(True)

def apply_all(obj):
    sel(obj)
    for md in list(obj.modifiers): bpy.ops.object.modifier_apply(modifier=md.name)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

def tris(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)

def set_mats(obj, mats):
    obj.data.materials.clear()
    for m in mats: obj.data.materials.append(m)

def uv_world(obj, tile=None, angle=66):
    """Unwrap (smart project) and rescale so one UV unit = `tile` metres of the material's set."""
    if not obj.data.polygons: return
    sel(obj); bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(angle), island_margin=0.004, scale_to_bounds=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    if tile is None:
        tex = obj.data.materials[0]["tex"] if obj.data.materials else "t3_cordura"
        tile = TILE.get(tex, 0.2)
    uv = obj.data.uv_layers.active.data
    a3 = sum(p.area for p in obj.data.polygons); auv = 0.0
    for p in obj.data.polygons:
        pts = [uv[i].uv for i in p.loop_indices]
        auv += abs(sum(pts[i].x * pts[(i + 1) % len(pts)].y - pts[(i + 1) % len(pts)].x * pts[i].y for i in range(len(pts)))) * 0.5
    if auv <= 0: return
    s = math.sqrt(a3 / auv) / tile
    for d in uv: d.uv = d.uv * s

def finish(obj, mats, bevel=0.0, segs=2, smooth_angle=35, uv=True, tile=None):
    """Bevel (metres, transforms applied first), triangulate n-gons, smooth by angle, unwrap."""
    sel(obj); bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    if mats is not None and not obj.data.materials: set_mats(obj, mats)
    if bevel > 0:
        md = obj.modifiers.new("Bevel", "BEVEL"); md.width = bevel; md.segments = segs; md.limit_method = "ANGLE"
        md.angle_limit = math.radians(40)
    t = obj.modifiers.new("Tri", "TRIANGULATE"); t.min_vertices = 5
    apply_all(obj)
    sel(obj); bpy.ops.object.shade_smooth_by_angle(angle=math.radians(smooth_angle))
    if uv: uv_world(obj, tile)
    return obj

def box(size, loc, rot=(0, 0, 0), name="Box"):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    o = bpy.context.active_object; o.name = name; o.scale = size
    sel(o); bpy.ops.object.transform_apply(location=False, rotation=False, scale=True); return o

def cyl(r, depth, loc, rot=(0, 0, 0), verts=24, name="Cyl"):
    bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=depth, vertices=verts, location=loc, rotation=rot)
    o = bpy.context.active_object; o.name = name; return o

def orient(obj, point, normal, up=Vector((0, 0, 1))):
    """Place a part built around the origin (its back on local -Y... facing local -Y outward)
    onto `point`, with local -Y along the outward surface `normal`."""
    f = -normal.normalized(); x = up.cross(f).normalized()
    if x.length < 1e-4: x = Vector((1, 0, 0))
    u = f.cross(x).normalized()
    obj.matrix_world = Matrix.Translation(point) @ Matrix((x, f, u)).transposed().to_4x4()
    sel(obj); bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

def mesh_obj(name, verts, faces):
    me = bpy.data.meshes.new(name); me.from_pydata([tuple(v) for v in verts], [], faces); me.update()
    o = bpy.data.objects.new(name, me); bpy.context.scene.collection.objects.link(o); return o

def sweep(name, path, normals, profile, closed=False, cap=True):
    """Sweep a 2D profile [(n, u)] along `path`; n is along the surface normal, u across."""
    verts = []; faces = []; k = len(profile); n = len(path)
    for i, p in enumerate(path):
        t = (path[min(i + 1, n - 1)] - path[max(i - 1, 0)]).normalized()
        nn = (normals[i] - t * normals[i].dot(t)).normalized(); uu = t.cross(nn).normalized()
        for (a, b) in profile: verts.append(p + nn * a + uu * b)
    for i in range(n - 1 if not closed else n):
        j = (i + 1) % n
        for q in range(k):
            r = (q + 1) % k
            faces.append((i * k + q, i * k + r, j * k + r, j * k + q))
    if cap and not closed:
        faces.append(tuple(range(k))[::-1]); faces.append(tuple((n - 1) * k + q for q in range(k)))
    return mesh_obj(name, verts, faces)

def rrect(w, h, r, seg=3):
    """Rounded-rectangle profile (n from 0..w, u centred), counter-clockwise."""
    pts = []
    for (cx, cy, a0) in ((w - r, h / 2 - r, 0), (r, h / 2 - r, 90), (r, -h / 2 + r, 180), (w - r, -h / 2 + r, 270)):
        for s in range(seg + 1):
            a = math.radians(a0 + 90 * s / seg); pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts

class Surf:
    """Nearest-point / ray queries against an evaluated mesh, in world space."""
    def __init__(self, obj):
        dg = bpy.context.evaluated_depsgraph_get(); e = obj.evaluated_get(dg); me = e.to_mesh()
        self.v = [obj.matrix_world @ v.co for v in me.vertices]
        self.f = [tuple(p.vertices) for p in me.polygons]
        e.to_mesh_clear()
        self.bvh = BVHTree.FromPolygons(self.v, self.f)
    def nearest(self, p):
        loc, nor, i, d = self.bvh.find_nearest(p); return loc, nor
    def ray(self, o, d):
        loc, nor, i, dist = self.bvh.ray_cast(o, d); return loc, nor
    def onto(self, p, off):
        loc, nor = self.nearest(p); return loc + nor * off, nor

def proxy_from(objs, name, keep=None, smooth_iter=0):
    dg = bpy.context.evaluated_depsgraph_get(); bm = bmesh.new()
    for o in objs:
        e = o.evaluated_get(dg); me = e.to_mesh(); tmp = bmesh.new(); tmp.from_mesh(me); tmp.transform(o.matrix_world)
        m2 = bpy.data.meshes.new("t"); tmp.to_mesh(m2); bm.from_mesh(m2); tmp.free(); e.to_mesh_clear()
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=0.0005)   # weld UV seams (else smoothing opens them)
    if keep:
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if not keep(v.co)], context="VERTS")
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new(name, me); bpy.context.scene.collection.objects.link(o)
    if smooth_iter:
        md = o.modifiers.new("Smooth", "SMOOTH"); md.factor = 0.5; md.iterations = smooth_iter
        apply_all(o)
    return o

def shrink(obj, target, off, mode="NEAREST_SURFACEPOINT", axis=None, neg=True, pos=True):
    md = obj.modifiers.new("Shrink", "SHRINKWRAP"); md.target = target; md.offset = off; md.wrap_method = mode
    if mode == "PROJECT":
        md.use_project_x = axis == "x"; md.use_project_y = axis == "y"; md.use_project_z = axis == "z"
        md.use_negative_direction = neg; md.use_positive_direction = pos
    return md

def outline_prism(points2d, plane_y, depth, name="Cutter"):
    """Extruded outline (x, z) for boolean cutting a grid lying in the XZ plane."""
    n = len(points2d); verts = []
    for y in (plane_y - depth, plane_y + depth):
        for (x, z) in points2d: verts.append((x, y, z))
    faces = [tuple(range(n))[::-1], tuple(range(n, 2 * n))]
    for i in range(n):
        j = (i + 1) % n; faces.append((i, j, n + j, n + i))
    o = mesh_obj(name, verts, faces)
    sel(o); bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.normals_make_consistent(inside=False); bpy.ops.object.mode_set(mode="OBJECT")
    return o

def grid_panel(name, points2d, y, res, project_dir, target, off, plate_curve=None):
    """Dense XZ grid cut to an outline (boolean), projected along Y onto `target`."""
    xs = [p[0] for p in points2d]; zs = [p[1] for p in points2d]
    w = max(xs) - min(xs); h = max(zs) - min(zs)
    bpy.ops.mesh.primitive_grid_add(x_subdivisions=res[0], y_subdivisions=res[1], size=1,
                                    location=((max(xs) + min(xs)) / 2, y, (max(zs) + min(zs)) / 2), rotation=(math.pi / 2, 0, 0))
    g = bpy.context.active_object; g.name = name; g.scale = (w * 1.04, h * 1.04, 1); apply_all(g)
    cut = outline_prism(points2d, y, 0.05)
    b = g.modifiers.new("Cut", "BOOLEAN"); b.operation = "INTERSECT"; b.object = cut; b.solver = "EXACT"
    apply_all(g); bpy.data.objects.remove(cut)
    # Face the outside (front panel: -Y; back panel: +Y).
    sel(g); bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.normals_make_consistent(inside=False); bpy.ops.object.mode_set(mode="OBJECT")
    want = -1 if project_dir > 0 else 1
    if sum(p.normal.y for p in g.data.polygons) * want < 0:
        sel(g); bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.select_all(action="SELECT"); bpy.ops.mesh.flip_normals(); bpy.ops.object.mode_set(mode="OBJECT")
    if plate_curve is None:
        shrink(g, target, off, "PROJECT", "y", neg=project_dir < 0, pos=project_dir > 0)
        apply_all(g)
        return g
    # Plate fit: a smooth curved plate (sagitta c*x^2 across, body profile smoothed down the
    # centre line), pushed out wherever the body would come closer than `off`.
    surf = Surf(target); sgn = -1.0 if project_dir > 0 else 1.0   # -1: front panel sits at -Y
    zs = sorted(v.co.z for v in g.data.vertices); z0, z1 = zs[0] - 0.03, zs[-1] + 0.03
    xs_ = [v.co.x for v in g.data.vertices]; xa, xb = min(xs_), max(xs_)
    prof = []
    for k in range(int((z1 - z0) / 0.01) + 1):
        z = z0 + k * 0.01; best = None
        # Rigid plate: the centre-line depth that keeps the WHOLE curved row `off` clear of the body.
        for q in range(25):
            x = xa + (xb - xa) * q / 24
            loc, nor = surf.ray(Vector((x, y, z)), Vector((0, project_dir, 0)))
            if loc is None: continue
            cand = loc.y + sgn * off - sgn * (-plate_curve * x * x) if False else (loc.y - off - plate_curve * x * x if sgn < 0 else loc.y + off + plate_curve * x * x)
            best = cand if best is None else (min(best, cand) if sgn < 0 else max(best, cand))
        prof.append([z, best])
    known = [q for q in prof if q[1] is not None]
    for q in prof:
        if q[1] is None: q[1] = min(known, key=lambda k: abs(k[0] - q[0]))[1]
    for _ in range(8):   # smooth down the plate, only ever moving it outward
        sm = [(prof[max(i - 1, 0)][1] + 2 * prof[i][1] + prof[min(i + 1, len(prof) - 1)][1]) / 4 for i in range(len(prof))]
        prof = [[prof[i][0], min(sm[i], prof[i][1]) if sgn < 0 else max(sm[i], prof[i][1])] for i in range(len(prof))]
    def yc(z):
        f = (z - z0) / 0.01; i = max(0, min(len(prof) - 2, int(f))); t = f - i
        return prof[i][1] * (1 - t) + prof[i + 1][1] * t
    for v in g.data.vertices:
        x, z = v.co.x, v.co.z
        v.co.y = yc(z) + (plate_curve * x * x if sgn < 0 else -plate_curve * x * x)
    g.data.update()
    return g

def arc_pts(cx, cz, r, a0, a1, n):
    return [(cx + r * math.cos(math.radians(a0 + (a1 - a0) * i / n)), cz + r * math.sin(math.radians(a0 + (a1 - a0) * i / n))) for i in range(n + 1)]

def decal_uv(obj, region, axis_u, axis_v, flip_u=False):
    """Map a flat-ish patch's verts into a t3_decals region (x0, y0, x1, y1) in image pixels
    (1024x512, origin top-left)."""
    W, H = 1024.0, 512.0
    co = [v.co for v in obj.data.vertices]
    us = [c.dot(axis_u) for c in co]; vs = [c.dot(axis_v) for c in co]
    u0, u1, v0, v1 = min(us), max(us), min(vs), max(vs)
    uv = obj.data.uv_layers.new(name="UVMap") if not obj.data.uv_layers else obj.data.uv_layers.active
    x0, y0, x1, y1 = region
    for p in obj.data.polygons:
        for li in p.loop_indices:
            c = co[obj.data.loops[li].vertex_index]
            fu = (c.dot(axis_u) - u0) / max(u1 - u0, 1e-6); fv = (c.dot(axis_v) - v0) / max(v1 - v0, 1e-6)
            if flip_u: fu = 1 - fu
            px = x0 + fu * (x1 - x0); py = y1 - fv * (y1 - y0)
            uv.data[li].uv = (px / W, 1 - py / H)

def join(objs, name):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs: o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]; bpy.ops.object.join()
    o = bpy.context.active_object; o.name = name; o.data.name = name
    # Merge material slots that point at the same material (keeps one surface per material).
    sel(o); bpy.ops.object.material_slot_remove_unused()
    return o

def merge_duplicate_slots(o):
    seen = {}; remap = {}
    for i, s in enumerate(o.material_slots):
        m = s.material
        if m.name in seen: remap[i] = seen[m.name]
        else: seen[m.name] = i
    for p in o.data.polygons:
        if p.material_index in remap: p.material_index = remap[p.material_index]
    sel(o); bpy.ops.object.material_slot_remove_unused()

# ------------------------------------------------------------------ skinning + export
def bind(obj, rig, groups):
    """groups: {"bone": weight} for rigid parts, or a callable that fills groups."""
    obj.parent = rig
    md = obj.modifiers.new("Armature", "ARMATURE"); md.object = rig
    return md

def rigid_weights(obj, bone):
    obj.vertex_groups.clear(); g = obj.vertex_groups.new(name=bone)
    g.add(list(range(len(obj.data.vertices))), 1.0, "REPLACE")

def transfer_weights(obj, body, allowed, smooth=6):
    obj.vertex_groups.clear()
    dt = obj.modifiers.new("DT", "DATA_TRANSFER"); dt.object = body
    dt.use_vert_data = True; dt.data_types_verts = {"VGROUP_WEIGHTS"}; dt.vert_mapping = "POLYINTERP_NEAREST"
    dt.layers_vgroup_select_src = "ALL"; dt.layers_vgroup_select_dst = "NAME"
    sel(obj); bpy.ops.object.datalayout_transfer(modifier="DT")
    bpy.ops.object.modifier_apply(modifier="DT")
    for g in list(obj.vertex_groups):
        if g.name not in allowed: obj.vertex_groups.remove(g)
    sel(obj); bpy.ops.object.mode_set(mode="WEIGHT_PAINT")
    bpy.ops.object.vertex_group_smooth(group_select_mode="ALL", factor=0.6, repeat=smooth)
    bpy.ops.object.vertex_group_limit_total(group_select_mode="ALL", limit=4)
    bpy.ops.object.vertex_group_normalize_all(group_select_mode="ALL", lock_active=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    # Any vertex left without weight (outside every allowed bone) rides spine_03.
    fallback = obj.vertex_groups.get("spine_03") or obj.vertex_groups.new(name="spine_03")
    for v in obj.data.vertices:
        if sum(g.weight for g in v.groups) < 1e-3: fallback.add([v.index], 1.0, "REPLACE")

def make_lod1(obj, ratio):
    sel(obj); bpy.ops.object.duplicate(); lod = bpy.context.active_object
    lod.name = obj.name + "_LOD1"; lod.data.name = lod.name
    for md in list(lod.modifiers):
        if md.type == "ARMATURE": lod.modifiers.remove(md)
    d = lod.modifiers.new("Decimate", "DECIMATE"); d.decimate_type = "COLLAPSE"; d.ratio = ratio
    t = lod.modifiers.new("Tri", "TRIANGULATE")
    sel(lod)
    for md in list(lod.modifiers): bpy.ops.object.modifier_apply(modifier=md.name)
    md = lod.modifiers.new("Armature", "ARMATURE"); md.object = obj.parent
    return lod

def clearance(obj, ref_objs, max_d=0.08):
    """Min signed distance of obj verts from reference skin (rest pose); negative = inside."""
    bvh = Surf(ref_objs[0]) if len(ref_objs) == 1 else None
    worst = 1.0; inside = 0
    s = Surf(ref_objs[0])
    for v in obj.data.vertices:
        p = obj.matrix_world @ v.co
        loc, nor = s.nearest(p)
        if loc is None: continue
        d = (p - loc).length
        if d > max_d: continue
        sd = d if (p - loc).dot(nor) >= 0 else -d
        worst = min(worst, sd); inside += sd < 0
        if sd < 0 and inside % 8 == 1: print("INSIDE", [round(x, 3) for x in p], round(sd, 4))
    return round(worst, 4), inside

def export(name, objs, rig):
    os.makedirs(TMP, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    rig.select_set(True)
    for o in objs: o.select_set(True)
    bpy.context.view_layer.objects.active = rig
    path = os.path.join(TMP, name + ".gltf")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLTF_SEPARATE", export_texture_dir="textures",
                              use_selection=True, export_skins=True, export_animations=False, export_morph=False,
                              export_yup=True, export_apply=False, export_image_format="AUTO", export_tangents=False,
                              export_def_bones=False, export_rest_position_armature=True)
    os.makedirs(OUT, exist_ok=True)
    shutil.copy(path, os.path.join(OUT, name + ".gltf")); shutil.copy(os.path.join(TMP, name + ".bin"), os.path.join(OUT, name + ".bin"))
    js = json.load(open(path))
    return {"gltf": os.path.relpath(os.path.join(OUT, name + ".gltf"), ROOT),
            "images": sorted(i["uri"] for i in js.get("images", [])),
            "bytes_gltf": os.path.getsize(os.path.join(OUT, name + ".gltf")), "bytes_bin": os.path.getsize(os.path.join(OUT, name + ".bin"))}

# ================================================================== T3 VEST: Bulwark Carrier
def bulwark_carrier():
    reset()
    rig = bpy.data.objects["AppearanceProofRig"]; body = bpy.data.objects["ProofBody"]
    torso = proxy_from([body], "TorsoProxy", keep=lambda c: 0.80 < c.z < 1.36 and abs(c.x) < 0.215, smooth_iter=14)
    cord = pbr("T3_Cordura", "t3_cordura", 0.8); web = pbr("T3_Webbing", "t3_webbing", 0.9)
    poly = pbr("T3_Polymer", "t3_polymer", 0.8); steel = pbr("T3_Steel", "t3_steel", 0.7)
    loop = pbr("T3_Loop", "t3_loop", 1.0); dec = pbr("T3_Decals", "t3_decals", 0.6)
    parts = []
    # Plate bags: front and back, plate-cut shoulders, padded rounded edges with binding (rim).
    def plate_outline(z0, z1, half, top_half, cut_z):
        r = arc_pts(half - 0.028, z0 + 0.028, 0.028, 270, 360, 4) + [(half, cut_z)]
        r += [(half - (half - top_half) * (1 - math.cos(math.pi / 2 * t / 6)), cut_z + (z1 - cut_z - 0.02) * math.sin(math.pi / 2 * t / 6)) for t in range(1, 7)]
        r += arc_pts(top_half - 0.02, z1 - 0.02, 0.02, 0, 90, 3)[1:]
        out = []
        for p in r + [(-x, z) for (x, z) in reversed(r)]:
            if not out or (abs(out[-1][0] - p[0]) > 1e-5 or abs(out[-1][1] - p[1]) > 1e-5): out.append(p)
        return out
    panels = {}
    for side, y, pdir, z0, z1, cutz in (("Front", -0.45, 1, 0.905, 1.218, 1.125), ("Back", 0.45, -1, 0.905, 1.250, 1.150)):
        g = grid_panel("PlateBag" + side, plate_outline(z0, z1, 0.128, 0.064, cutz), y, (22, 28), pdir, torso, 0.020, plate_curve=1.6)
        set_mats(g, [cord, cord, web])
        so = g.modifiers.new("Solid", "SOLIDIFY"); so.thickness = 0.024; so.offset = 1.0; so.use_even_offset = True
        so.use_rim = True; so.material_offset_rim = 2
        apply_all(g)
        finish(g, None, bevel=0.0065, segs=2, smooth_angle=50)
        panels[side] = g; parts.append(g)
        vs = [g.matrix_world @ v.co for v in g.data.vertices]
        print("PANEL", side, len(vs), [round(min(v[i] for v in vs), 3) for i in range(3)], [round(max(v[i] for v in vs), 3) for i in range(3)])
    front, back = panels["Front"], panels["Back"]
    sf = Surf(front); sb = Surf(back); st = Surf(torso)
    # Cummerbund: elastic side wings round the waist, tucked under both plate bags.
    ring = []; faces = []; NA, NZ = 44, 4
    for j in range(NZ + 1):
        z = 0.922 + (1.065 - 0.922) * j / NZ
        for i in range(NA):
            a = 2 * math.pi * i / NA; ring.append((0.16 * math.sin(a), -0.045 + 0.13 * -math.cos(a), z))
    for j in range(NZ):
        for i in range(NA):
            k = (i + 1) % NA; faces.append((j * NA + i, j * NA + k, (j + 1) * NA + k, (j + 1) * NA + i))
    cb = mesh_obj("Cummerbund", ring, faces)
    shrink(cb, torso, 0.024); apply_all(cb)
    bm = bmesh.new(); bm.from_mesh(cb.data)
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if abs(f.calc_center_median().x) < 0.085], context="FACES")
    bm.to_mesh(cb.data); bm.free()
    sel(cb); bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.select_all(action="SELECT"); bpy.ops.mesh.normals_make_consistent(inside=False); bpy.ops.object.mode_set(mode="OBJECT")
    set_mats(cb, [cord, cord, web])
    so = cb.modifiers.new("Solid", "SOLIDIFY"); so.thickness = 0.011; so.offset = 1.0; so.use_rim = True; so.material_offset_rim = 2
    apply_all(cb); finish(cb, None, bevel=0.003, segs=2, smooth_angle=50); parts.append(cb)
    scb = Surf(cb)
    # MOLLE: webbing rows (bar-tacked every 38 mm) on the back bag and both cummerbund wings.
    def molle_row(name, surf, pts_fn, n, width=0.025):
        path = []; nors = []
        for i in range(n + 1):
            p, d = pts_fn(i / n)
            loc, nor = surf.ray(p, d)
            if loc is None: loc, nor = surf.nearest(p)
            path.append(loc + nor * 0.0006); nors.append(nor)
        o = sweep(name, path, nors, [(0, -width / 2), (0.0028, -width / 2), (0.0028, width / 2), (0, width / 2)])
        o.data.materials.append(web); return o
    for r in range(4):
        z = 0.95 + r * 0.038
        o = molle_row("MolleBack%d" % r, sb, lambda t, z=z: (Vector((-0.105 + 0.21 * t, 0.4, z)), Vector((0, -1, 0))), 16)
        finish(o, None, bevel=0.0008, segs=1); parts.append(o)
    for sgn in (-1, 1):
        for r in range(2):
            z = 0.962 + r * 0.04
            def side_pts(t, z=z, sgn=sgn):
                a = math.radians(55 + 70 * t); d = Vector((-sgn * math.sin(a), math.cos(a), 0))
                return Vector((0, -0.045, z)) - d * 0.4, d
            o = molle_row("MolleWing%d%d" % (sgn > 0, r), scb, side_pts, 14)
            finish(o, None, bevel=0.0008, segs=1); parts.append(o)
    # Bar tacks on the back rows.
    for r in range(4):
        z = 0.95 + r * 0.038
        for c in range(7):
            x = -0.096 + c * 0.032; loc, nor = sb.ray(Vector((x, 0.4, z)), Vector((0, -1, 0)))
            if loc is None: continue
            t = box((0.0045, 0.004, 0.027), (0, 0, 0), name="Tack"); orient(t, loc + nor * 0.0028, nor)
            finish(t, [web], bevel=0.0008, segs=1, uv=True); parts.append(t)
    # Front: triple magazine pouch row (flap, elastic band, pull tab) over the lower plate bag.
    for i, x in enumerate((-0.074, 0.0, 0.074)):
        loc, nor = sf.ray(Vector((x, -0.4, 0.968)), Vector((0, 1, 0)))
        nor = Vector((nor.x * 0.4, nor.y, 0)).normalized()
        pouch = box((0.066, 0.034, 0.104), (0, -0.017, 0), name="Pouch")
        bm = bmesh.new(); bm.from_mesh(pouch.data)
        bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=1, use_grid_fill=True); bm.to_mesh(pouch.data); bm.free()
        for v in pouch.data.vertices:   # gentle bulge on the front face (magazines inside)
            if v.co.y < -0.02: v.co.y -= 0.004 * (1 - (v.co.x / 0.033) ** 2) * (1 - (v.co.z / 0.052) ** 2)
        finish(pouch, [cord], bevel=0.007, segs=3, uv=False)
        flap = box((0.070, 0.038, 0.030), (0, -0.019, 0.045), name="Flap"); finish(flap, [cord], bevel=0.008, segs=3, uv=False)
        band = box((0.0705, 0.0355, 0.016), (0, -0.0175, -0.010), name="Band"); finish(band, [web], bevel=0.003, segs=2, uv=False)
        tab = box((0.013, 0.0035, 0.026), (0, -0.0395, 0.022), name="Tab")
        for v in tab.data.vertices:
            if v.co.z < 0.015: v.co.y -= 0.0015
        finish(tab, [web], bevel=0.0012, segs=2, uv=False)
        sn = cyl(0.0045, 0.003, (0, -0.0395, 0.040), rot=(math.pi / 2, 0, 0), verts=16, name="Snap"); finish(sn, [steel], bevel=0.0008, segs=1, uv=False)
        grp = [pouch, flap, band, tab, sn]
        for o in grp: uv_world(o)
        g = join(grp, "MagPouch%d" % i); orient(g, loc + nor * 0.026, nor); merge_duplicate_slots(g); parts.append(g)
    # Upper chest: loop panel with the embroidered name tape (decal) on top.
    lp = grid_panel("LoopPanel", [(-0.075, 1.062), (0.075, 1.062), (0.075, 1.122), (-0.075, 1.122)], -0.4, (16, 6), 1, front, 0.0006)
    set_mats(lp, [loop]); so = lp.modifiers.new("Solid", "SOLIDIFY"); so.thickness = 0.0022; so.offset = 1.0; apply_all(lp)
    finish(lp, None, bevel=0.0008, segs=1); parts.append(lp)
    tape = grid_panel("NameTape", [(-0.062, 1.078), (0.062, 1.078), (0.062, 1.108), (-0.062, 1.108)], -0.4, (16, 4), 1, front, 0.0030)
    set_mats(tape, [dec]); decal_uv(tape, (0, 0, 1024, 192), Vector((1, 0, 0)), Vector((0, 0, 1)))
    so = tape.modifiers.new("Solid", "SOLIDIFY"); so.thickness = 0.0012; so.offset = 1.0; apply_all(tape)
    finish(tape, None, uv=False); parts.append(tape)
    # Shoulder straps with pads, front side-release buckles, back drag handle.
    for sgn in (-1, 1):
        x = sgn * 0.090
        raw = [Vector((x, -0.090, 1.196)), Vector((x, -0.085, 1.250)), Vector((x, -0.060, 1.292)), Vector((x, -0.020, 1.312)),
               Vector((x, 0.020, 1.302)), Vector((x, 0.045, 1.262)), Vector((x, 0.052, 1.222))]
        # Densify then lay the strap 22 mm off the smoothed torso.
        path = []; nors = []
        for i in range(len(raw) - 1):
            for s in range(4):
                p = raw[i].lerp(raw[i + 1], s / 4); loc, nor = st.nearest(p); path.append(loc + nor * 0.022); nors.append(nor)
        loc, nor = st.nearest(raw[-1]); path.append(loc + nor * 0.022); nors.append(nor)
        strap = sweep("Strap", path, nors, rrect(0.012, 0.058, 0.004, 2)); strap.data.materials.append(cord)
        finish(strap, None, smooth_angle=60); parts.append(strap)
        # Buckle (male+female, polymer) where the strap meets the front bag.
        p0 = path[1]; n0 = nors[1]
        bk = box((0.046, 0.010, 0.030), (0, -0.005, 0), name="Buckle"); finish(bk, [poly], bevel=0.003, segs=2, uv=False)
        prong = box((0.030, 0.008, 0.020), (0, -0.006, -0.022), name="Prong"); finish(prong, [poly], bevel=0.0025, segs=2, uv=False)
        for o in (bk, prong): uv_world(o)
        b = join([bk, prong], "Buckle"); orient(b, p0 + n0 * 0.012, n0); parts.append(b)
    hp = [Vector((-0.050, 0.0, 1.233)), Vector((-0.040, 0.0, 1.262)), Vector((0.0, 0.0, 1.276)), Vector((0.040, 0.0, 1.262)), Vector((0.050, 0.0, 1.233))]
    hpath = []; hn = []
    for p in hp:
        loc, nor = sb.ray(Vector((p.x, 0.4, min(p.z, 1.236))), Vector((0, -1, 0)))
        base = loc if loc is not None else Vector((p.x, 0.07, p.z))
        q = Vector((p.x, base.y + 0.014, p.z)); hpath.append(q); hn.append(Vector((0, 1, 0)))
    dh = sweep("DragHandle", hpath, hn, rrect(0.010, 0.026, 0.004, 2)); dh.data.materials.append(web)
    finish(dh, None, smooth_angle=60); parts.append(dh)
    # Side wing hook tabs (loop field) + steel D-rings at the front corners.
    for sgn in (-1, 1):
        loc, nor = sf.ray(Vector((sgn * 0.118, -0.4, 1.040)), Vector((0, 1, 0)))
        if loc is None: continue
        dr = bpy.ops.mesh.primitive_torus_add(major_radius=0.010, minor_radius=0.0018, major_segments=20, minor_segments=8, location=(0, 0, 0), rotation=(math.pi / 2, 0, 0))
        d = bpy.context.active_object; d.scale = (1, 1, 1.4); finish(d, [steel], uv=True)
        orient(d, loc + nor * 0.003, nor); parts.append(d)
    # Care label on the back bag interior edge (visible at the hem).
    lab = grid_panel("CareLabel", [(-0.035, 0.912), (0.035, 0.912), (0.035, 0.950), (-0.035, 0.950)], 0.4, (6, 4), -1, back, 0.0012)
    set_mats(lab, [dec]); decal_uv(lab, (512, 192, 1024, 512), Vector((-1, 0, 0)), Vector((0, 0, 1)))
    finish(lab, None, uv=False); parts.append(lab)
    vest = join(parts, "BulwarkCarrier"); merge_duplicate_slots(vest)
    sel(vest); bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    report = {"lod0_tris": tris(vest), "materials": [m.name for m in vest.data.materials]}
    report["clearance_m"], report["verts_inside_skin"] = clearance(vest, [body])
    bpy.data.objects.remove(torso)
    transfer_weights(vest, body, {"pelvis", "spine_01", "spine_02", "spine_03", "clavicle_l", "clavicle_r"})
    bind(vest, rig, None)
    lod = make_lod1(vest, LOD1_RATIO); lod.parent = rig
    report["lod1_tris"] = tris(lod); report["bones"] = sorted(g.name for g in vest.vertex_groups)
    report.update(export("gear_body_armor_t3", [vest, lod], rig))
    return report

# ================================================================== T3 HELMET: Warden Helm
def warden_helm():
    reset()
    rig = bpy.data.objects["AppearanceProofRig"]; body = bpy.data.objects["ProofBody"]
    hair = [bpy.data.objects["hair_short02_v1"]]
    head = proxy_from([body], "HeadProxy", keep=lambda c: c.z > 1.33 and abs(c.x) < 0.12)
    hb = proxy_from([body] + hair, "HeadHair", keep=lambda c: c.z > 1.33 and abs(c.x) < 0.13)
    shell_m = pbr("T3_Shell", "t3_shell", 0.9); loop = pbr("T3_Loop", "t3_loop", 1.0); poly = pbr("T3_Polymer", "t3_polymer", 0.8)
    steel = pbr("T3_Steel", "t3_steel", 0.7); web = pbr("T3_Webbing", "t3_webbing", 0.9); dec = pbr("T3_Decals", "t3_decals", 0.6)
    C = Vector((0.0, -0.050, 1.452)); E = 2.5
    def sgnpow(v, p): return math.copysign(abs(v) ** p, v)
    def rim_z(theta):   # theta 0 = front (-Y), +-pi = back; high-cut over the ears
        a = abs(math.degrees(theta))
        keys = [(0, 1.500), (30, 1.499), (55, 1.489), (72, 1.474), (100, 1.470), (130, 1.452), (155, 1.428), (180, 1.418)]
        for (a0, z0), (a1, z1) in zip(keys, keys[1:]):
            if a <= a1:
                t = (a - a0) / (a1 - a0); t = t * t * (3 - 2 * t); return z0 + (z1 - z0) * t
        return keys[-1][1]
    # Fit the superellipsoid radii so every hair/head point above the rim clears it by 11 mm.
    R = Vector((0.100, 0.112, 0.112))
    hpts = [v for v in Surf(hb).v if v.z > 1.40]
    def f(p, R):
        d = p - C; return abs(d.x / R.x) ** E + abs(d.y / R.y) ** E + abs(d.z / R.z) ** E
    for _ in range(40):
        worst = max(f(p + (p - C).normalized() * 0.011, R) for p in hpts if p.z > rim_z(math.atan2(p.x, -p.y)) - 0.01)
        if worst <= 1.0: break
        R = R * (worst ** (1 / E)) ** 0.5
    # Shell grid in (theta, t): t=0 crown, t=1 rim; clean rim loop with a slight flare.
    NS, NR = 64, 16
    def surf_pt(theta, phi):
        n = Vector((math.sin(phi) * math.sin(theta), -math.sin(phi) * math.cos(theta), math.cos(phi)))
        return C + Vector((R.x * sgnpow(n.x, 2 / E), R.y * sgnpow(n.y, 2 / E), R.z * sgnpow(n.z, 2 / E)))
    def phi_rim(theta):
        zc = (rim_z(theta) - C.z) / R.z; return math.acos(max(-1, min(1, sgnpow(zc, E / 2))))
    verts = [tuple(C + Vector((0, 0, R.z)))]; faces = []
    for r in range(1, NR + 1):
        t = r / NR
        for s in range(NS):
            th = -math.pi + 2 * math.pi * s / NS
            p = surf_pt(th, phi_rim(th) * t)
            flare = 0.006 * max(0.0, (t - 0.82) / 0.18) ** 2
            q = p + (Vector((p.x - C.x, p.y - C.y, 0)).normalized() * flare if (p - C).length > 0 else Vector())
            verts.append(tuple(q))
    for s in range(NS): faces.append((0, 1 + s, 1 + (s + 1) % NS))
    for r in range(NR - 1):
        for s in range(NS):
            a = 1 + r * NS + s; b = 1 + r * NS + (s + 1) % NS
            faces.append((a, a + NS, b + NS, b))
    shell = mesh_obj("Shell", verts, faces)
    sel(shell); bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.select_all(action="SELECT"); bpy.ops.mesh.normals_make_consistent(inside=False); bpy.ops.object.mode_set(mode="OBJECT")
    set_mats(shell, [shell_m, loop, poly])
    so = shell.modifiers.new("Solid", "SOLIDIFY"); so.thickness = 0.008; so.offset = -1.0; so.use_even_offset = True
    so.use_rim = True; so.material_offset = 1; so.material_offset_rim = 2
    apply_all(shell); finish(shell, None, bevel=0.0012, segs=2, smooth_angle=50)
    ss = Surf(shell); parts = [shell]
    # Rubber edge trim along the rim.
    rim = []; rn = []
    for s in range(NS + 1):
        th = -math.pi + 2 * math.pi * (s % NS) / NS; t = 1.0
        p = surf_pt(th, phi_rim(th)); p = p + Vector((p.x - C.x, p.y - C.y, 0)).normalized() * 0.006
        rim.append(p - Vector((0, 0, 0.0005))); rn.append(Vector((p.x - C.x, p.y - C.y, 0)).normalized())
    prof = [(0.0055 * math.cos(2 * math.pi * k / 8) - 0.004, 0.0055 * math.sin(2 * math.pi * k / 8)) for k in range(8)]
    trim = sweep("EdgeTrim", rim[:-1], rn[:-1], prof, closed=True, cap=False); trim.data.materials.append(poly)
    finish(trim, None, smooth_angle=70); parts.append(trim)
    def on_shell(theta, z, off):
        d = Vector((math.sin(theta), -math.cos(theta), 0))
        loc, nor = ss.ray(Vector((C.x, C.y, z)) + d * 0.4, -d)
        return loc + nor * off, nor
    # Front NVG shroud: wedge body, mount slot, three steel screws.
    loc, nor = on_shell(0.0, 1.515, 0.0)
    sh = box((0.050, 0.014, 0.034), (0, -0.007, 0), name="Shroud")
    for v in sh.data.vertices:
        if v.co.z > 0: v.co.x *= 0.78
    finish(sh, [poly], bevel=0.0025, segs=2, uv=False)
    slot = box((0.026, 0.004, 0.012), (0, -0.0145, -0.004), name="Slot"); finish(slot, [steel], bevel=0.001, segs=1, uv=False)
    grp = [sh, slot]
    for x, z in ((-0.017, -0.009), (0.017, -0.009), (0.0, 0.010)):
        sc = cyl(0.0028, 0.003, (x, -0.0148, z), rot=(math.pi / 2, 0, 0), verts=12, name="Screw"); finish(sc, [steel], bevel=0.0006, segs=1, uv=False); grp.append(sc)
    for o in grp: uv_world(o)
    g = join(grp, "Shroud"); orient(g, loc, nor); merge_duplicate_slots(g); parts.append(g)
    # Side accessory rails (sweep along the shell, parallel to the rim) with slots and end screws.
    for sgn in (-1, 1):
        path = []; nors = []
        for k in range(17):
            th = sgn * math.radians(62 + 50 * k / 16)
            p, n = on_shell(th, rim_z(th) + 0.020, 0.0); path.append(p); nors.append(n)
        rail = sweep("Rail", path, nors, rrect(0.0075, 0.014, 0.0022, 2)); rail.data.materials.append(poly)
        finish(rail, None, smooth_angle=45); parts.append(rail)
        for k in (2, 5, 8, 11, 14):
            p = path[k]; n = nors[k]; t = (path[k + 1] - path[k - 1]).normalized()
            sl = box((0.0045, 0.0016, 0.0095), (0, 0, 0), name="RailSlot")
            up = n.cross(t).normalized(); orient(sl, p + n * 0.0074, n, up=up); finish(sl, [steel], bevel=0.0004, segs=1); parts.append(sl)
        for k in (0, 16):
            p = path[k]; n = nors[k]
            sc = cyl(0.0032, 0.003, (0, 0, 0), rot=(math.pi / 2, 0, 0), verts=14, name="RailScrew"); orient(sc, p + n * 0.0085, n)
            finish(sc, [steel], bevel=0.0006, segs=1); parts.append(sc)
    # Loop fields: crown patch and rear patch (decal: WARDEN + reflective strip).
    crown = []; cf = []; NU, NV = 12, 10
    for i in range(NU + 1):
        for j in range(NV + 1):
            x = -0.045 + 0.09 * i / NU; y = C.y - 0.035 + 0.075 * j / NV
            loc, nor = ss.ray(Vector((x, y, 1.8)), Vector((0, 0, -1))); crown.append(loc + nor * 0.0009)
    for i in range(NU):
        for j in range(NV):
            a = i * (NV + 1) + j; cf.append((a, a + NV + 1, a + NV + 2, a + 1))
    cp = mesh_obj("CrownLoop", crown, cf); set_mats(cp, [loop])
    so = cp.modifiers.new("Solid", "SOLIDIFY"); so.thickness = 0.0018; so.offset = 1.0; apply_all(cp)
    sel(cp); bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.select_all(action="SELECT"); bpy.ops.mesh.normals_make_consistent(inside=False); bpy.ops.object.mode_set(mode="OBJECT")
    finish(cp, None, bevel=0.0006, segs=1); parts.append(cp)
    rear = []; rf = []
    for i in range(NU + 1):
        for j in range(6 + 1):
            x = -0.036 + 0.072 * i / NU; z = 1.452 + 0.046 * j / 6
            loc, nor = ss.ray(Vector((x, 0.4, z)), Vector((0, -1, 0))); rear.append(loc + nor * 0.0010)
    for i in range(NU):
        for j in range(6):
            a = i * 7 + j; rf.append((a, a + 1, a + 8, a + 7))
    rp = mesh_obj("RearPatch", rear, rf); set_mats(rp, [dec])
    sel(rp); bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.select_all(action="SELECT"); bpy.ops.mesh.normals_make_consistent(inside=False); bpy.ops.object.mode_set(mode="OBJECT")
    if sum(p.normal.y for p in rp.data.polygons) < 0:
        sel(rp); bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.select_all(action="SELECT"); bpy.ops.mesh.flip_normals(); bpy.ops.object.mode_set(mode="OBJECT")
    decal_uv(rp, (0, 192, 512, 512), Vector((-1, 0, 0)), Vector((0, 0, 1)))
    so = rp.modifiers.new("Solid", "SOLIDIFY"); so.thickness = 0.0014; so.offset = 1.0; apply_all(rp)
    finish(rp, None, uv=False); parts.append(rp)
    # Retention: front + rear straps per side meeting at a jaw junction, chin strap with buckle, chin cup.
    sh_head = Surf(hb)   # straps and harness ride over the hair, not under it
    def skin_path(raw, off, n=5):
        path = []; nors = []
        for i in range(len(raw) - 1):
            for s in range(n):
                p = raw[i].lerp(raw[i + 1], s / n); loc, nor = sh_head.nearest(p); path.append(loc + nor * off); nors.append(nor)
        loc, nor = sh_head.nearest(raw[-1]); path.append(loc + nor * off); nors.append(nor)
        return path, nors
    def rim_point(deg, sgn):
        th = sgn * math.radians(deg); p = surf_pt(th, phi_rim(th)); return p - Vector((0, 0, 0.004))
    sprof = [(0, -0.0085), (0.0016, -0.0085), (0.0016, 0.0085), (0, 0.0085)]
    for sgn in (-1, 1):
        j = Vector((sgn * 0.072, -0.095, 1.385))
        for deg in (62, 128):
            a = rim_point(deg, sgn)
            mid = a.lerp(j, 0.5); mid = mid + Vector((sgn * 0.01, 0, 0))
            path, nors = skin_path([a, mid, j], 0.0062)
            s = sweep("Strap", path, nors, sprof); s.data.materials.append(web); finish(s, None, smooth_angle=60); parts.append(s)
        chin = [j, Vector((sgn * 0.045, -0.135, 1.352)), Vector((0.0, -0.150, 1.345))]
        path, nors = skin_path(chin, 0.0050)
        s = sweep("ChinStrap", path, nors, sprof); s.data.materials.append(web); finish(s, None, smooth_angle=60); parts.append(s)
        jn = box((0.020, 0.006, 0.020), (0, 0, 0), name="Junction"); loc, nor = sh_head.nearest(j)
        orient(jn, loc + nor * 0.0085, nor); finish(jn, [poly], bevel=0.0018, segs=2); parts.append(jn)
    loc, nor = sh_head.nearest(Vector((0.040, -0.140, 1.350)))
    bk = box((0.026, 0.008, 0.016), (0, 0, 0), name="ChinBuckle"); orient(bk, loc + nor * 0.009, nor, up=Vector((0, -0.3, 1)))
    finish(bk, [poly], bevel=0.002, segs=2); parts.append(bk)
    loc, nor = sh_head.nearest(Vector((0.0, -0.160, 1.352)))
    bpy.ops.mesh.primitive_uv_sphere_add(segments=20, ring_count=10, radius=0.024, location=(0, 0, 0))
    cup = bpy.context.active_object; cup.scale = (1.0, 0.45, 0.65)
    bm = bmesh.new(); bm.from_mesh(cup.data); bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.y > 0.002], context="VERTS"); bm.to_mesh(cup.data); bm.free()
    so = cup.modifiers.new("Solid", "SOLIDIFY"); so.thickness = 0.003; apply_all(cup)
    orient(cup, loc + nor * 0.008, nor); finish(cup, [web], smooth_angle=60); parts.append(cup)
    # Rear retention dial on its harness band under the back of the shell.
    loc, nor = sh_head.ray(Vector((0, 0.4, 1.408)), Vector((0, -1, 0)))
    band_raw = [rim_point(140, -1), Vector((-0.045, loc.y - 0.004, 1.405)), Vector((0, loc.y, 1.404)), Vector((0.045, loc.y - 0.004, 1.405)), rim_point(140, 1)]
    path, nors = skin_path(band_raw, 0.006)
    hband = sweep("Harness", path, nors, [(0, -0.009), (0.0022, -0.009), (0.0022, 0.009), (0, 0.009)]); hband.data.materials.append(poly)
    finish(hband, None, smooth_angle=60); parts.append(hband)
    dial = cyl(0.017, 0.011, (0, -0.0055, 0), rot=(math.pi / 2, 0, 0), verts=48, name="Dial")
    for i, v in enumerate(dial.data.vertices):
        if i % 2 == 0: v.co.x *= 0.93; v.co.z *= 0.93
    finish(dial, [poly], bevel=0.0012, segs=2, uv=False); uv_world(dial)
    cap = cyl(0.009, 0.003, (0, -0.0115, 0), rot=(math.pi / 2, 0, 0), verts=24, name="DialCap"); finish(cap, [steel], bevel=0.0008, segs=1)
    d = join([dial, cap], "Dial"); n2 = Vector((0, 1, 0)); orient(d, Vector((0, loc.y + 0.008, 1.404)), n2); merge_duplicate_slots(d); parts.append(d)
    helm = join(parts, "WardenHelm"); merge_duplicate_slots(helm)
    sel(helm); bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    report = {"lod0_tris": tris(helm), "materials": [m.name for m in helm.data.materials], "radii_m": [round(x, 4) for x in R]}
    report["clearance_m"], report["verts_inside_skin"] = clearance(helm, [hb])
    for o in (head, hb): bpy.data.objects.remove(o)
    rigid_weights(helm, "head"); bind(helm, rig, None)
    lod = make_lod1(helm, LOD1_RATIO); lod.parent = rig
    report["lod1_tris"] = tris(lod); report["bones"] = ["head"]
    report.update(export("gear_helmet_t3", [helm, lod], rig))
    return report

if __name__ == "__main__":
    import sys
    which = os.environ.get("GEAR_E0_ONLY", "")
    report = {}
    if which in ("", "vest"): report["gear_body_armor_t3"] = bulwark_carrier()
    if which in ("", "helmet"): report["gear_helmet_t3"] = warden_helm()
    for k in report: report[k]["tool"] = "tools/blender_midstyle/build_gear_e0.py (gear art E0)"
    print("GEAR_E0", json.dumps(report))
    rp = os.path.join(OUT, "BUILD-REPORT.json")
    old = json.load(open(rp)) if os.path.exists(rp) else {}
    old.update(report); json.dump(old, open(rp, "w"), indent=1)
