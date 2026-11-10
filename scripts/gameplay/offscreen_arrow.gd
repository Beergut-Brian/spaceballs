## The bystander can leave the shot (the camera frames only the kicker): while he is off-screen,
## a small arrow in his colour sits at the screen edge pointing at him. Gameplay lane.
class_name OffscreenArrow
extends Control

const MARGIN := 56.0
## Keeps clear of the HUD's height ladder down the right edge.
const RIGHT_MARGIN := 190.0
const SIZE := 30.0

var target: Node3D
var color := Color.WHITE
var _t := 0.0
## Where the arrow sits this frame (screen px), or null while the target is on screen.
var at: Variant = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_for(who: Node3D, c: Color) -> void:
	target = who
	color = c
	visible = true


func hide_arrow() -> void:
	target = null
	at = null
	visible = false


func _process(delta: float) -> void:
	_t += delta
	at = _edge_point()
	queue_redraw()


## Null while `target` is in shot, else the point on the screen edge toward it.
func _edge_point() -> Variant:
	var cam := get_viewport().get_camera_3d()
	if not is_instance_valid(target) or cam == null or not target.is_visible_in_tree():
		return null
	var world := target.global_position + Vector3.UP * 0.9
	var rect := get_viewport_rect()
	var behind := cam.is_position_behind(world)
	var sp := cam.unproject_position(world)
	if not behind and rect.grow(-12.0).has_point(sp):
		return null
	var c := rect.size * 0.5
	var d := sp - c
	if behind:
		d = -d
	if d.length() < 0.01:
		d = Vector2.DOWN
	var inner_x := (c.x - RIGHT_MARGIN) if d.x > 0.0 else (c.x - MARGIN)
	var k := minf(inner_x / maxf(absf(d.x), 0.001), (c.y - MARGIN) / maxf(absf(d.y), 0.001))
	return c + d * k


func _draw() -> void:
	if at == null:
		return
	var p: Vector2 = at
	var dir := (p - get_viewport_rect().size * 0.5).normalized()
	var s := SIZE * (1.0 + 0.08 * sin(_t * 6.0))
	var side := dir.orthogonal()
	var tip := p + dir * s
	var pts := PackedVector2Array([tip, p - dir * s * 0.5 + side * s * 0.8, p - dir * s * 0.5 - side * s * 0.8])
	var outline := PackedVector2Array([tip + dir * 5.0, pts[1] + (pts[1] - p).normalized() * 5.0,
			pts[2] + (pts[2] - p).normalized() * 5.0])
	draw_colored_polygon(outline, Color.WHITE)
	draw_colored_polygon(pts, color)
