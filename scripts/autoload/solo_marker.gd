## The solo-mode marker: two little heads (green and red), top-left (the HUD strip owns the right
## edge), no text.
## Pops and blinks when solo toggles; stays while it is on. Drawn in code, owned by Players.
extends CanvasLayer

const SIZE := Vector2(96, 64)
const MARGIN := 24.0

var _icon: Control


func _ready() -> void:
	layer = 99
	process_mode = Node.PROCESS_MODE_ALWAYS
	_icon = Control.new()
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.size = SIZE
	_icon.pivot_offset = SIZE * 0.5
	_icon.position = Vector2.ONE * MARGIN
	_icon.draw.connect(_draw_icon)
	_icon.visible = false
	add_child(_icon)


func show_solo(on: bool, animate: bool = true) -> void:
	if _icon == null:
		return
	if not animate:
		_icon.visible = on
		return
	_icon.visible = true
	_icon.scale = Vector2.ONE * 1.8
	var tw := _icon.create_tween()
	tw.tween_property(_icon, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Fx.flash(_icon, Color.WHITE)
	if not on:
		tw.tween_property(_icon, "modulate:a", 0.0, 0.4)
		tw.tween_callback(func() -> void:
			_icon.visible = false
			_icon.modulate = Color.WHITE)


func is_showing() -> bool:
	return _icon != null and _icon.visible


func _draw_icon() -> void:
	var c := _icon
	c.draw_rect(Rect2(Vector2.ZERO, SIZE), Color(0, 0, 0, 0.35))
	for i in 2:
		var col: Color = Players.COLOR[i]
		var x := SIZE.x * (0.3 + 0.4 * i)
		c.draw_circle(Vector2(x, SIZE.y * 0.36), 13.0, col)
		c.draw_circle(Vector2(x, SIZE.y * 0.36), 13.0, Color.WHITE, false, 2.5)
		c.draw_rect(Rect2(x - 16.0, SIZE.y * 0.62, 32.0, SIZE.y * 0.3), col)
