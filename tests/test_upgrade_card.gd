## The upgrade card shows its kind on the back, without text, and keeps player colours for the
## highlight border only. The icons themselves are checked in test_upgrades_data.gd.
extends GdUnitTestSuite

const CARD := preload("res://scenes/ui/upgrade_card.tscn")
const BY_KIND := {"normal": "big_boot", "strong": "jetpack", "joke": "mustache", "curse": "sneeze"}


func _card(id: String) -> PanelContainer:
	var card: PanelContainer = auto_free(CARD.instantiate())
	add_child(card)
	card.set_upgrade(load("res://data/upgrades/%s.tres" % id))
	return card


func test_every_kind_has_its_own_back() -> void:
	var backs := {}
	for kind in BY_KIND:
		var card := _card(BY_KIND[kind])
		assert_str(card.upgrade.kind).is_equal(kind)
		assert_object(card.icon.texture).is_not_null()
		backs[card.LOOK[kind]["back"]] = true
	assert_int(backs.size()).is_equal(4)


func test_every_card_in_the_pool_has_a_look() -> void:
	var card := _card("big_boot")
	for file in DirAccess.get_files_at("res://data/upgrades"):
		if file.ends_with(".tres"):
			var u: UpgradeData = load("res://data/upgrades/" + file)
			assert_bool(card.LOOK.has(u.kind)).override_failure_message(file + " kind " + u.kind).is_true()


func test_player_colour_is_only_the_highlight() -> void:
	var card := _card("jetpack")
	var style := card.get_theme_stylebox("panel") as StyleBoxFlat
	card.set_highlight(true, Players.COLOR[0])
	assert_that(style.border_color).is_equal(Players.COLOR[0])
	card.set_highlight(false, Players.COLOR[0])
	assert_that(style.border_color).is_equal(card.LOOK["strong"]["trim"])
