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


## PF-3: the pick needs A, and nothing on screen said so. The highlighted card of a player still
## choosing carries the A button; it follows the stick and goes once that player has picked.
func test_pick_shows_a_on_the_highlighted_card_until_picked() -> void:
	Run._ensure_data()
	var pick: Control = auto_free(load("res://scenes/ui/upgrade_pick.tscn").instantiate())
	add_child(pick)
	pick.open({0: [Run.pool[0], Run.pool[1], Run.pool[2]], 1: [Run.pool[3], Run.pool[4], Run.pool[5]]}, [0, 1])
	var prompts := func(p: int) -> Array: return pick.cards_of(p).map(func(c: Control) -> bool: return c.prompt)
	assert_array(prompts.call(0)).is_equal([false, true, false])
	assert_array(prompts.call(1)).is_equal([false, true, false])
	pick._move(0, 1)
	assert_array(prompts.call(0)).is_equal([false, false, true])
	pick._pick(0)
	assert_array(prompts.call(0)).is_equal([false, false, false])
	assert_array(prompts.call(1)).is_equal([false, true, false])
	pick.close()


## PF-4: the end card's big green button and door needed A, and nothing showed it. Once the
## buttons show, an A sits under the focused one (the door when the stick moves onto it).
## PF-5: the end card's door went straight out to Open Jar; the lobby's and the pause menu's ask
## "Leave the game?" first, and now so does this one (B stays).
func test_end_card_shows_a_under_the_focused_button_and_the_door_asks() -> void:
	Run.demo = false
	var card: Control = auto_free(load("res://scenes/ui/end_card.tscn").instantiate())
	add_child(card)
	card.open()
	assert_object(card.prompt_target()).is_null()   # before the buttons show
	card._process(card.ACCEPT_AFTER + 0.1)
	assert_object(card.prompt_target()).is_same(card.button_hint)
	var safe_bottom: float = card.size.y - UiStyle.SAFE.y
	assert_float(card.prompt_at().y + card.PROMPT_SIZE * 0.5 + 5.0).is_less_equal(safe_bottom)
	card._focus_door(true, false)
	assert_object(card.prompt_target()).is_same(card.door)
	assert_float(card.prompt_at().y + card.PROMPT_SIZE * 0.5 + 5.0).is_less_equal(safe_bottom)
	var quits := [0]
	Game.quit_exits = false
	Game.quit_requested.connect(func() -> void: quits[0] += 1)
	card.press()
	assert_bool(card.confirm.active).is_true()
	assert_object(card.prompt_target()).is_null()   # the question has its own hint line
	assert_int(quits[0]).is_equal(0)
	card.confirm.choose(false)   # Stay
	assert_bool(card.visible).is_true()
	assert_int(quits[0]).is_equal(0)
	card.press()
	card.confirm.choose(true)
	assert_int(quits[0]).is_equal(1)
	Game.quit_exits = true
	card.close()


## PF-6: holding A on Play to start alone showed "STARTING SOLO" right where the READY! stamp sits
## (holding needs a ready player, so the stamp was always there): "STARTING SO..." under the stamp.
## While A is held the tag takes the stamp's place; let go and the stamp is back.
func test_starting_solo_tag_replaces_the_ready_stamp_while_held() -> void:
	var spot: Control = auto_free(load("res://scenes/ui/lobby_spot.gd").new())
	spot.readied = true
	assert_bool(spot.shows_stamp()).is_true()
	spot.hold = 0.4
	assert_bool(spot.shows_stamp()).is_false()
	spot.hold = 0.0
	assert_bool(spot.shows_stamp()).is_true()
