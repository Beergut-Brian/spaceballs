## P-03 / P-04: per-character run styles (Jeff flails, Chuck stomps), and K-08: a stick wiggle at the
## ball is a toe-poke, a real (short) run-up is the full kick. Real kicker scenes on a flat floor.
class_name TestRunStyle
extends GdUnitTestSuite

const KICKER := preload("res://scenes/players/kicker.tscn")
const BALL := Vector3(0, 0.35, 0)


func before() -> void:
	SettingsSandbox.enter("user://test_settings_run_style.json")


func after() -> void:
	SettingsSandbox.leave()


func before_test() -> void:
	PhysicsPin.enter()   # fixed 60 Hz step, seeded RNG, no curse left in Run by another suite
	await get_tree().physics_frame


func after_test() -> void:
	PhysicsPin.leave()


# --- the styles -----------------------------------------------------------------------

func test_jeff_and_chuck_have_their_own_styles() -> void:
	var jeff := RunStyle.for_character("jeff")
	var chuck := RunStyle.for_character("chuck")
	var other := RunStyle.for_character("zorp")   # no file: the plain jog
	assert_object(other).is_same(RunStyle.for_character(""))
	# Jeff: arms right round, a flapping comb, a bigger bob than the plain jog, no stomp.
	assert_bool(jeff.windmill).is_true()
	assert_float(jeff.flap).is_greater(0.3)
	assert_float(jeff.bob).is_greater(other.bob)
	assert_float(jeff.stomp).is_equal(0.0)
	# Chuck: stiff arms, slower heavy steps, a stomp with a hard landing.
	assert_bool(chuck.windmill).is_false()
	assert_float(chuck.arm_keep).is_less(0.5)
	assert_float(chuck.cadence).is_less(jeff.cadence)
	assert_float(chuck.stomp).is_equal(1.0)
	assert_float(chuck.land_squash).is_greater(0.0)


func test_stomp_lifts_slow_and_drops_hard() -> void:
	var chuck := RunStyle.for_character("chuck")
	var jeff := RunStyle.for_character("jeff")
	# Chuck is highest late in the step, then falls: the last 15 % loses more than the first 15 % gains.
	assert_float(chuck.lift(0.7, 1.0)).is_equal_approx(chuck.bob, 0.001)
	assert_float(chuck.lift(0.7, 1.0) - chuck.lift(0.85, 1.0)).is_greater(chuck.lift(0.15, 1.0) - chuck.lift(0.0, 1.0))
	assert_float(chuck.lift(1.0, 1.0)).is_equal_approx(0.0, 0.001)
	# Jeff's bounce is round: same both sides of the top.
	assert_float(jeff.lift(0.25, 1.0)).is_equal_approx(jeff.lift(0.75, 1.0), 0.001)
	# Standing still, no bob from the style.
	assert_float(chuck.lift(0.7, 0.0)).is_equal(0.0)


func test_chuck_stomps_with_a_landing_and_jeff_does_not() -> void:
	var chuck := await _runner("res://scenes/players/chuck.tscn")
	var jeff := await _runner("res://scenes/players/jeff.tscn")
	var hard := {"chuck": [], "jeff": []}
	chuck.footfall.connect(func(h: float) -> void: hard.chuck.append(h))
	jeff.footfall.connect(func(h: float) -> void: hard.jeff.append(h))
	var squashed := false
	for i in 90:
		for k: Kicker in [chuck, jeff]:
			k.stick_override = Vector2(0, 1)   # across the field, never at the ball
			k._physics_process(1.0 / 60.0)
		var rig := chuck.body.get_node("Jarling") as Node3D
		if rig.scale.y < 0.95:
			squashed = true
	assert_int(hard.chuck.size()).is_greater_equal(3)
	assert_float(hard.chuck.max()).is_greater(0.5)
	assert_bool(squashed).is_true()
	assert_int(hard.jeff.size()).is_greater(hard.chuck.size())   # quicker little steps
	assert_float(hard.jeff.max()).is_equal(0.0)


func test_jeff_windmills_and_chuck_keeps_his_arms_stiff() -> void:
	var turned := {}
	for path in ["res://scenes/players/jeff.tscn", "res://scenes/players/chuck.tscn"]:
		var k := await _runner(path)
		var skel: Skeleton3D = k.body.get_node("Jarling/Model").find_child("Skeleton3D", true, false)
		assert_object(skel.get_node_or_null("RunStyle")).is_not_null()
		var arm := skel.find_bone("arm.L")
		var angles: Array[float] = []
		skel.skeleton_updated.connect(_arm_angle.bind(skel, arm, angles))
		for i in 100:
			k.stick_override = Vector2(0, 1)
			k._physics_process(1.0 / 60.0)
			await get_tree().process_frame
		# How far the arm went round the shoulder (front-back), in total, while running.
		var total := 0.0
		var widest := 0.0
		for i in range(36, angles.size()):
			total += wrapf(angles[i] - angles[i - 1], -PI, PI)
			widest = maxf(widest, absf(wrapf(angles[i] - angles[35], -PI, PI)))
		turned[path.get_file()] = [absf(total), widest]
	print("[run_style] arm turn (total, widest): ", turned)
	assert_float(turned["jeff.tscn"][0]).is_greater(TAU)     # right round, more than once
	assert_float(turned["chuck.tscn"][0]).is_less(1.0)       # back and forth, never round
	assert_float(turned["chuck.tscn"][1]).is_less(1.0)       # a stiff little pump


func _arm_angle(skel: Skeleton3D, arm: int, out: Array[float]) -> void:
	var d := skel.get_bone_global_pose(arm).basis.y
	out.append(atan2(d.z, d.y))


# --- K-08: a wiggle is a toe-poke ------------------------------------------------------

func test_wiggle_at_the_ball_is_a_toe_poke_that_still_kicks() -> void:
	# Stick at the ball on and off, four times a second: he creeps there, but never runs.
	var k := await _runner("res://scenes/players/jeff.tscn", Vector3(0, 0, 8))
	var t := _reach(k, _wiggle)
	assert_float(t).is_less(20.0)   # still gets there: a kid who only wiggles still kicks
	assert_bool(k.has_run_up()).is_false()
	var q := await _kick(k)
	assert_bool(k.poking).is_true()
	assert_float(q).is_equal(Kicker.QUALITY_MIN)


func test_nudge_from_standing_next_to_it_is_a_toe_poke() -> void:
	var k := await _runner("res://scenes/players/chuck.tscn", Vector3(0, 0, 2.0))
	_reach(k, _at_ball)
	assert_bool(k.has_run_up()).is_false()
	assert_float(await _kick(k)).is_equal(Kicker.QUALITY_MIN)
	assert_bool(k.poking).is_true()


func test_short_real_run_up_is_the_full_kick() -> void:
	# Wander about first (free roam), then a straight run of about four metres.
	var k := await _runner("res://scenes/players/jeff.tscn", Vector3(0, 0, 5.0))
	var t := _reach(k, _at_ball)
	assert_float(t).is_less(2.0)
	assert_bool(k.has_run_up()).is_true()
	var q := await _kick(k)
	assert_bool(k.poking).is_false()
	assert_float(q).is_greater(1.0)


func test_poke_never_replaces_a_gag_or_the_frog() -> void:
	var k := await _runner("res://scenes/players/jeff.tscn", Vector3(0, 0, 2.0))
	var gag := UpgradeData.new()
	gag.windup_anim = &"sneeze"
	k.windup = gag
	k.begin_approach(BALL)
	_reach(k, _at_ball)
	await _kick(k)
	assert_bool(k.poking).is_false()


# --- helpers -----------------------------------------------------------------------------

## Stick at the ball (screen-right with the test camera) on and off, four times a second.
func _wiggle(t: float) -> Vector2:
	return Vector2(1, 0) if fmod(t, 0.25) < 0.1 else Vector2.ZERO


func _at_ball(_t: float) -> Vector2:
	return Vector2(1, 0)


func _runner(path: String, at := Vector3(0, 0, 8)) -> Kicker:
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
	var k: Kicker = load(path).instantiate()
	root.add_child(k)
	k.global_position = at
	k.bounds = Rect2(-50, -50, 100, 100)
	k.set_physics_process(false)
	k.begin_approach(BALL)
	await get_tree().physics_frame
	k._physics_process(1.0 / 60.0)   # settle on the floor
	return k


## Steps the kicker with `stick(t)` until he is in kick range of BALL. Returns seconds taken.
func _reach(k: Kicker, stick: Callable) -> float:
	var t := 0.0
	while t < 20.0:
		k.stick_override = stick.call(t)
		k._physics_process(1.0 / 60.0)
		t += 1.0 / 60.0
		if Vector2(k.global_position.x - BALL.x, k.global_position.z - BALL.z).length() < 1.1 + 0.35:
			return t
	return t


## Starts the wind-up and waits for the foot to meet the ball. Returns the run-up quality.
func _kick(k: Kicker) -> float:
	var got := [-1.0]
	k.kick_contact.connect(func(q: float) -> void: got[0] = q)
	k.start_windup()
	var waited := 0.0
	while got[0] < 0.0 and waited < Kicker.KICK_DEADLINE + 1.0:
		await get_tree().process_frame
		k._physics_process(1.0 / 60.0)
		waited += 1.0 / 60.0
	assert_float(got[0]).is_greater(0.0)
	return got[0]
