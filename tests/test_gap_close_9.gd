## Gap-close lane 9 (PLAN-STATUS.md): the space moment, the run's big payoff, in real frames.
## C-16: the orbiting ball stays in shot (it slid off the bottom of the TV on the near side of its
## loop) and gets a longer look. C-17 / V-13: the dance shot is from in front of him (it showed his
## back for the whole two seconds).
class_name TestGapClose9
extends GdUnitTestSuite

const P1 := Players.P1
const P2 := Players.P2
## Keep the whole ball this far (degrees) inside the top and bottom of the picture.
const EDGE_MARGIN_DEG := 3.0

var _main: Node


func before() -> void:
	SettingsSandbox.enter("user://test_gap_close_9_settings.json")


func after() -> void:
	SettingsSandbox.leave()
	await Audio.stop_all()


func before_test() -> void:
	Run.stop_run()
	PhysicsPin.enter()


func after_test() -> void:
	if is_instance_valid(_main):
		_main.free()
	Run.demo = false
	Game.demo = false
	Run.save_enabled = true
	Run.phase = Run.Phase.IDLE
	Run.stop_run()
	PhysicsPin.leave()


func _boot_main() -> Node:
	Run.save_enabled = false
	Run.demo = true
	_main = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(_main)
	await get_tree().process_frame
	await get_tree().process_frame
	return _main


func _send_to_space(main: Node, p: int) -> Node:
	Run.start_run()
	Run._in_space[p] = true
	var ball: Node = main.balls[p]
	ball.height = 200000.0
	ball.peak_height = 200000.0
	ball._reach_peak()
	main._on_ball_stopped(p, ball.peak_height, 8)
	return ball


# --- C-16: the ball floats in space, in shot ------------------------------------------------

func test_the_space_orbit_keeps_the_ball_in_shot() -> void:
	var main: Node = await _boot_main()
	var ball: Node = _send_to_space(main, P1)
	var rig: Node = main.rig
	assert_vector(rig._center).is_equal_approx(ball.orbit_center, Vector3.ONE * 0.001)
	var cam: Camera3D = rig.camera
	# The TV's picture: the vertical field of view, and the 16:9 horizontal one it gives.
	var half_v := deg_to_rad(cam.fov * 0.5)
	var half_h := atan(tan(half_v) * 16.0 / 9.0)
	var margin := deg_to_rad(EDGE_MARGIN_DEG)
	var radius: float = ball.RADIUS * ball.mesh.scale.x
	# Every camera angle on its slow circle against every place on the ball's loop.
	for i in 24:
		var a := TAU * i / 24.0
		var cpos: Vector3 = rig._center + Vector3(sin(a) * rig._orbit_r, rig._orbit_h, cos(a) * rig._orbit_r)
		var look: Vector3 = rig._center + Vector3.UP * rig._orbit_look
		var view := Transform3D.IDENTITY.looking_at(look - cpos, Vector3.UP)
		for j in 24:
			var b := TAU * j / 24.0
			var at: Vector3 = ball.orbit_center + ball._orbit_offset(b)
			var local := view.basis.inverse() * (at - cpos)   # camera space: -z ahead
			var depth := -local.z
			assert_float(depth).is_greater(radius)
			var size := asin(clampf(radius / local.length(), 0.0, 1.0))
			var up := absf(atan2(local.y, depth)) + size
			var side := absf(atan2(local.x, depth)) + size
			assert_bool(up < half_v - margin and side < half_h - margin).override_failure_message(
				"camera %d deg, ball %d deg: the ball leaves the picture (%.0f / %.0f deg off the middle)" \
				% [i * 15, j * 15, rad_to_deg(up), rad_to_deg(side)]).is_true()


func test_the_ball_floats_in_space_for_a_good_look() -> void:
	var main: Node = await _boot_main()
	var ball: Node = _send_to_space(main, P1)
	assert_int(ball.flight).is_equal(ball.Flight.FLOATING)
	assert_float(ball._return_in).is_equal_approx(ball.SPACE_ORBIT_SHOW, 0.001)
	assert_float(ball.SPACE_ORBIT_SHOW).is_greater_equal(3.0)


# --- C-17 / V-13: the victory dance, seen from the front -------------------------------------

func test_the_dance_shot_starts_in_front_of_him() -> void:
	var main: Node = await _boot_main()
	_send_to_space(main, P1)
	Run.phase = Run.FLIGHT_PHASE[P1]
	for yaw in [0.0, 0.9, PI, -2.1]:
		var k: Node3D = main.kickers[P1]
		k.rotation.y = yaw
		main._on_ball_returned(P1)   # the dance part of the space moment (it waits on a timer)
		var facing := -k.global_basis.z
		var to_cam: Vector3 = main.rig.camera.global_position - k.global_position
		to_cam.y = 0.0
		assert_float(facing.normalized().dot(to_cam.normalized())) \
				.override_failure_message("yaw %.1f: the camera is not in front of him" % yaw) \
				.is_greater(0.85)
