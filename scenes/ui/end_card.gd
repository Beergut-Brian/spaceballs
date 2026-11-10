## End card stub: confetti, and A (either player) restarts the run. The characters are the
## 3D kickers, framed by the camera's space orbit. Systems owns structure, Art the look.
extends Control

signal restart_requested()

const ACCEPT_AFTER := 1.2

var _t := 0.0

@onready var confetti: CPUParticles2D = $Confetti
@onready var button_hint: Control = $ButtonHint


func _ready() -> void:
	visible = false
	set_process(false)


func open() -> void:
	_t = 0.0
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
	button_hint.scale = Vector2.ONE * (1.0 + 0.1 * sin(_t * 6.0))
	if _t < ACCEPT_AFTER:
		return
	if Run.demo and _t > ACCEPT_AFTER + 1.0:
		_accept()
		return
	for p in [Players.P1, Players.P2]:
		if Input.is_action_just_pressed(Players.action(p, "action")):
			_accept()
			return


func _accept() -> void:
	Audio.play("ui_confirm")
	Fx.flash(button_hint)
	close()
	restart_requested.emit()
