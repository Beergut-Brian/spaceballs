## The busy sky (Sky lane, playtest 2026-11-09 #2): every tier has 3 to 6 objects, every object
## has a sound, a typical flight bumps into 1 to 3 of them (more on big kicks), a bump never moves
## the outcome (docs/contracts.md, the balance rule), and every object is freed again.
class_name TestSky
extends GdUnitTestSuite

const BALL := preload("res://scenes/ball.tscn")
const TIER_IDS := [&"backyard", &"rooftops", &"treetops", &"kites", &"clouds", &"thin_air", &"edge", &"space"]

var _sky: SkySet
var _nodes: Array[Node] = []
var _save_was := true
var _ticks_was := 60
var _steps_was := 8


## Every flight here is staged, not inherited: suites run in a different order on CI, and a suite
## that plays a real round (test_main_flow) can leave a curse on P1. A dribble curse makes the ball
## dribble for a second instead of climbing, so nothing flew and nothing was hit.
func before_test() -> void:
	_sky = load(SkyField.SKY_PATH)
	_save_was = Run.save_enabled
	Run.save_enabled = false
	Run._clear()   # no curse, upgrade, space or best height left from another suite
	Engine.time_scale = 1.0
	# A fixed physics step: 60 ticks a second, at most 8 a frame (the project's values, pinned).
	_ticks_was = Engine.physics_ticks_per_second
	_steps_was = Engine.max_physics_steps_per_frame
	Engine.physics_ticks_per_second = 60
	Engine.max_physics_steps_per_frame = 8
	seed(20261109)   # the ball's launch spin and the bump pushes use the global RNG


func after_test() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()
	Engine.time_scale = 1.0
	Engine.physics_ticks_per_second = _ticks_was
	Engine.max_physics_steps_per_frame = _steps_was
	Run.save_enabled = _save_was
	Run._clear()


func _cue_exists(cue: StringName) -> bool:
	var c := String(cue)
	if Audio.ALIASES.has(c) and not Audio._has_file(c):
		c = Audio.ALIASES[c][0]
	return ResourceLoader.exists(Audio.SFX_DIR + c + ".ogg") or ResourceLoader.exists(Audio.SFX_DIR + c + "_1.ogg")


func test_rising_matches_the_ball_flight_enum() -> void:
	var b := _ball()
	assert_array(SkyField.RISING).contains_exactly([b.Flight.PHYSICS, b.Flight.SCRIPTED])


func test_every_tier_has_three_to_six_objects() -> void:
	for id in TIER_IDS:
		var t := _sky.get_tier(id)
		assert_object(t).override_failure_message("no sky tier '%s'" % id).is_not_null()
		assert_int(t.count_min).is_greater_equal(3)
		assert_int(t.count_max).is_less_equal(6)
		assert_int(t.count_max).is_greater_equal(t.count_min)
		assert_bool(t.entries.any(func(e: SkyEntry) -> bool: return e.on_path)).is_true()


func test_every_sky_object_has_a_sound() -> void:
	var n := 0
	for t in _sky.tiers:
		for e in t.entries:
			var o := e.scene.instantiate() as SkyObject
			assert_object(o).override_failure_message("%s is not a SkyObject" % e.scene.resource_path).is_not_null()
			assert_bool(o.cue != &"" and _cue_exists(o.cue)) \
					.override_failure_message("%s: no sound for cue '%s'" % [e.scene.resource_path, o.cue]).is_true()
			if o.near_cue != &"":
				assert_bool(_cue_exists(o.near_cue)) \
						.override_failure_message("%s: no sound for near_cue '%s'" % [e.scene.resource_path, o.near_cue]).is_true()
			assert_object(o.get_node_or_null("Gag")).is_not_null()
			if o.reaction == SkyObject.Reaction.POP:
				assert_bool(o.get_node("Gag").get_children().any(func(c: Node) -> bool: return String(c.name).begins_with("Pop"))).is_true()
			if o.reaction == SkyObject.Reaction.SCATTER:
				assert_bool(o.get_node("Gag").get_children().any(func(c: Node) -> bool: return String(c.name).begins_with("Bird"))).is_true()
			o.free()
			n += 1
	assert_int(n).is_greater_equal(20)


func _field() -> SkyField:
	var f := SkyField.new()
	add_child(f)
	_nodes.append(f)
	return f


## The aim: 1 to 3 in the path on a typical (tiers 1 to 6) flight, more on big kicks, and 3 to 6
## objects in every tier the flight crosses.
func test_plans_aim_one_to_three_hits_and_more_on_big_kicks() -> void:
	var f := _field()
	for peak in [3.0, 9.0, 30.0, 200.0, 1200.0, 8000.0, 60000.0, 102000.0]:
		var top := f.tiers.tier_for(peak)
		for s in 30:
			var p := f.plan(peak, s * 7919 + int(peak))
			var hits := p.filter(func(i: Dictionary) -> bool: return i.on_path).size()
			assert_int(hits).override_failure_message("peak %s seed %d: %d in the path" % [peak, s, hits]) \
					.is_equal(SkyField.hits_for(top))
			if top <= 6:
				assert_int(hits).is_between(1, 3)
			else:
				assert_int(hits).is_greater(3)
			var per := {}
			for i in p:
				per[i.tier] = per.get(i.tier, 0) + 1
				assert_float(i.y).is_less_equal(TierSet.visual_y(peak) + 10.01)
				assert_float(float(i.scale)).is_greater(0.0)
				if i.on_path:
					assert_float(i.y).is_less(TierSet.visual_y(peak))
			for t in per:
				assert_int(per[t]).is_between(3, 6)


## The same seed gives the same sky; different kicks get a different one.
func test_plans_are_seeded() -> void:
	var f := _field()
	var a := f.plan(5000.0, 11)
	var b := f.plan(5000.0, 11)
	var c := f.plan(5000.0, 12)
	assert_int(a.size()).is_equal(b.size())
	for i in a.size():
		assert_float(a[i].y).is_equal(b[i].y)
	assert_bool(a.size() != c.size() or a.map(func(i: Dictionary) -> float: return i.y) != c.map(func(i: Dictionary) -> float: return i.y)).is_true()


func _ball() -> Node3D:
	var b := BALL.instantiate()
	add_child(b)
	_nodes.append(b)
	b.place_on_tee(Vector3(0, 0, 0))
	return b


## Flies `ball` to its peak; `each` runs every physics frame. Returns the flight's seconds.
## Fails unless the ball really climbed (a dribble curse skips the climb) and peaked in time, so
## a flight test can never pass on a flight that did not happen.
func _fly(ball: Node3D, peak: float, each: Callable) -> float:
	Engine.time_scale = 4.0
	var launched := [false]   # a dribble curse skips launched (and the sky with it)
	var on_launch := func(_p: float) -> void: launched[0] = true
	ball.launched.connect(on_launch)
	ball.launch(Run.BASE_POWER * 4.0, peak)
	ball.launched.disconnect(on_launch)
	var t := 0.0
	while ball.flight != ball.Flight.PEAK and t < 20.0:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		each.call()
	assert_bool(launched[0]).override_failure_message("the ball never climbed (curse %s)" % Run.curse_of(ball.player)).is_true()
	assert_int(ball.flight).override_failure_message("no peak in %.1f s" % t).is_equal(ball.Flight.PEAK)
	return t


## The balance rule: even bumped every frame, the ball peaks at exactly the planned height, its
## mesh never strays more than the bound, and the hit-stop adds at most SKY_MAX_HOLD.
func test_bumps_keep_the_height_within_the_bound() -> void:
	var peak := 5000.0
	var calm := _ball()
	var t_calm: float = await _fly(calm, peak, func() -> void: pass)
	assert_float(calm.height).is_equal_approx(peak, 0.001)
	var b := _ball()
	b.player = 1
	var worst := [0.0]
	var t_bumped: float = await _fly(b, peak, func() -> void:
		b.sky_react(Vector3(randf_range(-30, 30), randf_range(-30, 30), randf_range(-30, 30)), 0.2, 5.0)
		var vis := TierSet.visual_y(b.height)
		worst[0] = maxf(worst[0], b.sky_offset.length() / maxf(b.SKY_MIN_OFFSET, b.SKY_MAX_OFFSET * vis)))
	assert_float(b.height).is_equal_approx(peak, 0.001)
	assert_float(b.peak_height).is_equal(peak)
	assert_float(worst[0]).is_less_equal(1.001)
	assert_float(t_bumped - t_calm).is_less_equal(b.SKY_MAX_HOLD + 0.1)


## A real flight through the sky field: things get hit, the ball reacts, and every object is freed
## once the ball is back (and nothing is left over from the flight before).
func test_a_flight_hits_things_and_frees_them() -> void:
	var f := _field()
	f.rng.seed = 5
	var b := _ball()
	f.watch(b)
	var hit := {}   # every object hit during the flight, once (popped ones free themselves)
	var moved := [0.0]
	await _fly(b, 50000.0, func() -> void:
		moved[0] = maxf(moved[0], b.sky_offset.length())
		for o in f.get_children():
			if o is SkyObject and o.was_hit:
				hit[o.get_instance_id()] = true)
	# Path objects spawn on the ball's column and home onto it, so geometry, not luck, says every
	# one of them gets hit (4 on a 50 km kick, SkyField.hits_for).
	var path: int = (f._flights.get(b, {}).get("plan", []) as Array).filter(func(i: Dictionary) -> bool: return i.on_path).size()
	assert_int(path).is_greater_equal(2)
	assert_int(hit.size()).override_failure_message("%d of %d path objects hit on a 50 km kick" % [hit.size(), path]) \
			.is_greater_equal(path)
	assert_float(moved[0]).is_greater(0.05)
	assert_int(f.live_objects(b).size()).is_greater(0)
	# The next launch clears the old sky first; returned frees it all.
	b.place_on_tee(Vector3.ZERO)
	b.launch(Run.BASE_POWER, 3.0)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_int(f.get_children().filter(func(o: Node) -> bool: return o is SkyObject and o.position.y > 20.0).size()).is_equal(0)
	b.returned.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_int(f.get_children().filter(func(o: Node) -> bool: return o is SkyObject).size()).is_equal(0)
	assert_int(f.live_objects(b).size()).is_equal(0)


## Objects far below a climbing ball are culled during the flight, not kept to the end.
func test_objects_far_below_are_freed_in_flight() -> void:
	var f := _field()
	f.rng.seed = 9
	var b := _ball()
	f.watch(b)
	var low_left := [false]
	await _fly(b, 90000.0, func() -> void:
		for o in f.get_children():
			if o is SkyObject and not o.is_queued_for_deletion() and o.global_position.y < b.global_position.y - SkyField.CULL_BELOW - o.size * 2.0 - 12.0:   # 12: a frame or two of the ball's climb
				low_left[0] = true)
	assert_bool(low_left[0]).is_false()
	assert_int(f.get_children().filter(func(o: Node) -> bool: return o is SkyObject and o.position.y < 20.0).size()).is_equal(0)
