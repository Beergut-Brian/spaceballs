## Kicker: run-up quality bounds and the free run, using the real kicker on a flat floor.
class_name TestKicker
extends GdUnitTestSuite

const KICKER := preload("res://scenes/players/kicker.tscn")


## move_and_slide() uses the engine's last physics delta, so start from a clean 1x frame
## (another suite may have run with a time scale).
func before_test() -> void:
	PhysicsPin.enter()   # fixed 60 Hz step, seeded RNG, no curse left in Run by another suite
	await get_tree().physics_frame
	await get_tree().physics_frame


func after_test() -> void:
	PhysicsPin.leave()


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
	k._phase = float(seed_) * 0.73
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


func test_no_input_stays_put() -> void:
	# Free roam (playtest 2026-11-09): no auto-steer, so hands off means he stands still.
	var t := _time_to_reach(func(_t: float) -> Vector2: return Vector2.ZERO, 1)
	assert_float(t).is_greater_equal(20.0)


func test_stick_toward_ball_is_quick() -> void:
	# Camera looks along -X, so screen-right is toward the tee (-Z).
	var t := _time_to_reach(func(_t: float) -> Vector2: return Vector2(1, 0), 2)
	print("[kicker] stick-at-ball time: %.1f s" % t)
	assert_float(t).is_less(4.0)


func test_frog_mode_hides_upgrades_and_comes_back() -> void:
	var k: Kicker = auto_free(KICKER.instantiate())
	add_child(k)
	var u := UpgradeData.new()
	u.id = &"big_boot"
	u.kind = "normal"
	u.power_mult = 1.7
	k.add_upgrade_visual(u)
	assert_int(k.attach_point(&"head").get_child_count()).is_equal(1)
	k.set_frog(true, load("res://scenes/curses/frog.tscn"))
	assert_bool(k.frog).is_true()
	assert_bool(k.body.visible).is_false()
	assert_bool(k.attach.visible).is_false()
	assert_int(k.frog_slot.get_child_count()).is_equal(1)
	k.set_frog(false)
	assert_bool(k.body.visible).is_true()
	assert_bool(k.attach.visible).is_true()
	assert_int(k.attach_point(&"head").get_child_count()).is_equal(1)


func test_attach_points_exist() -> void:
	var k: Kicker = auto_free(KICKER.instantiate())
	add_child(k)
	for slot in Kicker.SLOTS:
		assert_object(k.attach_point(slot)).is_not_null()
		assert_str(k.attach_point(slot).name).is_equal(String(slot).capitalize())


func test_jeff_and_chuck_are_on_the_right_side() -> void:
	var jeff: Kicker = auto_free(load("res://scenes/players/jeff.tscn").instantiate())
	var chuck: Kicker = auto_free(load("res://scenes/players/chuck.tscn").instantiate())
	assert_int(jeff.player).is_equal(Players.P1)
	assert_int(chuck.player).is_equal(Players.P2)
