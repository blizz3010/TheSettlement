extends RefCounted
const Profiles = preload("res://scripts/character_profiles/profile_model.gd")
# Pure routing decisions. Disk store/title controller must bind generation and verified saves.
static func entry(catalogue_present: bool, catalogue: Variant, legacy_present: bool, rules: Dictionary) -> Dictionary:
 if not Profiles.rules_valid(rules):return {"screen":"blocked","reason":"Creation rules unavailable"}
 if catalogue_present:
  if not Profiles.catalogue_valid(catalogue,rules):return {"screen":"blocked","reason":"Invalid character catalogue; preserve files"}
  if catalogue.profiles.is_empty():return {"screen":"legacy_decision" if legacy_present else "create","slot":"slot_1"}
  return {"screen":"select","can_create":catalogue.profiles.size()<2}
 return {"screen":"legacy_decision" if legacy_present else "create","slot":"slot_1"}

static func selected(catalogue: Dictionary, slot: String, expected_revision: int, rules: Dictionary, gameplay_verified: bool) -> Dictionary:
 if not Profiles.catalogue_valid(catalogue,rules) or catalogue.revision != expected_revision or not gameplay_verified:return {}
 for profile in catalogue.profiles:
  if profile.slot == slot:
   return {"screen":"loading" if profile.intro_seen else "intro_then_loading", "slot":slot,"save_path":Profiles.save_path(slot),"revision":expected_revision}
 return {}
