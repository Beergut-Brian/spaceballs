## Gap-close lane 7 (2026-11-12): rough spots found in real frames of a demo run.
## C-14: the comedy drop (the ball falls back onto its tee and bounces twice, thud, thud) happened
## out of shot: the camera held the empty sky at the peak, a green arrow pointing down. Now the shot
## cuts to the tee when the drop starts, unless a cursed flight's "that's why" pop is still up.
extends GdUnitTestSuite

const P1 := Players.P1
const RIG := preload("res://scripts/gameplay/camera_rig.gd")
const TEE := Vector3(2, 0, 0)

var _main: Node


func before() -> void:
	SettingsSandbox.enter("user://test_gap_close_7_settings.json")


func after() -> void:
	SettingsSandbox.leave()
	await Audio.stop_all()


func after_test() -> void:
	if is_instance_valid(_main):
		_main.free()
	Run.save_enabled = true
	Run.demo = false
	Game.demo = false
	Run.phase = Run.Phase.IDLE
	Run.stop_run()
	Run._clear()
	Game._set_state(Game.State.TITLE)
	get_tree().root.get_viewport().disable_3d = false
	Engine.time_scale = 1.0


func _rig() -> Node3D:
	var rig := Node3D.new()
	rig.set_script(RIG)
	var cam := Camera3D.new()
	cam.name = "Camera"
	rig.add_child(cam)
	add_child(rig)
	auto_free(rig)
	return rig


## The tee shot sees the ball resting on the tee and the last stretch of its fall above it.
func test_tee_shot_sees_the_ball_land_and_bounce() -> void:
	var rig := _rig()
	rig.camera.global_position = Vector3(0, 300, 0)   # up at the peak
	rig.hold_peak()
	rig.watch_tee(TEE)
	assert_int(rig.mode).is_equal(RIG.Mode.TEE)
	var cam: Camera3D = rig.camera
	assert_float(cam.global_position.distance_to(TEE)).is_less(14.0)   # a cut, not a slow swoop
	for h in [0.3, 1.1 + 0.3, 3.0]:   # on the tee, the first bounce's top, falling in
		var at: Vector3 = TEE + Vector3.UP * h
		assert_bool(cam.is_position_in_frustum(at)).override_failure_message("%.1f m over the tee is out of shot" % h).is_true()
		# Near the middle, not at an edge: within the middle 70 % of the picture.
		var px := cam.unproject_position(at) / get_viewport().get_visible_rect().size
		assert_float(px.x).is_between(0.15, 0.85)
		assert_float(px.y).is_between(0.15, 0.85)


func _boot_main() -> Node:
	Run.save_enabled = false
	_main = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(_main)
	await get_tree().process_frame
	await get_tree().process_frame
	return _main


## In the real game: an uncursed flight's drop cuts to the tee; the ball is in the shot.
func test_the_drop_cuts_to_the_tee(timeout := 60000) -> void:
	var main := await _boot_main()
	var rig: Node3D = main.rig
	var ball: Node3D = main.balls[P1]
	ball.place_on_tee(main._marker("Tees", P1))
	rig.camera.global_position = Vector3(0, 300, 0)
	rig.hold_peak()
	Run.phase = Run.Phase.FLIGHT_P1
	ball._drop()
	assert_int(rig.mode).is_equal(RIG.Mode.TEE)
	var tee: Vector3 = main._marker("Tees", P1)
	assert_bool(rig.camera.is_position_in_frustum(tee + Vector3.UP * 0.3)).is_true()


## A cursed flight keeps its shot: the curse icon popping over the landing spot stays on screen.
func test_a_cursed_drop_keeps_the_that_s_why_shot(timeout := 60000) -> void:
	var main := await _boot_main()
	var rig: Node3D = main.rig
	var ball: Node3D = main.balls[P1]
	ball.place_on_tee(main._marker("Tees", P1))
	rig.hold_peak()
	Run._active_curse[P1] = Run.upgrade_by_id(&"sneeze")
	assert_bool(Run.curse_of(P1).is_curse()).is_true()
	Run.phase = Run.Phase.FLIGHT_P1
	ball._drop()
	assert_int(rig.mode).is_equal(RIG.Mode.PEAK)


## Outside its own flight (the lobby, a test calling _drop) the camera is left alone.
func test_a_drop_outside_the_flight_leaves_the_camera(timeout := 60000) -> void:
	var main := await _boot_main()
	var rig: Node3D = main.rig
	rig.hold_peak()
	Run.phase = Run.Phase.IDLE
	main.balls[P1]._drop()
	assert_int(rig.mode).is_equal(RIG.Mode.PEAK)
