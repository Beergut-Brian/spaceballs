## Tests and scripted runs never read or write the real shared picks file
## (~/.local/share/openjar/players.json) or the real user://settings.json: Roster and Save point
## at RunSandbox paths from boot, and a suite that redirects them re-resolves the picks. A scripted
## chooser run once wrote the real file and test_lobby came up with P1 as somebody else.
class_name TestPicksIsolation
extends GdUnitTestSuite

const DIR := "user://test_picks_isolation"
## Stands in for a real picks file left on the build machine by a chooser run.
const REAL := DIR + "/real_players.json"
const OWN := DIR + "/own_players.json"
## A fixture roster (Jeff, Chuck, Pip), not the vendored one, so a roster sync can't move this.
const THREE := "res://tests/fixtures/roster_three.json"

var _saved := {}
var _real_mtime := 0


func before() -> void:
	_saved = { "picks": Roster.picks_path, "settings": Save.settings_path, "data": Roster.data_path }
	Roster.data_path = THREE
	Roster.reload()
	DirAccess.make_dir_recursive_absolute(DIR)
	# Only the file's time is looked at, never its contents: this run must not write it.
	if FileAccess.file_exists(Roster.shared_path()):
		_real_mtime = FileAccess.get_modified_time(Roster.shared_path())


func after() -> void:
	for f in [REAL, OWN]:
		DirAccess.remove_absolute(f)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR))
	Roster.picks_path = _saved.picks
	Roster.data_path = _saved.data
	Save.settings_path = _saved.settings
	Save.reload_settings()
	Roster.reload()


func _write(path: String, data: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "\t"))
	f.close()


func _not_a_default() -> String:
	for id in Roster.roster():
		if id != Roster.default_for(Roster.P1) and id != Roster.default_for(Roster.P2):
			return id
	return ""


func test_test_and_scripted_runs_are_sandboxed_from_boot() -> void:
	assert_bool(RunSandbox.active()).is_true()             # this gdUnit run
	assert_bool(RunSandbox.active(["res://addons/gdUnit4/bin/GdUnitCmdTool.gd"])).is_true()
	for flag in ["--demo", "--shots=1,3", "--shot-dir=x", "--ui=chooser", "--timescale=4",
			"--screenshot-after=2", "--log-phases", "--sandbox"]:
		assert_bool(RunSandbox.active(["--path", ".", flag])).override_failure_message(flag).is_true()
	# A real launch (the launcher's args) uses the real shared file.
	assert_bool(RunSandbox.active(["--path", ".", "--profile=p1", "--p1-char=chuck"])).is_false()
	assert_str(Roster.boot_picks_path(["--profile=p1"])).is_equal(Roster.shared_path())
	assert_str(Roster.boot_picks_path()).is_equal(RunSandbox.PICKS)
	assert_str(Roster.boot_picks_path()).is_not_equal(Roster.shared_path())
	assert_str(RunSandbox.SETTINGS).is_not_equal("user://settings.json")


func test_a_preexisting_real_picks_file_does_not_change_the_defaults() -> void:
	var other := _not_a_default()
	assert_str(other).is_not_empty()
	var real := { Save.profile: { "P1": other, "P2": Roster.default_for(Roster.P1) }, "kid2": { "P1": other } }
	_write(REAL, real)
	var before_text := FileAccess.get_file_as_string(REAL)
	# The build machine's state: the picks were resolved from the stale real file.
	Roster.picks_path = REAL
	Roster.reload()
	assert_str(Roster.pick(Roster.P1)).is_equal(other)
	# What test_lobby (and every suite that redirects) now does in before(): own file, re-resolve.
	Roster.picks_path = OWN
	DirAccess.remove_absolute(OWN)
	Roster.reload()
	assert_str(Roster.pick(Roster.P1)).is_equal("jeff")
	assert_str(Roster.pick(Roster.P2)).is_equal("chuck")
	# Booting the lobby and changing a pick writes only the suite's own file.
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	assert_str(Roster.pick(Roster.P1)).is_equal("jeff")
	assert_bool(Roster.set_pick(Roster.P1, other)).is_true()
	main.free()
	var w := get_tree().root.get_node_or_null("ShowtimeWipe")
	if w:
		w.free()
	assert_str(FileAccess.get_file_as_string(REAL)).is_equal(before_text)
	assert_bool(FileAccess.file_exists(OWN)).is_true()
	# And the sandbox path a fresh boot uses never was the real one.
	assert_str(Roster.boot_picks_path()).is_not_equal(Roster.shared_path())


func test_the_real_shared_file_is_not_written_by_this_run() -> void:
	if not FileAccess.file_exists(Roster.shared_path()):
		assert_bool(FileAccess.file_exists(Roster.shared_path())).is_false()
		return
	assert_int(FileAccess.get_modified_time(Roster.shared_path())).is_equal(_real_mtime)
