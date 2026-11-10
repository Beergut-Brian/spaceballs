## Regenerates assets/ui/theme.tres from scenes/ui/kit/ui_style.gd. Run after changing UiStyle:
##   godot --headless --path . -s scripts/tools/build_theme.gd
extends SceneTree


func _init() -> void:
	var style: GDScript = load("res://scenes/ui/kit/ui_style.gd")
	var err := ResourceSaver.save(style.build_theme(), "res://assets/ui/theme.tres")
	print("theme: ", "res://assets/ui/theme.tres" if err == OK else "failed (%d)" % err)
	quit(0 if err == OK else 1)
