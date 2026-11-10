## Suites that boot main.tscn keep their settings out of the real user://settings.json: the
## Showtime settings panel saves solo whenever it changes, and a saved solo readies both players
## in the next suite's lobby (and on the next real boot).
class_name SettingsSandbox
extends RefCounted

static var _real := ""


static func enter(path := "user://test_settings_suite.json") -> void:
	if _real == "":
		_real = Save.settings_path
	Save.settings_path = path
	Save.wipe_settings()


static func leave() -> void:
	Save.wipe_settings()
	if _real != "":
		Save.settings_path = _real
	_real = ""
	Save.reload_settings()
