## Gap-close lane 8 (2026-11-12): rough spots found in real frames.
## C-19 / K-11: a player who reached space waits on his cloud while the other keeps kicking. In the
## frames he was never in the picture (up behind the HUD's height ladder or a lawn tree, or out of
## shot), and his cheer button showed nothing: a sound only. Now his colour arrow points at his
## cloud like the roaming bystander's, and a cheer makes it jump and throw stars (a ring of stars
## round him when he is in shot), drawn over the trees.
extends GdUnitTestSuite

const P1 := Players.P1
const P2 := Players.P2
const SIZE := Vector2(1920, 1080)

var _main: Node
var _space_p1 := func() -> void: Run._in_space[P1] = true


func before() -> void:
	SettingsSandbox.enter("user://test_gap_close_8_settings.json")


func after() -> void:
	SettingsSandbox.leave()
	await Audio.stop_all()


func after_test() -> void:
	if Run.run_started.is_connected(_space_p1):
		Run.run_started.disconnect(_space_p1)
	if is_instance_valid(_main):
		_main.free()
	Run.save_enabled = true
	Run.demo = false
	Game.demo = false
	Run.phase = Run.Phase.IDLE
	Run.stop_run()
	Run._clear()
	Game._set_state(Game.State.TITLE)
	Engine.time_scale = 1.0


## Under the HUD's height ladder (the right-hand column) counts as out of shot, like the very edge.
func test_the_ladder_column_is_not_in_view() -> void:
	assert_bool(OffscreenArrow.in_view(SIZE * 0.5, SIZE)).is_true()
	assert_bool(OffscreenArrow.in_view(Vector2(1600, 140), SIZE)).is_true()
	# Where the cloud player sat in the frames: behind the ladder's top tiles.
	assert_bool(OffscreenArrow.in_view(Vector2(1790, 129), SIZE)).is_false()
	assert_bool(OffscreenArrow.in_view(Vector2(1888, 139), SIZE)).is_false()
	assert_bool(OffscreenArrow.in_view(Vector2(5, 500), SIZE)).is_false()


## A cheer pops the arrow for a moment, then it settles back.
func test_pop_fades_back() -> void:
	var a := OffscreenArrow.new()
	add_child(a)
	auto_free(a)
	a.pop()
	assert_float(a._pop).is_equal(1.0)
	a._process(OffscreenArrow.POP_TIME * 0.5)
	assert_float(a._pop).is_between(0.4, 0.6)
	a._process(OffscreenArrow.POP_TIME)
	assert_float(a._pop).is_equal(0.0)
	a.pop()
	a.hide_arrow()
	assert_float(a._pop).is_equal(0.0)


## In the real game: P1 is in space, P2 kicks. P1's arrow points at his cloud, and his cheer pops it.
func test_the_cloud_players_cheer_shows_on_screen(timeout := 60000) -> void:
	Run.run_started.connect(_space_p1)
	Run.save_enabled = false
	Run.demo = true
	_main = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(_main)
	Engine.time_scale = 4.0
	var t := 0.0
	while Run.phase != Run.Phase.KICK_P2 and t < 20.0:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	assert_int(Run.phase).is_equal(Run.Phase.KICK_P2)
	var k: Kicker = _main.kickers[P1]
	assert_int(k.state).is_equal(Kicker.State.CLOUD)
	var arrow: OffscreenArrow = _main._bystander_arrow
	assert_object(arrow.target).is_same(k)
	assert_bool(arrow.visible).is_true()
	assert_float(arrow._pop).is_equal(0.0)
	Game._set_state(Game.State.PLAYING)
	Engine.time_scale = 1.0
	var action := Players.action(P1, "action")
	Input.action_press(action)
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release(action)
	assert_float(arrow._pop).is_greater(0.0)
	# Something to see either way: the arrow at the edge, or the star ring round him in shot.
	await get_tree().process_frame
	assert_bool(arrow.at != null or arrow._sp != null).is_true()
	assert_int(Run.phase).is_equal(Run.Phase.KICK_P2)   # his cheer never touches P2's kick
