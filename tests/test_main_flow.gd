## Boots main.tscn with two virtual players in --demo mode and plays round 1 for real
## (kickers steer themselves, balls fly, the pick auto-picks): the scene side of the phases.
class_name TestMainFlow
extends GdUnitTestSuite

var _main: Node


func before_test() -> void:
	Run.save_enabled = false
	Run.demo = true
	Engine.time_scale = 8.0


func after_test() -> void:
	if is_instance_valid(_main):
		_main.free()
	Engine.time_scale = 1.0
	Run.demo = false
	Run.save_enabled = true
	Run.phase = Run.Phase.IDLE
	Players._device_of = {Players.P1: -1, Players.P2: -1}
	Game._set_state(Game.State.TITLE)
	get_tree().root.get_viewport().disable_3d = false
	await get_tree().physics_frame
	await get_tree().physics_frame


## Waits in SIMULATED time (physics ticks), not wall-clock or process delta: on slow CI runners
## frames are long, physics is capped per frame and lags, so both other clocks run ahead of the game.
func _wait_for(cond: Callable, seconds: float) -> bool:
	var waited := 0.0
	while waited < seconds:
		if cond.call():
			return true
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()
	return false


func test_round_one_plays_through_pick_into_round_two(timeout := 240000) -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(_main)
	var kicked := []
	Run.kicked.connect(func(p, _power): kicked.append(p))
	assert_bool(await _wait_for(func(): return Run.phase == Run.Phase.KICK_P1, 3.0)).is_true()
	assert_bool(_main.get_node("UI/Title").visible).is_false()
	assert_bool(_main.get_node("UI/HUD").visible).is_true()
	assert_bool(await _wait_for(func(): return Run.phase == Run.Phase.PICK, 20.0)).is_true()
	assert_array(kicked).is_equal([Players.P1, Players.P2])
	var pick: Control = _main.get_node("UI/UpgradePick")
	assert_bool(pick.visible).is_true()
	assert_bool(pick.get_node("Halves/P1").visible).is_true()
	assert_bool(pick.get_node("Halves/P2").visible).is_true()
	assert_bool(get_tree().root.get_viewport().disable_3d).is_true()   # split screen on
	for c in pick.cards_of(Players.P1):
		assert_object(c.upgrade).is_not_null()
	assert_bool(await _wait_for(func(): return Run.round_index == 2 and Run.phase == Run.Phase.KICK_P1, 10.0)).is_true()
	assert_bool(pick.visible).is_false()
	assert_bool(get_tree().root.get_viewport().disable_3d).is_false()
	assert_int(Run.upgrades_of(Players.P1).size() + (1 if Run.curse_of(Players.P1) else 0)).is_equal(1)
	assert_float(Run.best_height(Players.P1)).is_greater(1.0)


func after() -> void:
	await Audio.stop_all()   # a cue still playing when the runner quits shows up as a leak
