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
## 1 right after a cheer, back to 0 over POP_TIME: the arrow jumps big and throws stars.
var _pop := 0.0
const POP_TIME := 0.6
const POP_STARS := 7
## Where the arrow sits this frame (screen px), or null while the target is on screen.
var at: Variant = null
## Where the target is on screen while he is in shot, else null.
var _sp: Variant = null


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
	_pop = 0.0
	visible = false


## The player it points at cheered. Off-screen: the arrow jumps and throws a fan of stars. In shot
## (often small and far, up on his cloud, or behind a canopy): a ring of stars bursts round him,
## drawn over the trees.
func pop() -> void:
	_pop = 1.0


func _process(delta: float) -> void:
	_t += delta
	_pop = maxf(0.0, _pop - delta / POP_TIME)
	at = _edge_point()
	queue_redraw()


## In the open part of the picture: not at the very edge, not under the HUD's height ladder (a
## player on his cloud sits up there behind it, gap-close-8).
static func in_view(sp: Vector2, size: Vector2) -> bool:
	return Rect2(Vector2(12.0, 12.0), size - Vector2(12.0 + RIGHT_MARGIN, 24.0)).has_point(sp)


## Null while `target` is in shot, else the point on the screen edge toward it.
func _edge_point() -> Variant:
	var cam := get_viewport().get_camera_3d()
	_sp = null
	if not is_instance_valid(target) or cam == null or not target.is_visible_in_tree():
		return null
	var world := target.global_position + Vector3.UP * 0.9
	var rect := get_viewport_rect()
	var behind := cam.is_position_behind(world)
	var sp := cam.unproject_position(world)
	_sp = null
	if not behind and in_view(sp, rect.size):
		_sp = sp
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
		if _pop > 0.0 and _sp != null:
			_draw_stars(_sp, Vector2.UP, TAU, 0.6)
		return
	var p: Vector2 = at
	var dir := (p - get_viewport_rect().size * 0.5).normalized()
	var jump := sin(_pop * PI) * 0.6 if _pop > 0.0 else 0.0
	var s := SIZE * (1.0 + 0.08 * sin(_t * 6.0) + jump)
	var side := dir.orthogonal()
	var tip := p + dir * s
	var pts := PackedVector2Array([tip, p - dir * s * 0.5 + side * s * 0.8, p - dir * s * 0.5 - side * s * 0.8])
	var outline := PackedVector2Array([tip + dir * 5.0, pts[1] + (pts[1] - p).normalized() * 5.0,
			pts[2] + (pts[2] - p).normalized() * 5.0])
	draw_colored_polygon(outline, Color.WHITE)
	draw_colored_polygon(pts, color)
	if _pop > 0.0:
		_draw_stars(p, dir, PI * 1.3, 1.0)


## A burst of stars from `p`: a fan of `spread` radians opening away from `dir` (the full ring for TAU).
func _draw_stars(p: Vector2, dir: Vector2, spread: float, reach: float) -> void:
	var out := 1.0 - _pop   # 0 at the cheer, 1 when they are gone
	var r := (40.0 + 150.0 * ease(out, 0.4)) * reach
	var a := clampf(_pop * 2.5, 0.0, 1.0)
	for i in POP_STARS:
		# A fan opening away from the screen edge, back toward the middle of the picture.
		var steps := POP_STARS if spread >= TAU else POP_STARS - 1
		var ang := (-dir).angle() + (float(i) / steps - 0.5) * spread
		var c := p + Vector2.from_angle(ang) * r
		var col := (Color(1.0, 0.92, 0.35) if i % 2 == 0 else color.lightened(0.3))
		_star(c, 22.0 * (0.7 + 0.3 * _pop), _t * 5.0 + i, Color(col, a))


func _star(c: Vector2, rad: float, spin: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 10:
		var rr := rad if k % 2 == 0 else rad * 0.45
		pts.append(c + Vector2.from_angle(spin + k * TAU / 10.0) * rr)
	draw_colored_polygon(pts, Color(1, 1, 1, col.a))
	var inner := PackedVector2Array()
	for q in pts:
		inner.append(c + (q - c) * 0.72)
	draw_colored_polygon(inner, col)
