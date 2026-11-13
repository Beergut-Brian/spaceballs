## Feel rule "no stick-only requirement" (2026-11-13): on a pad the d-pad walks the kicker in
## play and drives every menu that reads the move actions (pause, end card, upgrade pick), not
## only the stick. project.godot binds move_* to the stick and the keys only, so Players adds the
## d-pad buttons at boot (Players.add_dpad()).
extends GdUnitTestSuite

const KICKER := preload("res://scenes/players/kicker.tscn")
const PAD := { Players.P1: 5, Players.P2: 6 }
const DIRS := { "move_left": JOY_BUTTON_DPAD_LEFT, "move_right": JOY_BUTTON_DPAD_RIGHT,
	"move_up": JOY_BUTTON_DPAD_UP, "move_down": JOY_BUTTON_DPAD_DOWN }


func before() -> void:
	SettingsSandbox.enter("user://test_dpad_moves_settings.json")


func after() -> void:
	Players.reset()
	SettingsSandbox.leave()


func before_test() -> void:
	PhysicsPin.enter()
	Players.reset()
	await get_tree().physics_frame


func after_test() -> void:
	for dev: int in PAD.values():
		for b: JoyButton in DIRS.values():
			_button(dev, b, false)
	Players.reset()
	PhysicsPin.leave()


func _button(device: int, button: JoyButton, down: bool) -> void:
	var ev := InputEventJoypadButton.new()
	ev.device = device
	ev.button_index = button
	ev.pressed = down
	Input.parse_input_event(ev)
	Input.flush_buffered_events()


func _join_both() -> void:
	Players._assign(Players.P1, PAD[Players.P1])
	Players._assign(Players.P2, PAD[Players.P2])


func _dpad_count(action_name: String) -> int:
	var n := 0
	for ev in InputMap.action_get_events(action_name):
		if ev is InputEventJoypadButton and ev.button_index in DIRS.values():
			n += 1
	return n


## Flat floor, a camera looking down -z, one kicker for `player` reading its real input (no
## stick_override). Holds `button` on the player's pad for 30 ticks; returns how far he went.
func _walk(player: int, button: JoyButton) -> Vector3:
	var root := Node3D.new()
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200, 1, 200)
	shape.shape = box
	floor_body.add_child(shape)
	floor_body.position = Vector3(0, -0.5, 0)
	root.add_child(floor_body)
	var cam := Camera3D.new()
	root.add_child(cam)
	add_child(root)
	auto_free(root)
	cam.global_position = Vector3(0, 4, 12)
	cam.look_at(Vector3(0, 1, 0))
	cam.current = true
	var k: Kicker = KICKER.instantiate()
	k.player = player
	root.add_child(k)
	k.global_position = Vector3(0, 0, 0)
	k.set_physics_process(false)
	k.begin_approach(Vector3(0, 0.35, -30))
	var start := k.global_position
	_button(PAD[player], button, true)
	for i in 30:
		k._physics_process(1.0 / 60.0)
	_button(PAD[player], button, false)
	return k.global_position - start


func test_every_move_action_has_its_dpad_button_once() -> void:
	for p in [Players.P1, Players.P2]:
		for a: String in DIRS:
			assert_int(_dpad_count(Players.action(p, a))) \
					.override_failure_message("%s has no d-pad" % Players.action(p, a)).is_equal(1)
	Players.add_dpad()
	Players.add_dpad()
	assert_int(_dpad_count(Players.action(Players.P1, "move_up"))).is_equal(1)


func test_p1_dpad_walks_p1_kicker() -> void:
	_join_both()
	var moved := _walk(Players.P1, JOY_BUTTON_DPAD_RIGHT)
	assert_float(moved.x).is_greater(0.5)          # screen-right is +x for this camera
	assert_float(absf(moved.z)).is_less(0.3)
	# P1's pad never moves P2.
	_button(PAD[Players.P1], JOY_BUTTON_DPAD_RIGHT, true)
	assert_vector(Players.move_vector(Players.P2)).is_equal(Vector2.ZERO)


func test_p2_dpad_walks_p2_kicker() -> void:
	_join_both()
	var moved := _walk(Players.P2, JOY_BUTTON_DPAD_UP)
	assert_float(moved.z).is_less(-0.5)            # screen-up is away from the camera (-z)
	assert_float(absf(moved.x)).is_less(0.3)
	_button(PAD[Players.P2], JOY_BUTTON_DPAD_UP, true)
	assert_vector(Players.move_vector(Players.P1)).is_equal(Vector2.ZERO)


func test_no_dpad_stays_put() -> void:
	_join_both()
	var moved := _walk(Players.P1, JOY_BUTTON_A)   # A is not a direction
	assert_float(Vector2(moved.x, moved.z).length()).is_less(0.05)


func test_dpad_moves_the_pause_and_menu_cursor() -> void:
	_join_both()
	await await_idle_frame()   # menus read just_pressed in the process frame, not a physics tick
	_button(PAD[Players.P2], JOY_BUTTON_DPAD_DOWN, true)
	assert_int(MenuInput.read().move.y).is_equal(1)
	_button(PAD[Players.P2], JOY_BUTTON_DPAD_DOWN, false)
	await await_idle_frame()
	_button(PAD[Players.P1], JOY_BUTTON_DPAD_LEFT, true)
	assert_int(MenuInput.read().move.x).is_equal(-1)


func test_dpad_holds_the_end_card_ring_like_the_stick() -> void:
	# end_card.gd fills its hold ring while move_left / move_up is held.
	_join_both()
	_button(PAD[Players.P1], JOY_BUTTON_DPAD_UP, true)
	assert_bool(Input.is_action_pressed(Players.action(Players.P1, "move_up"))).is_true()
	_button(PAD[Players.P1], JOY_BUTTON_DPAD_UP, false)
	assert_bool(Input.is_action_pressed(Players.action(Players.P1, "move_up"))).is_false()


func test_solo_hands_the_dpad_to_the_focused_player() -> void:
	Players._assign(Players.P1, PAD[Players.P1])
	Players.set_solo(true, PAD[Players.P1])
	_button(PAD[Players.P1], JOY_BUTTON_DPAD_RIGHT, true)
	assert_vector(Players.move_vector(Players.P1)).is_equal(Vector2.RIGHT)
	assert_vector(Players.move_vector(Players.P2)).is_equal(Vector2.ZERO)
	_button(PAD[Players.P1], JOY_BUTTON_DPAD_RIGHT, false)
	Players.set_solo_focus(Players.P2)
	_button(PAD[Players.P1], JOY_BUTTON_DPAD_RIGHT, true)
	assert_vector(Players.move_vector(Players.P2)).is_equal(Vector2.RIGHT)
	assert_vector(Players.move_vector(Players.P1)).is_equal(Vector2.ZERO)
	_button(PAD[Players.P1], JOY_BUTTON_DPAD_RIGHT, false)
	Players.set_solo(false)
	assert_int(_dpad_count(Players.action(Players.P1, "move_left"))).is_equal(1)
