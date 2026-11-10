## Free movement (playtest 2026-11-09): the kicker goes where the stick says and nowhere else, the
## field's soft wall keeps him in, roaming first costs nothing, and gear changes how he runs.
class_name TestFreeRoam
extends GdUnitTestSuite

const KICKER := preload("res://scenes/players/kicker.tscn")
const STEP := 1.0 / 60.0

var _k: Kicker


func before_test() -> void:
	Engine.time_scale = 1.0
	await get_tree().physics_frame
	await get_tree().physics_frame


## Floor, a camera looking along -X (screen-right = -Z), and a kicker at (0, 0, 8); ball at origin.
func _setup(fx: Dictionary = {}) -> Kicker:
	var root := Node3D.new()
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200, 1, 200)
	shape.shape = box
	floor_body.add_child(shape)
	floor_body.position = Vector3(0, -0.5, 0)
	root.add_child(floor_body)
	var cam := Camera3D.new()
	root.add_child(cam)
	add_child(root)
	auto_free(root)
	cam.global_position = Vector3(9.5, 4, 4)
	cam.look_at(Vector3(0, 1, 4))
	cam.current = true
	_k = KICKER.instantiate()
	root.add_child(_k)
	_k.global_position = Vector3(0, 0, 8)
	_k.set_physics_process(false)
	_k.effects = fx
	_k.begin_approach(Vector3(0, 0.35, 0))
	return _k


func _run(stick: Vector2, seconds: float) -> void:
	_k.stick_override = stick
	var t := 0.0
	while t < seconds:
		_k._physics_process(STEP)
		t += STEP


func test_no_auto_steer_with_no_input() -> void:
	_setup()
	var from := _k.global_position
	_run(Vector2.ZERO, 4.0)
	assert_float(Vector2(_k.global_position.x - from.x, _k.global_position.z - from.z).length()).is_less(0.05)


func test_runs_away_from_the_ball_when_told() -> void:
	_setup()
	_k.global_position.z = 3.0
	_run(Vector2(-1, 0), 1.0)   # screen-left = +Z, away from the ball
	assert_float(_k.global_position.z).is_greater(5.5)
	_run(Vector2.ZERO, 1.0)
	var z := _k.global_position.z
	_run(Vector2.ZERO, 1.0)
	assert_float(absf(_k.global_position.z - z)).is_less(0.05)   # stops, no drift back


func test_turns_on_the_spot() -> void:
	_setup()
	_run(Vector2(0, -1), 0.15)   # a quick tap: turns to face it before getting anywhere
	var yaw := _k.rotation.y
	_run(Vector2(0, 1), 0.3)
	assert_float(absf(angle_difference(yaw, _k.rotation.y))).is_greater(2.0)


func test_soft_wall_keeps_him_on_the_field() -> void:
	_setup()
	for stick in [Vector2(-1, 0), Vector2(0, -1), Vector2(1, 0), Vector2(0, 1)]:
		_run(stick, 6.0)
		var p := Vector2(_k.global_position.x, _k.global_position.z)
		assert_bool(_k.bounds.grow(0.01).has_point(p)).override_failure_message("out at %s" % p).is_true()


func test_rocket_boots_run_faster() -> void:
	_setup()
	_k.global_position.z = 0.0
	_run(Vector2(-1, 0), 0.8)
	var plain := _k.global_position.z
	_setup({&"run_speed_mult": 1.4, &"accel_mult": 1.3, &"run_fx": [&"flame"] as Array[StringName]})
	_k.global_position.z = 0.0
	_run(Vector2(-1, 0), 0.8)
	assert_float(_k.global_position.z).is_greater(plain * 1.2)


func test_spring_shoes_hop_higher() -> void:
	var peak := func(fx: Dictionary) -> float:
		_setup(fx)
		_run(Vector2.ZERO, 0.3)
		_k._hop(1.0)
		var top := 0.0
		for i in 90:
			_k._physics_process(STEP)
			top = maxf(top, _k.global_position.y)
		return top
	var plain: float = peak.call({})
	assert_float(peak.call({&"jump_mult": 1.5})).is_greater(plain * 1.5)
	assert_float(peak.call({&"gravity_mult": 0.4})).is_greater(plain * 2.0)   # Moon Gravity


func test_roaming_first_costs_nothing() -> void:
	_setup()
	# A long silly wander round the field...
	_run(Vector2(-1, 0), 1.5)
	_run(Vector2(0, 1), 1.0)
	_run(Vector2(1, 1), 1.0)
	# ...then a straight sprint at the ball: the run-up is judged on the run-in only.
	var q := 0.0
	for i in 600:
		var d := Vector3(0, 0, 0) - _k.global_position
		d.y = 0.0
		if d.length() < 1.3:
			q = _k._quality_now()
			break
		_k.stick_override = null
		_k.bot = true   # straight at the ball
		_k._bot_goals.clear()
		_k._physics_process(STEP)
	assert_float(q).is_greater(1.1)


func test_runup_bonus_lifts_a_lazy_run() -> void:
	_setup()
	_run(Vector2(1, 0), 0.4)
	var plain := _k._quality_now()
	_k.effects = {&"runup_bonus": 0.15}
	assert_float(_k._quality_now()).is_equal_approx(minf(plain + 0.15, 1.2), 0.0001)
