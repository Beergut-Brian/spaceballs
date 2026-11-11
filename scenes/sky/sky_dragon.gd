## The Hill's Dragon (openjar-characters v0.5.1, vendored in assets/landmarks/dragon/) on a cameo in
## the Clouds: big, sleepy and friendly, gliding through on her far-too-small wings. Not playable,
## never in the way: a bonk is cosmetic (SkyObject contract), the ball always flies on.
## Glide: her rig's `flap` action on a loop, plus a slow body bob, roll and sway in code.
## Bonk: a happy sleepy roll (`cheer`, then a full slow roll, then `sleep`), a cloud puff and a
## rumble-purr. Passing by: a slow `wave`.
class_name SkyDragon
extends SkyObject

const GLB := preload("res://assets/landmarks/dragon/dragon.glb")
const ROLL_TIME := 1.6

var model: Node3D
var anim: AnimationPlayer
var _t := 0.0
var _rolling := false


static func make() -> SkyDragon:
	var d := SkyDragon.new()
	d.name = "Dragon"
	d.reaction = Reaction.BONK
	d.cue = &"dragon_purr"
	d.hit_radius = 1.5
	d.hit_offset = Vector3(0.0, 1.6, 0.0)
	d.near_radius = 3.2
	d.push = 8.0
	d.hold = 0.25
	d.spin = 4.0
	d.shake = 0.12
	d.puff_color = Color.WHITE
	var gag := Node3D.new()
	gag.name = "Gag"
	d.add_child(gag)
	d.model = GLB.instantiate() as Node3D
	d.model.name = "Body"
	gag.add_child(d.model)
	d.anim = d.model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	return d


func _ready() -> void:
	_t = randf() * TAU
	if anim and anim.has_animation(&"flap"):
		anim.get_animation(&"flap").loop_mode = Animation.LOOP_LINEAR
		anim.play(&"flap", 0.2, 0.7)   # the tiny wings, flapping (nothing much happens)


func _process(delta: float) -> void:
	super(delta)
	_t += delta
	if gag == null or _rolling:
		return
	# The glide: a slow bob, a lazy roll into the drift, a little sway of the head end.
	gag.position.y = sin(_t * 1.3) * 0.35
	gag.rotation.z = sin(_t * 0.9) * 0.12
	gag.rotation.x = sin(_t * 1.3 + 0.8) * 0.06


func hit(ball: Node3D) -> void:
	if was_hit:
		return
	was_hit = true
	_rolling = true
	_sfx("dragon_purr", null, 1.0)   # the rumble-purr
	# The ball bounces off her soft tummy, a little higher and spinning (cosmetic).
	if ball.has_method("sky_react"):
		ball.sky_react(Vector3.UP * push, hold, spin)
	if field and field.has_method("shake"):
		field.shake(shake)
	# A puff of cloud all round her.
	for k in 4:
		_puff(global_position + Vector3(randf_range(-1, 1), 1.0 + randf() * 1.5, randf_range(-1, 1)) * size,
				Color(1, 1, 1), 1.2 * size)
	# The happy sleepy roll.
	if anim:
		anim.play(&"cheer", 0.15)
	var tw := create_tween()
	tw.tween_property(gag, "rotation:z", gag.rotation.z + TAU, ROLL_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(gag, "position:y", 1.2, ROLL_TIME * 0.5).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		gag.rotation.z = 0.0
		if anim and anim.has_animation(&"sleep"):
			anim.play(&"sleep", 0.3))
	tw.tween_property(gag, "position:y", 0.0, 0.8).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void: _rolling = false)


func near(_ball: Node3D) -> void:
	if was_near or was_hit:
		return
	was_near = true
	if anim and anim.has_animation(&"wave"):
		anim.play(&"wave", 0.2)
		anim.queue(&"flap")
	_puff(global_position + Vector3.UP * size * 2.0, Color.WHITE, 0.6 * size)
