# TASKS item 22, PR D: field dressing (raid-only quick-use supply), original design.
# Blender 4.2, meter scale, Z-up (glTF exporter converts to Godot Y-up).
# Mid-to-high poly: bevels + subdivision, all modifiers and transforms applied.
#   blender -b --factory-startup -P tools/blender_midstyle/build_field_dressing.py
import bpy, bmesh, math, os, json
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "raid", "assets", "supplies")
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


def field_dressing():
    olive = mat("Dressing_pouch_olive", "#5d6440", 0.55)
    seal = mat("Dressing_seal_olive_dark", "#434a2c", 0.6)
    label = mat("Dressing_label_cream", "#e6e0c8", 0.8)
    plus = mat("Dressing_plus_green", "#3c8a55", 0.6)
    band = mat("Dressing_band_black", "#1f2120", 0.75)
    tab = mat("Dressing_tab_orange", "#d0702a", 0.5)
    # Vacuum-sealed pouch: soft rounded slab (meter scale, ~14 x 9 x 3 cm).
    p = box((0.14, 0.09, 0.028), (0, 0, 0.014)); finish(p, olive, bevel=0.009, segs=4, subd=2)
    # Heat-seal flanges on both short ends.
    for x in (-0.074, 0.074):
        f = box((0.012, 0.094, 0.004), (x, 0, 0.012)); finish(f, seal, bevel=0.0015, segs=2, subd=1)
        # Crimp ridges on the seal.
        for k in range(9):
            r = box((0.010, 0.0025, 0.0018), (x, -0.04 + k * 0.01, 0.0148)); finish(r, seal, bevel=0.0006, segs=2)
    # Printed label with a green plus.
    l = box((0.07, 0.05, 0.0015), (0.005, 0, 0.0285)); finish(l, label, bevel=0.002, segs=3, subd=1)
    a = box((0.026, 0.008, 0.0012), (-0.012, 0, 0.0298)); finish(a, plus, bevel=0.0008, segs=2)
    b = box((0.008, 0.026, 0.0012), (-0.012, 0, 0.0298)); finish(b, plus, bevel=0.0008, segs=2)
    for k in range(3):
        t = box((0.026, 0.0028, 0.0010), (0.022, 0.012 - k * 0.009, 0.0296)); finish(t, band, bevel=0.0004, segs=1)
    # Elastic band around the middle.
    e = box((0.018, 0.096, 0.034), (0.052, 0, 0.014)); finish(e, band, bevel=0.006, segs=4, subd=1)
    # Orange tear tab at one corner.
    tt = box((0.016, 0.012, 0.003), (-0.082, 0.032, 0.013)); finish(tt, tab, bevel=0.002, segs=3, subd=1)
    return export("field_dressing")

reset()
report = {"field_dressing": field_dressing()}
with open(os.path.join(OUT, "BUILD-REPORT.json"), "w") as fh:
    json.dump({"tool": "tools/blender_midstyle/build_field_dressing.py", "blender": bpy.app.version_string, "units": "meters", "items": report}, fh, indent=2)
print("FIELD_DRESSING_REPORT", json.dumps(report))
