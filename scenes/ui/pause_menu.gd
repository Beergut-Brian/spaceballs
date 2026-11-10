## Pause menu: three big icon buttons, no text. Resume, Restart (back to the lobby), Back to the
## launcher. Either player's stick moves the cursor, A presses, B resumes (Start is Game's).
## Shown while Game.state == PAUSED; runs while the tree is paused.
extends Control

enum Choice { RESUME, RESTART, DOOR }

var focus := Choice.RESUME

@onready var _buttons := [$Buttons/Resume, $Buttons/Restart, $Buttons/Door]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Game.state_changed.connect(_on_state_changed)
	visible = Game.state == Game.State.PAUSED
	_set_focus(Choice.RESUME, false)


func _process(_delta: float) -> void:
	if not visible or Game.state != Game.State.PAUSED:
		return
	var move := 0
	var a := false
	var b := false
	for p in Players.active_players():
		if Input.is_action_just_pressed(Players.action(p, "move_left")):
			move = -1
		elif Input.is_action_just_pressed(Players.action(p, "move_right")):
			move = 1
		a = a or Input.is_action_just_pressed(Players.action(p, "action"))
		b = b or Input.is_action_just_pressed(Players.action(p, "jump"))
	if move != 0:
		move_focus(move)
	if a:
		press()
	elif b:
		Game.resume()


func move_focus(dir: int) -> void:
	_set_focus(clampi(focus + dir, 0, _buttons.size() - 1) as Choice)


func press(choice: Choice = focus) -> void:
	_set_focus(choice, false)
	_buttons[choice].press()
	match choice:
		Choice.RESUME:
			Game.resume()
		Choice.RESTART:
			Audio.play("ui_confirm")
			Game.to_lobby()
		Choice.DOOR:
			Audio.play("ui_back")
			Game.quit()


func _set_focus(to: Choice, sound := true) -> void:
	# Bumping the end still makes a sound: every move does something.
	if sound:
		Audio.play("ui_move")
	focus = to
	for i in _buttons.size():
		_buttons[i].focused = i == focus


func _on_state_changed(_from: int, to: int) -> void:
	visible = to == Game.State.PAUSED
	if visible:
		_set_focus(Choice.RESUME, false)
