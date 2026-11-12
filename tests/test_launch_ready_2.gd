## Launch-ready second pass (2026-11-12): Jeff and Chuck are voiced since openjar-characters v0.5.3
## (Kaden approved D37 on 2026-11-11), so their personalities are heard in play (P-09, A-06):
## the first kicker says "ready", a mid-run drop-in says "swap_in", a cursed flop is laughed off with
## "lose" after the crowd's "awww". Real roster (read-only), sandboxed settings and picks.
class_name TestLaunchReady2
extends GdUnitTestSuite

var main: Node
var said: Array = []


func _hear(slot: int, id: String, path: String) -> void:
	said.append([slot, id, path.get_file()])


func before_test() -> void:
	PhysicsPin.enter(4.0)
	SettingsSandbox.enter("user://test_launch_ready_2.json")
	Players.reset()
	Run.stop_run()
	Run.save_enabled = false
	Run._ensure_data()
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	Roster.set_pick(Players.P1, "jeff")
	Roster.set_pick(Players.P2, "chuck")
	said.clear()
	Roster.said.connect(_hear)


func after_test() -> void:
	if Roster.said.is_connected(_hear):
		Roster.said.disconnect(_hear)
	Run._in_run.clear()
	Run._active_curse.clear()
	Run.stop_run()
	Game.state = Game.State.LOBBY
	main.free()
	SettingsSandbox.leave()
	Run.save_enabled = true
	PhysicsPin.leave()
	await Audio.stop_all()


func test_jeff_and_chuck_have_every_bark_the_game_uses() -> void:
	for id in ["jeff", "chuck"]:
		var who := Roster.info(id)
		for b in ["cheer", "oops", "win", "ready", "swap_in", "lose"]:
			assert_bool(b in who.barks).override_failure_message("%s has no %s" % [id, b]).is_true()
			assert_bool(ResourceLoader.exists("%s%s.ogg" % [who.voice, b])).is_true()
		assert_bool(ResourceLoader.exists(who.catchphrase)).is_true()


func test_jeff_kicks_with_his_own_voice() -> void:
	main._kick_barks(Players.P1, Players.P2, CrowdReactions.Level.GREAT, false)
	assert_array(said).contains([[Players.P1, "jeff", "cheer.ogg"]])


func test_first_kicker_says_ready_at_round_one_only() -> void:
	Run._in_run[Players.P1] = true
	Run._in_run[Players.P2] = true
	main._on_round_started(2)
	assert_array(said).is_empty()
	main._on_round_started(1)
	assert_array(said).is_equal([[Players.P1, "jeff", "ready.ogg"]])


func test_drop_in_mid_run_says_swap_in_not_in_the_lobby() -> void:
	Game.state = Game.State.LOBBY
	main._on_player_joined(Players.P2, 0)
	assert_array(said).is_empty()
	Game.state = Game.State.PLAYING
	main._on_player_joined(Players.P2, 0)
	assert_array(said).is_equal([[Players.P2, "chuck", "swap_in.ogg"]])


func test_cursed_flop_is_laughed_off_after_the_aww(timeout := 20000) -> void:
	var curse := load("res://data/upgrades/banana_peel.tres") as UpgradeData
	Run._active_curse[Players.P1] = curse
	main._on_ball_stopped(Players.P1, 0.5, 1)
	assert_array(said).is_empty()   # the crowd's "awww" first
	await get_tree().create_timer(main.LAUGH_OFF + 0.3).timeout
	assert_array(said).is_equal([[Players.P1, "jeff", "lose.ogg"]])
	# An uncursed landing says nothing.
	said.clear()
	Run._active_curse.clear()
	main._on_ball_stopped(Players.P1, 3.0, 2)
	await get_tree().create_timer(main.LAUGH_OFF + 0.3).timeout
	assert_array(said).is_empty()


## Every menu cue is a real file in the game's own marimba / woodblock sound (no raw code-synth beep
## ships), and the file keeps the caller's pitch: P1 high, P2 low, the countdown rising per dot.
func test_every_menu_cue_is_a_real_file_and_keeps_its_pitch() -> void:
	for cue in UiSound.CUES:
		assert_bool(UiSound.has_file(cue)).override_failure_message("no sfx/%s.ogg" % cue).is_true()
	var heard: Array = []
	var hear := func(cue: String, pitch: float) -> void: heard.append([cue, snappedf(pitch, 0.01)])
	Audio.played.connect(hear)
	UiSound.play("count_tick", 1.24)
	UiSound.play("ui_move", 0.89)
	Audio.played.disconnect(hear)
	assert_array(heard).is_equal([["count_tick", 1.24], ["ui_move", 0.89]])
