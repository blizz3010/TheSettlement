extends Node
# Item 16 icon-style preview. Renders an item's real in-game model to a transparent PNG.
# Mid-stylized look: fixed 3/4 orthographic view, warm soft key, cool fill, teal rim light
# and a thin dark outline added in image space. Uses only existing models/builders; no pinned edits.
const ClothingPreview=preload("res://scripts/clothing_preview.gd")
const FishingVisuals=preload("res://scripts/fishing_trader_visuals.gd")
const RENDER:=512
const OUT:=256
const FILL:=0.80          # longest projected side fills 80% of the frame
const PITCH:=28.0         # camera looks down this many degrees
const OUTLINE_PX:=4       # at RENDER size (2 px at OUT size)
const OUTLINE_COLOR:=Color("0b1412")

# Every sample row names the exact model source it renders. "keep" isolates the sold
# material surfaces of a counter display (e.g. the rocks on Rook's ore tray, not the tray).
const ITEMS:={
	"timber":{"trader":"Rook","name":"Timber","src":"glb","path":"res://assets/trader_display/timber_bundle.glb","yaw":-30.0},
	"stone":{"trader":"Rook","name":"Stone","src":"glb","path":"res://assets/trader_display/stone_ore_tray.glb","keep":["Grey_rock"],"tint":{"Grey_rock":[0.27,0.29,0.25,0.95]},"yaw":-35.0},
	"metal":{"trader":"Rook","name":"Metal scrap","src":"glb","path":"res://assets/trader_display/scrap_display_rack.glb","keep":["Forged_scrap_steel"],"yaw":-35.0},
	"helmet_basic":{"trader":"Psy","name":"Basic helmet","src":"glb","path":"res://assets/market_detail/psy_visor_helmet.glb","yaw":-35.0},
	"armor_basic_vest":{"trader":"Psy","name":"Basic armor vest","src":"glb","path":"res://assets/market_detail/psy_field_vest.glb","yaw":-30.0},
	"backpack_basic":{"trader":"Psy","name":"Field pack","src":"glb","path":"res://assets/market_detail/psy_expedition_pack.glb","yaw":-35.0},
	"basic_jacket":{"trader":"Tailor","name":"Basic jacket","src":"garment","slot":"jacket","yaw":-30.0},
	"basic_pants":{"trader":"Tailor","name":"Basic pants","src":"garment","slot":"pants","yaw":-30.0},
	"basic_gloves":{"trader":"Tailor","name":"Basic gloves","src":"garment","slot":"gloves","side":1,"yaw":-40.0},
	"basic_boots":{"trader":"Tailor","name":"Basic boots","src":"garment","slot":"boots","yaw":-35.0},
	"fishing_pole":{"trader":"Fishing","name":"Basic fishing pole","src":"rod","yaw":-20.0},
}
var viewport:SubViewport
var stage:Node3D
var camera:Camera3D
var _garment_source

func _ready():
	viewport=SubViewport.new();viewport.size=Vector2i(RENDER,RENDER);viewport.transparent_bg=true
	viewport.msaa_3d=Viewport.MSAA_4X;viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var root=Node3D.new();root.name="IconStudio";viewport.add_child(root)
	var env=Environment.new();env.background_mode=Environment.BG_CLEAR_COLOR
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("c9d3cf");env.ambient_light_energy=_f("TI_AMB",0.30)
	env.tonemap_mode=Environment.TONE_MAPPER_FILMIC;env.tonemap_exposure=_f("TI_EXP",1.0)
	var we=WorldEnvironment.new();we.environment=env;root.add_child(we)
	_light(root,"Key",Vector3(-42,-38,0),Color("fff0dc"),_f("TI_KEY",0.95),true)
	_light(root,"Fill",Vector3(-12,140,0),Color("b9c9dc"),_f("TI_FILL",0.25),false)
	_light(root,"Rim",Vector3(-25,180,0),Color("bfeee4"),_f("TI_RIM",1.0),false) # from behind, toward camera
	camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.current=true;camera.near=0.05;camera.far=60
	root.add_child(camera)
	stage=Node3D.new();stage.name="Item";root.add_child(stage)

func _f(k:String,d:float)->float:
	var v=OS.get_environment(k)
	return d if v.is_empty() else float(v)

func _light(root:Node3D,n:String,rot:Vector3,c:Color,e:float,shadow:bool):
	var l=DirectionalLight3D.new();l.name=n;l.rotation_degrees=rot;l.light_color=c;l.light_energy=e
	l.shadow_enabled=shadow;l.directional_shadow_max_distance=12.0;l.shadow_blur=2.0;l.shadow_bias=0.03
	root.add_child(l)

func build(id:String)->Node3D:
	var spec:Dictionary=ITEMS[id];var holder=Node3D.new();holder.name=id
	match spec.src:
		"glb":
			var scene=load(spec.path).instantiate();holder.add_child(scene)
			if spec.has("keep"):_isolate(scene,spec.keep,spec.get("tint",{}))
		"garment":
			if _garment_source==null:
				_garment_source=ClothingPreview.new();_garment_source.visible=false;add_child(_garment_source)
			var src:Node3D=_garment_source.garments[spec.slot]
			var copy:Node3D=src.duplicate();copy.visible=true
			if spec.has("side"):
				for c in copy.get_children():
					if signf(c.position.x)!=float(spec.side):c.free()
			holder.add_child(copy)
		"rod":
			FishingVisuals.rod(holder,Vector3(-0.55,-0.62,0),Vector3(0.55,0.62,0),0)
	return holder

func _isolate(scene:Node,keep:Array,tint:Dictionary={}):
	for mi in scene.find_children("*","MeshInstance3D",true,false):
		var src:Mesh=mi.mesh;var out=ArrayMesh.new()
		for s in src.get_surface_count():
			var m=src.surface_get_material(s)
			if m!=null and m.resource_name in keep:
				if tint.has(m.resource_name): # same damping the game applies when it reuses this ore (settlement_stream.gd)
					var t:Array=tint[m.resource_name];m=m.duplicate();m.albedo_color=Color(t[0],t[1],t[2]);m.roughness=t[3]
				out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,src.surface_get_arrays(s));out.surface_set_material(out.get_surface_count()-1,m)
		mi.mesh=out

func render(id:String)->Image:
	for c in stage.get_children():c.free()
	var item=build(id);stage.add_child(item)
	item.rotation_degrees.y=float(ITEMS[id].get("yaw",-35.0))
	var pitch=deg_to_rad(PITCH)
	camera.global_transform=Transform3D(Basis(),Vector3(0,sin(pitch),cos(pitch))*20.0).looking_at(Vector3.ZERO,Vector3.UP)
	var r=_projected_rect(item)
	camera.global_position+=camera.global_basis.x*r.get_center().x+camera.global_basis.y*r.get_center().y
	camera.size=maxf(r.size.x,r.size.y)/FILL
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img:Image=viewport.get_texture().get_image();img.convert(Image.FORMAT_RGBA8)
	img=outline(img)
	img.resize(OUT,OUT,Image.INTERPOLATE_LANCZOS)
	return img

func _projected_rect(item:Node3D)->Rect2:
	var inv=camera.global_transform.affine_inverse();var lo=Vector2(INF,INF);var hi=-lo
	for mi in item.find_children("*","MeshInstance3D",true,false):
		var xf=inv*mi.global_transform
		for s in mi.mesh.get_surface_count():
			for v in mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
				var p=xf*v;lo=lo.min(Vector2(p.x,p.y));hi=hi.max(Vector2(p.x,p.y))
	return Rect2(lo,hi-lo)

# Thin dark outline: separable max-filter dilation of alpha, composited under the render.
func outline(img:Image)->Image:
	var w=img.get_width();var h=img.get_height();var src=img.get_data()
	var a=PackedByteArray();a.resize(w*h)
	for i in w*h:a[i]=src[i*4+3]
	var t=PackedByteArray();t.resize(w*h)
	for y in h:
		for x in w:
			var m=0
			for k in range(maxi(0,x-OUTLINE_PX),mini(w,x+OUTLINE_PX+1)):m=maxi(m,a[y*w+k])
			t[y*w+x]=m
	var d=PackedByteArray();d.resize(w*h)
	for x in w:
		for y in h:
			var m=0
			for k in range(maxi(0,y-OUTLINE_PX),mini(h,y+OUTLINE_PX+1)):m=maxi(m,t[k*w+x])
			d[y*w+x]=m
	var o=PackedByteArray();o.resize(w*h*4)
	var oc=[int(OUTLINE_COLOR.r8),int(OUTLINE_COLOR.g8),int(OUTLINE_COLOR.b8)]
	for i in w*h:
		var sa=src[i*4+3]/255.0;var oa=d[i]/255.0*0.92
		var outa=sa+oa*(1.0-sa)
		o[i*4+3]=int(round(outa*255.0))
		for c in 3:
			o[i*4+c]=0 if outa<=0.0 else int(round((src[i*4+c]*sa+oc[c]*oa*(1.0-sa))/outa))
	return Image.create_from_data(w,h,false,Image.FORMAT_RGBA8,o)
