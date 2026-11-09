extends RefCounted
const SupportContract=preload('res://scripts/garden_baked_support.gd')
const BASE_SHA256='cdfb0dfefb27d5e8bce4b7e912315b2cc2bfde5ac16b09e63f705ba86b166690'
const WEST_SHA256='57ec5799d19a2eaf90158a2a74b255ab1082a10040c07b398f2b86c09f77eb16'
const DEVELOPER_EXPORT_SHA256='0cf6e56745cebc774ebad18fbc9ffa98cd56876ef4c36f53f448e667d74aceb7'
const REGION_NAMES=['HallBenchEastBack','EasternSpurNorth']
const EXPECTED_COUNTS={'HallBenchEastBack':1291,'EasternSpurNorth':1799}
const EXPECTED_GRASS={'HallBenchEastBack':1240,'EasternSpurNorth':1728}
const EXPORT_SOURCE_SHA256='49b25d49d6a686ac669c5195a0ac8df76f8eb911f48229a6c13bbb9ce2e53296'
const PARENT_GARDEN_SHA256='b0c8a6e93794d5dea677ccc81c768f185905daa61d76b19d50c7e118b84ab440'
const GRASS_SHADER_SHA256='a105f821501709a02075bf33365b7e327f7c90e40a07026a4609ac8b5506d98d'
const FOLIAGE_SHADER_SHA256='a0b2799e3bcf1b78df017c9ea16574248acf64b9ce410d78d373ae58f2c5f0a3'
const VERIFIED_RECIPE_SHA256='aa0926aea811ac5e3e7a156269c4a2c0e236cda4a58c7b652bb3338c34447cd1'
const MAX_BAKE_BYTES=32*1024*1024
const WIND_WORLD=.08
static func failure(reason:String)->Dictionary:return {'ok':false,'reason':reason}
static func load_recipe(path:String,expected_sha:String,grass_shader:Shader,foliage_shader:Shader)->Dictionary:
 if path.is_empty() or expected_sha.length()!=64:return failure('Reviewed terminal-PASS bake path and SHA256 are required')
 if expected_sha!=VERIFIED_RECIPE_SHA256:return failure('Only the reviewed sanitized recipe is accepted')
 for c in expected_sha:
  if not c in '0123456789abcdef':return failure('Bake SHA256 must be lowercase hexadecimal')
 var file=FileAccess.open(path,FileAccess.READ)
 if file==null or file.get_length()<=0 or file.get_length()>MAX_BAKE_BYTES:return failure('Bake missing or outside bounded 32MiB input limit')
 var bytes=file.get_buffer(file.get_length());file.close()
 var hashing=HashingContext.new();hashing.start(HashingContext.HASH_SHA256);hashing.update(bytes)
 if hashing.finish().hex_encode()!=expected_sha:return failure('Bake SHA256 mismatch')
 var data=bytes_to_var(bytes) # Objects disabled; never decode executable objects.
 if not data is Dictionary or not SupportContract.plain_values(data):return failure('Bake is not a plain typed Dictionary')
 if var_to_bytes(data)!=bytes:return failure('Bake does not round-trip exactly')
 if data.get('version',0)!=1 or data.get('clearance_policy',{})!={'world_wind':.08,'path_padding':.12,'obstacle_padding':.05}:return failure('Bake schema/clearance policy mismatch')
 var provenance=data.get('provenance',{})
 if not provenance is Dictionary or provenance.get('base_pck_sha256','')!=BASE_SHA256 or provenance.get('west_recipe_sha256','')!=WEST_SHA256 or provenance.get('developer_export_sha256','')!=DEVELOPER_EXPORT_SHA256 or provenance.get('source_manifest_sha256','')!=EXPORT_SOURCE_SHA256:return failure('Bake source/base/West/export provenance mismatch')
 var reference=data.get('reference',{})
 if not reference is Dictionary or not reference.get('ok',false) or not reference.get('complete',false) or reference.get('schema','')!='hall-east-spur-bake-reference-v1' or reference.get('expected_base_pck_sha256','')!=BASE_SHA256 or reference.get('parent_garden_sha256','')!=PARENT_GARDEN_SHA256:return failure('Bake reference is not a completed source02 two-bed export')
 var initial=reference.get('initial',{});var accepted=reference.get('accepted',{});var grass=reference.get('published_grass',{})
 if not initial is Dictionary or not accepted is Dictionary or not grass is Dictionary:return failure('Bake reference sections unavailable')
 for key in ['paths','reserved','occupied','solids']:
  if not initial.get(key) is Array:return failure('Bake baseline array missing: '+key)
 if not initial.get('support') is Dictionary or not initial.support.get('ok',false):return failure('Bake support descriptor missing')
 if not data.get('journal') is Array or not data.get('counts') is Dictionary or not data.get('bed_status') is Dictionary:return failure('Bake accepted recipe missing')
 if not accepted.get('ok',false) or data.journal!=accepted.get('journal') or data.counts!=accepted.get('counts') or data.bed_status!=accepted.get('bed_status'):return failure('Bake wrapper/accepted recipe mismatch')
 if data.journal.size()!=3090 or data.journal.size()>8480 or data.counts!=EXPECTED_COUNTS or data.bed_status.size()!=2 or grass.size()!=2:return failure('Bake is outside the reviewed two-bed recipe')
 if initial.has('raw_support_provenance') or not initial.get('delivered_west') is Dictionary or initial.delivered_west.get('recipe_sha256','')!=WEST_SHA256:return failure('Bake lacks sanitized shipped West baseline')
 for label in REGION_NAMES:
  if not data.bed_status.has(label) or not grass.has(label):return failure('Baked region missing: '+label)
  var published=grass[label]
  if not published is Dictionary or not published.get('surfaces') is Array or published.surfaces.size()!=1 or not published.get('use_custom_data',false) or published.get('use_colors',true) or published.get('transform_format',-1)!=MultiMesh.TRANSFORM_3D or published.get('instance_count',0)!=EXPECTED_GRASS[label]:return failure('Published regional blade format/count changed: '+label)
  if not published.get('mesh_aabb') is AABB or not published.get('custom_aabb') is AABB:return failure('Published regional grass bounds missing: '+label)
 if FileAccess.get_sha256(grass_shader.resource_path)!=GRASS_SHADER_SHA256 or FileAccess.get_sha256(foliage_shader.resource_path)!=FOLIAGE_SHADER_SHA256:return failure('Private shader bytes differ from accepted recipe')
 for asset in ASSET_HASHES:
  if FileAccess.get_sha256('res://'+asset)!=ASSET_HASHES[asset]:return failure('Original imported asset bytes changed: '+asset)
 return {'ok':true,'data':data,'sha256':expected_sha}
static func match_inputs(controller,inputs:Dictionary,initial:Dictionary)->Dictionary:
 if not preload("res://scripts/paving_platform_compat.gd").matches(inputs.paths,initial.paths) or inputs.reserved!=initial.reserved:return failure('Current paving/reservations differ from bake baseline')
 var west=inputs.delivered_west.duplicate(true);west.erase('controller_id');west.erase('root_id')
 if west!=initial.delivered_west:return failure('Current shipped West ownership/result differs from bake baseline')
 var portable=SupportContract.portable_support(controller.host,inputs.support_state)
 if not portable.get('ok',false):return failure('Current portable support unavailable: '+str(portable.get('reason','unknown')))
 var children=inputs.relief.get_children()
 if children.size()!=1 or not children[0] is CollisionShape3D:return failure('Relief no longer has its sole direct support shape')
 var now=SupportContract.canonical_support_roles(portable);var baked=SupportContract.canonical_support_roles(initial.support)
 if not now.ok:return failure('Current support role contract: '+now.reason)
 if not baked.ok:return failure('Baked support role contract: '+baked.reason)
 if now.canonical!=baked.canonical:return failure('Current support identity/geometry differs from bake role baseline')
 return {'ok':true}
static func world_wind_overlaps(blocks:Array,t:Transform3D,obstacle:AABB)->bool:
 var local=t.affine_inverse()*obstacle.grow(.05+WIND_WORLD)
 for block in blocks:
  if not block.bounds.intersects(local):continue
  for triangle in block.triangles:
   if triangle.intersects(local):return true
 return false

const ASSET_HASHES={
 ".godot/imported/Bark_NormalTree.png-c3ef14dd357b4050b579e189de431ce5.ctex": "5bd3fb15c61cd95061a5a93f044119e4e52640003eca3472600c0f57fa55a32e",
 ".godot/imported/Bark_NormalTree.png-c3ef14dd357b4050b579e189de431ce5.md5": "826114347856212e994c8137f2eb3bfa31d8383be53ba617624713b342c20e50",
 ".godot/imported/Bark_NormalTree_Normal.png-475fe75a7621d12a663265129be1c63f.ctex": "78b480bfbb0720b9f01c4c60fb744870481a07ce18eb3caecf4fc32f5a452f29",
 ".godot/imported/Bark_NormalTree_Normal.png-475fe75a7621d12a663265129be1c63f.md5": "74fc5f6fcb43e365e7d64805a1938c7e15d23319552dbb85d782cc97cf0e6392",
 ".godot/imported/Bush_Common.gltf-2e49e0eb36b0cc364d0eaa448ea16979.md5": "efbe28da1f5a705b0b552f5cc8d1e56057ef55829d6a9769c3efed17b626acaa",
 ".godot/imported/Bush_Common.gltf-2e49e0eb36b0cc364d0eaa448ea16979.scn": "4e0016a17d06627071314074ebc3f3cb54a139e8f3e32ff4bddd496bb252ead5",
 ".godot/imported/Bush_Common_Flowers.gltf-389110c8afa62dc00b746a089077747b.md5": "2e1c1740fb3375c0c8d29b48363bec617519c4c2a1b53e13e3a2d99b90e7e40a",
 ".godot/imported/Bush_Common_Flowers.gltf-389110c8afa62dc00b746a089077747b.scn": "9251a9d0484a73c47eb6580228a78707507ca03e6713f53f307820a0edb89f4a",
 ".godot/imported/Clover_1.gltf-84552e704bc7159b4352605d121320bb.md5": "bda191bc037ec382654c6907b9a7303707dd563d50d930fe5d7bcba9a4174744",
 ".godot/imported/Clover_1.gltf-84552e704bc7159b4352605d121320bb.scn": "11652b43e3fa555da255337c168b6884f4d0e2497793d282ce5bcc6b784782ea",
 ".godot/imported/CommonTree_1.gltf-ff85b5c8548a8bcb711cdf941904f5bf.md5": "3e2f1c19cdd5d107fbc0f8536ca3ffbc2f8826beace02fc5ffd1ecd970fad414",
 ".godot/imported/CommonTree_1.gltf-ff85b5c8548a8bcb711cdf941904f5bf.scn": "b0b235c4d8e842f90221000090d331f6050b60587e257267cbe69ebf3ba2ab13",
 ".godot/imported/CommonTree_3.gltf-57ec4bccf12cb518ce5d1eaa6d0b1450.md5": "7f3ea334988bf2207ba2298f1f7f41027f8ef8220a8472cc2847fb9a55e7d3f1",
 ".godot/imported/CommonTree_3.gltf-57ec4bccf12cb518ce5d1eaa6d0b1450.scn": "5dca2103e67c7f2e159c4bdd71149680575f2a5563cfcbe9a96aea43cf775278",
 ".godot/imported/Fern_1.gltf-e8d546c3e4924429eee28765583c8df5.md5": "41442ecffc77a7ba862273aff01474b0d197e43fa29b1af1c50ea7467b7bc007",
 ".godot/imported/Fern_1.gltf-e8d546c3e4924429eee28765583c8df5.scn": "176294a7e2bb889042c8e6b694f5113cbf0f44c76c87105a8ac2c7733a56e2e1",
 ".godot/imported/Flower_3_Group.gltf-37756fdd46eaf50cad823477e305645b.md5": "f72a3d40a11d5b17c7a9f674331114a0829471b77dd372c6ea51020782f4a0e7",
 ".godot/imported/Flower_3_Group.gltf-37756fdd46eaf50cad823477e305645b.scn": "55682e387c4215ea67439158bd4f467435ea1021b24d0bd423f0b4c389477cbc",
 ".godot/imported/Flower_4_Group.gltf-f21c7dcab439632fe3336fc42e3a3160.md5": "adf5d92690b4bd7ee1ecb39d73ecdc3dae7857132a28e7bbcf080766cf0b1925",
 ".godot/imported/Flower_4_Group.gltf-f21c7dcab439632fe3336fc42e3a3160.scn": "ff21d38cab373353641a13f88801ffb804e44865d0e119a416139c41d11e818a",
 ".godot/imported/Flowers.png-dc322cb24e12786268d1b70bf92f19cb.ctex": "7847702fce89eb41a5a20f8f2fe08df4a039835d82a0847a5d0640dd8fc27455",
 ".godot/imported/Flowers.png-dc322cb24e12786268d1b70bf92f19cb.md5": "b0bfb81947a6fe691289ca69eaa78c87ad1a0cd2f4c856452000a8f351a244ef",
 ".godot/imported/Grass.png-b0cbadb23ce10fa28c9e6771b3d540e1.ctex": "cc85651ec442d255cdf671c6d69eafccb71d4875cfe92ad91fd8f0fe546ebd77",
 ".godot/imported/Grass.png-b0cbadb23ce10fa28c9e6771b3d540e1.md5": "861c83b3ac05b7f8ca67253eaa459795a2bdebabe82ddd1049e5bb9076ef828e",
 ".godot/imported/Grass_Wispy_Short.gltf-a3da27bbb931a3501497dfe4974b750d.md5": "566bd3d342c229b55cede4698939f0876c5bdff509732e43ea49c9cac54b00cb",
 ".godot/imported/Grass_Wispy_Short.gltf-a3da27bbb931a3501497dfe4974b750d.scn": "1269f11fcfdedbdec382cbb34c2834276c889ae61c5e688bfc2929bc23f57db1",
 ".godot/imported/Leaves.png-852fc12bc71c331916959823244ab585.ctex": "2bbafd3a1348ec4b99005e197b76966ecfcc01f9d13eafea7376b5d3c391c2e6",
 ".godot/imported/Leaves.png-852fc12bc71c331916959823244ab585.md5": "88ef364ee5f09a1d08efc2835b7e67977805efaabbeb8d00be9b36fc8e6ccf63",
 ".godot/imported/Leaves_NormalTree_C.png-e6467ae01f45f93a839d24e178655208.ctex": "5866f045e997361c0252c088d0c11fa94f8332c8079d3fdbd831c8079a7c8d23",
 ".godot/imported/Leaves_NormalTree_C.png-e6467ae01f45f93a839d24e178655208.md5": "a5c5c3e56e18f21093b5f35d96de9bb599155e4cf63cac35125434f99be89128",
 ".godot/imported/Leaves_TwistedTree_C.png-569c3c14adbde94466d5fcbd0ec8df3a.ctex": "b5166391eb7f7052a9f6e42bdb18507d5133f65fb19b1f0b0e6dbf1b0f9a94f6",
 ".godot/imported/Leaves_TwistedTree_C.png-569c3c14adbde94466d5fcbd0ec8df3a.md5": "6de1d8549bc455b9cfcfcc059aeffc149f34e2f5850fb1dcf81ab510f5c7e756",
 ".godot/imported/PathRocks_Diffuse.png-3def7e351baac6f60650c86f559292a7.ctex": "86cc44169274cecfc6f393ca8ca2004790fb0d41ebdaea832b428a8021726442",
 ".godot/imported/PathRocks_Diffuse.png-3def7e351baac6f60650c86f559292a7.md5": "2659bde935e3c1cffa5584d0e292f8717383ee61a9bc9c7682862a33c1e91254",
 ".godot/imported/Pebble_Round_1.gltf-9ba590fb578798e4acd3aa3689748648.md5": "d0c868cb0de55e79407cb6936102b6a23db9ecd61d7aa8e841665c79c4acd443",
 ".godot/imported/Pebble_Round_1.gltf-9ba590fb578798e4acd3aa3689748648.scn": "cb94277ef8936fb0b3e3587e76388a73fe1ee25de1b90f85f8e52e006168c1d6",
 ".godot/imported/Plant_1.gltf-6800e0c5df8cbd5495edc5f5a73db04a.md5": "8fe200171a993e096882e08aaf108b12fb507a93cc25d83b0e26f0d43a10b5df",
 ".godot/imported/Plant_1.gltf-6800e0c5df8cbd5495edc5f5a73db04a.scn": "c962dc15fd8ed18d82e32c1ad4ffd7626a32ee7b76fef68f17a4803ee53531ee",
 ".godot/imported/Rock_Medium_1.gltf-b56e2293e111796eb3743c051e4d841a.md5": "92f95268e88ffc1ffef344c73d076ee491e5b45c707266eff8296839387e215c",
 ".godot/imported/Rock_Medium_1.gltf-b56e2293e111796eb3743c051e4d841a.scn": "44f2a2149b671ed34cc7a4732ee9d31540b2212271d049d9be08e73fa73d45f1",
 ".godot/imported/Rocks_Diffuse.png-65778a733d094f2b31c72ff2219058d7.ctex": "f4d3c4c676d7079137385ef4d55b4c15c02a0498eba7f734b2499f466da23edc",
 ".godot/imported/Rocks_Diffuse.png-65778a733d094f2b31c72ff2219058d7.md5": "06eabfd0dc2c9e41b62a0ec24148007b4bb3671a9fbcc530cc2ba045fefd7a67",
 "assets/quaternius/Bark_NormalTree.png": "f36e94fdd73255347325b998e02a0b2575fdf714b0315bfe5e8ff34bc8e13603",
 "assets/quaternius/Bark_NormalTree.png.import": "d9e285553fb4e087ef5ec8d042e4d6cfe0790337d4435f974962ee64d6f1d50a",
 "assets/quaternius/Bark_NormalTree_Normal.png": "852f6155404b8c39e100e41e26970e02a6a5c81b482d3726618dab28e3ad03a2",
 "assets/quaternius/Bark_NormalTree_Normal.png.import": "42f04a3e54a90a2c345c4a34dc2ee19433e715d9d78de09f767245bf62b162a9",
 "assets/quaternius/Bush_Common.bin": "a5e1a773c8ba78fd9c05a8b342131eba4879302a8fddd2c5186cab9ee1ef4966",
 "assets/quaternius/Bush_Common.gltf": "77811fca92610cb254713d3d49d5029ab6cf13050c3afb61aa942786a7b2ca90",
 "assets/quaternius/Bush_Common.gltf.import": "c7d7fb089759a24f5daee0244c32ea06a6ac8cd7bd5b0d4bb6bce57c411f9163",
 "assets/quaternius/Bush_Common_Flowers.bin": "15f56a013afe0eecaded0eb97fd8f323305af11e1f0f7bb9b68472ec4cdc20d5",
 "assets/quaternius/Bush_Common_Flowers.gltf": "08768c680e3abeafd25858c9d3f369bcb7eed014661d3b6825a397f2a6a3deea",
 "assets/quaternius/Bush_Common_Flowers.gltf.import": "4f4c0e8a96dc51fbe5ea04614492010d55b23283d733c7588a6e4954cc1ed43e",
 "assets/quaternius/Clover_1.bin": "788fabaffc3f8f2825ad88399bd4725d8bc397225d93d00926c3223fdee9516b",
 "assets/quaternius/Clover_1.gltf": "05fe48cdf1f3db879371a6ba0d843fcd407667b7680def5716c9f286efe0306b",
 "assets/quaternius/Clover_1.gltf.import": "381c07a5bc7ddf4009b61cc5ad53091d4ebc990db1bce16f320babe9a51812e4",
 "assets/quaternius/CommonTree_1.bin": "9dd689e84e1aa2f5b08db8def591254d582783c73737af54ba0d89b3e549c3ae",
 "assets/quaternius/CommonTree_1.gltf": "b51cdea6545edb51d102dd6c27caafe62aa75e3c328ac8f9039f4e7bfd690bfa",
 "assets/quaternius/CommonTree_1.gltf.import": "9ac8592456fa26584e9cdd141838a47a642ce45625c27da5adee24c2fc9a13e8",
 "assets/quaternius/CommonTree_3.bin": "24541f46fd9553e2389aba15575f2697009226e82118ed76868284114fd12b49",
 "assets/quaternius/CommonTree_3.gltf": "17c6537aa8042bb7255fbb501bf7aeb2b6db87c16766f794f9c37be3ce70c976",
 "assets/quaternius/CommonTree_3.gltf.import": "649b470832792eeed36aa3728a55cfe441e4afce2dd641f0ac5346b86b4f1e09",
 "assets/quaternius/Fern_1.bin": "5e92b87a27f81a69fe15347a533df3c77d567b48298dceeef43168ccb7c22853",
 "assets/quaternius/Fern_1.gltf": "d41915cffe9dbbde1ae88be381eb9c60f7caa2274511436cc78fe4de627468ab",
 "assets/quaternius/Fern_1.gltf.import": "75c0ee6141f607ba02ed983123be74a5bdeabab9d6a8c320dced8c7a9bc8fbf9",
 "assets/quaternius/Flower_3_Group.bin": "5ab387dd3d6fe181df3af4eeac4df85533e4c27e77545ae39a61e0c2aaaab248",
 "assets/quaternius/Flower_3_Group.gltf": "4df1612371982c543f930d6b213967372e0d459622d7eff7fc2ed1ddbfaa3b6c",
 "assets/quaternius/Flower_3_Group.gltf.import": "da847a55ecfce680b9a4abea861668d081bf5056340ec6862778edd2003be5df",
 "assets/quaternius/Flower_4_Group.bin": "3ac30b4c9eaa5078a17c061aa29e2e9618cc9eb58cb6d5d2ab0c07fa0b851ae1",
 "assets/quaternius/Flower_4_Group.gltf": "69ead56b36b50f06a0cf18380797fce7434302e9b2da7bf68a85014b993c6134",
 "assets/quaternius/Flower_4_Group.gltf.import": "34c1daeb436f7d83bbb7c56e280fd2caa6ad056f2cc12470b30dc22c48405c00",
 "assets/quaternius/Flowers.png": "5c531f2329c241c625aafd6cb769de29f33b480ef2a16491c2489f3c68e62a6a",
 "assets/quaternius/Flowers.png.import": "ee7b35e33bf8caa372374de677fcdeae93bf6de466efa90a3b8fda15fcf58d21",
 "assets/quaternius/Grass.png": "5d69048193b246a73c996b892607fb36c75d0c60afcb2dab8aa12de3c0b2d9bd",
 "assets/quaternius/Grass.png.import": "55fd5d1820ab9f01bc1cab3c1fa9468c11b86cc7d76348c9c2f19df7476e2257",
 "assets/quaternius/Grass_Wispy_Short.bin": "c38f46e5a66ed3917fd45104effb914228d43d3724f4659416e1533dcd71776d",
 "assets/quaternius/Grass_Wispy_Short.gltf": "3c1d3bdd332420e070abde72d73611d1f13acfbe027e26b2fb943f9bcbd6b1c5",
 "assets/quaternius/Grass_Wispy_Short.gltf.import": "12e9f8b8ed1ac9b8dae900ccdbcd9b7ad7935481e9efcc1291f7fd92ab039939",
 "assets/quaternius/Leaves.png": "23248cebe28a24e78add32db3c2ee2f4d7b9219e9d2467279722f0197a7b6bd5",
 "assets/quaternius/Leaves.png.import": "dfab88b2a8b5f04d97e7364a871a5c68e7e28f06a9b25f0625d52be476e28cb4",
 "assets/quaternius/Leaves_NormalTree_C.png": "998612bdf0b76a22f5f54d65cd7a457815d2842d89653fa4348a4ebb42933ad3",
 "assets/quaternius/Leaves_NormalTree_C.png.import": "a16ecf77b29b2fc7ce824a2cff849b5f391c97ba47841a73c554b6fe5341b825",
 "assets/quaternius/Leaves_TwistedTree_C.png": "0e459b56b14c0e81b1b7cf3d1e8c6f0bb71790eb6c46bb02a76a922d8df646ea",
 "assets/quaternius/Leaves_TwistedTree_C.png.import": "cf8c8e80417489015d1fdc85ba811fe6b2a1027a123fbbd3b7ccddece1875810",
 "assets/quaternius/License_Standard.txt": "120710e542c3ebaf83856c4eb55b4a1e680593b39302eba7fdc5d942dfe78c58",
 "assets/quaternius/PathRocks_Diffuse.png": "85a04abb2c136fee53b376daf3b7d7f96fdf3966de0258dff6fe2b24da792b23",
 "assets/quaternius/PathRocks_Diffuse.png.import": "89fb2a56e2cd65544b9b602ccfefe991c88bc62e240f0f93b8fbf9d27ff7b600",
 "assets/quaternius/Pebble_Round_1.bin": "f3dacef3243ccaaad7df2beb5c72574a38fb3eae45357e1b5e2b40200d51c375",
 "assets/quaternius/Pebble_Round_1.gltf": "9f6261c81134915e73cf35eb4e37076238fd1e79434515ac686d15cbd1f779ab",
 "assets/quaternius/Pebble_Round_1.gltf.import": "87541f43c5373333a63a28df2e8a47da1b9b58e6dd05b67610547f25a42fef71",
 "assets/quaternius/Plant_1.bin": "cc36c3e6e3473e13ce93ddb7f5efbfa57db43106f1036a8b8ea00edeedfde322",
 "assets/quaternius/Plant_1.gltf": "11749feb4c196bc69eaba0c0ad938fab09e3fe33c02e0d0f86b329eacf633b55",
 "assets/quaternius/Plant_1.gltf.import": "48083efb17f4dd1edfd9697338974511d0964898a2aeaff275543463958eaa8d",
 "assets/quaternius/Rock_Medium_1.bin": "ea79527d4c2b3bdb7a28bf589bf0c1fd96d192a4d0738636753911dd58681e99",
 "assets/quaternius/Rock_Medium_1.gltf": "5d1ab1fa03218f4a908728ed0eabe6486344a7e4f510b0d3d6f837fd1d011bd8",
 "assets/quaternius/Rock_Medium_1.gltf.import": "2ec63670dd74254823bf484544be6e6e7c46434ed8cd822acd1f75d9940cf6b9",
 "assets/quaternius/Rocks_Diffuse.png": "b813696df6081f469a127092eb0ce45cc39d56f3ccc0699152bfcd3804810b48",
 "assets/quaternius/Rocks_Diffuse.png.import": "2badb86c691c4a7f90ee8967e6b80a971682ecbdd735f5d818d8205f9fc40f81"
}
