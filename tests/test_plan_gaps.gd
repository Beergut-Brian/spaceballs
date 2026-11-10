## Plan gaps (PLAN-STATUS.md, 2026-11-10): the height strip's landmark pictures and best-ever flag,
## the tier stamp at the peak, and the other rows this lane built (added below as they land).
class_name TestPlanGaps
extends GdUnitTestSuite

const P1 := Players.P1
const P2 := Players.P2

var _hud: Control
var _ball: Node
var _best_before = null


func before_test() -> void:
	_best_before = Save.get_value("best_height", null)
	Run.stop_run()


func after_test() -> void:
	if is_instance_valid(_hud):
		_hud.free()
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
