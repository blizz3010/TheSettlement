extends RefCounted
# Definition IDs are separate from owned item stacks and session UI state.
const VERSION=1
const FREE_STARTER='recipe_griddle_fish'
const IDS=['recipe_griddle_fish','recipe_herbed_fish','recipe_toasted_herbs','pattern_basic_gloves','pattern_basic_pants','pattern_basic_jacket']
static func defaults()->Array:return [FREE_STARTER]
static func valid(value:Variant)->bool:
 if not value is Array or value.size()>IDS.size() or not value.has(FREE_STARTER):return false
 var seen={}
 for id in value:
  if not id is String or not IDS.has(id) or seen.has(id):return false
  seen[id]=true
 return true
static func encode(known:Array)->Dictionary:return {'version':VERSION,'known':known.duplicate()}
static func decode(value:Variant)->Variant:
 if not value is Dictionary or value.size()!=2 or value.get('version')!=VERSION or not valid(value.get('known')):return null
 return value.known.duplicate()
