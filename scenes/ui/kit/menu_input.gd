## Menu input from every joined pad (and the keyboard fallback): one shared cursor, either player
## drives it. read() once a frame; `a` / `b` hold the player who pressed, or -1.
class_name MenuInput
extends RefCounted


static func read() -> Dictionary:
	var move := Vector2i.ZERO
	var a := -1
	var b := -1
	for p in Players.active_players():
		if Input.is_action_just_pressed(Players.action(p, "move_up")):
			move.y = -1
		elif Input.is_action_just_pressed(Players.action(p, "move_down")):
			move.y = 1
		if Input.is_action_just_pressed(Players.action(p, "move_left")):
			move.x = -1
		elif Input.is_action_just_pressed(Players.action(p, "move_right")):
			move.x = 1
		if a == -1 and Input.is_action_just_pressed(Players.action(p, "action")):
			a = p
		elif b == -1 and Input.is_action_just_pressed(Players.action(p, "jump")):
			b = p
	return { "move": move, "a": a, "b": b }
