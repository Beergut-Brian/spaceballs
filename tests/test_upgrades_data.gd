## Content checks for data/upgrades/: every card follows GAME.md's kinds, tiers and power bands,
## has a 512 px icon and a visual (or the frog takeover), and only names sounds that exist.
extends GdUnitTestSuite

const DIR := "res://data/upgrades/"
const BANDS := {"normal": [1.6, 1.9], "strong": [2.3, 2.8], "joke": [1.0, 1.3], "curse": [0.1, 0.3]}
const NAMED := ["big_boot", "spring_shoes", "rocket_boots", "super_strength", "running_start",
	"lucky_sock", "trampoline_tee", "helium_ball", "coachs_whistle", "giant_foot", "cannon_leg",
	"jetpack", "pogo_legs", "tornado_spin", "dad_strength", "moon_gravity", "slingshot_buddy",
	"tiny_hat", "extra_shoes", "confetti_kick", "balloon_animal_ball", "mustache", "honk_horn_shoes",
	"opera_kick", "kiss_the_frog", "banana_peel", "sneeze", "shoelaces_tied", "too_much_lunch", "butterfly"]


func _all() -> Array[UpgradeData]:
	var out: Array[UpgradeData] = []
	for f in ResourceLoader.list_directory(DIR):
		if f.ends_with(".tres"):
			out.append(load(DIR + f) as UpgradeData)
	return out


func test_forty_plus_upgrades_cover_every_kind_and_tier() -> void:
	var ups := _all()
	assert_int(ups.size()).is_greater_equal(40)
	for kind in BANDS:
		for tier in [1, 2, 3]:
			if kind == "curse" and tier == 3:
				continue
			assert_bool(ups.any(func(u): return u.kind == kind and u.tier == tier)) \
				.override_failure_message("no %s card in tier %d" % [kind, tier]).is_true()


func test_every_game_md_example_exists() -> void:
	var ids := _all().map(func(u): return String(u.id))
	for id in NAMED:
		assert_bool(ids.has(id)).override_failure_message("missing " + id).is_true()


func test_fields_follow_the_spec() -> void:
	for u in _all():
		var label := String(u.id)
		assert_bool(BANDS.has(u.kind)).override_failure_message(label + " kind").is_true()
		assert_float(u.power_mult).override_failure_message(label + " power_mult out of band") \
			.is_between(BANDS[u.kind][0], BANDS[u.kind][1])
		assert_int(u.tier).is_between(1, 3)
		assert_str(u.name).is_not_empty()
		assert_str(u.description).is_not_empty()
		assert_object(u.icon).override_failure_message(label + " icon").is_not_null()
		assert_int(u.icon.get_width()).is_equal(512)
		assert_bool(u.visual != null or u.scene_override != null) \
			.override_failure_message(label + " has no visual").is_true()
		if u.kick_sfx != &"":
			# Same lookup as Audio._resolve: the cue itself or its numbered variants.
			var base := "res://assets/audio/sfx/%s" % u.kick_sfx
			assert_bool(FileAccess.file_exists(base + ".ogg") or FileAccess.file_exists(base + "_1.ogg")) \
				.override_failure_message(label + " kick_sfx would be silent").is_true()


func test_visuals_name_an_attach_point() -> void:
	for u in _all():
		if u.visual == null or Kicker.gear_for(u) != null:
			continue   # worn gear goes on through the equipment slots (tests/test_gear.gd)
		var node := u.visual.instantiate()
		assert_bool(node.has_meta(&"attach_point")) \
			.override_failure_message(String(u.id) + " visual has no attach_point").is_true()
		node.free()
