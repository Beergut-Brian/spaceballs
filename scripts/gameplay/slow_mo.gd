## Half a second of slow motion on the strongest kicks (GAME.md Art direction, Juice). A child of
## main.gd. Engine.time_scale drops to SCALE x whatever it was (so `--timescale` demos keep their
## speed) for SECONDS of real time, then comes back; overlapping calls extend it, and leaving the
## tree always restores the speed. Audio is not slowed (Godot doesn't scale it).
class_name SlowMo
extends Node

## Peak tier from which a kick gets the slow motion: edge of space and space (the sonic-boom kick).
const FROM_TIER := 7
## 0.4x: Kaden's audit 2026-11-10 asked for "around 0.4" (it was 0.25).
const SCALE := 0.4
const SECONDS := 0.5

var _base := -1.0
var _token := 0


static func wants(tier: int, cursed: bool) -> bool:
	return tier >= FROM_TIER and not cursed


func active() -> bool:
	return _base >= 0.0


func trigger() -> void:
	if _base < 0.0:
		_base = Engine.time_scale
	Engine.time_scale = _base * SCALE
	_token += 1
	var mine := _token
	# Real seconds, and it runs through a pause too.
	await get_tree().create_timer(SECONDS, true, false, true).timeout
	if mine == _token:
		restore()


## Back to the speed from before, unless something else (a test, a pause tool) has set its own since.
func restore() -> void:
	if _base >= 0.0 and is_equal_approx(Engine.time_scale, _base * SCALE):
		Engine.time_scale = _base
	_base = -1.0


func _exit_tree() -> void:
	_token += 1
	restore()
