## Whose turn it is, without a word: a big bobbing arrow in the kicker's colour over his head
## (above the whole gear pile) and a pulsing ring of the same colour round his ball. Gameplay lane.
class_name TurnMarker
extends Node3D

const ARROW_GAP := 0.7
## Further than this from his ball, a big arrow on the grass points the way and the ring glows.
const FAR := 4.5

var _kicker: Node3D
var _t := 0.0
var _top := 2.0
var _arrow: Node3D
var _ring: MeshInstance3D
var _mats: Array[StandardMaterial3D] = []
var _ball: Node3D
var _pointer: Node3D
var _far_t := 0.0
var _last_d := 0.0


func _ready() -> void:
	_arrow = Node3D.new()
	add_child(_arrow)
	var head := CylinderMesh.new()   # a cone pointing down
	head.top_radius = 0.42
	head.bottom_radius = 0.0
	head.height = 0.55
	head.radial_segments = 24
	var shaft := CylinderMesh.new()
	shaft.top_radius = 0.17
	shaft.bottom_radius = 0.17
	shaft.height = 0.5
	shaft.radial_segments = 16
	_arrow.add_child(_part(head, Vector3.ZERO))
	_arrow.add_child(_part(shaft, Vector3.UP * 0.5))
	var torus := TorusMesh.new()
	torus.inner_radius = 0.62
	torus.outer_radius = 0.8
	torus.rings = 48
	torus.ring_segments = 8
	_ring = _part(torus, Vector3.ZERO)
	_ring.top_level = true
	add_child(_ring)
	# The way-home arrow: lies flat on the grass by his feet, tip toward the ball.
	_pointer = Node3D.new()
	_pointer.top_level = true
	add_child(_pointer)
	var tip := CylinderMesh.new()
	tip.top_radius = 0.0
	tip.bottom_radius = 0.38
	tip.height = 0.6
	tip.radial_segments = 16
	var tail := BoxMesh.new()
	tail.size = Vector3(0.26, 0.08, 0.6)
	var t := _part(tip, Vector3(0, 0.12, -0.3))
	t.rotation.x = -PI * 0.5
	_pointer.add_child(t)
	_pointer.add_child(_part(tail, Vector3(0, 0.12, 0.3)))
	hide_marker()


func show_for(kicker: Node3D, tee: Vector3, color: Color) -> void:
	_kicker = kicker
	_t = 0.0
	_top = 1.0 if kicker.get(&"frog") else 2.0
	var attach := kicker.get_node_or_null("Attach")
	for vi in (attach.find_children("*", "VisualInstance3D", true, false) if attach else []):
		var v := vi as VisualInstance3D
		if v.is_visible_in_tree() and not (v is CPUParticles3D or v is GPUParticles3D):
			_top = maxf(_top, (v.global_transform * v.get_aabb()).end.y - kicker.global_position.y)
	_top = minf(_top, 6.0)
	for m in _mats:
		m.albedo_color = color
		m.emission = color
	_ring.global_position = tee + Vector3.UP * 0.04
	visible = true
	_ring.visible = true
	set_process(true)
	_process(0.0)


## The ball this turn is about (the way-home arrow points at it).
func set_ball(ball: Node3D) -> void:
	_ball = ball


func hide_marker() -> void:
	visible = false
	_ball = null
	if _ring:
		_ring.visible = false
	if _pointer:
		_pointer.visible = false
	set_process(false)


func _process(delta: float) -> void:
	_t += delta
	if not is_instance_valid(_kicker):
		hide_marker()
		return
	# Pops in, then bobs: hard to miss from the couch.
	var grow := clampf(_t / 0.25, 0.0, 1.0)
	_arrow.scale = Vector3.ONE * lerpf(0.01, 1.0, grow) * (1.0 + 0.08 * sin(_t * 8.0))
	_arrow.global_position = _kicker.global_position + Vector3.UP * (_top + ARROW_GAP + 0.18 * absf(sin(_t * 4.0)))
	_arrow.rotation.y = _t * 1.5
	var far := 0.0
	if is_instance_valid(_ball):
		var d := _ball.global_position - _kicker.global_position
		d.y = 0.0
		far = clampf((d.length() - FAR) / 2.0, 0.0, 1.0)
		_pointer.visible = far > 0.0
		if _pointer.visible:
			_pointer.global_position = _kicker.global_position + d.normalized() * (1.3 + 0.15 * sin(_t * 8.0))
			_pointer.rotation = Vector3(0.0, atan2(-d.x, -d.z), 0.0)
			_pointer.scale = Vector3.ONE * far
			# Every few seconds out there and not heading in, the ball calls him back: a ping.
			_far_t = 0.0 if d.length() < _last_d - 0.002 else _far_t + delta
			_last_d = d.length()
			if _far_t > 3.0:
				_far_t = 0.0
				Audio.play("orbit_chime", null, 1.3)
		else:
			_far_t = 2.0
	_ring.scale = Vector3(1.0, 1.0, 1.0) * (1.0 + 0.12 * sin(_t * 5.0)) * (1.0 + 0.6 * far)


func _part(mesh: PrimitiveMesh, at: Vector3) -> MeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.emission_enabled = true
	mat.emission_energy_multiplier = 0.6
	mat.rim_enabled = true
	# A white outline so a green arrow still pops against the green lawn and blue sky.
	var outline := StandardMaterial3D.new()
	outline.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	outline.cull_mode = BaseMaterial3D.CULL_FRONT
	outline.grow = true
	outline.grow_amount = 0.05
	outline.albedo_color = Color.WHITE
	mat.next_pass = outline
	mesh.material = mat
	_mats.append(mat)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = at
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
