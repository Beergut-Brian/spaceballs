## Select restarts the run only on two presses within 1 s (GAME.md Controls).
class_name TestGameRestart
extends GdUnitTestSuite


func before_test() -> void:
	Run.save_enabled = false


func after_test() -> void:
	Run.save_enabled = true


func test_two_presses_within_a_second_restart() -> void:
	Game.start_round()
	Game.start_round()
	var restarted := [0]
	var cb := func() -> void: restarted[0] += 1
	Game.restarted.connect(cb)
	assert_bool(Game.press_restart(100.0)).is_false()
	assert_int(restarted[0]).is_equal(0)
	assert_bool(Game.press_restart(100.8)).is_true()
	assert_int(restarted[0]).is_equal(1)
	assert_int(Game.round_index).is_equal(1)
	Game.restarted.disconnect(cb)


func test_presses_too_far_apart_do_not_restart() -> void:
	assert_bool(Game.press_restart(200.0)).is_false()
	assert_bool(Game.press_restart(201.5)).is_false()   # re-arms instead
	assert_bool(Game.press_restart(202.2)).is_true()
	assert_bool(Game.press_restart(202.4)).is_false()  # a third press starts over


func after() -> void:
	await Audio.stop_all()   # a cue still playing when the runner quits shows up as a leak
