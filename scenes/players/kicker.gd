## Kicker: runs crazily at the ball and kicks it automatically. Systems lane owns.
## jeff.tscn / chuck.tscn inherit kicker.tscn; Art swaps Body for the Jarling and drives an
## AnimationTree from `state`. Keep the node names and the API (docs/contracts.md "Kicker").
class_name Kicker
extends CharacterBody3D

enum State { IDLE, APPROACH, WINDUP, FOLLOW_THROUGH, CHEER, CHAIR, CLOUD }

signal state_changed(state: State)
signal kick_contact(run_up_quality: float)
signal hopped(player: int)
signal shouted(player: int)

const FROG_FALLBACK := preload("res://scenes/curses/frog.tscn")
const SLOTS: Array[StringName] = [&"head", &"feet", &"back", &"hands", &"body"]

@export var player: int = Players.P1
@export_group("Silly approach")
@export var max_speed := 5.0
## Low acceleration is what makes him overshoot and swing wide.
@export var accel := 1.4
@export var wobble := 0.5
## A stick pointing within ~55 degrees of the ball gets pulled onto it.
@export var assist_cone := 0.57
@export var assist := 0.55
## Seconds without getting closer before auto-steer starts, and how long it ramps.
@export var auto_steer_after := 2.0
@export var auto_steer_ramp := 1.0
## Whatever happens, auto-steer is fully on by this many seconds into the approach.
@export var auto_steer_deadline := 5.0
@export var field_radius := 14.0
@export_group("Moves")
@export var windup_time := 0.6
@export var hop_velocity := 4.5
@export var gravity := 16.0
@export var frog_hop_every := 0.45

var state: State = State.IDLE
var frog := false
## Tests (and bots) steer with this instead of a pad when it is a Vector2.
var stick_override: Variant = null

var _ball := Vector3.ZERO
var _start := Vector3.ZERO
var _time := 0.0
var _path := 0.0
var _best_dist := INF
var _since_progress := 0.0
var _auto := 0.0
var _hopped := false
var _phase := 0.0
var _frog_timer := 0.0
var _anim_t := 0.0
var _tween: Tween
var _rng := RandomNumberGenerator.new()

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


func _physics_process(delta: float) -> void:
	_anim_t += delta
	if state == State.CLOUD:
		velocity = Vector3.ZERO
	elif not is_on_floor():
		velocity.y -= gravity * delta
	if state == State.APPROACH:
		_approach(delta)
	else:
		var hv := Vector3(velocity.x, 0.0, velocity.z).move_toward(Vector3.ZERO, 20.0 * delta)
		velocity.x = hv.x
		velocity.z = hv.z
	_buttons()
	_idle_anim()
	if state != State.CLOUD:
		move_and_slide()


# --- API ---------------------------------------------------------------------

func begin_approach(ball_position: Vector3) -> void:
	_kill_tween()
	_ball = ball_position
	_start = global_position
	_time = 0.0
	_path = 0.0
	_best_dist = _flat(_ball - global_position).length()
	_since_progress = 0.0
	_auto = 0.0
	_hopped = false
	velocity = Vector3.ZERO
	body.rotation = Vector3.ZERO
	_face(_ball - global_position, 1.0)
	_set_state(State.APPROACH)
	Audio.play("frog" if frog else ("windup_jeff" if player == Players.P1 else "windup_chuck"))


func start_windup() -> void:
	if state != State.APPROACH:
		return
	var straight := _flat(global_position - _start).length()
	var avg_speed := _path / maxf(_time, 0.01)
	var quality := run_up_quality(_path, straight, avg_speed, max_speed, _hopped)
	velocity = Vector3(0.0, velocity.y, 0.0)
	_face(_ball - global_position, 1.0)
	_set_state(State.WINDUP)
	Audio.play("windup", null, 1.3)
	_kill_tween()
	_tween = create_tween()
	if frog:
		# The frog "kick" is a flop.
		_tween.tween_property(frog_slot, "scale", Vector3(1.4, 0.5, 1.4), 0.25)
		_tween.tween_callback(Audio.play.bind("frog"))
		_tween.tween_property(frog_slot, "scale", Vector3.ONE, 0.2)
	else:
		# Lean back, then two lunatic spins into the ball.
		_tween.tween_property(body, "rotation:x", -0.5, windup_time * 0.4).set_ease(Tween.EASE_OUT)
		_tween.tween_property(body, "rotation:y", TAU * 2.0, windup_time * 0.6).as_relative().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_tween.parallel().tween_property(body, "rotation:x", 0.35, windup_time * 0.6)
	_tween.tween_callback(_contact.bind(quality))
	_tween.tween_interval(0.5)
	_tween.tween_callback(_end_follow_through)


func set_waiting(chair: bool) -> void:
	_kill_tween()
	body.rotation = Vector3.ZERO
	_set_state(State.CHAIR if chair else State.CHEER)


func set_cloud() -> void:
	_kill_tween()
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
	frog = on
	for c in frog_slot.get_children():
		c.queue_free()
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


func attach_point(slot: StringName) -> Node3D:
	var n := attach.get_node_or_null(NodePath(String(slot).capitalize()))
	return n if n else attach.get_node("Body")


func add_upgrade_visual(upgrade: UpgradeData) -> void:
	var count := 0
	for slot in SLOTS:
		count += attach_point(slot).get_child_count()
	var piece: Node3D
	var slot: StringName
	if upgrade.visual:
		piece = upgrade.visual.instantiate()
		slot = piece.get_meta(&"attach_point", &"body")
	else:
		piece = _placeholder_piece(upgrade)
		slot = SLOTS[count % 4]
		var stacked := attach_point(slot).get_child_count()
		piece.position = Vector3(0, 0.16 * stacked, 0) if slot == &"head" else Vector3(0.05 * stacked, 0.05 * stacked, 0)
	attach_point(slot).add_child(piece)
	piece.scale = Vector3.ONE * 0.01
	var tw := piece.create_tween()
	tw.tween_property(piece, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Audio.play("upgrade_on")
	Fx.puff(piece.global_position, _icon_color(upgrade), 0.8)
	Fx.pop(body, 1.25)


func clear_upgrade_visuals() -> void:
	for slot in SLOTS:
		for c in attach_point(slot).get_children():
			c.queue_free()


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

func _approach(delta: float) -> void:
	_time += delta
	var to_ball := _flat(_ball - global_position)
	var dist := to_ball.length()
	var want := to_ball.normalized() if dist > 0.01 else Vector3.ZERO
	var stick := _stick_world()
	var dir := stick
	if stick.length() > 0.2 and stick.normalized().dot(want) > assist_cone:
		dir = stick.normalized().lerp(want, assist).normalized() * stick.length()
	if dist < _best_dist - 0.3:
		_best_dist = dist
		_since_progress = 0.0
	else:
		_since_progress += delta
	# Once it starts helping it ramps all the way (progress must not switch it back off).
	if _auto > 0.0 or _since_progress > auto_steer_after or _time > auto_steer_deadline - auto_steer_ramp:
		_auto = minf(_auto + delta / auto_steer_ramp, 1.0)
	var auto := _auto
	dir = dir.lerp(want, auto)
	# The silly part: a heading that never quite settles, worse the faster he goes.
	var wob := sin(_time * 5.5 + _phase) * wobble + _rng.randf_range(-0.2, 0.2)
	dir = dir.rotated(Vector3.UP, wob * minf(dir.length(), 1.0) * (1.0 - 0.6 * auto))
	var from_ball := _flat(global_position - _ball)
	if from_ball.length() > field_radius:
		dir = dir.lerp(-from_ball.normalized(), 0.8)
	var hv := Vector3(velocity.x, 0.0, velocity.z)
	if frog:
		_frog_timer -= delta
		if is_on_floor() and dir.length() > 0.2 and _frog_timer <= 0.0:
			_frog_timer = frog_hop_every
			hv = dir.normalized() * max_speed * 0.7
			velocity.y = hop_velocity * 0.7
			Audio.play("frog", null, 1.2)
		elif is_on_floor():
			hv = hv.move_toward(Vector3.ZERO, 30.0 * delta)
	else:
		# Auto-steer also firms up the feet, so a wanderer turns back quickly.
		hv = hv.move_toward(dir * max_speed, lerpf(accel, accel * 3.0, auto) * max_speed * delta)
	velocity.x = hv.x
	velocity.z = hv.z
	_path += hv.length() * delta
	if hv.length() > 0.3:
		_face(hv, 8.0 * delta)


func _contact(quality: float) -> void:
	_set_state(State.FOLLOW_THROUGH)
	Fx.puff(global_position + Vector3.UP * 0.3, Color(0.85, 0.75, 0.6), 1.2)
	kick_contact.emit(quality)


func _end_follow_through() -> void:
	body.rotation = Vector3.ZERO
	frog_slot.scale = Vector3.ONE
	if state == State.FOLLOW_THROUGH:
		_set_state(State.IDLE)


func _buttons() -> void:
	if Game.state != Game.State.PLAYING or not _reads_input() or state == State.CHAIR:
		return
	if Input.is_action_just_pressed(Players.action(player, "jump")) and state != State.WINDUP:
		if _hop(1.0):
			if state == State.APPROACH:
				_hopped = true
			Audio.play("hop")
			hopped.emit(player)
	if Input.is_action_just_pressed(Players.action(player, "action")):
		if state == State.APPROACH or state == State.WINDUP:
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
	velocity.y = hop_velocity * strength
	Fx.pop(body, 1.2)
	return true


func _idle_anim() -> void:
	match state:
		State.CHEER, State.IDLE:
			body.position.y = absf(sin(_anim_t * 5.0 + _phase)) * 0.08
		State.CHAIR:
			body.position.y = -0.45 + sin(_anim_t * 1.5) * 0.02
		State.APPROACH:
			# Flailing run: bob and side-to-side lean.
			body.position.y = absf(sin(_anim_t * 14.0)) * 0.12
			body.rotation.z = sin(_anim_t * 9.0 + _phase) * 0.25
		_:
			body.position.y = 0.0


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
		body.scale = Vector3.ONE
		frog_slot.scale = Vector3.ONE


func _set_state(to: State) -> void:
	if to == state:
		return
	state = to
	state_changed.emit(to)
