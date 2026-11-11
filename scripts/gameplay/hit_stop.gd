## A hit-stop on the boot: the world holds still for a blink at the moment of contact, longer for a
## bigger kick, so every kick lands with a "thwack" you can feel. A child of main.gd, next to SlowMo.
## Engine.time_scale drops to SCALE x whatever it was for real seconds, then comes back. The kicks
## that get SlowMo skip it (the slow motion is their payoff), and so do curses and frogs.
class_name HitStop
extends Node

const SCALE := 0.02
## Real seconds for a tier-1 kick and for the biggest one that gets a hit-stop.
const SHORTEST := 0.04
const LONGEST := 0.09

var _base := -1.0
var _token := 0


static func seconds_for(tier: int) -> float:
	return lerpf(SHORTEST, LONGEST, clampf((tier - 1) / 5.0, 0.0, 1.0))


static func wants(tier: int, cursed: bool) -> bool:
	return not cursed and not SlowMo.wants(tier, cursed)


func active() -> bool:
	return _base >= 0.0


func trigger(tier: int) -> void:
	if _base < 0.0:
		_base = Engine.time_scale
	Engine.time_scale = _base * SCALE
	_token += 1
	var mine := _token
	await get_tree().create_timer(seconds_for(tier), true, false, true).timeout
	if mine == _token:
		restore()


## Back to the speed from before, unless something else has set its own since.
func restore() -> void:
	if _base >= 0.0 and is_equal_approx(Engine.time_scale, _base * SCALE):
		Engine.time_scale = _base
	_base = -1.0


func _exit_tree() -> void:
	_token += 1
	restore()
