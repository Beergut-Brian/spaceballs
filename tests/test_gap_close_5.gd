## gap-close-5 (2026-11-10): the curse rows the re-audit ranked top (U-16 the cause on screen at the
## bite, U-17 the "that's why", U-18 the badge) were built by sb-curses-1, but frames on dev showed
## the cursed kick's dust cloud hiding him and the butterflies, the wind-up beat aimed at his feet
## (butterfly and badge off the top of the frame), and the that's-why icon under the tier stamp.
class_name TestGapClose5
extends GdUnitTestSuite

const JEFF := preload("res://scenes/players/jeff.tscn")
const BALL := preload("res://scenes/ball.tscn")
const RIG := preload("res://scripts/gameplay/camera_rig.gd")
const CameraRigScript := RIG


func before_test() -> void:
	Run._ensure_data()


func after_test() -> void:
	Engine.time_scale = 1.0
	await Audio.stop_all()


func _curses() -> Array[UpgradeData]:
	var out: Array[UpgradeData] = []
	out.assign(Run.pool.filter(func(c: UpgradeData) -> bool: return c.is_curse()))
	return out


## Floor + Jeff + a CurseShow whose rig records beats. [k, show, rig, root]
func _setup() -> Array:
	var root := Node3D.new()
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60, 1, 60)
	shape.shape = box
	floor_body.add_child(shape)
	floor_body.position = Vector3(0, -0.5, 0)
	root.add_child(floor_body)
	add_child(root)
	auto_free(root)
	var k: Kicker = JEFF.instantiate()
	root.add_child(k)
	var show := CurseShow.new()
	var rig := BeatRig.new()
	root.add_child(rig)
	show.rig = rig
	root.add_child(show)
	return [k, show, rig, root]


func test_a_cursed_kick_raises_only_a_wisp_of_dust() -> void:
	var k: Kicker = auto_free(JEFF.instantiate())
	add_child(k)
	k.windup = null
	assert_float(k.contact_dust()).is_equal(1.2)   # a normal kick: the full cloud
	for c in _curses():
		k.windup = c
		assert_float(k.contact_dust()).override_failure_message(String(c.id)).is_less_equal(0.3)
	k.windup = Run.pool.filter(func(c: UpgradeData) -> bool: return not c.is_curse())[0]
	assert_float(k.contact_dust()).is_equal(1.2)


func test_the_windup_beat_frames_his_chest_or_the_cause_never_his_feet() -> void:
	for c in _curses():
		var bits := _setup()
		var k: Kicker = bits[0]
		var show: CurseShow = bits[1]
		var rig: BeatRig = bits[2]
		await get_tree().physics_frame
		show.windup(0, k, null, c)
		assert_int(rig.beats.size()).override_failure_message("%s: no beat" % c.id).is_equal(1)
		var target: Node3D = rig.beats[0][0]
		assert_float(target.global_position.y - k.global_position.y) \
				.override_failure_message("%s: beat at his feet" % c.id).is_greater(0.6)


func test_the_butterfly_windup_beat_holds_still_on_his_chest() -> void:
	var bits := _setup()
	var k: Kicker = bits[0]
	var rig: BeatRig = bits[2]
	var bug := Node3D.new()   # the butterfly he chases circles his head: never the camera's target
	bits[3].add_child(bug)
	k._prop = bug
	(bits[1] as CurseShow).windup(0, k, null, Run.upgrade_by_id(&"butterfly"))
	assert_object(rig.beats[0][0]).is_same(k.attach_point(&"body"))
	k._prop = null


func test_butterflies_riding_the_ball_are_big_enough_to_see() -> void:
	var bits := _setup()
	var show: CurseShow = bits[1]
	var ball: Node3D = BALL.instantiate()
	bits[3].add_child(ball)
	ball.global_position = Vector3(0, 0.35, -1.0)
	var c := Run.upgrade_by_id(&"butterfly")
	var plain := show._prop(c, 1.0)
	auto_free(plain)
	show.bite(0, bits[0], ball, c)
	var bugs: Array = show._riders[0]
	assert_int(bugs.size()).is_equal(3)
	for bug in bugs:
		assert_float((bug as Node3D).scale.x).is_greater_equal(plain.scale.x * 1.5)
	show.clear_all()


func test_the_thats_why_camera_looks_over_the_icon_clear_of_the_stamp() -> void:
	var bits := _setup()
	var show: CurseShow = bits[1]
	var rig: BeatRig = bits[2]
	var ball: Node3D = BALL.instantiate()
	bits[3].add_child(ball)
	ball.global_position = Vector3(0, 0.35, -1.0)
	var why := show.callback(0, ball, Run.upgrade_by_id(&"sneeze"))
	assert_int(rig.beats.size()).is_equal(1)
	var look: Node3D = rig.beats[0][0]
	assert_object(look.get_parent()).is_same(why)
	assert_float(look.global_position.y - why.global_position.y).is_equal_approx(CurseShow.CALLBACK_LOOK_UP, 0.01)
	assert_float(CurseShow.CALLBACK_LOOK_UP).is_greater(0.4)


## A close beat from the high field camera looked straight down on his head (hiccups and butterfly
## wind-up frames); it now comes in over his shoulder.
func test_a_beat_from_high_above_comes_in_over_the_shoulder() -> void:
	var rig: Node3D = RIG.new()
	var cam := Camera3D.new()
	cam.name = "Camera"
	rig.add_child(cam)
	add_child(rig)
	auto_free(rig)
	var target := Node3D.new()
	rig.add_child(target)
	target.global_position = Vector3(0, 0.9, 0)
	cam.global_position = Vector3(0, 14, 1.0)   # nearly overhead
	rig.beat(target, 1.0, 3.4)
	await get_tree().create_timer(0.8).timeout
	var d := cam.global_position - target.global_position
	var tilt := rad_to_deg(atan2(d.y, Vector2(d.x, d.z).length()))
	assert_float(tilt).is_less(36.0)
	assert_float(tilt).is_greater(5.0)
	assert_float(d.length()).is_between(2.5, 5.0)
	# Level views keep their side: a beat from behind stays behind.
	assert_vector(CameraRigScript.beat_dir(Vector3(0, 1, 6))).is_equal_approx(Vector3(0, 1, 6).normalized(), Vector3.ONE * 0.01)


## U-18: in the close beat on his chest the badge sits beside his head, inside the frame, even over
## a tall gear pile; over his head again once the beat lets go.
func test_the_badge_stays_in_frame_during_the_close_beat() -> void:
	var bits := _setup()
	var root: Node3D = bits[3]
	var k: Kicker = bits[0]
	(bits[1] as Node).queue_free()   # its stand-in rig can't beat; this one uses the real rig
	var rig: Node3D = RIG.new()
	var cam := Camera3D.new()
	cam.name = "Camera"
	rig.add_child(cam)
	root.add_child(rig)
	cam.make_current()
	cam.global_position = Vector3(0, 6, 12)
	var show := CurseShow.new()
	show.rig = rig
	show.height_of = func(_k: Node3D) -> float: return 3.0   # a tall pile of gear
	root.add_child(show)
	await get_tree().process_frame
	show.badge(0, k, Run.upgrade_by_id(&"sneeze"))
	await get_tree().create_timer(0.4).timeout
	assert_float(show.badge_of(0).global_position.y).is_greater(3.0)   # over his head
	show.windup(0, k, null, Run.upgrade_by_id(&"sneeze"))
	await get_tree().create_timer(0.6).timeout
	assert_bool(rig.beating()).is_true()
	var b := show.badge_of(0)
	assert_bool(cam.is_position_in_frustum(b.global_position)).is_true()
	var px := cam.unproject_position(b.global_position)
	var vp := get_viewport().get_visible_rect().size
	assert_bool(Rect2(Vector2.ZERO, vp).has_point(px)).override_failure_message("badge at %s" % px).is_true()
	await get_tree().create_timer(0.6).timeout
	assert_bool(rig.beating()).is_false()
	await get_tree().create_timer(0.4).timeout
	assert_float(show.badge_of(0).global_position.y).is_greater(3.0)
	show.clear_all()


## Stands in for the camera rig: records every beat.
class BeatRig:
	extends Node
	var beats: Array = []
	func beat(target: Node3D, seconds: float = 0.7, dist: float = 3.2) -> void:
		beats.append([target, seconds, dist])
