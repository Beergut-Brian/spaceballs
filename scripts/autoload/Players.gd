## Who is holding which controller. Autoload: Players.
## First controller to press a button becomes P1 (green), the next becomes P2 (red).
## Joypad events in the p1_* / p2_* actions are rebound to the joined device so
## Input.is_action_pressed("p1_action") only fires for P1's pad. Keyboard stays as a fallback.
extends Node

const P1 := 0
const P2 := 1
const COLOR := { P1: Color("3cc24a"), P2: Color("e4393c") }
const PREFIX := { P1: "p1_", P2: "p2_" }
const ACTIONS := ["move_left", "move_right", "move_up", "move_down", "action", "jump"]
## Device id for a keyboard or --demo player: no pad events are rebound.
const VIRTUAL := -2

signal player_joined(player: int, device: int)
signal player_left(player: int)

var _device_of := { P1: -1, P2: -1 }


func _ready() -> void:
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	process_mode = Node.PROCESS_MODE_ALWAYS


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		_keyboard_join(event)
		return
	if not (event is InputEventJoypadButton and event.pressed):
		return
	var device: int = event.device
	if device in _device_of.values():
		return
	for player in [P1, P2]:
		if _device_of[player] == -1:
			_assign(player, device)
			return


func is_active(player: int) -> bool:
	return _device_of.get(player, -1) != -1


func device_of(player: int) -> int:
	return _device_of.get(player, -1)


func active_players() -> Array[int]:
	var out: Array[int] = []
	for p in [P1, P2]:
		if is_active(p):
			out.append(p)
	return out


func action(player: int, action_name: String) -> String:
	return PREFIX[player] + action_name


func move_vector(player: int) -> Vector2:
	return Input.get_vector(
		action(player, "move_left"), action(player, "move_right"),
		action(player, "move_up"), action(player, "move_down"))


func join_virtual(player: int) -> void:
	if not is_active(player):
		_assign(player, VIRTUAL)


## Keyboard fallback for development: a P1 key joins P1, a P2 key joins P2.
func _keyboard_join(event: InputEventKey) -> void:
	for player in [P1, P2]:
		if is_active(player):
			continue
		for a in ACTIONS:
			if event.is_action_pressed(action(player, a)):
				_assign(player, VIRTUAL)
				return


func _assign(player: int, device: int) -> void:
	_device_of[player] = device
	for a in ACTIONS:
		if device == VIRTUAL:
			break
		var name := action(player, a)
		for ev in InputMap.action_get_events(name):
			if ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
				ev.device = device
	Audio.play("player_join")
	player_joined.emit(player, device)


func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if connected:
		return
	for player in [P1, P2]:
		if _device_of[player] == device:
			_device_of[player] = -1
			player_left.emit(player)
