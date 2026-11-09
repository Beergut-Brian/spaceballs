## Builds the Art lane's prop scenes from Godot primitives (smooth-shaded, flat colours, rim light):
## field dressing, the frog and the tier landmarks. Re-run after editing:
##   godot --headless --path . -s art/tools/build_scenes.gd
## Every value here is the source of truth for those scenes; hand edits in the .tscn get overwritten.
extends SceneTree

const MOTION := preload("res://art/scripts/landmark_motion.gd")

# Palette: C Cool Arcade (art/palettes/cool_arcade.json) plus a few naturals for the lawn.
const INK := Color("0a0a14")
const ICE := Color("eef8ff")
const SLATE := Color("8e9cc0")
const SKY1 := Color("86f6ff")
const SKY2 := Color("38c6ff")
const SKY3 := Color("3d8bff")
const SKY4 := Color("7a6cff")
const SKY5 := Color("6628ff")
const TEAL := Color("1cc9a6")
const PLUM := Color("9c5e9e")
const PEACH := Color("ffbfa0")
const ORANGE := Color("ff9f2e")
const PINK := Color("ff4fd8")
const YELLOW := Color("ffd84d")
const P1_GREEN := Color("3cc24a")
const P2_RED := Color("e4393c")
const HAT_BLACK := Color("2b2b33")
const WHITE := Color("fbfbf7")
const BARK := Color("8a5a2b")
const LEAF_A := Color("4cb86a")
const LEAF_B := Color("2fa38a")
const LEAF_C := Color("7ccf5b")
const FROG := Color("8fd14f")
const FROG_BELLY := Color("eaf6b8")

var _mats := {}
var _meshes := {}
var _root: Node


func _init() -> void:
	_build_field()
	_build_frog()
	_build_landmarks()
	print("BUILD_SCENES_OK")
	quit()


# --- helpers -------------------------------------------------------------------

func mat(c: Color, rough := 0.7, rim := 0.35) -> StandardMaterial3D:
	var key := "%s/%s/%s" % [c.to_html(), rough, rim]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = rough
		if rim > 0.0:
			m.rim_enabled = true
			m.rim = rim
			m.rim_tint = 0.3
		_mats[key] = m
	return _mats[key]


func unshaded(c: Color) -> StandardMaterial3D:
	var key := "u/%s" % c.to_html()
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		if c.a < 1.0:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mats[key] = m
	return _mats[key]


func _mesh(kind: String, a := 0.0, b := 0.0, c := 0.0) -> Mesh:
	var key := "%s/%s/%s/%s" % [kind, a, b, c]
	if _meshes.has(key):
		return _meshes[key]
	var m: Mesh
	match kind:
		"sphere":
			var s := SphereMesh.new()
			s.radius = a
			s.height = a * 2.0
			s.radial_segments = int(b) if b > 0 else 32
			s.rings = int(b / 2) if b > 0 else 16
			m = s
		"hemi":
			var s := SphereMesh.new()
			s.radius = a
			s.height = a
			s.is_hemisphere = true
			s.radial_segments = 32
			s.rings = 12
			m = s
		"cyl":
			var cy := CylinderMesh.new()
			cy.top_radius = a
			cy.bottom_radius = b
			cy.height = c
			cy.radial_segments = 24
			cy.rings = 1
			m = cy
		"box":
			var bx := BoxMesh.new()
			bx.size = Vector3(a, b, c)
			m = bx
		"cap":
			var cp := CapsuleMesh.new()
			cp.radius = a
			cp.height = maxf(b, a * 2.0)
			cp.radial_segments = 24
			cp.rings = 6
			m = cp
		"prism":
			var p := PrismMesh.new()
			p.size = Vector3(a, b, c)
			m = p
		"torus":
			var t := TorusMesh.new()
			t.inner_radius = a
			t.outer_radius = b
			t.rings = 32
			t.ring_segments = 12
			m = t
		"quad":
			var q := QuadMesh.new()
			q.size = Vector2(a, b)
			m = q
	_meshes[key] = m
	return m


func node(parent: Node, n: String, pos := Vector3.ZERO, rot := Vector3.ZERO, scl := Vector3.ONE) -> Node3D:
	var x := Node3D.new()
	x.name = n
	parent.add_child(x)
	x.position = pos
	x.rotation = rot
	x.scale = scl
	return x


func mi(parent: Node, n: String, mesh: Mesh, m: Material, pos := Vector3.ZERO, rot := Vector3.ZERO, scl := Vector3.ONE, shadow := true) -> MeshInstance3D:
	var x := MeshInstance3D.new()
	x.name = n
	x.mesh = mesh
	x.material_override = m
	parent.add_child(x)
	x.position = pos
	x.rotation = rot
	x.scale = scl
	if not shadow:
		x.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return x


func sph(parent: Node, n: String, pos: Vector3, r: float, c: Color, scl := Vector3.ONE, rough := 0.7) -> MeshInstance3D:
	return mi(parent, n, _mesh("sphere", r), mat(c, rough), pos, Vector3.ZERO, scl)


func cyl(parent: Node, n: String, pos: Vector3, rt: float, rb: float, h: float, c: Color, rot := Vector3.ZERO) -> MeshInstance3D:
	return mi(parent, n, _mesh("cyl", rt, rb, h), mat(c), pos, rot)


func box(parent: Node, n: String, pos: Vector3, size: Vector3, c: Color, rot := Vector3.ZERO) -> MeshInstance3D:
	return mi(parent, n, _mesh("box", size.x, size.y, size.z), mat(c), pos, rot)


func cap(parent: Node, n: String, pos: Vector3, r: float, h: float, c: Color, rot := Vector3.ZERO) -> MeshInstance3D:
	return mi(parent, n, _mesh("cap", r, h), mat(c), pos, rot)


func motion(n: Node3D, mode: int, amount: float, speed: float, axis := Vector3.UP, phase := 0.0) -> Node3D:
	n.set_script(MOTION)
	n.set("mode", mode)
	n.set("amount", amount)
	n.set("speed", speed)
	n.set("axis", axis)
	n.set("phase", phase)
	return n


func own(n: Node, root: Node) -> void:
	for c in n.get_children():
		c.owner = root
		if c.scene_file_path == "":
			own(c, root)


func save(root: Node, path: String) -> void:
	own(root, root)
	var ps := PackedScene.new()
	var err := ps.pack(root)
	assert(err == OK)
	err = ResourceSaver.save(ps, path)
	if err != OK:
		push_error("save failed %s" % path)
	print("saved ", path)
	root.free()


func clear(n: Node, names: Array) -> void:
	for nm in names:
		var c := n.get_node_or_null(NodePath(nm))
		if c:
			c.get_parent().remove_child(c)
			c.free()


## Puffy cloud: overlapping spheres, flat bottom feel by squashing.
func cloud(parent: Node, n: String, pos: Vector3, size: float, seed_: int, m: Material = null) -> Node3D:
	var c := node(parent, n, pos)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var mm: Material = m if m else mat(Color("e6eef8"), 1.0, 0.3)
	var count := 5
	for i in count:
		var x := (float(i) / (count - 1) - 0.5) * 2.2 * size
		var r := size * (0.55 + 0.35 * sin(PI * float(i) / (count - 1))) * rng.randf_range(0.85, 1.1)
		mi(c, "Puff%d" % i, _mesh("sphere", 1.0, 24), mm, Vector3(x, r * 0.25, rng.randf_range(-0.2, 0.2) * size), Vector3.ZERO, Vector3(r, r * 0.8, r * 0.9))
	return c


## Round blob tree like the style mock: trunk plus three canopy blobs.
func tree(parent: Node, n: String, pos: Vector3, h: float, leaf: Color, seed_: int) -> Node3D:
	var t := node(parent, n, pos)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var tr := 0.09 * sqrt(h)
	cyl(t, "Trunk", Vector3(0, h * 0.35, 0), tr * 0.75, tr * 1.1, h * 0.7, BARK)
	var r := h * 0.32
	sph(t, "Crown", Vector3(0, h * 0.75, 0), r, leaf)
	sph(t, "BlobA", Vector3(r * 0.6, h * 0.62, r * 0.2), r * 0.7, leaf.lightened(0.08))
	sph(t, "BlobB", Vector3(-r * 0.5, h * 0.66, -r * 0.3), r * 0.75, leaf.darkened(0.06))
	sph(t, "Top", Vector3(r * 0.1 * rng.randf_range(-1, 1), h * 0.98, 0), r * 0.6, leaf.lightened(0.12))
	return t


# --- field ---------------------------------------------------------------------

func _build_field() -> void:
	var root: Node3D = load("res://scenes/levels/field.tscn").instantiate()
	clear(root, ["Dressing", "Juice", "SkyRamp", "RimLight", "Fence/Pickets",
		"Tees/P1/Mat", "Tees/P2/Mat", "LawnChair/Seat", "LawnChair/Back", "LawnChair/Frame",
		"Clouds/P1/Cloud", "Clouds/P2/Cloud", "Clouds/P1/Puffy", "Clouds/P2/Puffy"])
	root.set_meta(&"_placeholder", null)
	root.set_meta(&"_art", "Art lane dressing built by art/tools/build_scenes.gd. Markers (Tees, Spawns, Sidelines, LawnChair, Clouds, PickSpots, EndSpot) belong to Gameplay.")

	# Environment: sky shader driven by SkyRamp, sky ambient, light fog, gentle glow. No SDFGI/SSAO/SSR.
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ShaderMaterial.new()
	sm.shader = load("res://art/shaders/sky.gdshader")
	sky.sky_material = sm
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	env.sky = sky
	env.background_color = Color(0.36, 0.66, 0.9)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.6
	env.ambient_light_sky_contribution = 0.85
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = 1.0
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = Color(0.75, 0.95, 1.0)
	env.fog_density = 0.0015
	env.fog_height = 25.0
	env.fog_height_density = 0.0
	env.fog_sky_affect = 0.0
	env.fog_aerial_perspective = 0.1
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_bloom = 0.03
	env.glow_hdr_threshold = 1.3
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.08
	env.adjustment_contrast = 1.06
	(root.get_node("Environment") as WorldEnvironment).environment = env

	# Key: one warm sun, soft PSSM shadows over a short range.
	var sun: DirectionalLight3D = root.get_node("Sun")
	sun.transform = Transform3D.IDENTITY
	sun.rotation = Vector3(deg_to_rad(-52), deg_to_rad(28), 0)
	sun.light_color = Color(1.0, 0.95, 0.86)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.shadow_blur = 2.0
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	sun.shadow_opacity = 0.75
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 40.0
	sun.directional_shadow_split_1 = 0.25
	sun.directional_shadow_fade_start = 0.8
	# Rim: a cool back light, no shadows. Lights characters' edges from behind the camera's view.
	var rim := DirectionalLight3D.new()
	rim.name = "RimLight"
	root.add_child(rim)
	rim.rotation = Vector3(deg_to_rad(-25), deg_to_rad(-120), 0)
	rim.light_color = Color(0.78, 0.88, 1.0)
	rim.light_energy = 0.55
	rim.light_specular = 0.6
	rim.shadow_enabled = false

	# Ground: striped lawn shader, kick line painted through the tees.
	var grass := ShaderMaterial.new()
	grass.shader = load("res://art/shaders/grass.gdshader")
	var ground: MeshInstance3D = root.get_node("Ground/Mesh")
	var plane := PlaneMesh.new()
	plane.size = Vector2(3000, 3000)
	ground.mesh = plane
	ground.position = Vector3(0, 0.5, 0)
	ground.material_override = grass
	ground.set_surface_override_material(0, null)

	# Tees: chunky orange rubber tee on a white mat.
	for p in ["P1", "P2"]:
		var tee: MeshInstance3D = root.get_node("Tees/%s/Tee" % p)
		tee.mesh = _mesh("cyl", 0.07, 0.13, 0.14)
		tee.set_surface_override_material(0, null)
		tee.material_override = mat(ORANGE, 0.5)
		tee.position = Vector3(0, 0.07, 0)
		mi(root.get_node("Tees/%s" % p), "Mat", _mesh("cyl", 0.3, 0.32, 0.03), mat(Color("3f8f5a"), 0.9, 0.0), Vector3(0, 0.015, 0))

	# Low white picket fence across the back of the lawn (the existing Fence node keeps its name).
	var fence: MeshInstance3D = root.get_node("Fence")
	fence.mesh = _mesh("box", 0.06, 0.08, 30.0)
	fence.set_surface_override_material(0, null)
	fence.material_override = mat(WHITE, 0.6)
	fence.position = Vector3(-6.4, 0.55, 0)
	var pickets := MultiMeshInstance3D.new()
	pickets.name = "Pickets"
	fence.add_child(pickets)
	pickets.position = Vector3(0, -0.55, 0)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _mesh("cap", 0.06, 0.85)
	mm.instance_count = 50
	for i in mm.instance_count:
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(1.0, 1.0, 0.6)), Vector3(0, 0.42, -14.7 + i * 0.6)))
	pickets.multimesh = mm
	pickets.material_override = mat(WHITE, 0.6)
	var rail2 := mi(fence, "RailLow", _mesh("box", 0.06, 0.08, 30.0), mat(WHITE, 0.6), Vector3(0, -0.3, 0))
	rail2.name = "RailLow"

	# Lawn chair: moved off the P2 sideline spot so a standing Chuck never stands in it. The kicker
	# sits facing the chair's local -X (main.gd: rotation.y = chair + PI/2).
	var chair: Node3D = root.get_node("LawnChair")
	chair.position = Vector3(1.9, 0, -4.4)
	chair.rotation = Vector3(0, deg_to_rad(200), 0)
	var fr := node(chair, "Frame")
	var tube := mat(Color("d9e2ec"), 0.3, 0.2)
	for z in [-0.32, 0.32]:
		mi(fr, "Leg%s" % z, _mesh("cyl", 0.025, 0.025, 0.5), tube, Vector3(-0.2, 0.17, z), Vector3(0, 0, deg_to_rad(-35)))
		mi(fr, "LegB%s" % z, _mesh("cyl", 0.025, 0.025, 0.5), tube, Vector3(0.2, 0.17, z), Vector3(0, 0, deg_to_rad(35)))
		mi(fr, "Arm%s" % z, _mesh("cap", 0.035, 0.6), tube, Vector3(-0.02, 0.55, z), Vector3(0, 0, PI / 2))
	var seat := mi(chair, "Seat", _mesh("box", 0.6, 0.06, 0.62), mat(SKY2, 0.85), Vector3(-0.05, 0.32, 0))
	var back := mi(chair, "Back", _mesh("box", 0.06, 0.75, 0.62), mat(SKY2, 0.85), Vector3(0.3, 0.68, 0), Vector3(0, 0, deg_to_rad(-14)))
	for i in 3:
		mi(seat, "Stripe%d" % i, _mesh("box", 0.6, 0.065, 0.08), mat(WHITE, 0.85), Vector3(0, 0, -0.2 + i * 0.2))
		mi(back, "Stripe%d" % i, _mesh("box", 0.065, 0.75, 0.08), mat(WHITE, 0.85), Vector3(0, 0, -0.2 + i * 0.2))

	# Finished-player clouds: puffy, flat enough to stand on.
	for p in ["P1", "P2"]:
		var cl := cloud(root.get_node("Clouds/%s" % p), "Puffy", Vector3(0, -0.45, 0), 0.75, 3 if p == "P1" else 5)
		cl.scale = Vector3(1.0, 0.7, 1.0)

	var dressing := node(root, "Dressing")
	_dress_backyard(dressing)
	_dress_trees(dressing)
	_dress_horizon(dressing)
	_dress_crowd(dressing)

	var ramp := Node.new()
	ramp.name = "SkyRamp"
	ramp.set_script(load("res://art/scripts/sky_ramp.gd"))
	root.add_child(ramp)
	ramp.set("environment", root.get_node("Environment"))

	var juice := Node3D.new()
	juice.name = "Juice"
	juice.set_script(load("res://art/scripts/juice.gd"))
	root.add_child(juice)
	var layer := CanvasLayer.new()
	layer.name = "SpeedLines"
	layer.layer = 0
	juice.add_child(layer)
	var rect := ColorRect.new()
	rect.name = "Rect"
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lm := ShaderMaterial.new()
	lm.shader = load("res://art/shaders/speed_lines.gdshader")
	rect.material = lm
	layer.add_child(rect)

	var director := Node.new()
	director.name = "ShotDirector"
	director.set_script(load("res://art/scripts/shot_director.gd"))
	juice.add_child(director)

	save(root, "res://scenes/levels/field.tscn")


func _dress_backyard(d: Node3D) -> void:
	# Tier 1 landmark lives on the lawn: a washing line behind the crowd.
	var wl := node(d, "WashingLine", Vector3(-10.5, 0, 0))
	for z in [-5.0, 5.0]:
		cyl(wl, "Pole%s" % z, Vector3(0, 1.1, z), 0.06, 0.07, 2.2, SLATE)
		cyl(wl, "Cross%s" % z, Vector3(0, 2.15, z), 0.04, 0.04, 0.8, SLATE, Vector3(PI / 2, 0, PI / 2))
	mi(wl, "Line", _mesh("cyl", 0.012, 0.012, 10.0), mat(ICE), Vector3(0, 2.1, 0), Vector3(PI / 2, 0, 0))
	var clothes := [[-3.6, "shirt", SKY2], [-1.8, "sock", PINK], [-1.0, "sock", ORANGE], [0.4, "towel", SKY4],
		[2.2, "shirt", YELLOW], [3.6, "sock", TEAL]]
	var i := 0
	for c in clothes:
		var hang := node(wl, "Peg%d" % i, Vector3(0, 2.1, c[0]))
		match c[1]:
			"shirt":
				box(hang, "Shirt", Vector3(0, -0.35, 0), Vector3(0.04, 0.6, 0.55), c[2])
				box(hang, "Sleeves", Vector3(0, -0.15, 0), Vector3(0.04, 0.2, 0.95), c[2])
			"sock":
				cap(hang, "Sock", Vector3(0, -0.25, 0), 0.07, 0.45, c[2])
				cap(hang, "Toe", Vector3(0, -0.45, 0.08), 0.07, 0.25, c[2], Vector3(PI / 2, 0, 0))
			"towel":
				box(hang, "Towel", Vector3(0, -0.45, 0), Vector3(0.03, 0.85, 0.7), c[2])
				box(hang, "Band", Vector3(0, -0.7, 0), Vector3(0.035, 0.08, 0.7), ICE)
		motion(hang, MOTION.Mode.SWAY, 0.12, 0.35 + i * 0.05, Vector3.FORWARD, i * 0.7)
		i += 1
	# Bunting over the crowd: pennants in palette pops.
	var bunt := node(d, "Bunting", Vector3(-7.0, 0, 0))
	for z in [-7.0, 7.0]:
		cyl(bunt, "Pole%s" % z, Vector3(0, 1.4, z), 0.05, 0.05, 2.8, WHITE)
	mi(bunt, "String", _mesh("cyl", 0.01, 0.01, 14.0), mat(ICE), Vector3(0, 2.6, 0), Vector3(PI / 2, 0, 0))
	var cols := [SKY2, YELLOW, WHITE, ORANGE, SKY4, SKY1, PINK]
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _mesh("prism", 0.36, 0.42, 0.02)
	mm.instance_count = 24
	for k in mm.instance_count:
		var z := -6.6 + k * (13.2 / 23.0)
		var sag := 0.25 * (1.0 - pow(z / 7.0, 2.0))
		mm.set_instance_transform(k, Transform3D(Basis(Vector3.RIGHT, PI).rotated(Vector3.UP, PI / 2), Vector3(0, 2.4 - sag, z)))
		mm.set_instance_color(k, cols[k % cols.size()])
	var flags := MultiMeshInstance3D.new()
	flags.name = "Pennants"
	flags.multimesh = mm
	var fm := StandardMaterial3D.new()
	fm.vertex_color_use_as_albedo = true
	fm.roughness = 0.8
	fm.cull_mode = BaseMaterial3D.CULL_DISABLED
	flags.material_override = fm
	bunt.add_child(flags)


func _dress_trees(d: Node3D) -> void:
	var trees := node(d, "Trees")
	var spots := [
		[Vector3(-17, 0, -9), 6.0], [Vector3(-20, 0, 1), 7.0], [Vector3(-16, 0, 10), 5.5],
		[Vector3(-26, 0, -3), 8.0], [Vector3(-24, 0, 14), 6.5], [Vector3(-12, 0, -16), 5.0],
		[Vector3(-4, 0, -20), 6.5], [Vector3(8, 0, -22), 7.0], [Vector3(18, 0, -12), 6.0],
		[Vector3(-8, 0, 24), 6.0], [Vector3(6, 0, 26), 7.5], [Vector3(20, 0, 16), 6.0],
		[Vector3(-30, 0, -16), 7.0], [Vector3(-34, 0, 8), 8.0],
	]
	var leaves := [LEAF_A, LEAF_B, LEAF_C]
	for i in spots.size():
		tree(trees, "Tree%02d" % i, spots[i][0], spots[i][1], leaves[i % 3], i)


func _dress_horizon(d: Node3D) -> void:
	var hills := node(d, "Hills")
	var hill_m := mat(Color("62b04e"), 1.0, 0.0)
	var hill_m2 := mat(Color("70bb56"), 1.0, 0.0)
	var spots := [
		[Vector3(-110, -14, -60), 60.0], [Vector3(-130, -18, 30), 70.0], [Vector3(-90, -10, 90), 45.0],
		[Vector3(40, -16, -130), 70.0], [Vector3(-40, -12, 120), 55.0], [Vector3(120, -18, 40), 70.0],
	]
	for i in spots.size():
		mi(hills, "Hill%d" % i, _mesh("sphere", 1.0, 32), hill_m if i % 2 == 0 else hill_m2, spots[i][0], Vector3.ZERO,
				Vector3(spots[i][1], spots[i][1] * 0.32, spots[i][1] * 0.8), false)
	var sky := node(d, "SkyClouds")
	var cspots := [Vector3(-80, 26, -40), Vector3(-95, 34, 25), Vector3(-70, 22, 60), Vector3(-30, 30, -80),
		Vector3(30, 28, 80), Vector3(60, 32, -60)]
	for i in cspots.size():
		var c := cloud(sky, "Cloud%d" % i, cspots[i], 6.0 + (i % 3) * 1.5, 40 + i)
		c.look_at_from_position(cspots[i], Vector3(0, cspots[i].y, 0))
		for m in c.get_children():
			(m as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _dress_crowd(d: Node3D) -> void:
	var crowd := node(d, "Crowd", Vector3(-7.4, 0, 0))
	crowd.set_script(load("res://art/scripts/crowd.gd"))
	var seeds := ["09", "01", "52", "72", "20"]
	var zs := [-5.2, -2.6, 0.3, 2.9, 5.6]
	for i in seeds.size():
		var j: Node3D = load("res://assets/models/crowd/jarling_%s.glb" % seeds[i]).instantiate()
		j.name = "Jarling%s" % seeds[i]
		crowd.add_child(j)
		j.position = Vector3(0.3 * (i % 2), 0, zs[i])
		j.rotation = Vector3(0, PI / 2 + (0.25 if zs[i] > 0 else -0.25), 0)
		j.scale = Vector3.ONE * 1.25


# --- frog ----------------------------------------------------------------------

func _build_frog() -> void:
	var root := Node3D.new()
	root.name = "Frog"
	root.add_to_group("frog", true)
	root.set_script(load("res://art/scripts/frog_dress.gd"))
	root.set_meta(&"_art", "Art lane frog (art/tools/build_scenes.gd). Jarling-style, faces -Z like the kicker. JeffHood / ChuckHat carry the exact player accents.")
	var skin := mi(root, "Skin", _mesh("sphere", 1.0), mat(FROG, 0.55, 0.45), Vector3(0, 0.36, 0), Vector3.ZERO, Vector3(0.48, 0.36, 0.44))
	sph(root, "Belly", Vector3(0, 0.3, -0.2), 1.0, FROG_BELLY, Vector3(0.36, 0.26, 0.28))
	var head := node(root, "Head", Vector3(0, 0.62, -0.08))
	for s in [-1, 1]:
		var e := node(head, "Eye%s" % ("L" if s < 0 else "R"), Vector3(0.2 * s, 0.08, -0.06))
		sph(e, "Bump", Vector3.ZERO, 0.15, FROG, Vector3.ONE, 0.55)
		sph(e, "White", Vector3(0, 0.02, -0.08), 0.12, WHITE, Vector3.ONE, 0.3)
		sph(e, "Pupil", Vector3(0, 0.02, -0.17), 0.065, INK, Vector3(1, 1.2, 0.6), 0.2)
		sph(e, "Shine", Vector3(-0.03 * s, 0.06, -0.205), 0.022, WHITE, Vector3.ONE, 0.1)
		sph(root, "Cheek%s" % s, Vector3(0.3 * s, 0.38, -0.32), 0.06, Color("ff9db8"), Vector3(1, 0.6, 0.4))
		# Back legs folded at the sides, front mitts.
		sph(root, "Thigh%s" % s, Vector3(0.38 * s, 0.2, 0.12), 1.0, FROG, Vector3(0.16, 0.16, 0.24))
		sph(root, "Foot%s" % s, Vector3(0.42 * s, 0.04, -0.12), 1.0, FROG.darkened(0.08), Vector3(0.12, 0.04, 0.18))
		sph(root, "Mitt%s" % s, Vector3(0.2 * s, 0.05, -0.36), 1.0, FROG.darkened(0.08), Vector3(0.09, 0.05, 0.1))
	mi(root, "Smile", _mesh("torus", 0.15, 0.18), mat(INK, 0.4, 0.0), Vector3(0, 0.42, -0.36), Vector3(deg_to_rad(80), 0, 0), Vector3(1.0, 1.0, 0.6))
	box(root, "SmileCover", Vector3(0, 0.47, -0.37), Vector3(0.4, 0.1, 0.12), FROG)

	# Jeff: a tiny chicken hood with a pink comb, orange beak brim and the green headband.
	var hood := node(root, "JeffHood", Vector3(0, 0.6, 0.06))
	mi(hood, "Hood", _mesh("hemi", 0.36), mat(YELLOW, 0.75), Vector3(0, 0.02, 0.04), Vector3(deg_to_rad(-20), 0, 0), Vector3(1.05, 0.9, 1.0))
	mi(hood, "Headband", _mesh("torus", 0.33, 0.39), mat(P1_GREEN, 0.6), Vector3(0, 0.04, 0.03), Vector3(deg_to_rad(-20), 0, 0), Vector3(1.05, 0.6, 1.0))
	for k in 3:
		sph(hood, "Comb%d" % k, Vector3(0, 0.36 - abs(k - 1) * 0.05, 0.02 + (k - 1) * 0.1), 0.07, Color("d63384"))
	mi(hood, "Beak", _mesh("prism", 0.16, 0.12, 0.1), mat(ORANGE, 0.5), Vector3(0, 0.24, -0.3), Vector3(deg_to_rad(-90), 0, 0))
	sph(hood, "TailFeather", Vector3(0, 0.0, 0.42), 1.0, YELLOW, Vector3(0.06, 0.14, 0.06))

	# Chuck: trucker hat (near-black crown, red brim and piping, yellow patch).
	var hat := node(root, "ChuckHat", Vector3(0, 0.78, 0.0), Vector3(deg_to_rad(-8), 0, 0))
	mi(hat, "Crown", _mesh("hemi", 0.3), mat(HAT_BLACK, 0.7), Vector3.ZERO, Vector3.ZERO, Vector3(1.0, 0.85, 1.0))
	mi(hat, "Piping", _mesh("torus", 0.285, 0.315), mat(P2_RED, 0.6), Vector3(0, 0.01, 0), Vector3.ZERO, Vector3(1, 0.5, 1))
	mi(hat, "Brim", _mesh("cyl", 0.2, 0.2, 0.025), mat(P2_RED, 0.6), Vector3(0, 0.0, -0.32), Vector3(deg_to_rad(-6), 0, 0), Vector3(1.25, 1, 1.0))
	box(hat, "Patch", Vector3(0, 0.13, -0.24), Vector3(0.22, 0.13, 0.02), YELLOW, Vector3(deg_to_rad(-35), 0, 0))
	save(root, "res://scenes/curses/frog.tscn")


# --- landmarks -----------------------------------------------------------------
# height_ladder places each at (0, visual_y(threshold), 0). The camera follows the ball from the +X
# side, so the landmarks sit mostly at -X (behind the ball) and off to the sides, scaled up with height
# because the camera zooms out with speed.

func _landmark(id: String) -> Node3D:
	var r := Node3D.new()
	r.name = id.capitalize().replace(" ", "")
	r.set_meta(&"_art", "Tier landmark %s (art/tools/build_scenes.gd)." % id)
	return r


func _build_landmarks() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://scenes/levels/landmarks"))
	_lm_rooftops()
	_lm_treetops()
	_lm_kites()
	_lm_clouds()
	_lm_thin_air()
	_lm_edge()
	_lm_space()


func house(parent: Node, n: String, pos: Vector3, w: float, wall: Color, roof: Color, rot_y := 0.0) -> Node3D:
	# Ridge at local y = 1.5 (just above the rooftops threshold); walls reach the lawn at y = -4.
	var h := node(parent, n, pos, Vector3(0, rot_y, 0))
	box(h, "Walls", Vector3(0, -2.5, 0), Vector3(w, 3.0, 4.0), wall)
	mi(h, "Roof", _mesh("prism", w + 0.6, 2.4, 4.6), mat(roof, 0.75), Vector3(0, 0.2, 0), Vector3(0, PI / 2, 0), Vector3(4.6 / (w + 0.6), 1, (w + 0.6) / 4.6))
	box(h, "Chimney", Vector3(w * 0.25, 1.1, 0.8), Vector3(0.6, 1.6, 0.6), PEACH.darkened(0.25))
	box(h, "ChimneyTop", Vector3(w * 0.25, 1.95, 0.8), Vector3(0.75, 0.15, 0.75), SLATE)
	for k in 2:
		var wz := -1.0 + k * 2.0
		box(h, "Window%d" % k, Vector3(w * 0.5 + 0.01, -2.3, wz), Vector3(0.05, 1.0, 0.9), SKY1)
		box(h, "Frame%d" % k, Vector3(w * 0.5 + 0.02, -2.3, wz), Vector3(0.05, 1.1, 0.12), WHITE)
	box(h, "Door", Vector3(w * 0.5 + 0.01, -3.3, 0), Vector3(0.05, 1.4, 0.8), PLUM)
	return h


func cat(parent: Node, n: String, pos: Vector3, rot_y: float) -> Node3D:
	var c := node(parent, n, pos, Vector3(0, rot_y, 0), Vector3.ONE * 1.3)
	var fur := ORANGE
	sph(c, "Body", Vector3(0, 0.22, 0), 1.0, fur, Vector3(0.22, 0.2, 0.3))
	var head := node(c, "Head", Vector3(0, 0.5, 0.22))
	sph(head, "Skull", Vector3.ZERO, 0.2, fur)
	for s in [-1, 1]:
		mi(head, "Ear%s" % s, _mesh("prism", 0.12, 0.16, 0.06), mat(fur), Vector3(0.11 * s, 0.2, -0.02), Vector3(0, 0, -0.25 * s))
		sph(head, "Eye%s" % s, Vector3(0.08 * s, 0.03, 0.16), 0.065, WHITE, Vector3.ONE, 0.2)
		sph(head, "Pupil%s" % s, Vector3(0.08 * s, 0.03, 0.215), 0.025, INK, Vector3.ONE, 0.2)
		cap(c, "Leg%s" % s, Vector3(0.1 * s, 0.07, 0.12), 0.05, 0.22, fur.lightened(0.15))
	sph(head, "Mouth", Vector3(0, -0.08, 0.18), 0.035, INK, Vector3(1, 1.3, 0.5))
	sph(head, "Muzzle", Vector3(0, -0.04, 0.17), 0.06, ICE, Vector3(1.3, 0.8, 0.6))
	var tail := cap(c, "Tail", Vector3(0, 0.5, -0.28), 0.045, 0.6, fur)
	tail.rotation = Vector3(deg_to_rad(-15), 0, 0)
	for k in 3:
		box(c, "Stripe%d" % k, Vector3(0, 0.39, -0.1 + k * 0.1), Vector3(0.2, 0.04, 0.04), fur.darkened(0.25))
	motion(c, MOTION.Mode.HOP, 0.35, 0.9)
	return c


func _lm_rooftops() -> void:
	var r := _landmark("rooftops")
	house(r, "HouseA", Vector3(-17, 0, -7.5), 6.0, PEACH, SLATE)
	house(r, "HouseB", Vector3(-19, -0.8, 6.0), 5.0, ICE, PLUM)
	house(r, "HouseC", Vector3(-6, -1.2, -21.0), 5.0, Color("ffe6a8"), SKY3, PI / 2)
	cat(r, "StartledCat", Vector3(-15.0, 1.35, -6.2), PI / 2 - 0.4).scale = Vector3.ONE * 2.2
	save(r, "res://scenes/levels/landmarks/rooftops.tscn")


func bird(parent: Node, n: String, pos: Vector3, c: Color, phase: float) -> Node3D:
	var pivot := node(parent, n + "Orbit", Vector3.ZERO)
	var b := node(pivot, n, pos, Vector3(0, PI / 2, 0), Vector3.ONE * 1.6)
	sph(b, "Body", Vector3.ZERO, 1.0, c, Vector3(0.18, 0.16, 0.26))
	sph(b, "Head", Vector3(0, 0.1, 0.2), 0.12, c)
	mi(b, "Beak", _mesh("prism", 0.06, 0.1, 0.06), mat(ORANGE), Vector3(0, 0.08, 0.34), Vector3(PI / 2, 0, 0))
	for s in [-1, 1]:
		sph(b, "Eye%s" % s, Vector3(0.07 * s, 0.14, 0.29), 0.025, INK)
		var wing := node(b, "Wing%s" % s, Vector3(0.12 * s, 0.05, 0))
		sph(wing, "Feathers", Vector3(0.18 * s, 0, 0), 1.0, c.lightened(0.15), Vector3(0.22, 0.04, 0.14))
		motion(wing, MOTION.Mode.FLAP, 0.7 * s, 3.0, Vector3.FORWARD, phase)
	motion(pivot, MOTION.Mode.ORBIT, 0.0, 0.08, Vector3.UP, phase)
	return pivot


func _lm_treetops() -> void:
	var r := _landmark("treetops")
	var spots := [[Vector3(-22, -14, -10), 17.0, LEAF_A], [Vector3(-26, -14, 6), 18.0, LEAF_C],
		[Vector3(-12, -14, 18), 15.0, LEAF_B]]
	for i in spots.size():
		tree(r, "TallTree%d" % i, spots[i][0], spots[i][1], spots[i][2], 100 + i)
	var cols := [SKY2, YELLOW, PINK, SKY1]
	for i in 4:
		var a := TAU * i / 4.0
		var b := bird(r, "Bird%d" % i, Vector3(cos(a) * 4.5, 1.0 + (i % 2) * 1.2, sin(a) * 6.0), cols[i], i * 0.25)
		b.position = Vector3(-11, 0, 0)
	save(r, "res://scenes/levels/landmarks/treetops.tscn")


func kite(parent: Node, n: String, pos: Vector3, a: Color, b: Color, s: float) -> Node3D:
	var k := node(parent, n, pos, Vector3(0, PI / 2, 0), Vector3.ONE * s)
	var sail := node(k, "Sail", Vector3.ZERO, Vector3(0, 0, PI / 4), Vector3(1, 1.4, 1))
	box(sail, "Q1", Vector3(-0.25, 0.25, 0), Vector3(0.5, 0.5, 0.04), a)
	box(sail, "Q2", Vector3(0.25, 0.25, 0), Vector3(0.5, 0.5, 0.04), b)
	box(sail, "Q3", Vector3(-0.25, -0.25, 0), Vector3(0.5, 0.5, 0.04), b)
	box(sail, "Q4", Vector3(0.25, -0.25, 0), Vector3(0.5, 0.5, 0.04), a)
	for i in 5:
		var bow := sph(k, "Bow%d" % i, Vector3(0.1 * sin(i * 1.3), -1.1 - i * 0.35, 0), 0.08, [PINK, YELLOW, SKY2][i % 3], Vector3(1.6, 0.8, 0.8))
		bow.name = "Bow%d" % i
	mi(k, "Tail", _mesh("cyl", 0.008, 0.008, 1.8), mat(ICE), Vector3(0, -1.6, 0))
	mi(k, "String", _mesh("cyl", 0.01, 0.01, 6.0), unshaded(Color(1, 1, 1, 0.6)), Vector3(0, -4.0, 0.0), Vector3(0, 0, 0.35), Vector3.ONE, false)
	motion(k, MOTION.Mode.SWAY, 0.18, 0.4, Vector3.RIGHT)
	return k


func balloon(parent: Node, n: String, pos: Vector3, r: float) -> Node3D:
	var b := node(parent, n, pos)
	var sm := ShaderMaterial.new()
	sm.shader = load("res://art/shaders/stripes.gdshader")
	sm.set_shader_parameter(&"color_a", ORANGE)
	sm.set_shader_parameter(&"color_b", YELLOW)
	sm.set_shader_parameter(&"color_c", PINK)
	mi(b, "Envelope", _mesh("sphere", 1.0, 32), sm, Vector3.ZERO, Vector3.ZERO, Vector3(r, r * 1.15, r))
	mi(b, "Skirt", _mesh("cyl", r * 0.35, r * 0.2, r * 0.5), sm, Vector3(0, -r * 1.2, 0))
	box(b, "Basket", Vector3(0, -r * 1.75, 0), Vector3(r * 0.4, r * 0.32, r * 0.4), BARK)
	box(b, "Rim", Vector3(0, -r * 1.58, 0), Vector3(r * 0.44, r * 0.05, r * 0.44), BARK.darkened(0.2))
	for s in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		mi(b, "Rope%s" % s, _mesh("cyl", 0.04, 0.04, r * 0.4), mat(SLATE), Vector3(s.x * r * 0.18, -r * 1.42, s.y * r * 0.18))
	motion(b, MOTION.Mode.BOB, r * 0.12, 0.15)
	return b


func _lm_kites() -> void:
	var r := _landmark("kites")
	kite(r, "KiteA", Vector3(-10, -2, -7), PINK, YELLOW, 2.2)
	kite(r, "KiteB", Vector3(-15, 4, 6), SKY2, ORANGE, 2.6)
	kite(r, "KiteC", Vector3(-7, 7, 10), TEAL, ICE, 1.8)
	balloon(r, "HotAirBalloon", Vector3(-26, 3, -12), 6.0)
	save(r, "res://scenes/levels/landmarks/kites.tscn")


func plane(parent: Node, n: String, pos: Vector3, s: float) -> Node3D:
	var fly := node(parent, n + "Path", pos)
	var p := node(fly, n, Vector3.ZERO, Vector3.ZERO, Vector3.ONE * s)
	cap(p, "Body", Vector3.ZERO, 0.35, 2.6, ICE, Vector3(PI / 2, 0, 0))
	cap(p, "Stripe", Vector3(0, 0.0, 0), 0.355, 2.2, SKY3, Vector3(PI / 2, 0, 0)).scale = Vector3(1, 1, 0.3)
	box(p, "Wings", Vector3(0, -0.05, 0.1), Vector3(3.4, 0.08, 0.6), ICE)
	box(p, "TailWing", Vector3(0, 0.05, -1.1), Vector3(1.2, 0.06, 0.35), ICE)
	box(p, "Fin", Vector3(0, 0.4, -1.1), Vector3(0.06, 0.6, 0.4), SKY3)
	sph(p, "Cockpit", Vector3(0, 0.2, 0.7), 0.25, SKY1, Vector3(1, 0.8, 1.4), 0.15)
	sph(p, "Nose", Vector3(0, 0, 1.35), 0.12, ORANGE)
	var prop := node(p, "Prop", Vector3(0, 0, 1.45))
	box(prop, "Blade", Vector3.ZERO, Vector3(1.1, 0.12, 0.04), SLATE)
	motion(prop, MOTION.Mode.SPIN, 0.0, 6.0, Vector3.FORWARD)
	motion(fly, MOTION.Mode.FLY, 70.0, 0.06, Vector3.BACK)
	return fly


func _lm_clouds() -> void:
	var r := _landmark("clouds")
	var rng := RandomNumberGenerator.new()
	rng.seed = 350
	var spots := [Vector3(-14, -2, -10), Vector3(-20, 1, 4), Vector3(-12, -4, 12), Vector3(-30, 3, -2),
		Vector3(-26, -3, 18), Vector3(-34, -1, -18), Vector3(4, -6, -24), Vector3(10, -5, 22),
		Vector3(-8, 4, -22), Vector3(-44, 5, 10)]
	for i in spots.size():
		cloud(r, "Cloud%d" % i, spots[i], rng.randf_range(4.0, 7.0), 350 + i)
	plane(r, "Plane", Vector3(-22, 6, 0), 2.6)
	save(r, "res://scenes/levels/landmarks/clouds.tscn")


func _lm_thin_air() -> void:
	var r := _landmark("thin_air")
	var fly := node(r, "JetPath", Vector3(-40, 8, 0))
	var jet := node(fly, "Jet", Vector3.ZERO, Vector3.ZERO, Vector3.ONE * 4.0)
	cap(jet, "Body", Vector3.ZERO, 0.3, 3.2, ICE, Vector3(PI / 2, 0, 0))
	mi(jet, "Wings", _mesh("box", 3.6, 0.06, 0.7), mat(ICE), Vector3(0, -0.05, -0.1), Vector3(0, 0, 0))
	box(jet, "Fin", Vector3(0, 0.45, -1.3), Vector3(0.06, 0.8, 0.5), SKY4)
	box(jet, "Tail", Vector3(0, 0.05, -1.35), Vector3(1.3, 0.05, 0.35), ICE)
	sph(jet, "Window", Vector3(0, 0.15, 1.1), 0.18, SKY3, Vector3(1, 0.7, 1.4), 0.15)
	mi(jet, "Contrail", _mesh("cap", 0.12, 14.0), unshaded(Color(1, 1, 1, 0.55)), Vector3(0, 0, -8.5), Vector3(PI / 2, 0, 0), Vector3.ONE, false)
	motion(fly, MOTION.Mode.FLY, 90.0, 0.05, Vector3.FORWARD)
	# The lost party balloon drifting up with the ball.
	var lost := node(r, "PartyBalloon", Vector3(-7, 1.5, -5))
	sph(lost, "Balloon", Vector3.ZERO, 1.0, PINK, Vector3(1.6, 1.9, 1.6), 0.25)
	sph(lost, "Shine", Vector3(-0.6, 0.7, 0.9), 0.3, Color(1, 0.85, 0.97), Vector3(0.8, 1.2, 0.5), 0.1)
	mi(lost, "Knot", _mesh("prism", 0.35, 0.3, 0.35), mat(PINK), Vector3(0, -1.95, 0), Vector3(PI, 0, 0))
	for k in 6:
		mi(lost, "String%d" % k, _mesh("cyl", 0.025, 0.025, 0.7), mat(ICE), Vector3(0.18 * sin(k * 1.4), -2.4 - k * 0.6, 0), Vector3(0, 0, 0.35 * sin(k * 1.4 + 0.7)))
	motion(lost, MOTION.Mode.BOB, 0.8, 0.2)
	save(r, "res://scenes/levels/landmarks/thin_air.tscn")


func _lm_edge() -> void:
	var r := _landmark("edge")
	var am := ShaderMaterial.new()
	am.shader = load("res://art/shaders/aurora.gdshader")
	for i in 4:
		var a := deg_to_rad(-40 + i * 27)
		var pos := Vector3(-80 * cos(a), 34 + (i % 2) * 8, 80 * sin(a))
		var q := mi(r, "Aurora%d" % i, _mesh("quad", 55.0, 24.0), am, pos, Vector3(0, PI / 2 - a, 0), Vector3.ONE, false)
		q.rotation.y = atan2(pos.x, pos.z) + PI
	var sat := node(r, "Satellite", Vector3(-14, 3, -6), Vector3(0.3, 0.4, 0.2), Vector3.ONE * 2.6)
	box(sat, "Body", Vector3.ZERO, Vector3(1.0, 1.0, 1.3), YELLOW)
	box(sat, "Band", Vector3.ZERO, Vector3(1.05, 0.2, 1.35), SLATE)
	for s in [-1, 1]:
		cyl(sat, "Arm%s" % s, Vector3(0.9 * s, 0, 0), 0.04, 0.04, 0.8, SLATE, Vector3(0, 0, PI / 2))
		var panel := box(sat, "Panel%s" % s, Vector3(2.1 * s, 0, 0), Vector3(1.8, 0.05, 1.0), SKY3)
		for g in 3:
			box(panel, "Grid%d" % g, Vector3(-0.6 + g * 0.6, 0.03, 0), Vector3(0.04, 0.02, 1.0), ICE)
	mi(sat, "Dish", _mesh("hemi", 0.5), mat(ICE, 0.4), Vector3(0, 0.75, 0), Vector3(PI, 0, 0), Vector3(1, 0.5, 1))
	cyl(sat, "Antenna", Vector3(0, 1.1, 0), 0.02, 0.02, 0.6, SLATE)
	sph(sat, "Blink", Vector3(0, 1.42, 0), 0.07, PINK)
	motion(sat, MOTION.Mode.SPIN, 0.0, 0.05, Vector3(0.3, 1, 0.2))
	save(r, "res://scenes/levels/landmarks/edge.tscn")


func _lm_space() -> void:
	var r := _landmark("space")
	var moon := node(r, "Moon", Vector3(-140, 60, 45))
	sph(moon, "Surface", Vector3.ZERO, 1.0, Color("c9d0e6"), Vector3.ONE * 16.0, 1.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 8
	for i in 9:
		var d := Vector3(rng.randf_range(0.2, 1.0), rng.randf_range(-0.7, 0.7), rng.randf_range(-0.2, 0.9)).normalized()
		var cr := sph(moon, "Crater%d" % i, d * 15.5, 1.0, SLATE, Vector3.ONE, 1.0)
		cr.scale.x *= 0.35
		cr.look_at_from_position(cr.position, Vector3.ZERO)
		cr.scale = Vector3(rng.randf_range(1.5, 3.2), rng.randf_range(1.5, 3.2), 0.6)
	# Saucer with a waving alien (generic: green-teal, three eyes, antennae).
	var ufo := node(r, "Saucer", Vector3(-16, 3.0, -4), Vector3(0, PI / 2 - 0.25, 0), Vector3.ONE * 4.5)
	sph(ufo, "Hull", Vector3.ZERO, 1.0, SLATE.lightened(0.2), Vector3(1.4, 0.32, 1.4), 0.3)
	mi(ufo, "Ring", _mesh("torus", 1.25, 1.42), mat(SKY4, 0.4), Vector3.ZERO, Vector3.ZERO, Vector3(1, 0.6, 1))
	for k in 6:
		var a := TAU * k / 6.0
		mi(ufo, "Light%d" % k, _mesh("sphere", 0.09), unshaded([YELLOW, PINK, SKY1][k % 3]), Vector3(cos(a) * 1.33, 0.0, sin(a) * 1.33))
	var alien := node(ufo, "Alien", Vector3(0, 0.25, 0))
	sph(alien, "Torso", Vector3(0, 0.25, 0), 1.0, TEAL, Vector3(0.28, 0.32, 0.26))
	var head := node(alien, "Head", Vector3(0, 0.8, 0))
	sph(head, "Skull", Vector3.ZERO, 0.38, TEAL)
	for e in [-1, 0, 1]:
		sph(head, "Eye%d" % e, Vector3(0.15 * e, 0.06 + (0.08 if e == 0 else 0.0), 0.32), 0.09, WHITE, Vector3.ONE, 0.2)
		sph(head, "Pupil%d" % e, Vector3(0.15 * e, 0.06 + (0.08 if e == 0 else 0.0), 0.4), 0.045, INK, Vector3.ONE, 0.2)
	sph(head, "Smile", Vector3(0, -0.14, 0.33), 0.06, INK, Vector3(1.8, 0.6, 0.5))
	for s in [-1, 1]:
		cyl(head, "Stalk%s" % s, Vector3(0.14 * s, 0.45, 0), 0.02, 0.02, 0.35, TEAL.darkened(0.2), Vector3(0, 0, -0.3 * s))
		sph(head, "Bulb%s" % s, Vector3(0.2 * s, 0.63, 0), 0.07, PINK)
	var arm := node(alien, "WaveArm", Vector3(0.28, 0.4, 0))
	cap(arm, "Arm", Vector3(0.0, 0.25, 0), 0.07, 0.5, TEAL)
	sph(arm, "Mitt", Vector3(0.0, 0.52, 0), 0.1, TEAL.lightened(0.1))
	arm.rotation = Vector3(0, 0, -0.5)
	motion(arm, MOTION.Mode.WAVE, 0.5, 1.6, Vector3.FORWARD)
	cap(alien, "OtherArm", Vector3(-0.3, 0.25, 0), 0.07, 0.4, TEAL, Vector3(0, 0, -0.4))
	mi(ufo, "Dome", _mesh("hemi", 0.7), _glass(), Vector3(0, 0.18, 0), Vector3.ZERO, Vector3(1, 1.4, 1), false)
	motion(ufo, MOTION.Mode.BOB, 0.25, 0.35)
	save(r, "res://scenes/levels/landmarks/space.tscn")


func _glass() -> StandardMaterial3D:
	var g := StandardMaterial3D.new()
	g.albedo_color = Color(0.8, 0.95, 1.0, 0.28)
	g.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	g.roughness = 0.05
	g.metallic_specular = 0.9
	g.rim_enabled = true
	g.rim = 0.8
	return g
