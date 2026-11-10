## One player's spot in the lobby: a big panel in the player's colour. Empty: dim, with a pulsing
## "press" button. Joined: half lit. Ready: fully lit with a tick. `hold` (0..1) fills a ring
## round the button while that player holds A to start alone. Drawn in code, no text.
extends Control

@export var player: int = 0
## Below 1 the panel is see-through, for games that stand their real characters behind it.
@export_range(0.0, 1.0) var fill_alpha := 1.0

var joined := false:
	set(v):
		joined = v
		queue_redraw()
var readied := false:
	set(v):
		if v and not readied:
			_pop()
		readied = v
		queue_redraw()
var hold := 0.0:
	set(v):
		hold = clampf(v, 0.0, 1.0)
		queue_redraw()

var _t := 0.0


func _ready() -> void:
	pivot_offset = size * 0.5


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _pop() -> void:
	var tw := create_tween()
	scale = Vector2.ONE * 1.08
	tw.tween_property(self, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _draw() -> void:
	var col: Color = Players.COLOR[player]
	var rect := Rect2(Vector2.ZERO, size)
	var fill := col.darkened(0.8)
	if readied:
		fill = col
	elif joined:
		fill = col.darkened(0.45)
	fill.a *= fill_alpha
	_round_rect(rect, 36.0, fill)
	var border := Color.WHITE if readied else col
	_round_rect_outline(rect, 36.0, border, 14.0 if readied else 10.0)
	# The button hint at the bottom: pulses until ready, with the hold ring round it.
	var bc := Vector2(size.x * 0.5, size.y - 110.0)
	var br := 64.0
	if not readied:
		var push := absf(sin(_t * 3.0)) * 10.0
		draw_circle(bc + Vector2(0, 8), br, Color(0, 0, 0, 0.35))
		draw_circle(bc + Vector2(0, push - 4), br, col.lightened(0.25))
		draw_circle(bc + Vector2(0, push - 4), br, Color.WHITE, false, 6.0, true)
	else:
		# The tick: ready.
		var k := 44.0
		draw_polyline(PackedVector2Array([bc + Vector2(-k, 0), bc + Vector2(-k * 0.25, k * 0.7),
				bc + Vector2(k, -k * 0.7)]), Color.WHITE, 22.0, true)
	if hold > 0.0:
		draw_arc(bc, br + 26.0, -PI / 2, -PI / 2 + TAU, 48, Color(0, 0, 0, 0.4), 20.0, true)
		draw_arc(bc, br + 26.0, -PI / 2, -PI / 2 + TAU * hold, 48, Color.WHITE, 20.0, true)


func _round_rect(r: Rect2, radius: float, c: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(int(radius))
	draw_style_box(sb, r)


func _round_rect_outline(r: Rect2, radius: float, c: Color, w: float) -> void:
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.border_color = c
	sb.set_border_width_all(int(w))
	sb.set_corner_radius_all(int(radius))
	draw_style_box(sb, r)
