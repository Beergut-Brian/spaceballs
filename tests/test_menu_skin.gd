## Spaceballs' Showtime skin (data/menu_skin.tres): it loads, and the lobby shows Jeff (P1, left)
## and Chuck (P2, right) as the rigged 3D Jarlings, not the template's placeholder, over the live
## blurred field. The round card names who kicks first.
class_name TestMenuSkin
extends GdUnitTestSuite

var _main: Node


func before() -> void:
	SettingsSandbox.enter()


func after() -> void:
	SettingsSandbox.leave()
	await Audio.stop_all()   # a cue still playing when the runner quits shows up as a leak


func before_test() -> void:
	Players.reset()
	Game.demo = false
	Run.demo = false
	Game.round_index = 0
	Game._set_state(Game.State.LOBBY)
	UiStyle.use_skin(load(UiStyle.SKIN_PATH))


func after_test() -> void:
	if is_instance_valid(_main):
		_main.free()
	Players.reset()
	Run.stop_run()
	Game._set_state(Game.State.LOBBY)
	get_tree().paused = false


func test_skin_loads() -> void:
	var sk := load("res://data/menu_skin.tres") as MenuSkin
	assert_object(sk).is_not_null()
	assert_str(sk.title()).is_equal("Spaceballs")
	assert_bool(sk.accent.is_equal_approx(Color("ffc928"))).is_true()
	assert_bool(sk.accent2.is_equal_approx(Color("2a9dff"))).is_true()
	assert_bool(sk.deep.is_equal_approx(Color("16296b"))).is_true()
	assert_int(sk.backdrop).is_equal(MenuSkin.Backdrop.SCREEN)
	assert_str(sk.player_name(Players.P1)).is_equal("JEFF")
	assert_str(sk.player_name(Players.P2)).is_equal("CHUCK")


func test_lobby_shows_jeff_and_chuck() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	add_child(_main)
	await await_idle_frame()
	var lobby: Control = _main.get_node("UI/Lobby")
	assert_bool(lobby.visible).is_true()
	assert_str(lobby.get_node("TitleArt/TitleLabel").text.to_upper()).contains("SPACEBALLS")
	var models := ["jeff", "chuck"]
	for p in [Players.P1, Players.P2]:
		var slot: CharacterSlot = lobby.get_node("Spots/P%d/Character" % (p + 1))
		assert_bool(slot.character is Node3D).is_true()
		assert_str(slot.character.id).is_equal(models[p])   # the Roster pick (defaults)
		var model: Node = slot.character.get_node("Jarling/Model")
		assert_str(model.scene_file_path).contains(models[p])
		assert_object(model.find_child("AnimationPlayer", true, false)).is_not_null()
	# Both ready: the countdown's last beat sets the round card's line.
	Players.join_virtual(Players.P1)
	Players.join_virtual(Players.P2)
	lobby.press_a(Players.P1)
	lobby.press_a(Players.P2)
	lobby.count_step(lobby.COUNT_STEP * lobby.COUNT_DOTS + 0.01)
	assert_str(lobby.round_card_subtitle).is_equal("JEFF KICKS FIRST")
	assert_int(Game.state).is_equal(Game.State.PLAYING)
