## Graphics tiers (scripts/autoload/Graphics.gd, data/graphics.json) and the built-in bench
## (scripts/autoload/bench.gd). The TV box is an Intel HD 530 until a GTX 1060 goes in.
class_name TestGraphics
extends GdUnitTestSuite

const GraphicsScript := preload("res://scripts/autoload/Graphics.gd")

var _nodes: Array[Node] = []


func after_test() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()


func _low() -> Dictionary:
	return GraphicsScript.tier_settings("low")


# --- the pick ------------------------------------------------------------------

func test_intel_integrated_and_unknown_gpus_get_low() -> void:
	var pick := GraphicsScript.pick_tier
	assert_str(pick.call("Intel(R) HD Graphics 530 (SKL GT2)", "Intel")).is_equal("low")
	assert_str(pick.call("Mesa Intel(R) HD Graphics 530 (SKL GT2)", "Intel")).is_equal("low")
	assert_str(pick.call("Intel(R) UHD Graphics 620", "Intel Corporation",
			RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU)).is_equal("low")
	assert_str(pick.call("llvmpipe (LLVM 19.1.7, 256 bits)", "Mesa", RenderingDevice.DEVICE_TYPE_CPU)) \
			.is_equal("low")
	assert_str(pick.call("AMD Radeon Graphics (RADV RENOIR)", "AMD")).is_equal("low")
	assert_str(pick.call("", "")).is_equal("low")
	assert_str(pick.call("Some Future GPU", "Acme")).is_equal("low")


func test_nvidia_and_amd_discrete_get_high() -> void:
	var pick := GraphicsScript.pick_tier
	assert_str(pick.call("NVIDIA GeForce GTX 1060 6GB", "NVIDIA")).is_equal("high")
	assert_str(pick.call("NVIDIA GeForce GTX 1060 6GB/PCIe/SSE2", "NVIDIA Corporation",
			RenderingDevice.DEVICE_TYPE_DISCRETE_GPU)).is_equal("high")
	assert_str(pick.call("AMD Radeon RX 580 Series (RADV POLARIS10)", "AMD")).is_equal("high")
	assert_str(pick.call("Intel(R) Arc(TM) A750 Graphics (DG2)", "Intel",
			RenderingDevice.DEVICE_TYPE_DISCRETE_GPU)).is_equal("high")


func test_the_flag_overrides_the_gpu() -> void:
	var pick := GraphicsScript.pick_tier
	assert_str(pick.call("NVIDIA GeForce GTX 1060", "NVIDIA", -1,
			PackedStringArray(["--graphics=low"]))).is_equal("low")
	assert_str(pick.call("Intel(R) HD Graphics 530", "Intel", -1,
			PackedStringArray(["--graphics=high"]))).is_equal("high")
	assert_str(pick.call("Intel(R) HD Graphics 530", "Intel", -1,
			PackedStringArray(["--graphics=ultra"]))).is_equal("low")   # not a tier: the GPU decides
	assert_str(GraphicsScript.flag_tier(PackedStringArray(["--graphics=LOW"]))).is_equal("low")


func test_dev_builds_show_the_tier_next_to_the_version() -> void:
	var g: Node = GraphicsScript.new()
	g.tier = "low"
	assert_str(g.version_label("dev")).is_equal("dev  gfx low")
	assert_str(g.version_label("v0.3.0-dev.4")).is_equal("v0.3.0-dev.4  gfx low")
	assert_str(g.version_label("v0.3.0")).is_equal("v0.3.0")
	g.free()


# --- high is exactly as built ----------------------------------------------------

func test_high_changes_nothing() -> void:
	assert_dict(GraphicsScript.tier_settings("high")).is_empty()
	# What "as built" is (the look the 1060 has): pinned so a project edit can't drift high.
	assert_int(ProjectSettings.get_setting("rendering/anti_aliasing/quality/msaa_3d")).is_equal(1)
	assert_int(ProjectSettings.get_setting("display/window/vsync/vsync_mode")).is_equal(1)
	assert_str(ProjectSettings.get_setting("rendering/renderer/rendering_method")).is_equal("forward_plus")
	assert_str(Graphics.tier).is_equal("high")   # headless boots high
	var root := get_tree().root
	assert_int(root.msaa_3d).is_equal(Viewport.MSAA_2X)
	assert_float(root.scaling_3d_scale).is_equal(1.0)
	assert_int(root.scaling_3d_mode).is_equal(Viewport.SCALING_3D_MODE_BILINEAR)
	assert_int(root.screen_space_aa).is_equal(Viewport.SCREEN_SPACE_AA_DISABLED)
	assert_int(Engine.max_fps).is_equal(0)
	# Applying high to the field leaves every node as the scene made it.
	var field: Node3D = _field()
	var we: WorldEnvironment = field.get_node("Environment")
	var env_before := we.environment
	var sun: DirectionalLight3D = field.get_node("Sun")
	GraphicsScript.apply_node(we, {})
	GraphicsScript.apply_node(sun, {})
	assert_object(we.environment).is_same(env_before)
	assert_bool(we.environment.glow_enabled).is_true()
	assert_float(we.environment.fog_density).is_equal_approx(0.0015, 0.00001)
	assert_bool(sun.shadow_enabled).is_true()
	assert_int(sun.directional_shadow_mode).is_equal(DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS)
	assert_float(sun.directional_shadow_max_distance).is_equal(40.0)
	assert_float(sun.shadow_blur).is_equal(2.0)


# --- low -------------------------------------------------------------------------

func test_low_is_the_hd530_list() -> void:
	var s := _low()
	assert_int(int(s.msaa_3d)).is_equal(0)
	assert_bool(s.fxaa).is_true()
	assert_float(float(s.render_scale)).is_between(0.5, 0.75)
	assert_bool(s.fsr).is_true()
	assert_int(int(s.max_fps)).is_equal(60)
	assert_bool(s.vsync).is_true()
	for off in ["glow", "ssao", "ssil", "ssr", "sdfgi", "volumetric_fog"]:
		assert_bool(s[off]).override_failure_message(off).is_false()
	assert_float(float(s.mesh_lod_threshold)).is_greater(1.0)
	assert_float(float(s.particle_scale)).is_less(1.0)


func test_low_applies_to_viewports() -> void:
	var vp := SubViewport.new()
	_nodes.append(vp)
	vp.msaa_3d = Viewport.MSAA_2X
	GraphicsScript.apply_viewport(vp, _low())
	assert_int(vp.msaa_3d).is_equal(Viewport.MSAA_DISABLED)
	assert_int(vp.screen_space_aa).is_equal(Viewport.SCREEN_SPACE_AA_FXAA)
	assert_float(vp.scaling_3d_scale).is_equal(0.75)
	assert_int(vp.scaling_3d_mode).is_equal(Viewport.SCALING_3D_MODE_FSR)
	assert_float(vp.mesh_lod_threshold).is_equal(4.0)
	# The lobby's transparent character cards keep full scale (FSR has no alpha).
	var card := SubViewport.new()
	_nodes.append(card)
	card.transparent_bg = true
	GraphicsScript.apply_viewport(card, _low())
	assert_float(card.scaling_3d_scale).is_equal(1.0)
	assert_int(card.msaa_3d).is_equal(Viewport.MSAA_DISABLED)


func test_low_applies_to_the_field_environment_and_sun() -> void:
	var field: Node3D = _field()
	var we: WorldEnvironment = field.get_node("Environment")
	var shared := we.environment
	var sun: DirectionalLight3D = field.get_node("Sun")
	GraphicsScript.apply_node(we, _low())
	GraphicsScript.apply_node(sun, _low())
	assert_bool(we.environment.glow_enabled).is_false()
	assert_bool(we.environment.ssao_enabled).is_false()
	assert_bool(we.environment.ssr_enabled).is_false()
	assert_bool(we.environment.volumetric_fog_enabled).is_false()
	assert_float(we.environment.fog_density).is_equal_approx(0.0015 * 1.6, 0.00001)
	# Its own copy: the shared scene resource (and the next field instanced) stays high.
	assert_object(we.environment).is_not_same(shared)
	assert_bool(shared.glow_enabled).is_true()
	assert_bool(sun.shadow_enabled).is_true()
	assert_int(sun.directional_shadow_mode).is_equal(DirectionalLight3D.SHADOW_ORTHOGONAL)
	assert_float(sun.directional_shadow_max_distance).is_equal(22.0)
	# Once per node: entering the tree again does not apply twice.
	var density := we.environment.fog_density
	GraphicsScript.apply_node(we, _low())
	assert_float(we.environment.fog_density).is_equal(density)


func test_low_caps_the_far_plane_and_halves_particles() -> void:
	var cam := Camera3D.new()
	_nodes.append(cam)
	cam.far = 3000.0
	GraphicsScript.apply_node(cam, _low())
	assert_float(cam.far).is_equal(2000.0)
	var p := CPUParticles3D.new()
	_nodes.append(p)
	p.amount = 40
	GraphicsScript.apply_node(p, _low())
	assert_int(p.amount).is_equal(20)
	GraphicsScript.apply_node(p, _low())
	assert_int(p.amount).is_equal(20)


func _field() -> Node3D:
	var f: Node3D = load("res://scenes/levels/field.tscn").instantiate()
	_nodes.append(f)
	return f


# --- the bench -----------------------------------------------------------------

func test_bench_stats_avg_and_one_percent_low() -> void:
	var ms := PackedFloat32Array()
	for i in 99:
		ms.append(10.0)
	ms.append(100.0)
	var line := Bench.stats(ms)
	assert_str(line).contains("avg=91.7")
	assert_str(line).contains("low1=10.0")
	assert_str(line).contains("ft_max=100.00ms")


func test_bench_prints_windows_then_the_summary_and_quits() -> void:
	var b := Bench.new()
	_nodes.append(b)
	b.secs = 10.0
	b.warmup = 1.0
	var quits := [0]
	b.quit_fn = func() -> void: quits[0] += 1
	for i in 2000:
		b.step(16.0)
	assert_bool(b.done).is_true()
	assert_int(quits[0]).is_equal(1)
	assert_int(b.lines.size()).is_equal(3)   # t=5, t=10, the summary
	assert_str(b.lines[0]).starts_with("BENCH t=5 avg=")
	var re := RegEx.create_from_string("^BENCH avg=[0-9.]+ low1=[0-9.]+ .* tier=(high|low) ")
	assert_object(re.search(b.lines[2])).is_not_null()
	assert_str(b.lines[2]).contains("avg=62.5")


func test_a_frame_that_starts_in_the_warmup_is_not_counted() -> void:
	var b := Bench.new()
	_nodes.append(b)
	b.secs = 5.0
	b.warmup = 3.0
	b.quit_fn = func() -> void: pass
	b.step(2000.0)
	b.step(12000.0)   # the boot hitch, ending past the warm-up
	for i in 400:
		b.step(20.0)
	assert_bool(b.done).is_true()
	assert_str(b.lines[b.lines.size() - 1]).contains("ft_max=20.00ms")


func test_bench_is_a_sandboxed_run() -> void:
	assert_bool(RunSandbox.active(PackedStringArray(["--bench"]))).is_true()


## The real thing: the game booted with -- --bench plays, prints the summary and exits by itself.
func test_bench_mode_quits_by_itself() -> void:
	var out := []
	var code := OS.execute(OS.get_executable_path(), PackedStringArray(["--headless", "--path",
			ProjectSettings.globalize_path("res://"), "--", "--bench", "--bench-secs=2",
			"--bench-warmup=0.5", "--graphics=low"]), out, true)
	var text := "\n".join(out)
	assert_int(code).override_failure_message(text).is_equal(0)
	assert_str(text).contains("graphics: tier=low (flag)")
	var re := RegEx.create_from_string("(?m)^BENCH avg=[0-9.]+ low1=[0-9.]+ .*tier=low")
	assert_object(re.search(text)).override_failure_message(text).is_not_null()
	assert_str(text).not_contains("SCRIPT ERROR")
