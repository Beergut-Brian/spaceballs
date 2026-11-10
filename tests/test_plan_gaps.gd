## Plan gaps (PLAN-STATUS.md, 2026-11-10): the height strip's landmark pictures and best-ever flag,
## the tier stamp at the peak, and the other rows this lane built (added below as they land).
class_name TestPlanGaps
extends GdUnitTestSuite

const P1 := Players.P1
const P2 := Players.P2

var _hud: Control
var _ball: Node
var _main: Node
var _card: Control
var _best_before = null


func before() -> void:
	SettingsSandbox.enter()


func after() -> void:
	SettingsSandbox.leave()


func before_test() -> void:
	_best_before = Save.get_value("best_height", null)
	Run.stop_run()


func after_test() -> void:
	for n in [_hud, _main, _card]:
		if is_instance_valid(n):
			n.free()
	Run.demo = false
	Game.demo = false
	Run.save_enabled = true
	Players._device_of = {P1: -1, P2: -1}
	Game._set_state(Game.State.TITLE)
	Engine.time_scale = 1.0
	if is_instance_valid(_ball):
		_ball.free()
	Save.set_value("best_height", _best_before if _best_before != null else 0.0)
	Run.phase = Run.Phase.IDLE
	Run.stop_run()


func _boot_hud() -> Control:
	_hud = load("res://scenes/ui/hud.tscn").instantiate()
	_hud.size = Vector2(1920, 1080)
	get_tree().root.add_child(_hud)
	_hud.size = Vector2(1920, 1080)
	return _hud


# --- V-07 / K-14: the strip is pictures ---------------------------------------------

func test_every_tier_has_a_picture() -> void:
	var tiers: TierSet = load(Run.TIERS_PATH)
	assert_int(tiers.tiers.size()).is_equal(8)
	for t in tiers.tiers:
		assert_bool(TierIcon.has_picture(t.id)).override_failure_message("no picture for %s" % t.id).is_true()


func test_strip_blocks_are_landmark_pictures_top_down() -> void:
	var hud := _boot_hud()
	var blocks: Array = hud.blocks.get_children()
	assert_int(blocks.size()).is_equal(8)
	for b in blocks:
		assert_object(b).is_instanceof(TierIcon)
	assert_str(String((blocks[0] as TierIcon).tier_id)).is_equal("space")
	assert_str(String((blocks[7] as TierIcon).tier_id)).is_equal("backyard")
	# No numbers anywhere on the HUD.
	assert_array(hud.find_children("*", "Label", true, false)).is_empty()


# --- V-11: the tier stamp at the peak ---------------------------------------------------

func test_peak_shows_the_tier_stamp_in_the_kickers_colour() -> void:
	var hud := _boot_hud()
	hud.visible = true
	assert_bool(hud.stamp.visible).is_false()
	Run.ball_stopped.emit(P2, 60.0, 4)
	assert_bool(hud.stamp.visible).is_true()
	assert_str(String(hud.stamp.tier_id)).is_equal("kites")
	assert_that(hud.stamp.ring).is_equal(Players.COLOR[P2])
	# It goes away on its own.
	await get_tree().create_timer(2.0).timeout
	assert_bool(hud.stamp.visible).is_false()


# --- V-08: the best-ever flag rides up with a ball that beats it ----------------------------

func test_best_flag_rides_with_a_ball_that_beats_it() -> void:
	var hud := _boot_hud()
	Save.set_value("best_height", 20.0)
	_ball = load("res://scenes/ball.tscn").instantiate()
	hud.track(P1, _ball)
	Run.kicked.emit(P1, 10.0)
	Run.phase = Run.Phase.FLIGHT_P1
	_ball.set("height", 10.0)
	for i in 3:   # the strip's layout settles
		await get_tree().process_frame
	var at_best: float = hud.best_flag.position.y
	assert_bool(hud._beaten).is_false()
	_ball.set("height", 400.0)
	await get_tree().process_frame
	assert_bool(hud._beaten).is_true()
	assert_float(hud.best_flag.position.y).is_less(at_best)   # higher up the strip
	# Out of the flight it shows the saved best again (Run saves the new one at the stop).
	Run.phase = Run.Phase.IDLE
	await get_tree().process_frame
	assert_float(hud.best_flag.position.y).is_equal_approx(at_best, 0.5)


# --- V-16: half a second of slow motion on the strongest kicks -------------------------------

func test_slow_mo_only_for_the_strongest_uncursed_kicks() -> void:
	for t in range(1, 7):
		assert_bool(SlowMo.wants(t, false)).is_false()
	assert_bool(SlowMo.wants(7, false)).is_true()
	assert_bool(SlowMo.wants(8, false)).is_true()
	assert_bool(SlowMo.wants(8, true)).is_false()


func test_slow_mo_lasts_half_a_real_second_then_restores() -> void:
	var s := SlowMo.new()
	add_child(s)
	Engine.time_scale = 2.0
	s.trigger()
	assert_float(Engine.time_scale).is_equal_approx(2.0 * SlowMo.SCALE, 0.001)
	s.trigger()   # a second one inside the first just extends it
	assert_float(Engine.time_scale).is_equal_approx(2.0 * SlowMo.SCALE, 0.001)
	await get_tree().create_timer(0.3, true, false, true).timeout
	assert_bool(s.active()).is_true()
	await get_tree().create_timer(0.4, true, false, true).timeout
	assert_bool(s.active()).is_false()
	assert_float(Engine.time_scale).is_equal_approx(2.0, 0.001)
	# Leaving the tree mid-slow-mo restores the speed too.
	s.trigger()
	s.free()
	assert_float(Engine.time_scale).is_equal_approx(2.0, 0.001)
	Engine.time_scale = 1.0


# --- C-17 / C-18: the space moment: victory dance and a waving visitor -------------------------

func _boot_main() -> Node:
	Run.save_enabled = false
	Run.demo = true
	_main = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(_main)
	await get_tree().process_frame
	await get_tree().process_frame
	return _main


func test_ball_in_orbit_gets_a_dance_and_a_waving_visitor() -> void:
	var main: Node = await _boot_main()
	Run._in_space[P1] = true
	var ball: Node3D = main.balls[P1]
	ball.orbit_around(ball.global_position + Vector3.UP * 50.0, 1.8, 0.3, 0.0)
	main._on_ball_stopped(P1, 200000.0, 8)
	assert_bool(main.kickers[P1]._dancing).is_true()
	assert_object(main.visitor).is_not_null()
	assert_bool(main.visitor.is_inside_tree()).is_true()
	assert_float(main.visitor.global_position.distance_to(ball.orbit_center)).is_less(4.0)
	# The arm waves (landmark_motion WAVE on the saucer's alien).
	assert_object(main.visitor.find_child("Arm", true, false)).is_not_null()
	# A new run clears it.
	var v: Node = main.visitor
	Run.start_run()
	await get_tree().process_frame
	assert_bool(is_instance_valid(v)).is_false()
	assert_object(main.visitor).is_null()


# --- C-21: the end card shows the run's collection ---------------------------------------

func test_end_card_shelves_hold_each_players_picks() -> void:
	_card = load("res://scenes/ui/end_card.tscn").instantiate()
	get_tree().root.add_child(_card)
	var boots: UpgradeData = load("res://data/upgrades/rocket_boots.tres")
	var hat: UpgradeData = load("res://data/upgrades/tiny_hat.tres")
	Run._upgrades[P1] = [boots, hat] as Array[UpgradeData]
	Run._upgrades[P2] = [hat] as Array[UpgradeData]
	_card.open()
	assert_int(_card.shelves.size()).is_equal(2)
	var p1: Array = _card.shelves[P1].get_children()
	assert_int(p1.size()).is_equal(2)
	assert_str(String(p1[0].get_meta(&"upgrade_id"))).is_equal("rocket_boots")
	assert_object((p1[0].get_child(0) as TextureRect).texture).is_equal(boots.icon)
	assert_int(_card.shelves[P2].get_child_count()).is_equal(1)
	# P1 on the left, P2 on the right; each tile is framed in its player's colour.
	assert_float(_card.shelves[P1].position.x).is_less(_card.shelves[P2].position.x)
	var sb: StyleBoxFlat = p1[0].get_theme_stylebox("panel")
	assert_that(sb.border_color).is_equal(Players.COLOR[P1])
	# They pop in one at a time.
	assert_float(p1[0].scale.x).is_less(0.1)
	await get_tree().create_timer(1.2).timeout
	assert_float(p1[1].scale.x).is_equal_approx(1.0, 0.01)
	# Opening again (the next run) rebuilds them; a player with no picks gets no shelf.
	Run._upgrades[P2] = [] as Array[UpgradeData]
	_card.open()
	await get_tree().process_frame
	assert_bool(_card.shelves.has(P2)).is_false()
	Run._upgrades[P1] = [] as Array[UpgradeData]


# --- A-04: the field music gains a layer per height tier ---------------------------------------

## Where Godot's own decoder wraps the loop (base.get_length() reads the Ogg's last granule, which
## for field_loop.ogg says 30.600 s while the audio is 30.578 s, so compare real playback instead).
func _loop_point(path: String) -> float:
	var s: AudioStreamOggVorbis = load(path)
	s.loop = true
	var pb := s.instantiate_playback()
	pb.start(0.0)
	var mixed := 0
	while pb.get_loop_count() == 0 and mixed < 44100 * 40:
		pb.mix_audio(1.0, 256)
		mixed += 256
	return mixed / 44100.0 - pb.get_playback_position()


func test_field_loop_layers_wrap_with_the_base_loop() -> void:
	var base := _loop_point("res://assets/audio/music/field_loop.ogg")
	assert_float(base).is_between(30.0, 31.0)
	for i in range(1, 4):
		var at := _loop_point("res://assets/audio/music/field_loop_layer_%d.ogg" % i)
		assert_float(at).override_failure_message("layer %d wraps at %f, base at %f" % [i, at, base]) \
				.is_equal_approx(base, 0.0005)


func test_music_level_fades_the_layers_in_and_out() -> void:
	Audio._music.stop()
	Audio._track = ""
	Audio.music("field_loop", 0.01)
	await get_tree().create_timer(0.1).timeout   # the new track swaps in after the old one fades
	var sync := Audio._music.stream as AudioStreamSynchronized
	assert_object(sync).is_not_null()
	assert_int(sync.stream_count).is_equal(4)
	for i in range(1, 4):
		assert_float(sync.get_sync_stream_volume(i)).is_equal(Audio.LAYER_OFF_DB)
	# Tier 5 (main.gd: (tier - 1) / 2) = level 2: layers 1 and 2 up, 3 still silent.
	Audio.music_level((5 - 1) / 2, 0.05)
	await get_tree().create_timer(0.2).timeout
	assert_float(sync.get_sync_stream_volume(1)).is_equal_approx(0.0, 0.01)
	assert_float(sync.get_sync_stream_volume(2)).is_equal_approx(0.0, 0.01)
	assert_float(sync.get_sync_stream_volume(3)).is_equal(Audio.LAYER_OFF_DB)
	# The next kick (main.gd::_begin_kick) drops back to the base loop.
	Audio.music_level(0, 0.05)
	await get_tree().create_timer(0.2).timeout
	for i in range(1, 4):
		assert_float(sync.get_sync_stream_volume(i)).is_equal_approx(Audio.LAYER_OFF_DB, 0.01)
	Audio._music.stop()
	Audio._track = ""


func test_a_level_asked_for_during_the_swap_is_kept() -> void:
	Audio._music.stop()
	Audio._track = ""
	Audio.music("space_pad", 0.01)
	await get_tree().create_timer(0.1).timeout
	Audio.music("field_loop", 0.05)
	Audio.music_level(3)   # a tier crossed while space_pad is still fading out
	await get_tree().create_timer(0.3).timeout
	var sync := Audio._music.stream as AudioStreamSynchronized
	assert_object(sync).is_not_null()
	for i in range(1, 4):
		assert_float(sync.get_sync_stream_volume(i)).is_equal_approx(0.0, 0.01)
	Audio._music.stop()
	Audio._track = ""
