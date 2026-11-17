# Gear PR F: mid-to-high poly PBR composite insert (original design), the raid-only part
# Psy fits to turn a T3 piece into T4. Same pipeline as PR #23 (build_salvage_pbr.py):
# Blender 4.2, meter scale, Z-up (glTF converts to Y-up), transforms applied before bevels,
# cube-projected UVs at a fixed texel density on tileable PBR sets (base colour, ORM
# roughness/metallic, OpenGL normal) from tools/gear_parts_pbr/, UV 0-1 label decal.
# The flat plate is built first, then the whole part is curved with one bend so every
# piece (edge guard, label, grommets, tab) follows the plate.
#   python3 tools/gear_parts_pbr/make_textures.py
#   blender -b --factory-startup -P tools/blender_midstyle/build_composite_insert.py
import bpy, math, os, json
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "raid", "assets", "gear_parts")
TEX = os.path.join(ROOT, "tools", "gear_parts_pbr", "out")
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


# ---------------------------------------------------------------- composite insert
W, H, T = 0.250, 0.320, 0.022      # plate width (X), height (Z), thickness (Y)
CH = 0.055                          # shooter's-cut chamfer on the top corners
BEND_RADIUS = 0.50

def outline(w, h, ch, per_edge=40):
    """Plate outline, counter-clockwise from bottom-left, densely sampled (for the bend)."""
    x0, x1, z0, z1 = -w / 2, w / 2, -h / 2, h / 2
    corners = [(x0, z0), (x1, z0), (x1, z1 - ch), (x1 - ch, z1), (x0 + ch, z1), (x0, z1 - ch)]
    pts = []
    for i in range(len(corners)):
        a = Vector(corners[i]); b = Vector(corners[(i + 1) % len(corners)])
        n = max(2, int(per_edge * (b - a).length / w))
        for k in range(n): pts.append(a.lerp(b, k / n))
    return pts

def plate_body(material):
    # Dense grid cut to the outline, then solidified, so the bend stays smooth.
    bpy.ops.mesh.primitive_grid_add(x_subdivisions=50, y_subdivisions=64, size=1, location=(0, 0, 0), rotation=(math.pi / 2, 0, 0))
    g = bpy.context.active_object; g.scale = (W, H, 1); _apply(g)
    bpy.ops.object.mode_set(mode="EDIT")
    for (px, pz, nx, nz) in ((W / 2 - CH, H / 2, 1, 1), (-W / 2 + CH, H / 2, -1, 1)):
        bpy.ops.mesh.select_all(action="SELECT")
        n = Vector((nx, 0, nz)).normalized()
        bpy.ops.mesh.bisect(plane_co=(px, 0, pz), plane_no=n, clear_outer=True, use_fill=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    md = g.modifiers.new("Solid", "SOLIDIFY"); md.thickness = T; md.offset = 0.0
    finish(g, material, bevel=0.0035, segs=4)
    return g

def edge_guard(material):
    """Rubber edge guard: a round tube that wraps the plate rim."""
    cu = bpy.data.curves.new("EdgeGuard", "CURVE"); cu.dimensions = "3D"
    sp = cu.splines.new("POLY"); pts = outline(W + 0.002, H + 0.002, CH, 120)
    sp.points.add(len(pts) - 1)
    for i, p in enumerate(pts): sp.points[i].co = (p.x, 0.0, p.y, 1.0)
    sp.use_cyclic_u = True
    cu.bevel_mode = "ROUND"; cu.bevel_depth = T * 0.62; cu.bevel_resolution = 4; cu.use_fill_caps = False
    o = bpy.data.objects.new("EdgeGuard", cu); bpy.context.collection.objects.link(o)
    bpy.context.view_layer.objects.active = o; o.select_set(True)
    bpy.ops.object.convert(target="MESH")
    o = bpy.context.active_object
    o.scale = (1.0, 0.78, 1.0)       # a little flatter across the thickness, like moulded trim
    finish(o, material)
    return o

def grommet(loc, copper):
    ring = torus(0.0062, 0.0018, loc, (math.pi / 2, 0, 0), 40, 12); finish(ring, copper)
    back = torus(0.0062, 0.0018, (loc[0], -loc[1], loc[2]), (math.pi / 2, 0, 0), 40, 12); finish(back, copper)
    tube = cyl(0.0046, T + 0.002, (loc[0], 0, loc[2]), 32, (math.pi / 2, 0, 0)); finish(tube, copper, bevel=0.0006, segs=2)

def composite_insert():
    weave = pbr("Insert_composite_weave", "insert_weave"); edge = pbr("Insert_edge_rubber", "insert_edge", normal_strength=0.35)
    copper = pbr("Insert_copper", "copper"); dark = pbr("Insert_dark_steel", "dark_steel")
    web = pbr("Insert_webbing", "insert_webbing"); lab = pbr("Insert_label", "insert_label", normal_strength=0.6)
    body = plate_body(weave)
    edge_guard(edge)
    fy = -T / 2 - 0.0007             # front (strike) face is -Y
    # Label decal, subdivided so it follows the bend.
    bpy.ops.mesh.primitive_grid_add(x_subdivisions=24, y_subdivisions=12, size=1, location=(0, fy, 0.03), rotation=(math.pi / 2, 0, 0))
    d = bpy.context.active_object; d.scale = (0.150, 0.075, 1); _apply(d)
    d.data.materials.clear(); d.data.materials.append(lab)
    # Copper lacing grommets in the four corners (through the plate).
    for gx, gz in ((-W / 2 + 0.020, -H / 2 + 0.020), (W / 2 - 0.020, -H / 2 + 0.020), (-W / 2 + 0.024, H / 2 - CH - 0.004), (W / 2 - 0.024, H / 2 - CH - 0.004)):
        grommet((gx, -T / 2 - 0.0004, gz), copper)
    # Serial plate with two screws near the bottom edge.
    sp = box((0.070, 0.0016, 0.018), (0, fy - 0.0004, -H / 2 + 0.034)); finish(sp, dark, bevel=0.0007, segs=2)
    for sx in (-1, 1):
        screw((sx * 0.029, fy - 0.0016, -H / 2 + 0.034), dark, copper, r=0.0024, axis="y", turn=0.5 * sx)
    for k in range(9):   # stamped serial ticks
        t = box((0.0022, 0.0006, 0.007), (-0.020 + k * 0.005, fy - 0.0014, -H / 2 + 0.034)); finish(t, copper, bevel=0.0002, segs=1)
    # Webbing pull tab at the top edge, stitched with a bar tack.
    tab = torus(0.016, 0.0034, (0, 0, H / 2 + 0.012), (math.pi / 2, 0, 0), 48, 10); tab.scale = (1.0, 1.0, 0.55); finish(tab, web)
    tack = box((0.030, T + 0.004, 0.008), (0, 0, H / 2 - 0.002)); finish(tack, web, bevel=0.0012, segs=2)
    # Back (body side): inspection label and a copper sense-mesh contact pad with two leads.
    back_lab = pbr("Insert_back_label", "insert_back_label", normal_strength=0.6)
    by = T / 2 + 0.0007
    bpy.ops.mesh.primitive_grid_add(x_subdivisions=24, y_subdivisions=12, size=1, location=(0, by, 0.05), rotation=(math.pi / 2, 0, math.pi))
    bl = bpy.context.active_object; bl.scale = (0.140, 0.070, 1); _apply(bl)
    bl.data.materials.clear(); bl.data.materials.append(back_lab)
    pad = box((0.050, 0.0018, 0.030), (0, by + 0.0002, -0.075)); finish(pad, copper, bevel=0.0008, segs=2)
    for sx in (-1, 1):
        lead = cyl(0.0016, 0.060, (sx * 0.016, by + 0.0012, -0.120), 16); finish(lead, dark, bevel=0.0003, segs=1)
    # Join and bend the whole part around Z (curved plate), then centre on the floor.
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes: o.select_set(True)
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.join()
    obj = bpy.context.active_object; obj.name = "CompositeInsert"
    bend = obj.modifiers.new("Bend", "SIMPLE_DEFORM"); bend.deform_method = "BEND"; bend.deform_axis = "Z"
    bend.angle = W / BEND_RADIUS
    _apply(obj)
    # Stand it on its bottom edge, leaning back a little like a plate in a carrier.
    obj.rotation_euler = (math.radians(-8), 0, 0); _apply(obj)
    zmin = min((obj.matrix_world @ v.co).z for v in obj.data.vertices)
    obj.location.z -= zmin
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return export("composite_insert")

os.makedirs(OUT, exist_ok=True)
reset()
report = {"composite_insert": composite_insert()}
report["composite_insert"]["tool"] = "tools/blender_midstyle/build_composite_insert.py (gear PR F)"
print("GEAR_PART", json.dumps(report))
json.dump(report, open(os.path.join(OUT, "BUILD-REPORT.json"), "w"), indent=1)
