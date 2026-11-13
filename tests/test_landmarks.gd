## Playtest 2026-11-12 (PT1112-1): "When kicking a ball, sometimes random roofs with birds will
## appear." Landmarks read as height: the tier 2-3 landmarks stand on the lawn, nothing that belongs
## on the ground is in a random sky set, and a ball passing a landmark fires its beat once.
class_name TestLandmarks
extends GdUnitTestSuite

const BALL := preload("res://scenes/ball.tscn")
const LADDER := preload("res://scenes/levels/height_ladder.tscn")
const HUD := preload("res://scenes/ui/hud.tscn")
## Sky objects that only make sense on the ground (a roof with a chimney, a TV mast, a washing line,
## a branch): never in a random sky set.
const GROUND_ONLY := ["cat_chimney", "pigeons", "laundry", "squirrel"]
## How far under/over the lawn (world y 0) a landmark's lowest point may be.
const GROUND_SLACK := 0.05

var _nodes: Array[Node] = []
var _save_was := true
var _ticks_was := 60
var _steps_was := 8


func before_test() -> void:
	_save_was = Run.save_enabled
	Run.save_enabled = false
	Run._clear()   # no curse (a dribble curse skips the climb) or space left from another suite
	Engine.time_scale = 1.0
	_ticks_was = Engine.physics_ticks_per_second
	_steps_was = Engine.max_physics_steps_per_frame
	Engine.physics_ticks_per_second = 60
	Engine.max_physics_steps_per_frame = 8
	seed(20261112)


func after_test() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()
	Engine.time_scale = 1.0
	Engine.physics_ticks_per_second = _ticks_was
	Engine.max_physics_steps_per_frame = _steps_was
	Run.save_enabled = _save_was
	Run._clear()


func _keep(n: Node) -> Node:
	add_child(n)
	_nodes.append(n)
	return n


## Lowest world y of every mesh under `n`.
static func _bottom(n: Node) -> float:
	var lo := INF
	var meshes: Array[Node] = n.find_children("*", "MeshInstance3D", true, false)
	if n is MeshInstance3D:
		meshes.append(n)
	for m in meshes:
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		var box := mi.global_transform * mi.mesh.get_aabb()
		lo = minf(lo, box.position.y)
	return lo


## Every part of the rooftops and treetops landmarks stands on the lawn: each house and tree (the
## landmark's direct children) reaches world y 0 at the height HeightLadder puts it.
func test_tier_1_to_3_landmarks_stand_on_the_ground() -> void:
	var tiers: TierSet = load(Run.TIERS_PATH)
	# Tier 1 (backyard) is the lawn itself: no landmark hung in the sky for it.
	assert_object(tiers.tiers[0].landmark).is_null()
	for i in [1, 2]:
		var t: TierData = tiers.tiers[i]
		assert_object(t.landmark).override_failure_message("tier %s has no landmark" % t.id).is_not_null()
		var root := _keep(Node3D.new()) as Node3D
		var lm := t.landmark.instantiate() as Node3D
		root.add_child(lm)
		lm.position = Vector3(0, TierSet.visual_y(t.threshold), 0)
		assert_int(lm.get_child_count()).is_greater_equal(3)
		for c in lm.get_children():
			var lo := _bottom(c)
			assert_float(lo).override_failure_message("%s/%s floats: bottom at y %.2f" % [t.id, c.name, lo]) \
					.is_less_equal(GROUND_SLACK)
			assert_float(lo).override_failure_message("%s/%s sunk: bottom at y %.2f" % [t.id, c.name, lo]) \
					.is_greater_equal(-1.5)


## The rooftops landmark is a street of houses (a skyline, not one roof) with the cat and pigeons on
## them, and the treetops birds live in the trees: every critter that reacts is inside a house or tree.
func test_critters_live_on_the_houses_and_trees() -> void:
	var tiers: TierSet = load(Run.TIERS_PATH)
	var roofs := _keep(tiers.get_tier(2).landmark.instantiate()) as LandmarkBeat
	var houses := roofs.get_children().filter(func(c: Node) -> bool: return String(c.name).begins_with("House"))
	assert_int(houses.size()).is_greater_equal(4)
	var trees := _keep(tiers.get_tier(3).landmark.instantiate()) as LandmarkBeat
	for lm in [roofs, trees]:
		var who: Array[Node] = lm.reactors()
		assert_int(who.size()).is_greater_equal(3)
		for n in who:
			assert_bool(lm.is_ancestor_of(n) and n.get_parent() != lm).is_true()
	var kinds := roofs.reactors().map(func(n: Node) -> StringName: return n.get_meta(&"react"))
	assert_array(kinds).contains([&"startle", &"scatter"])


## No `rooftops` set and nothing ground-only in any random sky set (data/sky.tres).
func test_rooftops_and_ground_things_are_not_in_the_random_sky() -> void:
	var sky: SkySet = load(SkyField.SKY_PATH)
	assert_object(sky.get_tier(&"rooftops")).is_null()
	for t in sky.tiers:
		assert_bool(t.id == &"rooftops").is_false()
		for e in t.entries:
			var file := e.scene.resource_path.get_file().get_basename()
			assert_bool(file in GROUND_ONLY).override_failure_message("%s has ground-only '%s'" % [t.id, file]).is_false()
	# And a planned flight through tier 2 puts nothing in the rooftops band.
	var f := _keep(SkyField.new()) as SkyField
	for s in 20:
		for item in f.plan(12.0, s):
			assert_int(item.tier).is_not_equal(2)


## A real ball flying through the rooftops and treetops lines fires each landmark's beat exactly once
## (and not the kites' above its peak); the critters react and the HUD strip's picture pops.
func test_a_passing_ball_fires_the_tier_beat_once() -> void:
	var ladder := _keep(LADDER.instantiate()) as Node3D
	var hud := _keep(HUD.instantiate()) as Control
	var b := BALL.instantiate()
	_keep(b)
	b.place_on_tee(Vector3.ZERO)
	await get_tree().process_frame
	var roofs := ladder.landmark(2) as LandmarkBeat
	var trees := ladder.landmark(3) as LandmarkBeat
	var kites := ladder.landmark(4) as LandmarkBeat
	assert_object(roofs).is_not_null()
	assert_object(trees).is_not_null()
	var cat := roofs.reactors().filter(func(n: Node) -> bool: return n.get_meta(&"react") == &"startle")[0] as Node3D
	var cat_scale := cat.scale
	var bird := trees.reactors()[0] as Node3D
	var bird_rest := bird.position
	var fired := {}
	var count := func(_p: int, tier: int) -> void: fired[tier] = fired.get(tier, 0) + 1
	Run.ball_tier_reached.connect(count)
	var popped := [false, false]
	var cat_moved := [false]
	var bird_moved := [false]
	var block2 := hud.get_node("Strip/Blocks").get_child(8 - 2) as Control
	var block3 := hud.get_node("Strip/Blocks").get_child(8 - 3) as Control
	Engine.time_scale = 2.0
	b.launch(Run.BASE_POWER * 4.0, 20.0)
	var t := 0.0
	while b.flight != b.Flight.PEAK and t < 15.0:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		popped[0] = popped[0] or block2.scale.x > 1.05
		popped[1] = popped[1] or block3.scale.x > 1.05
		cat_moved[0] = cat_moved[0] or not cat.scale.is_equal_approx(cat_scale)
		bird_moved[0] = bird_moved[0] or bird.position.distance_to(bird_rest) > 1.0
	# Hold at the peak a moment: no second beat.
	for i in 20:
		await get_tree().physics_frame
	Run.ball_tier_reached.disconnect(count)
	assert_int(b.flight).override_failure_message("no peak in %.1f s" % t).is_equal(b.Flight.PEAK)
	assert_int(fired.get(2, 0)).is_equal(1)
	assert_int(fired.get(3, 0)).is_equal(1)
	assert_int(roofs.beats).is_equal(1)
	assert_int(trees.beats).is_equal(1)
	if kites:
		assert_int(kites.beats).is_equal(0)
	assert_bool(cat_moved[0]).override_failure_message("the cat never startled").is_true()
	assert_bool(bird_moved[0]).override_failure_message("the treetop birds never scattered").is_true()
	assert_bool(popped[0] and popped[1]).override_failure_message("strip pops %s" % [popped]).is_true()
