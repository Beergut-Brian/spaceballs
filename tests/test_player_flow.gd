## Player-flow lane 1 (2026-11-12): what a player on the couch hits walking every path of the
## exported build with a pad (handoff/PLAYER-FLOW.md). Each test pins one PF-<n> fix.
extends GdUnitTestSuite

const JuiceScript := preload("res://art/scripts/juice.gd")


func before() -> void:
	SettingsSandbox.enter("user://test_player_flow_settings.json")


func after() -> void:
	SettingsSandbox.leave()


## PF-1: Settings > Screen shake off saved the switch, but nothing read it: kicks still shook.
func test_screen_shake_off_means_no_shake() -> void:
	var juice = auto_free(JuiceScript.new())
	Save.set_setting(SettingsPanel.SHAKE, false)
	juice.shake(0.4)
	assert_float(juice._shake).is_equal(0.0)
	Save.set_setting(SettingsPanel.SHAKE, true)
	juice.shake(0.4)
	assert_float(juice._shake).is_equal(0.4)
