extends RefCounted
const Plot = preload("res://scripts/plot_state.gd")
const Inventory = preload("res://scripts/inventory_state.gd")
const Request = preload("res://scripts/request_state.gd")
const Craft = preload("res://scripts/craft_state.gd")
const Onboarding = preload("res://scripts/onboarding_state.gd")
const Fishing = preload("res://scripts/fishing_state.gd")
const Codec = preload("res://scripts/save_codec.gd")
static func valid(bytes: PackedByteArray) -> bool:
 var parser=JSON.new()
 return parser.parse(bytes.get_string_from_utf8())==OK and not Codec.decode(parser.data).is_empty()
static func create() -> PackedByteArray:
 var plot=Plot.new();var inventory=Inventory.new();var request=Request.new()
 var craft=Craft.new();var onboarding=Onboarding.new();var fishing=Fishing.new()
 onboarding.refresh(plot)
 var payload=Codec.encode(plot,inventory,request,craft,onboarding,fishing)
 var bytes=JSON.stringify(payload).to_utf8_buffer()
 if not valid(bytes):return PackedByteArray()
 var restored=Codec.decode(JSON.parse_string(bytes.get_string_from_utf8()))
 var again=Codec.encode(restored.plot,restored.inventory,restored.request,restored.craft,restored.onboarding,restored.fishing)
 if JSON.stringify(JSON.parse_string(JSON.stringify(payload)))!=JSON.stringify(JSON.parse_string(JSON.stringify(again))):return PackedByteArray()
 return bytes
