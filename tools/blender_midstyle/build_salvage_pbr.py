# Mid-to-high poly PBR redo of three salvage pieces (original designs): survey drive,
# research core, sensor head. Blender 4.2, meter scale, Z-up; glTF exporter converts to Y-up.
# Every object: bevelled edges, modifiers and transforms applied, cube-projected UVs at a
# fixed texel density (1 UV unit = 0.12 m) on tileable PBR sets from tools/salvage_pbr/
# (base colour, ORM roughness/metallic, OpenGL normal). Labels are UV 0-1 decal planes.
#   python3 tools/salvage_pbr/make_textures.py
#   blender -b --factory-startup -P tools/blender_midstyle/build_salvage_pbr.py
import bpy, math, os, json
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "raid", "assets", "salvage")
TEX = os.path.join(ROOT, "tools", "salvage_pbr", "out")
MATS = {}
UV_CUBE = 0.12

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.unit_settings.system = "METRIC"
    bpy.context.scene.unit_settings.scale_length = 1.0
    MATS.clear()

def _img(name, non_color):
    path = os.path.join(TEX, name + ".png")
    img = bpy.data.images.load(path, check_existing=True)
    if non_color: img.colorspace_settings.name = "Non-Color"
    return img

def pbr(name, tex, emit=None, emit_strength=0.0, normal_strength=1.0):
    """Principled BSDF fed by base / ORM (G rough, B metal) / normal maps."""
    if name in MATS: return MATS[name]
    m = bpy.data.materials.new(name); m.use_nodes = True; m.use_backface_culling = True
    nt = m.node_tree; b = nt.nodes["Principled BSDF"]
    base = nt.nodes.new("ShaderNodeTexImage"); base.image = _img(tex + "_base", False)
    nt.links.new(base.outputs["Color"], b.inputs["Base Color"])
    orm = nt.nodes.new("ShaderNodeTexImage"); orm.image = _img(tex + "_orm", True)
    sep = nt.nodes.new("ShaderNodeSeparateColor")
    nt.links.new(orm.outputs["Color"], sep.inputs["Color"])
    nt.links.new(sep.outputs["Green"], b.inputs["Roughness"])
    nt.links.new(sep.outputs["Blue"], b.inputs["Metallic"])
    nor = nt.nodes.new("ShaderNodeTexImage"); nor.image = _img(tex + "_normal", True)
    nm = nt.nodes.new("ShaderNodeNormalMap"); nm.inputs["Strength"].default_value = normal_strength
    nt.links.new(nor.outputs["Color"], nm.inputs["Color"]); nt.links.new(nm.outputs["Normal"], b.inputs["Normal"])
    if emit:
        h = emit.lstrip("#"); ec = [(int(h[i:i + 2], 16) / 255.0) ** 2.2 for i in (0, 2, 4)]
        b.inputs["Emission Color"].default_value = (*ec, 1); b.inputs["Emission Strength"].default_value = emit_strength
    MATS[name] = m; return m

def led(name, hexcol, strength=6.0):
    if name in MATS: return MATS[name]
    m = bpy.data.materials.new(name); m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    h = hexcol.lstrip("#"); c = [(int(h[i:i + 2], 16) / 255.0) ** 2.2 for i in (0, 2, 4)]
    b.inputs["Base Color"].default_value = (*c, 1); b.inputs["Roughness"].default_value = 0.15
    b.inputs["Emission Color"].default_value = (*c, 1); b.inputs["Emission Strength"].default_value = strength
    MATS[name] = m; return m

def _apply(obj):
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = obj; obj.select_set(True)
    for md in list(obj.modifiers): bpy.ops.object.modifier_apply(modifier=md.name)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)

def finish(obj, material, bevel=0.0, segs=3, subd=0, smooth=True, uv="cube", weld=False):
    # Bake scale/rotation first so bevel widths are real metres (not object-local units).
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = obj; obj.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    if bevel > 0:
        md = obj.modifiers.new("Bevel", "BEVEL"); md.width = bevel; md.segments = segs; md.limit_method = "ANGLE"
        md.harden_normals = False
    if subd > 0:
        md = obj.modifiers.new("Subd", "SUBSURF"); md.levels = subd; md.render_levels = subd
    tri = obj.modifiers.new("NgonTris", "TRIANGULATE"); tri.min_vertices = 5  # ngon caps -> tris (tangents)
    _apply(obj)
    if smooth:
        bpy.ops.object.shade_smooth_by_angle(angle=math.radians(35))
    if uv == "cube":
        bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.uv.cube_project(cube_size=UV_CUBE, correct_aspect=True, clip_to_bounds=False, scale_to_bounds=False)
        bpy.ops.object.mode_set(mode="OBJECT")
    obj.data.materials.clear(); obj.data.materials.append(material)
    obj.select_set(False)
    return obj

def box(size, loc, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    o = bpy.context.active_object; o.scale = size; return o

def cyl(r, depth, loc, verts=48, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=depth, location=loc, rotation=rot)
    return bpy.context.active_object

def sphere(r, loc, segs=48, rings=24):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segs, ring_count=rings, radius=r, location=loc)
    return bpy.context.active_object

def torus(major, minor, loc, rot=(0, 0, 0), maj=48, mn=12):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, location=loc, rotation=rot, major_segments=maj, minor_segments=mn)
    return bpy.context.active_object

def decal(size, loc, material, rot=(0, 0, 0)):
    """UV 0-1 label plane (text texture)."""
    bpy.ops.mesh.primitive_plane_add(size=1, location=loc, rotation=rot)
    o = bpy.context.active_object; o.scale = (size[0], size[1], 1)
    _apply(o)
    o.data.materials.clear(); o.data.materials.append(material)
    return o

def screw(loc, steel, slot_mat, r=0.0032, axis="z", turn=0.0):
    rot = {"z": (0, 0, turn), "x": (0, math.pi / 2, turn), "y": (math.pi / 2, 0, turn)}[axis]
    head = cyl(r, r * 0.7, loc, 24, rot); finish(head, steel, bevel=r * 0.35, segs=3)
    n = Vector({"z": (0, 0, 1), "x": (1, 0, 0), "y": (0, 1, 0)}[axis])
    top = Vector(loc) + n * (r * 0.36)
    for a in (0.0, math.pi / 2):
        s = box((r * 1.6, r * 0.28, r * 0.25) if axis == "z" else (r * 0.25, r * 1.6, r * 0.28) if axis == "x" else (r * 1.6, r * 0.25, r * 0.28), top)
        s.rotation_euler = (0, 0, turn + a) if axis == "z" else ((turn + a, 0, 0) if axis == "x" else (0, turn + a, 0))
        finish(s, slot_mat, smooth=False)

def export(name):
    for o in bpy.context.scene.objects: o.select_set(o.type == "MESH")
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, name + ".glb"), export_format="GLB", use_selection=True,
        export_apply=True, export_yup=True, export_image_format="AUTO", export_tangents=True)
    tris = 0; mats = set()
    for o in bpy.context.scene.objects:
        if o.type == "MESH":
            o.data.calc_loop_triangles(); tris += len(o.data.loop_triangles)
            for m in o.data.materials: mats.add(m.name)
    pts = [o.matrix_world @ Vector(c) for o in bpy.context.scene.objects if o.type == "MESH" for c in o.bound_box]
    dims = [round(max(p[k] for p in pts) - min(p[k] for p in pts), 3) for k in range(3)]
    imgs = sorted({(i.name, i.size[0], i.size[1]) for i in bpy.data.images if i.users > 0 and i.size[0] > 0})
    return {"tris": tris, "size_m": dims, "materials": sorted(mats), "textures": [{"name": n, "px": [w, h]} for n, w, h in imgs]}

# ---------------------------------------------------------------- survey drive
def survey_drive():
    case = pbr("Drive_case_paint", "drive_case"); rub = pbr("Drive_rubber", "drive_rubber")
    steel = pbr("Drive_steel", "steel"); dark = pbr("Drive_dark_steel", "dark_steel"); gold = pbr("Drive_contacts_gold", "gold")
    lab = pbr("Drive_label", "drive_label", normal_strength=0.6); green = led("Drive_status_led", "#38ff7a", 8.0)
    L, W, H = 0.150, 0.096, 0.034
    # Sealed two-part shell with a dark gasket seam between the halves.
    lower = box((L, W, H * 0.48), (0, 0, H * 0.24)); finish(lower, case, bevel=0.0045, segs=4)
    upper = box((L, W, H * 0.48), (0, 0, H * 0.76)); finish(upper, case, bevel=0.0045, segs=4)
    gasket = box((L - 0.004, W - 0.004, H * 0.06), (0, 0, H * 0.5)); finish(gasket, rub, bevel=0.0015, segs=2)
    # Raised top panel with a recessed frame for the label.
    panel = box((L * 0.74, W * 0.76, 0.003), (-0.004, 0, H + 0.0012)); finish(panel, case, bevel=0.0012, segs=3)
    recess = box((L * 0.62, W * 0.56, 0.0012), (-0.008, 0, H + 0.0029)); finish(recess, dark, bevel=0.0005, segs=2)
    decal((L * 0.58, W * 0.50), (-0.008, 0, H + 0.0037), lab)
    # Screws: four on the top panel, six along the seam flange (sealed casing).
    for sx in (-1, 1):
        for sy in (-1, 1):
            screw((sx * (L * 0.37 - 0.008) - 0.004, sy * (W * 0.38 - 0.003), H + 0.0035), steel, dark, r=0.0028, turn=0.3 * sx * sy)
    for sx in (-0.33, 0.0, 0.33):
        for sy in (-1, 1):
            screw((sx * L, sy * (W / 2 + 0.0004), H * 0.5), steel, dark, r=0.0024, axis="y", turn=0.4 + sx)
    # Rubber corner bumpers.
    for sx in (-1, 1):
        for sy in (-1, 1):
            b = box((0.022, 0.022, H + 0.006), (sx * (L / 2 - 0.007), sy * (W / 2 - 0.007), H / 2)); finish(b, rub, bevel=0.006, segs=5)
            ridge = box((0.024, 0.024, 0.002), (sx * (L / 2 - 0.007), sy * (W / 2 - 0.007), H * 0.5)); finish(ridge, rub, bevel=0.0009, segs=2)
    # Connector port on the +X end: steel bezel, dark socket, 2 rows of gold contacts, hinged dust flap.
    px = L / 2 + 0.0006
    bezel = box((0.004, 0.040, 0.016), (px, 0, H * 0.52)); finish(bezel, steel, bevel=0.0013, segs=3)
    sock = box((0.003, 0.032, 0.009), (px + 0.0012, 0, H * 0.52)); finish(sock, dark, bevel=0.0007, segs=2)
    for row in (-1, 1):
        for k in range(9):
            pin = box((0.0012, 0.0016, 0.0014), (px + 0.0022, -0.0128 + k * 0.0032, H * 0.52 + row * 0.0022)); finish(pin, gold, bevel=0.0003, segs=1)
    hinge = cyl(0.0017, 0.034, (px + 0.0024, 0, H * 0.52 + 0.0105), 24, (math.pi / 2, 0, 0)); finish(hinge, steel, bevel=0.0004, segs=2)
    flap = box((0.0016, 0.036, 0.012), (px + 0.0062, 0, H * 0.52 + 0.016), (0, math.radians(-55), 0)); finish(flap, rub, bevel=0.0007, segs=3)
    # Status LED in a steel bezel next to the label, plus a recessed write-protect switch.
    lb = cyl(0.0042, 0.0022, (L * 0.30, W * 0.27, H + 0.003), 32); finish(lb, steel, bevel=0.0006, segs=2)
    dome = sphere(0.0029, (L * 0.30, W * 0.27, H + 0.0042), 32, 16); dome.scale = (1, 1, 0.55); finish(dome, green)
    sw_r = box((0.012, 0.006, 0.0014), (L * 0.30, -W * 0.27, H + 0.0025)); finish(sw_r, dark, bevel=0.0005, segs=2)
    sw = box((0.0045, 0.004, 0.0024), (L * 0.30 - 0.003, -W * 0.27, H + 0.0035)); finish(sw, steel, bevel=0.0006, segs=2)
    # Vent slots on the long side and a tie-down loop on the -X end.
    for k in range(10):
        v = box((0.006, 0.0012, 0.0016), (-0.04 + k * 0.009, -W / 2 - 0.0002, H * 0.28)); finish(v, dark, bevel=0.0004, segs=1)
    loop = torus(0.009, 0.0016, (-L / 2 - 0.006, 0, H * 0.5), (0, math.pi / 2, 0), 40, 12); finish(loop, steel)
    for sy in (-1, 1):
        lug = box((0.008, 0.005, 0.008), (-L / 2 - 0.002, sy * 0.009, H * 0.5)); finish(lug, steel, bevel=0.0015, segs=3)
    return export("salvage_survey_drive")

# -------------------------------------------------------------- research core
def research_core():
    case = pbr("Core_case", "core_case"); steel = pbr("Core_steel", "steel"); dark = pbr("Core_dark_steel", "dark_steel")
    rub = pbr("Core_rubber", "drive_rubber"); lab = pbr("Core_label", "core_label", normal_strength=0.6)
    glow = pbr("Core_window_glow", "dark_steel", emit="#5fe3ff", emit_strength=2.5); amber = led("Core_status_led", "#ffb030", 7.0)
    R, H = 0.058, 0.150
    body = cyl(R, H * 0.72, (0, 0, H * 0.46), 64); finish(body, case, bevel=0.004, segs=4)
    # Heat-sink ribs on the lower half.
    for k in range(7):
        rib = torus(R + 0.0012, 0.0022, (0, 0, H * 0.16 + k * 0.0085), (0, 0, 0), 64, 10); finish(rib, dark)
    # Glass window band with the glowing core behind four vertical guard bars.
    win = cyl(R + 0.0008, 0.022, (0, 0, H * 0.66), 64); finish(win, glow, bevel=0.002, segs=3)
    for k in range(8):
        a = k * math.pi / 4
        bar = box((0.004, 0.006, 0.026), (math.cos(a) * (R + 0.002), math.sin(a) * (R + 0.002), H * 0.66), (0, 0, a)); finish(bar, steel, bevel=0.0012, segs=2)
    # Top and bottom end caps with screws.
    for z, s in ((H * 0.84, 1), (H * 0.09, -1)):
        cap = cyl(R + 0.004, 0.012, (0, 0, z), 64); finish(cap, steel, bevel=0.003, segs=4)
        for k in range(8):
            a = k * math.pi / 4 + math.pi / 8
            screw((math.cos(a) * (R - 0.006), math.sin(a) * (R - 0.006), z + s * 0.0062), steel, dark, r=0.0028, turn=a) if s > 0 else None
    foot = cyl(R - 0.004, 0.008, (0, 0, H * 0.035), 64); finish(foot, rub, bevel=0.003, segs=3)
    # Carry frame: two arched steel handles over the top cap.
    for a in (0.0, math.pi / 2):
        h = torus(0.034, 0.0035, (0, 0, H * 0.86), (math.pi / 2, 0, a), 48, 12)
        bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.select_all(action="DESELECT"); bpy.ops.object.mode_set(mode="OBJECT")
        for v in h.data.vertices:
            v.select = (h.matrix_world @ v.co).z < H * 0.86 - 0.001
        bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.delete(type="VERT"); bpy.ops.object.mode_set(mode="OBJECT")
        finish(h, steel)
    # Data connector on the top cap, status LED, flat label plate on the body.
    port = box((0.020, 0.012, 0.006), (0, 0, H * 0.875)); finish(port, dark, bevel=0.0015, segs=3)
    for k in range(6):
        pin = box((0.0016, 0.004, 0.0012), (-0.0075 + k * 0.003, 0, H * 0.875 + 0.0032)); finish(pin, pbr("Core_gold", "gold"), bevel=0.0003, segs=1)
    ledb = cyl(0.004, 0.003, (0.022, 0.022, H * 0.875), 32); finish(ledb, steel, bevel=0.0007, segs=2)
    ld = sphere(0.0028, (0.022, 0.022, H * 0.877), 32, 16); ld.scale = (1, 1, 0.6); finish(ld, amber)
    plate = box((0.004, 0.064, 0.034), (R + 0.0005, 0, H * 0.43)); finish(plate, steel, bevel=0.0012, segs=3)
    decal((0.060, 0.030), (R + 0.0028, 0, H * 0.43), lab, (math.pi / 2, 0, math.pi / 2))
    for sy in (-1, 1):
        for sz in (-1, 1):
            screw((R + 0.0028, sy * 0.028, H * 0.43 + sz * 0.0145), steel, dark, r=0.0016, axis="x")
    return export("salvage_research_core")

# ----------------------------------------------------------------- sensor head
def sensor():
    dome_m = pbr("Sensor_dome", "sensor_dome"); collar = pbr("Sensor_collar", "sensor_collar"); steel = pbr("Sensor_steel", "steel")
    dark = pbr("Sensor_dark_steel", "dark_steel"); rub = pbr("Sensor_rubber", "drive_rubber"); lab = pbr("Sensor_label", "sensor_label", normal_strength=0.6)
    red = led("Sensor_status_led", "#ff4a3a", 7.0)
    R = 0.042
    body = cyl(R, 0.070, (0, 0, 0.075), 64); finish(body, dome_m, bevel=0.003, segs=3)
    cap = sphere(R, (0, 0, 0.110), 64, 32)
    for v in cap.data.vertices:
        if v.co.z < 0: v.co.z = 0
    finish(cap, dome_m)
    # Dome sensor window ring and vent louvres.
    ring = torus(R * 0.72, 0.0025, (0, 0, 0.110 + R * 0.69), (0, 0, 0), 64, 12); finish(ring, dark)
    win = sphere(R * 0.70, (0, 0, 0.110 + R * 0.30), 48, 24); win.scale = (1, 1, 0.6); finish(win, pbr("Sensor_lens", "dark_steel", emit="#2a3c48", emit_strength=0.6))
    for k in range(12):
        a = k * math.pi / 6
        lv = box((0.0025, 0.012, 0.0022), (math.cos(a) * (R + 0.0005), math.sin(a) * (R + 0.0005), 0.095), (0, 0, a)); finish(lv, dark, bevel=0.0006, segs=2)
    # Painted metal collar with screws, mast clamp and bracket.
    col = cyl(R + 0.004, 0.018, (0, 0, 0.040), 64); finish(col, collar, bevel=0.002, segs=3)
    for k in range(6):
        a = k * math.pi / 3
        screw((math.cos(a) * (R + 0.0042), math.sin(a) * (R + 0.0042), 0.040), steel, dark, r=0.0022, axis="x", turn=a) if False else None
        s = cyl(0.0022, 0.0018, (math.cos(a) * (R + 0.0048), math.sin(a) * (R + 0.0048), 0.040), 20, (0, math.pi / 2, a)); finish(s, steel, bevel=0.0006, segs=2)
    base = cyl(R * 0.62, 0.030, (0, 0, 0.016), 48); finish(base, collar, bevel=0.002, segs=3)
    clamp = box((0.016, 0.050, 0.020), (-R * 0.55, 0, 0.012)); finish(clamp, collar, bevel=0.003, segs=3)
    for sy in (-1, 1):
        bolt = cyl(0.003, 0.024, (-R * 0.55, sy * 0.018, 0.012), 24, (0, math.pi / 2, 0)); finish(bolt, steel, bevel=0.0008, segs=2)
        nut = cyl(0.0048, 0.004, (-R * 0.55 - 0.012, sy * 0.018, 0.012), 6, (0, math.pi / 2, 0)); finish(nut, steel, bevel=0.0007, segs=2)
    # Cable gland connector with a cut cable stub, LED and label plate.
    gland = cyl(0.0065, 0.014, (R * 0.35, -R * 0.4, 0.002), 32, (math.radians(60), 0, 0)); finish(gland, steel, bevel=0.0012, segs=3)
    nut = cyl(0.008, 0.005, (R * 0.35, -R * 0.37, 0.006), 6, (math.radians(60), 0, 0)); finish(nut, steel, bevel=0.0008, segs=2)
    cable = cyl(0.0042, 0.040, (R * 0.35, -R * 0.4 - 0.022, -0.010), 24, (math.radians(70), 0, 0)); finish(cable, rub, bevel=0.0008, segs=2)
    cu = cyl(0.0028, 0.002, (R * 0.35, -R * 0.4 - 0.041, -0.017), 16, (math.radians(70), 0, 0)); finish(cu, pbr("Sensor_copper", "gold"))
    lb = cyl(0.0034, 0.0025, (R + 0.0035, 0.018, 0.058), 24, (0, math.pi / 2, 0)); finish(lb, steel, bevel=0.0005, segs=2)
    ld = sphere(0.0024, (R + 0.0052, 0.018, 0.058), 24, 12); ld.scale = (0.6, 1, 1); finish(ld, red)
    plate = box((0.003, 0.044, 0.022), (R + 0.001, -0.006, 0.078)); finish(plate, steel, bevel=0.001, segs=2)
    decal((0.040, 0.020), (R + 0.0028, -0.006, 0.078), lab, (math.pi / 2, 0, math.pi / 2))
    return export("salvage_sensor")

report_path = os.path.join(OUT, "BUILD-REPORT.json")
report = json.load(open(report_path)) if os.path.exists(report_path) else {}
for fn in (survey_drive, research_core, sensor):
    reset()
    key = "salvage_" + {"survey_drive": "survey_drive", "research_core": "research_core", "sensor": "sensor"}[fn.__name__]
    r = fn(); r["tool"] = "tools/blender_midstyle/build_salvage_pbr.py (PBR redo)"
    report[key] = r
    print("SALVAGE_PBR", key, json.dumps(r))
json.dump(report, open(report_path, "w"), indent=1)
