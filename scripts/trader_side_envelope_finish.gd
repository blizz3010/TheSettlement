extends RefCounted
# Isolated SOURCE-ONLY prototype. Call after trader_selective_finish and BEFORE batching.
# No collision, service, roof, original wall, rear-repair or front-opening mutation.
const ROLES = {'Psy': Vector2(8,7), 'Atlas': Vector2(7,8), 'Dan': Vector2(10,7)}
const EPS = 0.00001

static func _fail(reason:String)->Dictionary:
 return {'ok':false, 'reason':reason}

static func _roofs(shop:Node3D, spec:Dictionary)->Array:
 var found:Array=[]
 if spec.id=='Psy':
  var n=shop.get_node_or_null('Rust red outfitter roof')
  if n is MeshInstance3D:found.append(n)
 elif spec.id=='Atlas':
  var holder=shop.get_node_or_null('Utility roof')
  if holder:
   for n in holder.get_children():
    if n is MeshInstance3D:found.append(n)
  var n=shop.get_node_or_null('Teal recovery utility canopy')
  if n is MeshInstance3D:found.append(n)
 else:
  # Exact original two pitched boxes; duplicate generated node names are not selectors.
  var size=Vector3(sqrt(25.0+1.21),.14,6.0)
  for holder in shop.get_children():
   if not holder is Node3D:continue
   if not (holder.position.is_equal_approx(Vector3(-2.5,4.6,-.5)) or holder.position.is_equal_approx(Vector3(2.5,4.6,-.5))):continue
   for n in holder.get_children():
    if n is MeshInstance3D and n.mesh is BoxMesh and n.mesh.size.is_equal_approx(size):found.append(n)
  var n=shop.get_node_or_null('Ochre market cloth awning')
  if n is MeshInstance3D:found.append(n)
 return found

static func _physical_box_count(shop:Node3D, at:Vector3, size:Vector3)->int:
 var count=0
 for holder in shop.get_children():
  if not holder is Node3D or not holder.position.is_equal_approx(at):continue
  for shape in holder.find_children('*','CollisionShape3D',true,false):
   if shape.shape is BoxShape3D and shape.shape.size.is_equal_approx(size):count+=1
 return count

static func _height(line:Vector4,z:float)->float:
 return lerpf(line.y,line.w,(z-line.x)/(line.z-line.x))

static func _slice(shop:Node3D, roofs:Array, x:float)->Array:
 var lines:Array=[]
 for roof in roofs:
  var transform:Transform3D=shop.global_transform.affine_inverse()*roof.global_transform
  var faces:PackedVector3Array=roof.mesh.get_faces()
  for i in range(0,faces.size(),3):
   var v=[transform*faces[i],transform*faces[i+1],transform*faces[i+2]]
   var hits:Array=[]
   for j in range(3):
    var a:Vector3=v[j];var b:Vector3=v[(j+1)%3]
    if absf(a.x-x)<EPS:hits.append(a)
    if (a.x-x)*(b.x-x)<-EPS*EPS:hits.append(a.lerp(b,(x-a.x)/(b.x-a.x)))
   if hits.size()<2:continue
   hits.sort_custom(func(a,b):return a.z<b.z)
   var a:Vector3=hits[0];var b:Vector3=hits[-1]
   if b.z-a.z>EPS:lines.append(Vector4(a.z,a.y,b.z,b.y))
 return lines

static func _profile(shop:Node3D,roofs:Array,x:float,z0:float,z1:float)->Array:
 # Conservative lower envelope over both side faces, including every segment crossing.
 var lines:Array=[]
 for side in [-.09,.09]:lines.append_array(_slice(shop,roofs,x+side))
 if lines.size()>512:return []
 var breaks:Array=[z0,z1]
 for line in lines:
  if line.x>z0 and line.x<z1:breaks.append(line.x)
  if line.z>z0 and line.z<z1:breaks.append(line.z)
 for i in range(lines.size()):
  for j in range(i+1,lines.size()):
   var a:Vector4=lines[i];var b:Vector4=lines[j]
   var lo=maxf(z0,maxf(a.x,b.x));var hi=minf(z1,minf(a.z,b.z))
   if hi-lo<EPS:continue
   var d0=_height(a,lo)-_height(b,lo);var d1=_height(a,hi)-_height(b,hi)
   if d0*d1<0:breaks.append(lerpf(lo,hi,d0/(d0-d1)))
 breaks.sort();var unique:Array=[]
 for z in breaks:
  if unique.is_empty() or z-unique[-1]>EPS:unique.append(z)
 if unique.size()>512:return []
 var result:Array=[]
 for i in range(unique.size()-1):
  var a:float=unique[i];var b:float=unique[i+1];var mid=(a+b)*.5
  var best=null;var low=INF
  for line in lines:
   if mid>=line.x-EPS and mid<=line.z+EPS:
    var h=_height(line,mid)
    if h<low:low=h;best=line
  if best==null:return [] # Unsupported roof coverage fails before adding any nodes.
  var ya=_height(best,a);var yb=_height(best,b)
  if minf(ya,yb)<3.3 or maxf(ya,yb)>4.6:return []
  result.append(Vector4(a,ya,b,yb))
 return result

static func _quad(st:SurfaceTool,a:Vector3,b:Vector3,c:Vector3,d:Vector3):
 for p in [a,c,b,a,d,c]:st.add_vertex(p)

static func _panel(profile:Array,x:float)->ArrayMesh:
 var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for line in profile:
  var x0=x-.09;var x1=x+.09
  var a=Vector3(x0,2.59,line.x);var b=Vector3(x0,line.y-.065,line.x)
  var c=Vector3(x0,line.w-.065,line.z);var d=Vector3(x0,2.59,line.z)
  var offset=Vector3(.18,0,0)
  _quad(st,a,b,c,d);_quad(st,d+offset,c+offset,b+offset,a+offset)
  _quad(st,b,b+offset,c+offset,c);_quad(st,d,d+offset,a+offset,a)
 # End caps; interior segment seams are closed by adjacent surfaces.
 var first:Vector4=profile[0];var last:Vector4=profile[-1]
 _quad(st,Vector3(x-.09,2.59,first.x),Vector3(x+.09,2.59,first.x),Vector3(x+.09,first.y-.065,first.x),Vector3(x-.09,first.y-.065,first.x))
 _quad(st,Vector3(x-.09,2.59,last.z),Vector3(x-.09,last.w-.065,last.z),Vector3(x+.09,last.w-.065,last.z),Vector3(x+.09,2.59,last.z))
 st.generate_normals();return st.commit()

static func apply(shop:Node3D,spec:Dictionary,api,materials:Dictionary)->Dictionary:
 if not ROLES.has(spec.id):return _fail('Unexpected stand identity')
 if Vector2(spec.width,spec.depth)!=ROLES[spec.id]:return _fail('Original stand dimensions changed')
 if shop.has_node('SideEnvelopeCandidate'):return _fail('Duplicate candidate install')
 if not shop.has_meta('wall_finish'):return _fail('Must run after original wall finish, before batching')
 if spec.id=='Psy' and not shop.has_meta('psy_selective_finish'):return _fail('Psy selective finish missing')
 if spec.id=='Dan' and not shop.has_meta('dan_supported_cloth'):return _fail('Corrected Dan canopy missing')
 var roofs=_roofs(shop,spec);var expected={'Psy':1,'Atlas':2,'Dan':3}
 if roofs.size()!=expected[spec.id]:return _fail('Exact roof selectors unresolved; do not run after batching')
 for roof in roofs:
  if roof.mesh==null or roof.mesh.get_faces().size()>1024:return _fail('Roof triangle budget/schema changed')
 var w:float=spec.width;var d:float=spec.depth
 var back=-d/2+.3;var front=d/2-.7;var end=d/2-1.3
 # Bind original walls/posts physically, including Psy's replaced visual boards.
 for side in [-1,1]:
  var x=side*(w/2-.25)
  if _physical_box_count(shop,Vector3(x,1.35,-.5),Vector3(.18,2.5,d-1.6))!=1:return _fail('Original sidewall identity/size mismatch')
  for z in [back,front]:
   if _physical_box_count(shop,Vector3(x,2.0,z),Vector3(.2,3.5,.2))!=1:return _fail('Original corner post identity/size mismatch')
 var plans:Array=[]
 for side in [-1,1]:
  var x=side*(w/2-.25)
  var profile=_profile(shop,roofs,x,back+.09,front-.09)
  if profile.is_empty():return _fail('Unsupported side roof profile: '+str(side))
  plans.append({'x':x,'profile':profile,'mesh':_panel(profile,x)})
 # Build detached, then attach once complete. Every member uses solid=false.
 var root=Node3D.new();root.name='SideEnvelopeCandidate'
 var timber=preload('res://scripts/market_wall_finish.gd').wood()
 for plan in plans:
  var x:float=plan.x
  # 10mm overlaps into existing wall and front post; only the demonstrated side gap.
  api.box(root,'Front corner side closure',Vector3(x,1.35,(end-.01+front-.09)*.5),Vector3(.18,2.5,front-.09-(end-.01)),timber,false)
  var mesh=MeshInstance3D.new();mesh.name='Fitted upper side mineral panel';mesh.mesh=plan.mesh;mesh.material_override=materials.cream;root.add_child(mesh)
  for line in plan.profile:
   preload('res://scripts/market_facades.gd').beam(api,root,'Fitted side head rail',Vector3(x,line.y-.065,line.x),Vector3(x,line.w-.065,line.z),.12,timber)
  api.box(root,'Side sill join',Vector3(x,2.60,(back+front)*.5),Vector3(.20,.12,front-back-.18),timber,false)
  # Two broad upper bays; no glass dependency or tiny arbitrary lattice.
  var center_z=(back+front)*.5;var center_y=INF
  for line in plan.profile:
   if center_z>=line.x-EPS and center_z<=line.z+EPS:center_y=minf(center_y,_height(line,center_z))
  api.box(root,'Upper side center stile',Vector3(x,(2.6+center_y-.07)*.5,center_z),Vector3(.20,center_y-.07-2.6,.12),timber,false)
 if not root.find_children('*','CollisionObject3D',true,false).is_empty():root.free();return _fail('Unexpected candidate collision')
 shop.add_child(root)
 return {'ok':true,'role':spec.id,'root':root,'profile':plans.map(func(p):return p.profile),'side_gap_clear_before':.50,'side_gap_overlap_each_end':.01,'colliders_added':0,'front_opening_unchanged':true,'native_validated':false}
