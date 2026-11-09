## Placeholder visuals so every action has one (CLAUDE.md rule 7). Autoload: Fx.
## Art replaces the insides with particles and shaders; keep the calls. Systems lane owns.
extends Node

const PUFF_TIME := 0.35
const PUFF_BALLS := 7

var _puff_mesh: SphereMesh


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## A cartoon puff: a little cluster of soft balls that bursts out, swells and fades.
## Dust on the kick, sparkle at a tier, poof for the frog. (Art lane insides, Systems' call.)
func puff(where: Vector3, color: Color = Color.WHITE, size: float = 1.0) -> void:
	var root := get_tree().current_scene
	if root == null:
		return
	if _puff_mesh == null:
		_puff_mesh = SphereMesh.new()
		_puff_mesh.radius = 0.5
		_puff_mesh.height = 1.0
		_puff_mesh.radial_segments = 16
		_puff_mesh.rings = 8
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	mat.roughness = 1.0
	mat.rim_enabled = true
	mat.rim = 0.6
	mat.emission_enabled = true
	mat.emission = color * 0.35
	var n := PUFF_BALLS
	for i in n:
		var mesh := MeshInstance3D.new()
		mesh.mesh = _puff_mesh
		mesh.material_override = mat
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mesh)
		var a := TAU * i / n + randf() * 0.5
		var dir := Vector3(cos(a), randf_range(0.15, 0.6), sin(a)).normalized()
		mesh.global_position = where
		mesh.scale = Vector3.ONE * 0.15 * sqrt(size)
		var big := randf_range(0.45, 0.8) * sqrt(size)
		var tw := mesh.create_tween().set_parallel()
		tw.tween_property(mesh, "global_position", where + dir * 0.75 * size, PUFF_TIME * 1.6).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		tw.tween_property(mesh, "scale", Vector3.ONE * big, PUFF_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.chain().tween_property(mesh, "scale", Vector3.ONE * big * 0.2, PUFF_TIME)
		tw.chain().tween_callback(mesh.queue_free)
	var fade := root.create_tween()
	fade.tween_interval(PUFF_TIME * 0.8)
	fade.tween_property(mat, "albedo_color:a", 0.0, PUFF_TIME * 1.2)


## A quick white blink on a Control or Node2D.
func flash(item: CanvasItem, color: Color = Color.WHITE) -> void:
	if item == null or not item.is_inside_tree():
		return
	var tw := item.create_tween()
	tw.tween_property(item, "modulate", color * 2.0, 0.05)
	tw.tween_property(item, "modulate", Color.WHITE, 0.15)


## Squash-and-stretch on a 3D node, back to its current scale.
func pop(node: Node3D, amount: float = 1.3) -> void:
	if node == null or not node.is_inside_tree():
		return
	if not node.has_meta(&"fx_base_scale"):
		node.set_meta(&"fx_base_scale", node.scale)
	var base: Vector3 = node.get_meta(&"fx_base_scale")
	var tw := node.create_tween()
	tw.tween_property(node, "scale", Vector3(base.x * amount, base.y / amount, base.z * amount), 0.06)
	tw.tween_property(node, "scale", base, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
