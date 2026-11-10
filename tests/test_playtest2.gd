## Playtest 2026-11-09 #2: the long run-up (and the kick still fires on contact at the end of it),
## the bystander who can't kick, the banana peel from further out, the snap-to-kick on a low hop
## over the ball (and flying over on a high one), the curse flip, and the crowd's scaled reaction.
class_name TestPlaytest2
extends GdUnitTestSuite

const P1 := Players.P1
const P2 := Players.P2

var _main: Node
var _setup_cb: Callable


func before() -> void:
	SettingsSandbox.enter()



func after() -> void:
	SettingsSandbox.leave()

func before_test() -> void:
	Run.phase = Run.Phase.IDLE
	Players._device_of = {P1: -1, P2: -1}
	Game._set_state(Game.State.TITLE)
	Run.save_enabled = false
	Run.demo = true
	Engine.time_scale = 8.0


func after_test() -> void:
	if _setup_cb.is_valid() and Run.run_started.is_connected(_setup_cb):
		Run.run_started.disconnect(_setup_cb)
	if is_instance_valid(_main):
		_main.free()
	Engine.time_scale = 1.0
	Run.demo = false
	Game.demo = false
	Run.save_enabled = true
	Run.phase = Run.Phase.IDLE
	Players._device_of = {P1: -1, P2: -1}
	Game._set_state(Game.State.TITLE)
	get_tree().root.get_viewport().disable_3d = false
	await get_tree().physics_frame
	await get_tree().physics_frame


## Simulated seconds (physics ticks); returns how long it took, or -1.
func _wait_for(cond: Callable, seconds: float, each: Callable = Callable()) -> float:
	var waited := 0.0
	while waited < seconds:
		if cond.call():
			return waited
		if each.is_valid():
			each.call()
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()
	return -1.0


func _boot(on_start: Callable = func() -> void: pass) -> void:
	_setup_cb = on_start
	Run.run_started.connect(_setup_cb)
	_main = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(_main)


## Steer `k` like a pad pushed straight at `to` (the stick is camera-relative).
func _steer(k: Kicker, to: Vector3) -> void:
	var cam := k.get_viewport().get_camera_3d()
	var d := Vector3(to.x - k.global_position.x, 0.0, to.z - k.global_position.z).normalized()
	var right := Vector3(cam.global_basis.x.x, 0.0, cam.global_basis.x.z).normalized()
	var fwd := Vector3(-cam.global_basis.z.x, 0.0, -cam.global_basis.z.z).normalized()
	# out = right * x - fwd * y  =>  solve the 2x2 for (x, y)
	var det := right.x * -fwd.z - (-fwd.x) * right.z
	var x := (d.x * -fwd.z - (-fwd.x) * d.z) / det
	var y := (right.x * d.z - d.x * right.z) / det
	k.stick_override = Vector2(x, y).limit_length(1.0)


func _take_over(k: Kicker) -> void:
	k.bot = false
	k._bot_goals.clear()


func test_long_run_up_then_kick_on_contact(timeout := 120000) -> void:
	await _boot()
	assert_float(await _wait_for(func(): return Run.phase == Run.Phase.KICK_P1, 3.0)).is_not_equal(-1.0)
	var jeff: Kicker = _main.kickers[P1]
	var ball: Node3D = _main.balls[P1]
	_take_over(jeff)
	var dist := Vector2(jeff.global_position.x - ball.global_position.x, jeff.global_position.z - ball.global_position.z).length()
	var kicked := []
	Run.kicked.connect(func(p, _power): kicked.append(p))
	var t := await _wait_for(func(): return Run.phase != Run.Phase.KICK_P1 or jeff.state != Kicker.State.APPROACH,
			15.0, func(): _steer(jeff, ball.global_position))
	print("[playtest2] run-up: %.1f m in %.2f s at base speed" % [dist, t])
	assert_float(dist).is_greater(25.0)
	# Kaden: "way further away" -> about 5 to 7 seconds of running at base speed.
	assert_float(t).is_between(5.0, 7.0)
	jeff.stick_override = Vector2.ZERO
	# Contact with his own ball still kicks.
	assert_float(await _wait_for(func(): return kicked.has(P1), 6.0)).is_not_equal(-1.0)


func test_bystander_roams_with_gear_and_cannot_kick(timeout := 120000) -> void:
	var rocket := load("res://data/upgrades/rocket_boots.tres") as UpgradeData
	await _boot(func() -> void: Run.give(P2, rocket))
	assert_float(await _wait_for(func(): return Run.phase == Run.Phase.KICK_P1, 3.0)).is_not_equal(-1.0)
	var jeff: Kicker = _main.kickers[P1]
	var chuck: Kicker = _main.kickers[P2]
	_take_over(jeff)
	jeff.stick_override = Vector2.ZERO
	# Free to run, with his gear: the rocket boots' flame trail and their speed.
	assert_bool(chuck.roam).is_true()
	assert_bool((chuck.effects.get(&"run_fx", []) as Array).has(&"flame")).is_true()
	assert_float(chuck.effects.get(&"run_speed_mult", 1.0)).is_greater(1.0)
	# His own ball is not on its tee: nothing of his to kick.
	assert_bool(_main.balls[P2].visible).is_false()
	assert_bool(_main.balls[P2].is_armed()).is_false()
	# Running into Jeff's ball does nothing but a bump.
	var started := []
	Run.kick_started.connect(func(p): started.append(p))
	_take_over(chuck)
	var ball: Node3D = _main.balls[P1]
	var closest := [99.0]
	await _wait_for(func(): return false, 2.5, func() -> void:
		_steer(chuck, ball.global_position)
		closest[0] = minf(closest[0], Vector2(chuck.global_position.x - ball.global_position.x,
				chuck.global_position.z - ball.global_position.z).length()))
	assert_float(closest[0]).is_less(1.1)   # right up against it
	assert_array(started).is_empty()
	assert_int(Run.phase).is_equal(Run.Phase.KICK_P1)
	assert_bool(ball.is_armed()).is_true()
	assert_int(chuck.state).is_equal(Kicker.State.CHEER)


func test_low_hop_over_the_ball_snaps_in_front_and_kicks(timeout := 120000) -> void:
	await _boot()
	assert_float(await _wait_for(func(): return Run.phase == Run.Phase.KICK_P1, 3.0)).is_not_equal(-1.0)
	var jeff: Kicker = _main.kickers[P1]
	var ball: Node3D = _main.balls[P1]
	_take_over(jeff)
	jeff.stick_override = Vector2.ZERO
	var b := ball.global_position
	var ground: float = b.y - 0.35
	# Mid-hop, half a metre over the top of the ball, coming in along -Z.
	jeff.global_position = Vector3(b.x, ground + 1.15, b.z + 0.4)
	jeff.velocity = Vector3(0, 0.5, -5.0)
	var t := await _wait_for(func(): return jeff.state != Kicker.State.APPROACH, 0.5)
	assert_float(t).is_not_equal(-1.0)
	# Snapped down in front of the ball (the side he came from) and kicking.
	assert_float(jeff.global_position.y - ground).is_less(0.3)
	assert_float(jeff.global_position.z - b.z).is_between(0.4, 1.0)


func test_high_jump_flies_over_the_ball(timeout := 120000) -> void:
	await _boot()
	assert_float(await _wait_for(func(): return Run.phase == Run.Phase.KICK_P1, 3.0)).is_not_equal(-1.0)
	var jeff: Kicker = _main.kickers[P1]
	var ball: Node3D = _main.balls[P1]
	_take_over(jeff)
	jeff.stick_override = Vector2.ZERO
	var b := ball.global_position
	var ground: float = b.y - 0.35
	# A jetpack hop: three metres up, going fast.
	jeff.global_position = Vector3(b.x, ground + 3.0, b.z + 0.6)
	jeff.velocity = Vector3(0, 2.0, -6.0)
	await _wait_for(func(): return false, 0.45, func(): _steer(jeff, b + Vector3(0, 0, -10)))
	assert_int(jeff.state).is_equal(Kicker.State.APPROACH)
	assert_bool(ball.is_armed()).is_true()
	assert_float(jeff.global_position.z).is_less(b.z - 1.0)   # sailed right over


func test_banana_peel_slips_him_a_few_metres_out(timeout := 120000) -> void:
	var peel := load("res://data/upgrades/banana_peel.tres") as UpgradeData
	await _boot(func() -> void: Run._active_curse[P1] = peel)
	assert_float(await _wait_for(func(): return Run.phase == Run.Phase.KICK_P1, 3.0)).is_not_equal(-1.0)
	var jeff: Kicker = _main.kickers[P1]
	var ball: Node3D = _main.balls[P1]
	_take_over(jeff)
	var tee := ball.global_position
	var at_slip := []
	jeff.slipped.connect(func() -> void:
		at_slip.append(Vector2(jeff.global_position.x - tee.x, jeff.global_position.z - tee.z).length()))
	var stops := []
	Run.ball_stopped.connect(func(p, h, _t): if p == P1: stops.append(h))
	await _wait_for(func(): return not at_slip.is_empty(), 15.0, func(): _steer(jeff, tee))
	jeff.stick_override = Vector2.ZERO
	assert_array(at_slip).has_size(1)
	# Stepped on it well before the ball...
	assert_float(at_slip[0]).is_between(2.5, 4.5)
	assert_int(jeff.state).is_equal(Kicker.State.GAG)
	# ...slid into it, and the ball dribbled a pathetic distance.
	assert_float(await _wait_for(func(): return not stops.is_empty(), 10.0)).is_not_equal(-1.0)
	var slid := Vector2(jeff.global_position.x - tee.x, jeff.global_position.z - tee.z).length()
	assert_float(slid).is_less(1.5)
	assert_float(stops[0]).is_less(1.0)
	var moved := Vector2(ball.global_position.x - tee.x, ball.global_position.z - tee.z).length()
	assert_float(moved).is_between(0.5, 3.0)


func test_curse_reveal_flips_the_picked_card(timeout := 60000) -> void:
	var pick: Control = load("res://scenes/ui/upgrade_pick.tscn").instantiate()
	add_child(pick)
	var r := Run
	r._ensure_data()
	var normals: Array[UpgradeData] = []
	normals.assign(r.pool.filter(func(c): return c.kind == "normal").slice(0, 3))
	var sneeze := r.upgrade_by_id(&"sneeze")
	Run.demo = false
	pick.open({P1: normals}, [P1])
	var card: Control = pick.cards_of(P1)[1]
	assert_object(card.upgrade).is_equal(normals[1])
	Engine.time_scale = 4.0
	await pick.reveal_curse(P1, sneeze)
	assert_object(card.upgrade).is_equal(sneeze)
	assert_bool(card.flipping).is_false()
	pick.close()
	pick.free()


func test_crowd_reaction_scales_with_the_kick() -> void:
	const L := CrowdReactions.Level
	assert_int(CrowdReactions.kick_level(3, 3, 0.9, false)).is_equal(L.CLAP)
	assert_int(CrowdReactions.kick_level(4, 3, 0.9, false)).is_equal(L.GREAT)
	assert_int(CrowdReactions.kick_level(3, 3, 1.15, false)).is_equal(L.GREAT)
	assert_int(CrowdReactions.kick_level(5, 3, 1.2, true)).is_equal(L.NONE)
	# The Jarlings on the sideline actually move, and a great kick sends hats up.
	var crowd := Node3D.new()
	for i in 4:
		var m := Node3D.new()
		m.position = Vector3(0, 0, i)
		crowd.add_child(m)
	add_child(crowd)
	var cr := CrowdReactions.new()
	add_child(cr)
	cr.setup(crowd)
	cr.react(L.CLAP)
	await await_millis(400)
	var clap_top := 0.0
	for m in cr._members:
		clap_top = maxf(clap_top, m.position.y)
	cr.react(L.GREAT)
	assert_int(crowd.get_child_count()).is_greater(4)   # hats
	var great_top := 0.0
	for i in 40:
		await get_tree().process_frame
		for m in cr._members:
			great_top = maxf(great_top, m.position.y)
	assert_float(clap_top).is_greater(0.0)
	assert_float(great_top).is_greater(clap_top)
	cr.react(L.AWW)
	assert_int(cr.last_level).is_equal(L.AWW)
	cr.free()
	crowd.free()


func test_main_roars_at_a_new_tier_and_awws_a_curse(timeout := 120000) -> void:
	await _boot()
	assert_float(await _wait_for(func(): return Run.phase == Run.Phase.KICK_P1, 3.0)).is_not_equal(-1.0)
	var cr: CrowdReactions = _main._crowd
	assert_object(cr.crowd).is_not_null()
	Run._set_phase(Run.Phase.FLIGHT_P1)
	_main._on_tier_reached(P1, 2)
	assert_int(cr.last_level).is_equal(CrowdReactions.Level.ROAR)
	Run._active_curse[P1] = Run.upgrade_by_id(&"sneeze")
	_main._on_ball_stopped(P1, 0.3, 1)
	assert_int(cr.last_level).is_equal(CrowdReactions.Level.AWW)
	Run._active_curse[P1] = null
