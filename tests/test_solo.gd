## Solo mode (playtest only): one pad plays both players. Players toggling and InputMap focus,
## the solo pick sequence, Run skipping a player who leaves mid-kick, and a full solo round in main.
class_name TestSolo
extends GdUnitTestSuite

const RunScript := preload("res://scripts/autoload/Run.gd")
const P1 := Players.P1
const P2 := Players.P2
const PAD := 3

var _nodes: Array = []


func before() -> void:
	SettingsSandbox.enter()


func before_test() -> void:
	# CI runs suites in another order: start from clean autoloads.
	Players.reset()
	Run.phase = Run.Phase.IDLE
	Run.demo = false
	Run.save_enabled = false
	Game._set_state(Game.State.TITLE)
	get_tree().paused = false


func after_test() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()
	Players.reset()
	Engine.time_scale = 1.0
	Run.demo = false
	Game.demo = false
	Run.save_enabled = true
	Run.phase = Run.Phase.IDLE
	Game._set_state(Game.State.TITLE)
	get_tree().paused = false
	get_tree().root.get_viewport().disable_3d = false
	await get_tree().physics_frame
	await get_tree().physics_frame


func after() -> void:
	SettingsSandbox.leave()
	await Audio.stop_all()


func _pad_events(action_name: String) -> Array:
	return InputMap.action_get_events(action_name).filter(
			func(e): return e is InputEventJoypadButton or e is InputEventJoypadMotion)


func _key_codes(action_name: String) -> Array:
	return InputMap.action_get_events(action_name).filter(func(e): return e is InputEventKey) \
			.map(func(e): return e.physical_keycode)


func _press(button: JoyButton) -> void:
	for down in [true, false]:
		var ev := InputEventJoypadButton.new()
		ev.device = PAD
		ev.button_index = button
		ev.pressed = down
		Input.parse_input_event(ev)
		Input.flush_buffered_events()
		await get_tree().process_frame
		await get_tree().process_frame


# --- toggling ------------------------------------------------------------------

func test_solo_flag_parsing() -> void:
	assert_bool(Players.solo_from_args(PackedStringArray(["--solo"]))).is_true()
	assert_bool(Players.solo_from_args(PackedStringArray(["--demo", "--solo"]))).is_true()
	assert_bool(Players.solo_from_args(PackedStringArray([]))).is_false()
	assert_bool(Players.solo_from_args(PackedStringArray(["--demo", "--solo=1"]))).is_false()
	assert_bool(Players.solo).is_false()   # never on by default


func test_two_second_hold_toggles_on_then_off() -> void:
	var seen := []
	var cb := func(on: bool) -> void: seen.append(on)
	Players.solo_changed.connect(cb)
	assert_bool(Players.hold_step(PAD, true, 1.0)).is_false()
	assert_bool(Players.hold_step(PAD, true, 0.9)).is_false()
	assert_bool(Players.solo).is_false()
	assert_bool(Players.hold_step(PAD, true, 0.2)).is_true()
	assert_bool(Players.solo).is_true()
	# Still held: no flip-flopping.
	assert_bool(Players.hold_step(PAD, true, 5.0)).is_false()
	assert_bool(Players.solo).is_true()
	Players.hold_step(PAD, false, 0.016)
	assert_bool(Players.hold_step(PAD, true, 2.1)).is_true()
	assert_bool(Players.solo).is_false()
	Players.solo_changed.disconnect(cb)
	assert_array(seen).is_equal([true, false])


func test_short_holds_do_not_toggle() -> void:
	for i in 10:   # a kid mashing both buttons
		Players.hold_step(PAD, true, 1.5)
		Players.hold_step(PAD, false, 0.05)
	assert_bool(Players.solo).is_false()


func test_one_button_never_toggles() -> void:
	# hold_step only sees both_down; a single held button (Select or Start alone) is false.
	for i in 300:
		assert_bool(Players.hold_step(PAD, false, 0.1)).is_false()
	assert_bool(Players.solo).is_false()


func test_holds_on_two_pads_do_not_add_up() -> void:
	Players.hold_step(PAD, true, 1.5)
	Players.hold_step(PAD + 1, true, 1.5)
	assert_bool(Players.solo).is_false()


# --- mapping -------------------------------------------------------------------

func test_solo_maps_both_players_to_one_device() -> void:
	var joined := []
	var cb := func(p: int, d: int) -> void: joined.append([p, d])
	Players.player_joined.connect(cb)
	Players.set_solo(true, PAD)
	Players.player_joined.disconnect(cb)
	assert_bool(Players.is_active(P1)).is_true()
	assert_bool(Players.is_active(P2)).is_true()
	assert_int(Players.device_of(P1)).is_equal(PAD)
	assert_int(Players.device_of(P2)).is_equal(PAD)
	assert_array(joined).is_equal([[P1, PAD], [P2, PAD]])
	assert_bool(Players._marker.is_showing()).is_true()
	# Focus P1: P1's actions get the pad and both keyboard sets, P2's nothing.
	assert_int(Players.solo_focus).is_equal(P1)
	assert_int(_pad_events("p1_action").size()).is_equal(1)
	assert_int(_pad_events("p1_action")[0].device).is_equal(PAD)
	assert_array(_key_codes("p1_action")).contains([KEY_SPACE, KEY_ENTER])
	assert_array(_key_codes("p1_move_left")).contains([KEY_A, KEY_LEFT])
	assert_array(InputMap.action_get_events("p2_action")).is_empty()
	assert_str(Players.action(P2, "action")).is_equal("p2_action")
	Players.set_solo_focus(P2)
	assert_array(InputMap.action_get_events("p1_move_left")).is_empty()
	assert_array(_key_codes("p2_move_left")).contains([KEY_A, KEY_LEFT])
	assert_int(_pad_events("p2_jump")[0].device).is_equal(PAD)


func test_pad_press_reaches_only_the_focused_player() -> void:
	Players.set_solo(true, PAD)
	var ev := InputEventJoypadButton.new()
	ev.device = PAD
	ev.button_index = JOY_BUTTON_A
	ev.pressed = true
	assert_bool(ev.is_action("p1_action")).is_true()
	assert_bool(ev.is_action("p2_action")).is_false()
	Players.set_solo_focus(P2)
	assert_bool(ev.is_action("p1_action")).is_false()
	assert_bool(ev.is_action("p2_action")).is_true()
	ev.device = PAD + 1   # another pad does nothing in solo
	assert_bool(ev.is_action("p2_action")).is_false()


func test_turning_solo_off_restores_map_and_drop_in() -> void:
	var before := {}
	for a in ["p1_action", "p2_action", "p1_move_up", "p2_move_up"]:
		before[a] = InputMap.action_get_events(a).size()
	Players.set_solo(true, PAD)
	Players.set_solo_focus(P2)
	var left := []
	var cb := func(p: int) -> void: left.append(p)
	Players.player_left.connect(cb)
	Players.set_solo(false)
	Players.player_left.disconnect(cb)
	assert_array(left).is_equal([P2])
	assert_bool(Players._marker.is_showing()).is_true()   # fading out, then hidden
	assert_int(Players.device_of(P1)).is_equal(PAD)
	assert_bool(Players.is_active(P2)).is_false()
	for a in before:
		assert_int(InputMap.action_get_events(a).size()).is_equal(before[a])
	assert_int(_pad_events("p1_action")[0].device).is_equal(PAD)
	# P2 drops in again with a second pad, the normal way.
	var ev := InputEventJoypadButton.new()
	ev.device = PAD + 1
	ev.button_index = JOY_BUTTON_A
	ev.pressed = true
	Players._input(ev)
	assert_int(Players.device_of(P2)).is_equal(PAD + 1)
	assert_int(_pad_events("p2_action")[0].device).is_equal(PAD + 1)
	assert_int(_pad_events("p1_action")[0].device).is_equal(PAD)


func test_pad_hold_ends_flag_solo_and_keeps_that_pad_as_p1() -> void:
	Players.set_solo(true)   # --solo: keyboard and any pad
	assert_int(Players.device_of(P2)).is_equal(Players.VIRTUAL)
	Players.hold_step(PAD, true, 2.5)
	assert_bool(Players.solo).is_false()
	assert_int(Players.device_of(P1)).is_equal(PAD)
	assert_int(_pad_events("p1_action")[0].device).is_equal(PAD)
	assert_bool(Players.is_active(P2)).is_false()


func test_hold_that_paused_the_game_unpauses_it() -> void:
	Game._set_state(Game.State.PLAYING)
	var start := InputEventJoypadButton.new()
	start.device = PAD
	start.button_index = JOY_BUTTON_START
	start.pressed = true
	Players._input(start)   # remembers "not paused" when the hold began
	Game.pause()            # what the Start press does
	Players.hold_step(PAD, true, 2.5)
	Players._undo_hold_pause(PAD)
	assert_bool(Players.solo).is_true()
	assert_bool(get_tree().paused).is_false()
	assert_int(Game.state).is_equal(Game.State.PLAYING)


# --- Spaceballs: Run and the pick ---------------------------------------------

func test_run_skips_a_player_who_leaves_during_their_kick() -> void:
	var r: Node = RunScript.new()
	_nodes.append(r)
	r.drive_game = false
	r.save_enabled = false
	r._ensure_data()
	r.start_run([P1, P2])
	r.notify_kicked(P1, 1.0)
	r.notify_stopped(P1, 3.0)
	r.end_flight(P1)
	assert_int(r.phase).is_equal(RunScript.Phase.KICK_P2)
	r._on_player_left(P2)
	assert_int(r.phase).is_equal(RunScript.Phase.PICK)
	assert_array(r.pickers()).is_equal([P1])


func _open_pick() -> Control:
	var pick: Control = load("res://scenes/ui/upgrade_pick.tscn").instantiate()
	_nodes.append(pick)
	get_tree().root.add_child(pick)
	Run._ensure_data()
	var a: Array[UpgradeData] = [Run.pool[0], Run.pool[1], Run.pool[2]]
	var b: Array[UpgradeData] = [Run.pool[3], Run.pool[4], Run.pool[5]]
	pick.open({P1: a, P2: b}, [P1, P2])
	return pick


func test_solo_pick_takes_p1_then_p2_from_one_pad() -> void:
	Players.set_solo(true, PAD)
	var pick := _open_pick()
	var got := []
	pick.picked.connect(func(p: int, u: UpgradeData) -> void: got.append([p, u.id]))
	assert_int(pick.solo_turn()).is_equal(P1)
	assert_object(pick.halves[P2].modulate).is_equal(pick.WAITING_DIM)
	await _press(JOY_BUTTON_A)   # P1 picks the middle card
	assert_array(got).is_empty()
	assert_int(pick.solo_turn()).is_equal(P2)
	assert_int(Players.solo_focus).is_equal(P2)
	assert_object(pick.halves[P1].modulate).is_equal(pick.WAITING_DIM)
	assert_object(pick.halves[P2].modulate).is_equal(Color.WHITE)
	await _press(JOY_BUTTON_B)   # back to P1's choice
	assert_int(pick.solo_turn()).is_equal(P1)
	assert_int(Players.solo_focus).is_equal(P1)
	assert_array(got).is_empty()
	pick._move(P1, 1)            # P1 changes their mind: the right card
	await _press(JOY_BUTTON_A)
	assert_int(pick.solo_turn()).is_equal(P2)
	await _press(JOY_BUTTON_A)   # P2 picks: both emitted, P1 first
	assert_array(got).is_equal([[P1, Run.pool[2].id], [P2, Run.pool[4].id]])
	assert_int(pick.solo_turn()).is_equal(-1)


func test_b_without_solo_does_not_undo() -> void:
	Players.join_virtual(P1)
	Players.join_virtual(P2)
	var pick := _open_pick()
	assert_int(pick.solo_turn()).is_equal(-1)
	pick._pick(P1)
	pick.solo_back()
	assert_bool(pick._done[P1]).is_true()


func test_solo_off_mid_pick_keeps_p1_choice() -> void:
	Players.set_solo(true, PAD)
	var pick := _open_pick()
	var got := []
	pick.picked.connect(func(p: int, _u: UpgradeData) -> void: got.append(p))
	pick._pick(P1)
	assert_array(got).is_empty()
	Players.set_solo(false)
	assert_array(got).is_equal([P1])
	assert_int(pick.solo_turn()).is_equal(-1)


# --- a full solo round in main --------------------------------------------------

func _wait_for(cond: Callable, seconds: float) -> bool:
	var waited := 0.0
	while waited < seconds:
		if cond.call():
			return true
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()
	return false


func test_full_solo_round_reaches_round_two(timeout := 240000) -> void:
	Run.demo = true
	Engine.time_scale = 8.0
	var main: Node = load("res://scenes/main.tscn").instantiate()
	_nodes.append(main)
	get_tree().root.add_child(main)
	Players.set_solo(true)   # what --solo does, before the demo's deferred joins
	var focus_at := {}
	var picks := []
	var on_phase := func(_f: int, to: int) -> void: focus_at[to] = Players.solo_focus
	var on_pick := func(p: int, _id: StringName) -> void: picks.append(p)
	Run.phase_changed.connect(on_phase)
	Run.upgrade_picked.connect(on_pick)
	var ok := await _wait_for(func(): return Run.round_index >= 2 and Run.phase == Run.Phase.KICK_P1, 60.0)
	Run.phase_changed.disconnect(on_phase)
	Run.upgrade_picked.disconnect(on_pick)
	assert_bool(ok).override_failure_message("stuck in %s round %d" % [
			Run.Phase.keys()[Run.phase], Run.round_index]).is_true()
	assert_bool(Run.in_run(P1) and Run.in_run(P2)).is_true()
	assert_int(Players.device_of(P1)).is_equal(Players.device_of(P2))
	assert_int(focus_at.get(Run.Phase.KICK_P2, -1)).is_equal(P2)
	assert_int(focus_at.get(Run.Phase.KICK_P1, -1)).is_equal(P1)
	# Both picked, once each. Not in order: a card that flips into a curse plays its 2-3 s reveal demo
	# before Run.pick, so P2's pick can land first (playtest 2026-11-10: 40 % on the first pick).
	picks.sort()
	assert_array(picks).is_equal([P1, P2])
