## A big round icon button for menus, drawn in code, no text. The menu that owns it moves the
## focus and presses it; this only draws (and pops when pressed).
## Art lane: swap `texture` in for the drawn icon, keep the node.
@tool
extends Control

enum Icon { PLAY, RESTART, DOOR }

@export var icon: Icon = Icon.PLAY:
	set(v):
		icon = v
		queue_redraw()
@export var texture: Texture2D:
	set(v):
		texture = v
		queue_redraw()
@export var tint := Color("ffd84d")

var focused := false:
	set(v):
		if v == focused:
			return
		focused = v
		_bounce(1.15 if v else 1.0)
		queue_redraw()

var _t := 0.0


func _ready() -> void:
	pivot_offset = size * 0.5
	resized.connect(func() -> void: pivot_offset = size * 0.5)


func _process(delta: float) -> void:
	if focused and not Engine.is_editor_hint():
		_t += delta
		rotation = sin(_t * 4.0) * 0.04


func press() -> void:
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2.ONE * 0.85, 0.06)
	tw.tween_property(self, "scale", Vector2.ONE * (1.15 if focused else 1.0), 0.18) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _bounce(to: float) -> void:
	rotation = 0.0
	if not is_inside_tree():
		scale = Vector2.ONE * to
		return
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2.ONE * to, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5
	if focused:
		draw_circle(c, r, Color.WHITE)
		draw_circle(c, r * 0.88, tint)
	else:
		draw_circle(c, r * 0.88, tint.darkened(0.45))
	var ink := Color("1e1e26") if focused else Color(1, 1, 1, 0.7)
	if texture:
		var s := r * 1.1
		draw_texture_rect(texture, Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)), false)
		return
	match icon:
		Icon.PLAY:
			var k := r * 0.45
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(-k * 0.7, -k), c + Vector2(k, 0), c + Vector2(-k * 0.7, k)]), ink)
		Icon.RESTART:
			var k := r * 0.42
			draw_arc(c, k, deg_to_rad(-60), deg_to_rad(230), 32, ink, r * 0.14, true)
			var tip := c + Vector2.from_angle(deg_to_rad(-60)) * k
			draw_colored_polygon(PackedVector2Array([
				tip + Vector2(-r * 0.2, -r * 0.12), tip + Vector2(r * 0.16, -r * 0.2),
				tip + Vector2(r * 0.06, r * 0.2)]), ink)
		Icon.DOOR:
			var w := r * 0.62
			var h := r * 0.95
			var tl := c - Vector2(w, h) * 0.5
			draw_rect(Rect2(tl - Vector2(r * 0.07, r * 0.07), Vector2(w, h) + Vector2(r * 0.14, r * 0.07)), ink)
			var panel := Color("8a5a2b") if focused else tint.darkened(0.2)
			draw_rect(Rect2(tl + Vector2(r * 0.05, r * 0.05), Vector2(w - r * 0.1, h - r * 0.05)), panel)
			draw_circle(tl + Vector2(w * 0.75, h * 0.55), r * 0.07, ink)
