## Gap-close lane 3 (PLAN-STATUS.md): the rough edges Kaden notices in play. The kick lands with a
## hit-stop, the ball's comedy drop bounces with a thud each time, the crowd's levels sound different,
## the curse reveal says "uh-oh", the orbit chimes, and every gag plays its own sound (no pitched
## stand-ins left).
class_name TestGapClose3
extends GdUnitTestSuite

const P1 := Players.P1
const P2 := Players.P2
const SFX := "res://assets/audio/sfx/"

var _main: Node
var _ball: Node
var _nodes: Array[Node] = []
var _heard: Array[String] = []


func before() -> void:
	SettingsSandbox.enter("user://test_gap_close_3_settings.json")


func after() -> void:
	SettingsSandbox.leave()
	await Audio.stop_all()


func before_test() -> void:
	_heard.clear()
	Audio.played.connect(_on_played)
	Run.stop_run()


func after_test() -> void:
	if Audio.played.is_connected(_on_played):
		Audio.played.disconnect(_on_played)
	for n in [_main, _ball] + _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()
	Run.demo = false
	Game.demo = false
	Run.save_enabled = true
	Engine.time_scale = 1.0
	Run.phase = Run.Phase.IDLE
	Run.stop_run()


func _on_played(cue: String, _pitch: float) -> void:
	_heard.append(cue)


func _has_cue(cue: String) -> bool:
	return ResourceLoader.exists(SFX + cue + ".ogg") or ResourceLoader.exists(SFX + cue + "_1.ogg")


func _boot_main() -> Node:
	Run.save_enabled = false
	Run.demo = true
	_main = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(_main)
	await get_tree().process_frame
	await get_tree().process_frame
	return _main


func _gd_files(dir: String, out: Array[String]) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		_gd_files(dir.path_join(d), out)


# --- A-02: no gag falls back to a pitched stand-in -----------------------------------------

func test_every_gag_sound_names_a_real_file() -> void:
	var files: Array[String] = []
	for d in ["res://scenes", "res://scripts", "res://art/scripts"]:
		_gd_files(d, files)
	var re := RegEx.create_from_string("_sfx(?:\\.bind)?\\(\"([a-z0-9_]+)\"")
	var asked := 0
	for path in files:
		var src := FileAccess.get_file_as_string(path)
		for m in re.search_all(src):
			asked += 1
			var cue := m.get_string(1)
			assert_bool(_has_cue(cue)).override_failure_message(
					"%s asks for sfx '%s' but only its fallback exists" % [path, cue]).is_true()
	assert_int(asked).is_greater(10)


func test_the_new_cues_load() -> void:
	for cue in ["uh_oh", "inhale", "choo", "burp", "crowd_clap"]:
		assert_bool(_has_cue(cue)).override_failure_message(cue).is_true()
	for f in ["uh_oh.ogg", "inhale.ogg", "choo.ogg", "burp.ogg", "crowd_clap_1.ogg", "crowd_clap_2.ogg"]:
		assert_object(load(SFX + f) as AudioStream).override_failure_message(f).is_not_null()


# --- C-14: the comedy drop bounces, and every touch-down thuds -----------------------------

func test_the_drop_bounces_twice_and_every_touch_down_thuds() -> void:
	_ball = load("res://scenes/ball.tscn").instantiate()
	get_tree().root.add_child(_ball)
	await get_tree().process_frame
	_ball.place_on_tee(Vector3(0, 0, 0))
	var hits: Array[float] = []
	var lands_at_hit: Array[int] = []
	_ball.bounced.connect(func(s: float) -> void:
		hits.append(s)
		lands_at_hit.append(_heard.count("land")))
	var squash := [1.0]
	_ball.bounced.connect(func(s: float) -> void:
		if s >= 1.0:
			await get_tree().create_timer(0.05).timeout
			squash[0] = _ball.mesh.scale.y, CONNECT_ONE_SHOT)
	_ball._drop()
	await _ball.returned
	assert_array(hits).is_equal([1.0, 0.65, 0.3])
	assert_array(lands_at_hit).is_equal([1, 2, 3])   # a thud with each, not one at the end
	assert_float(squash[0]).is_less(0.95)            # the first touch-down squashes the ball
	# The bounces get smaller: the second rise is lower than the first.
	assert_float(_ball.DROP_BOUNCES[0]).is_greater(_ball.DROP_BOUNCES[1])


# --- V-15: a hit-stop on every ordinary kick -----------------------------------------------

func test_hit_stop_holds_the_world_for_a_blink_then_lets_go() -> void:
	var hs := HitStop.new()
	_nodes.append(hs)
	add_child(hs)
	hs.trigger(1)
	assert_float(Engine.time_scale).is_equal_approx(HitStop.SCALE, 0.0001)
	assert_bool(hs.active()).is_true()
	await get_tree().create_timer(HitStop.seconds_for(1) + 0.05, true, false, true).timeout
	assert_float(Engine.time_scale).is_equal_approx(1.0, 0.0001)
	assert_bool(hs.active()).is_false()


func test_bigger_kicks_hold_longer_and_slow_mo_kicks_skip_it() -> void:
	assert_float(HitStop.seconds_for(1)).is_equal_approx(HitStop.SHORTEST, 0.0001)
	assert_float(HitStop.seconds_for(6)).is_equal_approx(HitStop.LONGEST, 0.0001)
	assert_float(HitStop.seconds_for(4)).is_greater(HitStop.seconds_for(2))
	assert_bool(HitStop.wants(3, false)).is_true()
	assert_bool(HitStop.wants(3, true)).is_false()                 # a curse: no punch
	assert_bool(HitStop.wants(SlowMo.FROM_TIER, false)).is_false()  # slow motion is its payoff


func test_a_real_kick_gets_the_hit_stop() -> void:
	var main: Node = await _boot_main()
	Run.start_run()
	Run.phase = Run.Phase.KICK_P1
	main._on_kick_contact(1.0, P1)
	assert_bool(main.hit_stop.active()).is_true()
	assert_float(Engine.time_scale).is_less(0.1)
	await get_tree().create_timer(HitStop.LONGEST + 0.05, true, false, true).timeout
	assert_float(Engine.time_scale).is_equal_approx(1.0, 0.0001)


# --- V-19: clap, cheer and roar sound different ---------------------------------------------

func test_crowd_levels_each_have_their_own_sound() -> void:
	var crowd := Node3D.new()
	for i in 3:
		var m := Node3D.new()
		m.position.z = i
		crowd.add_child(m)
	add_child(crowd)
	_nodes.append(crowd)
	var r := CrowdReactions.new()
	crowd.add_child(r)
	r.setup(crowd)
	const L := CrowdReactions.Level
	for pair in [[L.CLAP, "crowd_clap"], [L.GREAT, "cheer"], [L.ROAR, "crowd_wild"], [L.AWW, "crowd_aww"]]:
		_heard.clear()
		r.react(pair[0])
		assert_str(_heard[0] if _heard.size() > 0 else "").is_equal(pair[1])
	for c in ["crowd_clap", "cheer", "crowd_wild", "crowd_aww"]:
		assert_bool(_has_cue(c)).is_true()


# --- U-11: the reveal's shiver says "uh-oh" before the trombone -----------------------------

func test_curse_reveal_says_uh_oh_then_the_curse() -> void:
	var pick: Control = load("res://scenes/ui/upgrade_pick.tscn").instantiate()
	_nodes.append(pick)
	add_child(pick)
	Run._ensure_data()
	var normals: Array[UpgradeData] = []
	normals.assign(Run.pool.filter(func(c): return c.kind == "normal").slice(0, 3))
	Run.demo = false
	pick.open({P1: normals}, [P1])
	Engine.time_scale = 4.0
	await pick.reveal_curse(P1, Run.upgrade_by_id(&"sneeze"))
	var uh := _heard.find("uh_oh")
	assert_int(uh).is_greater_equal(0)
	assert_int(_heard.find("curse")).is_greater(uh)
	assert_int(_heard.find("crowd_aww")).is_greater(_heard.find("curse"))
	pick.close()


# --- C-16: the ball settles into orbit with its own chime -----------------------------------

func test_a_ball_settling_into_orbit_chimes() -> void:
	var main: Node = await _boot_main()
	Run.start_run()
	Run._in_space[P1] = true
	var ball: Node = main.balls[P1]
	ball.height = 200000.0
	ball.peak_height = 200000.0
	ball._reach_peak()
	assert_array(_heard).contains(["orbit_chime"])
	assert_array(_heard).not_contains(["tier_up"])
	assert_bool(_has_cue("orbit_chime")).is_true()


# --- C-20: the end card camera comes in close -----------------------------------------------

func test_the_end_card_camera_is_close() -> void:
	var main: Node = await _boot_main()
	Run.demo = false
	main._begin_end()
	assert_float(main.rig._orbit_r).is_equal_approx(main.END_ORBIT_RADIUS, 0.001)
	assert_float(main.END_ORBIT_RADIUS).is_less(6.5)
	# Both of them inside the frame's middle: the camera looks at the pair from END_ORBIT_RADIUS.
	for p in [P1, P2]:
		var d: float = main.kickers[p].global_position.distance_to(main.rig._center)
		assert_float(d).is_less(main.END_ORBIT_RADIUS * 0.5)
	main.end_card.close()
