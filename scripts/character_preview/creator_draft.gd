extends RefCounted
# Isolated session-only preview state. No files, inventory or gameplay references.
const HAIR=["none","hair_short02_v1","hair_bob01_v1"]
const HAIR_TINTS=["natural","warm_brown","copper","blue_black"]
const HAIR_TINT_LABELS=["Natural","Warm brown tint","Copper tint","Blue-black tint"]
const TINT_COLORS={"natural":Color.WHITE,"warm_brown":Color(0.62,0.43,0.30),"copper":Color(1.0,0.52,0.27),"blue_black":Color(0.22,0.25,0.30)}
const BROWS=["brow_009_v1","brow_001_v1"]
const EYES=["eye_brown_v1","eye_blue_v1"]
var committed={"name":"Settler","cheek":0.0,"hair":"hair_short02_v1","brows":"brow_009_v1","eyes":"eye_brown_v1","hair_tint":"natural"}
var draft:Dictionary={}
var disposed=false
func begin():draft=committed.duplicate(true)
func valid(v:Variant)->bool:
 if disposed or not v is Dictionary or v.size() not in [5,6]:return false
 if v.size()==6 and (not v.has("hair_tint") or v.hair_tint not in HAIR_TINTS):return false
 if not v.get("name") is String:return false
 var name:String=v.name.strip_edges()
 if name.is_empty() or name.length()>24 or name.contains("\n") or name.contains("\r"):return false
 var amount=v.get("cheek")
 return (amount is float or amount is int) and is_finite(float(amount)) and amount>=0 and amount<=1 and v.get("hair") in HAIR and v.get("brows") in BROWS and v.get("eyes") in EYES
func commit()->bool:
 if not valid(draft):return false
 committed=draft.duplicate(true);committed.name=committed.name.strip_edges();committed.cheek=float(committed.cheek);begin();return true
func cancel():begin()
func reset():draft={"name":committed.name,"cheek":0.0,"hair":"hair_short02_v1","brows":"brow_009_v1","eyes":"eye_brown_v1","hair_tint":"natural"}
func dispose():disposed=true;draft.clear()

static func tinted_material(original:StandardMaterial3D, appearance:Dictionary)->StandardMaterial3D:
 var result=original.duplicate() as StandardMaterial3D
 result.albedo_color=original.albedo_color*TINT_COLORS.get(appearance.get("hair_tint","natural"),Color.WHITE)
 return result
