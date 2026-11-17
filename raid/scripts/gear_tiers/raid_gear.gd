extends Node
## Raid hookup for tiered gear (TASKS item 22, PR B).
## Loads user://gear_locker.json, binds the health reduction hook, wears durability in
## play, applies the downed rule (gear kept, Defs.DOWNED_DURABILITY_LOSS), boots safe-fall
## bonus, face-cover hazard i-frame bonus, headset threat cues + compression, a small
## HUD readout, and saves the locker when the raid ends.
## With nothing equipped the raid never adds this node, binds nothing and writes nothing,
## so behaviour is identical to main.
const Defs = preload("res://raid/scripts/gear_tiers/gear_defs.gd")
const Store = preload("res://raid/scripts/gear_tiers/gear_locker_store.gd")
const BasePlayer = preload("res://scripts/player.gd")
const GearPlayer = preload("res://raid/scripts/gear_tiers/raid_gear_player.gd")
const Storage = preload("res://raid/scripts/gear_tiers/gear_storage.gd")
## Unaided hearing distance for threat cues (m); headset hearing_range scales it.
const BASE_THREAT_RANGE := 24.0
const THREAT_BUS := "GearThreat"
const THREAT_DIR := "res://raid/audio/threat/"
const THREAT_CUES := {"turret_servo_whine": -12.0, "turret_warmup_tone": -14.0, "turret_shot": -8.0, "live_cable_crackle": -16.0}
const COMPRESSION := {
	"off": {},
	"light": {"threshold": -14.0, "ratio": 2.0, "gain": 2.0},
	"medium": {"threshold": -18.0, "ratio": 4.0, "gain": 4.0},
	"strong": {"threshold": -22.0, "ratio": 8.0, "gain": 6.0},
}
const CRACKLE_INTERVAL := 1.1
const HINT_SECONDS := 2.5

var store
var world: Node
var health: Node
var hud: PanelContainer
var hud_label: Label
var hint_label: Label
var dirty := false
var headset := {}
var hearing_range := 0.0
var streams := {}
var voices: Array = []
var events: Array = []  # [cue, distance] for tests
var bus_index := -1
var turret_was_tracking := false
var turret_shots := 0
var crackle_left := 0.0
var hint_left := 0.0
var safe_fall_bonus := 0.0
var hazard_iframe_bonus := 0.0
## PR D: haul carried beyond the pouch (kg) and the live movement band.
var load_kg := 0.0
var haul_ref: Dictionary = {}

# ------------------------------------------------------------------ loading
## Reads the sidecar if it exists. A missing file is an empty locker and is NOT created.
func load_locker(path: String = Store.DEFAULT_PATH) -> void:
	store = Store.new()
	if FileAccess.file_exists(path): store.load_locker(path)
	else: store.path = path

func active() -> bool:
	return store != null and not store.state.equipped_ids().is_empty()

func movement() -> Dictionary:
	if not active(): return {"sprint": 1.0, "walk": 1.0}
	var band: Dictionary = Storage.band(store.state, haul_ref)
	return {"sprint": float(band.sprint), "walk": float(band.walk)}

## player.gd unless the worn weight crosses a band, or (PR D) a rig/pack can add
## load mid-raid. GearPlayer at x1.0 moves exactly like player.gd.
func player_script() -> Script:
	var m := movement()
	if m.sprint < 1.0 or m.walk < 1.0: return GearPlayer
	return GearPlayer if active() and Storage.carries_load(store.state) else BasePlayer

## PR D: the haul changed; re-band movement on the live player and refresh the HUD.
func refresh_load(haul: Dictionary) -> void:
	haul_ref = haul
	load_kg = Storage.load_weight(haul)
	if world != null and is_instance_valid(world.player): configure_player(world.player)
	refresh_hud()

func configure_player(p: Node) -> void:
	if p.get_script() == GearPlayer:
		var m := movement()
		p.gear_sprint_mult = m.sprint
		p.gear_walk_mult = m.walk

# -------------------------------------------------------------------- setup
func setup(raid_world: Node, ui_parent: Control) -> void:
	name = "RaidGear"
	world = raid_world
	health = world.health_controller.health
	health.reduction = _reduce
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	var boots: Dictionary = store.state.equipped_def("boots")
	safe_fall_bonus = float(boots.get("safe_fall_bonus", 0.0)) * store.state.effectiveness(store.state.slots.boots) if not boots.is_empty() else 0.0
	world.health_controller.safe_fall_speed = world.health_controller.SAFE_FALL_SPEED + safe_fall_bonus
	var face: Dictionary = store.state.equipped_def("face_cover")
	hazard_iframe_bonus = float(face.get("hazard_iframe_bonus", 0.0)) if not face.is_empty() else 0.0
	headset = store.state.equipped_def("headset")
	if not headset.is_empty() and store.state.effectiveness(store.state.slots.headset) > 0.0:
		hearing_range = float(headset.hearing_range)
		_setup_audio()
	else:
		headset = {}
	_build_hud(ui_parent)
	refresh_hud()

func _reduce(amount: float, source: String) -> float:
	var result: float = store.state.reduce_damage(amount, source)
	if result != amount: dirty = true
	return result

func _on_damaged(_amount: float, source: String, _current: float) -> void:
	if hazard_iframe_bonus > 0.0 and Defs.class_for_source(source) == "hazard":
		health.invulnerable_left += hazard_iframe_bonus
	refresh_hud()

## Q2: equipped gear is kept when downed and loses DOWNED_DURABILITY_LOSS of max.
func _on_died(_source: String) -> void:
	store.state.apply_downed()
	dirty = true
	save_now()
	refresh_hud()

func save_now() -> bool:
	if not dirty: return true
	if store.save():
		dirty = false
		return true
	push_warning("Gear locker save failed: " + store.last_error)
	return false

func _exit_tree() -> void:
	save_now()
	for v in voices:
		if is_instance_valid(v): v.stop()
	if bus_index >= 0 and bus_index < AudioServer.bus_count and AudioServer.get_bus_name(bus_index) == THREAT_BUS:
		AudioServer.remove_bus(bus_index)
	bus_index = -1

# -------------------------------------------------------------------- audio
func threat_range() -> float:
	return BASE_THREAT_RANGE * (1.0 + hearing_range)

func _setup_audio() -> void:
	for cue in THREAT_CUES:
		var path: String = THREAT_DIR + cue + ".wav"
		var stream = load(path) if ResourceLoader.exists(path) else AudioStreamWAV.load_from_file(path)
		if stream is AudioStream: streams[cue] = stream
		else: push_warning("Threat cue unavailable: " + cue)
	if AudioServer.get_bus_index(THREAT_BUS) < 0:
		AudioServer.add_bus()
		bus_index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus_index, THREAT_BUS)
		AudioServer.set_bus_send(bus_index, "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master")
	else:
		bus_index = AudioServer.get_bus_index(THREAT_BUS)
	var spec: Dictionary = COMPRESSION.get(str(headset.compression), {})
	if not spec.is_empty():
		var comp := AudioEffectCompressor.new()
		comp.threshold = spec.threshold; comp.ratio = spec.ratio; comp.gain = spec.gain
		comp.attack_us = 20.0; comp.release_ms = 180.0
		AudioServer.add_bus_effect(bus_index, comp)

func play_threat(cue: String, at: Vector3) -> bool:
	if headset.is_empty() or not streams.has(cue) or not is_instance_valid(world.player): return false
	var distance: float = world.player.global_position.distance_to(at)
	if distance > threat_range(): return false
	voices = voices.filter(func(v): return is_instance_valid(v) and v.playing)
	if voices.size() >= 6: voices.pop_front().queue_free()
	var voice := AudioStreamPlayer3D.new()
	voice.stream = streams[cue]
	voice.bus = THREAT_BUS
	voice.volume_db = THREAT_CUES[cue]
	voice.max_distance = threat_range()
	voice.unit_size = 4.0
	voice.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	add_child(voice)
	voice.global_position = at
	voice.finished.connect(voice.queue_free)
	if is_inside_tree() and AudioServer.get_bus_index(THREAT_BUS) >= 0: voice.play()
	voices.append(voice)
	events.append([cue, distance])
	return true

func _physics_process(delta: float) -> void:
	if world == null or headset.is_empty(): 
		_tick_hint(delta)
		return
	var hc = world.health_controller
	var active_now: bool = hc.combat_active()
	if is_instance_valid(hc.turret):
		var t = hc.turret
		if t.tracking and not turret_was_tracking and active_now:
			play_threat("turret_servo_whine", t.global_position)
			play_threat("turret_warmup_tone", t.global_position)
			if bool(headset.get("threat_direction_hint", false)): _show_hint(t.global_position)
		if t.shots > turret_shots and active_now: play_threat("turret_shot", t.global_position)
		turret_was_tracking = t.tracking
		turret_shots = t.shots
	if is_instance_valid(hc.hazard) and active_now:
		crackle_left -= delta
		if crackle_left <= 0.0:
			crackle_left = CRACKLE_INTERVAL
			play_threat("live_cable_crackle", hc.hazard.global_position)
	_tick_hint(delta)

func _show_hint(at: Vector3) -> void:
	var p: Node3D = world.player
	var to := at - p.global_position
	var forward := -p.global_transform.basis.z
	var right := p.global_transform.basis.x
	var f := Vector2(forward.x, forward.z).normalized().dot(Vector2(to.x, to.z).normalized())
	var r := Vector2(right.x, right.z).normalized().dot(Vector2(to.x, to.z).normalized())
	var side := "ahead" if f > 0.7 else ("behind" if f < -0.5 else ("right" if r > 0.0 else "left"))
	hint_label.text = "THREAT %s · turret warming up" % side.to_upper()
	hint_label.show()
	hint_left = HINT_SECONDS

func _tick_hint(delta: float) -> void:
	if hint_left > 0.0:
		hint_left -= delta
		if hint_left <= 0.0 and is_instance_valid(hint_label): hint_label.hide()

# ---------------------------------------------------------------------- HUD
func _build_hud(ui_parent: Control) -> void:
	hud = PanelContainer.new()
	hud.name = "GearHud"
	hud.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	hud.position = Vector2(24, -186)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.06, 0.1, 0.11, 0.72)
	back.set_corner_radius_all(6)
	back.content_margin_left = 12; back.content_margin_right = 12; back.content_margin_top = 6; back.content_margin_bottom = 6
	hud.add_theme_stylebox_override("panel", back)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(column)
	hud_label = Label.new()
	hud_label.name = "GearReadout"
	hud_label.add_theme_font_size_override("font_size", 14)
	hud_label.add_theme_color_override("font_color", Color("cfe3da"))
	column.add_child(hud_label)
	hint_label = Label.new()
	hint_label.name = "ThreatHint"
	hint_label.add_theme_font_size_override("font_size", 15)
	hint_label.add_theme_color_override("font_color", Color("f2a35c"))
	hint_label.hide()
	column.add_child(hint_label)
	ui_parent.add_child(hud)

func readout() -> Dictionary:
	var s = store.state
	var lowest_name := ""
	var lowest := 2.0
	var total := 0.0
	var ids: Array = s.equipped_ids()
	for id in ids:
		var def := Defs.item(s.owned[id].def)
		var frac := float(s.owned[id].durability) / float(def.durability)
		total += frac
		if frac < lowest: lowest = frac; lowest_name = def.name
	var summary: Dictionary = s.summary()
	var carried_kg := Storage.total_weight(s, haul_ref)
	return {"dr": summary.dr, "weight": carried_kg, "worn_weight": summary.weight, "load": load_kg, "band": Defs.weight_band(carried_kg),
		"durability": total / float(ids.size()) if ids.size() > 0 else 1.0,
		"lowest": lowest if ids.size() > 0 else 1.0, "lowest_name": lowest_name}

func refresh_hud() -> void:
	if not is_instance_valid(hud_label): return
	var r := readout()
	var line1 := "GEAR  Ballistic %d%% · Hazard %d%% · Fall %d%%" % [roundi(r.dr.ballistic * 100), roundi(r.dr.hazard * 100), roundi(r.dr.fall * 100)]
	var line2 := "Durability %d%%" % roundi(r.durability * 100)
	if r.lowest < 0.999: line2 += " · lowest %s %d%%" % [r.lowest_name, roundi(r.lowest * 100)]
	if r.lowest <= 0.0: line2 += " (BROKEN)"
	line2 += " · %.1f kg" % r.weight
	if r.load > 0.0: line2 += " (load %.1f)" % r.load
	if r.band.sprint < 1.0: line2 += " · sprint −%d%%" % roundi((1.0 - r.band.sprint) * 100)
	if not headset.is_empty(): line2 += " · %s" % headset.name
	var text := line1 + "\n" + line2
	# PR D: storage line when a rig or pack is worn.
	var c := Storage.capacity(store.state)
	if str(c.rig_condition) != "none" or str(c.pack_condition) != "none":
		text += "\nStorage %d units (%s)" % [int(c.total), Storage.breakdown(c)]
		if int(c.quick_slots) > 0: text += " · %d quick slot%s" % [int(c.quick_slots), "" if int(c.quick_slots) == 1 else "s"]
	hud_label.text = text
