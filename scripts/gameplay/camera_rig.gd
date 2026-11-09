# PLACEHOLDER (systems grey-box): Gameplay owns the camera phases and replaces this; keep the API.
## Full-screen camera for approach / flight / peak / space. The pick's split screen lives in
## upgrade_pick.tscn; split(true) just stops the main viewport drawing 3D underneath it.
extends Node3D

enum Mode { FIELD, FOLLOW, PEAK, SPLIT, SPACE }

signal mode_changed(mode: Mode)

## TV-sports framing: side-on, a little behind the kicker and above.
@export var field_offset := Vector3(9.5, 3.2, 4.5)
@export var follow_offset := Vector3(1.0, 0.15, 0.25)
@export var follow_min := 9.0
@export var follow_max := 70.0
## Extra distance per m/s of ball speed: the zoom-out.
@export var follow_zoom := 0.45
@export var smooth := 6.0

var mode: Mode = Mode.FIELD
var _kicker: Node3D
var _tee := Vector3.ZERO
var _ball: Node3D
var _center := Vector3.ZERO
var _angle := 0.0
var _dist := 9.0
var _look := Vector3.ZERO

@onready var camera: Camera3D = $Camera


func _ready() -> void:
	camera.far = 3000.0
	camera.fov = 55.0


func frame_field(kicker: Node3D, tee: Vector3) -> void:
	_kicker = kicker
	_tee = tee
	_set_mode(Mode.FIELD)
	_snap()


func follow(ball: Node3D) -> void:
	_ball = ball
	_dist = follow_min
	_set_mode(Mode.FOLLOW)


func hold_peak() -> void:
	_set_mode(Mode.PEAK)


func split(on: bool) -> void:
	get_viewport().disable_3d = on
	if on:
		_set_mode(Mode.SPLIT)
	elif mode == Mode.SPLIT:
		_set_mode(Mode.FIELD)


func orbit(center: Vector3) -> void:
	_center = center
	_angle = 0.0
	get_viewport().disable_3d = false
	_set_mode(Mode.SPACE)
	_snap()


func _process(delta: float) -> void:
	var want_pos := camera.global_position
	var want_look := _look
	match mode:
		Mode.FIELD:
			if _kicker == null:
				return
			var mid := (_kicker.global_position + _tee) * 0.5 + Vector3.UP * 1.0
			want_pos = mid + field_offset
			want_look = mid
		Mode.FOLLOW:
			if _ball == null:
				return
			var speed: float = absf(_ball.get("speed")) if _ball.get("speed") != null else 0.0
			_dist = lerpf(_dist, clampf(follow_min + speed * follow_zoom, follow_min, follow_max), delta * 2.0)
			want_look = _ball.global_position
			want_pos = want_look + follow_offset.normalized() * _dist
		Mode.PEAK:
			return
		Mode.SPACE:
			_angle += delta * 0.35
			want_look = _center + Vector3.UP * 1.0
			want_pos = _center + Vector3(sin(_angle) * 7.0, 2.5, cos(_angle) * 7.0)
		Mode.SPLIT:
			return
	var k := clampf(delta * smooth, 0.0, 1.0)
	if mode == Mode.FOLLOW:
		k = clampf(delta * smooth * 2.0, 0.0, 1.0)
	camera.global_position = camera.global_position.lerp(want_pos, k)
	_look = _look.lerp(want_look, k)
	if not camera.global_position.is_equal_approx(_look):
		camera.look_at(_look)


func _snap() -> void:
	set_process(true)
	_process(1000.0)


func _set_mode(m: Mode) -> void:
	mode = m
	mode_changed.emit(m)
