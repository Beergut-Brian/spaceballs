## store/jar.glb (the launcher hub's jar world) loads the way the launcher loads it, at runtime with
## GLTFDocument, and stays inside the launcher contract: <= 5,000 triangles, <= 8 materials,
## textures <= 512 px, no lights/cameras, something visible. Rebuild with art/tools/make_jar.sh.
class_name TestStoreJar
extends GdUnitTestSuite

const JAR := "res://store/jar.glb"


func _load() -> Node3D:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	assert_int(doc.append_from_file(ProjectSettings.globalize_path(JAR), state)).is_equal(OK)
	return doc.generate_scene(state) as Node3D


func test_jar_fits_the_launcher_budget() -> void:
	var root := _load()
	assert_object(root).is_not_null()
	var tris := 0
	var mats := {}
	var textures_ok := true
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(s)
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
			tris += (idx.size() if idx.size() > 0 else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
			var mat := mi.mesh.surface_get_material(s) as BaseMaterial3D
			assert_object(mat).is_not_null()   # untextured glTF materials would lose their colour
			mats[mat] = true
			var tex := mat.albedo_texture
			assert_object(tex).is_not_null()
			if tex.get_width() > 512 or tex.get_height() > 512:
				textures_ok = false
	assert_int(tris).is_greater(500).is_less_equal(5000)
	assert_int(mats.size()).is_less_equal(8)
	assert_bool(textures_ok).is_true()
	assert_int(root.find_children("*", "Light3D", true, false).size()).is_equal(0)
	assert_int(root.find_children("*", "Camera3D", true, false).size()).is_equal(0)
	root.free()


func test_jar_stands_on_its_floor_at_the_origin() -> void:
	var root := _load()
	var box := AABB()
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		var b := _xf(mi) * mi.get_aabb()
		box = b if box.size == Vector3.ZERO else box.merge(b)
	assert_float(box.position.y).is_equal_approx(0.0, 0.02)
	assert_float(box.get_center().x).is_equal_approx(0.0, 0.1)
	assert_float(box.get_center().z).is_equal_approx(0.0, 0.1)
	assert_float(box.size.y).is_greater(box.size.x)   # tall like the jar: the kick goes up
	root.free()


static func _xf(n: Node) -> Transform3D:
	var xf := Transform3D.IDENTITY
	while n != null:
		if n is Node3D:
			xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf
