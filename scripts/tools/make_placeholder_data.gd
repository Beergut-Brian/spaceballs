# PLACEHOLDER (systems grey-box): writes data/tiers.tres and data/upgrades/*.tres.
# Content replaces the output with the real 40+ upgrades and tuned tiers; this script is only
# here so the grey-box numbers are reproducible. Run:
#   godot --headless --path . -s scripts/tools/make_placeholder_data.gd
extends SceneTree

const TIERS := [
	# id, threshold (m), HUD colour, sky top, sky horizon
	[&"backyard", 0.0, "7fc8f8", "5aa9e6", "cfeaff"],
	[&"rooftops", 4.0, "f2a65a", "4f9bdc", "bfe1fb"],
	[&"treetops", 14.0, "6a994e", "3f86cf", "a9d3f5"],
	[&"kites", 55.0, "f7d046", "2f6fbf", "8fc2ee"],
	[&"clouds", 350.0, "e8eef2", "2459a8", "c9d8e8"],
	[&"thin_air", 2500.0, "6c8ebf", "173c80", "5a7fb8"],
	[&"edge", 18000.0, "6b4fa0", "0b1a45", "3a2d6b"],
	[&"space", 100000.0, "1b1b3a", "02020a", "101030"],
]

const UPGRADES := [
	# id, name, tier, kind, power_mult, icon colour, description
	[&"big_boot", "Big Boot", 1, "normal", 1.70, "4a90d9", "A boot the size of a bathtub."],
	[&"spring_shoes", "Spring Shoes", 1, "normal", 1.75, "5fb7e5", "Boing boing boing."],
	[&"lucky_sock", "Lucky Sock", 1, "normal", 1.65, "7aa6f0", "Never washed. Very lucky."],
	[&"rocket_boots", "Rocket Boots", 2, "normal", 1.85, "3d6fd1", "Boots with rockets on."],
	[&"super_strength", "Super Strength", 2, "normal", 1.80, "2f8fb0", "Muscles on muscles."],
	[&"giant_foot", "Giant Foot", 3, "normal", 1.90, "1f5fa8", "One foot is now enormous."],
	[&"jetpack", "Jetpack", 1, "strong", 2.50, "f0b429", "Whoosh."],
	[&"pogo_legs", "Pogo Legs", 1, "strong", 2.40, "f7c948", "Legs replaced with pogo sticks."],
	[&"cannon_leg", "Cannon Leg", 2, "strong", 2.60, "de911d", "A cannon where the leg was."],
	[&"dad_strength", "Dad Strength", 3, "strong", 2.70, "cb6e17", "Opens any jar."],
	[&"tiny_hat", "Tiny Hat", 1, "joke", 1.10, "f38bc9", "A very small hat."],
	[&"mustache", "Mustache", 1, "joke", 1.20, "e66cb2", "Distinguished."],
	[&"honk_horn_shoes", "Honk Horn Shoes", 2, "joke", 1.25, "d64e9c", "Every step honks."],
	[&"kiss_the_frog", "Kiss the Frog", 1, "curse", 0.20, "9b5de5", "Mwah. Ribbit."],
	[&"banana_peel", "Banana Peel", 1, "curse", 0.30, "b388eb", "Whoops."],
	[&"sneeze", "Sneeze", 2, "curse", 0.25, "8e7dbe", "Achoo, mid-kick."],
]


func _init() -> void:
	var set := TierSet.new()
	for t in TIERS:
		var d := TierData.new()
		d.id = t[0]
		d.threshold = t[1]
		d.color = Color(t[2])
		d.sky = Gradient.new()
		d.sky.set_color(0, Color(t[3]))
		d.sky.set_color(1, Color(t[4]))
		d.icon = _square(Color(t[2]))
		set.tiers.append(d)
	_save(set, "res://data/tiers.tres")
	DirAccess.make_dir_recursive_absolute("res://data/upgrades")
	var frog := load("res://scenes/curses/frog.tscn")
	for u in UPGRADES:
		var d := UpgradeData.new()
		d.id = u[0]
		d.name = u[1]
		d.tier = u[2]
		d.kind = u[3]
		d.power_mult = u[4]
		d.icon = _square(Color(u[5]))
		d.description = u[6]
		if d.id == &"kiss_the_frog":
			d.scene_override = frog
		_save(d, "res://data/upgrades/%s.tres" % d.id)
	quit()


func _square(c: Color) -> GradientTexture2D:
	var tex := GradientTexture2D.new()
	tex.width = 64
	tex.height = 64
	tex.gradient = Gradient.new()
	tex.gradient.set_color(0, c)
	tex.gradient.set_color(1, c)
	return tex


func _save(res: Resource, path: String) -> void:
	var err := ResourceSaver.save(res, path)
	if err != OK:
		push_error("could not save %s: %d" % [path, err])
