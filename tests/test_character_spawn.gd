## Spaceballs plays whoever you picked (Roster, docs/roster.md): the field kickers spawn as the
## Roster pick, gear goes onto (and moves with) the picked body, the frog keeps only that character's
## own costume, names come from the pick, voices fall back to the generic cue, and the test-only
## stand-in (tests/fixtures/standin/, a generic seed-9 Jarling) never ships.
extends GdUnitTestSuite

const P1 := Players.P1
const P2 := Players.P2
const KICKER := preload("res://scenes/players/jarling_kicker.tscn")
const STANDIN := "res://tests/fixtures/roster_standin.json"
const STANDIN_GLB := "res://tests/fixtures/standin/standin.glb"
const FILE := "user://test_spawn_players.json"
const DIR := "res://data/upgrades/"

var _main: Node
var _real := {}


func before() -> void:
	SettingsSandbox.enter("user://test_settings_spawn.json")
	_real = { "picks": Roster.picks_path, "data": Roster.data_path }
	Roster.picks_path = FILE


func after() -> void:
	DirAccess.remove_absolute(FILE)
	Roster.picks_path = _real.picks
	Roster.data_path = _real.data
	Roster.args_override = PackedStringArray()
	Roster.reload()
	SettingsSandbox.leave()
	await Audio.stop_all()


func before_test() -> void:
	if FileAccess.file_exists(FILE):
		DirAccess.remove_absolute(FILE)
	Players.reset()
	Game.demo = false
	Run.demo = false
	Game.round_index = 0
	Game._set_state(Game.State.LOBBY)
	get_tree().paused = false
	UiStyle.use_skin(load("res://data/menu_skin.tres"))   # Spaceballs' skin (a suite may leave a blank one)


func after_test() -> void:
	if is_instance_valid(_main):
		_main.free()
	UiStyle.use_skin(load("res://data/menu_skin.tres"))
	Players.reset()
	Game._set_state(Game.State.LOBBY)
	get_tree().paused = false
	var w := get_tree().root.get_node_or_null("ShowtimeWipe")
	if w:
		w.free()


## The stand-in roster, with these launch args (like the launcher's --p1-char= / --p2-char=).
func _roster(args: Array) -> void:
	Roster.data_path = STANDIN
	Roster.args_override = PackedStringArray(["--test-spawn"] + args)
	Roster.reload()


func _boot() -> Node:
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	return _main


func _model(k: Node) -> Node:
	return k.get_node("Body/Jarling/Model")


func _card(id: String) -> UpgradeData:
	return load(DIR + id + ".tres") as UpgradeData


func _kicker(id: String, player := P1) -> Kicker:
	var k: Kicker = KICKER.instantiate()
	k.player = player
	k.character_id = id
	add_child(auto_free(k))
	k.equipment.pop_in = false
	return k


func test_field_kickers_spawn_as_the_pick() -> void:
	_roster(["--p1-char=standin"])
	var main := _boot()
	var k1: Kicker = main.kickers[P1]
	var k2: Kicker = main.kickers[P2]
	assert_str(k1.character_id).is_equal("standin")
	assert_str(_model(k1).scene_file_path).is_equal(STANDIN_GLB)
	assert_str(k2.character_id).is_equal("chuck")
	assert_str(_model(k2).scene_file_path).is_equal("res://assets/characters/chuck/chuck.glb")
	# The slot keeps the player colour, whoever stands in it.
	assert_bool((k1.accent.material_override as StandardMaterial3D).albedo_color.is_equal_approx(Players.COLOR[P1])).is_true()
	assert_str(k1.character_name()).is_equal("Stand-in")


func test_defaults_are_jeff_and_chuck() -> void:
	Roster.data_path = "res://data/roster.json"
	Roster.args_override = PackedStringArray(["--test-spawn"])
	Roster.reload()
	var main := _boot()
	assert_str(main.kickers[P1].character_id).is_equal("jeff")
	assert_str(main.kickers[P2].character_id).is_equal("chuck")
	assert_str(_model(main.kickers[P1]).scene_file_path).is_equal("res://assets/characters/jeff/jeff.glb")


func test_swapped_chuck_p1_jeff_p2() -> void:
	_roster(["--p1-char=chuck", "--p2-char=jeff"])
	var main := _boot()
	var k1: Kicker = main.kickers[P1]
	var k2: Kicker = main.kickers[P2]
	assert_str(k1.character_id).is_equal("chuck")
	assert_str(k2.character_id).is_equal("jeff")
	assert_bool((k1.accent.material_override as StandardMaterial3D).albedo_color.is_equal_approx(Players.COLOR[P1])).is_true()
	assert_bool((k2.accent.material_override as StandardMaterial3D).albedo_color.is_equal_approx(Players.COLOR[P2])).is_true()
	# The hat that pops is Chuck's, on whichever side he plays.
	assert_object(k1.get_node("Body/Jarling")._hat).is_not_null()
	assert_object(k2.get_node("Body/Jarling")._hat).is_null()
	assert_str(UiStyle.skin().player_name(P1)).is_equal("CHUCK")
	assert_str(UiStyle.skin().player_name(P2)).is_equal("JEFF")


func test_round_card_names_the_picked_character() -> void:
	_roster(["--p1-char=standin"])
	var main := _boot()
	var lobby: Control = main.get_node("UI/Lobby")
	await await_idle_frame()
	Players.join_virtual(P1)
	Players.join_virtual(P2)
	lobby.press_a(P1)
	lobby.press_a(P2)
	lobby.count_step(lobby.COUNT_STEP * lobby.COUNT_DOTS + 0.01)
	assert_str(lobby.round_card_subtitle).is_equal("STAND-IN KICKS FIRST")
	assert_bool(lobby.round_card_color.is_equal_approx(Players.COLOR[P1])).is_true()


func test_lobby_pick_changes_the_field_kicker_and_podium() -> void:
	_roster([])
	var main := _boot()
	await await_idle_frame()
	var lobby: Control = main.get_node("UI/Lobby")
	Players.join_virtual(P1)
	lobby.press_b(P1)
	assert_bool(lobby.choose(P1, 1)).is_true()   # jeff -> (chuck is P2's) -> standin
	assert_str(Roster.pick(P1)).is_equal("standin")
	assert_str(main.kickers[P1].character_id).is_equal("standin")
	assert_str(_model(main.kickers[P1]).scene_file_path).is_equal(STANDIN_GLB)
	await await_millis(200)   # the podium swaps at the bottom of its squash (70 ms)
	var podium: Node = lobby.get_node("Spots/P1/Character").character
	assert_str(podium.id).is_equal("standin")
	assert_str(podium.get_node("Jarling/Model").scene_file_path).is_equal(STANDIN_GLB)


func test_gear_equips_on_the_picked_body() -> void:
	_roster([])
	var k := _kicker("standin")
	for s in JarlingEquipment.SLOTS:
		var m := k.equipment.slot_node(s)
		assert_str(String(m.name)).is_equal("slot_%s" % s)
		assert_bool(_model(k).is_ancestor_of(m)).override_failure_message("slot_%s not on the stand-in" % s).is_true()
	k.add_upgrade_visual(_card("rocket_boots"))
	k.add_upgrade_visual(_card("super_cape"))
	k.add_upgrade_visual(_card("super_cape"))
	assert_bool(k.equipment.has_item(&"rocket_boots")).is_true()
	assert_bool(_model(k).is_ancestor_of(k.worn_piece("feet"))).is_true()
	# Swapping character keeps the outfit (and its level) and puts it on the new body.
	assert_bool(k.set_character("jeff")).is_true()
	assert_str(_model(k).scene_file_path).is_equal("res://assets/characters/jeff/jeff.glb")
	assert_bool(k.equipment.has_item(&"rocket_boots")).is_true()
	assert_int(k.equipment.level(&"back")).is_equal(2)
	assert_bool(_model(k).is_ancestor_of(k.worn_piece("feet"))).is_true()
	assert_bool(_model(k).is_ancestor_of(k.worn_piece("back"))).is_true()
	assert_int(k.get_node("Body/Jarling").get_child_count()).is_equal(1)   # one model, not two


func test_kick_and_cheer_on_the_stand_in() -> void:
	_roster([])
	var k := _kicker("standin")
	var anim := _model(k).find_child("AnimationPlayer", true, false) as AnimationPlayer
	for a in ["idle", "run", "kick", "cheer"]:
		assert_bool(anim.has_animation(a)).override_failure_message("no %s animation" % a).is_true()
	k.begin_approach(k.global_position + Vector3(0, 0, -3))
	assert_str(anim.current_animation).is_equal("run")
	k.start_windup()
	assert_str(anim.current_animation).is_equal("kick")
	k.dance(true)   # the end-card cheer
	await await_idle_frame()
	assert_int(k.state).is_equal(Kicker.State.CHEER)
	assert_str(anim.current_animation).is_equal("cheer")


func test_space_helmet_survives_a_swap() -> void:
	_roster([])
	var k := _kicker("jeff")
	await await_idle_frame()   # the helmet mounts on the head bone deferred
	assert_bool(k.set_character("standin")).is_true()
	await await_idle_frame()
	assert_bool(is_instance_valid(k.helmet)).is_true()
	assert_bool(_model(k).is_ancestor_of(k.helmet)).is_true()
	k.set_space_suit(true)
	assert_bool(k.helmet.visible).is_true()


func test_frog_wears_only_its_own_characters_costume() -> void:
	_roster([])
	for c in [["jeff", true, false], ["chuck", false, true], ["standin", false, false]]:
		var k := _kicker(c[0], P1 if c[0] != "chuck" else P2)
		k.set_frog(true)
		await await_idle_frame()
		var f: Node = k.frog_slot.get_child(0)
		assert_bool(f.get_node("JeffHood").visible).override_failure_message(c[0] + " hood").is_equal(c[1])
		assert_bool(f.get_node("ChuckHat").visible).override_failure_message(c[0] + " hat").is_equal(c[2])
		k.set_frog(false)
		assert_bool(k.body.visible).is_true()


func test_voices_fall_back_never_borrow() -> void:
	assert_str(Kicker.voice_cue("windup", "jeff")).is_equal("windup_jeff")
	assert_str(Kicker.voice_cue("windup", "chuck")).is_equal("windup_chuck")
	assert_str(Kicker.voice_cue("windup", "standin")).is_equal("windup")
	assert_str(Kicker.voice_cue("windup", "")).is_equal("windup")
	assert_bool(ResourceLoader.exists(Kicker.SFX_DIR + "windup_1.ogg")).is_true()   # the fallback is real


func test_the_stand_in_never_ships() -> void:
	var cfg := ConfigFile.new()
	assert_int(cfg.load("res://export_presets.cfg")).is_equal(OK)
	var n := 0
	for sec in cfg.get_sections():
		if sec.ends_with(".options") or not cfg.has_section_key(sec, "exclude_filter"):
			continue
		n += 1
		var ex := str(cfg.get_value(sec, "exclude_filter")).split(",")
		assert_bool(ex.has("tests/*")).override_failure_message(sec + " ships tests/").is_true()
		var inc := str(cfg.get_value(sec, "include_filter"))
		assert_str(inc).not_contains("tests")
	assert_int(n).is_greater(0)
	# Nothing the game ships points at the fixture.
	var roster := FileAccess.get_file_as_string("res://data/roster.json")
	assert_str(roster).not_contains("tests/")
	assert_str(roster).not_contains("standin")
	for p in ["res://scenes/main.tscn", "res://data/menu_skin.tres", "res://scenes/players/jarling_kicker.tscn"]:
		assert_str(FileAccess.get_file_as_string(p)).not_contains("tests/")


func test_a_long_name_fits_the_plate() -> void:
	const Spot := preload("res://scenes/ui/lobby_spot.gd")
	_roster(["--p1-char=standin"])
	var main := _boot()
	await await_idle_frame()
	var spot: Control = main.get_node("UI/Lobby/Spots/P1")
	var avail: float = spot.size.x - 70.0 + 10.0 - (10.0 + 112.0 + 24.0 + 40.0) - 64.0   # plate end - name_x - arrow
	assert_int(Spot.fit_size("JEFF", avail, 62)).is_equal(62)
	var s := Spot.fit_size("STAND-IN", avail, 62)
	assert_int(s).is_less(62)
	assert_float(UiStyle.show_font(800).get_string_size("STAND-IN", HORIZONTAL_ALIGNMENT_LEFT, -1, s).x).is_less_equal(avail)
