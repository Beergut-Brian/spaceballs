## F3 overlay, F12 screenshot, --screenshot-after=<s> for headless review. Autoload: Debug.
extends CanvasLayer

var _label: Label
var _shot_after := -1.0
var _log_phases := false


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_label = Label.new()
	_label.position = Vector2(16, 16)
	_label.add_theme_font_size_override("font_size", 20)
	_label.visible = false
	add_child(_label)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshot-after="):
			_shot_after = float(arg.trim_prefix("--screenshot-after="))
		elif arg == "--log-phases":
			_log_phases = true
	if _log_phases:
		Run.phase_changed.connect(func(_f, t) -> void:
			print("phase: round %d %s" % [Run.round_index, Run.Phase.keys()[t]]))
		Run.ball_stopped.connect(func(p, h, t) -> void:
			print("  ball P%d stopped at %.1f m, tier %d" % [p + 1, h, t]))
		Run.upgrade_picked.connect(func(p, id) -> void: print("  P%d picked %s" % [p + 1, id]))
		Run.reached_space.connect(func(p) -> void: print("  P%d reached space" % [p + 1]))


func _process(delta: float) -> void:
	if _label.visible:
		_label.text = "fps %d\nstate %s\nround %d\nplayers %s\nphase %s\npower %.1f / %.1f" % [
			Engine.get_frames_per_second(),
			Game.State.keys()[Game.state],
			Game.round_index,
			str(Players.active_players()),
			Run.Phase.keys()[Run.phase],
			Run.power_of(Players.P1), Run.power_of(Players.P2)]
	if _shot_after >= 0.0:
		_shot_after -= delta
		if _shot_after < 0.0:
			await screenshot()
			Game.quit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_overlay"):
		_label.visible = not _label.visible
	elif event.is_action_pressed("debug_screenshot"):
		screenshot()


func screenshot() -> String:
	if DisplayServer.get_name() == "headless":
		# No renderer: report state instead so the Reviewer still gets a signal of life.
		print("screenshot: headless, state=%s players=%s phase=%s round=%d" % [Game.State.keys()[Game.state],
				str(Players.active_players()), Run.Phase.keys()[Run.phase], Run.round_index])
		return ""
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("user://screenshots")
	var path := "user://screenshots/%s.png" % Time.get_datetime_string_from_system().replace(":", "-")
	img.save_png(path)
	print("screenshot: ", ProjectSettings.globalize_path(path))
	return path
