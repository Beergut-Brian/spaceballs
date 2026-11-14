## Graphics tiers. Autoload: Graphics. Systems lane owns.
## The TV box is an Intel HD 530 (2026-11-14); a GTX 1060 may go in later. Two tiers, data in
## res://data/graphics.json:
##   high  the look as built (the 1060). Graphics changes nothing at all in high.
##   low   Intel integrated / unknown GPUs: FXAA not MSAA, 0.75 render scale with FSR 1, one short
##         shadow cascade, glow / SSAO / SSIL / SSR / SDFGI / volumetrics off, LOD bias up, a shorter
##         camera far plane with a little more fog, half the particles, 60 fps cap, vsync on.
## Pick at boot: --graphics=low|high (after --) wins; else the GPU (pick_tier()). Headless has no
## renderer: high (nothing to change). Dev builds show the tier next to the lobby's version label.
## -- --bench runs the built-in benchmark (scripts/autoload/bench.gd) and quits.
extends Node

const FILE := "res://data/graphics.json"
const TIERS := ["high", "low"]
const FLAG := "--graphics="

## The tier in use: "high" or "low".
var tier := "high"
## Why it was picked (the boot log line, the bench line).
var reason := ""
var adapter := ""
var vendor := ""
## The settings of `tier` (data/graphics.json); {} for high.
var settings := {}


## The GPU -> tier rule. `device_type` is RenderingDevice.DeviceType (-1 when unknown).
## NVIDIA and AMD discrete -> high; Intel integrated, AMD APUs, software renderers and anything
## unknown -> low. `args` may carry --graphics=low|high, which wins.
static func pick_tier(adapter_name: String, vendor_name: String, device_type: int = -1,
		args: PackedStringArray = PackedStringArray()) -> String:
	var forced := flag_tier(args)
	if forced != "":
		return forced
	var s := (adapter_name + " " + vendor_name).to_lower()
	var integrated := device_type == RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU \
			or device_type == RenderingDevice.DEVICE_TYPE_CPU \
			or device_type == RenderingDevice.DEVICE_TYPE_VIRTUAL_GPU
	var discrete := device_type == RenderingDevice.DEVICE_TYPE_DISCRETE_GPU
	if integrated or s.contains("llvmpipe") or s.contains("lavapipe") or s.contains("softpipe") \
			or s.contains("swiftshader"):
		return "low"
	if s.contains("nvidia") or s.contains("geforce") or s.contains("quadro"):
		return "high"
	if s.contains("amd") or s.contains("radeon") or s.contains("ati technologies"):
		if discrete:
			return "high"
		# APUs: "AMD Radeon Graphics", "Radeon(TM) Vega 8 Graphics", RADV codenames.
		for apu in ["radeon graphics", "radeon(tm) graphics", "vega 3 ", "vega 6 ", "vega 8 ",
				"vega 10 ", "vega 11 ", "renoir", "cezanne", "rembrandt", "phoenix", "vangogh",
				"raphael", "picasso", "raven", "lucienne", "barcelo", "mendocino", "custom gpu"]:
			if s.contains(apu):
				return "low"
		return "high"
	if s.contains("intel") and discrete:
		return "high"   # Arc A / B cards say so through the device type
	return "low"


## "--graphics=low" -> "low"; "" when absent or not a tier.
static func flag_tier(args: PackedStringArray) -> String:
	for a in args:
		if a.begins_with(FLAG):
			var t := a.trim_prefix(FLAG).strip_edges().to_lower()
			if t in TIERS:
				return t
	return ""


## The settings for `name` from the data file ({} when missing).
static func tier_settings(name: String, path := FILE) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var j := JSON.new()
	if j.parse(FileAccess.get_file_as_string(path)) != OK or not j.data is Dictionary:
		return {}
	var d = j.data.get(name, {})
	return d if d is Dictionary else {}


## The lobby footer: the build label, plus the tier on dev builds ("dev  gfx low").
func version_label(base: String) -> String:
	if base == "dev" or base.contains("-dev"):
		return "%s  gfx %s" % [base, tier]
	return base


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := OS.get_cmdline_user_args()
	var forced := flag_tier(args)
	if DisplayServer.get_name() == "headless":
		adapter = "headless"
		tier = forced if forced != "" else "high"
		reason = "flag" if forced != "" else "headless (no renderer)"
	else:
		adapter = RenderingServer.get_video_adapter_name()
		vendor = RenderingServer.get_video_adapter_vendor()
		var dtype := -1
		var rd := RenderingServer.get_rendering_device()
		if rd:
			dtype = rd.get_device_type()
		tier = pick_tier(adapter, vendor, dtype, args)
		reason = "flag" if forced != "" else "gpu type %d" % dtype
	print("graphics: tier=%s (%s) adapter=\"%s\" vendor=\"%s\"" % [tier, reason, adapter, vendor])
	use(tier)
	if "--bench" in args:
		var b: Node = load("res://scripts/autoload/bench.gd").new()
		b.name = "Bench"
		add_child(b)


## Switches to `name` and applies it to the window and everything in the tree from now on.
## Low is one-way in a session (high is "as built", so there is nothing to put back).
func use(name: String) -> void:
	tier = name if name in TIERS else "high"
	settings = tier_settings(tier)
	if settings.is_empty():
		return
	apply_window(settings)
	apply_viewport(get_tree().root, settings)
	if not get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.connect(_on_node_added)
	_walk(get_tree().root)


func _walk(n: Node) -> void:
	_on_node_added(n)
	for c in n.get_children():
		_walk(c)


func _on_node_added(n: Node) -> void:
	# Deferred: scripts set far planes and particle amounts in their own _ready (after node_added).
	if n is SubViewport or n is WorldEnvironment or n is Light3D or n is Camera3D \
			or n is CPUParticles3D or n is GPUParticles3D or n is CPUParticles2D or n is GPUParticles2D:
		apply_node.call_deferred(n, settings)


## Engine and RenderingServer globals: fps cap, vsync, shadow atlas and filter.
func apply_window(s: Dictionary) -> void:
	if s.has("max_fps"):
		Engine.max_fps = int(s.max_fps)
	if s.get("vsync", false):
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	if s.has("shadow_atlas"):
		RenderingServer.directional_shadow_atlas_set_size(int(s.shadow_atlas), true)
		get_tree().root.positional_shadow_atlas_size = int(s.shadow_atlas)
	if s.has("shadow_soft_quality"):
		RenderingServer.directional_soft_shadow_filter_set_quality(int(s.shadow_soft_quality))
		RenderingServer.positional_soft_shadow_filter_set_quality(int(s.shadow_soft_quality))


## AA, render scale + FSR, LOD bias. Transparent SubViewports (the lobby's character cards) keep
## full scale: FSR has no alpha.
static func apply_viewport(vp: Viewport, s: Dictionary) -> void:
	if s.has("msaa_3d"):
		vp.msaa_3d = int(s.msaa_3d) as Viewport.MSAA
	if s.has("fxaa"):
		vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if s.fxaa else Viewport.SCREEN_SPACE_AA_DISABLED
	if s.has("mesh_lod_threshold"):
		vp.mesh_lod_threshold = float(s.mesh_lod_threshold)
	if vp.transparent_bg:
		return
	if s.has("render_scale"):
		vp.scaling_3d_scale = float(s.render_scale)
	if s.get("fsr", false):
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR


## One node, once (re-entering the tree, e.g. the lobby adopting a kicker, does not halve twice).
static func apply_node(n: Node, s: Dictionary) -> void:
	if s.is_empty() or not is_instance_valid(n) or n.has_meta(&"_gfx"):
		return
	n.set_meta(&"_gfx", true)
	if n is SubViewport:
		apply_viewport(n, s)
	elif n is WorldEnvironment:
		apply_environment(n, s)
	elif n is DirectionalLight3D:
		if not s.get("shadows", true):
			n.shadow_enabled = false
		elif n.shadow_enabled:
			n.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
			n.directional_shadow_max_distance = minf(n.directional_shadow_max_distance,
					float(s.get("shadow_max_distance", n.directional_shadow_max_distance)))
			n.shadow_blur = float(s.get("shadow_blur", n.shadow_blur))
	elif n is Light3D:
		if s.has("shadows"):
			n.shadow_enabled = false   # only the sun casts on low
	elif n is Camera3D:
		if s.has("camera_far_max"):
			n.far = minf(n.far, float(s.camera_far_max))
	elif s.has("particle_scale"):
		n.amount = maxi(1, int(round(n.amount * float(s.particle_scale))))


## The scene's Environment is a shared sub-resource: low works on its own copy.
static func apply_environment(we: WorldEnvironment, s: Dictionary) -> void:
	if we.environment == null:
		return
	var env: Environment = we.environment.duplicate()
	for key in ["glow", "ssao", "ssil", "ssr", "sdfgi", "volumetric_fog"]:
		if s.has(key) and not s[key]:
			env.set("%s_enabled" % key, false)
	if env.fog_enabled and s.has("fog_density_scale"):
		env.fog_density *= float(s.fog_density_scale)
	we.environment = env
