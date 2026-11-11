## Full-screen camera for approach / flight / peak / space. The pick's split screen lives in
## upgrade_pick.tscn; split(true) just stops the main viewport drawing 3D underneath it.
extends Node3D

enum Mode { FIELD, FOLLOW, PEAK, SPLIT, SPACE }

signal mode_changed(mode: Mode)

## TV-sports framing: side-on, a little behind the kicker and above.
@export var field_offset := Vector3(7.6, 2.7, 3.8)
## The frog round: in close, so the tiny frog and his pathetic dribble read from the couch.
@export var close_offset := Vector3(4.6, 1.7, 2.6)
@export var follow_offset := Vector3(1.0, 0.15, 0.25)
@export var follow_min := 9.0
@export var follow_max := 70.0
## Extra distance per m/s of ball speed: the zoom-out.
@export var follow_zoom := 0.45
@export var smooth := 6.0
@export_group("Long run-up")
## Seconds of the runner's velocity the shot looks ahead by.
@export var lead_time := 0.5
## Closer than this to his ball the shot widens to hold both; at `both_full` it is the midpoint.
@export var both_from := 12.0
@export var both_full := 5.0
## Big jumps: the shot rises with him, looking this many seconds of vertical speed ahead.
@export var rise_lead := 0.2
## Pull back this much per metre he is up, so the lawn stays in the bottom of the shot.
@export var rise_pullback := 0.06

var mode: Mode = Mode.FIELD
var _kicker: Node3D
var _tee := Vector3.ZERO
var _ball: Node3D
var _center := Vector3.ZERO
var _angle := 0.0
var _dist := 9.0
var _look := Vector3.ZERO
var _close := false
var _orbit_r := 7.0
var _orbit_h := 2.5
var _lead := Vector3.ZERO
var _lift := 0.0
## A curse's camera beat (CurseShow): for a moment the lens moves in on the cause, whatever the mode.
var _beat_target: Node3D
var _beat_t := 0.0
var _beat_dist := 3.2

@onready var camera: Camera3D = $Camera


func _ready() -> void:
	camera.far = 3000.0
	camera.fov = 55.0


## Frames only this kicker (and his ball on `tee`); the bystander may leave the shot.
func frame_field(kicker: Node3D, tee: Vector3) -> void:
	_kicker = kicker
	_tee = tee
	_lead = Vector3.ZERO
	_lift = 0.0
	_set_mode(Mode.FIELD)
	_snap()


func frame_close(on: bool) -> void:
	_close = on


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


func orbit(center: Vector3, radius: float = 7.0, height: float = 2.5, snap: bool = true) -> void:
	_center = center
	_orbit_r = radius
	_orbit_h = height
	get_viewport().disable_3d = false
	_set_mode(Mode.SPACE)
	if snap:
		_angle = 0.0
		_snap()
	else:
		# Glide in from wherever the camera is now.
		var d := camera.global_position - center
		_angle = atan2(d.x, d.z)


## A beat on `target` (the butterflies on the ball, the peel under his foot): `seconds` of close-up,
## `dist` metres out along the current view, then back to whatever the rig was doing.
func beat(target: Node3D, seconds: float = 0.7, dist: float = 3.2) -> void:
	_beat_target = target
	_beat_t = seconds
	_beat_dist = dist


func beating() -> bool:
	return _beat_t > 0.0 and is_instance_valid(_beat_target)


func _process(delta: float) -> void:
	if beating() and mode != Mode.SPLIT:
		_beat_t -= delta
		var at := _beat_target.global_position
		var dir := camera.global_position - at
		dir = dir.normalized() if dir.length() > 0.01 else Vector3.BACK
		var kb := clampf(delta * smooth * 2.5, 0.0, 1.0)
		camera.global_position = camera.global_position.lerp(at + dir * _beat_dist + Vector3.UP * 0.25, kb)
		_look = _look.lerp(at, kb)
		if not camera.global_position.is_equal_approx(_look):
			camera.look_at(_look)
		return
	var want_pos := camera.global_position
	var want_look := _look
	match mode:
		Mode.FIELD:
			if _kicker == null:
				return
			var r := field_frame(delta)
			want_pos = r[0]
			want_look = r[1]
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
			_angle += minf(delta, 0.1) * 0.35   # _snap() passes a huge delta
			want_look = _center + Vector3.UP * 1.0
			want_pos = _center + Vector3(sin(_angle) * _orbit_r, _orbit_h, cos(_angle) * _orbit_r)
		Mode.SPLIT:
			return
	var k := clampf(delta * smooth, 0.0, 1.0)
	if mode == Mode.FOLLOW:
		k = clampf(delta * smooth * 2.0, 0.0, 1.0)
	camera.global_position = camera.global_position.lerp(want_pos, k)
	_look = _look.lerp(want_look, k)
	if not camera.global_position.is_equal_approx(_look):
		camera.look_at(_look)


## [camera position, look-at] for the run-up. Far out: on the runner, a little ahead of him.
## Getting close: widening to hold him and his ball. Jumping high: rising with him.
func field_frame(delta: float) -> Array:
	var k := clampf(delta, 0.0, 1.0)
	var kp := _kicker.global_position
	var v: Vector3 = _kicker.get("velocity") if _kicker.get("velocity") is Vector3 else Vector3.ZERO
	_lead = _lead.lerp(Vector3(v.x, 0.0, v.z) * lead_time, clampf(k * 2.5, 0.0, 1.0))
	var air := maxf(kp.y - _tee.y, 0.0)
	var want_lift := 0.0
	if air > 0.4:
		want_lift = maxf(air + clampf(v.y * rise_lead, -1.0, 1.5), 0.0)
	_lift = lerpf(_lift, want_lift, clampf(k * 4.0, 0.0, 1.0))
	var gap := Vector2(kp.x - _tee.x, kp.z - _tee.z).length()
	var both := clampf((both_from - gap) / (both_from - both_full), 0.0, 1.0)
	var runner := kp + _lead * (1.0 - both)
	var focus := runner.lerp((kp + _tee) * 0.5, both)
	focus.y = _tee.y + (0.6 if _close else 1.0) + _lift
	var off := field_offset * lerpf(1.1, clampf(gap / 7.0, 1.0, 1.6), both)
	if _close:
		# Starts a little wider while he is still far from the tee, then moves in.
		off = close_offset * clampf(gap / 4.0, 1.0, 1.6)
	off *= 1.0 + _lift * rise_pullback
	return [focus + off, focus]


func _snap() -> void:
	set_process(true)
	_process(1000.0)


func _set_mode(m: Mode) -> void:
	mode = m
	mode_changed.emit(m)
