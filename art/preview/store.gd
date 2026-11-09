## Store art stages (store/grid.png, store/hero.png). Art lane. Poses Jarling .glbs at a frame of an
## authored action, sets faces, places faced balls. Rendered by art/tools/render_store.sh.
extends Node3D

const BALL_SHADER := preload("res://art/shaders/ball.gdshader")
const FACES := preload("res://assets/sprites/ball_faces.png")
const ACCENTS := [Color("3cc24a"), Color("e4393c")]
const POPS := [Color("ffd84d"), Color("38c6ff")]
const EXPR := {&"neutral": Vector3(0, 0, 0), &"happy": Vector3(0.5, 0, 0),
	&"surprised": Vector3(0, 0.5, 0), &"determined": Vector3(0.5, 0.5, 0)}

@export_enum("grid", "hero") var kind := "grid"


func _ready() -> void:
	if kind == "grid":
		_grid()
	else:
		_hero()


func _grid() -> void:
	var stage := $Stage as Node3D
	var cam := stage.get_node("Camera3D") as Camera3D
	cam.look_at_from_position(stage.to_global(Vector3(0, 1.0, 4.6)), stage.to_global(Vector3(0, 1.6, 0)))
	var tee_mat := StandardMaterial3D.new()
	tee_mat.albedo_color = Color("ff9f2e")
	(stage.get_node("Tee") as MeshInstance3D).material_override = tee_mat
	_pose(stage.get_node("Jeff"), &"kick", 0.42, &"determined")
	_pose(stage.get_node("Chuck"), &"kick", 0.47, &"determined")
	var b1 := _ball(stage, 0, Vector3(-0.62, 4.2, -0.4), 2.0, 0.9)
	_streak(stage, b1.position, Vector3(0.12, -1.0, 0.1), ACCENTS[0])
	_ball(stage, 1, Vector3(0.95, 0.36, 0.55), 0.0, 1.0)
	var tee := stage.get_node("Tee") as Node3D
	tee.position = Vector3(0.95, 0.0, 0.55)


func _hero() -> void:
	var c := ($Planet as Node3D).position
	($Sun as Node3D).rotation_degrees = Vector3(-28, -62, 0)
	var spots := [Vector3(-1.9, 1.55, 1.4), Vector3(2.0, 0.85, 0.9)]
	for i in 2:
		var p: Vector3 = spots[i]
		var u := (p - c).normalized()
		var travel := Vector3(1.0, 0.0, 0.45 if i == 0 else -0.5).normalized()
		var n := u.cross(travel).normalized()
		_ball(self, i, p, 2.0, 1.7)
		var arc := MeshInstance3D.new()
		var t := TorusMesh.new()
		var r := (p - c).length()
		t.inner_radius = r - 0.025
		t.outer_radius = r + 0.025
		t.rings = 256
		t.ring_segments = 6
		arc.mesh = t
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.albedo_color = ACCENTS[i].lerp(Color.WHITE, 0.4)
		m.albedo_color.a = 0.85
		arc.material_override = m
		add_child(arc)
		arc.position = c
		arc.basis = Basis(u, n, u.cross(n))


func _pose(model: Node, anim: StringName, t: float, face: StringName) -> void:
	var ap := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	ap.play(anim)
	ap.seek(t, true)
	ap.pause()
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(s) as StandardMaterial3D
			if m == null:
				continue
			m = m.duplicate()
			m.rim_enabled = true
			m.rim = 0.45
			m.rim_tint = 0.3
			if m.resource_name.ends_with("_face"):
				m.uv1_offset = EXPR[face]
			mi.set_surface_override_material(s, m)


func _ball(parent: Node, player: int, pos: Vector3, expr: float, size: float) -> MeshInstance3D:
	var b := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.3
	s.height = 0.6
	s.radial_segments = 48
	s.rings = 24
	b.mesh = s
	var m := ShaderMaterial.new()
	m.shader = BALL_SHADER
	m.set_shader_parameter(&"faces", FACES)
	m.set_shader_parameter(&"accent", ACCENTS[player])
	m.set_shader_parameter(&"pop", POPS[player])
	m.set_shader_parameter(&"expr", expr)
	b.material_override = m
	parent.add_child(b)
	b.position = pos
	b.scale = Vector3.ONE * size
	var cam := get_viewport().get_camera_3d()
	if cam:
		# Turn the face to the camera.
		var to_cam := (cam.global_position - b.global_position)
		b.global_rotation.y = atan2(to_cam.x, to_cam.z) - 1.15
	return b


func _streak(parent: Node, from: Vector3, dir: Vector3, tint: Color) -> void:
	for k in 5:
		var q := MeshInstance3D.new()
		var cap := CapsuleMesh.new()
		cap.radius = 0.2 - k * 0.03
		cap.height = 1.4 - k * 0.15
		q.mesh = cap
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.albedo_color = tint.lerp(Color.WHITE, 0.6)
		m.albedo_color.a = 0.24 - k * 0.04
		q.material_override = m
		parent.add_child(q)
		q.position = from + dir.normalized() * (0.75 + k * 0.45)
		q.look_at(q.global_position + dir, Vector3.FORWARD)
		q.rotate_object_local(Vector3.RIGHT, PI / 2)
