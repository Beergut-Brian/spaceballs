## One thing in the sky the ball can bump into (docs/contracts.md, Sky objects). Sky lane.
## SkyField spawns it at a tier's scale, may steer it into the ball's path (`homing`), and calls
## hit() / near(). The reaction is cosmetic: the ball only gets ball.sky_react (no height change).
## Scene layout (scenes/sky/build_sky.gd writes these): Root (this) > Gag (the part the gag tweens)
## > parts. Name conventions under Gag: `Pop*` balloons that burst, `Bird*` birds that scatter,
## `Beam` shown when the saucer catches. Idle motion lives on leaf parts (landmark_motion.gd).
class_name SkyObject
extends Node3D

enum Reaction { POP, BONK, SCATTER, BOUNCE, SNAG, PING, CATCH }

const CONFETTI := [Color("ff4fd8"), Color("38c6ff"), Color("ffd84d"), Color("3cc24a"), Color("ff9f2e")]

@export var reaction: Reaction = Reaction.BONK
## Audio.play cue on a hit (assets/audio/CUES.md) and its pitch.
@export var cue: StringName = &"sky_bonk"
@export var cue_pitch := 1.0
## Optional startle when the ball only passes by (`near_radius` > 0).
@export var near_cue: StringName = &""
@export var near_pitch := 1.0
## Local units (the root is scaled by the tier's SkyTier.scale).
@export var hit_radius := 1.0
@export var near_radius := 0.0
@export var hit_offset := Vector3.ZERO
## The ball's reaction: push in m/s (sideways away from us, or up/down for POP/BOUNCE/CATCH),
## hit-stop seconds, extra spin, camera shake.
@export var push := 3.0
@export var hold := 0.1
@export var spin := 0.0
@export var shake := 0.08
@export var puff_color := Color.WHITE
## Scenery drift in local units per second (planes cruise, balloons rise).
@export var drift := Vector3.ZERO

var was_hit := false
var was_near := false
## Set by SkyField: steer toward the ball's path when it comes up from below.
var homing := false
var home_jitter := Vector2.ZERO
var field: Node
## The tier's SkyTier.scale (the root's scale, minus the pop-in).
var size := 1.0

@onready var gag: Node3D = get_node_or_null("Gag")


func _process(delta: float) -> void:
	if not was_hit or reaction == Reaction.BONK:
		position += basis * drift * delta   # basis carries the yaw and the tier scale


func hit_center() -> Vector3:
	return global_transform * hit_offset


func hit_reach() -> float:
	return hit_radius * size


func near_reach() -> float:
	return near_radius * size


func near(_ball: Node3D) -> void:
	if was_near or was_hit:
		return
	was_near = true
	if near_cue != &"":
		_sfx(String(near_cue), null, near_pitch)
	if gag:
		var tw := gag.create_tween()
		tw.tween_property(gag, "position:y", 0.25, 0.1).set_ease(Tween.EASE_OUT)
		tw.tween_property(gag, "position:y", 0.0, 0.25).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_puff(global_position + Vector3.UP * size * 0.6, Color.WHITE, 0.4 * size)


func hit(ball: Node3D) -> void:
	if was_hit:
		return
	was_hit = true
	_sfx(String(cue), null, cue_pitch)
	var away := ball.global_position - hit_center()
	away.y = 0.0
	away = away.normalized() if away.length() > 0.01 else Vector3.BACK
	var p := away * push
	match reaction:
		Reaction.POP:
			p = Vector3.UP * push + away
		Reaction.BOUNCE:
			p = Vector3.DOWN * push + away * 0.5
		Reaction.CATCH:
			p = Vector3.DOWN * push * 0.5
	if ball.has_method("sky_react"):
		ball.sky_react(p, hold, spin)
	if field and field.has_method("shake"):
		field.shake(shake)
	_puff(ball.global_position, puff_color, 0.5 + 0.25 * size)
	match reaction:
		Reaction.POP: _pop()
		Reaction.BONK: _bonk(away)
		Reaction.SCATTER: _scatter()
		Reaction.BOUNCE: _bounce()
		Reaction.SNAG: _snag()
		Reaction.PING: _ping()
		Reaction.CATCH: _catch(ball)


## Audio and Fx by path (like art/scripts/juice.gd), so scenes/sky/build_sky.gd can load this script
## from a bare SceneTree with no autoloads.
func _sfx(cue_name: String, _at = null, pitch: float = 1.0) -> void:
	var audio := get_node_or_null(^"/root/Audio")
	if audio:
		audio.play(cue_name, null, pitch)


func _puff(where: Vector3, color: Color, size: float) -> void:
	var fx := get_node_or_null(^"/root/Fx")
	if fx:
		fx.puff(where, color, size)


func _fx_pop(n: Node3D, amount: float) -> void:
	var fx := get_node_or_null(^"/root/Fx")
	if fx:
		fx.pop(n, amount)


func _parts(prefix: String) -> Array[Node3D]:
	var out: Array[Node3D] = []
	if gag:
		for c in gag.get_children():
			if c is Node3D and String(c.name).begins_with(prefix):
				out.append(c)
	return out


## Balloons burst one after another into confetti; whatever is left (strings, basket) drops away.
func _pop() -> void:
	var tw := create_tween()
	var i := 0
	for b in _parts("Pop"):
		tw.tween_callback(_burst.bind(b))
		if i > 0:
			tw.tween_callback(_sfx.bind(String(cue), null, cue_pitch * (1.1 + 0.08 * i)))
		tw.tween_interval(0.07)
		i += 1
	if gag:
		tw.tween_property(gag, "position", gag.position + Vector3.DOWN * 3.0, 1.2).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(gag, "scale", Vector3.ONE * 0.01, 1.2).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)


func _burst(b: Node3D) -> void:
	var at := b.global_position
	b.visible = false
	_puff(at, Color.WHITE, 0.6 * size)
	_confetti(at, 16)


## Paper bits fly out, flutter down and shrink away.
func _confetti(at: Vector3, n: int) -> void:
	var s := size
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.22, 0.03, 0.15) * s
	for k in n:
		var bit := MeshInstance3D.new()
		bit.mesh = mesh
		var m := StandardMaterial3D.new()
		m.albedo_color = CONFETTI[k % CONFETTI.size()]
		m.emission_enabled = true
		m.emission = m.albedo_color * 0.3
		bit.material_override = m
		bit.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		bit.top_level = true
		add_child(bit)
		bit.global_position = at
		var dir := Vector3(randf_range(-1, 1), randf_range(-0.2, 1), randf_range(-1, 1)).normalized()
		var tw := bit.create_tween().set_parallel()
		tw.tween_property(bit, "global_position", at + dir * s * 1.4, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(bit, "rotation", Vector3(randf() * 9, randf() * 9, randf() * 9), 1.2)
		tw.chain().tween_property(bit, "global_position", at + dir * s * 1.6 + Vector3.DOWN * s * 1.5, 0.85)
		tw.parallel().tween_property(bit, "scale", Vector3.ONE * 0.01, 0.85).set_ease(Tween.EASE_IN)


## "Hey!": a wobble, a little white huff from the cockpit, and on it flies.
func _bonk(away: Vector3) -> void:
	if gag == null:
		return
	var axis := Vector3.UP.cross(away).normalized()
	var tw := gag.create_tween()
	for a in [0.45, -0.3, 0.18, -0.08, 0.0]:
		tw.tween_property(gag, "quaternion", Quaternion(axis, a), 0.12).set_trans(Tween.TRANS_SINE)
	_puff(global_position + Vector3.UP * size * 0.8, Color.WHITE, 0.6 * size)
	_fx_pop(gag, 1.25)


## Every bird flaps off in its own direction, then the flock is gone.
func _scatter() -> void:
	var s := size
	var tw := create_tween().set_parallel()
	for b in _parts("Bird"):
		var dir := Vector3(randf_range(-1, 1), randf_range(0.3, 1), randf_range(-1, 1)).normalized()
		tw.tween_property(b, "position", b.position + dir * 6.0, 1.1).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(b, "rotation:y", atan2(dir.x, dir.z), 0.15)
		tw.tween_property(b, "scale", Vector3.ONE * 0.01, 0.4).set_delay(0.8)
	_puff(global_position, Color(1, 1, 0.95), 0.5 * s)
	tw.chain().tween_callback(queue_free)


## Squish, boing: the cloud (or blimp, or moon) gives like a cushion.
func _bounce() -> void:
	if gag == null:
		return
	var tw := gag.create_tween()
	tw.tween_property(gag, "scale", Vector3(1.3, 0.65, 1.3), 0.09).set_ease(Tween.EASE_OUT)
	tw.tween_property(gag, "scale", Vector3.ONE, 0.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## The string snags: the kite whirls round the ball twice, then tumbles away.
func _snag() -> void:
	if gag == null:
		return
	var tw := gag.create_tween()
	tw.tween_property(gag, "rotation:y", gag.rotation.y + TAU * 2.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(gag, "position", gag.position + Vector3(0, -4, 1), 1.4).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(gag, "rotation:z", 2.5, 1.4)
	tw.parallel().tween_property(gag, "scale", Vector3.ONE * 0.01, 1.4).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)


## Ping! A quick spin and a sparkle.
func _ping() -> void:
	if gag == null:
		return
	var tw := gag.create_tween()
	tw.tween_property(gag, "rotation:y", gag.rotation.y + TAU, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_puff(hit_center(), Color(1, 0.95, 0.5), 0.6 * size)
	_fx_pop(gag, 1.2)


## The alien catches the ball in its beam, holds it a beat, and tosses it back up: wheee.
func _catch(ball: Node3D) -> void:
	var beam := gag.get_node_or_null("Beam") as Node3D if gag else null
	if beam:
		beam.visible = true
	if gag:
		var wob := gag.create_tween()
		wob.tween_property(gag, "rotation:z", 0.3, 0.15)
		wob.tween_property(gag, "rotation:z", -0.2, 0.2)
		wob.tween_property(gag, "rotation:z", 0.0, 0.2)
	var tw := create_tween()
	tw.tween_interval(0.35)
	tw.tween_callback(func() -> void:
		if is_instance_valid(ball) and ball.has_method("sky_react"):
			ball.sky_react(Vector3.UP * push * 2.0, 0.0, 12.0)
		_puff(hit_center(), Color(0.6, 1, 0.6), 0.6 * size))
	tw.tween_interval(0.4)
	tw.tween_callback(func() -> void:
		if beam:
			beam.visible = false)
