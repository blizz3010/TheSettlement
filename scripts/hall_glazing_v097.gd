extends RefCounted
## H01: bounded successor for the retained imported Hall. No authored GLB available.
## Replace only glazing surface 6. No added glass sheets, collision or service changes.
const REBATED=preload('res://assets/hall_v097/glazing_rebated.res')
const KEY='hall_glazing_rebate_v097'
const SOURCE_ARRAY_HASH=2037619590
# Production styling and basement-floor preparation re-encode normals/tangents
# twice. Geometry, UV and indices remain exact. Only these two observed full
# arrays are allowed; arbitrary count-compatible geometry is still rejected.
const PRODUCTION_ARRAY_HASH=4106236272
static func apply(hall:MeshInstance3D)->Dictionary:
 if not is_instance_valid(hall) or hall.mesh==null:return {'ok':false,'reason':'Missing Hall mesh'}
 if hall.has_meta(KEY):
  var prior=hall.get_meta(KEY)
  if prior is Dictionary and prior.get('mesh')==hall.mesh:return prior
  return {'ok':false,'reason':'Stale glazing receipt'}
 if hall.mesh.get_surface_count()!=18 or hash(hall.mesh.surface_get_arrays(6)) not in [SOURCE_ARRAY_HASH,PRODUCTION_ARRAY_HASH]:
  return {'ok':false,'reason':'Unexpected imported Hall glazing; retain source'}
 var source=hall.mesh
 var packed=source.get('_surfaces').duplicate()
 # Preserve the exact original material binding, including any successor shader.
 var replacement=REBATED.get('_surfaces')[0].duplicate()
 replacement['material']=source.surface_get_material(6)
 packed[6]=replacement
 var result=ArrayMesh.new();result.set('_surfaces',packed)
 for key in source.get_meta_list():result.set_meta(key,source.get_meta(key))
 hall.mesh=result
 var receipt={'ok':true,'mesh':result,'source_mesh':source,'changed_surface':6,'window_components':19,'desk_glazing_components_retained':2,'new_lights':0,'new_colliders':0}
 hall.set_meta(KEY,receipt)
 return receipt
