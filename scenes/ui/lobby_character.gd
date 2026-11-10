## Placeholder lobby character: a box with a head and an arm that waves. Games swap this node for
## their own character; the lobby calls set_joined(on) and wave() on whatever sits here.
extends Control

@export var player: int = 0

var _joined := false
var _arm := 0.3
var _tw: Tween


func set_joined(on: bool) -> void:
	_joined = on
	queue_redraw()


func wave() -> void:
	if _tw:
		_tw.kill()
	_tw = create_tween()
	for i in 3:
		_tw.tween_method(_set_arm, 0.3, -0.9, 0.14)
		_tw.tween_method(_set_arm, -0.9, 0.3, 0.14)


func _set_arm(a: float) -> void:
	_arm = a
	queue_redraw()


func _draw() -> void:
	# Lighter than the spot behind it so it reads on a lit panel.
	var col: Color = Players.COLOR[player].lightened(0.55)
	if not _joined:
		col = Color(1, 1, 1, 0.12)
	var w := size.x
	var h := size.y
	var body := Rect2(w * 0.28, h * 0.42, w * 0.44, h * 0.58)
	var ink := Color("1e1e26") if _joined else Color(1, 1, 1, 0.12)
	# Arm: from the shoulder, raised when waving.
	var shoulder := Vector2(w * 0.7, h * 0.5)
	var hand := shoulder + Vector2.from_angle(_arm - PI / 2 + 0.9) * h * 0.32
	draw_line(shoulder, hand, ink, w * 0.13 + 8.0, true)
	draw_line(shoulder, hand, col, w * 0.13, true)
	draw_circle(hand, w * 0.09 + 4.0, ink)
	draw_circle(hand, w * 0.09, col)
	draw_rect(body.grow(6.0), ink)
	draw_rect(body, col)
	var head := Vector2(w * 0.5, h * 0.24)
	draw_circle(head, w * 0.2 + 6.0, ink)
	draw_circle(head, w * 0.2, col)
	if _joined:
		draw_circle(head + Vector2(-w * 0.07, -h * 0.01), w * 0.035, ink)
		draw_circle(head + Vector2(w * 0.07, -h * 0.01), w * 0.035, ink)
		draw_arc(head + Vector2(0, h * 0.03), w * 0.08, 0.2, PI - 0.2, 12, ink, 5.0, true)
