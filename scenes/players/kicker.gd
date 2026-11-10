## Kicker: runs freely round the field; running into his own ball starts the kick. Systems lane owns
## the node, Gameplay the movement and the upgrade effects (docs/contracts.md "Kicker").
## jarling_kicker.tscn inherits kicker.tscn: Body holds the rigged Jarling (art/scripts/jarling_rig.gd)
## and set_character() makes it whoever the player picked (Roster, docs/roster.md), gear and all. Keep the node names and the API (docs/contracts.md "Kicker").
class_name Kicker
extends CharacterBody3D

## GAG (appended so the other values keep their numbers): a full-body wind-up gag before the kick.
enum State { IDLE, APPROACH, WINDUP, FOLLOW_THROUGH, CHEER, CHAIR, CLOUD, GAG }

signal state_changed(state: State)
signal kick_contact(run_up_quality: float)
signal hopped(player: int)
signal shouted(player: int)
signal gag_started(gag: StringName)
## Banana peel: he stepped on it (a few metres out), so the kick starts now, from here.
signal slipped()
## A foot comes down on the run (stride phase wraps). `hard` > 0 is a stomp (RunStyle.stomp).
signal footfall(hard: float)

const FROG_FALLBACK := preload("res://scenes/curses/frog.tscn")
const SLOTS: Array[StringName] = [&"head", &"feet", &"back", &"hands", &"body"]
const QUALITY_MIN := 0.8
const QUALITY_MAX := 1.2
## Full-body wind-up gags an upgrade's `windup_anim` can name. They change the approach, never the
## result: every one ends in exactly one kick_contact.
const GAGS: Array[StringName] = [&"slip", &"chase", &"waddle", &"trip", &"sneeze"]
## Whatever happens to a tween, the foot meets the ball by this many seconds into the wind-up.
const KICK_DEADLINE := 4.0
const SFX_DIR := "res://assets/audio/sfx/"
const GEAR_DIR := "res://assets/gear/"
## The sound a worn item makes on the kick: [cue, fallback cue, fallback pitch, at the wind-up instead].
const GEAR_CUES := {
	&"cannon_leg": ["cannon_boom", "kick_3", 0.7, false], &"honk_horn_shoes": ["honk", "card_move", 0.45, false],
	&"balloon_animal_ball": ["squeak", "hop", 2.0, false], &"rubber_chicken": ["squawk", "shout", 1.8, false],
	&"opera_kick": ["opera_la", "cheer", 0.6, true], &"coachs_whistle": ["whistle", "ui_confirm", 2.0, true],
}
## Slots for the grey-box kicker (no Jarling under Body): Jarling model space, +Y up, +Z front.
const GREYBOX_SLOTS := {
	&"head": Vector3(0, 0.78, 0), &"face": Vector3(0, 0.79, 0.25), &"back": Vector3(0, 0.52, -0.12),
	&"waist": Vector3(0, 0.29, 0), &"hand_l": Vector3(0.3, 0.33, 0), &"hand_r": Vector3(-0.3, 0.33, 0),
	&"knee_l": Vector3(0.09, 0.19, 0), &"knee_r": Vector3(-0.09, 0.19, 0),
	&"foot_l": Vector3(0.09, 0, 0), &"foot_r": Vector3(-0.09, 0, 0),
}
## Banana peel: lies this far before the ball on his way in; stepping within PEEL_STEP of it
## (or getting closer to the ball than the peel, from any side) slips him.
const PEEL_GAP := 3.6
const PEEL_STEP := 0.7
## Run-up quality looks at this many seconds before contact: roaming first costs nothing.
const RUNUP_WINDOW := 1.2
## K-08, a kick needs a short real run-up: over the last RUNUP_SHORT s he must have covered at least
## RUNUP_PACE x his top speed x RUNUP_SHORT metres, straight-line. Less (a stick wiggle at the ball,
## a nudge from standing) is a toe-poke: a quick tap, the lowest run-up quality, still a kick.
const RUNUP_SHORT := 0.6
const RUNUP_PACE := 0.45
## Colours of the running trails (run_fx).
const RUN_FX_COLOR := {
	&"flame": Color(1.0, 0.3, 0.05), &"wind": Color(0.8, 0.95, 1.0), &"sparkle": Color(1.0, 0.95, 0.5),
}

@export var player: int = Players.P1
## Which Roster character this kicker is. "" = whoever the player picked (Roster.pick(player)).
## jeff.tscn / chuck.tscn fix it for previews and tests; main.tscn leaves it to the pick.
@export var character_id := ""
@export_group("Free run")
@export var max_speed := 5.5
## Fractions of max_speed per second: speeding up, and stopping when the stick lets go.
@export var accel := 2.2
@export var decel := 4.0
## Pushing against the run brakes this much harder (turn-and-go).
@export var reverse_boost := 2.5
@export var turn_speed := 14.0
## The bystander runs about with all his gear too (playtest 2026-11-09 #2: at full speed).
@export var roam_speed := 1.0
## The field (XZ: x, z, width, depth), inside the fence. A soft wall pushes back over `wall_soft` m.
@export var bounds := Rect2(-5.7, -5.8, 13.6, 40.3)
@export var wall_soft := 1.2
@export_group("Moves")
@export var windup_time := 0.6
@export var hop_velocity := 4.5
@export var gravity := 16.0
@export var frog_hop_every := 0.45

var state: State = State.IDLE
var frog := false
## Tests (and bots) steer with this instead of a pad when it is a Vector2.
var stick_override: Variant = null
## This kick's gag source (main.gd: the round's curse, else the newest upgrade with a windup_anim).
var windup: UpgradeData = null
## This kick's gear effects (Run.effects_of). Empty = plain kicker.
var effects: Dictionary = {}
## Demo: wanders off for a bit, then runs at the ball.
var bot := false
## A waiting player (CHEER) moves with the stick when this is on.
var roam := false

var _ball := Vector3.ZERO
var _start := Vector3.ZERO
var _time := 0.0
var _hist: Array[Vector4] = []   # (x, z, time, hopped) over the last RUNUP_WINDOW s
var _hopped_t := -10.0
var _fx_t := 0.0
var _bot_goals: Array[Vector3] = []
var _bot_t := 0.0
var _rest_scale := Vector3.ONE
var _slipping := false
var _wander_goal := Vector3.ZERO
var _wander_t := 0.0
## Worn gear (docs/contracts.md "Worn gear"): one item per slot, swap or level up, never a stack.
var equipment: JarlingEquipment
var _worn := {}   # prop key (UpgradeData.slot, or the id for slot none) -> piece
var _gear_slot := {}   # UpgradeData.slot -> id of the gear worn for it
var _fx_nodes: Array[Node] = []
var _quiet := false
static var _gear_cache := {}
var _phase := 0.0
var _frog_timer := 0.0
var _anim_t := 0.0
var _tween: Tween
var _gag := &""
var _windup_t := 0.0
var _kicked := false
var _prop: Node3D
var _dancing := false
var _rng := RandomNumberGenerator.new()
## How this character runs (RunStyle.for_character): bob, stomp, arms, costume. P-03 / P-04.
var run_style: RunStyle = RunStyle.for_character("")
## The run right now, for the rig's arms: 0..1 of top speed, and the stride phase (1 = one step).
var run_amount := 0.0
var stride := 0.0
## This kick is a toe-poke (no real run-up, K-08): set in start_windup, read by the rig.
var poking := false
var _land_t := 10.0

@onready var body: Node3D = $Body
@onready var accent: MeshInstance3D = $Body/Accent
@onready var attach: Node3D = $Attach
@onready var frog_slot: Node3D = $FrogSlot
@onready var helmet: Node3D = $Body/Helmet


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	_rng.randomize()
	_phase = _rng.randf() * TAU
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Players.COLOR[player]
	accent.material_override = mat
	helmet.visible = false
	if body.has_node("Jarling"):
		var id := character_id if character_id != "" else Roster.pick(player)
		character_id = ""
		for c in [id, Roster.default_for(player)] + Roster.roster():
			if set_character(c):
				break
	if body.find_child("slot_head", true, false) == null:
		var slots := Node3D.new()
		slots.name = "Slots"
		slots.transform = Transform3D(Basis.from_scale(Vector3(-1.3, 1.3, -1.3)), Vector3.ZERO)
		body.add_child(slots)
		for s: StringName in GREYBOX_SLOTS:
			var m := Marker3D.new()
			m.name = "slot_%s" % s
			m.position = GREYBOX_SLOTS[s]
			slots.add_child(m)
	_make_equipment()
	kick_contact.connect(func(_q: float) -> void: _gear_cue(false))
	state_changed.connect(func(s: State) -> void:
		if s == State.WINDUP:
			_gear_cue(true))


func _make_equipment() -> void:
	equipment = JarlingEquipment.new()
	equipment.name = "Equipment"
	equipment.jarling = body
	add_child(equipment)
	equipment.poof.connect(_on_gear_poof)
	equipment.item_equipped.connect(_on_gear_equipped)
	equipment.item_unequipped.connect(func(_s: StringName, _i: JarlingGear) -> void: _find_gear_fx())
	equipment.item_leveled_up.connect(func(_s: StringName, _i: JarlingGear, _l: int) -> void:
		if not _quiet:
			Audio.play("upgrade_on", null, 1.3))


## Become Roster character `id` (its vendored Jarling .glb) in place: same rig, collision, state,
## frog form and actions, and the gear worn now moves onto the new body at the same levels.
## False (and nothing changes) for an unknown id or a missing .glb.
func set_character(id: String) -> bool:
	var who := Roster.info(id)
	var rig := body.get_node_or_null("Jarling")
	if who.is_empty() or not ResourceLoader.exists(str(who.glb)) or rig == null or not rig.has_method("set_model"):
		return false
	if id == character_id:
		return true
	var worn: Array[Vector2i] = []   # (index into ids, level)
	var ids: Array[StringName] = []
	var had := equipment != null
	if had:
		for gid: StringName in _gear_slot.values():
			if equipment.has_item(gid):
				var item: JarlingGear = _gear_cache[String(gid)]
				ids.append(gid)
				worn.append(Vector2i(ids.size() - 1, equipment.level(item.slots[0])))
		_quiet = true
		equipment.unequip_all()
		remove_child(equipment)
		equipment.free()
		equipment = null
	rig.set_model(load(str(who.glb)) as PackedScene, id + "_hat")
	character_id = id
	run_style = RunStyle.for_character(id)
	if not had:
		return true
	_make_equipment()
	for w in worn:
		var item: JarlingGear = _gear_cache[String(ids[w.x])]
		equipment.equip(item)
		for i in w.y - 1:
			equipment.level_up(item.slots[0])
	_quiet = false
	_find_gear_fx()
	return true


## The display name of who this kicker is ("Jeff"), or "Player 1" with no Roster character.
func character_name() -> String:
	var who := Roster.info(character_id)
	return str(who.name) if not who.is_empty() else "Player %d" % (player + 1)


## A character's own voice for `base` ("windup_<id>", when the Audio lane has recorded it), else the
## generic `base` cue. Never another character's voice.
static func voice_cue(base: String, id: String) -> String:
	var own := "%s_%s" % [base, id]
	if id != "" and (ResourceLoader.exists(SFX_DIR + own + ".ogg") or ResourceLoader.exists(SFX_DIR + own + "_1.ogg")):
		return own
	return base


func _physics_process(delta: float) -> void:
	_anim_t += delta
	if state == State.CLOUD:
		velocity = Vector3.ZERO
	elif not is_on_floor():
		velocity.y -= gravity * _fx(&"gravity_mult") * delta
	if state == State.APPROACH:
		_approach(delta, 1.0)
	elif state == State.CHEER and roam and not _dancing:
		_approach(delta, roam_speed)
	else:
		var hv := Vector3(velocity.x, 0.0, velocity.z).move_toward(Vector3.ZERO, 20.0 * delta)
		velocity.x = hv.x
		velocity.z = hv.z
	if state == State.GAG or state == State.WINDUP:
		_windup_t += delta
		if _windup_t > KICK_DEADLINE and not _kicked:
			_kill_tween()
			_contact(_quality_now())
			_end_follow_through()
	_buttons()
	_idle_anim()
	_gear_fx(delta)
	if state != State.CLOUD:
		move_and_slide()
		if state == State.APPROACH or (state == State.CHEER and roam):
			_keep_in_bounds()


# --- API ---------------------------------------------------------------------

func begin_approach(ball_position: Vector3) -> void:
	_kill_tween()
	_ball = ball_position
	_start = global_position
	_time = 0.0
	_hist.clear()
	_hopped_t = -10.0
	_bot_goals.clear()
	_bot_t = 0.0
	_slipping = false
	if bot:
		# Demo: one swerve on the way in, so the free run (and the gear on it) shows.
		var mid := global_position.lerp(ball_position, _rng.randf_range(0.35, 0.6))
		mid.x = _rng.randf_range(bounds.position.x + 1.5, bounds.end.x - 1.5)
		_bot_goals.append(Vector3(mid.x, 0.0, mid.z))
	roam = false
	_dancing = false
	_gag = &""
	velocity = Vector3.ZERO
	body.rotation = Vector3.ZERO
	body.position = Vector3.ZERO
	apply_effects(effects)
	_face(_ball - global_position, 1.0)
	_spawn_prop()
	_set_state(State.APPROACH)
	Audio.play("frog" if frog else voice_cue("windup", character_id))


func start_windup() -> void:
	if state != State.APPROACH:
		return
	var quality := _quality_now()
	var gag := gag_of(windup)
	poking = not frog and gag == &"" and not has_run_up()
	if poking:
		quality = QUALITY_MIN
	velocity = Vector3(0.0, velocity.y, 0.0)
	_face(_ball - global_position, 1.0)
	_windup_t = 0.0
	_kicked = false
	_kill_tween()
	_tween = create_tween()
	if frog:
		_set_state(State.WINDUP)
		Audio.play("windup", null, 1.3)
		# The frog "kick" is a flop and a tongue-boop.
		_tween.tween_property(frog_slot, "scale", Vector3(1.4, 0.5, 1.4), 0.25)
		_tween.tween_callback(Audio.play.bind("frog"))
		_tween.tween_callback(_tongue_boop)
		_tween.tween_property(frog_slot, "scale", Vector3.ONE, 0.2)
	elif gag != &"":
		_gag = gag
		_set_state(State.GAG)
		gag_started.emit(gag)
		call("_gag_" + String(gag), _tween)
	elif poking:
		# No run-up (K-08): a quick, surprised toe-poke instead of the lunatic wind-up.
		_set_state(State.WINDUP)
		Audio.play("squeak", null, 1.5)
		_toe_poke(_tween)
	else:
		_set_state(State.WINDUP)
		Audio.play("windup", null, 1.3)
		var style: StringName = effects.get(&"kick_style", &"normal")
		if has_method("_style_" + String(style)):
			call("_style_" + String(style), _tween)
		else:
			_kick_moves(_tween, 1.0)
	_tween.tween_callback(_contact.bind(quality))
	if gag == &"slip" or gag == &"trip":
		# Lie there a beat, then scramble back up.
		_tween.tween_interval(0.45)
		_tween.tween_property(body, "rotation", Vector3.ZERO, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tween.parallel().tween_property(body, "position", Vector3.ZERO, 0.3)
	else:
		_tween.tween_interval(0.5)
	_tween.tween_callback(_end_follow_through)


## K-08: did he cover a real (short) run-up just now? Straight-line distance over the last RUNUP_SHORT
## s against RUNUP_PACE of his top speed. A wiggle at the ball or a nudge from standing is not one.
func has_run_up() -> bool:
	if _hist.size() < 2:
		return false
	var last := _hist[-1]
	var i := _hist.size() - 1
	while i > 0 and _hist[i - 1].z >= last.z - RUNUP_SHORT:
		i -= 1
	var first := _hist[i]
	if last.z - first.z < RUNUP_SHORT - 0.05:
		return false   # not running that long yet
	var top := max_speed * _fx(&"run_speed_mult")
	if gag_of(windup) == &"waddle":
		top *= 0.7
	var gone := Vector2(last.x - first.x, last.y - first.y).length()
	return gone >= RUNUP_PACE * top * RUNUP_SHORT


## The upgrade's gag, if it names one this kicker knows.
static func gag_of(upgrade: UpgradeData) -> StringName:
	if upgrade == null or not GAGS.has(upgrade.windup_anim):
		return &""
	return upgrade.windup_anim


func set_waiting(chair: bool) -> void:
	_kill_tween()
	roam = false
	_clear_prop()
	_dancing = false
	_gag = &""
	body.rotation = Vector3.ZERO
	_set_state(State.CHAIR if chair else State.CHEER)


## Standing still on the spot (the lobby): idle animation, no roaming.
func set_idle() -> void:
	set_waiting(false)
	_set_state(State.IDLE)


func set_cloud() -> void:
	_kill_tween()
	_clear_prop()
	_gag = &""
	body.rotation = Vector3.ZERO
	velocity = Vector3.ZERO
	_set_state(State.CLOUD)


func cheer() -> void:
	Audio.play("cheer")
	_hop(0.8)
	Fx.puff(global_position + Vector3.UP * 2.2, Color(1, 0.95, 0.6), 0.5)
	shouted.emit(player)


func set_frog(on: bool, override: PackedScene = null) -> void:
	if on == frog and (not on or frog_slot.get_child_count() > 0):
		return
	var was_frog := frog
	frog = on
	for c in frog_slot.get_children():
		c.queue_free()
	if was_frog and not on and is_inside_tree():
		# Poof! Back to himself, gear and all.
		Fx.puff(global_position + Vector3.UP * 0.4, Color(0.75, 1.0, 0.6), 0.9)
		Fx.pop(body, 1.35)
		_sfx("poof", "upgrade_on", 0.8)
	body.visible = not on
	attach.visible = not on   # upgrades are gone for the frog round, back next round
	if on:
		var f := (override if override else FROG_FALLBACK).instantiate()
		frog_slot.add_child(f)
		var skin := f.find_child("Skin", true, false) as MeshInstance3D
		if skin:
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Players.COLOR[player].lerp(Color(0.5, 0.8, 0.3), 0.35)
			skin.material_override = mat
		Fx.puff(global_position + Vector3.UP * 0.5, Color(0.6, 0.9, 0.4), 1.5)
		Audio.play("frog")


func set_space_suit(on: bool) -> void:
	helmet.visible = on


## End card: cheering, plus a side-to-side boogie and a spin every few seconds.
func dance(on: bool) -> void:
	_dancing = on
	if on and state != State.CLOUD:
		_set_state(State.CHEER)


func attach_point(slot: StringName) -> Node3D:
	var n := attach.get_node_or_null(NodePath(String(slot).capitalize()))
	return n if n else attach.get_node("Body")


## The gear item of a wearable card (assets/gear/<id>.json), or null (curses, ball cards, no art yet).
static func gear_for(upgrade: UpgradeData) -> JarlingGear:
	if upgrade == null or upgrade.slot == "none" or upgrade.slot == "ball":
		return null
	var id := String(upgrade.id)
	if not _gear_cache.has(id):
		var path := GEAR_DIR + id + ".json"
		_gear_cache[id] = JarlingGear.load_json(path) if FileAccess.file_exists(path) else null
	return _gear_cache[id]


## One item per body slot (UpgradeData.slot): gear is worn through `equipment`, which swaps a filled
## slot and levels up a repeat, so nothing stacks. Its power stays (Run).
func add_upgrade_visual(upgrade: UpgradeData) -> void:
	var gear := gear_for(upgrade)
	if gear:
		# One card slot is one item, even when the two pieces sit on different body slots.
		var old: StringName = _gear_slot.get(upgrade.slot, &"")
		var swap := old != &"" and old != gear.id and equipment.has_item(old)
		if swap:
			_quiet = true
			equipment.unequip(_gear_cache[String(old)].slots[0])
			_quiet = false
		_gear_slot[upgrade.slot] = gear.id
		equipment.equip(gear)
		if swap:
			_sfx("poof", "upgrade_on", 0.8)
		return
	var key := upgrade.slot if upgrade.slot != "none" else String(upgrade.id)
	var old_piece: Node3D = _worn.get(key)
	if is_instance_valid(old_piece):
		_worn.erase(key)
		old_piece.get_parent().remove_child(old_piece)
		add_child(old_piece)
		old_piece.top_level = true
		var fly := old_piece.create_tween()
		var to := global_position + Vector3(_rng.randf_range(-1.5, 1.5), 2.5, _rng.randf_range(0.5, 1.5))
		fly.tween_property(old_piece, "global_position", to, 0.4).set_ease(Tween.EASE_OUT)
		fly.parallel().tween_property(old_piece, "scale", Vector3.ONE * 0.01, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		fly.tween_callback(old_piece.queue_free)
		Fx.puff(to, Color.WHITE, 0.6)
	var piece: Node3D
	var slot: StringName = &"head"
	if upgrade.visual:
		piece = upgrade.visual.instantiate()
		slot = piece.get_meta(&"attach_point", &"body")
	else:
		piece = _placeholder_piece(upgrade)
	attach_point(slot).add_child(piece)
	_worn[key] = piece
	piece.scale = Vector3.ONE * 0.01
	var tw := piece.create_tween()
	tw.tween_property(piece, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Audio.play("upgrade_on")
	Fx.puff(piece.global_position, _icon_color(upgrade), 0.8)
	Fx.pop(body, 1.25)


## What is worn for a card slot (UpgradeData.slot), or null.
func worn_piece(slot: String) -> Node3D:
	var id: StringName = _gear_slot.get(slot, &"")
	if id != &"" and equipment.has_item(id):
		var item: JarlingGear = _gear_cache[String(id)]
		return equipment.slot_node(item.slots[0]).get_node_or_null("gear_%s" % id) as Node3D
	var n: Node3D = _worn.get(slot)
	return n if is_instance_valid(n) else null


func clear_upgrade_visuals() -> void:
	_worn.clear()
	_gear_slot.clear()
	_quiet = true
	equipment.unequip_all()
	_quiet = false
	apply_effects({})
	for slot in SLOTS:
		for c in attach_point(slot).get_children():
			c.queue_free()


func _on_gear_poof(_slot: StringName, at: Vector3) -> void:
	if _quiet or not is_inside_tree():
		return
	Audio.play("upgrade_on")
	Fx.puff(at, Color.WHITE, 0.8)
	Fx.pop(body, 1.25)


## A soft rim on the gear, like the Jarling's own materials, and its effect hooks.
func _on_gear_equipped(slot: StringName, _item: JarlingGear) -> void:
	for n in equipment.slot_node(slot).find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(s) as StandardMaterial3D
			if mat and not mat.rim_enabled:
				mat.rim_enabled = true
				mat.rim = 0.5
				mat.rim_tint = 0.35
	_find_gear_fx()


func _find_gear_fx() -> void:
	_fx_nodes = body.find_children("fx_*", "Node3D", true, false)


## Effect hooks in the gear: flames burn while running or kicking, propellers and fans turn.
func _gear_fx(delta: float) -> void:
	if _fx_nodes.is_empty():
		return
	var busy := state == State.WINDUP or state == State.GAG or state == State.FOLLOW_THROUGH \
			or Vector2(velocity.x, velocity.z).length() > 1.0
	for n: Node3D in _fx_nodes:
		if not is_instance_valid(n) or n.is_queued_for_deletion():
			continue
		var nm := String(n.name)
		if nm.begins_with("fx_flame"):
			n.visible = busy
			n.scale = Vector3.ONE * (0.85 + 0.3 * absf(sin(_anim_t * 31.0 + n.get_index() * 1.7)))
		elif nm.begins_with("fx_spin"):
			n.rotate_object_local(Vector3.UP, (16.0 if busy else 3.0) * delta)
		elif nm.begins_with("fx_orbit"):
			n.rotate_object_local(Vector3.UP, 1.6 * delta)


func _gear_cue(at_windup: bool) -> void:
	if frog:
		return
	for id: StringName in GEAR_CUES:
		var cue: Array = GEAR_CUES[id]
		if cue[3] == at_windup and equipment.has_item(id):
			_sfx(cue[0], cue[1], cue[2])


## 0.8 (wobbly, slow) to 1.2 (straight, fast, with a hop). Never stops a kick.
static func run_up_quality(path_length: float, straight_distance: float,
		avg_speed: float, max_speed_: float, did_hop: bool) -> float:
	var straight := 0.0
	var fast := 0.0
	if path_length > 0.01:
		straight = clampf(remap(straight_distance / path_length, 0.6, 0.97, 0.0, 1.0), 0.0, 1.0)
	if max_speed_ > 0.0:
		fast = clampf(remap(avg_speed / max_speed_, 0.3, 0.8, 0.0, 1.0), 0.0, 1.0)
	var q := 0.8 + 0.37 * (0.5 * straight + 0.5 * fast) + (0.03 if did_hop else 0.0)
	return clampf(q, 0.8, 1.2)


# --- internals -----------------------------------------------------------------

func _approach(delta: float, speed_scale: float) -> void:
	_time += delta
	var stick := _stick_world()
	if bot and stick_override == null:
		stick = _bot_stick(delta) if state == State.APPROACH else _wander_stick(delta)
	var hv := Vector3(velocity.x, 0.0, velocity.z)
	var top := max_speed * _fx(&"run_speed_mult") * speed_scale
	if gag_of(windup) == &"waddle":
		top *= 0.7
	if frog:
		_frog_timer -= delta
		if is_on_floor() and stick.length() > 0.2 and _frog_timer <= 0.0:
			_frog_timer = frog_hop_every
			hv = stick.normalized() * max_speed * 0.7
			velocity.y = hop_velocity * 0.7
			Audio.play("frog", null, 1.2)
		elif is_on_floor():
			hv = hv.move_toward(Vector3.ZERO, 30.0 * delta)
	else:
		# Where the stick points, nothing else: no pull toward the ball, no drift with no input.
		var rate := decel
		if stick.length() > 0.1:
			rate = accel * _fx(&"accel_mult")
			if hv.length() > 0.5 and hv.normalized().dot(stick.normalized()) < -0.2:
				rate *= reverse_boost
		hv = hv.move_toward(stick * top, rate * max_speed * delta)
	hv = _soft_wall(hv, delta)
	velocity.x = hv.x
	velocity.z = hv.z
	if stick.length() > 0.2:
		_face(stick, turn_speed * delta)   # turns on the spot, even from standing
	elif hv.length() > 0.3:
		_face(hv, 8.0 * delta)
	if state == State.APPROACH:
		_hist.append(Vector4(global_position.x, global_position.z, _time, 0.0))
		while _hist.size() > 2 and _hist[0].z < _time - RUNUP_WINDOW:
			_hist.pop_front()
		_check_peel()
	_run_fx(delta, hv.length() / maxf(top, 0.01))


## Banana peel: on it (or past it from another side, and then it zips under his foot): slip.
func _check_peel() -> void:
	if _slipping or gag_of(windup) != &"slip" or not is_instance_valid(_prop) or frog:
		return
	var to_peel := _flat(_prop.global_position - global_position).length()
	if to_peel > PEEL_STEP and _flat(_ball - global_position).length() > PEEL_GAP - 0.4:
		return
	_slipping = true
	if to_peel > PEEL_STEP:
		_prop.global_position = Vector3(global_position.x, _prop.global_position.y, global_position.z)
	slipped.emit()


## A slip has started (or the peel is still waiting for him).
func is_slipping() -> bool:
	return _slipping


## Past the soft edge the field pushes back, harder the further out; nothing gets through.
func _soft_wall(hv: Vector3, delta: float) -> Vector3:
	var p := Vector2(global_position.x, global_position.z)
	var inner := bounds.grow(-wall_soft)
	var push := Vector2(
		(inner.position.x - p.x) if p.x < inner.position.x else (inner.end.x - p.x if p.x > inner.end.x else 0.0),
		(inner.position.y - p.y) if p.y < inner.position.y else (inner.end.y - p.y if p.y > inner.end.y else 0.0))
	if push == Vector2.ZERO:
		return hv
	var out := -push.normalized()
	var v := Vector2(hv.x, hv.z)
	var outward := v.dot(out)
	var depth := clampf(push.length() / wall_soft, 0.0, 1.0)
	if outward > 0.0:
		v -= out * outward * clampf(depth * 12.0 * delta + depth * depth, 0.0, 1.0)
	v -= out * depth * 6.0 * delta * max_speed
	return Vector3(v.x, 0.0, v.y)


func _keep_in_bounds() -> void:
	var p := global_position
	p.x = clampf(p.x, bounds.position.x, bounds.end.x)
	p.z = clampf(p.z, bounds.position.y, bounds.end.y)
	global_position = p


## Demo bot: each wander goal in turn, then straight at the ball.
func _bot_stick(delta: float) -> Vector3:
	_bot_t += delta
	while not _bot_goals.is_empty() and (_flat(_bot_goals[0] - global_position).length() < 0.9 or _bot_t > 3.0):
		_bot_goals.pop_front()
		_bot_t = 0.0
	var goal := _bot_goals[0] if not _bot_goals.is_empty() else _ball
	var d := _flat(goal - global_position)
	return d.normalized() if d.length() > 0.05 else Vector3.ZERO


## Demo bystander: jogs between random spots near his tee and hops now and then, gear showing.
func _wander_stick(delta: float) -> Vector3:
	_wander_t -= delta
	if _wander_t <= 0.0 or _flat(_wander_goal - global_position).length() < 0.8:
		_wander_t = _rng.randf_range(1.5, 3.0)
		_wander_goal = Vector3(_rng.randf_range(bounds.position.x + 1.5, bounds.end.x - 1.5), 0.0,
				_rng.randf_range(bounds.position.y + 1.5, minf(bounds.position.y + 16.0, bounds.end.y - 1.5)))
		if _rng.randf() < 0.5:
			_hop(1.0)
	var d := _flat(_wander_goal - global_position)
	return d.normalized() if d.length() > 0.05 else Vector3.ZERO


## The gear while running: flame, wind and sparkle trails, honks, squeaks and the spring-shoe boing.
func _run_fx(delta: float, speed01: float) -> void:
	var kinds: Array = effects.get(&"run_fx", [])
	if kinds.is_empty() or frog or speed01 < 0.35:
		return
	_fx_t -= delta
	var feet := global_position + Vector3.UP * 0.15 - global_basis.z * -0.35
	for k: StringName in kinds:
		if k == &"bounce" and is_on_floor() and velocity.y <= 0.0:
			# Spring shoes: every step is a little boing.
			velocity.y = hop_velocity * 0.5 * _fx(&"jump_mult")
			Audio.play("hop", null, 1.5 + _rng.randf() * 0.2)
			Fx.pop(body, 1.15)
	if _fx_t > 0.0:
		return
	_fx_t = 0.07
	for k: StringName in kinds:
		match k:
			&"flame", &"wind", &"sparkle":
				var c: Color = RUN_FX_COLOR[k]
				if k == &"flame" and _rng.randf() < 0.4:
					c = Color(1.0, 0.75, 0.1)   # yellow tongues in the red
				Fx.puff(feet + Vector3(_rng.randf_range(-0.1, 0.1), 0.0, _rng.randf_range(-0.1, 0.1)),
						c, 0.35 if k == &"flame" else 0.25)
				if k == &"flame" and _rng.randf() < 0.12:
					Audio.play("whoosh", null, 0.6)
			&"honk":
				if _rng.randf() < 0.35:
					Audio.play("honk", null, 0.9 + _rng.randf() * 0.3)
			&"squeak":
				if _rng.randf() < 0.3:
					Audio.play("squeak", null, 1.0 + _rng.randf() * 0.3)


## Takes this kick's gear effects: bulk shows at once, the rest is read while running and kicking.
func apply_effects(fx: Dictionary) -> void:
	effects = fx
	var bulk: float = fx.get(&"bulk", 1.0)
	_rest_scale = Vector3(bulk, lerpf(1.0, bulk, 0.5), bulk)
	if is_node_ready():
		body.scale = _rest_scale
		body.set_meta(&"fx_base_scale", _rest_scale)


func _fx(key: StringName) -> float:
	return float(effects.get(key, 1.0))


func _contact(quality: float) -> void:
	if _kicked:
		return
	_kicked = true
	_set_state(State.FOLLOW_THROUGH)
	Fx.puff(global_position + Vector3.UP * 0.3, Color(0.85, 0.75, 0.6), 0.5 if frog else 1.2)
	kick_contact.emit(quality)


func _end_follow_through() -> void:
	body.rotation = Vector3.ZERO
	body.position = Vector3.ZERO
	frog_slot.scale = Vector3.ONE
	_gag = &""
	if state == State.FOLLOW_THROUGH:
		_set_state(State.IDLE)


func _buttons() -> void:
	if Game.state != Game.State.PLAYING or not _reads_input() or state == State.CHAIR:
		return
	if Input.is_action_just_pressed(Players.action(player, "jump")) and state != State.WINDUP and state != State.GAG:
		if _hop(1.0):
			if state == State.APPROACH:
				_hopped_t = _time
			Audio.play("hop")
			hopped.emit(player)
	if Input.is_action_just_pressed(Players.action(player, "action")):
		if state == State.APPROACH or state == State.WINDUP or state == State.GAG:
			Audio.play("shout")
			_hop(0.5)
			Fx.puff(global_position + Vector3.UP * 2.0, Players.COLOR[player].lightened(0.5), 0.4)
			shouted.emit(player)
		else:
			cheer()


func _hop(strength: float) -> bool:
	if state == State.CLOUD:
		var tw := create_tween()
		tw.tween_property(body, "position:y", 0.5 * strength, 0.12).as_relative()
		tw.tween_property(body, "position:y", -0.5 * strength, 0.18).as_relative()
		return true
	if not is_on_floor():
		return false
	velocity.y = hop_velocity * strength * _fx(&"jump_mult")
	Fx.pop(body, 1.2)
	return true


func _idle_anim() -> void:
	run_amount = 0.0
	if _gag != &"" and state != State.APPROACH:
		return   # the gag tween owns Body
	if _dancing and (state == State.CHEER or state == State.CLOUD):
		body.position.y = absf(sin(_anim_t * 6.0 + _phase)) * 0.18
		body.rotation.z = sin(_anim_t * 6.0 + _phase) * 0.3
		# A full spin every 3 s, the rest of the time a wiggle.
		var beat := fmod(_anim_t + _phase, 3.0)
		body.rotation.y = TAU * smoothstep(2.4, 3.0, beat) + sin(_anim_t * 3.0) * 0.35
		return
	match state:
		State.CHEER, State.IDLE when not (state == State.CHEER and roam):
			body.position.y = absf(sin(_anim_t * 5.0 + _phase)) * 0.08
		State.CHAIR:
			body.position.y = -0.45 + sin(_anim_t * 1.5) * 0.02
		State.APPROACH when gag_of(windup) == &"waddle":
			# Too much lunch: a slow, wide side-to-side waddle.
			body.position.y = absf(sin(_anim_t * 7.0)) * 0.05
			body.rotation.z = sin(_anim_t * 7.0) * 0.38
		State.APPROACH, State.CHEER when state == State.APPROACH or roam:
			_run_anim(clampf(Vector2(velocity.x, velocity.z).length() / max_speed, 0.0, 1.0))
			return
		_:
			body.position.y = 0.0


## The character's own run (RunStyle): Jeff's loose bob and sway, Chuck's lift-and-stomp.
func _run_anim(run: float) -> void:
	var st := run_style
	var dt := get_physics_process_delta_time()
	run_amount = run
	if run < 0.15:
		body.position.y = absf(sin(_anim_t * 5.0 + _phase)) * 0.06
		body.rotation.z = lerpf(body.rotation.z, 0.0, 0.2)
		body.rotation.x = lerpf(body.rotation.x, 0.0, 0.2)
		_land_squash(dt)
		return
	var before := stride
	stride += dt * st.cadence * lerpf(0.55, 1.0, run)
	body.position.y = st.lift(stride, run)
	# The roll goes one way per step, the other way the next.
	body.rotation.z = sin(stride * PI + _phase) * st.sway * run
	body.rotation.x = lerpf(body.rotation.x, -st.lean * run, 0.2)
	if floori(stride) != floori(before) and is_on_floor():
		_on_footfall(run)
	_land_squash(dt)


func _on_footfall(run: float) -> void:
	var hard := run_style.stomp * run
	footfall.emit(hard)
	if hard < 0.3:
		return
	_land_t = 0.0
	# Stomp: a thud and a dust puff under the heel, every step.
	Audio.play("land", null, 0.65 + _rng.randf() * 0.1)
	Fx.puff(global_position + Vector3.UP * 0.05, Color(0.8, 0.72, 0.55), 0.1 + 0.06 * hard)


## A short, hard landing: the body squashes for a few frames after each stomp.
func _land_squash(dt: float) -> void:
	var rig := body.get_node_or_null("Jarling") as Node3D
	if rig == null:
		return
	_land_t += dt
	var k := clampf(1.0 - _land_t / 0.12, 0.0, 1.0) * run_style.land_squash
	rig.scale = Vector3(1.0 + k * 0.6, 1.0 - k, 1.0 + k * 0.6)


func _reads_input() -> bool:
	return player == Players.P1 or Players.is_active(player)


func _stick_world() -> Vector3:
	if stick_override == null and not _reads_input():
		return Vector3.ZERO
	var mv: Vector2 = stick_override if stick_override is Vector2 else Players.move_vector(player)
	var cam := get_viewport().get_camera_3d()
	if cam == null or mv.length() < 0.01:
		return Vector3.ZERO
	var right := _flat(cam.global_basis.x).normalized()
	var fwd := _flat(-cam.global_basis.z).normalized()
	var out := right * mv.x - fwd * mv.y
	return out.limit_length(1.0)


func _face(dir: Vector3, weight: float) -> void:
	var d := _flat(dir)
	if d.length() < 0.01:
		return
	var target := atan2(-d.x, -d.z)
	rotation.y = lerp_angle(rotation.y, target, clampf(weight, 0.0, 1.0))


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


func _icon_color(upgrade: UpgradeData) -> Color:
	var tex := upgrade.icon as GradientTexture2D
	return tex.gradient.get_color(0) if tex and tex.gradient else Color.WHITE


func _placeholder_piece(upgrade: UpgradeData) -> Node3D:
	var m := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.28, 0.14, 0.28)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = _icon_color(upgrade)
	box.material = mat
	m.mesh = box
	m.name = String(upgrade.id)
	return m


func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = null
	if is_node_ready():
		body.scale = _rest_scale
		body.position = Vector3.ZERO
		frog_slot.scale = Vector3.ONE


func _set_state(to: State) -> void:
	if to == state:
		return
	state = to
	_land_t = 10.0
	var rig := body.get_node_or_null("Jarling") as Node3D if is_node_ready() else null
	if rig:
		rig.scale = Vector3.ONE
	state_changed.emit(to)


# --- wind-up gags ----------------------------------------------------------------
# Each adds its moves to `tw`; start_windup() appends the kick_contact. Body faces -Z.
# rotation.x > 0 leans back, < 0 pitches forward; the pivot is at the feet.

## The normal lunatic kick: lean, two spins into the ball. `speed` < 1 is quicker.
func _kick_moves(tw: Tween, speed: float) -> void:
	var t := windup_time * speed
	tw.tween_property(body, "rotation:x", -0.5, t * 0.4).set_ease(Tween.EASE_OUT)
	tw.tween_property(body, "rotation:y", TAU * 2.0, t * 0.6).as_relative().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(body, "rotation:x", 0.35, t * 0.6)


## K-08, no run-up: a startled little toe-poke. Up on one leg, a tap, a wobble.
func _toe_poke(tw: Tween) -> void:
	tw.tween_property(body, "rotation:x", 0.25, 0.12).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(body, "position:y", 0.12, 0.12).set_ease(Tween.EASE_OUT)
	tw.tween_property(body, "rotation:x", -0.2, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(body, "position:y", 0.0, 0.1)


# --- kick styles (UpgradeData.kick_style): the gear shows in the kick itself ---------------

## Super Strength, Big Boot: up on tiptoe, then a stomp-kick that thumps the ground.
func _style_stomp(tw: Tween) -> void:
	tw.tween_property(body, "position:y", 0.7, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(body, "rotation:x", 0.45, 0.3)
	tw.tween_interval(0.12)
	tw.tween_property(body, "position:y", 0.0, 0.1).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(body, "rotation:x", -0.5, 0.1)
	tw.tween_callback(func() -> void:
		Audio.play("land", null, 0.5)
		Fx.puff(global_position + Vector3.UP * 0.1, Color(0.85, 0.75, 0.6), 2.2)
		Fx.pop(body, 1.35))


## Cannon Leg: lean back, a fizzing fuse, BOOM, and the kick knocks him back a step.
func _style_cannon(tw: Tween) -> void:
	tw.tween_property(body, "rotation:x", 0.5, 0.3).set_ease(Tween.EASE_OUT)
	for i in 3:
		tw.tween_callback(Fx.puff.bind(global_position + Vector3.UP * 0.5 - global_basis.z * -0.3, Color(1.0, 0.8, 0.3), 0.25))
		tw.tween_callback(Audio.play.bind("hop", null, 2.0 + i * 0.2))
		tw.tween_interval(0.15)
	tw.tween_property(body, "rotation:x", -0.55, 0.07)
	tw.tween_callback(func() -> void:
		_sfx("cannon_boom", "kick_4", 0.6)
		Fx.puff(global_position + Vector3.UP * 0.4 + global_basis.z * -0.7, Color(0.55, 0.55, 0.58), 2.4)
		Fx.puff(global_position + Vector3.UP * 0.4 + global_basis.z * -0.7, Color(1.0, 0.7, 0.25), 1.2))
	tw.tween_property(body, "position:z", 0.5, 0.12).set_ease(Tween.EASE_OUT)


## Tornado Spin, Turbo Fan: a whirlwind of spins with wind puffs, rising off the grass.
func _style_spin(tw: Tween) -> void:
	tw.tween_callback(_sfx.bind("whoosh", "whoosh", 1.4))
	tw.tween_method(func(u: float) -> void:
		body.rotation.y = u * TAU * 5.0
		body.position.y = sin(u * PI) * 0.6
		if int(u * 12.0) != int((u - 0.03) * 12.0):
			Fx.puff(global_position + Vector3(cos(u * 30.0), 0.3, sin(u * 30.0)) * 0.8, RUN_FX_COLOR[&"wind"], 0.35), 0.0, 1.0, 0.8)
	tw.tween_property(body, "rotation:x", -0.45, 0.08)


## Pogo Legs, Kangaroo Tail, Spring Shoes: boing, boing, BOING onto the ball.
func _style_pogo(tw: Tween) -> void:
	for i in 3:
		var h := 0.35 + 0.35 * i
		tw.tween_callback(Audio.play.bind("hop", null, 1.2 + i * 0.15))
		tw.tween_property(body, "scale", _rest_scale * Vector3(1.2, 0.75, 1.2), 0.06)
		tw.tween_property(body, "position:y", h, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(body, "scale", _rest_scale * Vector3(0.85, 1.25, 0.85), 0.1)
		tw.tween_property(body, "position:y", 0.0, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(body, "scale", _rest_scale, 0.1)
	tw.tween_property(body, "rotation:x", -0.5, 0.06)


## Jetpack, Rocket Boots: blast off on a column of fire, hang there, dive-kick the ball.
func _style_jet(tw: Tween) -> void:
	tw.tween_callback(_sfx.bind("whoosh", "whoosh", 0.7))
	tw.tween_method(func(u: float) -> void:
		body.position.y = u * 1.4
		body.rotation.x = 0.3 * u
		if int(u * 14.0) != int((u - 0.02) * 14.0):
			Fx.puff(global_position + Vector3.UP * (u * 1.4 + 0.2), RUN_FX_COLOR[&"flame"], 0.45), 0.0, 1.0, 0.55)
	tw.tween_interval(0.15)
	tw.tween_property(body, "position:y", 0.0, 0.12).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(body, "rotation:x", -0.6, 0.12)


## Thunder Hat: the cloud rumbles, a flash, and the kick comes with lightning.
func _style_zap(tw: Tween) -> void:
	tw.tween_property(body, "rotation:x", 0.35, 0.3)
	for i in 2:
		tw.tween_callback(Fx.puff.bind(global_position + Vector3.UP * 2.4, Color(0.6, 0.6, 0.7), 0.6))
		tw.tween_callback(Audio.play.bind("land", null, 0.4))
		tw.tween_interval(0.18)
	tw.tween_callback(func() -> void:
		Fx.puff(global_position + Vector3.UP * 1.2, Color(1.0, 1.0, 0.5), 1.8)
		Fx.puff(global_position + Vector3.UP * 0.3 + global_basis.z * -0.6, Color(1.0, 0.95, 0.3), 1.2)
		Audio.play("kick_4", null, 1.6))
	tw.tween_property(body, "rotation:x", -0.5, 0.07)


## Banana Peel: steps on it a few metres out, feet fly up, lands flat on his back and slides,
## spinning, all the way into the ball. The ball dribbles off a sad metre (ball.gd).
func _gag_slip(tw: Tween) -> void:
	var from := global_position
	var gap := _flat(_ball - from)
	var stop := from + gap.normalized() * maxf(gap.length() - 0.7, 0.0)
	tw.tween_callback(_sfx.bind("slip", "land", 1.6))
	tw.tween_callback(_fling_peel)
	tw.tween_property(body, "position:z", -0.35, 0.1)
	tw.tween_property(body, "rotation:x", -0.35, 0.08)
	tw.tween_callback(_sfx.bind("shout", "hop", 1.4))
	tw.tween_property(body, "rotation:x", 1.35, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(body, "position:y", 0.85, 0.15).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(body, "position:y", 0.22, 0.15).set_ease(Tween.EASE_IN).set_delay(0.15)
	tw.tween_callback(func() -> void:
		Audio.play("land", null, 0.7)
		Fx.puff(global_position + Vector3.UP * 0.1, Color(1.0, 0.93, 0.4), 0.6)
		Fx.pop(body, 1.2)
		Audio.play("whoosh", null, 1.4))
	# Wheee: on his back, spinning, straight into the ball.
	tw.tween_method(_slide.bind(from, stop), 0.0, 1.0, 0.8)
	tw.parallel().tween_property(body, "rotation:y", TAU, 0.8).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void: body.rotation.y = 0.0)


func _slide(u: float, from: Vector3, to: Vector3) -> void:
	var at := from.lerp(to, 1.0 - (1.0 - u) * (1.0 - u))
	global_position = Vector3(at.x, global_position.y, at.z)
	if _rng.randf() < 0.35:
		Fx.puff(global_position + Vector3.UP * 0.05, Color(0.55, 0.8, 0.4), 0.3)


## The peel shoots out from under his foot, spinning, and lands behind him.
func _fling_peel() -> void:
	if not is_instance_valid(_prop):
		return
	var peel := _prop
	var start := peel.global_position
	var back := _flat(start - _ball).normalized() * 2.2
	var tw := peel.create_tween()
	tw.tween_method(func(u: float) -> void:
		peel.global_position = start + back * u + Vector3.UP * sin(u * PI) * 1.4
		peel.rotation = Vector3(u * TAU * 2.0, u * TAU, 0.0), 0.0, 1.0, 0.6)


## Butterfly: forgets the ball, chases it round in a circle with three hops, then remembers.
func _gag_chase(tw: Tween) -> void:
	var bug := _prop
	if bug:
		bug.top_level = true
	tw.tween_callback(_sfx.bind("flutter", "card_move", 1.6))
	tw.tween_method(_chase_step.bind(bug), 0.0, 1.0, 1.5)
	tw.tween_callback(func() -> void:
		_sfx("shout", "hop", 1.2)
		if is_instance_valid(bug):
			var fly := bug.create_tween()
			fly.tween_property(bug, "global_position", bug.global_position + Vector3(1.5, 4.0, -1.0), 1.2)
			fly.tween_callback(bug.queue_free))
	tw.tween_callback(Audio.play.bind("windup", null, 1.5))
	_kick_moves(tw, 0.75)


func _chase_step(u: float, bug: Node3D) -> void:
	# One full turn, so he ends up facing the ball again. The butterfly stays just ahead of his nose.
	var yaw := u * TAU
	body.rotation.y = yaw if u < 1.0 else 0.0
	body.position.y = absf(sin(u * PI * 3.0)) * 0.45
	if is_instance_valid(bug):
		var a := yaw + 0.6
		var off := global_basis * (Vector3(-sin(a), 0.0, -cos(a)) * 1.1)
		bug.global_position = global_position + off + Vector3.UP * (1.7 + sin(u * 20.0) * 0.15)
	if int(u * 3.0) != int((u - 0.02) * 3.0) and u > 0.02:
		Audio.play("hop", null, 1.3)


## Too Much Lunch: waddles to a stop, rocks, burps, and belly-bumps the ball.
func _gag_waddle(tw: Tween) -> void:
	for i in 2:
		tw.tween_property(body, "rotation:z", 0.4, 0.22).set_trans(Tween.TRANS_SINE)
		tw.tween_property(body, "rotation:z", -0.4, 0.22).set_trans(Tween.TRANS_SINE)
	tw.tween_property(body, "rotation:z", 0.0, 0.12)
	tw.tween_callback(func() -> void:
		_sfx("burp", "frog", 0.55)
		Fx.puff(global_position + Vector3.UP * 1.6 + global_basis.z * -0.4, Color(0.85, 1.0, 0.7), 0.6))
	tw.tween_property(body, "rotation:x", 0.35, 0.25).set_ease(Tween.EASE_OUT)
	tw.tween_property(body, "scale", _rest_scale * Vector3(1.25, 0.85, 1.25), 0.12)
	tw.tween_property(body, "rotation:x", -0.45, 0.12).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(body, "position:z", -0.35, 0.12)
	tw.parallel().tween_property(body, "scale", _rest_scale, 0.12)
	tw.tween_callback(_sfx.bind("boing", "hop", 0.6))


## Shoelaces Tied: three stumbling hops, each worse, then a faceplant; the heel boots the ball.
func _gag_trip(tw: Tween) -> void:
	for i in 3:
		tw.tween_callback(Audio.play.bind("hop", null, 1.1 + i * 0.15))
		tw.tween_property(body, "rotation:x", -0.25 - i * 0.22, 0.16)
		tw.parallel().tween_property(body, "position:y", 0.25, 0.08).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(body, "position:y", 0.0, 0.08).set_ease(Tween.EASE_IN).set_delay(0.08)
		tw.parallel().tween_property(body, "position:z", -0.12 * (i + 1), 0.16)
	tw.tween_callback(_sfx.bind("trip", "shout", 0.8))
	tw.tween_property(body, "rotation:x", -1.4, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(body, "position:y", 0.2, 0.18)
	tw.tween_callback(func() -> void:
		Audio.play("land", null, 0.6)
		Fx.puff(global_position + global_basis.z * -1.3 + Vector3.UP * 0.1, Color(0.85, 0.75, 0.6), 0.6)
		Fx.pop(body, 1.2))


## Sneeze: ah... ah... AH... CHOO! The sneeze throws him into the kick.
func _gag_sneeze(tw: Tween) -> void:
	for i in 3:
		tw.tween_callback(_sfx.bind("inhale", "shout", 1.2 + i * 0.2))
		tw.tween_property(body, "rotation:x", 0.15 * (i + 1), 0.28).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(body, "scale", _rest_scale * Vector3(0.95, 1.06 + 0.05 * i, 0.95), 0.28)
		tw.tween_interval(0.12)
	tw.tween_interval(0.2)
	tw.tween_callback(func() -> void:
		_sfx("achoo", "curse", 1.3)
		_set_state(State.WINDUP)   # the tissue box prop pops on WINDUP
		Fx.puff(global_position + Vector3.UP * 1.5 + global_basis.z * -1.0, Color(0.9, 1.0, 0.95), 0.7))
	tw.tween_property(body, "rotation:x", -0.7, 0.08)
	tw.parallel().tween_property(body, "scale", _rest_scale * Vector3(1.15, 0.85, 1.15), 0.08)
	tw.tween_property(body, "scale", _rest_scale, 0.15)
	tw.tween_property(body, "rotation:x", 0.3, 0.18)


func _tongue_boop() -> void:
	var tongue := frog_slot.find_child("Tongue", true, false) as Node3D
	if tongue == null:
		return
	var tw := tongue.create_tween()
	var rest := tongue.scale
	tw.tween_property(tongue, "scale", rest * Vector3(1.0, 1.0, 4.0), 0.08)
	tw.tween_property(tongue, "scale", rest, 0.18)


## A curse's prop shows for its kick only (curses never join the gear stack). The banana peel
## waits on the grass just before the ball.
func _spawn_prop() -> void:
	_clear_prop()
	if windup == null or not windup.is_curse() or windup.visual == null or frog:
		return
	_prop = windup.visual.instantiate()
	var gag := gag_of(windup)
	if gag != &"sneeze":
		# The kicker plays the gag's sounds itself.
		for key in [&"gag_cue", &"fallback_cue"]:
			if key in _prop:
				_prop.set(key, &"")
	if gag == &"slip":
		_prop.top_level = true
		add_child(_prop)
		var back := _flat(global_position - _ball).normalized()
		_prop.global_position = _ball + back * PEEL_GAP + Vector3.DOWN * (_ball.y - global_position.y)
		_prop.rotation.y = _rng.randf() * TAU
		_prop.scale = Vector3.ONE * 2.2
	else:
		attach_point(_prop.get_meta(&"attach_point", &"body")).add_child(_prop)
		if gag == &"chase":
			_prop.scale = Vector3.ONE * 1.8


func _clear_prop() -> void:
	if is_instance_valid(_prop):
		_prop.queue_free()
	_prop = null


## Run-up over the last RUNUP_WINDOW s: straight and fast is best, a hop adds a pinch.
func _quality_now() -> float:
	var path := 0.0
	for i in range(1, _hist.size()):
		path += Vector2(_hist[i].x - _hist[i - 1].x, _hist[i].y - _hist[i - 1].y).length()
	var straight := 0.0
	var span := 0.01
	if _hist.size() > 1:
		straight = Vector2(_hist[-1].x - _hist[0].x, _hist[-1].y - _hist[0].y).length()
		span = maxf(_hist[-1].z - _hist[0].z, 0.01)
	var top := max_speed * _fx(&"run_speed_mult")
	var q := run_up_quality(path, straight, path / span, top, _time - _hopped_t < RUNUP_WINDOW + 0.3)
	return clampf(q + float(effects.get(&"runup_bonus", 0.0)), QUALITY_MIN, QUALITY_MAX)


## Plays `cue` if the Audio lane has made it, else an existing cue at `pitch`.
func _sfx(cue: String, fallback: String, pitch: float = 1.0) -> void:
	if ResourceLoader.exists(SFX_DIR + cue + ".ogg") or ResourceLoader.exists(SFX_DIR + cue + "_1.ogg"):
		Audio.play(cue)
	else:
		Audio.play(fallback, null, pitch)
