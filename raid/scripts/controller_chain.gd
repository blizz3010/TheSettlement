extends RefCounted
## Shared check for the stacked trader-controller extensions (Dan -> Atlas -> Psy
## tiers -> raid loot). An installer must treat a controller that already runs a
## LATER extension as installed, or a second install pass would swap the script
## back down the chain and orphan the later panels.
static func inherits(node, path: String) -> bool:
	if node == null or not is_instance_valid(node) or node.get_script() == null:
		return false
	var script: Script = node.get_script()
	while script != null:
		if script.resource_path == path:
			return true
		script = script.get_base_script()
	return false
