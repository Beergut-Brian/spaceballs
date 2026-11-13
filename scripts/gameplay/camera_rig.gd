## Full-screen camera for approach / flight / peak / space. The pick's split screen lives in
## upgrade_pick.tscn; split(true) just stops the main viewport drawing 3D underneath it.
extends Node3D

enum Mode { FIELD, FOLLOW, PEAK, SPLIT, SPACE, TEE }

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
## The comedy drop (C-14): a still shot of the tee, the ball falling into it from the top.
@export var tee_look_up := 1.3
@export var tee_shot_scale := 1.15
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
const BEAT_TILT_MIN := 0.12   # rad, about 7 degrees over the target
const BEAT_TILT_MAX := 0.55   # rad, about 32 degrees: over his shoulder, not over his head
## Lawn trees the shot must not sit in or look through: Vector4(x, y, z, radius) spheres.
var occluders: Array[Vector4] = []
## A tree between the lens and the subject whose edge comes within this angle of the view's centre
## crowds the shot (a canopy a metre off the sight line by the lens fills half the screen).
const CROWD_ANGLE := 0.35   # rad, about 20 degrees
## Air kept round a tree when the lens has to be pulled in, and the closest it comes to the subject.
const OCCLUDER_MARGIN := 0.5
const OCCLUDER_MIN_DIST := 2.5
## Swings tried around the subject (rad, nearest first) before pulling in, and how fast it swings.
const SWINGS: Array[float] = [0.0, 0.3, -0.3, 0.6, -0.6, 0.9, -0.9, 1.2, -1.2]
const SWING_RATE := 2.5
var _swing := 0.0
## The other player roaming the field while this one kicks (P-10). In the run-up shot he counts as
## one more occluder (a sphere round his body): a bystander who wanders between the lens and the
## kicker had the kicker's own windup hidden behind him; now the shot swings round him like a tree.
var bystander: Node3D
const BYSTANDER_RADIUS := 0.6
const BYSTANDER_CENTRE := 0.8   # m over his feet: the middle of a Jarling

@onready var camera: Camera3D = $Camera


func _ready() -> void:
	camera.far = 3000.0
	camera.fov = 55.0


## The field's lawn trees (`Dressing/Trees`, its `occluders` meta: crown blobs and trunk spheres from
## art/tools/build_scenes.gd) become occluders. A kicker running past the trees by the field's edge
## had the run-up camera beside a canopy: half the screen leaves.
func set_trees(trees: Node) -> void:
	occluders.clear()
	if not trees is Node3D or not trees.has_meta(&"occluders"):
		return
	var xf := (trees as Node3D).global_transform
	for o: Vector4 in trees.get_meta(&"occluders"):
		var c := xf * Vector3(o.x, o.y, o.z)
		occluders.append(Vector4(c.x, c.y, c.z, o.w))


## How far out along `look` -> `want` the lens can sit before a tree is in the way.
func clear_reach(look: Vector3, want: Vector3) -> float:
	var arm := want - look
	var length := arm.length()
	if occluders.is_empty() or length < 0.01:
		return length
	var dir := arm / length
	var reach := length
	for o in occluders:
		var c := Vector3(o.x, o.y, o.z)
		var r := o.w + OCCLUDER_MARGIN
		var oc := look - c
		if oc.length_squared() <= r * r:
			continue   # he is right by this tree: it is his scenery, nothing to pull in front of
		var b := oc.dot(dir)
		var disc := b * b - (oc.length_squared() - r * r)
		if disc < 0.0:
			continue
		var t := -b - sqrt(disc)
		if t > 0.0 and t < reach:
			reach = t
	return reach


## How close (rad) the nearest tree in front of the subject comes to the middle of the picture; a
## tree round the lens counts as -1. INF when nothing is in the way.
func crowd_gap(look: Vector3, lens: Vector3) -> float:
	var sight := look - lens
	var dist := sight.length()
	if dist < 0.01:
		return INF
	var f := sight / dist
	var gap := INF
	for o in occluders:
		var c := Vector3(o.x, o.y, o.z)
		if c.distance_to(look) < o.w + 1.0:
			continue   # he is standing in this tree: it is his scenery
		var v := c - lens
		var d := v.length()
		if d < o.w + OCCLUDER_MARGIN:
			return -1.0
		var along := v.dot(f)
		if along <= 0.0 or along > dist:
			continue   # behind the lens, or behind him
		gap = minf(gap, acos(clampf(along / d, -1.0, 1.0)) - asin(minf(o.w / d, 1.0)))
	return gap


func crowded(look: Vector3, lens: Vector3) -> bool:
	return crowd_gap(look, lens) < CROWD_ANGLE


## Where the lens can go: `want` pulled in toward `look` until no tree sits in between (a spring
## arm), never closer than OCCLUDER_MIN_DIST.
func clear_view(look: Vector3, want: Vector3) -> Vector3:
	var arm := want - look
	var length := arm.length()
	if length < 0.01:
		return want
	var reach := clear_reach(look, want)
	if reach >= length:
		return want
	return look + arm / length * maxf(reach, OCCLUDER_MIN_DIST)


## The shot swung round `look` to the nearest clear angle (eased over time, `delta` >= 1 snaps),
## then pulled in only if no swing is clear. A tree by the field's edge is walked round, not zoomed
## through.
func swing_clear(look: Vector3, want: Vector3, delta: float) -> Vector3:
	if occluders.is_empty():
		_swing = 0.0
		return want
	var arm := want - look
	var target := _swing
	if crowded(look, look + arm.rotated(Vector3.UP, _swing)):
		# nearest clear swing to the plain shot, ties to the side we are already on; if none is
		# clear (he is right by a tree), the least crowded one
		var best := INF
		var widest := -INF
		var found := false
		for a in SWINGS:
			var g := crowd_gap(look, look + arm.rotated(Vector3.UP, a))
			if g >= CROWD_ANGLE:
				var cost := absf(a) + absf(a - _swing) * 0.5
				if cost < best:
					best = cost
					target = a
					found = true
			elif not found and g > widest + 0.02:
				widest = g
				target = a
	elif _swing != 0.0 and not crowded(look, want):
		target = 0.0   # the way is clear again: drift back to the plain shot
	_swing = lerpf(_swing, target, clampf(delta * SWING_RATE, 0.0, 1.0))
	return clear_view(look, look + arm.rotated(Vector3.UP, _swing))


## The bystander's occluder sphere, or none when there is no bystander on the field.
func bystander_occluder() -> Array[Vector4]:
	var out: Array[Vector4] = []
	if is_instance_valid(bystander) and bystander.is_inside_tree() and bystander.visible \
			and bystander.get(&"roam") == true:
		var c := bystander.global_position + Vector3.UP * BYSTANDER_CENTRE
		out.append(Vector4(c.x, c.y, c.z, BYSTANDER_RADIUS))
	return out


## Frames only this kicker (and his ball on `tee`); the bystander may leave the shot, and the shot
## swings round him when he walks in front of the lens.
func frame_field(kicker: Node3D, tee: Vector3) -> void:
	_kicker = kicker
	_tee = tee
	_lead = Vector3.ZERO
	_lift = 0.0
	_swing = 0.0
	_set_mode(Mode.FIELD)
	_snap()


func frame_close(on: bool) -> void:
	_close = on


func follow(ball: Node3D) -> void:
	_ball = ball
	_dist = follow_min
	_set_mode(Mode.FOLLOW)


## Cut to the tee for the comedy drop (C-14). The flight's peak hold looked at empty sky while the
## ball fell back and bounced on the lawn out of shot: the joke happened where nobody could see it.
func watch_tee(tee: Vector3) -> void:
	_tee = tee
	_swing = 0.0
	_set_mode(Mode.TEE)
	_snap()


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


## Where a beat looks from: the way the camera already is, but never steeper than BEAT_TILT_MAX (a
## close beat from the high field camera looked straight down on his head) nor flatter than
## BEAT_TILT_MIN.
static func beat_dir(from_target: Vector3) -> Vector3:
	var flat := Vector3(from_target.x, 0.0, from_target.z)
	flat = flat.normalized() if flat.length() > 0.01 else Vector3.BACK
	var tilt := atan2(from_target.y, Vector2(from_target.x, from_target.z).length())
	tilt = clampf(tilt, BEAT_TILT_MIN, BEAT_TILT_MAX)
	return flat * cos(tilt) + Vector3.UP * sin(tilt)


func beating() -> bool:
	return _beat_t > 0.0 and is_instance_valid(_beat_target)


func _process(delta: float) -> void:
	if beating() and mode != Mode.SPLIT:
		_beat_t -= delta
		var at := _beat_target.global_position
		var dir := beat_dir(camera.global_position - at)
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
		Mode.TEE:
			want_look = _tee + Vector3.UP * tee_look_up
			want_pos = want_look + field_offset * tee_shot_scale
	if mode == Mode.FIELD or mode == Mode.TEE:
		var extra := bystander_occluder()
		occluders.append_array(extra)
		want_pos = swing_clear(want_look, want_pos, delta)
		occluders.resize(occluders.size() - extra.size())
	elif mode == Mode.SPACE:
		want_pos = clear_view(want_look, want_pos)
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
