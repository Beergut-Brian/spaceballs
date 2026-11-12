## Launch-ready-2 (2026-11-12): in real frames of a forced Sneeze curse the roaming bystander (P-10)
## stood between the lens and the kicker at the windup, hiding the kick. The run-up shot (V-09) now
## swings round the bystander like a lawn tree; with nobody in the way it is the same shot as before.
extends GdUnitTestSuite

const RIG := preload("res://scripts/gameplay/camera_rig.gd")
const TEE := Vector3(2, 0, 0)


class Walker extends Node3D:
	var roam := true


func _rig() -> Array:
	var root := Node3D.new()
	var rig := Node3D.new()
	rig.set_script(RIG)
	var cam := Camera3D.new()
	cam.name = "Camera"
	rig.add_child(cam)
	root.add_child(rig)
	var kicker := Node3D.new()
	root.add_child(kicker)
	var other := Walker.new()
	root.add_child(other)
	add_child(root)
	auto_free(root)
	return [rig, kicker, other]


## The bystander's sphere crowds the picture: in front of the subject, edge within 15 degrees of
## the view's centre, or round the lens.
static func _hidden_by(look: Vector3, lens: Vector3, body: Vector3, r: float) -> bool:
	var f := (look - lens).normalized()
	var v := body - lens
	var d := v.length()
	if d < r:
		return true
	var along := v.dot(f)
	if along <= 0.0 or along > lens.distance_to(look):
		return false
	return acos(clampf(along / d, -1.0, 1.0)) - asin(minf(r / d, 1.0)) < deg_to_rad(15.0)


func _between(look: Vector3, lens: Vector3, t: float) -> Vector3:
	var at := look.lerp(lens, t)
	return Vector3(at.x, 0.0, at.z)


func test_the_shot_swings_round_a_bystander_in_front_of_the_lens() -> void:
	var bits := _rig()
	var rig: Node3D = bits[0]
	var kicker: Node3D = bits[1]
	var other: Walker = bits[2]
	other.global_position = Vector3(40, 0, 40)   # far away first: the plain shot
	var checked := 0
	for spot in [Vector3(2, 0, 6), Vector3(0, 0, 3), Vector3(4, 0, 10), Vector3(2, 0, 1.5)]:
		kicker.global_position = spot
		rig.bystander = null
		rig.frame_field(kicker, TEE)
		var look: Vector3 = rig.get("_look")
		var lens: Vector3 = rig.camera.global_position
		var plain := lens.distance_to(look)
		# He walks in halfway between the lens and the kicker: the old shot is blocked.
		other.global_position = _between(look, lens, 0.5)
		var body := other.global_position + Vector3.UP * RIG.BYSTANDER_CENTRE
		assert_bool(_hidden_by(look, lens, body, RIG.BYSTANDER_RADIUS)).is_true()
		rig.bystander = other
		rig.frame_field(kicker, TEE)
		look = rig.get("_look")
		lens = rig.camera.global_position
		assert_bool(_hidden_by(look, lens, body, RIG.BYSTANDER_RADIUS)) \
			.override_failure_message("kicker at %s still hidden behind the bystander" % spot).is_false()
		# Swung round him at the same distance: no zoom onto the kicker's nose.
		assert_float(lens.distance_to(look)).is_equal_approx(plain, 0.05)
		other.global_position = Vector3(40, 0, 40)
		checked += 1
	assert_int(checked).is_equal(4)
	# The occluder list is the trees' alone again after every frame.
	assert_int(rig.occluders.size()).is_equal(0)


func test_a_bystander_out_of_the_way_or_not_roaming_changes_nothing() -> void:
	var bits := _rig()
	var rig: Node3D = bits[0]
	var kicker: Node3D = bits[1]
	var other: Walker = bits[2]
	kicker.global_position = Vector3(2, 0, 6)
	rig.bystander = null
	rig.frame_field(kicker, TEE)
	var look: Vector3 = rig.get("_look")
	var plain: Vector3 = rig.camera.global_position
	# Off to the side, out of the picture's middle.
	other.global_position = kicker.global_position + Vector3(5, 0, -3)
	rig.bystander = other
	rig.frame_field(kicker, TEE)
	assert_vector(rig.camera.global_position).is_equal_approx(plain, Vector3.ONE * 0.01)
	# In the way but not roaming (benched, on his cloud, kicking himself): not an occluder.
	other.global_position = _between(look, plain, 0.5)
	other.roam = false
	rig.frame_field(kicker, TEE)
	assert_vector(rig.camera.global_position).is_equal_approx(plain, Vector3.ONE * 0.01)
	assert_array(rig.bystander_occluder()).is_empty()
	other.roam = true
	assert_int(rig.bystander_occluder().size()).is_equal(1)
