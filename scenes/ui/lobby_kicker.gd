## Spaceballs' lobby character: stands in for the template's drawn placeholder in Spots/P*/Character
## and drives the real 3D kicker that main.gd stands behind the spot (Jeff left, Chuck right).
## The lobby calls set_joined(on) and wave(); readied, he keeps cheering until rest().
extends Control

@export var player: int = 0

var kicker: Kicker


func set_joined(_on: bool) -> void:
	rest()


func wave() -> void:
	if kicker == null:
		return
	kicker.set_waiting(false)   # CHEER: arms up, happy face, a bounce
	kicker.cheer()


## Back to standing on the spot (un-readied, or a fresh lobby).
func rest() -> void:
	if kicker:
		kicker.set_idle()
