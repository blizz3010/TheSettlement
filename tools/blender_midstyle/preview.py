# Quick workbench preview of a built .blend: blender -b -P preview.py -- <blend> <out_prefix> x,y,z dist angle[,angle..] [lens]
import bpy, sys, math
from mathutils import Vector
args = sys.argv[sys.argv.index("--") + 1:]
blend, out, target = args[0], args[1], [float(v) for v in args[2].split(",")]
dist = float(args[3]); views = args[4].split(","); lens = float(args[5]) if len(args) > 5 else 50
bpy.ops.wm.open_mainfile(filepath=blend)
sc = bpy.context.scene
sc.render.engine = 'BLENDER_WORKBENCH'
sc.display.shading.light = 'STUDIO'; sc.display.shading.color_type = 'TEXTURE'
sc.display.shading.show_cavity = False
sc.render.resolution_x = 800; sc.render.resolution_y = 800
cam_data = bpy.data.cameras.new("C"); cam_data.lens = lens
cam = bpy.data.objects.new("C", cam_data); sc.collection.objects.link(cam); sc.camera = cam
t = Vector(target)
for v in views:
    a = math.radians(float(v))
    cam.location = t + Vector((math.sin(a) * dist, -math.cos(a) * dist, dist * .25))
    d = t - cam.location; cam.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()
    sc.render.filepath = out + "_%s.png" % v
    bpy.ops.render.render(write_still=True)
