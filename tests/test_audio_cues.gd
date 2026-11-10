## Every cue the game can ask for resolves to a loadable stream, and every sfx file is used.
## (Replaces the old fixed list in test_smoke.gd: this one reads the code and the data.)
class_name TestAudioCues
extends GdUnitTestSuite

const CODE_DIRS := ["res://scenes", "res://scripts"]
const CUES_DOC := "res://assets/audio/CUES.md"
## Files made ahead of the code that will play them (see CUES.md): an upgrade kick_sfx the
## Upgrades lane has not written yet, and gags the Gameplay lane asked for.
const PENDING_DATA := ["opera", "frog_bloop", "crowd_aww", "orbit_chime", "crowd_wild", "trip",
		"waddle", "butterfly"]


func test_every_cue_resolves_to_a_stream() -> void:
	var cues := _all_cues()
	assert_int(cues.size()).is_greater(25)
	for cue in cues:
		var stream := _load_cue(cue)
		assert_object(stream).override_failure_message("no loadable file for cue '%s'" % cue) \
				.is_not_null()


## Every cue in the CUES.md table has a file, so the doc never promises a sound that is missing.
func test_every_documented_cue_resolves() -> void:
	var cues := _doc_cues()
	assert_int(cues.size()).is_greater(40)
	for cue in cues:
		assert_object(_load_cue(cue)).override_failure_message(
				"CUES.md lists '%s' but sfx/ has no file for it" % cue).is_not_null()


## upgrade_piece.gd only plays gag_cue when sfx/<cue>.ogg itself exists (no _N variants), and
## falls back silently otherwise, so check that exact file.
func test_every_piece_gag_cue_has_a_single_file() -> void:
	var gags := _piece_gag_cues()
	assert_int(gags.size()).is_greater(0)
	for cue in gags:
		assert_bool(ResourceLoader.exists(Audio.SFX_DIR + cue + ".ogg")) \
				.override_failure_message("piece gag_cue '%s' needs sfx/%s.ogg" % [cue, cue]).is_true()


func test_every_sfx_file_is_used() -> void:
	var cues := _all_cues()
	for c in PENDING_DATA:
		cues[c] = true
	cues.merge(_piece_gag_cues())
	for id in Kicker.GEAR_CUES:   # worn gear's kick sounds (kicker.gd)
		cues[Kicker.GEAR_CUES[id][0]] = true
	for id in Roster.roster():   # a character's own wind-up voice (Kicker.voice_cue)
		cues["windup_" + id] = true
	var re := RegEx.create_from_string("^(.+)_\\d+$")
	for f in DirAccess.get_files_at(Audio.SFX_DIR):
		if not f.ends_with(".ogg"):
			continue
		var stem := f.get_basename()
		var m := re.search(stem)
		var used := cues.has(stem) or (m != null and cues.has(m.get_string(1)))
		assert_bool(used).override_failure_message("sfx/%s is never played" % f).is_true()


func test_layered_music_is_silent_without_files() -> void:
	Audio._music.stop()   # an earlier suite's field music may still be playing
	Audio._track = ""
	Audio.music("no_such_track")
	Audio.music_level(2)
	assert_bool(Audio._music.playing).is_false()


func _load_cue(cue: String) -> AudioStream:
	if Audio.ALIASES.has(cue) and not Audio._has_file(cue):
		cue = Audio.ALIASES[cue][0]
	var path := Audio.SFX_DIR + cue + ".ogg"
	if not ResourceLoader.exists(path):
		path = Audio.SFX_DIR + cue + "_1.ogg"
	if not ResourceLoader.exists(path):
		return null
	return load(path) as AudioStream


## Literal cue names in Audio.play(...) calls, plus the ones picked from constants and data.
func _all_cues() -> Dictionary:
	var cues := {}
	var call := RegEx.create_from_string("Audio\\.play\\((.*)\\)")
	var lit := RegEx.create_from_string("\"([a-z0-9_]+)\"")
	for path in _gd_files():
		for line in FileAccess.get_file_as_string(path).split("\n"):
			var m := call.search(line)
			if m:
				for l in lit.search_all(m.get_string(1)):
					if not l.get_string(1).ends_with("_"):   # "gag_" + id: added below
						cues[l.get_string(1)] = true
	for c in (load("res://scenes/main.gd") as GDScript).get_script_constant_map()["KICK_CUES"]:
		cues[String(c)] = true
	for id in (load("res://scenes/ball.gd") as GDScript).get_script_constant_map()["TIER_GAGS"]:
		cues["gag_" + String(id)] = true
	var tier_set: TierSet = Run.tiers if Run.tiers else load("res://data/tiers.tres")
	for t in tier_set.tiers:
		cues[String(t.tier_up_cue)] = true
	for f in DirAccess.get_files_at("res://data/upgrades"):
		var u := load("res://data/upgrades/" + f.trim_suffix(".remap")) as UpgradeData
		if u and u.kick_sfx != &"":
			cues[String(u.kick_sfx)] = true
	var sky := load("res://data/sky.tres") as SkySet   # sky objects' cues (scenes/sky/, Sky lane)
	for t in sky.tiers:
		for e in t.entries:
			var o := e.scene.instantiate()
			for key in [&"cue", &"near_cue"]:
				if o.get(key) != &"":
					cues[String(o.get(key))] = true
			o.free()
	return cues


## First-column names of the cue table in CUES.md.
func _doc_cues() -> Dictionary:
	var cues := {}
	var row := RegEx.create_from_string("^\\| ([a-z0-9_]+) \\|")
	for line in FileAccess.get_file_as_string(CUES_DOC).split("\n"):
		var m := row.search(line)
		if m:
			cues[m.get_string(1)] = true
	return cues


## gag_cue values set on the upgrade piece scenes.
func _piece_gag_cues() -> Dictionary:
	var cues := {}
	var re := RegEx.create_from_string("gag_cue = &\"([a-z0-9_]+)\"")
	for f in DirAccess.get_files_at("res://scenes/upgrades"):
		if f.ends_with(".tscn"):
			for m in re.search_all(FileAccess.get_file_as_string("res://scenes/upgrades/" + f)):
				cues[m.get_string(1)] = true
	return cues


func _gd_files(dir := "") -> PackedStringArray:
	var out := PackedStringArray()
	for d in (CODE_DIRS if dir == "" else [dir]):
		for f in DirAccess.get_files_at(d):
			if f.ends_with(".gd"):
				out.append(d + "/" + f)
		for sub in DirAccess.get_directories_at(d):
			out.append_array(_gd_files(d + "/" + sub))
	return out
