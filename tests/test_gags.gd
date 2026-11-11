## Wind-up gags (Gameplay polish): every gag changes the approach, never the result. Whatever
## the gag (or the frog), and even if its tween dies, the foot meets the ball exactly once.
class_name TestGags
extends GdUnitTestSuite

const JEFF := preload("res://scenes/players/jeff.tscn")
const CARDS := {
	&"banana_peel": &"slip", &"butterfly": &"chase", &"too_much_lunch": &"waddle",
	&"shoelaces_tied": &"trip", &"sneeze": &"sneeze",
}


func before_test() -> void:
	PhysicsPin.enter(4.0)   # fixed 60 Hz step, seeded RNG, no curse left in Run by another suite
	await get_tree().physics_frame


func after_test() -> void:
	PhysicsPin.leave()
	await Audio.stop_all()


## Floor + camera + Jeff standing just short of a ball at the origin.
func _setup() -> Kicker:
	var root := Node3D.new()
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60, 1, 60)
	shape.shape = box
	floor_body.add_child(shape)
	floor_body.position = Vector3(0, -0.5, 0)
	root.add_child(floor_body)
	var cam := Camera3D.new()
	root.add_child(cam)
	add_child(root)
	auto_free(root)
	cam.global_position = Vector3(8, 3, 2)
	cam.look_at(Vector3.ZERO)
	var k: Kicker = JEFF.instantiate()
	root.add_child(k)
	k.global_position = Vector3(0, 0, 1.2)
	return k


## Starts the wind-up and counts contacts for up to `seconds` of game time.
func _kick(k: Kicker, windup: UpgradeData, seconds: float = 6.0, sabotage := false) -> Array:
	var contacts := []
	k.kick_contact.connect(func(q: float) -> void: contacts.append(q))
	k.windup = windup
	k.begin_approach(Vector3(0, 0.35, 0))
	k.start_windup()
	if sabotage and k._tween:
		k._tween.kill()   # whatever breaks the gag, the deadline still kicks
	var t := 0.0
	while t < seconds:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	return contacts


func _card(id: StringName) -> UpgradeData:
	return load("res://data/upgrades/%s.tres" % id)


func test_the_five_cards_name_a_gag() -> void:
	for id in CARDS:
		var u := _card(id)
		assert_str(String(u.windup_anim)).is_equal(String(CARDS[id]))
		assert_str(String(Kicker.gag_of(u))).is_equal(String(CARDS[id]))
	assert_str(String(Kicker.gag_of(null))).is_empty()
	var odd := UpgradeData.new()
	odd.windup_anim = &"moonwalk"   # unknown names fall back to the normal kick
	assert_str(String(Kicker.gag_of(odd))).is_empty()


func test_every_gag_kicks_exactly_once(timeout := 120000) -> void:
	for id in CARDS:
		var k := _setup()
		var started := []
		k.gag_started.connect(func(g: StringName) -> void: started.append(g))
		var contacts: Array = await _kick(k, _card(id))
		assert_array(started).is_equal([CARDS[id]])
		assert_int(contacts.size()).override_failure_message("gag %s kicked %d times" % [CARDS[id], contacts.size()]).is_equal(1)
		assert_float(contacts[0]).is_between(0.8, 1.2)
		# Back on his feet, the prop gone or still harmless, Body upright again.
		assert_int(k.state).is_equal(Kicker.State.IDLE)
		assert_vector(k.body.rotation).is_equal_approx(Vector3.ZERO, Vector3.ONE * 0.001)


func test_a_broken_gag_still_kicks_by_the_deadline(timeout := 60000) -> void:
	for id in [&"banana_peel", &"sneeze"]:
		var k := _setup()
		var contacts: Array = await _kick(k, _card(id), Kicker.KICK_DEADLINE + 1.0, true)
		assert_int(contacts.size()).is_equal(1)


func test_frog_flop_wins_over_a_gag(timeout := 60000) -> void:
	var k := _setup()
	k.set_frog(true, load("res://scenes/curses/frog.tscn"))
	var started := []
	k.gag_started.connect(func(g: StringName) -> void: started.append(g))
	var contacts: Array = await _kick(k, _card(&"banana_peel"), 3.0)
	assert_array(started).is_empty()
	assert_int(contacts.size()).is_equal(1)


func test_no_gag_is_the_normal_kick(timeout := 60000) -> void:
	var k := _setup()
	var started := []
	k.gag_started.connect(func(g: StringName) -> void: started.append(g))
	var contacts: Array = await _kick(k, _card(&"big_boot"), 3.0)
	assert_array(started).is_empty()
	assert_int(contacts.size()).is_equal(1)


func test_curse_prop_shows_for_its_kick_only(timeout := 60000) -> void:
	var k := _setup()
	k.windup = _card(&"banana_peel")
	k.begin_approach(Vector3(0, 0.35, 0))
	assert_object(k._prop).is_not_null()
	assert_int(k.attach_point(&"feet").get_child_count()).is_equal(0)   # on the grass, not worn
	k.set_waiting(false)
	assert_object(k._prop).is_null()
