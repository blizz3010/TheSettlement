# TASKS item 13: raid salvage models (original designs) for Atlas's Salvage tab icons.
# Blender 4.2, meter scale, Z-up (glTF exporter converts to Godot Y-up).
# Mid-to-high poly: bevels + subdivision, all modifiers and transforms applied.
#   blender -b --factory-startup -P tools/blender_midstyle/build_salvage_items.py
import bpy, bmesh, math, os, json
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "raid", "assets", "salvage")
os.makedirs(OUT, exist_ok=True)
MATS = {}

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.unit_settings.system = "METRIC"
    bpy.context.scene.unit_settings.scale_length = 1.0
    MATS.clear()

def lin(v):
    # Hex colours are authored in sRGB; Principled/glTF base colour is linear.
    return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4

def mat(name, hexcol, rough=0.6, metal=0.0, emit=None, emit_strength=0.0):
    if name in MATS: return MATS[name]
    m = bpy.data.materials.new(name); m.use_nodes = True; m.use_backface_culling = True
    b = m.node_tree.nodes["Principled BSDF"]
    h = hexcol.lstrip("#"); c = [lin(int(h[i:i + 2], 16) / 255.0) for i in (0, 2, 4)]
    b.inputs["Base Color"].default_value = (*c, 1); m.diffuse_color = (*c, 1)
    b.inputs["Roughness"].default_value = rough; b.inputs["Metallic"].default_value = metal
    if emit:
        e = emit.lstrip("#"); ec = [lin(int(e[i:i + 2], 16) / 255.0) for i in (0, 2, 4)]
        b.inputs["Emission Color"].default_value = (*ec, 1); b.inputs["Emission Strength"].default_value = emit_strength
    MATS[name] = m; return m

def finish(obj, material, bevel=0.0, segs=2, subd=0, smooth=True):
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    if bevel > 0:
        md = obj.modifiers.new("Bevel", "BEVEL"); md.width = bevel; md.segments = segs; md.limit_method = "ANGLE"
    if subd > 0:
        md = obj.modifiers.new("Subd", "SUBSURF"); md.levels = subd; md.render_levels = subd
    for md in list(obj.modifiers):
        bpy.ops.object.modifier_apply(modifier=md.name)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    if smooth: bpy.ops.object.shade_smooth()
    obj.data.materials.clear(); obj.data.materials.append(material)
    obj.select_set(False)
    return obj

def cyl(r, depth, loc, verts=48, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=depth, location=loc, rotation=rot)
    return bpy.context.active_object

def box(size, loc, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    o = bpy.context.active_object; o.scale = size; return o

def sphere(r, loc, segs=48, rings=24):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segs, ring_count=rings, radius=r, location=loc)
    return bpy.context.active_object

def torus(major, minor, loc, rot=(0, 0, 0), maj_seg=64, min_seg=16):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, location=loc, rotation=rot, major_segments=maj_seg, minor_segments=min_seg)
    return bpy.context.active_object

def export(name):
    for o in bpy.context.scene.objects: o.select_set(o.type == "MESH")
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, name + ".glb"), export_format="GLB", use_selection=True, export_apply=True, export_yup=True)
    tris = 0
    for o in bpy.context.scene.objects:
        if o.type == "MESH":
            o.data.calc_loop_triangles(); tris += len(o.data.loop_triangles)
    dims = [0, 0, 0]
    pts = [o.matrix_world @ Vector(c) for o in bpy.context.scene.objects if o.type == "MESH" for c in o.bound_box]
    for k in range(3): dims[k] = round(max(p[k] for p in pts) - min(p[k] for p in pts), 3)
    return {"tris": tris, "size_m": dims}

def copper_wire():
    copper = mat("Salvage_copper", "#c06a3a", 0.32, 1.0); strap = mat("Salvage_strap_black", "#1d1f1f", 0.7)
    # A coil: stacked wire turns as thin tori, each slightly offset, plus two straps.
    for k in range(9):
        a = k * 0.6
        finish(torus(0.105 + 0.004 * math.sin(a * 2.0), 0.0055, (0.003 * math.cos(a), 0.003 * math.sin(a), 0.006 + k * 0.0105), maj_seg=96, min_seg=12), copper)
    for ang in (0.0, math.pi):
        s = box((0.012, 0.03, 0.115), (0.108 * math.cos(ang), 0.108 * math.sin(ang), 0.05), rot=(0, 0, ang))
        finish(s, strap, bevel=0.003, segs=2)
    tail = cyl(0.0055, 0.09, (0.13, 0.03, 0.09), verts=12, rot=(0, math.radians(70), math.radians(20)))
    finish(tail, copper)

def sensor():
    shell = mat("Salvage_sensor_shell", "#d9d6cc", 0.45); dark = mat("Salvage_sensor_dark", "#2a2f33", 0.5, 0.3)
    lens = mat("Salvage_sensor_lens", "#3a6f8f", 0.08, 0.0, "#59c7ff", 0.4); steel = mat("Salvage_sensor_steel", "#8d949a", 0.35, 1.0)
    finish(cyl(0.045, 0.11, (0, 0, 0.075)), shell, bevel=0.008, segs=3)
    dome = sphere(0.045, (0, 0, 0.13)); finish(dome, shell)
    finish(cyl(0.03, 0.012, (0, 0.04, 0.11), rot=(math.radians(90), 0, 0)), dark, bevel=0.003)
    finish(sphere(0.022, (0, 0.046, 0.11), 32, 16), lens)
    for z in (0.045, 0.1):
        finish(torus(0.047, 0.0035, (0, 0, z), maj_seg=64, min_seg=10), dark)
    br = box((0.03, 0.11, 0.008), (0, -0.02, 0.012)); finish(br, steel, bevel=0.003, segs=2)
    finish(cyl(0.012, 0.03, (0.0, -0.05, 0.03), verts=24, rot=(math.radians(90), 0, 0)), dark, bevel=0.002)

def capacitor():
    can = mat("Salvage_cap_can", "#5d7f9c", 0.3, 0.8); sleeve = mat("Salvage_cap_sleeve", "#1f3550", 0.55)
    term = mat("Salvage_cap_terminal", "#c9a94f", 0.3, 1.0); top = mat("Salvage_cap_top", "#2c2c2c", 0.6)
    finish(cyl(0.06, 0.2, (0, 0, 0.1), verts=64), can, bevel=0.006, segs=3)
    finish(cyl(0.0615, 0.12, (0, 0, 0.09), verts=64), sleeve, bevel=0.002, segs=2)
    finish(cyl(0.055, 0.012, (0, 0, 0.204), verts=64), top, bevel=0.003, segs=2)
    for x in (-0.024, 0.024):
        finish(cyl(0.008, 0.03, (x, 0, 0.222), verts=24), term, bevel=0.0015)
        bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=0.012, depth=0.008, location=(x, 0, 0.214))
        finish(bpy.context.active_object, term, bevel=0.0015, segs=2, smooth=False)
    finish(torus(0.061, 0.003, (0, 0, 0.012), maj_seg=64, min_seg=8), top)

def survey_drive():
    body = mat("Salvage_drive_body", "#3f4a3a", 0.5, 0.2); bump = mat("Salvage_drive_bumper", "#d07b2a", 0.75)
    plate = mat("Salvage_drive_plate", "#b9bdb5", 0.35, 0.9); led = mat("Salvage_drive_led", "#2f8f4a", 0.2, 0.0, "#6dff9a", 0.8)
    finish(box((0.12, 0.08, 0.024), (0, 0, 0.014)), body, bevel=0.006, segs=3, subd=1)
    for sx in (-1, 1):
        for sy in (-1, 1):
            finish(box((0.026, 0.026, 0.03), (sx * 0.052, sy * 0.032, 0.014)), bump, bevel=0.007, segs=3, subd=1)
    finish(box((0.06, 0.04, 0.002), (0.0, 0.0, 0.027)), plate, bevel=0.0008, segs=1)
    finish(box((0.018, 0.006, 0.008), (0.0, -0.042, 0.014)), plate, bevel=0.001)
    finish(sphere(0.003, (0.035, -0.02, 0.0275), 16, 8), led)

def power_cell():
    shell = mat("Salvage_cell_shell", "#2b3136", 0.45, 0.6); frame = mat("Salvage_cell_frame", "#a3a7a8", 0.35, 1.0)
    glow = mat("Salvage_cell_glow", "#2bb3c9", 0.2, 0.0, "#5ff0ff", 0.9); cap = mat("Salvage_cell_cap", "#c4462f", 0.5)
    finish(cyl(0.05, 0.26, (0, 0, 0.15), verts=64), shell, bevel=0.006, segs=3)
    finish(cyl(0.051, 0.12, (0, 0, 0.15), verts=64), glow, bevel=0.002)
    for z in (0.08, 0.22):
        finish(torus(0.054, 0.006, (0, 0, z), maj_seg=64, min_seg=12), frame)
    for z in (0.02, 0.28):
        finish(cyl(0.042, 0.03, (0, 0, z), verts=48), cap, bevel=0.005, segs=3)
    for ang in (0, math.pi):
        finish(box((0.008, 0.012, 0.25), (0.062 * math.cos(ang), 0.062 * math.sin(ang), 0.15)), frame, bevel=0.003, segs=2)
    handle = torus(0.04, 0.006, (0, 0, 0.31), rot=(math.radians(90), 0, 0), maj_seg=48, min_seg=12)
    finish(handle, frame)

def research_core():
    housing = mat("Salvage_core_housing", "#454c55", 0.4, 0.8); fin = mat("Salvage_core_fin", "#7d858d", 0.35, 1.0)
    glass = mat("Salvage_core_glass", "#9fd8ff", 0.05, 0.0); core = mat("Salvage_core_glow", "#b25cff", 0.3, 0.0, "#d18cff", 1.2)
    bolt = mat("Salvage_core_bolt", "#c9a94f", 0.3, 1.0)
    bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=0.08, depth=0.16, location=(0, 0, 0.09))
    finish(bpy.context.active_object, housing, bevel=0.008, segs=3, smooth=False)
    for k in range(6):
        a = k * math.pi / 3 + math.pi / 6
        finish(box((0.006, 0.03, 0.13), (0.078 * math.cos(a), 0.078 * math.sin(a), 0.09), rot=(0, 0, a)), fin, bevel=0.002, segs=2)
    finish(torus(0.042, 0.005, (0, 0, 0.176), maj_seg=48, min_seg=10), glass)
    finish(sphere(0.034, (0, 0, 0.168), 48, 24), core)
    for k in range(6):
        a = k * math.pi / 3
        finish(cyl(0.006, 0.01, (0.06 * math.cos(a), 0.06 * math.sin(a), 0.172), verts=16), bolt, bevel=0.0015)
    finish(cyl(0.07, 0.014, (0, 0, 0.007), verts=6), housing, bevel=0.004, segs=2, smooth=False)

BUILDERS = {"salvage_copper_wire": copper_wire, "salvage_sensor": sensor, "salvage_capacitor": capacitor,
            "salvage_survey_drive": survey_drive, "salvage_power_cell": power_cell, "salvage_research_core": research_core}
report = {}
for name, fn in BUILDERS.items():
    reset(); fn(); report[name] = export(name)
    print("BUILT", name, report[name])
with open(os.path.join(OUT, "BUILD-REPORT.json"), "w") as f:
    json.dump(report, f, indent=1)
