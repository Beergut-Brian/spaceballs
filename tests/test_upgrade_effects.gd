## Upgrades change the play (playtest 2026-11-09): every card has a felt or seen effect and a body
## slot, gear you have is never offered again, a new item in a slot replaces the old one's look
## while the power still adds up, and the kick only starts on the kicker's own ball.
class_name TestUpgradeEffects
extends GdUnitTestSuite

const RunScript := preload("res://scripts/autoload/Run.gd")
const KICKER := preload("res://scenes/players/kicker.tscn")

var _runs: Array[Node] = []
var _main: Node


func before() -> void:
	SettingsSandbox.enter()



func after() -> void:
	SettingsSandbox.leave()

func before_test() -> void:
	PhysicsPin.enter()   # fixed 60 Hz step, seeded RNG, no curse left in Run by another suite


func after_test() -> void:
	PhysicsPin.leave()
	for r in _runs:
		r.free()
	_runs.clear()
	if is_instance_valid(_main):
		_main.free()
		Engine.time_scale = 1.0
		Run.demo = false
		Run.save_enabled = true
		Run.phase = Run.Phase.IDLE
		Players._device_of = {Players.P1: -1, Players.P2: -1}
		Game._set_state(Game.State.TITLE)
		await get_tree().physics_frame


func _run(players: Array = [0]) -> Node:
	var r: Node = RunScript.new()
	r.drive_game = false
	r.save_enabled = false
	r.rng.seed = 1
	_runs.append(r)
	r._ensure_data()
	r.start_run(players)
	return r


func _card(id: StringName, pool: Array[UpgradeData]) -> UpgradeData:
	for c in pool:
		if c.id == id:
			return c
	return null


func test_every_card_has_a_slot_and_an_effect() -> void:
	var r := _run()
	assert_int(r.pool.size()).is_equal(44)
	for c: UpgradeData in r.pool:
		assert_bool(UpgradeData.SLOTS.has(c.slot)).override_failure_message("%s slot %s" % [c.id, c.slot]).is_true()
		assert_bool(UpgradeData.KICK_STYLES.has(c.kick_style)).override_failure_message(String(c.id)).is_true()
		assert_bool(UpgradeData.BALL_EFFECTS.has(c.ball_effect)).override_failure_message(String(c.id)).is_true()
		assert_bool(UpgradeData.RUN_FX.has(c.run_fx)).override_failure_message(String(c.id)).is_true()
		if c.scene_override == null:   # the frog is its own effect
			assert_bool(c.has_effect()).override_failure_message("%s does nothing you can see" % c.id).is_true()
		if c.kind != "curse":
			assert_str(c.slot).override_failure_message("%s has no slot" % c.id).is_not_equal("")


func test_named_cards_do_what_they_say() -> void:
	var pool: Array[UpgradeData] = _run().pool
	assert_float(_card(&"spring_shoes", pool).jump_mult).is_greater(1.0)
	assert_str(String(_card(&"spring_shoes", pool).run_fx)).is_equal("bounce")
	assert_float(_card(&"rocket_boots", pool).run_speed_mult).is_greater(1.2)
	assert_str(String(_card(&"rocket_boots", pool).run_fx)).is_equal("flame")
	assert_float(_card(&"running_start", pool).accel_mult).is_greater(1.5)
	assert_str(String(_card(&"cannon_leg", pool).kick_style)).is_equal("cannon")
	assert_str(String(_card(&"helium_ball", pool).ball_effect)).is_equal("floaty")
	assert_float(_card(&"moon_gravity", pool).gravity_mult).is_less(0.5)
	assert_float(_card(&"super_strength", pool).bulk).is_greater(1.2)
	assert_float(_card(&"super_strength", pool).shake).is_greater(0.0)
	assert_float(_card(&"jetpack", pool).jump_mult).is_greater(1.5)


func test_owned_gear_is_never_offered_again() -> void:
	var r := _run()
	var rng := RandomNumberGenerator.new()
	for s in 300:
		rng.seed = s
		var owned: Array[UpgradeData] = []
		for c in r.pool:
			if c.kind != "curse" and rng.randf() < 0.5:
				owned.append(c)
		for round_i in [1 + s % 13, 14]:
			var cards := RunScript.draw_from(r.pool, round_i, s % 3 == 0, rng, owned)
			assert_int(cards.size()).is_greater(0)
			for c in cards:
				assert_bool(owned.has(c)).override_failure_message("offered %s again" % c.id).is_false()


func test_a_whole_run_never_repeats_gear() -> void:
	for s in 60:
		var r := _run([0])
		var rng := RandomNumberGenerator.new()
		rng.seed = s
		while r.phase != RunScript.Phase.END and r.round_index <= 20:
			if r.phase == RunScript.Phase.PICK:
				var cards: Array[UpgradeData] = r.draw_cards(0, rng)
				for c in cards:
					if not c.is_curse():
						assert_bool(r.upgrades_of(0).has(c)).is_false()
				r.pick(0, cards[rng.randi() % cards.size()])
				continue
			var power: float = r.notify_kicked(0, 1.0)
			var h: float = r.kick_height(0, power)
			r.notify_stopped(0, h)
			r.end_flight(0)
		var ids: Array = r.upgrades_of(0).map(func(u): return u.id)
		for id in ids:
			assert_int(ids.count(id)).is_equal(1)


## Hidden curses come from the whole curse pool every time: the same one can come again.
func test_curses_can_repeat() -> void:
	var r := _run()
	var rng := RandomNumberGenerator.new()
	var seen := {}
	for s in 400:
		rng.seed = s
		var c: UpgradeData = RunScript.pick_curse(r.pool, 9, rng)
		seen[c.id] = seen.get(c.id, 0) + 1
	assert_bool(seen.values().any(func(n): return n > 1)).is_true()
	assert_int(seen.size()).is_greater(3)


func test_slot_replace_keeps_power_and_swaps_the_look() -> void:
	var r := _run()
	var spring := _card(&"spring_shoes", r.pool)
	var rocket := _card(&"rocket_boots", r.pool)
	assert_str(spring.slot).is_equal(rocket.slot)
	r._upgrades[0] = [spring]
	var one: float = r.power_of(0)
	r._upgrades[0] = [spring, rocket]
	var two: float = r.power_of(0)
	assert_float(two).is_equal_approx(one * rocket.power_mult, 0.001)   # never lose height
	var fx: Dictionary = r.effects_of(0)
	assert_object(fx.worn["feet"]).is_same(rocket)
	# Stats add up; the look is what you wear.
	assert_float(fx.jump_mult).is_equal_approx(spring.jump_mult, 0.001)
	assert_float(fx.run_speed_mult).is_equal_approx(rocket.run_speed_mult, 0.001)
	assert_bool(fx.run_fx.has(&"flame")).is_true()
	assert_bool(fx.run_fx.has(&"bounce")).is_false()
	assert_str(String(fx.kick_style)).is_equal("jet")
	# On the kicker: one piece on the feet, the old one is gone.
	var k: Kicker = auto_free(KICKER.instantiate())
	add_child(k)
	k.add_upgrade_visual(spring)
	var first := k.worn_piece("feet")
	k.add_upgrade_visual(rocket)
	assert_object(k.worn_piece("feet")).is_not_same(first)
	await get_tree().create_timer(0.6).timeout
	assert_bool(is_instance_valid(first)).is_false()
	assert_str(String(k.equipment.equipped(&"foot_r").id)).is_equal("rocket_boots")
	assert_int(k.equipment.slot_node(&"foot_r").get_child_count()).is_equal(1)


func test_frog_switches_effects_off() -> void:
	var r := _run()
	r._upgrades[0] = [_card(&"rocket_boots", r.pool)]
	r._active_curse[0] = _card(&"kiss_the_frog", r.pool)
	assert_float(r.effects_of(0).run_speed_mult).is_equal(1.0)


func _wait_for(cond: Callable, seconds: float) -> bool:
	var waited := 0.0
	while waited < seconds:
		if cond.call():
			return true
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()
	return false


func test_kick_fires_on_contact_with_own_ball_only(timeout := 60000) -> void:
	Run.phase = Run.Phase.IDLE
	Players._device_of = {Players.P1: -1, Players.P2: -1}
	Game._set_state(Game.State.TITLE)
	Run.save_enabled = false
	Run.demo = true
	_main = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(_main)
	PhysicsPin.seed_main(_main)
	assert_bool(await _wait_for(func(): return Run.phase == Run.Phase.KICK_P1, 3.0)).is_true()
	var jeff: Kicker = _main.kickers[Players.P1]
	var chuck: Kicker = _main.kickers[Players.P2]
	for k in [jeff, chuck]:
		k.bot = false
		k.stick_override = Vector2.ZERO
	var started := []
	Run.kick_started.connect(func(p): started.append(p))
	var b1: Node3D = _main.balls[Players.P1]
	var b2: Node3D = _main.balls[Players.P2]
	# Chuck wanders onto Jeff's ball: nothing.
	chuck.global_position = Vector3(b1.global_position.x, 0.0, b1.global_position.z + 0.3)
	await _wait_for(func(): return false, 0.5)
	assert_array(started).is_empty()
	# Jeff runs into Chuck's ball: nothing.
	jeff.global_position = Vector3(b2.global_position.x, 0.0, b2.global_position.z + 0.3)
	await _wait_for(func(): return false, 0.5)
	assert_array(started).is_empty()
	assert_int(jeff.state).is_equal(Kicker.State.APPROACH)
	# Jeff runs into his own ball: the kick starts.
	jeff.global_position = Vector3(b1.global_position.x, 0.0, b1.global_position.z + 0.6)
	assert_bool(await _wait_for(func(): return not started.is_empty(), 1.0)).is_true()
	assert_array(started).is_equal([Players.P1])
