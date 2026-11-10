## Suites that boot main.tscn keep their settings out of the real user://settings.json: the
## Showtime settings panel saves solo whenever it changes, and a saved solo readies both players
## in the next suite's lobby (and on the next real boot). The chooser writes the picks file shared
## with the launcher at once, so the picks are sandboxed too (never the real OS data dir file).
class_name SettingsSandbox
extends RefCounted

static var _real := ""
static var _real_picks := ""


static func enter(path := "user://test_settings_suite.json") -> void:
	if _real == "":
		_real = Save.settings_path
	Save.settings_path = path
	Save.wipe_settings()
	if _real_picks == "":
		_real_picks = Roster.picks_path
	Roster.picks_path = path.get_basename() + "_picks.json"
	DirAccess.remove_absolute(Roster.picks_path)
	Roster.reload()


static func leave() -> void:
	Save.wipe_settings()
	if _real != "":
		Save.settings_path = _real
	_real = ""
	Save.reload_settings()
	if _real_picks != "":
		DirAccess.remove_absolute(Roster.picks_path)
		Roster.picks_path = _real_picks
	_real_picks = ""
	Roster.reload()
