## Gap-close lane 4 (PLAN-STATUS.md, Kaden's 2026-11-10 audit): the music grows over the run, the
## slow motion is 0.4x, each player has a session-best pennant on the strip, and the crowd claps
## back when a waiting player cheers.
class_name TestGapClose4
extends GdUnitTestSuite

const P1 := Players.P1
const P2 := Players.P2
const MainScript := preload("res://scenes/main.gd")
const Hud := preload("res://scenes/ui/hud.gd")

var _main: Node
var _hud: Control
var _heard: Array[String] = []


func before() -> void:
	SettingsSandbox.enter("user://test_gap_close_4_settings.json")


func after() -> void:
	SettingsSandbox.leave()
	await Audio.stop_all()


func before_test() -> void:
	_heard.clear()
	Hud.session_best.clear()
	Audio.played.connect(_on_played)
	Run.stop_run()


func after_test() -> void:
	if Audio.played.is_connected(_on_played):
		Audio.played.disconnect(_on_played)
	for n in [_main, _hud]:
		if is_instance_valid(n):
			n.free()
	Hud.session_best.clear()
	Run.demo = false
	Game.demo = false
	Run.save_enabled = true
	Players._device_of = {P1: -1, P2: -1}
	Game._set_state(Game.State.TITLE)
	Engine.time_scale = 1.0
	Run.phase = Run.Phase.IDLE
	Run.stop_run()


func _on_played(cue: String, _pitch: float) -> void:
	_heard.append(cue)


func _boot_main() -> Node:
	Run.save_enabled = false
	Run.demo = true
	_main = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(_main)
	await get_tree().process_frame
	await get_tree().process_frame
	return _main


# --- A-04: the music steps up over the run, not only inside one flight ------------------------

func test_music_level_per_tier() -> void:
	var want := {1: 0, 2: 0, 3: 1, 4: 1, 5: 2, 6: 2, 7: 3, 8: 3}
	for t in want:
		assert_int(MainScript.music_level_for(t)).is_equal(want[t])


func test_music_floor_grows_with_the_run_and_leaves_room_to_climb() -> void:
	assert_int(MainScript.music_floor(1)).is_equal(0)   # a fresh run: just the loop
	assert_int(MainScript.music_floor(4)).is_equal(0)
	assert_int(MainScript.music_floor(5)).is_equal(1)   # the run has been high: the shaker stays
	assert_int(MainScript.music_floor(8)).is_equal(2)
	for t in range(1, 9):
		# A flight to the run's best tier always has at least one layer more to bring in.
		assert_int(MainScript.music_level_for(t)).is_greater(MainScript.music_floor(t) - 1)
		assert_int(MainScript.music_floor(t)).is_less(3)


func test_a_kick_late_in_a_high_run_keeps_the_layers() -> void:
	var main: Node = await _boot_main()
	await get_tree().create_timer(0.6).timeout   # the boot's field_loop fade-in settles
	main._run_top_tier = 6
	main._begin_kick(P1)
	await get_tree().create_timer(0.2).timeout
	assert_int(Audio._level).is_equal(MainScript.music_floor(6))
	assert_int(Audio._level).is_equal(1)
	main._run_top_tier = 1
	main._begin_kick(P1)
	await get_tree().create_timer(0.2).timeout
	assert_int(Audio._level).is_equal(0)


# --- V-16: slow motion around 0.4x for half a second ----------------------------------------

func test_slow_mo_is_about_point_four_for_under_half_a_second() -> void:
	assert_float(SlowMo.SCALE).is_between(0.35, 0.45)
	assert_float(SlowMo.SECONDS).is_between(0.3, 0.5)
	var s := SlowMo.new()
	add_child(s)
	s.trigger()
	assert_float(Engine.time_scale).is_equal_approx(0.4, 0.001)
	await get_tree().create_timer(0.6, true, false, true).timeout
	assert_float(Engine.time_scale).is_equal_approx(1.0, 0.001)   # it ends on its own
	s.free()


# --- V-08: each player's best peak this session is a pennant in their colour ------------------

func _boot_hud() -> Control:
	_hud = load("res://scenes/ui/hud.tscn").instantiate()
	_hud.size = Vector2(1920, 1080)
	get_tree().root.add_child(_hud)
	_hud.size = Vector2(1920, 1080)
	return _hud


func test_session_pennants_mark_each_players_best_peak() -> void:
	var hud := _boot_hud()
	await get_tree().process_frame
	assert_bool(hud.pennants[P1].visible).is_false()   # nothing kicked yet
	Run.ball_stopped.emit(P1, 30.0, Run.tier_of_height(30.0))
	Run.ball_stopped.emit(P2, 900.0, Run.tier_of_height(900.0))
	await get_tree().process_frame
	assert_bool(hud.pennants[P1].visible).is_true()
	assert_bool(hud.pennants[P2].visible).is_true()
	# The higher ball's pennant is higher on the strip; P1 left of it, P2 right.
	assert_float(hud.pennants[P2].position.y).is_less(hud.pennants[P1].position.y)
	assert_float(hud.pennants[P1].position.x).is_less(0.0)
	assert_float(hud.pennants[P2].position.x).is_greater_equal(hud.strip.size.x)
	# A lower kick later doesn't pull it down; a higher one moves it up.
	var y1: float = hud.pennants[P1].position.y
	Run.ball_stopped.emit(P1, 5.0, Run.tier_of_height(5.0))
	await get_tree().process_frame
	assert_float(hud.pennants[P1].position.y).is_equal_approx(y1, 0.5)
	Run.ball_stopped.emit(P1, 2000.0, Run.tier_of_height(2000.0))
	await get_tree().process_frame
	assert_float(hud.pennants[P1].position.y).is_less(y1)
	assert_float(Hud.session_best[P1]).is_equal(2000.0)


func test_pennants_are_the_player_colours() -> void:
	var hud := _boot_hud()
	for p in [P1, P2]:
		var flag: Polygon2D = hud.pennants[p].get_node("Flag")
		assert_object(flag.color).is_equal(Players.COLOR[p])


# --- K-11: the crowd claps back at a waiting player's cheer ---------------------------------

func test_a_waiting_players_cheer_gets_the_crowd_clapping_and_nothing_else() -> void:
	var main: Node = await _boot_main()
	Engine.time_scale = 4.0
	var t := 0.0
	while Run.phase != Run.Phase.KICK_P1 and t < 10.0:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	assert_int(Run.phase).is_equal(Run.Phase.KICK_P1)
	Game._set_state(Game.State.PLAYING)
	var k: Kicker = main.kickers[P2]
	var cheers := []
	k.cheered.connect(func(p: int) -> void: cheers.append(p))
	var power_before := Run.power_of(P2)
	_heard.clear()
	var action := Players.action(P2, "action")
	Input.action_press(action)
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release(action)
	assert_array(cheers).contains([P2])
	assert_array(_heard).contains(["cheer", "crowd_clap"])
	assert_int(main._crowd._hop.size()).is_greater(0)   # fans hop
	# Feedback only: no kick, no power, the phase is still P1's.
	assert_int(Run.phase).is_equal(Run.Phase.KICK_P1)
	assert_float(Run.power_of(P2)).is_equal(power_before)
	assert_bool(k.state == Kicker.State.WINDUP or k.state == Kicker.State.GAG).is_false()


func test_mashing_cheer_never_stacks_the_clap() -> void:
	var c := CrowdReactions.new()
	add_child(c)
	var crowd := Node3D.new()
	for i in 5:
		crowd.add_child(Node3D.new())
	add_child(crowd)
	c.setup(crowd)
	_heard.clear()
	for i in 6:
		c.echo_cheer()
	assert_int(_heard.count("crowd_clap")).is_equal(1)
	c.free()
	crowd.free()
