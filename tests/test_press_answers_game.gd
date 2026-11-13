## Every press answers on this game's own screens (docs/press-answers.md "Spaceballs screens"):
## the upgrade pick and the end card refuse a press that does nothing (the honk, a wobble on the
## focused card or button), and nothing else changes. Real pad events on pads 5 (P1) and 6 (P2).
## Own settings and picks files (SettingsSandbox), never the real ones.
class_name TestPressAnswersGame
extends GdUnitTestSuite

const P1 := Players.P1
const P2 := Players.P2
const PAD := { Players.P1: 5, Players.P2: 6 }
const SETTINGS := "user://test_press_answers_game_settings.json"

var _nodes: Array[Node] = []
var _cues: Array[String] = []


func before() -> void:
	SettingsSandbox.enter(SETTINGS)
	Audio.played.connect(_on_played)
	Game.quit_exits = false


func after() -> void:
	Audio.played.disconnect(_on_played)
	Game.quit_exits = true
	Players.reset()
	SettingsSandbox.leave()


func before_test() -> void:
	Save.wipe_settings()
	Players.reset()
	Run.stop_run()
	Run.demo = false
	Run.save_enabled = false
	Game.demo = false
	Game._set_state(Game.State.ROUND_END)
	get_tree().paused = false
	Players._assign(P1, PAD[P1])
	Players._assign(P2, PAD[P2])
	_cues.clear()


func after_test() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()
	Run.stop_run()
	Players.reset()
	Game._set_state(Game.State.LOBBY)


func _on_played(cue: String, _pitch: float) -> void:
	_cues.append(cue)


## A real press and release on `device`, one frame each.
func _pad(device: int, button: JoyButton) -> void:
	for down in [true, false]:
		var ev := InputEventJoypadButton.new()
		ev.device = device
		ev.button_index = button
		ev.pressed = down
		Input.parse_input_event(ev)
		Input.flush_buffered_events()
		await await_idle_frame()


func _trigger(device: int, axis: JoyAxis) -> void:
	for v in [1.0, 0.0]:
		var ev := InputEventJoypadMotion.new()
		ev.device = device
		ev.axis = axis
		ev.axis_value = v
		Input.parse_input_event(ev)
		Input.flush_buffered_events()
		await await_idle_frame()


func _honks() -> int:
	return _cues.count(MenuInput.REFUSE_CUE)


# ---- upgrade pick ------------------------------------------------------------------------------

func _open_pick() -> Control:
	var pick: Control = load("res://scenes/ui/upgrade_pick.tscn").instantiate()
	_nodes.append(pick)
	get_tree().root.add_child(pick)
	Run._ensure_data()
	var a: Array[UpgradeData] = [Run.pool[0], Run.pool[1], Run.pool[2]]
	var b: Array[UpgradeData] = [Run.pool[3], Run.pool[4], Run.pool[5]]
	pick.open({P1: a, P2: b}, [P1, P2])
	await await_idle_frame()
	await await_idle_frame()   # MenuInput takes stock first
	return pick


func test_pick_unused_buttons_refuse_and_change_nothing() -> void:
	var pick := await _open_pick()
	var got := []
	pick.picked.connect(func(p: int, u: UpgradeData) -> void: got.append([p, u.id]))
	var r0 := MenuInput.refusals
	await _pad(PAD[P1], JOY_BUTTON_X)
	assert_int(MenuInput.refusals).is_equal(r0 + 1)
	assert_str(MenuInput.last_refused).is_equal("x")
	assert_int(_honks()).is_equal(1)
	var card1: Control = pick.cards_of(P1)[1]
	assert_bool(card1.is_wobbling()).is_true()
	assert_bool(pick.cards_of(P2)[1].is_wobbling()).is_false()   # the presser's own card
	await _pad(PAD[P2], JOY_BUTTON_Y)
	assert_bool(pick.cards_of(P2)[1].is_wobbling()).is_true()
	await _pad(PAD[P2], JOY_BUTTON_LEFT_SHOULDER)
	await _pad(PAD[P1], JOY_BUTTON_START)   # no pause between rounds: refuse
	await _trigger(PAD[P1], JOY_AXIS_TRIGGER_RIGHT)
	assert_int(MenuInput.refusals).is_equal(r0 + 5)
	assert_str(MenuInput.last_refused).is_equal("rt")
	# Nothing else changed: no pick, same cards highlighted, still open, still between rounds.
	assert_array(got).is_empty()
	assert_int(pick._sel[P1]).is_equal(1)
	assert_int(pick._sel[P2]).is_equal(1)
	assert_bool(pick._done[P1] or pick._done[P2]).is_false()
	assert_bool(pick.visible).is_true()
	assert_int(Game.state).is_equal(Game.State.ROUND_END)
	assert_str(Save.settings_path).is_equal(SETTINGS)   # never the real file


func test_pick_b_refuses_and_a_after_picking_refuses() -> void:
	var pick := await _open_pick()
	var got := []
	pick.picked.connect(func(p: int, u: UpgradeData) -> void: got.append([p, u.id]))
	var r0 := MenuInput.refusals
	await _pad(PAD[P1], JOY_BUTTON_B)   # not solo: B has no job on the pick
	assert_int(MenuInput.refusals).is_equal(r0 + 1)
	assert_str(MenuInput.last_refused).is_equal("b")
	assert_bool(pick._done[P1]).is_false()
	await _pad(PAD[P1], JOY_BUTTON_A)   # picks
	assert_int(got.size()).is_equal(1)
	assert_int(MenuInput.refusals).is_equal(r0 + 1)
	await _pad(PAD[P1], JOY_BUTTON_A)   # already picked: refuse, no second pick
	assert_int(MenuInput.refusals).is_equal(r0 + 2)
	assert_str(MenuInput.last_refused).is_equal("a")
	assert_int(got.size()).is_equal(1)
	assert_bool(pick._done[P2]).is_false()


func test_pick_select_keeps_its_restart_job() -> void:
	var pick := await _open_pick()
	var r0 := MenuInput.refusals
	await _pad(PAD[P1], JOY_BUTTON_BACK)
	assert_int(MenuInput.refusals).is_equal(r0)
	assert_array(_cues).contains(["restart_arm"])


# ---- end card ----------------------------------------------------------------------------------

func _open_card() -> Control:
	var card: Control = load("res://scenes/ui/end_card.tscn").instantiate()
	_nodes.append(card)
	get_tree().root.add_child(card)
	card.open()
	card._t = card.ACCEPT_AFTER + 1.0   # the buttons are up
	await await_idle_frame()
	await await_idle_frame()
	_cues.clear()
	return card


func test_end_card_unused_buttons_refuse_and_change_nothing() -> void:
	var card := await _open_card()
	var restarts := [0]
	card.restart_requested.connect(func() -> void: restarts[0] += 1)
	var r0 := MenuInput.refusals
	await _pad(PAD[P2], JOY_BUTTON_Y)
	assert_int(MenuInput.refusals).is_equal(r0 + 1)
	assert_int(_honks()).is_equal(1)
	assert_int(card.hint_wobbles).is_equal(1)
	await _pad(PAD[P1], JOY_BUTTON_RIGHT_STICK)
	await _trigger(PAD[P2], JOY_AXIS_TRIGGER_LEFT)
	assert_int(MenuInput.refusals).is_equal(r0 + 3)
	assert_int(card.hint_wobbles).is_equal(3)
	assert_bool(card.visible).is_true()
	assert_bool(card.door_focused).is_false()
	assert_bool(card.confirm.active).is_false()
	assert_int(restarts[0]).is_equal(0)


func test_end_card_start_refuses_once_and_door_wobbles() -> void:
	var card := await _open_card()
	await _pad(PAD[P1], JOY_BUTTON_START)
	assert_int(_honks()).is_equal(1)   # refused_press() owns Start: one honk, not two
	card._focus_door(true, false)
	var door: IconButton = card.door
	var w0 := door.wobbles
	await _pad(PAD[P1], JOY_BUTTON_X)
	assert_int(door.wobbles).is_equal(w0 + 1)
	assert_bool(door.is_wobbling()).is_true()
	assert_bool(card.door_focused).is_true()
	assert_bool(card.confirm.active).is_false()
