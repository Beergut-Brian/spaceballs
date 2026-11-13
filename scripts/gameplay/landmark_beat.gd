## The tier beat on a landmark (playtest 2026-11-12): when a ball passes the landmark's height,
## HeightLadder calls beat() and the landmark's critters react, one beat, no text. The tier sparkle
## and gag sound come from the ball (ball.gd _check_tiers), the strip pop from the HUD.
## Who reacts is set by the builder (art/tools/build_scenes.gd) as node meta `react`:
##   &"startle": the cat jumps, puffs up and spins round.
##   &"scatter": a bird flies up and away, then settles back.
## No autoloads here: the scene builder (a -s script) attaches it to the landmark roots.
class_name LandmarkBeat
extends Node3D

const SCATTER_OUT := 0.45
const SCATTER_AWAY := 1.6
const SCATTER_BACK := 1.4

## How many beats this landmark has fired (tests read it).
var beats := 0


func beat() -> void:
	beats += 1
	var k := 0
	for n in find_children("*", "Node3D", true, false):
		match n.get_meta(&"react", &""):
			&"startle":
				_startle(n as Node3D)
			&"scatter":
				_scatter(n as Node3D, k)
				k += 1


## Every node that reacts on a beat.
func reactors() -> Array[Node]:
	return find_children("*", "Node3D", true, false).filter(func(n: Node) -> bool: return n.has_meta(&"react"))


func _tween_for(n: Node3D) -> Tween:
	var old: Tween = n.get_meta(&"beat_tween") if n.has_meta(&"beat_tween") else null
	if old and old.is_valid():
		old.kill()
	var tw := n.create_tween()
	n.set_meta(&"beat_tween", tw)
	return tw


func _startle(n: Node3D) -> void:
	if not n.has_meta(&"rest_scale"):
		n.set_meta(&"rest_scale", n.scale)
		n.set_meta(&"rest_yaw", n.rotation.y)
	var base: Vector3 = n.get_meta(&"rest_scale")
	var yaw: float = n.get_meta(&"rest_yaw")
	n.scale = base
	n.rotation.y = yaw
	var tw := _tween_for(n)
	# Fur up and a full spin while it leaps (its HOP motion jumps higher for the moment).
	tw.tween_property(n, "scale", Vector3(base.x * 1.35, base.y * 1.5, base.z * 1.35), 0.08)
	tw.parallel().tween_property(n, "rotation:y", yaw + TAU, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(n, "scale", base, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	if &"amount" in n and &"speed" in n:
		if not n.has_meta(&"rest_hop"):
			n.set_meta(&"rest_hop", Vector2(n.get(&"amount"), n.get(&"speed")))
		var hop: Vector2 = n.get_meta(&"rest_hop")
		n.set(&"amount", hop.x * 4.0)
		n.set(&"speed", hop.y * 1.8)
		tw.tween_callback(func() -> void:
			n.set(&"amount", hop.x)
			n.set(&"speed", hop.y))


func _scatter(n: Node3D, k: int) -> void:
	if not n.has_meta(&"rest_pos"):
		n.set_meta(&"rest_pos", n.position)
	var rest: Vector3 = n.get_meta(&"rest_pos")
	n.position = rest
	# Up and out, each bird its own way (golden angle), back to its spot a moment later.
	var a := k * 2.39996
	var away := rest + Vector3(cos(a) * 3.5, 3.0 + (k % 3) * 0.8, sin(a) * 3.5)
	var tw := _tween_for(n)
	tw.tween_property(n, "position", away, SCATTER_OUT).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_interval(SCATTER_AWAY)
	tw.tween_property(n, "position", rest, SCATTER_BACK).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
