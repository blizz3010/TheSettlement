extends RefCounted
# Explicit session-only annotations. No save files or gameplay meaning.
var _records:Dictionary={}
var serial:int=0
var revision:int=0
var disposed=false
const MAX_MARKERS=64 # provisional fixture/UI budget, not finalized game capacity
func rows()->Array:return _records.values().duplicate(true)
func add(at:Vector2,label:String,expected:int,bounds:Rect2)->String:
	if disposed or expected!=revision or not at.is_finite() or not bounds.has_point(at) or _records.size()>=MAX_MARKERS:return ""
	label=label.strip_edges()
	if label.is_empty() or label.length()>64 or label.contains("\n") or label.contains("\r"):return ""
	serial+=1;var id="session_marker_%d"%serial;_records[id]={"id":id,"at":at,"label":label};revision+=1;return id
func remove(id:String,expected:int)->bool:
	if disposed or expected!=revision:return false
	if not _records.has(id):return true
	_records.erase(id);revision+=1;return true
func hit(pixel:Vector2,transform,radius:float=10)->String:
	var chosen="";var nearest=radius
	for row in rows():
		var distance=transform.project(row.at).distance_to(pixel)
		if distance<nearest:nearest=distance;chosen=row.id
	return chosen
func dispose():disposed=true;revision+=1
