## Gap-close lane 6 (2026-11-11): rough spots found in real frames of a demo run.
## V-09: a kicker near the field's edge put the run-up camera inside a lawn tree (a whole screen of
## leaves); the rig now pulls the lens in front of any tree between it and the kicker.
extends GdUnitTestSuite

const FIELD := preload("res://scenes/levels/field.tscn")
const RIG := preload("res://scripts/gameplay/camera_rig.gd")
const MAIN := preload("res://scenes/main.tscn")
const BOUNDS := Rect2(-5.7, -5.8, 13.6, 40.3)   # Kicker.bounds
const TEE := Vector3(2, 0, 0)


func before() -> void:
	SettingsSandbox.enter("user://test_gap_close_6_settings.json")


func after() -> void:
	SettingsSandbox.leave()


func _rig_on_field() -> Array:
	var root := Node3D.new()
	var field: Node3D = FIELD.instantiate()
	root.add_child(field)
	var rig := Node3D.new()
	rig.set_script(RIG)
	var cam := Camera3D.new()
	cam.name = "Camera"
	rig.add_child(cam)
	root.add_child(rig)
	var kicker := Node3D.new()
	root.add_child(kicker)
	add_child(root)
	auto_free(root)
	return [rig, field, kicker]


## How many crown spheres crowd the picture: in front of the subject with their edge within 15
## degrees of the view's centre, or round the lens. The demo frame that started this had a canopy
## edge 10 degrees off centre, 3.4 m from the lens: half the screen leaves.
static func _blocked(look: Vector3, lens: Vector3, crowns: Array[Vector4]) -> int:
	var hits := 0
	var f := (look - lens).normalized()
	var dist := lens.distance_to(look)
	for o in crowns:
		var c := Vector3(o.x, o.y, o.z)
		var d := lens.distance_to(c)
		if d < o.w:
			hits += 1   # the lens is inside the canopy
			continue
		var along := (c - lens).dot(f)
		if along <= 0.0 or along >= dist:
			continue   # behind the lens, or behind him: not in the way
		if acos(along / d) - asin(o.w / d) < deg_to_rad(15.0):
			hits += 1
	return hits


static func _under_a_tree(p: Vector3, crowns: Array[Vector4]) -> bool:
	for o in crowns:
		if Vector2(p.x - o.x, p.z - o.z).length() < o.w + 2.0:
			return true
	return false


## The canopy blobs of the field's lawn trees (the `occluders` meta also holds thin trunk spheres).
func _crowns(field: Node3D) -> Array[Vector4]:
	var out: Array[Vector4] = []
	for o: Vector4 in field.get_node("Dressing/Trees").get_meta(&"occluders"):
		if o.w >= 1.0:
			out.append(o)
	return out


## Every spot a kicker can stand on: the run-up shot never looks through, or past the edge of, a
## canopy near the lens.
## Without the trees registered, the same sweep finds blocked shots (the frame that started this).
func test_run_up_camera_never_sits_in_a_tree(timeout := 60000) -> void:
	var bits := _rig_on_field()
	var rig: Node3D = bits[0]
	var field: Node3D = bits[1]
	var kicker: Node3D = bits[2]
	var crowns := _crowns(field)
	assert_int(crowns.size()).is_greater(20)
	var spots: Array[Vector3] = []
	var x := BOUNDS.position.x
	while x <= BOUNDS.end.x + 0.01:
		var z := BOUNDS.position.y
		while z <= BOUNDS.end.y + 0.01:
			spots.append(Vector3(x, 0, z))
			z += 1.0
		x += 1.0
	var before := 0
	var plain := {}
	for p in spots:
		kicker.global_position = p
		rig.frame_field(kicker, TEE)
		var look: Vector3 = rig.get("_look")
		before += _blocked(look, rig.camera.global_position, crowns)
		plain[p] = rig.camera.global_position.distance_to(look)
	assert_int(before).override_failure_message("the old shot should have hit a tree somewhere").is_greater(0)

	rig.set_trees(field.get_node("Dressing/Trees"))
	assert_int(rig.occluders.size()).is_greater(crowns.size())
	var after := 0
	var pulled := []
	for p in spots:
		kicker.global_position = p
		rig.frame_field(kicker, TEE)
		var look: Vector3 = rig.get("_look")
		var lens: Vector3 = rig.camera.global_position
		if not _under_a_tree(p, crowns):
			after += _blocked(look, lens, crowns)
		if lens.distance_to(look) < plain[p] - 0.01 and not _under_a_tree(p, crowns):
			pulled.append(p)
	assert_int(after).override_failure_message("%d shots still crowded by a tree (was %d)" % [after, before]).is_equal(0)
	# It swings round the trees, keeping the same distance: no sudden zoom onto his nose (unless he
	# stands right under one, where the lens moves in under the canopy).
	assert_array(pulled).override_failure_message("pulled in at %s" % [pulled]).is_empty()


## A shot with nothing in the way is left exactly where it was.
func test_clear_shots_are_untouched() -> void:
	var bits := _rig_on_field()
	var rig: Node3D = bits[0]
	var field: Node3D = bits[1]
	rig.set_trees(field.get_node("Dressing/Trees"))
	var look := Vector3(2, 1, 6)
	var want := look + Vector3(8.4, 1.7, 4.2)
	assert_vector(rig.clear_view(look, want)).is_equal_approx(want, Vector3.ONE * 0.001)


## The real game registers the field's trees with its camera.
func test_main_gives_the_camera_the_lawn_trees(timeout := 60000) -> void:
	Run.save_enabled = false
	var main: Node = MAIN.instantiate()
	get_tree().root.add_child(main)
	await get_tree().process_frame
	var rig: Node3D = main.get_node("CameraRig")
	assert_int(rig.occluders.size()).is_greater(50)
	main.free()
	Run.save_enabled = true
	Run.phase = Run.Phase.IDLE
	Game._set_state(Game.State.TITLE)
	get_tree().root.get_viewport().disable_3d = false
	await Audio.stop_all()
	await get_tree().physics_frame

