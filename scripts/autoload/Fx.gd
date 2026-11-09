## Placeholder visuals so every action has one (CLAUDE.md rule 7). Autoload: Fx.
## Art replaces the insides with particles and shaders; keep the calls. Systems lane owns.
extends Node

const PUFF_TIME := 0.35


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## A sphere that swells and fades: dust puff, star burst, kick flash.
func puff(where: Vector3, color: Color = Color.WHITE, size: float = 1.0) -> void:
	var root := get_tree().current_scene
	if root == null:
		return
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 12
	sphere.rings = 6
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	sphere.material = mat
	mesh.mesh = sphere
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mesh)
	mesh.global_position = where
	mesh.scale = Vector3.ONE * 0.2 * size
	var tw := mesh.create_tween().set_parallel()
	tw.tween_property(mesh, "scale", Vector3.ONE * 1.6 * size, PUFF_TIME).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, PUFF_TIME)
	tw.chain().tween_callback(mesh.queue_free)


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
