## The ball's look: beach-ball panels in the player's colour, a face that reacts (calm on the tee,
## shocked at launch, happy in flight and at the peak), squash-and-stretch, and a ribbon trail.
## Art lane. Child of Ball; reads ball.flight / ball.player, never writes gameplay state.
extends Node3D

const FACES := preload("res://assets/sprites/ball_faces.png")
const SHADER := preload("res://art/shaders/ball.gdshader")
## Ball.Flight: TEE, PHYSICS, SCRIPTED, PEAK, DROP, FLOATING
const TEE := 0
const PHYSICS := 1
const SCRIPTED := 2
const PEAK := 3
const DROP := 4
const POPS := [Color("ffd84d"), Color("38c6ff")]   # palette pop panel per player
const ACCENTS := [Color("3cc24a"), Color("e4393c")]
const TRAIL_POINTS := 10

@export var trail_width := 0.2

var _ball: Node3D
var _mesh: MeshInstance3D
var _mat: ShaderMaterial
var _flight := -1
var _in_state := 0.0
var _points: PackedVector3Array = []
var _trail: MeshInstance3D
var _imm: ImmediateMesh
var _tw: Tween


func _ready() -> void:
	_ball = get_parent()
	_mesh = _ball.get_node("Mesh")
	_imm = ImmediateMesh.new()
	_trail = MeshInstance3D.new()
	_trail.mesh = _imm
	_trail.top_level = true
	_trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var tm := StandardMaterial3D.new()
	tm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	tm.disable_fog = true
	tm.vertex_color_use_as_albedo = true
	tm.cull_mode = BaseMaterial3D.CULL_DISABLED
	_trail.material_override = tm
	add_child(_trail)
	_setup.call_deferred()   # after Ball._ready, which sets a placeholder material_override


func _setup() -> void:
	var p: int = clampi(int(_ball.get("player")), 0, 1)
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter(&"faces", FACES)
	_mat.set_shader_parameter(&"accent", ACCENTS[p])
	_mat.set_shader_parameter(&"pop", POPS[p])
	_mesh.material_override = _mat
	_trail.global_transform = Transform3D.IDENTITY


func _process(delta: float) -> void:
	if _mat == null:
		return
	var f: int = _ball.get("flight")
	_in_state += delta
	if f != _flight:
		_on_flight(_flight, f)
		_flight = f
		_in_state = 0.0
	var expr := 0.0
	match f:
		PHYSICS, SCRIPTED:
			expr = 1.0 if _in_state < 0.6 else 2.0
		PEAK, 5:
			expr = 2.0
		DROP:
			expr = 1.0
	_mat.set_shader_parameter(&"expr", expr)
	_update_trail(f == PHYSICS or f == SCRIPTED)


func _on_flight(from: int, to: int) -> void:
	if to == PHYSICS:
		_pop(Vector3(1.35, 0.65, 1.35), Vector3(0.75, 1.35, 0.75))
	elif to == TEE and from == DROP:
		_pop(Vector3(1.4, 0.6, 1.4), Vector3(0.9, 1.1, 0.9))


func _pop(a: Vector3, b: Vector3) -> void:
	if _tw and _tw.is_valid():
		_tw.kill()
	_tw = create_tween()
	_tw.tween_property(_mesh, "scale", a, 0.05)
	_tw.tween_property(_mesh, "scale", b, 0.1)
	_tw.tween_property(_mesh, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _update_trail(flying: bool) -> void:
	if flying:
		_points.append(_ball.global_position)
		if _points.size() > TRAIL_POINTS:
			_points.remove_at(0)
	elif not _points.is_empty():
		_points.remove_at(0)   # the tail catches up and vanishes
	_imm.clear_surfaces()
	var cam := get_viewport().get_camera_3d()
	if _points.size() < 2 or cam == null:
		return
	var tint: Color = ACCENTS[clampi(int(_ball.get("player")), 0, 1)].lerp(Color.WHITE, 0.6)
	_imm.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var n := _points.size()
	for i in n:
		var p := _points[i]
		var nxt := _points[mini(i + 1, n - 1)]
		var prv := _points[maxi(i - 1, 0)]
		var dir := (nxt - prv).normalized()
		var side := dir.cross(cam.global_position - p).normalized()
		var u := float(i) / float(n - 1)   # 0 tail .. 1 head
		var w := trail_width * u
		var c := tint
		c.a = u * u * 0.45
		_imm.surface_set_color(c)
		_imm.surface_add_vertex(p + side * w)
		_imm.surface_set_color(c)
		_imm.surface_add_vertex(p - side * w)
	_imm.surface_end()
