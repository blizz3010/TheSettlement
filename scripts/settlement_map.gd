extends Control
const Envelope=preload("res://scripts/settlement_envelope.gd")
# North-up survey of actual scene footprints; never a generated raid/world map.
var scene: Node3D
var detailed := false
var footprints: Array = []
var landmarks: Array = []
const INK = Color("e8ddbd")
const TEAL = Color("66d6bf")
func setup(world: Node3D, full := false):
	scene=world; detailed=full; mouse_filter=Control.MOUSE_FILTER_IGNORE
	refresh_geometry()
func refresh_geometry():
	footprints.clear();landmarks.clear()
	if not is_instance_valid(scene):return
	# The main plaza and its western/northern routes are visual primitive meshes,
	# not separate colliders. Survey those real ground surfaces too.
	for node in scene.get_children():
		if not node is MeshInstance3D or not is_instance_valid(node.mesh):continue
		if node.mesh is BoxMesh and node.mesh.size.y<0.3 and node.mesh.size.x*node.mesh.size.z>=4 and node.mesh.size.x<60 and node.mesh.size.z<60:
			var poly=PackedVector2Array()
			for corner in [Vector3(-1,0,-1),Vector3(1,0,-1),Vector3(1,0,1),Vector3(-1,0,1)]:
				var p=node.global_transform*(corner*node.mesh.size*0.5);poly.append(Vector2(p.x,p.z))
			footprints.append(poly)
		elif node.mesh is CylinderMesh and node.mesh.height<0.3 and node.mesh.top_radius>1:
			var poly=PackedVector2Array()
			for i in range(32):
				var p=node.global_transform*Vector3(cos(i*TAU/32)*node.mesh.top_radius,0,sin(i*TAU/32)*node.mesh.top_radius);poly.append(Vector2(p.x,p.z))
			footprints.append(poly)
	# Ground-level paving and solid structure floor footprints are surveyed directly.
	for node in scene.find_children("*","CollisionShape3D",true,false):
		if not node.shape is BoxShape3D:continue
		var extent:Vector3=node.shape.size
		var terrace=node.get_parent().get_parent().name=="Retaining terrace"
		if (extent.y>0.65 and not terrace) or extent.x*extent.z<4 or extent.x>60 or extent.z>60:continue
		if node.global_position.y < -0.8:continue
		var poly=PackedVector2Array()
		for corner in [Vector3(-1,0,-1),Vector3(1,0,-1),Vector3(1,0,1),Vector3(-1,0,1)]:
			var p=node.global_transform*(corner*extent*0.5);poly.append(Vector2(p.x,p.z))
		footprints.append(poly)
	for node in scene.find_children("*","Node3D",true,false):
		for key in ["paving_polygons","footprints"]:
			if node.has_meta(key):
				for poly in node.get_meta(key):
					if poly is PackedVector2Array:footprints.append(poly)
	var fountain=scene.get_node_or_null("FountainCollision")
	if fountain:landmarks.append({"name":"Fountain","at":fountain.global_position})
	landmarks.append({"name":"Town Hall", "at":scene.HallGeometry.ANCHOR})
	landmarks.append({"name":"Your Home", "at":scene.PLOT})
	landmarks.append({"name":"Test fishing", "at":scene.FISHING_SPOT})
	landmarks.append({"name":"Requests", "at":scene.BOARD})
	landmarks.append({"name":"Rook’s Supplies", "at":scene.SUPPLIES_COUNTER})
	for id in ["Psy","Atlas","Dan"]:
		var stand=scene.get_node_or_null("MarketExpansion/"+id+"Stand")
		if stand:landmarks.append({"name":id,"at":stand.global_position})
	queue_redraw()
func _process(_delta):queue_redraw()
# Production ground spans108m; add2m framing margin on each side.
func project(point:Vector3)->Vector2:
	return size*0.5+Vector2(point.x,point.z)*minf(size.x,size.y)/Envelope.MAP_BOUNDS.size.x
func _draw():
	draw_rect(Rect2(Vector2.ZERO,size),Color("142826"))
	draw_rect(Rect2(Vector2.ONE,size-Vector2.ONE*2),Color("927c52"),false,2)
	for poly in footprints:
		var points=PackedVector2Array()
		for p in poly:points.append(project(Vector3(p.x,0,p.y)))
		if points.size()>2:draw_colored_polygon(points,Color("52615a"))
	var font=ThemeDB.fallback_font
	draw_string(font,Vector2(size.x/2-5,20),"N",HORIZONTAL_ALIGNMENT_LEFT,-1,14,INK)
	for place in landmarks:
		var p=project(place.at);draw_circle(p,3,Color("d4b677"))
		if detailed:draw_string(font,p+Vector2(7,-5),place.name,HORIZONTAL_ALIGNMENT_LEFT,-1,14,INK)
	if not is_instance_valid(scene) or not is_instance_valid(scene.player):return
	var p=project(scene.player.global_position)
	var direction=Vector2(-sin(scene.player.rotation.y),-cos(scene.player.rotation.y))
	draw_circle(p,5,TEAL)
	draw_line(p,p+direction*14,TEAL,3,true)
