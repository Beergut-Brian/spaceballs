## Sideline crowd of generic Jarlings: idles, and cheers for a few seconds on every kick and
## every tier the ball crosses. Art lane. Reads the Run autoload by path (no hard dependency).
extends Node3D

const EXPR_HAPPY := Vector3(0.5, 0, 0)
const EXPR_NEUTRAL := Vector3.ZERO

var _members: Array = []   # [AnimationPlayer, face material, cheer time left]
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 7
	for child in get_children():
		var ap := child.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if ap == null:
			continue
		for a in [&"idle", &"cheer"]:
			if ap.has_animation(a):
				ap.get_animation(a).loop_mode = Animation.LOOP_LINEAR
		var face: StandardMaterial3D
		for mi in child.find_children("*", "MeshInstance3D", true, false):
			for s in mi.mesh.get_surface_count():
				var m := mi.mesh.surface_get_material(s) as StandardMaterial3D
				if m == null:
					continue
				if m.resource_name.ends_with("_face"):
					face = m.duplicate()
					face.rim_enabled = true
					face.rim = 0.45
					mi.set_surface_override_material(s, face)
				else:
					m.rim_enabled = true
					m.rim = 0.45
					m.rim_tint = 0.3
		ap.play(&"idle")
		ap.seek(_rng.randf() * 2.0, true)
		ap.speed_scale = _rng.randf_range(0.85, 1.15)
		_members.append([ap, face, 0.0])
	var run := get_node_or_null("/root/Run")
	if run:
		# The kick itself: scenes/main.gd scales the reaction (scripts/gameplay/crowd_reactions.gd).
		run.ball_tier_reached.connect(func(_p: int, _t: int) -> void: cheer(2.0))
		run.reached_space.connect(func(_p: int) -> void: cheer(6.0))


func cheer(seconds: float) -> void:
	for m in _members:
		# A ragged start reads as a real crowd.
		m[2] = maxf(m[2], seconds + _rng.randf() * 0.4)


func _process(delta: float) -> void:
	for m in _members:
		var ap: AnimationPlayer = m[0]
		m[2] = maxf(m[2] - delta, 0.0)
		var want := &"cheer" if m[2] > 0.0 else &"idle"
		if ap.current_animation != String(want):
			ap.play(want, 0.2)
			if m[1]:
				m[1].uv1_offset = EXPR_HAPPY if m[2] > 0.0 else EXPR_NEUTRAL
