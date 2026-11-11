## Playtest 2026-11-10 #3: The Hill's Dragon glides through the Clouds tier on a tuned chance per
## run. The ball can bonk her (happy sleepy roll, cloud puff, rumble-purr, a cosmetic bounce). She
## never holds up a run and is never playable.
class_name TestDragonCameo
extends GdUnitTestSuite

const BALL := preload("res://scenes/ball.tscn")


func after_test() -> void:
	Engine.time_scale = 1.0
	await Audio.stop_all()


func test_her_odds_live_in_data_and_make_her_a_treat() -> void:
	var d := load("res://data/dragon_cameo.tres") as CameoData
	assert_object(d).is_not_null()
	assert_float(d.chance_per_run).is_between(0.2, 0.5)
	assert_str(String(d.tier_id)).is_equal("clouds")
	var tiers: TierSet = load(Run.TIERS_PATH)
	assert_str(String(tiers.tiers[4].id)).is_equal("clouds")   # tier 5
	var cameo := DragonCameo.new()
	add_child(cameo)
	auto_free(cameo)
	cameo.rng.seed = 42
	var yes := 0
	for i in 4000:
		cameo.roll()
		yes += 1 if cameo.active else 0
	assert_float(yes / 4000.0).is_between(d.chance_per_run - 0.03, d.chance_per_run + 0.03)


func test_she_is_vendored_from_the_library_with_credits_and_her_rig() -> void:
	assert_bool(ResourceLoader.exists("res://assets/landmarks/dragon/dragon.glb")).is_true()
	var credits := FileAccess.get_file_as_string("res://assets/CREDITS.md")
	for f in ["assets/landmarks/dragon/dragon.glb", "assets/landmarks/dragon/bible.md",
			"`look.md`", "`UPSTREAM_CREDITS.md`", "assets/audio/sfx/dragon_purr.ogg"]:
		assert_bool(credits.contains(f)).override_failure_message("no credits row for " + f).is_true()
	var d := SkyDragon.make()
	auto_free(d)
	assert_object(d.anim).is_not_null()
	for a in [&"flap", &"cheer", &"sleep", &"wave"]:
		assert_bool(d.anim.has_animation(a)).override_failure_message(String(a)).is_true()


func test_never_playable() -> void:
	var roster := FileAccess.get_file_as_string("res://data/roster.json")
	assert_bool(roster.contains("\"dragon\"")).is_false()
	assert_bool(Roster.roster().has("dragon")).is_false()


## A Clouds kick on a dragon run: she joins the flight, glides, the bonk makes her roll and purr and
## bounces the ball up (cosmetic), and she goes when the ball comes home.
func test_bonk_roll_purr_and_she_never_blocks(timeout := 60000) -> void:
	var root := Node3D.new()
	add_child(root)
	auto_free(root)
	var field := SkyField.new()
	root.add_child(field)
	var ball: Node3D = BALL.instantiate()
	root.add_child(ball)
	ball.global_position = Vector3(0, 0.35, 0)
	field.watch(ball)
	var cameo := DragonCameo.new()
	root.add_child(cameo)
	await get_tree().process_frame
	cameo.active = true
	cameo.shown = 0
	cameo.watch(ball)
	var peak: float = field.tiers.tiers[5].threshold * 1.2   # into tier 6: through the Clouds
	ball.launched.emit(peak)
	await get_tree().process_frame
	await get_tree().process_frame
	var d := cameo.dragon
	assert_object(d).is_not_null()
	assert_bool(field.live_objects(ball).has(d)).is_true()
	assert_int(cameo.shown).is_equal(1)
	var b5 := field.band(5)
	assert_float(d.global_position.y - ball.global_position.y).is_between(b5.x - 1.0, b5.y)
	assert_str(String(d.anim.current_animation)).is_equal("flap")
	# The bonk.
	var vel_before: Vector3 = ball.get(&"_sky_vel")
	d.hit(ball)
	assert_bool(d.was_hit).is_true()
	assert_float((ball.get(&"_sky_vel") as Vector3).y).is_greater(vel_before.y + 1.0)
	Engine.time_scale = 4.0
	await get_tree().create_timer(0.5).timeout
	assert_float(absf(d.gag.rotation.z)).is_greater(0.3)   # rolling over
	await get_tree().create_timer(2.5).timeout
	assert_str(String(d.anim.current_animation)).is_equal("sleep")
	# The ball comes home: she goes with the rest of the flight.
	ball.returned.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_bool(is_instance_valid(d)).is_false()
	# Only once a run.
	ball.launched.emit(peak)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_int(cameo.shown).is_equal(1)


func test_no_dragon_below_the_clouds_or_on_an_off_run() -> void:
	var root := Node3D.new()
	add_child(root)
	auto_free(root)
	var field := SkyField.new()
	root.add_child(field)
	var ball: Node3D = BALL.instantiate()
	root.add_child(ball)
	field.watch(ball)
	var cameo := DragonCameo.new()
	root.add_child(cameo)
	await get_tree().process_frame
	cameo.watch(ball)
	cameo.active = true
	ball.launched.emit(field.tiers.tiers[3].threshold * 1.1)   # tier 4: rooftops-ish, no clouds
	await get_tree().process_frame
	await get_tree().process_frame
	assert_int(cameo.shown).is_equal(0)
	cameo.active = false
	ball.launched.emit(field.tiers.tiers[6].threshold)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_int(cameo.shown).is_equal(0)
