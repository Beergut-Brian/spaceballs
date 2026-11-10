## End card: confetti, then two buttons. A on the big green one (focused) goes back to the lobby
## (restart_requested); stick right onto the door and A goes back to the launcher (Game.quit()).
## The characters are the 3D kickers, framed by the camera's space orbit. Systems owns structure,
## Art the look.
extends Control

signal restart_requested()

const ACCEPT_AFTER := 1.2

var _t := 0.0
var door_focused := false

@onready var confetti: CPUParticles2D = $Confetti
@onready var button_hint: Control = $ButtonHint
@onready var door: Control = $Door


func _ready() -> void:
	visible = false
	set_process(false)


func open() -> void:
	_t = 0.0
	_focus_door(false, false)
	visible = true
	confetti.emitting = true
	Audio.play("confetti")
	set_process(true)


func close() -> void:
	visible = false
	confetti.emitting = false
	set_process(false)


func _process(delta: float) -> void:
	_t += delta
	button_hint.visible = _t > ACCEPT_AFTER
	door.visible = button_hint.visible and not Run.demo
	button_hint.scale = Vector2.ONE * (1.0 + (0.0 if door_focused else 0.1 * sin(_t * 6.0)))
	if _t < ACCEPT_AFTER:
		return
	if Run.demo and _t > ACCEPT_AFTER + 1.0:
		_accept()
		return
	for p in [Players.P1, Players.P2]:
		if Input.is_action_just_pressed(Players.action(p, "move_right")) \
				or Input.is_action_just_pressed(Players.action(p, "move_down")):
			_focus_door(true)
		elif Input.is_action_just_pressed(Players.action(p, "move_left")) \
				or Input.is_action_just_pressed(Players.action(p, "move_up")):
			_focus_door(false)
		if Input.is_action_just_pressed(Players.action(p, "action")):
			press()
			return


## A on whatever is focused: the big button back to the lobby, or the door to the launcher.
func press() -> void:
	if door_focused:
		door.press()
		Audio.play("ui_back")
		Game.quit()
	else:
		_accept()


func _focus_door(on: bool, sound := true) -> void:
	if sound:
		Audio.play("ui_move")
	door_focused = on
	door.focused = on
	button_hint.modulate = Color(1, 1, 1, 0.55) if on else Color.WHITE


func _accept() -> void:
	Audio.play("ui_confirm")
	Fx.flash(button_hint)
	close()
	restart_requested.emit()
