## Player-flow lane 1 (2026-11-12): what a player on the couch hits walking every path of the
## exported build with a pad (handoff/PLAYER-FLOW.md). Each test pins one PF-<n> fix.
extends GdUnitTestSuite

const JuiceScript := preload("res://art/scripts/juice.gd")


func before() -> void:
	SettingsSandbox.enter("user://test_player_flow_settings.json")


func after() -> void:
	SettingsSandbox.leave()
	await Audio.stop_all()


## PF-1: Settings > Screen shake off saved the switch, but nothing read it: kicks still shook.
func test_screen_shake_off_means_no_shake() -> void:
	var juice = auto_free(JuiceScript.new())
	Save.set_setting(SettingsPanel.SHAKE, false)
	juice.shake(0.4)
	assert_float(juice._shake).is_equal(0.0)
	Save.set_setting(SettingsPanel.SHAKE, true)
	juice.shake(0.4)
	assert_float(juice._shake).is_equal(0.4)


## PF-2: "Leave the game?" from the pause menu said "Progress is saved", but the run in progress is
## not (only the best kick and the card collection are). The lobby's question keeps its line.
func test_leaving_from_pause_says_the_run_ends() -> void:
	var pause: Control = auto_free(load("res://scenes/ui/pause_menu.tscn").instantiate())
	add_child(pause)
	pause.press(pause.Choice.DOOR)
	var body: Label = pause.get_node("Confirm/Card/Body")
	assert_bool(pause.get_node("Confirm").active).is_true()
	assert_str(body.text).is_equal(ConfirmDialog.BODY_IN_RUN)
	assert_str(body.text).not_contains("Progress is saved")
	pause.get_node("Confirm").choose(false)
	var lobby_q: ConfirmDialog = auto_free(load("res://scenes/ui/confirm_dialog.tscn").instantiate())
	add_child(lobby_q)
	lobby_q.open()
	assert_str(lobby_q.get_node("Card/Body").text).is_equal(ConfirmDialog.BODY_LOBBY)
	lobby_q.dismiss()
