# Item 16: standalone mid-stylized trader item models for buy-menu icons.
# Blender 4.2, meter scale, Z-up (glTF exporter converts to Godot Y-up).
# Every object has modifiers and transforms applied before export.
#   blender -b --factory-startup -P tools/blender_midstyle/build_trader_items.py
import bpy, bmesh, math, os, sys
from mathutils import Vector, Matrix

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "trader_items")
TEX = os.path.join(ROOT, "assets", "midstyle_test", "textures")
os.makedirs(OUT, exist_ok=True)

MATS = {}

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.unit_settings.system = "METRIC"
    bpy.context.scene.unit_settings.scale_length = 1.0
    MATS.clear()

def mat(name, tex=None, rough=0.75, metal=0.0, hexcol="#ffffff", spec=0.4):
    if name in MATS:
        return MATS[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    m.use_backface_culling = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    h = hexcol.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    # Principled expects linear-ish; leave sRGB-ish for a mid-stylized punch.
    bsdf.inputs["Base Color"].default_value = (*c, 1)
    m.diffuse_color = (*c, 1)
    if tex:
        path = os.path.join(TEX, tex + ".jpg")
        if os.path.exists(path):
            img = nt.nodes.new("ShaderNodeTexImage")
            img.image = bpy.data.images.load(path, check_existing=True)
            img.location = (-400, 200)
            coord = nt.nodes.new("ShaderNodeTexCoord")
            mapn = nt.nodes.new("ShaderNodeMapping")
            mapn.inputs["Scale"].default_value = (2.0, 2.0, 2.0)
            nt.links.new(coord.outputs["UV"], mapn.inputs["Vector"])
            nt.links.new(mapn.outputs["Vector"], img.inputs["Vector"])
            mix = nt.nodes.new("ShaderNodeMix")
            mix.data_type = "RGBA"
            mix.blend_type = "MULTIPLY"
            mix.inputs["Factor"].default_value = 0.85
            mix.inputs[7].default_value = (*c, 1)
            nt.links.new(img.outputs["Color"], mix.inputs[6])
            nt.links.new(mix.outputs[2], bsdf.inputs["Base Color"])
            npath = os.path.join(TEX, tex + "_n.jpg")
            if os.path.exists(npath):
                nimg = nt.nodes.new("ShaderNodeTexImage")
                nimg.image = bpy.data.images.load(npath, check_existing=True)
                nimg.image.colorspace_settings.name = "Non-Color"
                nmap = nt.nodes.new("ShaderNodeNormalMap")
                nmap.inputs["Strength"].default_value = 0.7
                nt.links.new(nimg.outputs["Color"], nmap.inputs["Color"])
                nt.links.new(nmap.outputs["Normal"], bsdf.inputs["Normal"])
                nt.links.new(mapn.outputs["Vector"], nimg.inputs["Vector"])
    MATS[name] = m
    return m

def obj_from_bm(bm, name, material):
    uv = bm.loops.layers.uv.new("UVMap") if not bm.loops.layers.uv else bm.loops.layers.uv[0]
    # naive cube-ish unwrap if empty
    for f in bm.faces:
        for i, loop in enumerate(f.loops):
            if loop[uv].uv.length == 0:
                loop[uv].uv = (i % 2, (i // 2) % 2)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    me.materials.append(material)
    return ob

def select_only(ob):
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob

def apply_all(ob):
    select_only(ob)
    for mod in list(ob.modifiers):
        bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

def smooth(ob, angle=35):
    select_only(ob)
    bpy.ops.object.shade_smooth_by_angle(angle=math.radians(angle))

def bevel(ob, width, segs=2, angle=40):
    mod = ob.modifiers.new("Bevel", "BEVEL")
    mod.width = width
    mod.segments = segs
    mod.limit_method = "ANGLE"
    mod.angle_limit = math.radians(angle)
    return mod

def smart_uv(ob):
    select_only(ob)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.03)
    bpy.ops.object.mode_set(mode="OBJECT")

def box(name, material, center, size, bev=0.004, segs=2, rot=(0, 0, 0)):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
    ob = obj_from_bm(bm, name, material)
    ob.location = center
    ob.rotation_euler = rot
    if bev > 0:
        bevel(ob, bev, segs)
    apply_all(ob)
    smooth(ob)
    smart_uv(ob)
    return ob

def cyl(name, material, center, r, depth, segs=16, bev=0.002, rot=(0, 0, 0), cap=True):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=cap, cap_tris=False, segments=segs, radius1=r, radius2=r, depth=depth)
    ob = obj_from_bm(bm, name, material)
    ob.location = center
    ob.rotation_euler = rot
    if bev > 0:
        bevel(ob, bev, 1)
    apply_all(ob)
    smooth(ob, 50)
    smart_uv(ob)
    return ob

def sphere(name, material, center, r, segs=12, rings=8, scale=(1, 1, 1)):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=rings, radius=r)
    bmesh.ops.scale(bm, vec=Vector(scale), verts=bm.verts)
    ob = obj_from_bm(bm, name, material)
    ob.location = center
    apply_all(ob)
    smooth(ob, 80)
    smart_uv(ob)
    return ob

def torus(name, material, center, major, minor, segs=16, nseg=8, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(
        align="WORLD", location=center, rotation=rot,
        major_radius=major, minor_radius=minor,
        major_segments=max(8, segs), minor_segments=max(6, nseg),
    )
    ob = bpy.context.object
    ob.name = name
    if ob.data.materials:
        ob.data.materials[0] = material
    else:
        ob.data.materials.append(material)
    apply_all(ob)
    smooth(ob, 60)
    smart_uv(ob)
    return ob

def join(name, objects):
    if not objects:
        return None
    if len(objects) == 1:
        objects[0].name = name
        return objects[0]
    bpy.ops.object.select_all(action="DESELECT")
    for ob in objects:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    objects[0].name = name
    apply_all(objects[0])
    return objects[0]

def center_origin(ob):
    # Recenter geometry on the bounding-box center, leave object at origin.
    select_only(ob)
    bpy.ops.object.origin_set(type="ORIGIN_GEOMETRY", center="BOUNDS")
    ob.location = (0, 0, 0)
    apply_all(ob)

def export_glb(ob, path):
    center_origin(ob)
    select_only(ob)
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
        export_normals=True,
        export_materials="EXPORT",
        export_image_format="JPEG",
        export_jpeg_quality=88,
        export_texcoords=True,
    )
    print("exported", path, "verts", len(ob.data.vertices), "tris", len(ob.data.loop_triangles) or len(ob.data.polygons))

# ------------------------------------------------------------------ items

def item_pickaxe():
    oak = mat("PickHaft", "oak", rough=0.7, hexcol="#6b4f32")
    iron = mat("PickHead", "iron", rough=0.35, metal=0.85, hexcol="#6a6e72")
    leather = mat("PickWrap", "leather_rust", rough=0.8, hexcol="#6a3b28")
    haft = cyl("Haft", oak, (0, 0, 0.02), 0.016, 0.72, segs=12, bev=0.002, rot=(math.radians(90), 0, 0))
    wrap = cyl("Wrap", leather, (0, 0.08, 0.02), 0.019, 0.08, segs=10, bev=0.001, rot=(math.radians(90), 0, 0))
    # Head: a chunky T with pointed ends
    eye = box("Eye", iron, (0, -0.30, 0.02), (0.04, 0.05, 0.04), bev=0.003)
    spike = box("Spike", iron, (0.11, -0.30, 0.02), (0.18, 0.035, 0.028), bev=0.004)
    adze = box("Adze", iron, (-0.10, -0.30, 0.02), (0.16, 0.04, 0.018), bev=0.003)
    return join("pickaxe", [haft, wrap, eye, spike, adze])

def item_scythe():
    oak = mat("ScytheHaft", "walnut", rough=0.7, hexcol="#4a3424")
    iron = mat("ScytheBlade", "iron", rough=0.3, metal=0.8, hexcol="#8a9096")
    leather = mat("ScytheGrip", "leather_rust", rough=0.8, hexcol="#5a3020")
    # Slightly shortened for icon framing, still reads as a long-handled tool.
    haft = cyl("Haft", oak, (0, 0.05, 0), 0.014, 0.95, segs=12, bev=0.002, rot=(math.radians(78), 0, math.radians(8)))
    grip = cyl("Grip", leather, (0.01, 0.28, -0.02), 0.017, 0.09, segs=10, bev=0.001, rot=(math.radians(78), 0, math.radians(8)))
    snath = cyl("Snath", oak, (-0.02, -0.38, 0.04), 0.012, 0.18, segs=10, bev=0.002, rot=(math.radians(20), math.radians(70), 0))
    # Curved blade approximated with a few beveled boxes
    parts = [haft, grip, snath]
    for i, (x, y, z, sx, sy, rz) in enumerate([
        (0.02, -0.46, 0.05, 0.22, 0.022, 20),
        (0.18, -0.50, 0.04, 0.16, 0.018, 45),
        (0.28, -0.42, 0.03, 0.12, 0.016, 80),
    ]):
        parts.append(box(f"Blade{i}", iron, (x, y, z), (sx, sy, 0.008), bev=0.002, rot=(0, 0, math.radians(rz))))
    return join("scythe", parts)

def item_crafting_guide():
    cloth = mat("GuideCloth", "bookcloth_teal", rough=0.7, hexcol="#2e6a62")
    page = mat("GuidePages", "page_edge", rough=0.85, hexcol="#d9cda8")
    ribbon = mat("GuideRibbon", "ribbon_red", rough=0.6, hexcol="#9a2a2a")
    brass = mat("GuideBrass", "brass", rough=0.35, metal=0.7, hexcol="#c4a056")
    body = box("Cover", cloth, (0, 0, 0), (0.16, 0.22, 0.028), bev=0.003)
    pages = box("Pages", page, (0.006, 0, 0), (0.14, 0.20, 0.022), bev=0.001)
    band = box("Ribbon", ribbon, (0.04, -0.02, 0.016), (0.012, 0.20, 0.003), bev=0.0005)
    corner1 = box("CornerA", brass, (-0.07, 0.095, 0.015), (0.024, 0.024, 0.004), bev=0.001)
    corner2 = box("CornerB", brass, (-0.07, -0.095, 0.015), (0.024, 0.024, 0.004), bev=0.001)
    clasp = box("Clasp", brass, (0.078, 0, 0.004), (0.012, 0.03, 0.018), bev=0.002)
    return join("crafting_guide", [body, pages, band, corner1, corner2, clasp])

def item_plans():
    paper = mat("PlanPaper", "plan_paper", rough=0.85, hexcol="#c5d0b4")
    end = mat("PlanEnd", "plan_end", rough=0.8, hexcol="#8a7a55")
    twine = mat("PlanTwine", "twine", rough=0.8, hexcol="#c4b07a")
    roll = cyl("Roll", paper, (0, 0, 0), 0.028, 0.28, segs=18, bev=0.002, rot=(0, math.radians(90), 0))
    cap_l = cyl("CapL", end, (-0.145, 0, 0), 0.030, 0.012, segs=16, bev=0.001, rot=(0, math.radians(90), 0))
    cap_r = cyl("CapR", end, (0.145, 0, 0), 0.030, 0.012, segs=16, bev=0.001, rot=(0, math.radians(90), 0))
    string = torus("Tie", twine, (0, 0, 0.01), 0.032, 0.004, segs=14, nseg=8, rot=(math.radians(90), 0, 0))
    tag = box("Tag", end, (0.02, 0.04, 0.01), (0.03, 0.04, 0.002), bev=0.0005)
    return join("building_plans", [roll, cap_l, cap_r, string, tag])

def item_rig():
    leather = mat("RigLeather", "leather_rust", rough=0.7, hexcol="#5c3a28")
    iron = mat("RigIron", "iron", rough=0.4, metal=0.7, hexcol="#5a5e62")
    cloth = mat("RigCloth", "burlap", rough=0.85, hexcol="#6a5a40")
    # Chest harness + pouches, torso-sized, no body.
    strap_l = box("StrapL", leather, (-0.09, 0.0, 0.08), (0.035, 0.06, 0.32), bev=0.004, rot=(0, math.radians(12), 0))
    strap_r = box("StrapR", leather, (0.09, 0.0, 0.08), (0.035, 0.06, 0.32), bev=0.004, rot=(0, math.radians(-12), 0))
    belt = box("Belt", leather, (0, 0.01, -0.08), (0.28, 0.06, 0.04), bev=0.004)
    buckle = box("Buckle", iron, (0, 0.04, -0.08), (0.04, 0.02, 0.05), bev=0.002)
    pouch1 = box("Pouch1", cloth, (-0.08, 0.04, -0.12), (0.08, 0.06, 0.10), bev=0.005)
    pouch2 = box("Pouch2", cloth, (0.08, 0.04, -0.12), (0.08, 0.06, 0.10), bev=0.005)
    pouch3 = box("Pouch3", leather, (0, 0.05, -0.14), (0.07, 0.05, 0.08), bev=0.004)
    flap1 = box("Flap1", leather, (-0.08, 0.07, -0.08), (0.08, 0.01, 0.06), bev=0.002)
    flap2 = box("Flap2", leather, (0.08, 0.07, -0.08), (0.08, 0.01, 0.06), bev=0.002)
    return join("rig_basic", [strap_l, strap_r, belt, buckle, pouch1, pouch2, pouch3, flap1, flap2])

def item_cloth():
    linen = mat("LinenCloth", "linen", rough=0.85, hexcol="#d8c9a8")
    twine = mat("ClothTwine", "twine", rough=0.8, hexcol="#b8a06a")
    # Folded bolt of linen
    fold1 = box("Fold1", linen, (0, 0, 0.00), (0.22, 0.16, 0.018), bev=0.004)
    fold2 = box("Fold2", linen, (0.01, 0.01, 0.016), (0.20, 0.15, 0.016), bev=0.004)
    fold3 = box("Fold3", linen, (-0.005, -0.008, 0.030), (0.21, 0.145, 0.014), bev=0.004)
    tie = cyl("Tie", twine, (0, 0, 0.022), 0.006, 0.18, segs=8, bev=0.001, rot=(0, math.radians(90), 0))
    return join("cloth_linen", [fold1, fold2, fold3, tie])

def item_spool():
    wood = mat("SpoolWood", "end_grain", rough=0.7, hexcol="#8a6238")
    thread = mat("SpoolThread", "thread_white", rough=0.6, hexcol="#e8e0d0")
    flange_b = cyl("FlangeB", wood, (0, 0, -0.028), 0.045, 0.008, segs=16, bev=0.001)
    core = cyl("Core", wood, (0, 0, 0), 0.016, 0.05, segs=12, bev=0.001)
    flange_t = cyl("FlangeT", wood, (0, 0, 0.028), 0.045, 0.008, segs=16, bev=0.001)
    wind = cyl("Thread", thread, (0, 0, 0), 0.038, 0.044, segs=16, bev=0.002)
    return join("thread_spool", [flange_b, core, flange_t, wind])

def item_pattern():
    paper = mat("PatternPaper", "pattern_paper", rough=0.88, hexcol="#e4d7b8")
    ink = mat("PatternInk", "ink_black", rough=0.7, hexcol="#2a2a28")
    tape = mat("PatternTape", "tape", rough=0.8, hexcol="#d2c48a")
    sheet = box("Sheet", paper, (0, 0, 0), (0.22, 0.28, 0.004), bev=0.001)
    # Simple pattern marks as thin raised strips
    marks = [sheet]
    for i, (x, y, sx, sy) in enumerate([
        (-0.04, 0.04, 0.10, 0.004), (0.04, -0.02, 0.004, 0.14),
        (-0.02, -0.08, 0.12, 0.004), (0.06, 0.08, 0.06, 0.004),
    ]):
        marks.append(box(f"Mark{i}", ink, (x, y, 0.003), (sx, sy, 0.002), bev=0.0003))
    marks.append(box("CornerTape", tape, (-0.09, 0.12, 0.003), (0.03, 0.03, 0.002), bev=0.0004))
    return join("pattern_sheet", marks)

def item_shirt():
    cloth = mat("ShirtCloth", "wool_cream", rough=0.8, hexcol="#d8cbb0")
    btn = mat("ShirtButton", "brass", rough=0.4, metal=0.6, hexcol="#c4a056")
    # Folded shirt: body + collar + sleeves tucked
    body = box("Body", cloth, (0, 0, 0), (0.20, 0.16, 0.03), bev=0.006)
    collar = box("Collar", cloth, (0, 0.07, 0.02), (0.10, 0.04, 0.016), bev=0.003)
    sleeve_l = box("SleeveL", cloth, (-0.12, 0.0, 0.008), (0.06, 0.08, 0.024), bev=0.004, rot=(0, 0, math.radians(8)))
    sleeve_r = box("SleeveR", cloth, (0.12, 0.0, 0.008), (0.06, 0.08, 0.024), bev=0.004, rot=(0, 0, math.radians(-8)))
    b1 = cyl("Btn1", btn, (0, 0.02, 0.017), 0.007, 0.004, segs=8, bev=0.0005)
    b2 = cyl("Btn2", btn, (0, -0.02, 0.017), 0.007, 0.004, segs=8, bev=0.0005)
    return join("shirt_basic", [body, collar, sleeve_l, sleeve_r, b1, b2])

def item_pigments():
    # Three cloth packets in distinct colours
    papers = [
        mat("PigmentIndigo", "wool_indigo", rough=0.8, hexcol="#3a4a78"),
        mat("PigmentTerracotta", "terracotta", rough=0.8, hexcol="#a35a3a"),
        mat("PigmentMoss", "leaf_green", rough=0.8, hexcol="#5a6e3a"),
    ]
    twine = mat("PigmentTwine", "twine", rough=0.8, hexcol="#c4b07a")
    parts = []
    for i, (x, y, m) in enumerate([(-0.05, 0.02, papers[0]), (0.05, 0.00, papers[1]), (0.00, -0.05, papers[2])]):
        parts.append(box(f"Pack{i}", m, (x, y, 0.0), (0.07, 0.09, 0.028), bev=0.004, rot=(0, 0, math.radians(-12 + i * 14))))
        parts.append(cyl(f"Tie{i}", twine, (x, y, 0.016), 0.004, 0.08, segs=8, bev=0.0005, rot=(0, math.radians(90), math.radians(i * 14))))
    return join("pigment_packets", parts)

def item_bait():
    tin = mat("BaitTin", "teal_paint", rough=0.45, metal=0.2, hexcol="#3d6a62")
    lid = mat("BaitLid", "brass", rough=0.4, metal=0.55, hexcol="#b89a4a")
    cork_m = mat("BaitCork", "cork", rough=0.85, hexcol="#c4a06a")
    # Round bait tin with a slightly open lid
    body = cyl("Tin", tin, (0, 0, 0), 0.045, 0.04, segs=16, bev=0.002)
    rim = cyl("Rim", tin, (0, 0, 0.018), 0.047, 0.006, segs=16, bev=0.001)
    cover = cyl("Lid", lid, (0.03, 0.0, 0.036), 0.046, 0.006, segs=16, bev=0.001, rot=(0, math.radians(18), math.radians(20)))
    knob = sphere("Knob", lid, (0.03, 0.0, 0.044), 0.008, segs=8, rings=6)
    # A couple of bait bits peeking out
    bit1 = sphere("Bit1", cork_m, (-0.01, 0.01, 0.026), 0.01, segs=8, rings=6, scale=(1.0, 0.7, 0.6))
    bit2 = sphere("Bit2", cork_m, (0.01, -0.01, 0.024), 0.008, segs=8, rings=6, scale=(0.8, 1.1, 0.5))
    return join("bait_portion", [body, rim, cover, knob, bit1, bit2])

def item_pole():
    oak = mat("PoleWood", "oak", rough=0.7, hexcol="#6b4f32")
    cork_m = mat("PoleCork", "cork", rough=0.85, hexcol="#c4a06a")
    iron = mat("PoleIron", "iron", rough=0.35, metal=0.8, hexcol="#5a5e62")
    line = mat("PoleLine", "twine", rough=0.7, hexcol="#d8c9a0")
    # Three-part rod with reel — thicker than the procedural one so it reads at 34 px.
    butt = cyl("Butt", cork_m, (0, 0.28, 0), 0.016, 0.16, segs=12, bev=0.002, rot=(math.radians(90), 0, math.radians(8)))
    mid = cyl("Mid", oak, (0.01, 0.02, 0), 0.011, 0.42, segs=12, bev=0.002, rot=(math.radians(90), 0, math.radians(8)))
    tip = cyl("Tip", oak, (0.025, -0.32, 0), 0.006, 0.28, segs=10, bev=0.001, rot=(math.radians(90), 0, math.radians(8)))
    reel = cyl("Reel", iron, (0.03, 0.18, 0.02), 0.028, 0.016, segs=14, bev=0.002, rot=(0, math.radians(90), 0))
    spool = cyl("Spool", line, (0.03, 0.18, 0.02), 0.022, 0.012, segs=12, bev=0.001, rot=(0, math.radians(90), 0))
    foot = box("Foot", iron, (0.01, 0.18, 0.0), (0.012, 0.04, 0.016), bev=0.001)
    guide1 = torus("Guide1", iron, (0.018, -0.12, 0), 0.010, 0.002, segs=8, nseg=6, rot=(0, math.radians(90), 0))
    guide2 = torus("Guide2", iron, (0.028, -0.38, 0), 0.007, 0.0015, segs=8, nseg=6, rot=(0, math.radians(90), 0))
    return join("fishing_pole", [butt, mid, tip, reel, spool, foot, guide1, guide2])

def item_jacket():
    wool = mat("JacketWool", "wool_indigo", rough=0.8, hexcol="#3a4658")
    lining = mat("JacketLining", "drape_ochre", rough=0.8, hexcol="#8a6a40")
    btn = mat("JacketBtn", "brass", rough=0.4, metal=0.6, hexcol="#c4a056")
    body = box("Body", wool, (0, 0, 0.02), (0.28, 0.12, 0.36), bev=0.008)
    lapel_l = box("LapelL", lining, (-0.06, 0.065, 0.08), (0.07, 0.02, 0.18), bev=0.003, rot=(0, math.radians(12), math.radians(-8)))
    lapel_r = box("LapelR", lining, (0.06, 0.065, 0.08), (0.07, 0.02, 0.18), bev=0.003, rot=(0, math.radians(-12), math.radians(8)))
    collar = box("Collar", wool, (0, 0.05, 0.20), (0.16, 0.06, 0.05), bev=0.004)
    sleeve_l = cyl("SleeveL", wool, (-0.18, 0.0, 0.02), 0.04, 0.26, segs=12, bev=0.004, rot=(math.radians(90), 0, math.radians(16)))
    sleeve_r = cyl("SleeveR", wool, (0.18, 0.0, 0.02), 0.04, 0.26, segs=12, bev=0.004, rot=(math.radians(90), 0, math.radians(-16)))
    b1 = cyl("B1", btn, (0.02, 0.062, 0.04), 0.01, 0.006, segs=8, bev=0.0005, rot=(math.radians(90), 0, 0))
    b2 = cyl("B2", btn, (0.02, 0.062, -0.04), 0.01, 0.006, segs=8, bev=0.0005, rot=(math.radians(90), 0, 0))
    return join("basic_jacket", [body, lapel_l, lapel_r, collar, sleeve_l, sleeve_r, b1, b2])

def item_pants():
    wool = mat("PantsWool", "wool_cream", rough=0.8, hexcol="#4a4a40")
    leather = mat("PantsBelt", "leather_rust", rough=0.75, hexcol="#5c3a28")
    waist = box("Waist", wool, (0, 0, 0.16), (0.22, 0.10, 0.08), bev=0.006)
    belt = box("Belt", leather, (0, 0.0, 0.20), (0.23, 0.11, 0.025), bev=0.003)
    leg_l = cyl("LegL", wool, (-0.06, 0, 0.0), 0.05, 0.32, segs=12, bev=0.005)
    leg_r = cyl("LegR", wool, (0.06, 0, 0.0), 0.05, 0.32, segs=12, bev=0.005)
    return join("basic_pants", [waist, belt, leg_l, leg_r])

def item_gloves():
    leather = mat("GloveLeather", "leather_rust", rough=0.7, hexcol="#6a3b28")
    stitch = mat("GloveStitch", "thread_gold", rough=0.6, hexcol="#c4a056")
    # One glove, slightly turned, fingers readable
    palm = box("Palm", leather, (0, 0, 0), (0.07, 0.03, 0.10), bev=0.004)
    fingers = []
    for i, x in enumerate([-0.026, -0.009, 0.008, 0.025]):
        length = 0.07 if i != 1 else 0.08
        fingers.append(cyl(f"F{i}", leather, (x, 0, 0.07 + length / 2 - 0.02), 0.009, length, segs=8, bev=0.002))
    thumb = cyl("Thumb", leather, (-0.045, 0.01, 0.02), 0.01, 0.055, segs=8, bev=0.002, rot=(0, math.radians(40), math.radians(-20)))
    cuff = cyl("Cuff", leather, (0, 0, -0.06), 0.032, 0.04, segs=10, bev=0.002)
    seam = box("Seam", stitch, (0, 0.016, 0.0), (0.004, 0.002, 0.08), bev=0.0004)
    return join("basic_gloves", [palm, *fingers, thumb, cuff, seam])

def item_boots():
    leather = mat("BootLeather", "leather_rust", rough=0.7, hexcol="#4a2e20")
    sole = mat("BootSole", "burlap", rough=0.9, hexcol="#2a2420")
    iron = mat("BootIron", "iron", rough=0.4, metal=0.6, hexcol="#5a5e62")
    # One boot, three-quarter friendly
    shaft = cyl("Shaft", leather, (0, 0, 0.08), 0.045, 0.14, segs=12, bev=0.004)
    vamp = box("Vamp", leather, (0.04, 0, 0.02), (0.10, 0.08, 0.05), bev=0.006)
    toe = sphere("Toe", leather, (0.08, 0, 0.02), 0.04, segs=10, rings=6, scale=(1.1, 1.0, 0.7))
    s = box("Sole", sole, (0.03, 0, -0.01), (0.16, 0.08, 0.02), bev=0.003)
    heel = box("Heel", sole, (-0.04, 0, -0.02), (0.06, 0.075, 0.03), bev=0.003)
    eye = cyl("Eye", iron, (0.01, 0.04, 0.08), 0.006, 0.006, segs=8, bev=0.0005, rot=(math.radians(90), 0, 0))
    return join("basic_boots", [shaft, vamp, toe, s, heel, eye])


ITEMS = {
    "pickaxe_preview": item_pickaxe,
    "scythe_preview": item_scythe,
    "crafting_guide": item_crafting_guide,
    "building_plans_preview": item_plans,
    "rig_basic": item_rig,
    "cloth_linen": item_cloth,
    "thread_spool": item_spool,
    "pattern_sheet": item_pattern,
    "shirt_basic": item_shirt,
    "dye_palette_future": item_pigments,
    "bait_portion": item_bait,
    "fishing_pole": item_pole,
    "basic_jacket": item_jacket,
    "basic_pants": item_pants,
    "basic_gloves": item_gloves,
    "basic_boots": item_boots,
}


def main():
    only = [a for a in sys.argv if a in ITEMS]
    names = only or list(ITEMS)
    os.makedirs(OUT, exist_ok=True)
    failed = []
    for name in names:
        reset()
        print("building", name, flush=True)
        try:
            ob = ITEMS[name]()
            export_glb(ob, os.path.join(OUT, name + ".glb"))
        except Exception as exc:
            failed.append(name)
            print("FAILED", name, type(exc).__name__, exc, flush=True)
    print("DONE", len(names) - len(failed), "ok,", len(failed), "failed", failed, "->", OUT)
    if failed:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
