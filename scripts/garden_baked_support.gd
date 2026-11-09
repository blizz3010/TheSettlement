extends RefCounted
# Exact portable support conversion from the reviewed developer exporter.
static func plain_values(value)->bool:
 if typeof(value) in [TYPE_OBJECT,TYPE_RID,TYPE_CALLABLE,TYPE_SIGNAL]:return false
 if value is Dictionary:
  for key in value:
   if not plain_values(key) or not plain_values(value[key]):return false
 elif value is Array:
  for item in value:
   if not plain_values(item):return false
 return true
static func register_node(host,id:int,nodes:Dictionary)->Dictionary:
 var node=instance_from_id(id)
 if not is_instance_valid(node) or not node is Node:return {'ok':false,'reason':'Support ObjectID no longer resolves to a node'}
 if node!=host and not host.is_ancestor_of(node):return {'ok':false,'reason':'Support node is outside the host boundary'}
 var path:NodePath=host.get_path_to(node)
 var parent_path=null;var owner_path=null
 if node!=host:
  var parent=node.get_parent()
  if not is_instance_valid(parent) or (parent!=host and not host.is_ancestor_of(parent)):return {'ok':false,'reason':'Support parent is outside the host boundary'}
  parent_path=host.get_path_to(parent)
  if node.owner!=null:
   if node.owner!=host and not host.is_ancestor_of(node.owner):return {'ok':false,'reason':'Support scene owner is outside the host boundary'}
   owner_path=host.get_path_to(node.owner)
 nodes[path]={'class':node.get_class(),'parent_path':parent_path,'owner_path':owner_path}
 return {'ok':true,'path':path}
static func register_resource(id:int,binding:String,resources:Dictionary)->Dictionary:
 var resource=instance_from_id(id)
 if not is_instance_valid(resource) or not resource is Resource:return {'ok':false,'reason':'Support ObjectID no longer resolves to a resource'}
 if not resources.has(id):resources[id]={'class':resource.get_class(),'resource_path':resource.resource_path,'bindings':[]}
 if binding in resources[id].bindings:return {'ok':false,'reason':'Duplicate support resource binding'}
 resources[id].bindings.append(binding)
 return {'ok':true}
static func portable_support(host,raw:Dictionary)->Dictionary:
 if not raw.get('ok',false):return {'ok':false,'reason':'Raw support snapshot is not valid'}
 # Preserve every original row, ordering, primitive value and packed geometry.
 # Only per-process identity fields are replaced. Shared-resource identity classes
 # are preserved by canonical owner-path/property binding lists.
 var state=raw.duplicate(true);var nodes={};var resources={}
 var node_ids=[]
 node_ids.append_array([raw.turf[0],raw.turf[1],raw.render_owner[0],raw.render_owner[1]])
 for key in ['bodies','shapes','renders']:
  for row in raw[key]:node_ids.append_array([row[0],row[1]])
 var node_paths={}
 for id in node_ids:
  if node_paths.has(id):continue
  var node_registered=register_node(host,id,nodes)
  if not node_registered.ok:return node_registered
  node_paths[id]=node_registered.path
 var resource_registered=register_resource(raw.turf[4],str(node_paths[raw.turf[0]])+':mesh',resources)
 if not resource_registered.ok:return resource_registered
 for row in raw.shapes:
  resource_registered=register_resource(row[4].id,str(node_paths[row[0]])+':shape',resources)
  if not resource_registered.ok:return resource_registered
 for row in raw.renders:
  resource_registered=register_resource(row[4],str(node_paths[row[0]])+':mesh',resources)
  if not resource_registered.ok:return resource_registered
 var resource_keys={};var bindings={}
 for id in resources:
  var description:Dictionary=resources[id]
  description.bindings.sort()
  var key:String=description.bindings[0]
  if bindings.has(key):return {'ok':false,'reason':'Ambiguous canonical support resource binding'}
  resource_keys[id]=key;bindings[key]=description
 state.turf[0]=node_paths[raw.turf[0]];state.turf[1]=node_paths[raw.turf[1]];state.turf[4]=resource_keys[raw.turf[4]]
 state.render_owner[0]=node_paths[raw.render_owner[0]];state.render_owner[1]=node_paths[raw.render_owner[1]]
 for key in ['bodies','shapes','renders']:
  for i in range(raw[key].size()):
   state[key][i][0]=node_paths[raw[key][i][0]];state[key][i][1]=node_paths[raw[key][i][1]]
 for i in range(raw.shapes.size()):state.shapes[i][4]['id']=resource_keys[raw.shapes[i][4].id]
 for i in range(raw.renders.size()):state.renders[i][4]=resource_keys[raw.renders[i][4]]
 return {'ok':true,'schema':'source09-portable-support-v1','state':state,'nodes':nodes,'resources':bindings}
# Reviewed, bounded semantic bijection. This is not generated-name stripping.
static func role_failure(reason:String)->Dictionary:return {'ok':false,'canonical':{},'original_role_paths':{},'reason':reason}
static func canonical_support_roles(portable:Dictionary)->Dictionary:
 if not portable.get('ok',false) or portable.get('schema','')!='source09-portable-support-v1':return role_failure('Invalid portable support schema')
 var s=portable.state;var nodes=portable.nodes;var resources=portable.resources
 if s.bodies.size()!=2 or s.shapes.size()!=5 or s.renders.size()!=4:return role_failure('Expected exactly two bodies, five support shapes and four renders')
 var ground=s.bodies[0][0];var relief=s.bodies[1][0];var owner=s.render_owner[0]
 if s.turf[0]!=NodePath('SettlementTerrain/GroundRelief') or s.turf[1]!=NodePath('SettlementTerrain') or relief!=NodePath('SettlementTerrain/WalkableRelief') or s.bodies[1][1]!=NodePath('SettlementTerrain') or owner!=NodePath('HallBasementBlockout') or s.render_owner[1]!=NodePath('.'):return role_failure('Named support identity changed')
 if ground==relief or s.bodies[0][1]!=NodePath('.') or s.bodies[0][2]!=Transform3D(Basis.IDENTITY,Vector3(0,-.35,0)):return role_failure('Validated ground body contract changed')
 var rows=[s.turf,s.render_owner];rows.append_array(s.bodies);rows.append_array(s.shapes);rows.append_array(s.renders)
 for row in rows:
  if not nodes.has(row[0]) or nodes[row[0]].parent_path!=row[1]:return role_failure('Portable node/parent relationships disagree')
 if nodes[ground].get('class')!='StaticBody3D' or nodes[relief].get('class')!='StaticBody3D' or nodes[s.turf[0]].get('class')!='MeshInstance3D' or nodes[owner].get('class')!='Node3D':return role_failure('Support owner class changed')
 var roles={ground:NodePath('__BAKE_ROLE__/ground_body')};var original={'ground_body':ground}
 for i in range(4):
  var shape=s.shapes[i];var render=s.renders[i]
  if shape[1]!=ground or render[1]!=owner or shape[4].get('kind')!='box' or shape[4].size!=render[5] or shape[2]!=render[2] or shape[3] or not render[3]:return role_failure('Ground shape/render bijection changed')
  if nodes[shape[0]].get('class')!='CollisionShape3D' or nodes[render[0]].get('class')!='MeshInstance3D':return role_failure('Ground member class changed')
  if resources[shape[4].id].get('class')!='BoxShape3D' or resources[render[4]].get('class')!='BoxMesh':return role_failure('Ground support resource class changed')
  for item in [[shape[0],'ground_shape_'+str(i)],[render[0],'ground_render_'+str(i)]]:
   if roles.has(item[0]):return role_failure('Ground roles do not have distinct identities')
   roles[item[0]]=NodePath('__BAKE_ROLE__/'+item[1]);original[item[1]]=item[0]
 # Identify the one relief shape by parent membership, never by a generated name
 # or by assuming the final row is the relief. Live collection separately checks
 # the relief body has exactly one direct CollisionShape3D child.
 var relief_members=[]
 for shape in s.shapes:
  if shape[1]==relief:relief_members.append(shape)
 if relief_members.size()!=1:return role_failure('Relief must have exactly one direct support shape')
 var r=relief_members[0]
 if nodes[r[0]].get('class')!='CollisionShape3D' or r[4].get('kind')!='concave' or r[3] or resources[r[4].id].get('class')!='ConcavePolygonShape3D' or roles.has(r[0]):return role_failure('Relief support shape contract changed')
 roles[r[0]]=NodePath('__BAKE_ROLE__/relief_shape');original['relief_shape']=r[0]
 if roles.size()!=10:return role_failure('Support role bijection is incomplete')
 for path in roles:
  if path in [s.turf[0],s.turf[1],relief,owner,NodePath('.')] or nodes.has(roles[path]):return role_failure('Semantic role collides with a named support identity')
 # Validate the complete resource-alias partition before re-keying it.
 var actual={}
 var resource_rows=[[s.turf[4],str(s.turf[0])+':mesh']]
 for shape in s.shapes:resource_rows.append([shape[4].id,str(shape[0])+':shape'])
 for render in s.renders:resource_rows.append([render[4],str(render[0])+':mesh'])
 for pair in resource_rows:
  if not actual.has(pair[0]):actual[pair[0]]=[]
  if pair[1] in actual[pair[0]]:return role_failure('Duplicate resource owner binding')
  actual[pair[0]].append(pair[1])
 if actual.size()!=resources.size():return role_failure('Unexpected support resource alias group')
 var resource_keys={};var new_resources={}
 for key in resources:
  if not actual.has(key):return role_failure('Unreferenced support resource')
  actual[key].sort()
  if actual[key]!=resources[key].bindings or key!=actual[key][0]:return role_failure('Resource alias topology disagrees with support rows')
  var description=resources[key].duplicate(true);var aliases=[]
  for binding in description.bindings:
   var separator=binding.rfind(':');var path=NodePath(binding.substr(0,separator));var suffix=binding.substr(separator)
   if suffix not in [':mesh',':shape']:return role_failure('Unexpected resource binding property')
   aliases.append(str(roles.get(path,path))+suffix)
  aliases.sort();description.bindings=aliases
  var new_key=aliases[0]
  if new_resources.has(new_key):return role_failure('Canonical resource alias collision')
  resource_keys[key]=new_key;new_resources[new_key]=description
 var state=s.duplicate(true);var new_nodes={}
 for path in nodes:
  var description=nodes[path].duplicate(true)
  description.parent_path=roles.get(description.parent_path,description.parent_path)
  description.owner_path=roles.get(description.owner_path,description.owner_path)
  new_nodes[roles.get(path,path)]=description
 state.turf[0]=roles.get(s.turf[0],s.turf[0]);state.turf[1]=roles.get(s.turf[1],s.turf[1]);state.turf[4]=resource_keys[s.turf[4]]
 state.render_owner[0]=roles.get(s.render_owner[0],s.render_owner[0]);state.render_owner[1]=roles.get(s.render_owner[1],s.render_owner[1])
 for key in ['bodies','shapes','renders']:
  for i in range(s[key].size()):
   state[key][i][0]=roles.get(s[key][i][0],s[key][i][0]);state[key][i][1]=roles.get(s[key][i][1],s[key][i][1])
 for i in range(s.shapes.size()):state.shapes[i][4].id=resource_keys[s.shapes[i][4].id]
 for i in range(s.renders.size()):state.renders[i][4]=resource_keys[s.renders[i][4]]
 return {'ok':true,'canonical':{'schema':'source09-support-roles-v1','state':state,'nodes':new_nodes,'resources':new_resources},'original_role_paths':original,'reason':''}
