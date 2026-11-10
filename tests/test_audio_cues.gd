## Every cue the game can ask for resolves to a loadable stream, and every sfx file is used.
## (Replaces the old fixed list in test_smoke.gd: this one reads the code and the data.)
class_name TestAudioCues
extends GdUnitTestSuite

const CODE_DIRS := ["res://scenes", "res://scripts"]
## Files made for upgrade kick_sfx lines the Upgrades lane has not written yet (see CUES.md).
const PENDING_DATA := ["honk", "opera"]


func test_every_cue_resolves_to_a_stream() -> void:
	var cues := _all_cues()
	assert_int(cues.size()).is_greater(25)
	for cue in cues:
		var stream := _load_cue(cue)
		assert_object(stream).override_failure_message("no loadable file for cue '%s'" % cue) \
				.is_not_null()


func test_every_sfx_file_is_used() -> void:
	var cues := _all_cues()
	for c in PENDING_DATA:
		cues[c] = true
	var re := RegEx.create_from_string("^(.+)_\\d+$")
	for f in DirAccess.get_files_at(Audio.SFX_DIR):
		if not f.ends_with(".ogg"):
			continue
		var stem := f.get_basename()
		var m := re.search(stem)
		var used := cues.has(stem) or (m != null and cues.has(m.get_string(1)))
		assert_bool(used).override_failure_message("sfx/%s is never played" % f).is_true()


func test_layered_music_is_silent_without_files() -> void:
	Audio.music("no_such_track")
	Audio.music_level(2)
	assert_bool(Audio._music.playing).is_false()


func _load_cue(cue: String) -> AudioStream:
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
