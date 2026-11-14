## Standing feel rules (Kaden, audited 2026-11-13; PLAN-STATUS S12 rows FR-01..FR-08) that have
## no suite of their own: a press that does nothing still says so (FR-05), solo is never on at
## boot, even when the settings remember it (FR-04). The d-pad rule is tests/test_dpad_moves.gd.
extends GdUnitTestSuite

const KICKER := preload("res://scenes/players/kicker.tscn")
const PAD := 5

var _cues: Array[String] = []
var _card: Control
var _state_was: int


func before() -> void:
	SettingsSandbox.enter("user://test_feel_rules_settings.json")
	Audio.played.connect(_on_played)


func after() -> void:
	Audio.played.disconnect(_on_played)
	Players.reset()
	SettingsSandbox.leave()


func before_test() -> void:
	_cues.clear()
	_state_was = Game.state
	Players.reset()
	Players._assign(Players.P1, PAD)
	await await_idle_frame()   # just_pressed is read in a process frame here, not a physics tick


func after_test() -> void:
	for b in [JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_START]:
		_button(b, false)
	if is_instance_valid(_card):
		_card.free()
	Run.demo = false
	Game.state = _state_was
	Players.reset()


func _on_played(cue: String, _pitch: float) -> void:
	_cues.append(cue)


func _button(button: JoyButton, down: bool) -> void:
	var ev := InputEventJoypadButton.new()
	ev.device = PAD
	ev.button_index = button
	ev.pressed = down
	Input.parse_input_event(ev)
	Input.flush_buffered_events()


func _kicker(height: float) -> Kicker:
	var root := Node3D.new()
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40, 1, 40)
	shape.shape = box
	floor_body.add_child(shape)
	floor_body.position = Vector3(0, -0.5, 0)
	root.add_child(floor_body)
	add_child(root)
	auto_free(root)
	var k: Kicker = KICKER.instantiate()
	root.add_child(k)
	k.global_position = Vector3(0, height, 0)
	k.set_physics_process(false)
	return k


# --- FR-05: every press says something ------------------------------------------------------

func test_b_in_the_air_refuses_instead_of_staying_silent() -> void:
	Game.state = Game.State.PLAYING
	var k := _kicker(3.0)                    # high above the floor: is_on_floor() is false
	var refused := [0]
	k.refused.connect(func(_p: int) -> void: refused[0] += 1)
	_button(JOY_BUTTON_B, true)
	k._buttons()
	assert_int(refused[0]).is_equal(1)
	assert_array(_cues).contains(["nope"])
	assert_array(_cues).not_contains(["hop"])


func test_b_on_the_ground_still_hops_not_refuses() -> void:
	Game.state = Game.State.PLAYING
	var k := _kicker(0.0)
	k.velocity = Vector3.ZERO
	k.move_and_slide()                       # settle onto the floor so is_on_floor() is true
	var hops := [0]
	k.hopped.connect(func(_p: int) -> void: hops[0] += 1)
	_button(JOY_BUTTON_B, true)
	k._buttons()
	assert_int(hops[0]).is_equal(1)
	assert_array(_cues).contains(["hop"])
	assert_array(_cues).not_contains(["nope"])


func test_b_during_the_wind_up_refuses() -> void:
	Game.state = Game.State.PLAYING
	var k := _kicker(0.0)
	k.state = Kicker.State.WINDUP
	_button(JOY_BUTTON_B, true)
	k._buttons()
	assert_array(_cues).contains(["nope"])


func _open_card() -> Control:
	Run.demo = false
	_card = load("res://scenes/ui/end_card.tscn").instantiate()
	get_tree().root.add_child(_card)
	_card.open()
	_card.set_process(false)
	return _card


func test_end_card_b_and_start_refuse() -> void:
	var card := _open_card()
	card._t = card.ACCEPT_AFTER + 1.0
	_button(JOY_BUTTON_B, true)
	assert_bool(card.refused_press()).is_true()
	_button(JOY_BUTTON_B, false)
	await await_idle_frame()
	_button(JOY_BUTTON_START, true)
	assert_bool(card.refused_press()).is_true()
	_cues.clear()
	card.refuse()
	# press-answers-adopt-1: the end card is a menu, so it refuses with the menus' honk (was nope).
	assert_array(_cues).contains([MenuInput.REFUSE_CUE])


func test_end_card_a_refuses_only_before_the_buttons_show() -> void:
	var card := _open_card()
	card._t = 0.2
	_button(JOY_BUTTON_A, true)
	assert_bool(card.refused_press()).is_true()
	card._t = card.ACCEPT_AFTER + 1.0         # same press, buttons up: A presses the big button
	assert_bool(card.refused_press()).is_false()


# --- FR-04: solo is never on at boot ----------------------------------------------------------

func test_solo_needs_the_flag() -> void:
	assert_bool(Players.solo_from_args(PackedStringArray([]))).is_false()
	assert_bool(Players.solo_from_args(PackedStringArray(["--solo"]))).is_true()


func test_a_remembered_solo_setting_does_not_turn_solo_on_at_boot() -> void:
	Save.set_setting(SettingsPanel.SOLO, true)  # the sandbox file, never the real one
	var fresh: Node = load("res://scripts/autoload/Players.gd").new()
	add_child(fresh)
	auto_free(fresh)
	await await_idle_frame()
	await await_idle_frame()
	assert_bool(fresh.solo).is_false()
	assert_bool(Players.solo).is_false()
