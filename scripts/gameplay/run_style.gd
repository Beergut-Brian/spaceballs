## How a character runs (P-03 / P-04): Jeff flails, Chuck stomps, everyone else jogs. Per Roster
## character, not per player: whoever picks Jeff runs like Jeff in either colour.
## `data/run_styles/<character id>.tres`, else `default.tres`. Kicker moves Body with the bob and the
## stomp; art/scripts/run_style_modifier.gd moves the arms and the costume on top of the run clip.
class_name RunStyle
extends Resource

const DIR := "res://data/run_styles/"

## Body bob at full speed (m): how high each step lifts him.
@export var bob := 0.12
## Steps per second at full speed.
@export var cadence := 4.5
## Side-to-side roll at full speed (rad).
@export var sway := 0.25
## Forward (+) or back (-) lean while running (rad).
@export var lean := 0.0
## Arm swing each side of the run clip's (rad). With `windmill` it is the speed of the turn instead.
@export var arm_swing := 0.4
## Arms go right round (full turns, L and R half a turn apart) instead of swinging.
@export var windmill := false
## 0..1: how much of the run clip's own arm swing he keeps (Chuck's arms stay stiff).
@export var arm_keep := 1.0
## Costume flap (rad) on the comb / hood bone at full speed.
@export var flap := 0.0
## 0 = a round bounce; 1 = a slow lift and a hard drop onto the heel (Chuck's stomp).
@export var stomp := 0.0
## The squash on each hard landing (fraction of height), with a dust puff and a thud.
@export var land_squash := 0.0
## The run clip's speed, times this (a frantic Jeff, a plodding Chuck).
@export var anim_speed := 1.0

static var _cache := {}


static func for_character(id: String) -> RunStyle:
	var key := id if id != "" and ResourceLoader.exists(DIR + id + ".tres") else "default"
	if not _cache.has(key):
		var s: RunStyle = load(DIR + key + ".tres") if ResourceLoader.exists(DIR + key + ".tres") else null
		_cache[key] = s if s else RunStyle.new()
	return _cache[key]


## Body height for stride phase `u` (0..1 = one step) at run amount `run` (0..1).
func lift(u: float, run: float) -> float:
	u = fposmod(u, 1.0)
	var round_ := sin(u * PI)
	# Stomp: lift over 70 % of the step (ease out), then drop in the last 30 % (ease in) and land.
	var up := 0.7
	var stomp_ := sin(u / up * PI * 0.5) if u < up else cos((u - up) / (1.0 - up) * PI * 0.5)
	stomp_ = stomp_ * stomp_ if u >= up else stomp_
	return bob * run * lerpf(round_, stomp_, stomp)
