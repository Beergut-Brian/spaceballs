## Gap-close lane 2: K-07 end card works with the stick alone (hold onto the big button), and the
## puff when a card's piece goes on wears that card's colour (painted icons, not the grey-box squares).
extends GdUnitTestSuite

const JEFF := preload("res://scenes/players/jeff.tscn")
const DIR := "res://data/upgrades/"

var _card: Control


func before() -> void:
	SettingsSandbox.enter("user://test_gap_close_settings.json")


func after() -> void:
	SettingsSandbox.leave()


func after_test() -> void:
	if is_instance_valid(_card):
		_card.free()
	Run.demo = false


func _up(id: String) -> UpgradeData:
	return load(DIR + id + ".tres") as UpgradeData


func _open_card() -> Control:
	Run.demo = false
	_card = load("res://scenes/ui/end_card.tscn").instantiate()
	get_tree().root.add_child(_card)
	_card.open()
	return _card


# --- K-07: stick only on the end card ----------------------------------------------------

func test_holding_the_stick_onto_the_big_button_goes_back_to_the_lobby() -> void:
	var card := _open_card()
	var asked := [0]
	card.restart_requested.connect(func() -> void: asked[0] += 1)
	assert_bool(card.hold_step(true, 0.5)).is_false()
	assert_float(card.hold).is_greater(0.3)
	# The ring is drawn and the button grows with the hold: it shows on screen.
	var ring: Control = card.get_node("ButtonHint/HoldRing")
	assert_object(ring).is_not_null()
	assert_bool(card.hold_step(true, 0.5)).is_false()
	assert_int(asked[0]).is_equal(0)
	assert_bool(card.hold_step(true, 0.3)).is_true()
	assert_int(asked[0]).is_equal(1)
	assert_bool(card.visible).is_false()


func test_letting_go_drains_the_ring_and_a_wiggle_never_fills_it() -> void:
	var card := _open_card()
	card.hold_step(true, 0.6)
	card.hold_step(false, 0.5)
	assert_float(card.hold).is_equal(0.0)
	# Wiggling: half the time held, half released, for a long while.
	for i in 200:
		assert_bool(card.hold_step(i % 2 == 0, 1.0 / 60.0)).is_false()
	assert_bool(card.visible).is_true()


func test_the_stick_never_leaves_the_game_through_the_door() -> void:
	var card := _open_card()
	card._focus_door(true, false)
	for i in 300:
		assert_bool(card.hold_step(true, 1.0 / 60.0)).is_false()
	assert_float(card.hold).is_equal(0.0)
	assert_bool(card.visible).is_true()


func test_reopening_starts_with_an_empty_ring() -> void:
	var card := _open_card()
	card.hold_step(true, 0.6)
	card.close()
	card.open()
	assert_float(card.hold).is_equal(0.0)


# --- the card-coloured puff --------------------------------------------------------------

func test_painted_icons_give_their_own_colour_not_white() -> void:
	var seen := {}
	for id in ["rocket_boots", "helium_ball", "jetpack", "tiny_hat", "duck_floatie", "super_cape"]:
		var c := Kicker.icon_color(_up(id))
		assert_bool(c.is_equal_approx(Color.WHITE)).override_failure_message(id + " puff is white").is_false()
		assert_float(c.s).override_failure_message(id + " puff is grey").is_greater(0.5)
		seen[c.to_html(false)] = true
	assert_int(seen.size()).is_greater(3)   # different cards, different puffs
	# The grey-box gradient icons still use their own stop; no icon is white.
	var bare := UpgradeData.new()
	assert_that(Kicker.icon_color(bare)).is_equal(Color.WHITE)


func test_duck_floatie_puff_is_yellow() -> void:
	var c := Kicker.icon_color(_up("duck_floatie"))
	assert_float(c.h).is_between(0.08, 0.2)


func test_gear_poof_wears_the_card_colour() -> void:
	var k: Kicker = auto_free(JEFF.instantiate())
	add_child(k)
	k.equipment.pop_in = false
	var boots := _up("rocket_boots")
	k.add_upgrade_visual(boots)
	assert_that(k._poof_color).is_equal(Kicker.icon_color(boots))
