## Ball: real physics for the first moments, then a deterministic scripted arc so a 100 km kick
## is as stable as a 2 m one. Heights are real metres; the scene is log-compressed above 20 m
## (TierSet.visual_y), so the hand-off happens below that, where the two agree.
extends RigidBody3D

signal kick_zone_entered(body: Node3D)
signal returned()
## Each touch-down of the comedy drop onto the tee (1.0 the first, smaller after; 0.3 the last).
signal bounced(strength: float)
## Sky hook (docs/contracts.md, Ball): a real flight started (not the frog dribble).
signal launched(peak_height: float)

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
## The fall onto the tee, then the bounce heights (metres) after it.
const DROP_TIME := 0.36
const DROP_BOUNCES := [1.1, 0.3]
const TEE_HEIGHT := 0.35
## Landmarks with a little sound gag on top of the tier sparkle (assets/audio/sfx/gag_<id>.ogg).
const TIER_GAGS: Array[StringName] = [&"rooftops", &"treetops", &"clouds", &"edge", &"space"]
## Space: the orbit the ball settles into (visual metres, seconds per lap).
const ORBIT_RADIUS := 1.8
const ORBIT_PERIOD := 4.0
## Frog round and banana slip: the ball dribbles this far along the grass instead of flying.
const DRIBBLE_DISTANCE := 1.4
const DRIBBLE_TIME := 0.9
const FACE_YAW := 1.15
## Sky hook: reactions only offset the Mesh (never the arc), at most this share of the visual
## height (or SKY_MIN_OFFSET m), and pause the scripted arc at most SKY_MAX_HOLD s per flight.
const SKY_MAX_OFFSET := 0.04
const SKY_MIN_OFFSET := 0.6
const SKY_MAX_HOLD := 0.6
const SKY_SPRING := 60.0
const SKY_DAMP := 9.0

@export var player: int = 0
## This kick's ball effects (UpgradeData.ball_effect, via Run.effects_of): set before launch().
var effects: Array[StringName] = []

## Floaty (Helium Ball, Moon Gravity): this much gravity, a longer arc and a longer hang at the top.
const FLOAT_GRAVITY := 0.4
const TRAIL_COLOR := {
	&"rocket": Color(1.0, 0.3, 0.05), &"sparkle": Color(1.0, 0.95, 0.5), &"floaty": Color(1.0, 0.45, 0.8),
	&"curve": Color(0.75, 0.9, 1.0),
}
var _trail_t := 0.0
var _curve_side := 1.0

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
## FLOATING: circling `orbit_center` (space, end card) when `_orbiting`.
var orbit_center := Vector3.ZERO
var _orbiting := false
var _orbit_r := ORBIT_RADIUS
var _orbit_a := 0.0
var _orbit_tilt := 0.0
var _orbit_speed := TAU / ORBIT_PERIOD
var _return_in := -1.0
var _ring: MeshInstance3D
var _dribbling := false
## Sky hook state: the Mesh's world offset, its spring velocity, hit-stop left / used, extra spin.
var sky_offset := Vector3.ZERO
var _sky_vel := Vector3.ZERO
var _sky_hold := 0.0
var _sky_hold_used := 0.0
var _sky_spin := 0.0

@onready var zone: Area3D = $KickZone
@onready var mesh: MeshInstance3D = $Mesh


func _ready() -> void:
	add_to_group(&"balls")
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
	_stop_orbit()
	_sky_reset()
	mesh.scale = Vector3.ONE
	gravity_scale = 1.0
	constant_force = Vector3.ZERO


func is_armed() -> bool:
	return _armed


## The frog round and the banana slip: the ball barely goes anywhere.
static func dribbles(curse: UpgradeData) -> bool:
	return curse != null and (curse.scene_override != null or curse.windup_anim == &"slip")


func arm(on: bool) -> void:
	_armed = on
	if on:
		for b in zone.get_overlapping_bodies():
			_on_zone_body_entered(b)


func launch(power: float, peak: float) -> void:
	_armed = false
	peak_height = peak
	if dribbles(Run.curse_of(player)):
		_dribble()
		return
	_tier = 1
	_t = 0.0
	freeze = false
	var g := Run.GRAVITY * (FLOAT_GRAVITY if has_effect(&"floaty") else 1.0)
	gravity_scale = g / Run.GRAVITY
	var v0 := minf(sqrt(2.0 * g * maxf(peak, 0.0)), MAX_PHYSICS_SPEED)
	var forward := minf(power * 0.35, 3.0)
	apply_central_impulse(Vector3(0.0, v0, -forward) * mass)
	if has_effect(&"curve"):
		_curve_side = -1.0 if randf() < 0.5 else 1.0
		constant_force = Vector3(_curve_side * 6.0, 0.0, 0.0) * mass
	_launch_fx()
	angular_velocity = Vector3(randf_range(-8, 8), randf_range(-4, 4), randf_range(-8, 8))
	flight = Flight.PHYSICS
	Audio.play("whoosh", null, clampf(0.7 + v0 / 40.0, 0.7, 1.7))
	_sky_reset()
	launched.emit(peak)


func _physics_process(delta: float) -> void:
	if _dribbling:
		return   # the dribble tween owns the ball
	_sky_step(delta)
	if flight == Flight.PHYSICS or flight == Flight.SCRIPTED:
		_trail(delta)
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
			if _sky_hold > 0.0:
				_sky_hold -= delta   # hit-stop: the arc's clock waits, the peak doesn't move
				return
			_t += delta
			var u := clampf(_t / _arc_time, 0.0, 1.0)
			var vis := lerpf(_arc_from, _arc_to, 1.0 - (1.0 - u) * (1.0 - u))
			speed = (vis - _last_vis) / maxf(delta, 0.0001)
			_last_vis = vis
			global_position = Vector3(_arc_xz.x, _tee.y + TEE_HEIGHT + vis, _arc_xz.z)
			if has_effect(&"floaty"):
				global_position.x += sin(_t * 2.2) * 0.8   # drifting like a balloon
			if has_effect(&"curve"):
				global_position.x += _curve_side * sin(u * PI) * 3.0
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
			if _return_in > 0.0:
				_return_in -= delta
				if _return_in <= 0.0:
					returned.emit()
			if _orbiting:
				_orbit_a += _orbit_speed * delta
				global_position = orbit_center + _orbit_offset(_orbit_a)
				# Keep the face toward the camera so the smile reads.
				var cam := get_viewport().get_camera_3d()
				if cam:
					# The face sits at yaw FACE_YAW in the ball's own space (ball.gdshader face_angle).
					var to_cam := cam.global_position - global_position
					rotation = Vector3(0.0, atan2(to_cam.x, to_cam.z) - FACE_YAW, 0.0)
			else:
				global_position.y += sin(Time.get_ticks_msec() / 400.0) * delta * 0.3
				rotate_y(delta * 0.5)


func _hand_off() -> void:
	freeze = true
	_arc_xz = global_position
	_arc_from = global_position.y - _tee.y - TEE_HEIGHT
	_arc_to = TierSet.visual_y(peak_height)
	var v := maxf(linear_velocity.y, 1.0)
	_arc_time = clampf(2.0 * (_arc_to - _arc_from) / v, ARC_TIME_MIN, ARC_TIME_MAX)
	if has_effect(&"floaty"):
		_arc_time *= 1.6
	elif has_effect(&"rocket"):
		_arc_time *= 0.8
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
		if data and data.id in TIER_GAGS:
			Audio.play("gag_" + String(data.id))
		if _tier < 8:   # dark space-tier colours make black blobs; Juice's star burst covers space
			Fx.puff(global_position, (data.color if data else Color.WHITE).lerp(Color.WHITE, 0.4), 2.0 + _tier * 0.5)
		Run.notify_tier(player, _tier)


func _reach_peak() -> void:
	flight = Flight.PEAK
	freeze = true
	speed = 0.0
	_hold = SPACE_HOLD if height >= Run.tiers.space_height() or peak_height >= Run.tiers.space_height() else PEAK_HOLD
	constant_force = Vector3.ZERO
	if has_effect(&"floaty"):
		_hold += 0.8   # it hangs up there
	if has_effect(&"confetti"):
		_confetti_pop()
	Audio.play("land")
	Fx.puff(global_position, Color(1, 1, 0.7), 1.5)
	if Run.in_space(player):
		# Settle into orbit: the ball swings round a point beside its peak, smiling.
		orbit_around(global_position + Vector3(-ORBIT_RADIUS, 0.0, 0.0), ORBIT_RADIUS, 0.3, 0.0)
		_return_in = SPACE_HOLD
		Audio.play("orbit_chime")
	Run.notify_stopped(player, peak_height)


func _drop() -> void:
	flight = Flight.DROP
	freeze = true
	global_position = _tee + Vector3.UP * (TEE_HEIGHT + DROP_HEIGHT)
	height = 0.0
	_kill_tween()
	_tween = create_tween()
	var rest := _tee + Vector3.UP * TEE_HEIGHT
	if has_effect(&"floaty"):
		_tween.tween_property(self, "global_position", rest, 1.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		# The comedy drop: it falls, then bounces twice, smaller each time, and every touch-down
		# thuds, puffs dust and squashes the ball.
		_tween.tween_property(self, "global_position", rest, DROP_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		for i in DROP_BOUNCES.size():
			var h: float = DROP_BOUNCES[i]
			var up := sqrt(h) * 0.13
			_tween.tween_callback(_bounce.bind(1.0 - i * 0.35))
			_tween.tween_property(self, "global_position", rest + Vector3.UP * h, up).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			_tween.tween_property(self, "global_position", rest, up).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if has_effect(&"bouncy"):
		# Boing, boing, boing back onto the tee.
		for h in [1.6, 0.7, 0.25]:
			_tween.tween_callback(Audio.play.bind("hop", null, 1.6 - h * 0.3))
			_tween.tween_property(self, "global_position", rest + Vector3.UP * h, 0.12 + h * 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			_tween.tween_property(self, "global_position", rest, 0.12 + h * 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_callback(func() -> void:
		Audio.play("land", null, 1.3)
		Fx.puff(_tee, Color(0.8, 0.7, 0.55), 0.6)   # settles; small enough that the ball shows
		bounced.emit(0.3)
		flight = Flight.TEE
		returned.emit())


## One touch-down of the comedy drop (`strength` 1 for the first, smaller after).
func _bounce(strength: float) -> void:
	Audio.play("land", null, 0.9 + (1.0 - strength) * 0.5)
	Fx.puff(_tee, Color(0.8, 0.7, 0.55), 0.12 + strength * 0.18)   # small: the ball must stay in sight
	Fx.pop(mesh, 1.0 + 0.4 * strength)
	bounced.emit(strength)


func _on_zone_body_entered(body: Node3D) -> void:
	if _armed and flight == Flight.TEE:
		kick_zone_entered.emit(body)


func _kill_tween() -> void:
	_dribbling = false
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = null


## Circle `center` forever (FLOATING): the space moment and the end card. `tilt` leans the orbit
## plane (radians about X), `phase` is where on the loop it starts.
func orbit_around(center: Vector3, radius: float, tilt: float, phase: float) -> void:
	_kill_tween()
	freeze = true
	linear_velocity = Vector3.ZERO
	orbit_center = center
	_orbit_r = radius
	_orbit_tilt = tilt
	_orbit_a = phase
	_orbiting = true
	flight = Flight.FLOATING
	mesh.scale = Vector3.ONE * 1.5   # big enough to see the smile
	_sky_reset()
	_return_in = -1.0
	global_position = center + _orbit_offset(phase)
	_show_ring()


func _orbit_offset(a: float) -> Vector3:
	return Basis(Vector3.RIGHT, _orbit_tilt) * Vector3(cos(a), 0.0, sin(a)) * _orbit_r


func _show_ring() -> void:
	if _ring == null:
		_ring = MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.rings = 64
		torus.ring_segments = 6
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Players.COLOR[player].lerp(Color.WHITE, 0.5)
		mat.albedo_color.a = 0.45
		torus.material = mat
		_ring.mesh = torus
		_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_ring.top_level = true
		add_child(_ring)
	var torus := _ring.mesh as TorusMesh
	torus.outer_radius = _orbit_r + 0.04
	torus.inner_radius = _orbit_r - 0.04
	_ring.global_transform = Transform3D(Basis(Vector3.RIGHT, _orbit_tilt), orbit_center)
	_ring.visible = true


func _stop_orbit() -> void:
	_orbiting = false
	_return_in = -1.0
	if _ring:
		_ring.visible = false


## Frog round: a pathetic little dribble along the grass, then the usual peak hold and drop.
func _dribble() -> void:
	flight = Flight.PHYSICS   # the face looks shocked, the trail draws
	freeze = true
	_t = 0.0
	var from := global_position
	var to := from + Vector3(0.0, -TEE_HEIGHT + 0.25, -DRIBBLE_DISTANCE)
	Audio.play("whoosh", null, 0.5)
	_kill_tween()
	_dribbling = true
	_tween = create_tween()
	_tween.tween_method(func(u: float) -> void:
		var hop := absf(sin(u * PI * 3.0)) * 0.3 * (1.0 - u)
		global_position = from.lerp(to, 1.0 - (1.0 - u) * (1.0 - u)) + Vector3.UP * hop
		rotation.x = -u * 6.0
		height = maxf(global_position.y - _tee.y - TEE_HEIGHT, 0.0), 0.0, 1.0, DRIBBLE_TIME)
	_tween.tween_callback(func() -> void:
		_dribbling = false
		flight = Flight.PEAK
		height = peak_height
		_hold = PEAK_HOLD + 0.6
		Run.notify_stopped(player, peak_height))


func has_effect(e: StringName) -> bool:
	return effects.has(e)


## The kick's ball effects, seen at once: a squash-and-boing, split ghosts, a confetti pop.
func _launch_fx() -> void:
	_trail_t = 0.0
	if has_effect(&"bouncy"):
		mesh.scale = Vector3(1.5, 0.55, 1.5)
		var tw := mesh.create_tween()
		tw.tween_property(mesh, "scale", Vector3(0.8, 1.35, 0.8), 0.1)
		tw.tween_property(mesh, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		Audio.play("hop", null, 0.8)
	if has_effect(&"floaty"):
		Audio.play("squeak", null, 1.4)
	if has_effect(&"rocket"):
		Audio.play("whoosh", null, 0.6)
	if has_effect(&"split"):
		_split_ghosts()
	if has_effect(&"confetti"):
		_confetti_pop()


func _trail(delta: float) -> void:
	_trail_t -= delta
	if _trail_t > 0.0 or global_position.y - _tee.y > 400.0:
		return
	_trail_t = 0.06
	for e in effects:
		if TRAIL_COLOR.has(e):
			Fx.puff(global_position + Vector3(randf_range(-0.15, 0.15), -0.3, randf_range(-0.15, 0.15)),
					TRAIL_COLOR[e], 0.6 if e == &"rocket" else 0.4)


## Two see-through copies peel off sideways and fade: "which one is it?!"
func _split_ghosts() -> void:
	Audio.play("confetti_pop", null, 1.4)
	for side in [-1.0, 1.0]:
		var g := MeshInstance3D.new()
		g.mesh = mesh.mesh
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Players.COLOR[player].lerp(Color.WHITE, 0.6)
		mat.albedo_color.a = 0.6
		g.material_override = mat
		g.top_level = true
		add_child(g)
		g.global_position = global_position
		var tw := g.create_tween()
		tw.tween_property(g, "global_position", global_position + Vector3(side * 2.5, 5.0, -1.0), 1.0).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(mat, "albedo_color:a", 0.0, 1.0).set_ease(Tween.EASE_IN)
		tw.tween_callback(g.queue_free)


func _confetti_pop() -> void:
	Audio.play("confetti_pop")
	for c in [Color(1, 0.4, 0.5), Color(0.4, 0.8, 1), Color(1, 0.9, 0.3), Color(0.6, 1, 0.5)]:
		Fx.puff(global_position + Vector3(randf_range(-0.6, 0.6), randf_range(0.0, 0.6), randf_range(-0.6, 0.6)), c, 0.5)


## Sky hook (docs/contracts.md, Ball): a sky object bumped the ball. Cosmetic only: `push` (m/s)
## kicks a spring that offsets the Mesh, `hold` is hit-stop on the scripted arc, `spin` twirls it.
func sky_react(push: Vector3, hold: float = 0.0, spin: float = 0.0) -> void:
	_sky_vel += push
	_sky_spin += spin
	if flight == Flight.SCRIPTED:
		var h := clampf(hold, 0.0, SKY_MAX_HOLD - _sky_hold_used)
		_sky_hold += h
		_sky_hold_used += h


func sky_bound() -> float:
	return maxf(SKY_MIN_OFFSET, SKY_MAX_OFFSET * TierSet.visual_y(height))


func _sky_step(delta: float) -> void:
	if sky_offset == Vector3.ZERO and _sky_vel == Vector3.ZERO and _sky_spin == 0.0:
		return
	_sky_vel += (-SKY_SPRING * sky_offset - SKY_DAMP * _sky_vel) * delta
	sky_offset += _sky_vel * delta
	var bound := sky_bound()
	if sky_offset.length() > bound:
		sky_offset = sky_offset.normalized() * bound
		_sky_vel *= 0.5
	if sky_offset.length() < 0.002 and _sky_vel.length() < 0.02:
		sky_offset = Vector3.ZERO
		_sky_vel = Vector3.ZERO
	mesh.rotate_y(_sky_spin * delta)
	_sky_spin = move_toward(_sky_spin, 0.0, delta * 25.0)
	mesh.position = global_basis.inverse() * sky_offset


func _sky_reset() -> void:
	sky_offset = Vector3.ZERO
	_sky_vel = Vector3.ZERO
	_sky_hold = 0.0
	_sky_hold_used = 0.0
	_sky_spin = 0.0
	if mesh:
		mesh.position = Vector3.ZERO
		mesh.rotation = Vector3.ZERO
