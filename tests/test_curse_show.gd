## Playtest 2026-11-10 #1: every curse is obvious. The reveal demo (2-3 s, its own sound), the
## badge over the cursed player until his cursed kick is done, the cause on camera at the kick, and
## the "that's why" callback at the landing spot. Pictures and sounds only.
class_name TestCurseShow
extends GdUnitTestSuite

const JEFF := preload("res://scenes/players/jeff.tscn")
const BALL := preload("res://scenes/ball.tscn")
const SFX := "res://assets/audio/sfx/"


func before_test() -> void:
	PhysicsPin.enter(4.0)   # fixed 60 Hz step, seeded RNG, no curse left in Run by another suite
	Run._ensure_data()


func after_test() -> void:
	PhysicsPin.leave()
	await Audio.stop_all()


func _curses() -> Array[UpgradeData]:
	var out: Array[UpgradeData] = []
	out.assign(Run.pool.filter(func(c: UpgradeData) -> bool: return c.is_curse()))
	return out


static func _has_sfx(cue: String) -> bool:
	return ResourceLoader.exists(SFX + cue + ".ogg") or ResourceLoader.exists(SFX + cue + "_1.ogg")


## Floor + camera + Jeff + a CurseShow with a stand-in rig that records beats.
func _setup() -> Array:
	var root := Node3D.new()
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60, 1, 60)
	shape.shape = box
	floor_body.add_child(shape)
	floor_body.position = Vector3(0, -0.5, 0)
	root.add_child(floor_body)
	var cam := Camera3D.new()
	root.add_child(cam)
	add_child(root)
	auto_free(root)
	cam.global_position = Vector3(0, 1.5, 6)
	cam.look_at(Vector3(0, 1, 0))
	var k: Kicker = JEFF.instantiate()
	root.add_child(k)
	var show := CurseShow.new()
	var rig := BeatRig.new()
	root.add_child(rig)
	show.rig = rig
	root.add_child(show)
	return [k, show, cam, rig, root]


func test_every_curse_has_its_own_cause_and_sound() -> void:
	var curses := _curses()
	assert_int(curses.size()).is_greater_equal(7)
	var causes := {}
	for c in curses:
		var cause := CurseShow.cause_of(c)
		assert_str(String(cause)).override_failure_message("%s has no cause" % c.id).is_not_equal("generic")
		causes[cause] = true
		assert_bool(_has_sfx(CurseShow.cue_of(c))).override_failure_message("%s: no sound file" % c.id).is_true()
		assert_object(c.icon).override_failure_message("%s: no icon" % c.id).is_not_null()
	assert_int(causes.size()).is_equal(curses.size())   # each its own picture
	assert_str(String(CurseShow.cause_of(null))).is_equal("")


func test_reveal_lasts_two_to_three_seconds_then_the_badge_pops_on(timeout := 120000) -> void:
	for c in _curses():
		var bits := _setup()
		var k: Kicker = bits[0]
		var show: CurseShow = bits[1]
		await get_tree().physics_frame
		var rest: Vector3 = k.body.scale
		var reveal_seen := [false]
		var game_t := [0.0]   # game seconds (scaled), so a busy machine can't skew it
		var watch := func() -> void:
			reveal_seen[0] = reveal_seen[0] or show.has_node("CurseReveal")
			game_t[0] += get_process_delta_time()
		get_tree().process_frame.connect(watch)
		await show.reveal(0, k, c, bits[2])
		get_tree().process_frame.disconnect(watch)
		var game_s: float = game_t[0]
		assert_float(game_s).override_failure_message("%s: %.2f s" % [c.id, game_s]).is_between(2.0, 3.2)
		assert_bool(reveal_seen[0]).override_failure_message("%s: no demo on screen" % c.id).is_true()
		assert_bool(show.has_badge(0)).override_failure_message("%s: no badge" % c.id).is_true()
		assert_vector(k.body.scale).is_equal_approx(rest, Vector3.ONE * 0.01)
		assert_bool(k.frog).is_false()   # the frog demo turns him back
		await get_tree().process_frame
		assert_bool(show.has_node("CurseReveal")).is_false()


func test_badge_floats_over_him_until_his_cursed_kick_is_done() -> void:
	var bits := _setup()
	var k: Kicker = bits[0]
	var show: CurseShow = bits[1]
	var ball: Node3D = BALL.instantiate()
	bits[4].add_child(ball)
	ball.global_position = Vector3(0, 0.35, -1.0)
	var c := Run.upgrade_by_id(&"sneeze")
	show.badge(0, k, c)
	k.global_position = Vector3(3, 0, 0)
	await get_tree().create_timer(0.6).timeout
	var b := show.badge_of(0)
	assert_object(b).is_not_null()
	assert_float(b.global_position.x).is_equal_approx(3.0, 0.05)
	assert_float(b.global_position.y).is_greater(1.8)
	assert_bool(b.find_child("Icon", true, false) is Sprite3D).is_true()
	assert_bool(show.has_badge(1)).is_false()
	var why := show.callback(0, ball, c)
	assert_bool(show.has_badge(0)).is_false()
	assert_object(why).is_not_null()
	await get_tree().create_timer(2.2).timeout
	assert_bool(is_instance_valid(why)).is_false()   # a short beat, then gone


func test_butterflies_land_on_the_ball_and_pull_it_off_course() -> void:
	var bits := _setup()
	var k: Kicker = bits[0]
	var show: CurseShow = bits[1]
	var rig: BeatRig = bits[3]
	var ball: Node3D = BALL.instantiate()
	bits[4].add_child(ball)
	ball.global_position = Vector3(0, 0.35, -1.0)
	var c := Run.upgrade_by_id(&"butterfly")
	ball.set(&"flight", 3)   # PEAK: holding, as after a cursed kick
	ball.set(&"_hold", 5.0)
	show.bite(0, k, ball, c)
	assert_int(rig.beats.size()).is_equal(1)
	assert_object(rig.beats[0][0]).is_same(ball.get(&"mesh"))
	await get_tree().create_timer(1.1).timeout
	var mesh: Node3D = ball.get(&"mesh")
	var off := mesh.global_position - ball.global_position
	assert_float(Vector2(off.x, off.z).length()).is_greater(0.8)
	var bugs: Array = show._riders[0]
	assert_int(bugs.size()).is_equal(3)
	for bug in bugs:
		assert_float((bug as Node3D).global_position.distance_to(mesh.global_position)).is_less(0.6)
	# That's why: the butterflies fly to the icon over the ball, the ball comes home on the drop.
	var why := show.callback(0, ball, c)
	assert_int(rig.beats.size()).is_equal(2)
	assert_bool(bugs.all(func(b): return is_instance_valid(b) and b.get_parent() == why)).is_true()
	ball.set(&"flight", 4)   # DROP
	await get_tree().process_frame
	await get_tree().process_frame
	assert_vector(mesh.position).is_equal(Vector3.ZERO)


func test_the_peel_gets_a_beat_under_his_foot() -> void:
	var bits := _setup()
	var k: Kicker = bits[0]
	var show: CurseShow = bits[1]
	var rig: BeatRig = bits[3]
	var peel := Node3D.new()
	bits[4].add_child(peel)
	k._prop = peel
	show.windup(0, k, null, Run.upgrade_by_id(&"banana_peel"))
	assert_int(rig.beats.size()).is_equal(1)
	assert_object(rig.beats[0][0]).is_same(peel)
	k._prop = null


func test_every_curse_gets_a_camera_beat_at_the_kick() -> void:
	for c in _curses():
		var bits := _setup()
		var show: CurseShow = bits[1]
		var rig: BeatRig = bits[3]
		var ball: Node3D = BALL.instantiate()
		bits[4].add_child(ball)
		show.bite(0, bits[0], ball, c)
		assert_int(rig.beats.size()).override_failure_message(String(c.id)).is_equal(1)
		show.clear_all()


func test_camera_rig_beat_moves_in_then_lets_go() -> void:
	var rig: Node3D = load("res://scripts/gameplay/camera_rig.gd").new()
	var cam := Camera3D.new()
	cam.name = "Camera"
	rig.add_child(cam)
	add_child(rig)
	auto_free(rig)
	cam.global_position = Vector3(0, 5, 20)
	var target := Node3D.new()
	rig.add_child(target)
	target.global_position = Vector3(2, 1, 0)
	rig.beat(target, 0.4, 3.0)
	assert_bool(rig.beating()).is_true()
	await get_tree().create_timer(0.2).timeout
	assert_float(cam.global_position.distance_to(target.global_position)).is_less(10.0)
	await get_tree().create_timer(0.4).timeout
	assert_bool(rig.beating()).is_false()


## Stands in for the camera rig: records every beat.
class BeatRig:
	extends Node
	var beats: Array = []
	func beat(target: Node3D, seconds: float = 0.7, dist: float = 3.2) -> void:
		beats.append([target, seconds, dist])
