extends RefCounted
# Explicitly provisional metadata, not approved balance or active gameplay modifiers.
const COSTS={"steady":1,"restless":-1,"methodical":1,"impatient":-1}
const LABELS={"steady":"Steady (prototype)","restless":"Restless (prototype)","methodical":"Methodical (prototype)","impatient":"Impatient (prototype)"}
static func data()->Dictionary:
 return {"id":"experimental-creation-1","ranges":{"str":[3,12],"int":[3,12],"dex":[3,12]},"perks":COSTS.duplicate()}
