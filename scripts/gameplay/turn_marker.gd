## Whose turn it is, without a word: a big bobbing arrow in the kicker's colour over his head
## (above the whole gear pile) and a pulsing ring of the same colour round his ball. Gameplay lane.
class_name TurnMarker
extends Node3D

const ARROW_GAP := 0.7

var _kicker: Node3D
var _t := 0.0
var _top := 2.0
var _arrow: Node3D
var _ring: MeshInstance3D
var _mats: Array[StandardMaterial3D] = []


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
	hide_marker()


func show_for(kicker: Node3D, tee: Vector3, color: Color) -> void:
	_kicker = kicker
	_t = 0.0
	_top = 2.0
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


func hide_marker() -> void:
	visible = false
	if _ring:
		_ring.visible = false
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
	_ring.scale = Vector3(1.0, 1.0, 1.0) * (1.0 + 0.12 * sin(_t * 5.0))


func _part(mesh: PrimitiveMesh, at: Vector3) -> MeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.emission_enabled = true
	mat.emission_energy_multiplier = 0.6
	mat.rim_enabled = true
	mesh.material = mat
	_mats.append(mat)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = at
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
