## Launch-ready lane (2026-11-10): the last polish rows (U-15 Hiccups reveal, V-24 P1 ring on the
## grass, C-13 round counter) and ship hygiene (no grey-box placeholder markers in shipped files,
## every asset credited).
class_name TestLaunchReady
extends GdUnitTestSuite

const JEFF := preload("res://scenes/players/jeff.tscn")


func before_test() -> void:
	PhysicsPin.enter(4.0)   # fixed 60 Hz step, seeded RNG, no curse left in Run by another suite
	Run._ensure_data()


func after_test() -> void:
	PhysicsPin.leave()
	await Audio.stop_all()


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
	root.add_child(show)
	return [k, show, cam]


## U-15: the Hiccups reveal reads at a glance: three hiccup bubbles out of his mouth, three big hops,
## and the demo ball knocked well back (it used to shuffle 0.9 m with two small hops).
func test_hiccup_reveal_blows_bubbles_hops_high_and_knocks_the_ball_back(timeout := 60000) -> void:
	var bits := _setup()
	var k: Kicker = bits[0]
	var show: CurseShow = bits[1]
	await get_tree().physics_frame
	var c := Run.upgrade_by_id(&"hiccups")
	assert_object(c).is_not_null()
	var seen := {bubbles = {}, top = 0.0, ball_start = null, ball_far = 0.0}
	var y0 := k.global_position.y
	var watch := func() -> void:
		var st := show.get_node_or_null("CurseReveal")
		if st == null:
			return
		for n in st.get_children():
			if n.name.begins_with("HicBubble"):
				seen.bubbles[n.get_instance_id()] = true
		var b := st.get_node_or_null("DemoBall") as Node3D
		if b:
			if seen.ball_start == null:
				seen.ball_start = b.global_position
			seen.ball_far = maxf(seen.ball_far, _flat(b.global_position - seen.ball_start).length())
		seen.top = maxf(seen.top, k.global_position.y - y0)
	get_tree().process_frame.connect(watch)
	await show.reveal(0, k, c, bits[2])
	get_tree().process_frame.disconnect(watch)
	assert_int(seen.bubbles.size()).is_equal(3)
	assert_float(seen.top).override_failure_message("hop %.2f m" % seen.top).is_greater(0.6)
	assert_float(seen.ball_far).override_failure_message("ball %.2f m" % seen.ball_far).is_greater(1.1)
	assert_bool(show.has_badge(0)).is_true()


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


## No shipped scene or script still carries a grey-box PLACEHOLDER marker (the content replaced it).
func test_no_grey_box_placeholder_markers_ship() -> void:
	var hits: Array[String] = []
	for dir in ["res://scenes", "res://scripts", "res://data"]:
		_scan(dir, hits)
	assert_array(hits).is_empty()


func _scan(dir: String, hits: Array[String]) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.get_extension() in ["gd", "tscn", "tres", "md"]:
			var path := dir.path_join(f)
			if FileAccess.get_file_as_string(path).contains("PLACEHOLDER (systems grey-box)"):
				hits.append(path)
	for d in DirAccess.get_directories_at(dir):
		_scan(dir.path_join(d), hits)


## Every committed art/audio file outside the vendored characters has a line in assets/CREDITS.md.
func test_every_shipped_asset_has_a_credits_line() -> void:
	var credits := FileAccess.get_file_as_string("res://assets/CREDITS.md")
	var missing: Array[String] = []
	for dir in ["res://assets/audio", "res://assets/models", "res://assets/sprites", "res://assets/gear",
			"res://assets/landmarks", "res://assets/fonts", "res://store"]:
		_credit_scan(dir, credits, missing)
	assert_array(missing).is_empty()


func _credit_scan(dir: String, credits: String, missing: Array[String]) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	for f in DirAccess.get_files_at(dir):
		if f.get_extension() not in ["ogg", "wav", "png", "glb", "ttf", "otf", "mp4", "ogv"]:
			continue
		var rel := dir.path_join(f).trim_prefix("res://assets/").trim_prefix("res://")
		if not (credits.contains(rel) or credits.contains(f) or _glob_credited(dir, f, credits)):
			missing.append(rel)
	for d in DirAccess.get_directories_at(dir):
		_credit_scan(dir.path_join(d), credits, missing)


## Rows like `gear/*.glb` or `voice/*.ogg` credit a whole folder.
static func _glob_credited(dir: String, f: String, credits: String) -> bool:
	var rel_dir := dir.trim_prefix("res://assets/").trim_prefix("res://")
	return credits.contains(rel_dir + "/*." + f.get_extension()) or credits.contains(rel_dir + "/*_")


## V-24: the player-colour ring at his feet glows a little and sits on a white band, so P1's green
## reads on the green grass; the colour ring stays on top.
func test_feet_ring_glows_on_a_white_band() -> void:
	for p in 2:
		var k: Kicker = auto_free(preload("res://scenes/players/jarling_kicker.tscn").instantiate())
		k.player = p
		add_child(k)
		var mat := k.accent.material_override as StandardMaterial3D
		assert_bool(mat.emission_enabled).is_true()
		assert_that(mat.albedo_color).is_equal(Players.COLOR[p])
		var o := k.accent.get_node_or_null("Outline") as MeshInstance3D
		assert_object(o).is_not_null()
		assert_that((o.material_override as StandardMaterial3D).albedo_color.v).is_greater(0.95)
		var ring := k.accent.mesh as TorusMesh
		var band := o.mesh as TorusMesh
		assert_float(band.outer_radius).is_greater(ring.outer_radius)
		assert_float(band.inner_radius).is_less(ring.inner_radius)
		# the band's top stays below the colour ring's top
		var band_top := o.position.y + (band.outer_radius - band.inner_radius) * 0.5 * o.scale.y
		assert_float(band_top).is_less((ring.outer_radius - ring.inner_radius) * 0.5)


## C-13: the round counter is big ink-outlined balls (44 px), this round's ball golden.
func test_round_counter_balls_are_big_and_this_round_is_gold() -> void:
	var hud: Node = auto_free(load("res://scenes/ui/hud.tscn").instantiate())
	add_child(hud)
	var keep := Run.round_index
	Run.round_index = 4
	hud._refresh_rounds()
	await get_tree().process_frame
	var balls: Array = hud.rounds.get_children().filter(func(c: Node) -> bool: return not c.is_queued_for_deletion())
	Run.round_index = keep
	assert_int(balls.size()).is_equal(4)
	await get_tree().process_frame
	for b: Control in balls:
		assert_float(b.size.x).override_failure_message("ball %s" % b.size).is_equal_approx(b.size.y, 0.5)
		assert_float(b.custom_minimum_size.x).is_greater_equal(44.0)
		var sb := b.get_theme_stylebox("panel") as StyleBoxFlat
		assert_int(sb.border_width_left).is_greater_equal(4)
		assert_float(sb.border_color.v).is_less(0.3)   # dark ink rim, not white on white sky
	var last := (balls[3] as Control).get_theme_stylebox("panel") as StyleBoxFlat
	var first := (balls[0] as Control).get_theme_stylebox("panel") as StyleBoxFlat
	assert_bool(last.bg_color.is_equal_approx(first.bg_color)).is_false()


## A-06: a voiced character reacts to his own kick ("cheer" on a great one, "oops" on a cursed one)
## and the other player's character cheers him; Jeff and Chuck (no voice yet, D37) stay quiet.
func test_voiced_characters_bark_at_kicks_jeff_and_chuck_stay_quiet(timeout := 60000) -> void:
	SettingsSandbox.enter("user://test_launch_ready.json")
	Players.reset()
	Run.stop_run()
	Run.save_enabled = false
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	var said: Array = []
	var hear := func(slot: int, _id: String, path: String) -> void: said.append([slot, path.get_file()])
	Roster.said.connect(hear)
	# Jeff (P1 default) has no voice: nothing said, the crowd stands in.
	Roster.set_pick(Players.P1, "jeff")
	assert_bool(main.bark(Players.P1, "cheer")).is_false()
	var voiced := ""
	for id in Roster.roster():
		if "cheer" in Roster.info(id).barks and "oops" in Roster.info(id).barks and id != Roster.pick(Players.P2):
			voiced = id
			break
	assert_str(voiced).is_not_empty()
	Roster.set_pick(Players.P1, voiced)
	main._kick_barks(Players.P1, Players.P2, CrowdReactions.Level.GREAT, false)
	main._kick_barks(Players.P1, Players.P2, CrowdReactions.Level.CLAP, false)   # a small kick: quiet
	main._kick_barks(Players.P1, Players.P2, CrowdReactions.Level.NONE, true)
	Roster.said.disconnect(hear)
	assert_array(said).is_equal([[Players.P1, "cheer.ogg"], [Players.P1, "oops.ogg"]])
	main.free()
	Roster.set_pick(Players.P1, "jeff")
	SettingsSandbox.leave()
	Run.save_enabled = true
