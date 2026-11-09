# PLACEHOLDER (systems grey-box): Gameplay owns the ball and replaces this; keep the API.
## Ball: real physics for the first moments, then a deterministic scripted arc so a 100 km kick
## is as stable as a 2 m one. Heights are real metres; the scene is log-compressed above 20 m
## (TierSet.visual_y), so the hand-off happens below that, where the two agree.
extends RigidBody3D

signal kick_zone_entered(body: Node3D)
signal returned()

enum Flight { TEE, PHYSICS, SCRIPTED, PEAK, DROP, FLOATING }

const HANDOFF_TIME := 2.0
const HANDOFF_HEIGHT := 18.0
## Jolt never sees more than this; the scripted arc does the rest.
const MAX_PHYSICS_SPEED := 40.0
const ARC_TIME_MIN := 1.2
const ARC_TIME_MAX := 6.0
const PEAK_HOLD := 0.8
const SPACE_HOLD := 2.0
const DROP_HEIGHT := 12.0
const DROP_TIME := 0.55
const TEE_HEIGHT := 0.35

@export var player: int = 0

var height := 0.0
var speed := 0.0
var flight := Flight.TEE
var peak_height := 0.0

var _tee := Vector3.ZERO
var _t := 0.0
var _arc_from := 0.0
var _arc_to := 0.0
var _arc_time := 1.0
var _arc_xz := Vector3.ZERO
var _tier := 1
var _armed := false
var _hold := 0.0
var _last_vis := 0.0
var _tween: Tween

@onready var zone: Area3D = $KickZone
@onready var mesh: MeshInstance3D = $Mesh


func _ready() -> void:
	collision_layer = 16
	collision_mask = 1
	zone.collision_layer = 0
	zone.collision_mask = 2
	zone.body_entered.connect(_on_zone_body_entered)
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Players.COLOR[player].lerp(Color.WHITE, 0.55)
	mat.rim_enabled = true
	mesh.material_override = mat


func place_on_tee(tee: Vector3) -> void:
	_kill_tween()
	_tee = tee
	flight = Flight.TEE
	freeze = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	global_position = tee + Vector3.UP * TEE_HEIGHT
	global_rotation = Vector3.ZERO
	height = 0.0
	speed = 0.0
	visible = true


func arm(on: bool) -> void:
	_armed = on
	if on:
		for b in zone.get_overlapping_bodies():
			_on_zone_body_entered(b)


func launch(power: float, peak: float) -> void:
	_armed = false
	peak_height = peak
	_tier = 1
	_t = 0.0
	freeze = false
	var v0 := minf(sqrt(2.0 * Run.GRAVITY * maxf(peak, 0.0)), MAX_PHYSICS_SPEED)
	var forward := minf(power * 0.35, 3.0)
	apply_central_impulse(Vector3(0.0, v0, -forward) * mass)
	angular_velocity = Vector3(randf_range(-8, 8), randf_range(-4, 4), randf_range(-8, 8))
	flight = Flight.PHYSICS
	Audio.play("whoosh", null, clampf(0.7 + v0 / 40.0, 0.7, 1.7))


func _physics_process(delta: float) -> void:
	match flight:
		Flight.PHYSICS:
			_t += delta
			height = maxf(global_position.y - _tee.y - TEE_HEIGHT, 0.0)
			speed = linear_velocity.length()
			_check_tiers()
			if peak_height > HANDOFF_HEIGHT and (height >= HANDOFF_HEIGHT or _t >= HANDOFF_TIME):
				_hand_off()
			elif _t > 0.1 and linear_velocity.y <= 0.0:
				_reach_peak()
		Flight.SCRIPTED:
			_t += delta
			var u := clampf(_t / _arc_time, 0.0, 1.0)
			var vis := lerpf(_arc_from, _arc_to, 1.0 - (1.0 - u) * (1.0 - u))
			speed = (vis - _last_vis) / maxf(delta, 0.0001)
			_last_vis = vis
			global_position = Vector3(_arc_xz.x, _tee.y + TEE_HEIGHT + vis, _arc_xz.z)
			rotate_y(delta * 6.0)
			height = TierSet.real_height(vis)
			_check_tiers()
			if u >= 1.0:
				height = peak_height
				_reach_peak()
		Flight.PEAK:
			speed = 0.0
			_hold -= delta
			if _hold <= 0.0:
				if Run.in_space(player):
					flight = Flight.FLOATING
					returned.emit()
				else:
					_drop()
		Flight.FLOATING:
			global_position.y += sin(Time.get_ticks_msec() / 400.0) * delta * 0.3
			rotate_y(delta * 0.5)


func _hand_off() -> void:
	freeze = true
	_arc_xz = global_position
	_arc_from = global_position.y - _tee.y - TEE_HEIGHT
	_arc_to = TierSet.visual_y(peak_height)
	var v := maxf(linear_velocity.y, 1.0)
	_arc_time = clampf(2.0 * (_arc_to - _arc_from) / v, ARC_TIME_MIN, ARC_TIME_MAX)
	_last_vis = _arc_from
	_t = 0.0
	flight = Flight.SCRIPTED
	Audio.play("whoosh", null, clampf(1.0 + log(maxf(peak_height, 1.0)) / 12.0, 1.0, 2.0))


func _check_tiers() -> void:
	var t := Run.tier_of_height(height)
	while _tier < t:
		_tier += 1
		var data: TierData = Run.tiers.get_tier(_tier) if Run.tiers else null
		Audio.play(String(data.tier_up_cue) if data else "tier_up", null, 1.0 + _tier * 0.05)
		Fx.puff(global_position, data.color if data else Color.WHITE, 2.0 + _tier * 0.5)
		Run.notify_tier(player, _tier)


func _reach_peak() -> void:
	flight = Flight.PEAK
	freeze = true
	speed = 0.0
	_hold = SPACE_HOLD if height >= Run.tiers.space_height() or peak_height >= Run.tiers.space_height() else PEAK_HOLD
	Audio.play("land")
	Fx.puff(global_position, Color(1, 1, 0.7), 1.5)
	Run.notify_stopped(player, peak_height)
	if Run.in_space(player):
		_hold = SPACE_HOLD


func _drop() -> void:
	flight = Flight.DROP
	freeze = true
	global_position = _tee + Vector3.UP * (TEE_HEIGHT + DROP_HEIGHT)
	height = 0.0
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(self, "global_position", _tee + Vector3.UP * TEE_HEIGHT, DROP_TIME) \
			.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(func() -> void:
		Audio.play("land", null, 1.3)
		Fx.puff(_tee + Vector3.UP * 0.2, Color(0.8, 0.7, 0.55), 1.0)
		flight = Flight.TEE
		returned.emit())


func _on_zone_body_entered(body: Node3D) -> void:
	if _armed and flight == Flight.TEE:
		kick_zone_entered.emit(body)


func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = null
