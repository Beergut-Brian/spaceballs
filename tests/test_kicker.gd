## Kicker: run-up quality bounds, and the kid check "a player who only wiggles the stick
## still kicks every round" (within ~10 s), using the real kicker on a flat floor.
class_name TestKicker
extends GdUnitTestSuite

const KICKER := preload("res://scenes/players/kicker.tscn")


func test_run_up_quality_bounds() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 2000:
		var path := rng.randf_range(0.0, 40.0)
		var straight := rng.randf_range(0.0, path)
		var q := Kicker.run_up_quality(path, straight, rng.randf_range(0.0, 10.0), 5.0, rng.randf() < 0.5)
		assert_float(q).is_between(0.8, 1.2)
	# A perfect straight sprint with a hop is the best it gets; a crawl is the floor.
	assert_float(Kicker.run_up_quality(8.0, 8.0, 5.0, 5.0, true)).is_equal_approx(1.2, 0.0001)
	assert_float(Kicker.run_up_quality(8.0, 8.0, 5.0, 5.0, false)).is_equal_approx(1.17, 0.0001)
	assert_float(Kicker.run_up_quality(30.0, 3.0, 0.5, 5.0, false)).is_equal_approx(0.8, 0.0001)
	assert_float(Kicker.run_up_quality(0.0, 0.0, 0.0, 5.0, false)).is_equal_approx(0.8, 0.0001)
	# Straighter and faster is never worse.
	assert_float(Kicker.run_up_quality(10.0, 9.5, 4.0, 5.0, false)) \
			.is_greater(Kicker.run_up_quality(10.0, 7.0, 2.0, 5.0, false))


## Builds floor + kicker + a fake ball position and steps physics until the kicker is within
## kick range (the ball's KickZone radius) or the time runs out. Returns seconds taken.
func _time_to_reach(stick: Callable, seed_: int) -> float:
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
	var k: Kicker = KICKER.instantiate()
	root.add_child(k)
	k.global_position = Vector3(0, 0, 8)
	k._rng.seed = seed_
	k.set_physics_process(false)
	var ball := Vector3(0, 0.35, 0)
	k.begin_approach(ball)
	var t := 0.0
	var step := 1.0 / 60.0
	while t < 20.0:
		var mv: Vector2 = stick.call(t)
		k.stick_override = mv
		k._physics_process(step)
		t += step
		if Vector2(k.global_position.x - ball.x, k.global_position.z - ball.z).length() < 1.1 + 0.35:
			return t
	return t


func test_wiggle_only_still_kicks_within_10_s() -> void:
	var worst := 0.0
	for s in 12:
		var wiggle := func(t: float) -> Vector2:
			return Vector2(sin(t * 11.0 + s), cos(t * 7.0 + s * 2.0))
		worst = maxf(worst, _time_to_reach(wiggle, s))
	print("[kicker] wiggle-only worst time to the ball: %.1f s" % worst)
	assert_float(worst).is_less(10.0)


func test_no_input_still_kicks_within_10_s() -> void:
	var t := _time_to_reach(func(_t: float) -> Vector2: return Vector2.ZERO, 1)
	print("[kicker] hands-off time to the ball: %.1f s" % t)
	assert_float(t).is_less(10.0)


func test_stick_toward_ball_is_quick() -> void:
	# Camera looks along -X, so screen-right is toward the tee (-Z).
	var t := _time_to_reach(func(_t: float) -> Vector2: return Vector2(1, 0), 2)
	print("[kicker] stick-at-ball time: %.1f s" % t)
	assert_float(t).is_less(4.0)
