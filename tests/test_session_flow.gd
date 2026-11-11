## Soak lane: one couch session from a fresh start, end to end, in one test. Each step has its
## own test elsewhere (test_lobby, test_chooser, test_solo); this chains them in the order a family
## meets them, so a step that only breaks *after* another (the lobby after an end card, a drop-in
## after a lone hold-start) shows up here.
class_name TestSessionFlow
extends GdUnitTestSuite

const P1 := Players.P1
const P2 := Players.P2
const Lobby := preload("res://scenes/ui/lobby.gd")
const PauseMenu := preload("res://scenes/ui/pause_menu.gd")
const PAD2 := 7

var _main: Node
var _quits := 0


func before() -> void:
	SettingsSandbox.enter("user://test_session_flow.json")
	Game.quit_exits = false
	Game.quit_requested.connect(_on_quit)


func after() -> void:
	Game.quit_requested.disconnect(_on_quit)
	Game.quit_exits = true
	SettingsSandbox.leave()


func before_test() -> void:
	Players.reset()
	Run.stop_run()
	Run.demo = false
	Run.save_enabled = false
	Game.demo = false
	Game.round_index = 0
	Game._set_state(Game.State.LOBBY)
	get_tree().paused = false
	_quits = 0


func after_test() -> void:
	if is_instance_valid(_main):
		_main.free()
	Players.reset()
	Run.stop_run()
	Run.save_enabled = true
	Game._set_state(Game.State.LOBBY)
	get_tree().paused = false


func _on_quit() -> void:
	_quits += 1


func _lobby() -> Lobby:
	return _main.get_node("UI/Lobby")


func _finish_countdown() -> void:
	_lobby().count_step(Lobby.COUNT_STEP * Lobby.COUNT_DOTS + 0.01)


func test_a_whole_session_from_a_fresh_start() -> void:
	# A remembered solo from last time does not make this a one-player session.
	Save.set_setting(SettingsPanel.SOLO, true)
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	await await_idle_frame()
	assert_bool(Players.solo).is_false()
	var lobby := _lobby()
	assert_int(Game.state).is_equal(Game.State.LOBBY)

	# Two pads; both press A: the countdown runs and both kick from round 1.
	Players.join_virtual(P1)
	Players._assign(P2, PAD2)
	lobby.press_a(P1)
	lobby.press_a(P2)
	assert_bool(lobby.counting).is_true()
	_finish_countdown()
	assert_int(Game.state).is_equal(Game.State.PLAYING)
	assert_bool(Run.in_run(P1) and Run.in_run(P2)).is_true()
	assert_int(Run.phase).is_equal(Run.Phase.KICK_P1)

	# Start pauses; Resume carries on.
	Game.pause()
	var pm: PauseMenu = _main.get_node("UI/PauseMenu")
	assert_bool(pm.visible).is_true()
	pm.press(PauseMenu.Choice.RESUME)
	assert_int(Game.state).is_equal(Game.State.PLAYING)

	# The run ends: the end card; A goes back to a clean lobby, nobody readied.
	Run._finish()
	var card: Control = _main.get_node("UI/EndCard")
	assert_bool(card.visible).is_true()
	card.press()
	await await_idle_frame()
	assert_int(Game.state).is_equal(Game.State.LOBBY)
	assert_bool(lobby.visible).is_true()
	assert_bool(card.visible).is_false()
	assert_int(Run.phase).is_equal(Run.Phase.IDLE)
	assert_bool(lobby.readied[P1] or lobby.readied[P2]).is_false()
	assert_bool(lobby.counting).is_false()

	# The chooser on the podium works again after a run: right changes P1, never to P2's pick,
	# and the field kicker follows; A locks it in.
	var before_pick := Roster.pick(P1)
	assert_bool(lobby.choose(P1, 1)).is_true()
	assert_str(Roster.pick(P1)).is_not_equal(before_pick)
	assert_str(Roster.pick(P1)).is_not_equal(Roster.pick(P2))
	assert_str(_main.kickers[P1].character_id).is_equal(Roster.pick(P1))

	# P2's pad goes away; P1 readies and holds A alone: a one-player run.
	Players._on_joy_connection_changed(PAD2, false)
	assert_bool(Players.is_active(P2)).is_false()
	lobby.press_a(P1)
	assert_bool(lobby.choose(P1, 1)).is_false()   # readied: locked
	assert_bool(lobby.hold_step(P1, true, Lobby.HOLD_TO_START)).is_true()
	_finish_countdown()
	assert_int(Game.state).is_equal(Game.State.PLAYING)
	assert_bool(Run.in_run(P1)).is_true()
	assert_bool(Run.in_run(P2)).is_false()

	# P2 drops in mid-round: up off the chair now, a ball from the next round.
	Players.join_virtual(P2)
	assert_bool(Run.in_run(P2)).is_false()
	assert_int(_main.kickers[P2].state).is_not_equal(Kicker.State.CHAIR)
	Game.end_round()
	Game.start_round()
	assert_bool(Run.in_run(P2)).is_true()

	# Start, the big door icon, "leave": out to the launcher.
	Game.pause()
	pm.press(PauseMenu.Choice.DOOR)
	var confirm: ConfirmDialog = pm.get_node("Confirm")
	assert_bool(confirm.active).is_true()
	assert_int(_quits).is_equal(0)
	confirm.choose(true)
	assert_int(_quits).is_equal(1)
