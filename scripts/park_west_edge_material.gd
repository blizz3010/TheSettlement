extends RefCounted
# Portable visual-only adapter. Caller validates GLB/source binding first.
# Does not sample terrain, change physics, or publish/attach to the live world.
static func prepare(scene:Node3D,shader:Shader,expected_shader_sha:String)->Dictionary:
 if scene==null or shader==null:return {'ok':false,'reason':'Missing baked scene/shader'}
 if FileAccess.get_sha256(shader.resource_path)!=expected_shader_sha:return {'ok':false,'reason':'Shader source hash mismatch'}
 if scene.get_child_count()!=11 or not scene.find_children('*','CollisionObject3D',true,false).is_empty():return {'ok':false,'reason':'Unexpected baked hierarchy or physics'}
 var edge=scene.get_node_or_null('FlushStoneEdge')
 if edge==null:return {'ok':false,'reason':'Missing exact edge identity'}
 var meshes=edge.find_children('*','MeshInstance3D',true,false);var triangles=0
 if meshes.size()!=31:return {'ok':false,'reason':'Unexpected edge mesh count'}
 for mesh in meshes:
  if mesh.mesh==null:return {'ok':false,'reason':'Missing edge geometry'}
  triangles+=mesh.mesh.get_faces().size()/3
 if triangles!=62:return {'ok':false,'reason':'Unexpected edge geometry'}
 var material=ShaderMaterial.new();material.shader=shader
 preload('res://scripts/route_material_detail.gd').bind(edge,material)
 for mesh in meshes:mesh.material_override=material
 return {'ok':true,'edge_triangles':62,'shader_sha':expected_shader_sha,'terrain_queries':0}
