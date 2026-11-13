## The pause menu's big door icon back to Open Jar (template PD-01, adopted as FR-03): it is in
## the pause scene (128 px, 140 px focused, "Back to Open Jar" beneath), the cursor stops on it,
## A asks first (then Game.quit, saved), B resumes, and the d-pad reaches it (Players.add_dpad()
## feeds the move actions that MenuInput reads). Boots main.tscn with real pad events on two
## joined pads. Own settings and picks files (SettingsSandbox), never the real ones.
class_name TestPauseDoor
extends GdUnitTestSuite

const P1 := Players.P1
const P2 := Players.P2
const PAD := { Players.P1: 5, Players.P2: 6 }
const Lobby := preload("res://scenes/ui/lobby.gd")
const PauseMenu := preload("res://scenes/ui/pause_menu.gd")

var _main: Node
var _quits := 0


func before() -> void:
	SettingsSandbox.enter("user://test_pause_door_settings.json")
	Game.quit_exits = false
	Game.quit_requested.connect(_on_quit)


func after() -> void:
	Game.quit_requested.disconnect(_on_quit)
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
	Game.round_index = 0
	Game._set_state(Game.State.LOBBY)
	get_tree().paused = false
	_quits = 0


func after_test() -> void:
	if is_instance_valid(_main):
		_main.free()
	Run.stop_run()
	Players.reset()
	Game._set_state(Game.State.LOBBY)
	get_tree().paused = false


func _on_quit() -> void:
	_quits += 1


## A real press and release on `device`, one frame each (menus read just_pressed per frame).
func _pad(device: int, button: JoyButton) -> void:
	for down in [true, false]:
		var ev := InputEventJoypadButton.new()
		ev.device = device
		ev.button_index = button
		ev.pressed = down
		Input.parse_input_event(ev)
		Input.flush_buffered_events()
		await await_idle_frame()


## Pads 5 and 6 are P1 and P2, the round starts, the pause opens.
func _paused_with_pads() -> PauseMenu:
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	Players._assign(P1, PAD[P1])
	Players._assign(P2, PAD[P2])
	var lobby: Lobby = _main.get_node("UI/Lobby")
	lobby.count_step(Lobby.COUNT_STEP * Lobby.COUNT_DOTS + 0.01)
	assert_int(Game.state).is_equal(Game.State.PLAYING)
	Game.pause()
	await await_idle_frame()
	return _main.get_node("UI/PauseMenu")


func _door(pm: Node) -> IconButton:
	return pm.get_node("Card/Door/Icon")


func test_door_icon_is_in_the_pause_scene() -> void:
	var pm: Node = auto_free(load("res://scenes/ui/pause_menu.tscn").instantiate())
	var door: Node = pm.get_node_or_null("Card/Door/Icon")
	assert_object(door).is_instanceof(IconButton)
	var icon := door as IconButton
	assert_int(icon.icon).is_equal(IconButton.Icon.DOOR)
	assert_vector(icon.size).is_equal(Vector2(128, 128))
	assert_float(icon.size.x * icon.focus_scale).is_equal_approx(140.0, 0.01)
	assert_bool(icon.disabled).is_false()
	var label: Label = pm.get_node("Card/Door/Label")
	assert_str(label.text).is_equal("Back to Open Jar")
	# Beneath the icon, and centred under it.
	assert_float(label.position.y).is_greater(icon.position.y + 128.0)
	assert_float(label.position.x + label.size.x * 0.5).is_equal_approx(icon.position.x + 64.0, 1.0)
	# The old text bar is gone.
	assert_object(pm.get_node_or_null("Card/Buttons/Door")).is_null()


func test_door_icon_takes_the_focus() -> void:
	var pm := await _paused_with_pads()
	var door := _door(pm)
	assert_bool(door.focused).is_false()
	for i in 3:
		pm.move_focus(1)
	assert_int(pm.focus).is_equal(PauseMenu.Choice.DOOR)
	assert_bool(door.focused).is_true()
	pm.move_focus(1)   # bumps the end: stays on the door
	assert_int(pm.focus).is_equal(PauseMenu.Choice.DOOR)
	pm.move_focus(-1)
	assert_bool(door.focused).is_false()
	assert_int(pm.focus).is_equal(PauseMenu.Choice.SETTINGS)


func test_dpad_reaches_the_door() -> void:
	var pm := await _paused_with_pads()
	assert_int(pm.focus).is_equal(PauseMenu.Choice.RESUME)
	await _pad(PAD[P1], JOY_BUTTON_DPAD_DOWN)
	assert_int(pm.focus).is_equal(PauseMenu.Choice.RESTART)
	await _pad(PAD[P2], JOY_BUTTON_DPAD_DOWN)   # either pad
	assert_int(pm.focus).is_equal(PauseMenu.Choice.SETTINGS)
	await _pad(PAD[P1], JOY_BUTTON_DPAD_DOWN)
	assert_int(pm.focus).is_equal(PauseMenu.Choice.DOOR)
	assert_bool(_door(pm).focused).is_true()
	await _pad(PAD[P1], JOY_BUTTON_DPAD_UP)
	assert_int(pm.focus).is_equal(PauseMenu.Choice.SETTINGS)


func test_a_on_the_door_asks_first_then_quits_saved() -> void:
	var pm := await _paused_with_pads()
	Save.set_value("pause_door_quit", 1)
	for i in 3:
		pm.move_focus(1)
	await _pad(PAD[P1], JOY_BUTTON_A)
	var confirm: ConfirmDialog = pm.get_node("Confirm")
	assert_bool(confirm.active).is_true()
	assert_int(_quits).is_equal(0)
	assert_int(Game.state).is_equal(Game.State.PAUSED)
	await _pad(PAD[P1], JOY_BUTTON_B)   # B in the question: stay
	assert_bool(confirm.active).is_false()
	assert_int(Game.state).is_equal(Game.State.PAUSED)
	assert_int(_quits).is_equal(0)
	await _pad(PAD[P2], JOY_BUTTON_A)   # ask again (either pad), then leave
	assert_bool(confirm.active).is_true()
	confirm.choose(true)
	assert_int(_quits).is_equal(1)
	assert_bool(Save._dirty).is_false()   # Game.quit saved first
	Save.wipe()


func test_b_resumes() -> void:
	var pm := await _paused_with_pads()
	for i in 3:
		pm.move_focus(1)
	await _pad(PAD[P2], JOY_BUTTON_B)
	assert_int(Game.state).is_equal(Game.State.PLAYING)
	assert_bool(get_tree().paused).is_false()
	assert_bool(pm.visible).is_false()
	assert_int(_quits).is_equal(0)
