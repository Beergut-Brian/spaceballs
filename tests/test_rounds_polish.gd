## The frog round and the end card, played for real in main.tscn (--demo, sped up).
class_name TestRoundsPolish
extends GdUnitTestSuite

var _main: Node
var _setup_cb: Callable


func before() -> void:
	SettingsSandbox.enter()



func after() -> void:
	SettingsSandbox.leave()

func before_test() -> void:
	Run.phase = Run.Phase.IDLE
	Players._device_of = {Players.P1: -1, Players.P2: -1}
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
	Players._device_of = {Players.P1: -1, Players.P2: -1}
	Game._set_state(Game.State.TITLE)
	get_tree().root.get_viewport().disable_3d = false
	await Audio.stop_all()
	await get_tree().physics_frame


func _wait_for(cond: Callable, seconds: float) -> bool:
	var waited := 0.0
	while waited < seconds:
		if cond.call():
			return true
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()
	return false


func _boot(on_start: Callable) -> void:
	_setup_cb = on_start
	Run.run_started.connect(_setup_cb)
	_main = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(_main)


func test_frog_round(timeout := 240000) -> void:
	var boot := load("res://data/upgrades/big_boot.tres") as UpgradeData
	var frog := load("res://data/upgrades/kiss_the_frog.tres") as UpgradeData
	await _boot(func() -> void:
		Run._upgrades[Players.P1].append(boot)
		_main.kickers[Players.P1].add_upgrade_visual(boot)
		Run._active_curse[Players.P1] = frog)
	var jeff: Kicker = _main.kickers[Players.P1]
	var ball: Node3D = _main.balls[Players.P1]
	assert_bool(await _wait_for(func(): return Run.phase == Run.Phase.KICK_P1, 3.0)).is_true()
	# Poof: a frog, gear switched off for this round only.
	assert_bool(jeff.frog).is_true()
	assert_bool(jeff.attach.visible).is_false()
	var tee: Vector3 = ball.global_position
	var stops := []
	Run.ball_stopped.connect(func(p, h, _t): if p == Players.P1: stops.append(h))
	assert_bool(await _wait_for(func(): return not stops.is_empty(), 20.0)).is_true()
	# The ball dribbles a pathetic distance along the grass.
	assert_float(stops[0]).is_less(1.0)
	print("[frog] tee=%s ball=%s" % [tee, ball.global_position])
	var moved := Vector2(ball.global_position.x - tee.x, ball.global_position.z - tee.z).length()
	assert_float(moved).is_between(0.5, 3.0)
	assert_float(ball.global_position.y - tee.y).is_less(0.5)
	# Next round he poofs back, gear and all.
	assert_bool(await _wait_for(func(): return Run.phase == Run.Phase.PICK, 20.0)).is_true()
	assert_bool(jeff.frog).is_false()
	assert_bool(jeff.attach.visible).is_true()
	assert_bool(Run.upgrades_of(Players.P1).has(boot)).is_true()


func test_end_card_flow(timeout := 240000) -> void:
	var cannon := load("res://data/upgrades/cannon_leg.tres") as UpgradeData
	await _boot(func() -> void:
		for p in [Players.P1, Players.P2]:
			for i in 8:
				Run._upgrades[p].append(cannon))
	var spaced := []
	Run.reached_space.connect(func(p): spaced.append(p))
	assert_bool(await _wait_for(func(): return Run.phase == Run.Phase.END, 60.0)).is_true()
	Run.demo = false   # from here a person has to press A
	Game.demo = false
	assert_array(spaced).contains_exactly_in_any_order([Players.P1, Players.P2])
	var card: Control = _main.get_node("UI/EndCard")
	assert_bool(card.visible).is_true()
	for p in [Players.P1, Players.P2]:
		var k: Kicker = _main.kickers[p]
		assert_bool(k._dancing).is_true()
		assert_bool(k.helmet.visible).is_true()
		assert_bool(_main.balls[p].visible).is_true()
		assert_bool(_main.balls[p]._orbiting).is_true()
	var at: Vector3 = _main.balls[Players.P1].global_position
	await _wait_for(func(): return false, 0.5)
	assert_bool(_main.balls[Players.P1].global_position.is_equal_approx(at)).is_false()   # still orbiting
	# Floating up there: nobody falls out of the end card.
	var y: float = _main.kickers[Players.P1].global_position.y
	await _wait_for(func(): return false, 1.0)
	assert_float(_main.kickers[Players.P1].global_position.y).is_equal_approx(y, 0.01)
	# A (after the short guard) goes back to the lobby.
	await _wait_for(func(): return card._t > card.ACCEPT_AFTER, 3.0)
	Input.action_press(Players.action(Players.P1, "action"))
	await get_tree().process_frame
	await get_tree().process_frame
	Input.action_release(Players.action(Players.P1, "action"))
	await get_tree().process_frame
	assert_int(Game.state).is_equal(Game.State.LOBBY)
	var lobby: Control = _main.get_node("UI/Lobby")
	assert_bool(lobby.visible).is_true()
	assert_bool(lobby.readied[Players.P1]).is_false()   # the end card's A does not ready too
	assert_bool(card.visible).is_false()
	assert_bool(_main.kickers[Players.P1].helmet.visible).is_false()
	# Both ready up in the lobby: a fresh run from round 1.
	lobby.press_a(Players.P1)
	lobby.press_a(Players.P2)
	lobby.count_step(10.0)
	assert_bool(await _wait_for(func(): return Run.phase == Run.Phase.KICK_P1, 3.0)).is_true()
	assert_int(Run.round_index).is_equal(1)
	assert_bool(Run.in_space(Players.P1)).is_false()
