## Every curse is obvious (playtest 2026-11-10 #1). Pictures and sounds only, never text:
## - reveal(): when the picked card flips, a 2-3 s demo over the kicker of what the curse will do
##   (butterflies land on a little ball and carry it off; the peel shoots his feet up; ...);
## - badge(): a small curse icon floats over the cursed player until his cursed kick is done;
## - windup() / bite(): at the run-up and the kick, the cause is on screen and the camera gives it a
##   beat (butterflies land on the ball and pull it sideways; the peel pops under his foot);
## - callback(): after the kick, "that's why": the curse icon pops over the ball's landing spot with
##   the cause animating round it.
## main.gd owns one (`curse_show`) and calls these; everything here is cosmetic (heights come from Run).
class_name CurseShow
extends Node3D

const REVEAL_TIME := 2.4
## Hiccups reveal: his hop speed on each "hic" and how far each one knocks the demo ball back.
const HIC_HOP := 5.0
const HIC_KNOCK := 0.42
const CALLBACK_TIME := 1.6
const BEAT_TIME := 0.75
const BADGE_SIZE := 0.8
const BADGE_GAP := 0.45
const CALLBACK_SIZE := 1.3
const DRIFT_TIME := 1.0
## Butterflies riding the ball at the kick: bigger than the prop, so they read in the close beat.
const RIDER_SIZE := 1.7
## The "that's why" camera looks this far over the icon (keeps the icon clear of the tier stamp).
const CALLBACK_LOOK_UP := 0.7
## A camera nearer than this to him puts his badge beside his head, where the shot still has it.
const CLOSE_CAM := 6.0
const PURPLE := Color(0.62, 0.36, 0.92)
const ICON_DIR := "res://assets/sprites/upgrades/"

## The cause each curse card shows (by id; unknown curses fall back on their gag, then `generic`).
const CAUSES := {
	&"butterfly": &"butterfly", &"banana_peel": &"peel", &"sneeze": &"sneeze",
	&"shoelaces_tied": &"laces", &"too_much_lunch": &"lunch", &"hiccups": &"hiccup",
	&"kiss_the_frog": &"frog",
}
## Each cause's own sound (assets/audio/sfx/<cue>[_n].ogg): the reveal demo and the callback use it.
const CUES := {
	&"butterfly": "butterfly", &"peel": "slip", &"sneeze": "choo", &"laces": "trip",
	&"lunch": "burp", &"hiccup": "hic", &"frog": "frog_bloop", &"generic": "poof",
}
## How far the cause pulls the ball off course after the kick (metres sideways, visual only).
const DRIFT := { &"butterfly": 1.6, &"sneeze": 1.1, &"hiccup": 0.8 }

## Camera rig with beat() (main.gd sets it); null in tests that have none.
var rig: Node
## kicker -> metres from his feet to the top of his gear (main.gd's _stack_height); else 1.8.
var height_of: Callable
## Each player's real ball mesh (main.gd sets them): the reveal demo uses a little copy of his own
## ball, so it reads as "my ball".
var ball_looks: Array = []

var _badges := {}      # player -> {node, kicker, h, t}
var _riders := {}      # player -> Array[Node3D]: butterflies sitting on the ball
var _drifts := {}      # player -> {ball, dir, dist, t}
var _disc: Texture2D


static func cause_of(curse: UpgradeData) -> StringName:
	if curse == null:
		return &""
	if CAUSES.has(curse.id):
		return CAUSES[curse.id]
	if curse.scene_override != null:
		return &"frog"
	match curse.windup_anim:
		&"slip": return &"peel"
		&"chase": return &"butterfly"
		&"sneeze": return &"sneeze"
		&"trip": return &"laces"
		&"waddle": return &"lunch"
	if curse.run_fx == &"bounce":
		return &"hiccup"
	return &"generic"


static func cue_of(curse: UpgradeData) -> String:
	return CUES.get(cause_of(curse), "poof")


func _process(delta: float) -> void:
	for p in _badges.keys():
		var b: Dictionary = _badges[p]
		var node: Node3D = b.node
		var k: Node3D = b.kicker
		if not is_instance_valid(node) or not is_instance_valid(k):
			_badges.erase(p)
			continue
		b.t += delta
		if fmod(b.t, 0.5) < delta:
			b.h = _height(k)
		node.visible = k.is_visible_in_tree()
		# Glides (not jumps) between over-his-head and beside-his-head when a close beat starts.
		var spot := badge_spot(k, b.h) + Vector3.UP * sin(b.t * 3.0) * 0.06
		node.global_position = node.global_position.lerp(spot, clampf(delta * 12.0, 0.0, 1.0))
		# About the same size on screen whatever the shot: small in the close-up beats.
		var cam := get_viewport().get_camera_3d()
		if cam and not _popping(node):
			node.scale = Vector3.ONE * clampf(cam.global_position.distance_to(node.global_position) / 12.0, 0.2, 1.0)
		node.rotation.z = sin(b.t * 2.0) * 0.12
	for p in _drifts.keys():
		var d: Dictionary = _drifts[p]
		var ball: Node3D = d.ball
		if not is_instance_valid(ball) or not is_instance_valid(ball.get(&"mesh")):
			_drifts.erase(p)
			continue
		var mesh: Node3D = ball.get(&"mesh")
		# The drop teleports the ball back over the tee: the pull ends there.
		if int(ball.get(&"flight")) >= 4:   # Ball.Flight.DROP
			mesh.position = Vector3.ZERO
			_drifts.erase(p)
			continue
		d.t += delta
		var u := clampf(d.t / DRIFT_TIME, 0.0, 1.0)
		var off: Vector3 = d.dir * d.dist * (1.0 - (1.0 - u) * (1.0 - u))
		if d.hops:
			off.y += absf(sin(u * PI * 3.0)) * 0.25 * (1.0 - u)
		mesh.position = ball.global_basis.inverse() * off
	for p in _riders.keys():
		var list: Array = _riders[p]
		var ball: Node3D = _drifts[p].ball.get(&"mesh") if _drifts.has(p) else null
		for i in list.size():
			var bug: Node3D = list[i]
			if not is_instance_valid(bug) or ball == null:
				continue
			var a := TAU * i / list.size() + Time.get_ticks_msec() / 300.0
			bug.global_position = ball.global_position + Vector3(cos(a) * 0.34, 0.4 + sin(a * 2.0) * 0.05, sin(a) * 0.34)


# --- the reveal -----------------------------------------------------------------

## The card just flipped into `curse`: a picture-only demo beside `k` (facing `cam`) of what it will
## do to him, with its own sound, then his curse badge pops on. Awaitable, REVEAL_TIME seconds.
func reveal(p: int, k: Node3D, curse: UpgradeData, cam: Camera3D = null) -> void:
	var cause := cause_of(curse)
	var body := _body(k)
	var rest_rot := body.rotation
	var rest_scale := body.scale
	var toward := k.global_basis.z
	var side := k.global_basis.x
	if cam:
		toward = cam.global_position - k.global_position
		side = cam.global_basis.x
	toward = _flat(toward).normalized() if _flat(toward).length() > 0.01 else Vector3.BACK
	side = _flat(side).normalized() if _flat(side).length() > 0.01 else Vector3.RIGHT
	var stage := Node3D.new()
	stage.name = "CurseReveal"
	add_child(stage)
	var feet := k.global_position
	var ball := _mini_ball(p)
	stage.add_child(ball)
	var ball_at := feet + side * 0.4 + toward * 0.45 + Vector3.UP * 0.2
	# Where the curse sends the ball: back and a little aside, so it stays in his half of the screen.
	var away := (side * 0.5 - toward).normalized()
	ball.global_position = ball_at
	var tw := stage.create_tween()
	tw.tween_callback(Fx.pop.bind(ball, 1.4))
	match cause:
		&"butterfly":
			# Three butterflies flutter down onto the ball and carry it off sideways.
			var bugs: Array[Node3D] = []
			for i in 3:
				var bug := _prop(curse, 1.3)
				stage.add_child(bug)
				bug.global_position = ball_at + away * (0.5 * i - 0.3) + Vector3.UP * 1.7
				bugs.append(bug)
			tw.tween_callback(Audio.play.bind(cue_of(curse), null, 1.0))
			tw.tween_method(func(u: float) -> void:
				for i in bugs.size():
					var perch := ball.global_position + Vector3(cos(i * 2.1) * 0.2, 0.22, sin(i * 2.1) * 0.2)
					bugs[i].global_position = bugs[i].global_position.lerp(perch, u)
					bugs[i].position.y += sin(u * 30.0 + i) * 0.02, 0.0, 1.0, 0.7)
			tw.tween_callback(Audio.play.bind("butterfly", null, 1.3))
			tw.tween_method(func(u: float) -> void:
				ball.global_position = ball_at + away * u * 0.9 + Vector3.UP * sin(u * PI) * 0.9
				for i in bugs.size():
					bugs[i].global_position = ball.global_position + Vector3(cos(i * 2.1 + u * 9.0) * 0.2, 0.24, sin(i * 2.1 + u * 9.0) * 0.2), 0.0, 1.0, 0.8)
			tw.tween_callback(func() -> void:
				for bug in bugs:
					var fly := bug.create_tween()
					fly.tween_property(bug, "global_position", bug.global_position + Vector3(randf_range(-1, 1), 2.5, 0), 0.6))
			_sad_plop(tw, ball, ball_at + away * 0.95)
		&"peel":
			# The peel slides under his foot, his feet fly up, he lands on his bottom.
			var peel := _prop(curse, 1.6)
			stage.add_child(peel)
			peel.global_position = feet + toward * 0.3 + Vector3.UP * 0.03
			peel.scale = Vector3.ONE * 0.01
			tw.tween_property(peel, "scale", Vector3.ONE * 1.6, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_interval(0.25)
			tw.tween_callback(Audio.play.bind(cue_of(curse), null, 1.0))
			tw.tween_callback(_hop.bind(k, 3.0))
			tw.tween_property(body, "rotation:x", rest_rot.x + 1.2, 0.25).set_trans(Tween.TRANS_BACK)
			tw.parallel().tween_property(peel, "global_position", peel.global_position + toward * 0.9 + Vector3.UP * 0.6, 0.3)
			tw.parallel().tween_property(peel, "rotation:y", TAU * 2.0, 0.5)
			tw.tween_callback(func() -> void:
				Audio.play("land", null, 0.7)
				Fx.puff(feet + Vector3.UP * 0.1, Color(1.0, 0.93, 0.4), 0.6))
			# The peel lands on the grass beside him, out of his face.
			tw.parallel().tween_property(peel, "global_position", feet - side * 0.7 + Vector3.UP * 0.03, 0.3).set_ease(Tween.EASE_IN)
			tw.tween_interval(0.35)
			tw.tween_property(body, "rotation", rest_rot, 0.25)
			_sad_plop(tw, ball, ball_at + away * 0.3)
		&"sneeze":
			# Ah... ah... CHOO! The sneeze blows the ball away sideways.
			for i in 2:
				tw.tween_callback(Audio.play.bind("inhale", null, 1.2 + i * 0.2))
				tw.tween_property(body, "scale", rest_scale * Vector3(0.94, 1.08 + 0.05 * i, 0.94), 0.32)
				tw.parallel().tween_property(body, "rotation:x", rest_rot.x + 0.15 * (i + 1), 0.32)
				tw.tween_interval(0.1)
			tw.tween_callback(func() -> void:
				Audio.play(cue_of(curse))
				for j in 3:
					Fx.puff(feet + Vector3.UP * 1.4 + (ball_at - feet - Vector3.UP * 1.2) * (0.3 + 0.3 * j), Color(0.88, 1.0, 0.94), 0.45))
			tw.tween_property(body, "rotation:x", rest_rot.x - 0.5, 0.08)
			tw.parallel().tween_property(body, "scale", rest_scale, 0.12)
			tw.parallel().tween_property(ball, "global_position", ball_at + away * 1.0 + Vector3.UP * 0.3, 0.45).set_ease(Tween.EASE_OUT)
			tw.tween_property(body, "rotation", rest_rot, 0.2)
			_sad_plop(tw, ball, ball_at + away * 1.0)
		&"laces":
			# The laces knot at his feet; two tied-up hops and a wobbly tip forward.
			var laces := _prop(curse, 3.0)
			stage.add_child(laces)
			laces.global_position = feet + Vector3.UP * 0.1 + toward * 0.35
			laces.scale = Vector3.ONE * 0.01
			tw.tween_property(laces, "scale", Vector3.ONE * 3.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(laces, "rotation:y", TAU, 0.4)
			for i in 2:
				tw.tween_callback(Audio.play.bind("hop", null, 1.1 + i * 0.15))
				tw.tween_callback(_hop.bind(k, 2.5))
				tw.tween_property(body, "rotation:x", rest_rot.x - 0.3 - 0.25 * i, 0.25)
			tw.tween_callback(Audio.play.bind(cue_of(curse), null, 1.0))
			tw.tween_property(body, "rotation:x", rest_rot.x - 1.0, 0.18).set_ease(Tween.EASE_IN)
			tw.tween_callback(Fx.puff.bind(feet + toward * 0.6, Color(0.85, 0.75, 0.6), 0.5))
			tw.tween_interval(0.25)
			tw.tween_property(body, "rotation", rest_rot, 0.25)
			_sad_plop(tw, ball, ball_at + away * 0.2)
		&"lunch":
			# His tummy swells, he rocks, burps, and the ball barely rolls.
			tw.tween_callback(Audio.play.bind("waddle", null, 0.9))
			tw.tween_property(body, "scale", rest_scale * Vector3(1.4, 0.95, 1.4), 0.4).set_trans(Tween.TRANS_BACK)
			for i in 2:
				tw.tween_property(body, "rotation:z", rest_rot.z + 0.35, 0.2).set_trans(Tween.TRANS_SINE)
				tw.tween_property(body, "rotation:z", rest_rot.z - 0.35, 0.2).set_trans(Tween.TRANS_SINE)
			tw.tween_property(body, "rotation:z", rest_rot.z, 0.1)
			tw.tween_callback(func() -> void:
				Audio.play(cue_of(curse))
				Fx.puff(feet + Vector3.UP * 1.5 + toward * 0.4, Color(0.85, 1.0, 0.7), 0.7))
			tw.tween_interval(0.25)
			tw.tween_property(body, "scale", rest_scale, 0.3)
			_sad_plop(tw, ball, ball_at + away * 0.25)
		&"hiccup":
			# HIC! HIC! HIC! Each hiccup jolts him (stretch, a big hop), a hiccup bubble pops out of his
			# mouth, and the ball gets knocked back hard, a little further each time.
			var mouth := feet + Vector3.UP * 1.45 + toward * 0.3
			for i in 3:
				var from := ball_at + away * HIC_KNOCK * i
				var knock := ball_at + away * HIC_KNOCK * (i + 1)
				tw.tween_callback(func() -> void:
					Audio.play(cue_of(curse), null, 1.0 + i * 0.12)
					_hop(k, HIC_HOP)
					_hic_bubble(stage, mouth + side * (0.12 * i - 0.12), toward)
					Fx.puff(mouth, Color(0.7, 0.9, 1.0), 0.3))
				tw.tween_property(body, "scale", rest_scale * Vector3(0.82, 1.28, 0.82), 0.06).set_ease(Tween.EASE_OUT)
				tw.parallel().tween_property(body, "rotation:x", rest_rot.x - 0.25, 0.06)
				tw.parallel().tween_method(func(u: float) -> void:
					ball.global_position = from.lerp(knock, u) + Vector3.UP * sin(u * PI) * 0.4
					ball.rotation.z = -(i + u) * 2.5, 0.0, 1.0, 0.26)
				tw.tween_property(body, "scale", rest_scale, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				tw.parallel().tween_property(body, "rotation:x", rest_rot.x, 0.16)
				tw.tween_interval(0.12)
			_sad_plop(tw, ball, ball_at + away * HIC_KNOCK * 3.0)
		&"frog":
			# He turns into the frog for a moment; the ball just dribbles off.
			tw.tween_callback(func() -> void:
				if k.has_method(&"set_frog"):
					k.call(&"set_frog", true, curse.scene_override)
				Audio.play(cue_of(curse)))
			tw.tween_interval(0.3)
			tw.tween_callback(Audio.play.bind("frog", null, 1.2))
			tw.tween_method(func(u: float) -> void:
				ball.global_position = ball_at + away * 0.6 * u + Vector3.UP * absf(sin(u * PI * 3.0)) * 0.12 * (1.0 - u)
				ball.rotation.z = -u * 6.0, 0.0, 1.0, 0.7)
			tw.tween_interval(0.3)
			tw.tween_callback(func() -> void:
				if k.has_method(&"set_frog"):
					k.call(&"set_frog", false))
			_sad_plop(tw, ball, ball_at + away * 0.6)
		_:
			tw.tween_callback(Audio.play.bind(cue_of(curse), null, 1.0))
			tw.tween_interval(1.2)
			_sad_plop(tw, ball, ball_at)
	await get_tree().create_timer(REVEAL_TIME).timeout
	if is_instance_valid(body):
		body.rotation = rest_rot
		body.scale = rest_scale
	stage.queue_free()
	badge(p, k, curse)


## A hiccup bubble: a shiny see-through bubble that pops out of his mouth, floats up and bursts.
func _hic_bubble(stage: Node3D, at: Vector3, toward: Vector3) -> Node3D:
	var b := MeshInstance3D.new()
	b.name = "HicBubble"
	var sph := SphereMesh.new()
	sph.radius = 0.2
	sph.height = 0.4
	b.mesh = sph
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.72, 0.92, 1.0, 0.55)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.rim_enabled = true
	mat.rim = 1.0
	mat.metallic_specular = 1.0
	mat.roughness = 0.05
	b.material_override = mat
	var shine := MeshInstance3D.new()
	var dot := SphereMesh.new()
	dot.radius = 0.05
	dot.height = 0.1
	shine.mesh = dot
	var smat := StandardMaterial3D.new()
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.albedo_color = Color.WHITE
	shine.material_override = smat
	shine.position = Vector3(-0.08, 0.09, 0.12)
	b.add_child(shine)
	stage.add_child(b, true)   # readable names: HicBubble, HicBubble2, ...
	b.global_position = at
	b.scale = Vector3.ONE * 0.05
	var tw := b.create_tween()
	tw.tween_property(b, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(b, "global_position", at + toward * 0.25 + Vector3.UP * 0.25, 0.18)
	tw.tween_property(b, "global_position", at + toward * 0.3 + Vector3.UP * 0.75, 0.45).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void:
		Audio.play("sky_pop", null, 1.7)
		Fx.puff(b.global_position, Color(0.8, 0.95, 1.0), 0.3)
		b.queue_free())
	return b


## The ball's sad little hop and plop that ends every reveal demo.
func _sad_plop(tw: Tween, ball: Node3D, at: Vector3) -> void:
	tw.tween_property(ball, "global_position", at + Vector3.UP * 0.25, 0.14).set_ease(Tween.EASE_OUT)
	tw.tween_property(ball, "global_position", at, 0.14).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		Audio.play("squeak", null, 0.6)
		Fx.puff(at, Color(0.75, 0.7, 0.85), 0.35)
		Fx.pop(ball, 1.6))


# --- the badge --------------------------------------------------------------

## A small curse icon floating over `k` until clear_badge(p) (his cursed kick is done).
func badge(p: int, k: Node3D, curse: UpgradeData) -> void:
	clear_badge(p, false)
	var node := _icon(curse, BADGE_SIZE)
	node.name = "CurseBadge%d" % p
	add_child(node)
	var h := _height(k)
	node.global_position = badge_spot(k, h)
	node.scale = Vector3.ONE * 0.01
	node.set_meta(&"popping", true)
	var tw := node.create_tween()
	tw.tween_property(node, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(node.set_meta.bind(&"popping", false))
	Audio.play("poof", null, 1.3)
	_badges[p] = {node = node, kicker = k, h = h, t = 0.0}


## Over his head; in the pick (whose camera stops just above his head) and whenever the camera is in
## close on him (a curse beat, and the moment after it while the camera eases out; over his head
## that cut it off) beside it instead.
func badge_spot(k: Node3D, h: float) -> Vector3:
	if Run.phase == Run.Phase.PICK or _close_cam(k):
		return k.global_position + _flat(k.global_basis.x).normalized() * 0.62 + Vector3.UP * minf(h, 1.6) * 0.72
	return k.global_position + Vector3.UP * (h + BADGE_GAP)


func _close_cam(k: Node3D) -> bool:
	if rig != null and is_instance_valid(rig) and rig.has_method(&"beating") and bool(rig.call(&"beating")):
		return true
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	return cam != null and cam.global_position.distance_to(k.global_position) < CLOSE_CAM


func _popping(node: Node3D) -> bool:
	return node.has_meta(&"popping") and node.get_meta(&"popping")


func has_badge(p: int) -> bool:
	return _badges.has(p) and is_instance_valid(_badges[p].node)


func badge_of(p: int) -> Node3D:
	return _badges[p].node if has_badge(p) else null


func clear_badge(p: int, poof := true) -> void:
	if not _badges.has(p):
		return
	var node: Node3D = _badges[p].node
	_badges.erase(p)
	if not is_instance_valid(node):
		return
	node.set_meta(&"popping", true)
	if poof and node.is_inside_tree():
		Fx.puff(node.global_position, PURPLE.lightened(0.3), 0.4)
		var tw := node.create_tween()
		tw.tween_property(node, "scale", Vector3.ONE * 0.01, 0.2).set_ease(Tween.EASE_IN)
		tw.tween_callback(node.queue_free)
	else:
		node.queue_free()


## A new run, or the run is over: no badges, no riders, nothing pulling a ball.
func clear_all() -> void:
	for p in _badges.keys():
		clear_badge(p, false)
	for p in _riders.keys():
		for bug in _riders[p]:
			if is_instance_valid(bug):
				bug.queue_free()
	_riders.clear()
	for p in _drifts.keys():
		var ball: Node3D = _drifts[p].ball
		if is_instance_valid(ball) and is_instance_valid(ball.get(&"mesh")):
			(ball.get(&"mesh") as Node3D).position = Vector3.ZERO
	_drifts.clear()


# --- the bite ---------------------------------------------------------------

## The cursed run-up turns into its gag: the cause gets a beat on camera.
func windup(_p: int, k: Node3D, _ball: Node3D, curse: UpgradeData) -> void:
	var cause := cause_of(curse)
	var prop: Node3D = k.get(&"_prop") if &"_prop" in k else null
	match cause:
		&"peel", &"laces":
			# The peel right there under his foot; the knotted laces on his shoes.
			if is_instance_valid(prop):
				Fx.pop(prop, 1.8)
				Fx.puff(prop.global_position + Vector3.UP * 0.15, Color(1.0, 0.93, 0.4) if cause == &"peel" else Color(1, 1, 1), 0.4)
				_beat(prop, BEAT_TIME, 2.6)
			else:
				_beat(_chest(k), BEAT_TIME, 3.0)
		_:
			# His chest, not his feet: the butterfly circling his head, his tummy, his sneeze and his
			# badge all stay in the shot. (A beat on the butterfly itself swung the camera round with
			# it into a top-down shot.)
			_beat(_chest(k), BEAT_TIME, 3.4)


## The kick lands (after ball.launch): the cause acts on the ball, on camera.
func bite(p: int, k: Node3D, ball: Node3D, curse: UpgradeData) -> void:
	var cause := cause_of(curse)
	if curse == null or not is_instance_valid(ball):
		return
	var mesh: Node3D = ball.get(&"mesh") if &"mesh" in ball else ball
	var side := _flat(k.global_basis.x).normalized() if _flat(k.global_basis.x).length() > 0.01 else Vector3.RIGHT
	if randf() < 0.5:
		side = -side
	match cause:
		&"butterfly":
			# Butterflies land on the ball and pull it off course.
			var bugs: Array = []
			for i in 3:
				var bug := _prop(curse, RIDER_SIZE)
				add_child(bug)
				bug.global_position = mesh.global_position + Vector3(randf_range(-1.0, 1.0), 1.5, randf_range(-0.5, 0.5))
				bugs.append(bug)
			_riders[p] = bugs
			Audio.play(cue_of(curse), null, 1.2)
		&"sneeze":
			var face := k.global_position + Vector3.UP * 1.4
			for j in 3:
				Fx.puff(face.lerp(mesh.global_position, 0.3 + 0.35 * j), Color(0.88, 1.0, 0.94), 0.5)
		&"hiccup":
			Audio.play(cue_of(curse), null, 1.1)
			Fx.puff(mesh.global_position + Vector3.UP * 0.3, Color(0.7, 0.9, 1.0), 0.4)
		&"laces", &"peel":
			var prop: Node3D = k.get(&"_prop") if &"_prop" in k else null
			if is_instance_valid(prop):
				Fx.pop(prop, 1.6)
		_:
			pass
	if DRIFT.has(cause):
		_drifts[p] = {ball = ball, dir = side, dist = DRIFT[cause], t = 0.0, hops = cause == &"hiccup"}
	_beat(mesh, BEAT_TIME, 3.0)


# --- the "that's why" -------------------------------------------------------

## After the cursed kick stops: the curse icon pops over the ball's landing spot with the cause
## animating round it, then the player's badge goes (his cursed kick is done).
func callback(p: int, ball: Node3D, curse: UpgradeData) -> Node3D:
	clear_badge(p)
	if curse == null or not is_instance_valid(ball):
		return null
	var cause := cause_of(curse)
	var mesh: Node3D = ball.get(&"mesh") if &"mesh" in ball else ball
	var at := mesh.global_position + Vector3.UP * 1.0
	var pop := Node3D.new()
	pop.name = "CurseWhy%d" % p
	add_child(pop)
	pop.global_position = at
	var icon := _icon(curse, CALLBACK_SIZE)
	pop.add_child(icon)
	icon.scale = Vector3.ONE * 0.01
	var tw := pop.create_tween()
	tw.tween_property(icon, "scale", Vector3.ONE * 1.15, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(icon, "scale", Vector3.ONE, 0.1)
	Audio.play(cue_of(curse))
	Fx.puff(at, PURPLE.lightened(0.3), 0.8)
	# The cause, round the icon.
	var props: Array[Node3D] = []
	var riders: Array = _riders.get(p, [])
	_riders.erase(p)
	match cause:
		&"butterfly":
			for i in 3:
				var bug: Node3D = riders[i] if i < riders.size() and is_instance_valid(riders[i]) else _prop(curse, 1.0)
				if bug.get_parent():
					bug.reparent(pop)
				else:
					pop.add_child(bug)
				props.append(bug)
		&"frog":
			var frog := curse.scene_override.instantiate() as Node3D if curse.scene_override else _prop(curse, 1.0)
			if &"size" in frog:
				frog.set(&"size", 0.6)
			pop.add_child(frog)
			props.append(frog)
		&"sneeze", &"lunch", &"hiccup", &"generic":
			pass
		_:
			var prop := _prop(curse, 3.0 if cause == &"laces" else 1.4)
			pop.add_child(prop)
			props.append(prop)
	for bug in riders:
		if is_instance_valid(bug) and not props.has(bug):
			bug.queue_free()
	var puff_color := {&"sneeze": Color(0.88, 1.0, 0.94), &"lunch": Color(0.85, 1.0, 0.7), &"hiccup": Color(0.7, 0.9, 1.0)}
	var anim := pop.create_tween()
	anim.tween_method(func(u: float) -> void:
		for i in props.size():
			if not is_instance_valid(props[i]):
				continue
			var a := TAU * i / maxf(props.size(), 1) + u * TAU * 1.5
			match cause:
				&"butterfly":
					props[i].position = Vector3(cos(a) * 0.9, sin(a * 2.0) * 0.25, sin(a) * 0.4)
				&"frog":
					props[i].position = Vector3(0.9, -0.8 + absf(sin(u * PI * 4.0)) * 0.4, 0.0)
				&"peel":
					props[i].position = Vector3(0.9, -0.3, 0.0)
					props[i].rotation = Vector3(0.0, u * TAU * 2.0, sin(u * TAU * 2.0) * 0.4)
				_:
					props[i].position = Vector3(0.9, -0.4, 0.0)
					props[i].rotation.z = sin(u * TAU * 3.0) * 0.5
		icon.rotation.z = sin(u * TAU * 2.0) * 0.12
		if puff_color.has(cause) and fmod(u * 4.0, 1.0) < 0.04:
			Fx.puff(pop.global_position + Vector3(0.8, -0.3, 0.0), puff_color[cause], 0.35), 0.0, 1.0, CALLBACK_TIME)
	anim.tween_property(pop, "scale", Vector3.ONE * 0.01, 0.2).set_ease(Tween.EASE_IN)
	anim.tween_callback(pop.queue_free)
	# The camera looks a little above the icon, so the icon sits below the HUD's tier stamp
	# (top centre) instead of under it.
	var look := Node3D.new()
	look.name = "Look"
	pop.add_child(look)
	look.position = Vector3.UP * CALLBACK_LOOK_UP
	_beat(look, 0.9, 4.0)
	return pop


# --- bits -------------------------------------------------------------------

func _beat(target: Node3D, seconds: float, dist: float) -> void:
	if rig and is_instance_valid(rig) and rig.has_method(&"beat") and is_instance_valid(target):
		rig.call(&"beat", target, seconds, dist)


## His chest (the Body attach point), so a close beat keeps him, his badge and the cause in frame.
## The Body node sits at his feet: a beat on it put the badge and the butterfly off the top.
func _chest(k: Node3D) -> Node3D:
	if k.has_method(&"attach_point"):
		var n: Node3D = k.call(&"attach_point", &"body")
		if n:
			return n
	return _body(k)


func _body(k: Node3D) -> Node3D:
	var b := k.get_node_or_null(^"Body") as Node3D
	return b if b else k


func _height(k: Node3D) -> float:
	if height_of.is_valid():
		return float(height_of.call(k))
	return 1.8


func _hop(k: Node3D, v: float) -> void:
	if is_instance_valid(k) and k is CharacterBody3D:
		(k as CharacterBody3D).velocity.y = v


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


## The curse's icon on a round purple badge, always facing the camera, drawn over everything.
func _icon(curse: UpgradeData, size: float) -> Node3D:
	var root := Node3D.new()
	var disc := Sprite3D.new()
	disc.texture = _disc_texture()
	disc.pixel_size = size * 1.25 / 128.0
	disc.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	disc.no_depth_test = true
	disc.shaded = false
	disc.render_priority = 1
	root.add_child(disc)
	var tex: Texture2D = curse.icon if curse and curse.icon else null
	if tex == null and curse and ResourceLoader.exists(ICON_DIR + String(curse.id) + ".png"):
		tex = load(ICON_DIR + String(curse.id) + ".png")
	if tex:
		var pic := Sprite3D.new()
		pic.name = "Icon"
		pic.texture = tex
		pic.pixel_size = size / float(maxi(tex.get_width(), 1))
		pic.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		pic.no_depth_test = true
		pic.shaded = false
		pic.render_priority = 2
		root.add_child(pic)
	return root


## A white disc with a purple ring (the curse colour), made once.
func _disc_texture() -> Texture2D:
	if _disc:
		return _disc
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := (n - 1) / 2.0
	for y in n:
		for x in n:
			var d := Vector2(x - c, y - c).length() / c
			var col := Color(0, 0, 0, 0)
			if d <= 1.0:
				col = PURPLE if d > 0.84 else Color(1, 1, 1, 0.92)
				col.a *= clampf((1.0 - d) * c, 0.0, 1.0)
			img.set_pixel(x, y, col)
	_disc = ImageTexture.create_from_image(img)
	return _disc


## The curse's own prop (butterfly, peel, laces, ...), silent: we play its sounds here.
func _prop(curse: UpgradeData, s: float) -> Node3D:
	var node: Node3D
	if curse and curse.visual:
		node = curse.visual.instantiate() as Node3D
	if node == null:
		var m := MeshInstance3D.new()
		var sph := SphereMesh.new()
		sph.radius = 0.15
		sph.height = 0.3
		m.mesh = sph
		var mat := StandardMaterial3D.new()
		mat.albedo_color = PURPLE
		m.material_override = mat
		node = m
	for key in [&"gag_cue", &"fallback_cue"]:
		if key in node:
			node.set(key, &"")
	node.scale = Vector3.ONE * s
	return node


## A little copy of the game ball for the reveal demo (a plain white ball if there is none).
func _mini_ball(p: int) -> MeshInstance3D:
	var look: MeshInstance3D = ball_looks[p] if p >= 0 and p < ball_looks.size() else null
	if is_instance_valid(look):
		var copy := look.duplicate(0) as MeshInstance3D
		copy.name = "DemoBall"
		copy.transform = Transform3D.IDENTITY
		copy.scale = Vector3.ONE * 0.7
		return copy
	var m := MeshInstance3D.new()
	m.name = "DemoBall"
	var sph := SphereMesh.new()
	sph.radius = 0.2
	sph.height = 0.4
	m.mesh = sph
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.98, 0.92)
	mat.rim_enabled = true
	mat.rim = 0.5
	m.material_override = mat
	return m
