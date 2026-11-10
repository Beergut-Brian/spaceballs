## Art QA helper, dormant unless the game runs with `-- --art-shots=<dir>`: saves a PNG at the moments
## Art needs to check (wind-up, contact, every first tier crossing, peaks, frog, pick, end card) and
## quits after the end card. Use with --demo --timescale=4 through godot-render (see handoff report).
extends Node

var _dir := ""
var _seen := {}


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--art-shots="):
			_dir = arg.trim_prefix("--art-shots=")
	if _dir == "":
		queue_free()
		return
	DirAccess.make_dir_recursive_absolute(_dir)
	var run := get_node("/root/Run")
	run.kick_started.connect(func(p: int) -> void:
		var frog: bool = _kicker(p).get("frog")
		_shot("frog_p%d" % p if frog else "windup_p%d" % p, 0.35))
	run.kicked.connect(func(p: int, _pw: float) -> void: _shot("contact_p%d" % p, 0.03))
	run.ball_tier_reached.connect(func(_p: int, t: int) -> void:
		_shot("tier%d_cross" % t, 0.12)
		_shot("tier%d_flight" % t, 0.6))
	run.ball_stopped.connect(func(_p: int, _h: float, t: int) -> void: _shot("peak_tier%d" % t, 0.3))
	run.phase_changed.connect(func(_f: int, to: int) -> void:
		if to == 5:   # PICK
			_shot("pick", 0.25)
		elif to == 6:   # END
			_shot("end_a", 1.5)
			_shot("end_b", 2.5)
			get_tree().create_timer(5.0).timeout.connect(func() -> void: get_node("/root/Game").quit()))
	get_node("/root/Run").reached_space.connect(func(p: int) -> void: _shot("space_p%d" % p, 1.0))


func _shot(tag: String, delay: float) -> void:
	if _seen.has(tag):
		return
	_seen[tag] = true
	await get_tree().create_timer(delay).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [_dir, tag]
	img.save_png(path)
	print("artshot: %s  draws=%d prims=%d objects=%d" % [path,
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)])


func _kicker(p: int) -> Node:
	var scene := get_tree().current_scene
	return scene.get_node_or_null("Kickers/P%d" % (p + 1)) if scene else null
