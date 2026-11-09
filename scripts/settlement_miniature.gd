extends RefCounted
# Decorative cartographic model of the fixed v067 layout, not saved/player plots.
const Terrain=preload('res://scripts/settlement_terrain.gd')
const Market=preload('res://scripts/market_expansion.gd')
const Hall=preload('res://scripts/town_hall_geometry.gd')
const Ship=preload('res://scripts/launchpad_ship.gd')
const Rook=preload('res://scripts/rook_shop.gd')
const Plot=preload('res://scripts/plot_layout.gd')
const SCALE=.0062
const HEIGHT_SCALE=.0186 # Three-times vertical exaggeration for legible relief.
const ORIGIN_X=-.15
static func point(x:float,z:float,y:float)->Vector3:return Vector3(ORIGIN_X+x*SCALE,.028+maxf(-.05,y)*HEIGHT_SCALE,z*SCALE)
static func ground(x:float,z:float)->Vector3:return point(x,z,Terrain.height_at(x,z))
static func material()->StandardMaterial3D:
 var m=StandardMaterial3D.new();m.vertex_color_use_as_albedo=true;m.roughness=.86;return m
static func start()->SurfaceTool:
 var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);return st
static func triangle(st:SurfaceTool,a:Vector3,b:Vector3,c:Vector3,color:Color,normal:Vector3):
 var cross=(b-a).cross(c-a)
 if cross.length_squared()<1e-15:return
 var vertices=[a,c,b] if cross.dot(normal)>0 else [a,b,c]
 for v in vertices:st.set_normal(normal.normalized());st.set_color(color);st.add_vertex(v)
static func top(st,a,b,c,color):
 var normal=(b-a).cross(c-a).normalized()
 if normal.y<0:normal=-normal
 triangle(st,a,b,c,color,normal)
static func attach(r:Node3D,name:String,st:SurfaceTool):
 var m=MeshInstance3D.new();m.name=name;m.mesh=st.commit();m.material_override=material();r.add_child(m)
static func draped_point(q:Vector2,lattice:Array)->Vector3:
 var gx=(q.x+54)/2.25;var gz=(q.y+54)/2.25
 var ix=clampi(floori(gx),0,47);var iz=clampi(floori(gz),0,47);var u=clampf(gx-ix,0,1);var v=clampf(gz-iz,0,1)
 var a=lattice[iz][ix].y;var b=lattice[iz][ix+1].y;var c=lattice[iz+1][ix].y;var d=lattice[iz+1][ix+1].y
 var y=a+(b-a)*u+(c-a)*v if u+v<=1 else d+(c-d)*(1-u)+(b-d)*(1-v)
 return Vector3(ORIGIN_X+q.x*SCALE,y+.002,q.y*SCALE)
static func drape(st,poly:PackedVector2Array,color:Color,lattice:Array):
 var bounds=Rect2(poly[0],Vector2.ZERO)
 for p in poly:bounds=bounds.expand(p)
 for iz in range(clampi(floori((bounds.position.y+54)/2.25),0,47),clampi(floori((bounds.end.y+54)/2.25),0,47)+1):
  for ix in range(clampi(floori((bounds.position.x+54)/2.25),0,47),clampi(floori((bounds.end.x+54)/2.25),0,47)+1):
   var a=Vector2(-54+ix*2.25,-54+iz*2.25);var b=a+Vector2(2.25,0);var c=a+Vector2(0,2.25);var d=a+Vector2(2.25,2.25)
   for cell in [PackedVector2Array([a,b,c]),PackedVector2Array([b,d,c])]:
    for clipped in Geometry2D.intersect_polygons(poly,cell):
     var indices=Geometry2D.triangulate_polygon(clipped)
     for j in range(0,indices.size(),3):top(st,draped_point(clipped[indices[j]],lattice),draped_point(clipped[indices[j+1]],lattice),draped_point(clipped[indices[j+2]],lattice),color)
static func segment(st,a:Vector2,b:Vector2,width:float,color:Color,lattice:Array):
 var across=(b-a).orthogonal().normalized()*width*.5
 drape(st,PackedVector2Array([a-across,a+across,b+across,b-across]),color,lattice)
static func block(st,center:Vector2,size:Vector2,height:float,color:Color,lattice:Array,roof=true,yaw=0.0):
 var middle=draped_point(center,lattice)-Vector3.UP*.002;var rotation=Basis(Vector3.UP,yaw)
 var bottom=[];var upper=[]
 for offset in [Vector2(-size.x/2,-size.y/2),Vector2(size.x/2,-size.y/2),Vector2(size.x/2,size.y/2),Vector2(-size.x/2,size.y/2)]:
  var q=center+offset.rotated(-yaw);bottom.append(draped_point(q,lattice)-Vector3.UP*.002)
 var top_y=middle.y
 for p in bottom:top_y=maxf(top_y,p.y)
 for p in bottom:upper.append(Vector3(p.x,top_y+height*SCALE,p.z))
 for i in range(4):
  var j=(i+1)%4;var outward=((bottom[i]+bottom[j])*.5-middle);outward.y=0
  triangle(st,bottom[i],bottom[j],upper[j],color,outward);triangle(st,bottom[i],upper[j],upper[i],color,outward)
 if roof:
  var a=(upper[0]+upper[1])*.5+Vector3.UP*size.x*SCALE*.20;var b=(upper[2]+upper[3])*.5+Vector3.UP*size.x*SCALE*.20;var clay=Color('#705b43')
  triangle(st,upper[0],upper[3],b,clay,rotation*Vector3(-1,1,0));triangle(st,upper[0],b,a,clay,rotation*Vector3(-1,1,0));triangle(st,a,b,upper[2],clay,rotation*Vector3(1,1,0));triangle(st,a,upper[2],upper[1],clay,rotation*Vector3(1,1,0))
  triangle(st,upper[0],a,upper[1],clay,rotation*Vector3(0,0,-1));triangle(st,upper[3],upper[2],b,clay,rotation*Vector3(0,0,1))
 else:top(st,upper[0],upper[1],upper[2],color);top(st,upper[0],upper[2],upper[3],color)
static func build(r:Node3D)->bool:
 if r.get_child_count()!=5:return false
 var land=start();var lattice=[];var highest=-INF
 for iz in range(49):
  var row=[]
  for ix in range(49):
   var p=ground(-54+ix*2.25,-54+iz*2.25)
   if not p.is_finite() or p.y>.35:return false
   row.append(p);highest=maxf(highest,p.y)
  lattice.append(row)
 for iz in range(48):
  for ix in range(48):
   var a=lattice[iz][ix];var b=lattice[iz][ix+1];var c=lattice[iz+1][ix];var d=lattice[iz+1][ix+1]
   var tint=Color('#586b48').lerp(Color('#aaa080'),clampf((a.y-.028)/.12,0,1))
   top(land,a,b,c,tint);top(land,b,d,c,tint)
 attach(r,'Survey actual terrain relief',land)
 var water=start()
 # Course is exact; ribbon width is a readable cartographic symbol, not bank survey.
 for i in range(85):
  var x=-42.5+i
  var ribbon=PackedVector2Array([Vector2(x,Terrain.stream_z(x)-.8),Vector2(x+1,Terrain.stream_z(x+1)-.8),Vector2(x+1,Terrain.stream_z(x+1)+.8),Vector2(x,Terrain.stream_z(x)+.8)])
  drape(water,ribbon,Color('#4b9597'),lattice)
 attach(r,'Survey northern river course',water)
 var routes=start();var stone=Color('#c6b990')
 for path in Terrain.PATHS:segment(routes,path[0],path[1],3.4,stone,lattice)
 segment(routes,Vector2(0,-21),Vector2(0,-3),7,stone,lattice);segment(routes,Vector2(-24,-4),Vector2(0,-4),5,stone,lattice)
 var plaza=PackedVector2Array()
 for i in range(64):plaza.append(Vector2(cos(i*TAU/64),sin(i*TAU/64))*10)
 drape(routes,plaza,stone,lattice)
 attach(r,'Survey principal stone routes',routes)
 var buildings=start();var cream=Color('#d6c69e')
 block(buildings,Vector2(Hall.ANCHOR.x,Hall.ANCHOR.z),Vector2(18,18),6.2,cream,lattice)
 for spec in Market.SPECS:block(buildings,Vector2(spec.at.x,spec.at.z),Vector2(spec.width,spec.depth),3.4,cream,lattice,true,spec.yaw)
 block(buildings,Rook.FOOTPRINT.get_center(),Rook.FOOTPRINT.size,3.4,cream,lattice)
 block(buildings,Vector2(-27.25,-4),Vector2(4.5,4.8),2.95,Color("#455478"),lattice)
 block(buildings,Vector2(-7,2),Vector2(4,4),3.0,cream,lattice)
 block(buildings,Vector2(Plot.ORIGIN.x,Plot.ORIGIN.z),Vector2(8,8),3.0,Color('#b69b75'),lattice)
 # Ship is a simplified hull/fin silhouette at the exact authored anchor.
 block(buildings,Vector2(Ship.CENTER.x,Ship.CENTER.z),Vector2(4,9),3,Color('#aabfc0'),lattice,false)
 block(buildings,Vector2(Ship.CENTER.x,Ship.CENTER.z-1),Vector2(8,2),1.5,Color('#76898b'),lattice,false)
 block(buildings,Vector2.ZERO,Vector2(2.8,2.8),2.0,Color('#8fa7a0'),lattice,false)
 attach(r,'Survey landmark silhouettes',buildings)
 var key=start();var bronze=Color('#b59a67')
 # North arrow in the unused side margin, without labeling invented plots.
 var center=Vector3(.42,.032,-.10)
 top(key,center+Vector3(0,0,-.06),center+Vector3(-.025,0,.02),center+Vector3(.025,0,.02),bronze)
 top(key,center+Vector3(-.006,0,.02),center+Vector3(.006,0,.02),center+Vector3(.006,0,.09),bronze)
 top(key,center+Vector3(-.006,0,.02),center+Vector3(.006,0,.09),center+Vector3(-.006,0,.09),bronze)
 attach(r,'Survey north direction',key)
 r.set_meta('settlement_survey_model',{'horizontal_scale':SCALE,'vertical_exaggeration':3,'terrain_samples':2401,'extent':54,'river':'actual course; symbolic width draped over miniature relief, not water elevation','routes':'actual principal centerlines; schematic width','landmarks':'source-bound anchors with simplified silhouettes','live_saved_plots':false})
 return r.get_child_count()==10
