extends RefCounted
# Source-only durable DTO contract. No filesystem, gameplay mutation or automatic migration.
const ATTRIBUTES = ["str", "int", "dex"]
const MAX_REVISION = 2147483647
const SLOT_IDS = ["slot_1", "slot_2"]
const Appearance = preload("res://scripts/character_preview/creator_draft.gd")

static func integer(value: Variant) -> bool:
 return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value))

static func save_path(slot: String) -> String:
 return "user://characters/%s/settlement_v1.json" % slot if slot in SLOT_IDS else ""

static func rules_valid(rules: Dictionary) -> bool:
 if rules.keys().size() != 3 or not rules.get("id") is String or rules.id.is_empty():return false
 if not rules.get("ranges") is Dictionary or rules.ranges.size() != 3 or not rules.get("perks") is Dictionary:return false
 for key in ATTRIBUTES:
  var pair = rules.ranges.get(key)
  if not pair is Array or pair.size() != 2:return false
  if not integer(pair[0]) or not integer(pair[1]) or pair[0] < 0 or pair[1] < pair[0] or pair[1] > 1000:return false
 for key in rules.perks:
  if not key is String or key.is_empty() or not integer(rules.perks[key]) or abs(rules.perks[key]) > 1000:return false
 return true

static func roll(rules: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
 if not rules_valid(rules) or rng == null:return {}
 var values = {}
 for key in ATTRIBUTES:values[key] = rng.randi_range(int(rules.ranges[key][0]), int(rules.ranges[key][1]))
 return values

static func profile_valid(value: Variant, rules: Dictionary) -> bool:
 if not rules_valid(rules) or not value is Dictionary or value.size() != 7:return false
 if not integer(value.get("version")) or value.version != 1 or not value.get("slot") in SLOT_IDS or value.get("rules_id") != rules.id:return false
 if not value.get("intro_seen") is bool:return false
 var appearance = Appearance.new()
 if not appearance.valid(value.get("appearance")):return false
 if value.appearance.name != value.appearance.name.strip_edges() or value.appearance.name.length() > 24:return false
 if not value.get("stats") is Dictionary or value.stats.size() != 3 or not value.get("perks") is Array:return false
 for key in ATTRIBUTES:
  var number = value.stats.get(key)
  if not integer(number) or number < rules.ranges[key][0] or number > rules.ranges[key][1]:return false
 var seen = {};var balance = 0
 for key in value.perks:
  if not key is String or not rules.perks.has(key) or seen.has(key):return false
  seen[key] = true;balance += int(rules.perks[key])
 return balance == 0

static func catalogue_valid(value: Variant, rules: Dictionary) -> bool:
 if not rules_valid(rules):return false
 if not value is Dictionary or value.size() != 3 or not integer(value.get("version")) or value.version != 1:return false
 if not integer(value.get("revision")) or value.revision < 0 or value.revision > MAX_REVISION or not value.get("profiles") is Array or value.profiles.size() > 2:return false
 var seen = {}
 for profile in value.profiles:
  if not profile_valid(profile, rules) or seen.has(profile.slot):return false
  seen[profile.slot] = true
 return true

static func add_candidate(current: Dictionary, profile: Dictionary, expected_revision: int, rules: Dictionary) -> Dictionary:
 if not catalogue_valid(current, rules) or current.revision != expected_revision or current.revision >= MAX_REVISION or not profile_valid(profile, rules):return {}
 if current.profiles.size() >= 2:return {}
 for existing in current.profiles:
  if existing.slot == profile.slot:return {}
 var next = current.duplicate(true)
 next.profiles.append(profile.duplicate(true));next.revision += 1
 return next

static func intro_candidate(current: Dictionary, slot: String, expected_revision: int, rules: Dictionary) -> Dictionary:
 if not catalogue_valid(current, rules) or current.revision != expected_revision or current.revision >= MAX_REVISION:return {}
 var next = current.duplicate(true)
 for profile in next.profiles:
  if profile.slot == slot:
   if profile.intro_seen:return {}
   profile.intro_seen = true;next.revision += 1;return next
 return {}
