## Builds the Sky lane's object scenes (scenes/sky/*.tscn) from Godot primitives: smooth-shaded,
## flat palette colours, rim light, like the landmarks (art/tools/build_scenes.gd). Re-run after editing:
##   godot-render --path . -s scenes/sky/build_sky.gd      (headless works too: no MultiMesh here)
## Every value here is the source of truth for those scenes; hand edits in the .tscn get overwritten.
## Each root is a SkyObject (scenes/sky/sky_object.gd): Root > Gag > parts, about 2 units across.
extends SceneTree

const MOTION := preload("res://art/scripts/landmark_motion.gd")
const SKY_OBJECT := preload("res://scenes/sky/sky_object.gd")
const R := SKY_OBJECT.Reaction
## landmark_motion.gd modes
const BOB := 0
const SPIN := 1
const FLY := 4
const WAVE := 5
const FLAP := 6
const SWAY := 7

# Palette: C Cool Arcade (art/palettes/cool_arcade.json) plus a few naturals.
const INK := Color("0a0a14")
const ICE := Color("eef8ff")
const SLATE := Color("8e9cc0")
const SKY1 := Color("86f6ff")
const SKY2 := Color("38c6ff")
const SKY3 := Color("3d8bff")
const SKY4 := Color("7a6cff")
const TEAL := Color("1cc9a6")
const PLUM := Color("9c5e9e")
const PEACH := Color("ffbfa0")
const ORANGE := Color("ff9f2e")
const PINK := Color("ff4fd8")
const YELLOW := Color("ffd84d")
const WHITE := Color("fbfbf7")
const BARK := Color("8a5a2b")
const LEAF := Color("4cb86a")
const BRICK := Color("d9603b")
const GREY := Color("a9adbd")
const ALIEN := Color("9be564")
## Plane trim: blue, never the players' green or red.
const TRIM := Color("2f6bff")

var _mats := {}
var _meshes := {}


func _init() -> void:
	_kite()
	_bird()
	_laundry()
	_cat_chimney()
	_pigeons()
	_flock()
	_squirrel()
	_party_balloons()
	_hot_air_balloon()
	_blimp()
	_prop_plane()
	_bounce_cloud()
	_jet()
	_balloon_bunch()
	_satellite()
	_weather_balloon()
	_saucer()
	_moon()
	_comet()
	_data()
	print("BUILD_SKY_OK")
	quit()


# --- helpers -------------------------------------------------------------------

func mat(c: Color, rough := 0.7, rim := 0.35, glow := 0.0) -> StandardMaterial3D:
	var key := "%s/%s/%s/%s" % [c.to_html(), rough, rim, glow]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = rough
		if c.a < 1.0:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		if rim > 0.0:
			m.rim_enabled = true
			m.rim = rim
			m.rim_tint = 0.3
		if glow > 0.0:
			m.emission_enabled = true
			m.emission = c
			m.emission_energy_multiplier = glow
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
			s.radial_segments = 32
			s.rings = 16
			m = s
		"hemi":
			var s := SphereMesh.new()
			s.radius = a
			s.height = a
			s.is_hemisphere = true
			s.radial_segments = 32
			s.rings = 10
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


func mi(parent: Node, n: String, mesh: Mesh, m: Material, pos := Vector3.ZERO, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var x := MeshInstance3D.new()
	x.name = n
	x.mesh = mesh
	x.material_override = m
	x.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # nothing below to shadow up here
	parent.add_child(x)
	x.position = pos
	x.rotation = rot
	x.scale = scl
	return x


func sph(p: Node, n: String, pos: Vector3, r: float, c: Color, scl := Vector3.ONE, glow := 0.0) -> MeshInstance3D:
	return mi(p, n, _mesh("sphere", r), mat(c, 0.7, 0.35, glow), pos, Vector3.ZERO, scl)


func cyl(p: Node, n: String, pos: Vector3, rt: float, rb: float, h: float, c: Color, rot := Vector3.ZERO) -> MeshInstance3D:
	return mi(p, n, _mesh("cyl", rt, rb, h), mat(c), pos, rot)


func box(p: Node, n: String, pos: Vector3, size: Vector3, c: Color, rot := Vector3.ZERO) -> MeshInstance3D:
	return mi(p, n, _mesh("box", size.x, size.y, size.z), mat(c), pos, rot)


func cap(p: Node, n: String, pos: Vector3, r: float, h: float, c: Color, rot := Vector3.ZERO) -> MeshInstance3D:
	return mi(p, n, _mesh("cap", r, h), mat(c), pos, rot)


func motion(n: Node3D, mode: int, amount: float, speed: float, axis := Vector3.UP, phase := 0.0) -> Node3D:
	n.set_script(MOTION)
	n.set("mode", mode)
	n.set("amount", amount)
	n.set("speed", speed)
	n.set("axis", axis)
	n.set("phase", phase)
	return n


## The root: a SkyObject with its reaction, cue and reach, and its Gag pivot.
func root(n: String, reaction: int, cue: String, hit_radius: float, extra := {}) -> Array:
	var r := Node3D.new()
	r.name = n
	r.set_script(SKY_OBJECT)
	r.set("reaction", reaction)
	r.set("cue", StringName(cue))
	r.set("hit_radius", hit_radius)
	for k in extra:
		r.set(k, extra[k])
	var gag := node(r, "Gag")
	return [r, gag]


## Two dot eyes and a smile on a face looking along +Z (scaled by `s`).
func face(p: Node, at: Vector3, s := 1.0) -> void:
	sph(p, "EyeL", at + Vector3(-0.09, 0.05, 0) * s, 0.04 * s, INK)
	sph(p, "EyeR", at + Vector3(0.09, 0.05, 0) * s, 0.04 * s, INK)
	mi(p, "Smile", _mesh("torus", 0.07 * s, 0.09 * s), mat(INK), at + Vector3(0, -0.03, 0) * s,
			Vector3(PI / 2, 0, 0), Vector3(1, 1, 0.5))


## A round bird looking along +Z with flapping wings. Returns the bird node (no motion on it).
func bird(p: Node, n: String, pos: Vector3, body: Color, s := 1.0, phase := 0.0) -> Node3D:
	var b := node(p, n, pos, Vector3.ZERO, Vector3.ONE * s)
	sph(b, "Body", Vector3.ZERO, 0.3, body, Vector3(1, 0.9, 1.2))
	sph(b, "Belly", Vector3(0, -0.06, 0.12), 0.22, WHITE, Vector3(1, 0.8, 1))
	sph(b, "Head", Vector3(0, 0.25, 0.25), 0.2, body)
	mi(b, "Beak", _mesh("cyl", 0.0, 0.07, 0.18), mat(ORANGE), Vector3(0, 0.24, 0.48), Vector3(PI / 2, 0, 0))
	sph(b, "EyeL", Vector3(-0.1, 0.32, 0.4), 0.04, INK)
	sph(b, "EyeR", Vector3(0.1, 0.32, 0.4), 0.04, INK)
	for side in [-1.0, 1.0]:
		var w := motion(node(b, "Wing%s" % ("L" if side < 0 else "R"), Vector3(side * 0.25, 0.05, 0)),
				FLAP, 0.7, 3.0, Vector3(0, 0, side), phase)
		sph(w, "Feather", Vector3(side * 0.3, 0, 0), 0.22, body, Vector3(1.6, 0.3, 1.0))
	mi(b, "Tail", _mesh("prism", 0.3, 0.25, 0.06), mat(body), Vector3(0, 0.05, -0.38), Vector3(-PI / 2.4, 0, 0))
	return b


func balloon(p: Node, n: String, pos: Vector3, c: Color, r := 0.35) -> Node3D:
	var b := node(p, n, pos)
	sph(b, "Rubber", Vector3.ZERO, r, c, Vector3(1, 1.18, 1))
	sph(b, "Shine", Vector3(-r * 0.4, r * 0.45, r * 0.6), r * 0.16, WHITE)
	mi(b, "Knot", _mesh("cyl", 0.02, r * 0.18, r * 0.2), mat(c), Vector3(0, -r * 1.22, 0))
	return b


func string_to(p: Node, n: String, a: Vector3, b: Vector3, c := WHITE, r := 0.012) -> void:
	var d := b - a
	var m := mi(p, n, _mesh("cyl", r, r, d.length()), mat(c, 0.7, 0.0), (a + b) * 0.5)
	m.basis = Basis(Quaternion(Vector3.UP, d.normalized()))


func save(r: Node, file: String) -> void:
	_own(r, r)
	var ps := PackedScene.new()
	assert(ps.pack(r) == OK)
	var path := "res://scenes/sky/%s.tscn" % file
	if ResourceSaver.save(ps, path) != OK:
		push_error("save failed %s" % path)
	print("saved ", path)
	r.free()


func _own(n: Node, r: Node) -> void:
	for c in n.get_children():
		c.owner = r
		_own(c, r)


# --- backyard ------------------------------------------------------------------

func _kite() -> void:
	var a := root("Kite", R.SNAG, "sky_twang", 0.8, {spin = 30.0, push = 2.0, hold = 0.2, shake = 0.06,
			puff_color = Color(1, 0.8, 0.9)})
	var k := motion(node(a[1], "Kite"), SWAY, 0.25, 0.6, Vector3(0, 0, 1))
	mi(k, "SailA", _mesh("prism", 0.9, 0.7, 0.05), mat(PINK), Vector3(0, 0.35, 0))
	mi(k, "SailB", _mesh("prism", 0.9, 0.7, 0.05), mat(YELLOW), Vector3(0, -0.35, 0), Vector3(0, 0, PI))
	box(k, "Spar", Vector3.ZERO, Vector3(0.9, 0.04, 0.07), BARK)
	face(k, Vector3(0, 0.25, 0.05), 1.6)
	for i in 4:
		var y := -0.85 - i * 0.28
		mi(k, "Bow%d" % i, _mesh("prism", 0.22, 0.12, 0.05), mat([SKY2, ORANGE][i % 2]),
				Vector3(sin(i * 1.3) * 0.08, y, 0), Vector3(0, 0, PI / 2))
	string_to(k, "Tail", Vector3(0, -0.7, 0), Vector3(0.1, -1.9, 0), WHITE, 0.008)
	string_to(a[1], "String", Vector3(0, -0.7, 0), Vector3(0.6, -4.5, 0.5), WHITE, 0.01)
	save(a[0], "kite")


func _bird() -> void:
	var a := root("Bird", R.SCATTER, "sky_flutter", 0.6, {push = 1.5, hold = 0.06, shake = 0.04,
			near_radius = 2.2, near_cue = &"squawk", near_pitch = 1.3, drift = Vector3(0, 0, 0.5)})
	bird(a[1], "Bird1", Vector3.ZERO, SKY2, 1.2)   # Bird* sit right under Gag so they scatter
	save(a[0], "bird")


func _laundry() -> void:
	var a := root("Laundry", R.SNAG, "sky_flap", 0.8, {spin = 20.0, push = 2.0, hold = 0.12, shake = 0.04})
	var line := motion(node(a[1], "Line"), SWAY, 0.12, 0.8, Vector3(1, 0, 0))
	string_to(line, "Rope", Vector3(-1.1, 0.4, 0), Vector3(1.1, 0.4, 0), WHITE, 0.015)
	var shirt := motion(node(line, "Shirt", Vector3(-0.35, 0.4, 0)), SWAY, 0.25, 1.6, Vector3(1, 0, 0))
	box(shirt, "Body", Vector3(0, -0.35, 0), Vector3(0.55, 0.6, 0.05), SKY2)
	box(shirt, "SleeveL", Vector3(-0.38, -0.15, 0), Vector3(0.28, 0.2, 0.05), SKY2, Vector3(0, 0, 0.5))
	box(shirt, "SleeveR", Vector3(0.38, -0.15, 0), Vector3(0.28, 0.2, 0.05), SKY2, Vector3(0, 0, -0.5))
	sph(shirt, "Spot", Vector3(0, -0.32, 0.03), 0.1, YELLOW, Vector3(1, 1, 0.3))
	var sock := motion(node(line, "Sock", Vector3(0.45, 0.4, 0)), SWAY, 0.35, 1.9, Vector3(1, 0, 0), 0.3)
	box(sock, "Leg", Vector3(0, -0.22, 0), Vector3(0.18, 0.4, 0.05), WHITE)
	box(sock, "Foot", Vector3(0.08, -0.45, 0), Vector3(0.32, 0.15, 0.05), WHITE)
	box(sock, "Stripe", Vector3(0, -0.08, 0.01), Vector3(0.19, 0.07, 0.05), PINK)
	for x in [-0.35, 0.45]:
		box(line, "Peg%s" % x, Vector3(x, 0.42, 0.02), Vector3(0.06, 0.14, 0.06), ORANGE)
	save(a[0], "laundry")


# --- rooftops ------------------------------------------------------------------

func _cat_chimney() -> void:
	var a := root("CatChimney", R.BONK, "gag_rooftops", 0.7, {cue_pitch = 1.25, push = 2.5, hold = 0.1,
			near_radius = 4.5, near_cue = &"gag_rooftops", near_pitch = 1.1, hit_offset = Vector3(0, 0.55, 0)})
	var g: Node3D = a[1]
	mi(g, "Roof", _mesh("prism", 2.4, 0.8, 1.4), mat(PLUM), Vector3(0, -1.2, 0))
	box(g, "Chimney", Vector3(0.45, -0.45, 0), Vector3(0.6, 1.0, 0.6), BRICK)
	box(g, "Cap", Vector3(0.45, 0.08, 0), Vector3(0.72, 0.12, 0.72), SLATE)
	var cat := node(g, "Cat", Vector3(0.45, 0.45, 0))
	sph(cat, "Body", Vector3.ZERO, 0.28, ORANGE, Vector3(1, 0.9, 1.2))
	sph(cat, "Head", Vector3(0, 0.3, 0.2), 0.22, ORANGE)
	for side in [-1.0, 1.0]:
		mi(cat, "Ear%s" % side, _mesh("prism", 0.14, 0.16, 0.06), mat(ORANGE), Vector3(side * 0.12, 0.52, 0.2))
		sph(cat, "Eye%s" % side, Vector3(side * 0.08, 0.34, 0.4), 0.05, INK, Vector3(1, 1.4, 1))
	sph(cat, "Nose", Vector3(0, 0.27, 0.42), 0.03, PINK)
	var tail := motion(node(cat, "Tail", Vector3(0, 0.0, -0.3)), WAVE, 0.6, 1.2, Vector3(0, 0, 1))
	cap(tail, "Tip", Vector3(0, 0.3, 0), 0.06, 0.6, ORANGE)
	save(a[0], "cat_chimney")


func _pigeons() -> void:
	var a := root("Pigeons", R.SCATTER, "sky_flutter", 1.0, {push = 2.0, hold = 0.08, shake = 0.05,
			near_radius = 2.5, near_cue = &"squawk", near_pitch = 0.8})
	var g: Node3D = a[1]
	box(g, "Antenna", Vector3(0, -0.25, 0), Vector3(2.0, 0.06, 0.06), SLATE)
	box(g, "Mast", Vector3(0, -0.9, 0), Vector3(0.08, 1.3, 0.08), SLATE)
	for i in 3:
		bird(g, "Bird%d" % i, Vector3(-0.65 + i * 0.65, 0.05, 0), [GREY, SLATE, GREY][i], 0.9, i * 0.3)
	save(a[0], "pigeons")


# --- treetops ------------------------------------------------------------------

func _flock() -> void:
	var a := root("Flock", R.SCATTER, "sky_flutter", 1.3, {push = 2.5, hold = 0.08, shake = 0.06,
			cue_pitch = 1.1, drift = Vector3(0, 0, 0.8)})
	var g: Node3D = a[1]
	var spots := [Vector3(0, 0, 0.6), Vector3(-0.7, 0.15, 0), Vector3(0.7, 0.1, 0), Vector3(-1.3, 0.3, -0.6),
			Vector3(1.3, 0.25, -0.6)]
	var cols := [YELLOW, SKY2, PINK, SKY2, ORANGE]
	for i in spots.size():
		bird(g, "Bird%d" % i, spots[i], cols[i], 0.8, i * 0.17)
	save(a[0], "flock")


func _squirrel() -> void:
	var a := root("Squirrel", R.BONK, "squeak", 0.9, {cue_pitch = 1.3, push = 2.5, hold = 0.08,
			near_radius = 2.5, near_cue = &"squeak", near_pitch = 1.6})
	var g: Node3D = a[1]
	cyl(g, "Branch", Vector3(0, -0.35, 0), 0.12, 0.16, 2.4, BARK, Vector3(0, 0, PI / 2))
	for i in 3:
		sph(g, "Leaves%d" % i, Vector3(-1.2 + i * 0.25, -0.2 + i * 0.12, (i - 1) * 0.2), 0.42 - i * 0.06, LEAF)
	var s := motion(node(g, "Squirrel", Vector3(0.3, 0.0, 0)), BOB, 0.06, 2.2)
	sph(s, "Body", Vector3.ZERO, 0.26, ORANGE.darkened(0.25), Vector3(0.9, 1.1, 1))
	sph(s, "Head", Vector3(0, 0.32, 0.12), 0.19, ORANGE.darkened(0.25))
	sph(s, "Belly", Vector3(0, -0.02, 0.14), 0.17, PEACH)
	for side in [-1.0, 1.0]:
		sph(s, "Ear%s" % side, Vector3(side * 0.11, 0.5, 0.1), 0.06, ORANGE.darkened(0.25))
		sph(s, "Eye%s" % side, Vector3(side * 0.08, 0.36, 0.28), 0.04, INK)
	var tail := motion(node(s, "Tail", Vector3(0, 0.0, -0.25)), WAVE, 0.3, 1.5, Vector3(1, 0, 0))
	sph(tail, "Fluff", Vector3(0, 0.35, -0.12), 0.26, ORANGE.darkened(0.15), Vector3(0.8, 1.6, 0.8))
	save(a[0], "squirrel")


# --- kites and balloons ----------------------------------------------------------

func _party_balloons() -> void:
	var a := root("PartyBalloons", R.POP, "sky_pop", 0.9, {push = 3.0, hold = 0.1, shake = 0.08,
			hit_offset = Vector3(0, 0.3, 0), drift = Vector3(0, 0.2, 0)})
	var g: Node3D = a[1]
	var spots := [Vector3(-0.4, 0.3, 0), Vector3(0.4, 0.4, 0.1), Vector3(0, 0.8, -0.1)]
	var cols := [PINK, YELLOW, SKY2]
	var bob := motion(node(g, "Strings"), SWAY, 0.1, 0.5, Vector3(0, 0, 1))
	for i in 3:
		balloon(g, "Pop%d" % i, spots[i], cols[i], 0.38)
		string_to(bob, "String%d" % i, spots[i] + Vector3(0, -0.48, 0), Vector3(0, -1.2, 0))
	mi(bob, "Bow", _mesh("prism", 0.2, 0.12, 0.05), mat(ORANGE), Vector3(0, -1.2, 0), Vector3(0, 0, PI / 2))
	save(a[0], "party_balloons")


func _hot_air_balloon() -> void:
	var a := root("HotAirBalloon", R.BOUNCE, "sky_boing", 1.2, {cue_pitch = 0.8, push = 3.0, hold = 0.15,
			shake = 0.08, near_radius = 3.0, near_cue = &"cheer", near_pitch = 1.4, drift = Vector3(0.1, 0.1, 0)})
	var g := motion(node(a[1], "Sway"), SWAY, 0.06, 0.4, Vector3(0, 0, 1))
	sph(g, "Envelope", Vector3(0, 0.6, 0), 1.0, ORANGE, Vector3(1, 1.1, 1))
	mi(g, "BandA", _mesh("torus", 0.95, 1.06), mat(PINK), Vector3(0, 0.85, 0), Vector3.ZERO, Vector3(1, 1.6, 1))
	mi(g, "BandB", _mesh("torus", 0.82, 0.93), mat(YELLOW), Vector3(0, 0.1, 0), Vector3.ZERO, Vector3(1, 1.6, 1))
	cyl(g, "Skirt", Vector3(0, -0.45, 0), 0.4, 0.22, 0.35, PINK)
	box(g, "Basket", Vector3(0, -1.25, 0), Vector3(0.5, 0.35, 0.5), BARK)
	for x in [-0.2, 0.2]:
		for z in [-0.2, 0.2]:
			string_to(g, "Rope%s%s" % [x, z], Vector3(x, -1.08, z), Vector3(x * 1.4, -0.55, z * 1.4), BARK, 0.01)
	# The passenger: a little Jarling-ish rider waving from the basket.
	var j := node(g, "Rider", Vector3(0, -1.0, 0.05))
	cap(j, "Body", Vector3(0, 0.05, 0), 0.12, 0.3, TEAL)
	sph(j, "Head", Vector3(0, 0.3, 0), 0.14, PEACH)
	face(j, Vector3(0, 0.3, 0.13), 0.9)
	var arm := motion(node(j, "Arm", Vector3(0.12, 0.12, 0)), WAVE, 0.6, 1.6, Vector3(0, 0, 1))
	cap(arm, "Hand", Vector3(0.05, 0.16, 0), 0.04, 0.3, TEAL, Vector3(0, 0, -0.3))
	save(a[0], "hot_air_balloon")


func _blimp() -> void:
	var a := root("Blimp", R.BOUNCE, "sky_boing", 1.1, {cue_pitch = 0.6, push = 2.5, hold = 0.12,
			shake = 0.07, drift = Vector3(0, 0, 0.4)})
	var g: Node3D = a[1]
	cap(g, "Hull", Vector3.ZERO, 0.6, 2.6, SKY1.lerp(WHITE, 0.4), Vector3(PI / 2, 0, 0))
	cap(g, "Stripe", Vector3.ZERO, 0.62, 1.2, SKY4, Vector3(PI / 2, 0, 0))
	for i in 4:
		var rot := Vector3(0, 0, i * PI / 2)
		var fin := node(g, "Fin%d" % i, Vector3(0, 0, -1.1), rot)
		mi(fin, "Blade", _mesh("prism", 0.05, 0.45, 0.5), mat(PINK), Vector3(0, 0.6, 0), Vector3(0, PI / 2, 0))
	box(g, "Gondola", Vector3(0, -0.68, 0.1), Vector3(0.3, 0.2, 0.6), YELLOW)
	for i in 3:
		sph(g, "Window%d" % i, Vector3(0.16, -0.66, -0.1 + i * 0.2), 0.05, SKY2)
	var prop := motion(node(g, "Prop", Vector3(0, -0.68, -0.28)), SPIN, 0.0, 3.0, Vector3(0, 0, 1))
	box(prop, "Blade", Vector3.ZERO, Vector3(0.45, 0.06, 0.02), SLATE)
	save(a[0], "blimp")


# --- clouds --------------------------------------------------------------------

func _prop_plane() -> void:
	var a := root("PropPlane", R.BONK, "sky_bonk", 1.0, {push = 4.0, hold = 0.15, shake = 0.12,
			drift = Vector3(0, 0, 0.9)})
	var g := motion(node(a[1], "Bob"), BOB, 0.08, 0.7)
	cap(g, "Body", Vector3.ZERO, 0.28, 1.7, YELLOW, Vector3(PI / 2, 0, 0))
	box(g, "Wing", Vector3(0, 0.05, 0.15), Vector3(2.2, 0.07, 0.42), TRIM)
	box(g, "TailWing", Vector3(0, 0.1, -0.7), Vector3(0.8, 0.05, 0.22), TRIM)
	mi(g, "Fin", _mesh("prism", 0.05, 0.35, 0.3), mat(TRIM), Vector3(0, 0.3, -0.72), Vector3(0, PI / 2, 0))
	mi(g, "Canopy", _mesh("hemi", 0.2), mat(Color(SKY1, 0.8), 0.2), Vector3(0, 0.2, 0.05))
	sph(g, "Pilot", Vector3(0, 0.25, 0.05), 0.12, PEACH)
	sph(g, "Nose", Vector3(0, 0, 0.85), 0.12, SLATE)
	var prop := motion(node(g, "Prop", Vector3(0, 0, 0.93)), SPIN, 0.0, 5.0, Vector3(0, 0, 1))
	box(prop, "Blade", Vector3.ZERO, Vector3(0.9, 0.08, 0.03), INK)
	save(a[0], "prop_plane")


func _bounce_cloud() -> void:
	var a := root("BounceCloud", R.BOUNCE, "sky_boing", 1.3, {push = 4.0, hold = 0.2, shake = 0.06,
			puff_color = WHITE})
	var g := motion(node(a[1], "Bob"), BOB, 0.1, 0.4)
	var bits := [[Vector3(0, 0.15, 0), 0.75], [Vector3(-0.8, -0.05, 0), 0.55], [Vector3(0.8, -0.05, 0.05), 0.58],
			[Vector3(-0.35, 0.45, -0.1), 0.5], [Vector3(0.4, 0.4, -0.1), 0.48], [Vector3(0, -0.2, 0.2), 0.6]]
	for i in bits.size():
		sph(g, "Puff%d" % i, bits[i][0], bits[i][1], WHITE)
	face(g, Vector3(0, 0.05, 0.78), 2.2)
	sph(g, "CheekL", Vector3(-0.32, -0.05, 0.7), 0.08, PINK.lerp(WHITE, 0.5), Vector3(1, 0.7, 0.4))
	sph(g, "CheekR", Vector3(0.32, -0.05, 0.7), 0.08, PINK.lerp(WHITE, 0.5), Vector3(1, 0.7, 0.4))
	save(a[0], "bounce_cloud")


# --- thin air ------------------------------------------------------------------

func _jet() -> void:
	var a := root("Jet", R.BONK, "sky_bonk", 1.0, {cue_pitch = 0.85, push = 4.0, hold = 0.15, shake = 0.14,
			drift = Vector3(0, 0, 1.6)})
	var g: Node3D = a[1]
	cap(g, "Body", Vector3.ZERO, 0.25, 2.2, WHITE, Vector3(PI / 2, 0, 0))
	mi(g, "Nose", _mesh("cyl", 0.0, 0.25, 0.4), mat(WHITE), Vector3(0, 0, 1.25), Vector3(PI / 2, 0, 0))
	for side in [-1.0, 1.0]:
		box(g, "Wing%s" % side, Vector3(side * 0.75, -0.05, -0.05), Vector3(1.3, 0.06, 0.45), SKY3,
				Vector3(0, side * 0.5, 0))
		box(g, "Tail%s" % side, Vector3(side * 0.3, 0.05, -0.95), Vector3(0.5, 0.05, 0.2), SKY3,
				Vector3(0, side * 0.5, 0))
		cyl(g, "Engine%s" % side, Vector3(side * 0.6, -0.17, 0.1), 0.09, 0.09, 0.4, SLATE, Vector3(PI / 2, 0, 0))
	mi(g, "Fin", _mesh("prism", 0.05, 0.45, 0.4), mat(SKY3), Vector3(0, 0.35, -0.95), Vector3(0, PI / 2, 0))
	for i in 4:
		sph(g, "Window%d" % i, Vector3(0.2, 0.08, 0.6 - i * 0.25), 0.05, SKY2)
	sph(g, "Cockpit", Vector3(0, 0.12, 0.95), 0.1, SKY2, Vector3(1.4, 0.6, 1))
	# The contrail: two lines of puffs fading out behind the engines.
	for side in [-1.0, 1.0]:
		for i in 6:
			var r := 0.08 + i * 0.04
			sph(g, "Trail%s_%d" % [side, i], Vector3(side * 0.6, -0.17, -0.5 - i * 0.55), r,
					Color(1, 1, 1, 0.85 - i * 0.12))
	save(a[0], "jet")


func _balloon_bunch() -> void:
	var a := root("BalloonBunch", R.POP, "sky_pop", 1.1, {push = 3.0, hold = 0.12, shake = 0.08,
			hit_offset = Vector3(0, 0.4, 0), drift = Vector3(0, 0.25, 0.1)})
	var g: Node3D = a[1]
	var cols := [PINK, YELLOW, SKY2, ORANGE, TEAL, SKY4]
	var strings := motion(node(g, "Strings"), SWAY, 0.12, 0.45, Vector3(1, 0, 0))
	for i in 6:
		var ang := i * TAU / 5.0
		var pos := Vector3(cos(ang) * 0.5, 0.4 + (0.45 if i == 5 else 0.0), sin(ang) * 0.5) if i < 5 else Vector3(0, 1.0, 0)
		balloon(g, "Pop%d" % i, pos, cols[i], 0.36)
		string_to(strings, "String%d" % i, pos + Vector3(0, -0.45, 0), Vector3(0, -1.0, 0))
	save(a[0], "balloon_bunch")


# --- edge of space ---------------------------------------------------------------

func _satellite() -> void:
	var a := root("Satellite", R.PING, "sky_ping", 1.0, {push = 3.0, hold = 0.12, shake = 0.06,
			puff_color = YELLOW})
	var g := motion(node(a[1], "Turn"), SPIN, 0.0, 0.08, Vector3(0.2, 1, 0.1))
	box(g, "Body", Vector3.ZERO, Vector3(0.6, 0.6, 0.8), YELLOW)
	for side in [-1.0, 1.0]:
		box(g, "Arm%s" % side, Vector3(side * 0.55, 0, 0), Vector3(0.5, 0.06, 0.06), SLATE)
		box(g, "Panel%s" % side, Vector3(side * 1.25, 0, 0), Vector3(1.0, 0.05, 0.55), SKY3)
		for k in 3:
			box(g, "Line%s%d" % [side, k], Vector3(side * (0.95 + k * 0.3), 0.03, 0), Vector3(0.03, 0.02, 0.56), SKY1)
	mi(g, "Dish", _mesh("hemi", 0.35), mat(WHITE), Vector3(0, 0.45, 0), Vector3(PI, 0, 0), Vector3(1, 0.5, 1))
	cyl(g, "Antenna", Vector3(0, 0.6, 0), 0.02, 0.02, 0.5, SLATE)
	sph(g, "Light", Vector3(0, 0.88, 0), 0.06, PINK, Vector3.ONE, 2.0)
	save(a[0], "satellite")


func _weather_balloon() -> void:
	var a := root("WeatherBalloon", R.POP, "sky_pop", 1.0, {cue_pitch = 0.7, push = 3.5, hold = 0.15,
			shake = 0.1, hit_offset = Vector3(0, 0.6, 0), drift = Vector3(0, 0.3, 0)})
	var g: Node3D = a[1]
	balloon(g, "Pop0", Vector3(0, 0.6, 0), WHITE, 0.9)
	var hang := motion(node(g, "Hang"), SWAY, 0.15, 0.5, Vector3(0, 0, 1))
	string_to(hang, "Line", Vector3(0, -0.5, 0), Vector3(0, -1.6, 0))
	box(hang, "Box", Vector3(0, -1.75, 0), Vector3(0.3, 0.3, 0.3), ORANGE)
	sph(hang, "Blink", Vector3(0, -1.55, 0), 0.05, TEAL, Vector3.ONE, 2.0)
	save(a[0], "weather_balloon")


# --- space ---------------------------------------------------------------------

func _saucer() -> void:
	var a := root("Saucer", R.CATCH, "sky_catch", 1.2, {push = 4.0, hold = 0.5, shake = 0.1,
			puff_color = ALIEN, near_radius = 3.5, near_cue = &"gag_space", near_pitch = 1.2})
	var g: Node3D = a[1]
	var hover := motion(node(g, "Hover"), BOB, 0.1, 0.6)
	mi(hover, "Disc", _mesh("sphere", 1.0), mat(GREY, 0.35, 0.5), Vector3.ZERO, Vector3.ZERO, Vector3(1.2, 0.22, 1.2))
	mi(hover, "Rim", _mesh("torus", 1.05, 1.25), mat(SKY4), Vector3.ZERO, Vector3.ZERO, Vector3(1, 0.6, 1))
	for i in 8:
		var ang := i * TAU / 8.0
		sph(hover, "Light%d" % i, Vector3(cos(ang) * 1.15, 0.0, sin(ang) * 1.15), 0.08,
				[YELLOW, PINK, SKY1][i % 3], Vector3.ONE, 2.5)
	var alien := node(hover, "Alien", Vector3(0, 0.3, 0))
	sph(alien, "Head", Vector3(0, 0.15, 0), 0.3, ALIEN, Vector3(1, 1.1, 1))
	for side in [-1.0, 1.0]:
		sph(alien, "Eye%s" % side, Vector3(side * 0.12, 0.2, 0.24), 0.08, INK, Vector3(1, 1.3, 0.6))
		sph(alien, "Shine%s" % side, Vector3(side * 0.1, 0.24, 0.3), 0.025, WHITE)
		var ant := node(alien, "Antenna%s" % side, Vector3(side * 0.12, 0.42, 0), Vector3(0, 0, -side * 0.3))
		cyl(ant, "Stalk", Vector3(0, 0.12, 0), 0.015, 0.015, 0.25, ALIEN)
		sph(ant, "Bob", Vector3(0, 0.27, 0), 0.05, YELLOW, Vector3.ONE, 1.5)
	var wave := motion(node(alien, "Arm", Vector3(0.25, 0.0, 0.05)), WAVE, 0.7, 1.4, Vector3(0, 0, 1))
	cap(wave, "Hand", Vector3(0.08, 0.15, 0), 0.05, 0.3, ALIEN, Vector3(0, 0, -0.4))
	mi(hover, "Dome", _mesh("hemi", 0.55), mat(Color(SKY1, 0.35), 0.1, 0.6), Vector3(0, 0.15, 0))
	var beam := mi(g, "Beam", _mesh("cyl", 0.3, 1.0, 2.2), mat(Color(ALIEN, 0.35), 1.0, 0.0, 1.0),
			Vector3(0, -1.2, 0))
	beam.visible = false
	save(a[0], "saucer")


func _moon() -> void:
	var a := root("Moon", R.BOUNCE, "sky_bonk", 1.4, {cue_pitch = 0.55, push = 4.0, hold = 0.2, shake = 0.1})
	var g := motion(node(a[1], "Turn"), SPIN, 0.0, 0.03)
	sph(g, "Rock", Vector3.ZERO, 1.4, Color("d8d4e8"))
	var craters := [Vector3(0.5, 0.6, 1.1), Vector3(-0.7, -0.2, 1.1), Vector3(0.2, -0.8, 1.05), Vector3(-0.2, 0.9, -1.0),
			Vector3(1.1, -0.3, -0.7), Vector3(-1.2, 0.5, -0.4)]
	for i in craters.size():
		var c: Vector3 = craters[i].normalized() * 1.33
		var m := sph(g, "Crater%d" % i, c, 0.22 + 0.06 * (i % 3), Color("aaa3c4"), Vector3(1, 1, 0.35))
		m.basis = Basis(Quaternion(Vector3.BACK, c.normalized())) * Basis.from_scale(Vector3(1, 1, 0.35))
	face(a[1], Vector3(0, 0, 1.42), 3.0)
	save(a[0], "moon")


func _comet() -> void:
	var a := root("Comet", R.PING, "sky_ping", 0.8, {cue_pitch = 1.4, push = 3.0, hold = 0.1, shake = 0.06,
			puff_color = SKY1, near_radius = 3.0, near_cue = &"whoosh", near_pitch = 1.6, drift = Vector3(0, -0.3, 2.0)})
	var g: Node3D = a[1]
	sph(g, "Head", Vector3.ZERO, 0.4, ICE, Vector3.ONE, 1.2)
	sph(g, "Glow", Vector3.ZERO, 0.55, Color(SKY1, 0.4), Vector3.ONE, 1.5)
	for i in 7:
		var r := 0.45 - i * 0.05
		sph(g, "Tail%d" % i, Vector3(sin(i * 1.7) * 0.08, cos(i * 1.3) * 0.08, -0.4 - i * 0.45), r,
				Color([SKY1, YELLOW, PINK][i % 3], 0.7 - i * 0.08), Vector3.ONE, 1.2)
	save(a[0], "comet")


# --- data/sky.tres -------------------------------------------------------------

## Per tier: [id, count_min, count_max, scale, spread, [[scene, weight, on_path], ...]].
const TIERS := [
	[&"backyard", 3, 4, 0.7, Vector2(2.2, 5.0), [["kite", 1.0, true], ["bird", 1.2, true], ["laundry", 0.8, true]]],
	[&"rooftops", 3, 5, 1.2, Vector2(2.0, 5.0), [["cat_chimney", 1.0, false], ["pigeons", 1.2, true], ["bird", 0.6, true]]],
	[&"treetops", 3, 6, 2.0, Vector2(1.8, 4.5), [["flock", 1.2, true], ["squirrel", 0.8, true], ["bird", 0.5, true], ["kite", 0.4, true]]],
	[&"kites", 4, 6, 4.5, Vector2(1.6, 4.0), [["party_balloons", 1.2, true], ["hot_air_balloon", 1.0, true], ["blimp", 0.6, true], ["kite", 0.6, true]]],
	[&"clouds", 4, 6, 7.0, Vector2(1.6, 4.0), [["prop_plane", 1.2, true], ["bounce_cloud", 1.2, true], ["party_balloons", 0.3, true]]],
	[&"thin_air", 3, 5, 9.0, Vector2(1.6, 4.0), [["jet", 1.2, true], ["balloon_bunch", 1.0, true], ["bounce_cloud", 0.4, true]]],
	[&"edge", 3, 5, 10.0, Vector2(1.6, 4.0), [["satellite", 1.2, true], ["weather_balloon", 1.0, true]]],
	[&"space", 3, 5, 10.0, Vector2(1.6, 4.0), [["saucer", 1.2, true], ["moon", 0.7, true], ["comet", 0.8, true]]],
]


func _data() -> void:
	var set := SkySet.new()
	for row in TIERS:
		var t := SkyTier.new()
		t.id = row[0]
		t.count_min = row[1]
		t.count_max = row[2]
		t.scale = row[3]
		t.spread = row[4]
		for e in row[5]:
			var entry := SkyEntry.new()
			entry.scene = load("res://scenes/sky/%s.tscn" % e[0])
			entry.weight = e[1]
			entry.on_path = e[2]
			t.entries.append(entry)
		set.tiers.append(t)
	if ResourceSaver.save(set, "res://data/sky.tres") != OK:
		push_error("save failed data/sky.tres")
	print("saved res://data/sky.tres")
