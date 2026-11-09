extends RefCounted
# Source-owned replacement of the two flat nozzle closures only. The imported
# resource and all non-cap arrays remain untouched; unexpected assets fail closed.
const SOURCE="res://.godot/imported/launchpad_ship.glb-8f17bda94b0c6d26b2702b1c8e595124.scn"
const SOURCE_SHA="8d7e6b1fb7366ac214dd6e8285182f196279655397d61bed39b1497c6c66d7d0"
const CENTERS=[Vector3(0,3.08,-2.15),Vector3(0,3.08,2.15)]
static func category(surface:int,vertices:PackedVector3Array,triangle:PackedInt32Array)->Dictionary:
 for engine in 2:
  var center:Vector3=CENTERS[engine]
  var disc=true;var outer=true;var bronze_front=true;var bronze_back=true
  for index in triangle:
   var p:Vector3=vertices[index];var radius=Vector2(p.y-center.y,p.z-center.z).length()
   disc=disc and surface==1 and p.x>=4.7648 and p.x<=4.7952 and radius<=.2902
   outer=outer and surface==1 and absf(p.x-4.735)<.0002 and radius<=.6002
   bronze_front=bronze_front and surface==3 and absf(p.x-4.765)<.0002 and radius<=.3905
   bronze_back=bronze_back and surface==3 and absf(p.x-4.735)<.0002 and radius<=.3905
  if disc:return {"engine":engine,"kind":"center_disc"}
  if outer:return {"engine":engine,"kind":"outer_front"}
  if bronze_front:return {"engine":engine,"kind":"bronze_front"}
  if bronze_back:return {"engine":engine,"kind":"bronze_back"}
 return {}
static func prepare(source:Mesh)->Dictionary:
 var version=Engine.get_version_info()
 if version.major!=4 or version.minor!=6 or not source is ArrayMesh:return {"ok":false,"reason":"Nozzle storage adapter requires the shipped Godot4.6 ArrayMesh contract."}
 if FileAccess.get_sha256(SOURCE)!=SOURCE_SHA:return {"ok":false,"reason":"Ship source signature changed."}
 if source.get_surface_count()!=10 or source.get_blend_shape_count()!=0:return {"ok":false,"reason":"Ship surface contract changed."}
 if not source.surface_get_material(1) is StandardMaterial3D or not source.surface_get_material(3) is StandardMaterial3D:return {"ok":false,"reason":"Ship structural materials are unsupported."}
 if source.surface_get_material(1).resource_name!="Graphite structural metal" or source.surface_get_material(3).resource_name!="Warm oxidized bronze":return {"ok":false,"reason":"Ship material contract changed."}
 var arrays=[];var removed={};var caps={};var counts={};var originals=[]
 for surface in source.get_surface_count():
  var original=source.surface_get_arrays(surface);originals.append(original)
  var next=original.duplicate(true)
  if surface in [1,3]:
   var vertices:PackedVector3Array=original[Mesh.ARRAY_VERTEX];var indices:PackedInt32Array=original[Mesh.ARRAY_INDEX];var retained=PackedInt32Array();removed[str(surface)]=[]
   for offset in range(0,indices.size(),3):
    var tri=indices.slice(offset,offset+3);var match_=category(surface,vertices,tri)
    if match_.is_empty():retained.append_array(tri);continue
    var key=str(match_.engine)+"/"+match_.kind
    counts[key]=int(counts.get(key,0))+1
    removed[str(surface)].append({"offset":offset,"indices":Array(tri),"engine":match_.engine,"kind":match_.kind})
    if match_.kind!="center_disc":
     if not caps.has(key):caps[key]=[]
     for index in tri:
      var point=vertices[index];var found=false
      for prior in caps[key]:
       if point.distance_to(prior)<.0001:found=true;break
      if not found:caps[key].append(point)
   next[Mesh.ARRAY_INDEX]=retained
  arrays.append(next)
 for engine in 2:
  for kind in ["center_disc","outer_front","bronze_front","bronze_back"]:
   var key=str(engine)+"/"+kind;var expected={"center_disc":60,"outer_front":18,"bronze_front":14,"bronze_back":14}[kind]
   if counts.get(key,0)!=expected:return {"ok":false,"reason":"Exact nozzle triangle count mismatch: "+key,"counts":counts}
   if kind!="center_disc" and caps[key].size()!=(20 if kind=="outer_front" else 16):return {"ok":false,"reason":"Exact nozzle ring boundary changed: "+key}
 # Rebuilding through add_surface_from_arrays requantizes imported packed normals
 # and drops authored LOD data. Copy Godot's observed serialized surface storage
 # instead, replacing only index bytes (including the same cap subset in LODs).
 var storage=source.get("_surfaces")
 if not storage is Array or storage.size()!=10:return {"ok":false,"reason":"Unsupported ship surface storage."}
 var raw=storage.duplicate(true);var lod_removed={}
 for surface in [1,3]:
  var row:Dictionary=raw[surface]
  for required in ["index_data","index_count","vertex_data","attribute_data","lods","vertex_count"]:
   if not row.has(required):return {"ok":false,"reason":"Incomplete ship surface storage."}
  var stride:int=row.index_data.size()/int(row.index_count)
  if stride not in [2,4]:return {"ok":false,"reason":"Unsupported ship index width."}
  row.index_data=pack_indices(arrays[surface][Mesh.ARRAY_INDEX],stride)
  row.index_count=arrays[surface][Mesh.ARRAY_INDEX].size()
  var lods:Array=row.lods
  if lods.size()%2!=0:return {"ok":false,"reason":"Unsupported ship LOD storage."}
  for index in range(1,lods.size(),2):
   var bytes:PackedByteArray=lods[index]
   var indices=unpack_indices(bytes,stride);var retained=PackedInt32Array();var removed_lod=[]
   if indices.size()%3!=0:return {"ok":false,"reason":"Invalid ship LOD triangle list."}
   for offset in range(0,indices.size(),3):
    var tri=indices.slice(offset,offset+3)
    var match_=category(surface,originals[surface][Mesh.ARRAY_VERTEX],tri)
    if match_.is_empty():retained.append_array(tri)
    else:removed_lod.append({"offset":offset,"indices":Array(tri),"engine":match_.engine,"kind":match_.kind})
   lods[index]=pack_indices(retained,stride)
   lod_removed[str(surface)+"/"+str(index/2)]={"distance":lods[index-1],"removed":removed_lod}
  row.lods=lods
 var copy=ArrayMesh.new();copy.resource_name="Source-owned recessed nozzle copy V096";copy.set("_surfaces",raw)
 if copy.get_surface_count()!=10:return {"ok":false,"reason":"Nozzle copy did not preserve surfaces."}
 var copied_storage=copy.get("_surfaces")
 for surface in source.get_surface_count():
  var copied=copy.surface_get_arrays(surface)
  for field in Mesh.ARRAY_MAX:
   if copied[field]!=arrays[surface][field]:return {"ok":false,"reason":"Mesh copy changed an unrelated array.","surface":surface,"field":field}
  for key in storage[surface]:
   if key in ["index_data","index_count","lods"] and surface in [1,3]:continue
   if storage[surface][key]!=copied_storage[surface].get(key):return {"ok":false,"reason":"Mesh copy changed an unrelated raw buffer.","surface":surface,"field":key}
 return {"ok":true,"mesh":copy,"caps":caps,"counts":counts,"removed":removed,"lod_removed":lod_removed,"source_sha":SOURCE_SHA,"removed_triangles":212}
static func pack_indices(indices:PackedInt32Array,stride:int)->PackedByteArray:
 var bytes=PackedByteArray();bytes.resize(indices.size()*stride)
 for index in indices.size():
  if stride==2:bytes.encode_u16(index*stride,indices[index])
  else:bytes.encode_u32(index*stride,indices[index])
 return bytes
static func unpack_indices(bytes:PackedByteArray,stride:int)->PackedInt32Array:
 var indices=PackedInt32Array()
 for index in bytes.size()/stride:indices.append(bytes.decode_u16(index*stride) if stride==2 else bytes.decode_u32(index*stride))
 return indices
static func triangle(tool:SurfaceTool,a:Vector3,b:Vector3,c:Vector3,normal:Vector3):
 # Godot front faces use clockwise winding; normals must face the visible cavity.
 if (b-a).cross(c-a).dot(normal)>0:
  var swap=b;b=c;c=swap
 for p in [a,b,c]:tool.set_normal(normal.normalized());tool.set_uv(Vector2(p.y,p.z));tool.add_vertex(p)
static func ring(boundary:Array,center:Vector3,normal:Vector3,inner_radius:float=.285)->ArrayMesh:
 # Stitch the original outer polygon to the shared16-sided mouth without
 # resampling/rounding original boundary vertices or creating sliver triangles.
 var outer=boundary.duplicate()
 outer.sort_custom(func(a,b):return fposmod(atan2(a.z-center.z,a.y-center.y),TAU)<fposmod(atan2(b.z-center.z,b.y-center.y),TAU))
 var first=0
 for index in outer.size():
  if outer[index].y>outer[first].y:first=index
 var ordered=outer.slice(first)+outer.slice(0,first);var inner=[]
 for index in 16:
  var angle=TAU*float(index)/16
  inner.append(Vector3(center.x,center.y+cos(angle)*inner_radius,center.z+sin(angle)*inner_radius))
 var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 var i=0;var j=0;var count=ordered.size()
 while i<count or j<16:
  var a:Vector3=ordered[i%count];var b:Vector3=inner[j%16]
  var outer_next=float(i+1)/count if i<count else INF
  var inner_next=float(j+1)/16 if j<16 else INF
  if absf(outer_next-inner_next)<.000001:
   var next_a:Vector3=ordered[(i+1)%count];var next_b:Vector3=inner[(j+1)%16]
   triangle(tool,a,next_a,b,normal);triangle(tool,next_a,next_b,b,normal);i+=1;j+=1
  elif outer_next<inner_next:
   triangle(tool,a,ordered[(i+1)%count],b,normal);i+=1
  else:
   triangle(tool,a,inner[(j+1)%16],b,normal);j+=1
 tool.index() # The existing shared batcher must not mix indexed and unindexed inputs.
 return tool.commit()
static func cavity(center:Vector3,front_x:float,neck_x:float)->ArrayMesh:
 var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 for index in 16:
  var a=TAU*float(index)/16;var b=TAU*float(index+1)/16;var middle=(a+b)*.5
  var front_a=Vector3(front_x,center.y+cos(a)*.285,center.z+sin(a)*.285)
  var front_b=Vector3(front_x,center.y+cos(b)*.285,center.z+sin(b)*.285)
  var neck_a=Vector3(neck_x,center.y+cos(a)*.285,center.z+sin(a)*.285)
  var neck_b=Vector3(neck_x,center.y+cos(b)*.285,center.z+sin(b)*.285)
  var back_a=Vector3(4.600,center.y+cos(a)*.20,center.z+sin(a)*.20)
  var back_b=Vector3(4.600,center.y+cos(b)*.20,center.z+sin(b)*.20)
  var neck_normal=Vector3(0,-cos(middle),-sin(middle))
  triangle(tool,front_a,neck_a,front_b,neck_normal);triangle(tool,front_b,neck_a,neck_b,neck_normal)
  var normal=Vector3(.085/(neck_x-4.600),-cos(middle),-sin(middle)).normalized()
  triangle(tool,neck_a,back_a,neck_b,normal);triangle(tool,neck_b,back_a,back_b,normal)
  triangle(tool,Vector3(4.600,center.y,center.z),back_a,back_b,Vector3.RIGHT)
 tool.index() # The existing shared batcher must not mix indexed and unindexed inputs.
 return tool.commit()
