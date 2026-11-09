## Field juice: screen shake scaled to kick power, star burst at every tier crossing, speed lines
## while a ball is flying fast. Art lane. Listens to Run (by path) and drives the current camera's
## h/v offsets, so it never fights the camera rig's position.
extends Node3D

const STAR := preload("res://assets/sprites/star.png")
## Run.BASE_POWER: the wimpy round-1 kick shakes a little, a space kick a lot.
const BASE_POWER := 8.0

@export var max_shake := 0.45
@export var speed_for_lines := Vector2(10.0, 45.0)

var _shake := 0.0
var _shake_t := 0.0
var _star_mesh: QuadMesh
var _star_mat: StandardMaterial3D

@onready var lines: ColorRect = $SpeedLines/Rect


func _ready() -> void:
	_star_mesh = QuadMesh.new()
	_star_mesh.size = Vector2(1, 1)
	var run := get_node_or_null("/root/Run")
	if run:
		run.kicked.connect(_on_kicked)
		run.ball_tier_reached.connect(_on_tier)
	lines.material.set_shader_parameter(&"amount", 0.0)


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)
	_shake_t = 0.0


func _on_kicked(_player: int, power: float) -> void:
	var k := clampf(log(maxf(power, 1.0) / BASE_POWER) / log(60.0), 0.0, 1.0)
	shake(lerpf(0.06, max_shake, k))


func _on_tier(player: int, tier: int) -> void:
	var ball := _ball(player)
	if ball:
		burst(ball.global_position, 1.0 + tier * 0.35)
	shake(0.05 + tier * 0.012)


## Stars fly out from `where` and spin away.
func burst(where: Vector3, size: float = 1.0) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = STAR
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var n := 10
	for i in n:
		var s := MeshInstance3D.new()
		s.mesh = _star_mesh
		s.material_override = mat
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(s)
		s.global_position = where
		s.scale = Vector3.ONE * 0.1
		var a := TAU * i / n + randf() * 0.3
		var dir := Vector3(cos(a), sin(a), randf_range(-0.4, 0.4)).normalized()
		var tw := s.create_tween().set_parallel()
		tw.tween_property(s, "global_position", where + dir * 2.2 * size, 0.55).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		tw.tween_property(s, "scale", Vector3.ONE * 0.7 * size, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.chain().tween_property(s, "scale", Vector3.ONE * 0.01, 0.3)
		tw.chain().tween_callback(s.queue_free)
	var fade := create_tween()
	fade.tween_interval(0.45)
	fade.tween_property(mat, "albedo_color:a", 0.0, 0.35)


func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam:
		if _shake > 0.001:
			_shake_t += delta
			var amp := _shake * exp(-_shake_t * 6.0)
			cam.h_offset = sin(_shake_t * 67.0) * amp
			cam.v_offset = cos(_shake_t * 53.0) * amp * 0.8
			if amp < 0.002:
				_shake = 0.0
				cam.h_offset = 0.0
				cam.v_offset = 0.0
	var speed := 0.0
	for p in [0, 1]:
		var b := _ball(p)
		if b and b.visible and b.get("flight") in [1, 2]:   # PHYSICS, SCRIPTED
			speed = maxf(speed, absf(float(b.get("speed"))))
	var want := smoothstep(speed_for_lines.x, speed_for_lines.y, speed)
	if get_viewport().disable_3d:
		want = 0.0
	var cur: float = lines.material.get_shader_parameter(&"amount")
	lines.material.set_shader_parameter(&"amount", move_toward(cur, want, delta * 3.0))


func _ball(player: int) -> Node3D:
	var scene := get_tree().current_scene
	return scene.get_node_or_null("Balls/P%d" % (player + 1)) as Node3D if scene else null
