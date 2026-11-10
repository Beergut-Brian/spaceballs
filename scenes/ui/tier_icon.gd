## A height tier as a picture, no numbers (GAME.md: "height strip: vertical, landmark pictures").
## Drawn in code from simple shapes so it stays crisp at any size: the HUD strip's blocks and the
## peak stamp both use it. `tier_id` is the TierData id (backyard .. space); `bg` fills a rounded
## block behind the picture (alpha 0 = picture only). Systems owns structure, Art may swap the
## drawings for painted icons any time.
class_name TierIcon
extends Control

const IDS: Array[StringName] = [&"backyard", &"rooftops", &"treetops", &"kites", &"clouds",
		&"thin_air", &"edge", &"space"]
const INK := Color(0.12, 0.14, 0.22)
const WHITE := Color(1, 1, 1)

@export var tier_id: StringName = &"backyard":
	set(v):
		tier_id = v
		queue_redraw()
@export var bg := Color(0, 0, 0, 0):
	set(v):
		bg = v
		queue_redraw()
## Round badge (the stamp) instead of a rounded block.
@export var round_badge := false:
	set(v):
		round_badge = v
		queue_redraw()
@export var ring := Color(0, 0, 0, 0):
	set(v):
		ring = v
		queue_redraw()

var _s := 1.0
var _o := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


## Every tier id has a drawing (tests).
static func has_picture(id: StringName) -> bool:
	return IDS.has(id)


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	if round_badge:
		var c := size * 0.5
		var rad := minf(size.x, size.y) * 0.5
		if ring.a > 0.0:
			draw_circle(c, rad, ring)
		if bg.a > 0.0:
			draw_circle(c, rad * 0.88, bg)
	elif bg.a > 0.0:
		var sb := StyleBoxFlat.new()
		sb.bg_color = bg
		sb.set_corner_radius_all(int(minf(size.x, size.y) * 0.18))
		draw_style_box(sb, r)
	# A square drawing area in the middle, 0..1 coordinates.
	var side := minf(size.x, size.y) * (0.7 if round_badge else 0.86)
	_s = side
	_o = (size - Vector2(side, side)) * 0.5
	match tier_id:
		&"backyard": _backyard()
		&"rooftops": _rooftops()
		&"treetops": _treetops()
		&"kites": _kites()
		&"clouds": _clouds()
		&"thin_air": _thin_air()
		&"edge": _edge()
		&"space": _space()


# --- helpers (0..1 space) ----------------------------------------------------------

func _p(x: float, y: float) -> Vector2:
	return _o + Vector2(x, y) * _s


func _poly(pts: Array, col: Color, outline := true) -> void:
	var a := PackedVector2Array()
	for q in pts:
		a.append(_p(q.x, q.y))
	if outline:
		var closed := a.duplicate()
		closed.append(a[0])
		draw_polyline(closed, INK, maxf(_s * 0.035, 1.5), true)
	draw_colored_polygon(a, col)


func _dot(x: float, y: float, r: float, col: Color, outline := true) -> void:
	if outline:
		draw_circle(_p(x, y), r * _s + maxf(_s * 0.025, 1.0), INK)
	draw_circle(_p(x, y), r * _s, col)


func _line(a: Vector2, b: Vector2, col: Color, w: float) -> void:
	draw_line(_p(a.x, a.y), _p(b.x, b.y), col, maxf(w * _s, 1.0), true)


func _box(x: float, y: float, w: float, h: float, col: Color) -> void:
	_poly([Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h)], col)


# --- the eight pictures -----------------------------------------------------------

## A picket fence on grass.
func _backyard() -> void:
	_box(0.0, 0.78, 1.0, 0.22, Color(0.36, 0.78, 0.36))
	for i in 4:
		var x := 0.1 + i * 0.22
		_poly([Vector2(x, 0.36), Vector2(x + 0.08, 0.26), Vector2(x + 0.16, 0.36),
				Vector2(x + 0.16, 0.84), Vector2(x, 0.84)], WHITE)
	_box(0.02, 0.48, 0.96, 0.08, WHITE)


## A house with a chimney and a cat on top.
func _rooftops() -> void:
	_box(0.62, 0.22, 0.12, 0.24, Color(0.75, 0.4, 0.3))
	_poly([Vector2(0.08, 0.55), Vector2(0.5, 0.2), Vector2(0.92, 0.55)], Color(0.55, 0.45, 0.85))
	_box(0.18, 0.55, 0.64, 0.38, Color(0.98, 0.9, 0.78))
	_box(0.42, 0.68, 0.16, 0.25, Color(0.45, 0.3, 0.6))
	# The cat: body, head, two ears.
	_dot(0.68, 0.15, 0.065, Color(1.0, 0.6, 0.2))
	_poly([Vector2(0.62, 0.11), Vector2(0.63, 0.03), Vector2(0.67, 0.09)], Color(1.0, 0.6, 0.2), false)
	_poly([Vector2(0.69, 0.09), Vector2(0.73, 0.03), Vector2(0.74, 0.11)], Color(1.0, 0.6, 0.2), false)


## A round tree and a bird flying past.
func _treetops() -> void:
	_box(0.42, 0.62, 0.14, 0.34, Color(0.55, 0.36, 0.22))
	_dot(0.36, 0.5, 0.2, Color(0.25, 0.75, 0.45))
	_dot(0.62, 0.46, 0.22, Color(0.3, 0.82, 0.5))
	_dot(0.48, 0.3, 0.2, Color(0.35, 0.88, 0.55))
	var gull := PackedVector2Array()
	for q in [Vector2(0.6, 0.12), Vector2(0.68, 0.19), Vector2(0.75, 0.13), Vector2(0.82, 0.19), Vector2(0.9, 0.12)]:
		gull.append(_p(q.x, q.y))
	draw_polyline(gull, INK, maxf(0.045 * _s, 1.5), true)


## A striped hot-air balloon and its basket.
func _kites() -> void:
	_line(Vector2(0.36, 0.62), Vector2(0.44, 0.8), INK, 0.03)
	_line(Vector2(0.64, 0.62), Vector2(0.56, 0.8), INK, 0.03)
	_dot(0.5, 0.38, 0.3, Color(0.95, 0.35, 0.4))
	_poly([Vector2(0.42, 0.1), Vector2(0.58, 0.1), Vector2(0.6, 0.66), Vector2(0.4, 0.66)], Color(1.0, 0.85, 0.3), false)
	_box(0.42, 0.8, 0.16, 0.13, Color(0.6, 0.4, 0.25))


## A fluffy cloud and a little propeller plane.
func _clouds() -> void:
	var puffs := [Vector3(0.3, 0.68, 0.16), Vector3(0.52, 0.6, 0.2), Vector3(0.72, 0.7, 0.14)]
	for q in puffs:   # the outline first, then one white fill, so no seams inside the cloud
		draw_circle(_p(q.x, q.y), q.z * _s + maxf(_s * 0.025, 1.0), INK)
	draw_rect(Rect2(_p(0.22, 0.7) - Vector2(0, _s * 0.025), Vector2(0.52, 0.17) * _s), INK)
	for q in puffs:
		draw_circle(_p(q.x, q.y), q.z * _s, WHITE)
	draw_rect(Rect2(_p(0.24, 0.66), Vector2(0.48, 0.18) * _s), WHITE)
	# The plane.
	_poly([Vector2(0.18, 0.22), Vector2(0.62, 0.22), Vector2(0.7, 0.28), Vector2(0.62, 0.34),
			Vector2(0.18, 0.34)], Color(0.95, 0.75, 0.25))
	_poly([Vector2(0.36, 0.28), Vector2(0.48, 0.28), Vector2(0.4, 0.46), Vector2(0.3, 0.46)], Color(0.9, 0.4, 0.3))
	_poly([Vector2(0.14, 0.12), Vector2(0.24, 0.12), Vector2(0.26, 0.24), Vector2(0.16, 0.24)], Color(0.9, 0.4, 0.3))
	_line(Vector2(0.73, 0.18), Vector2(0.73, 0.38), INK, 0.04)


## A jet and a lost party balloon.
func _thin_air() -> void:
	_poly([Vector2(0.06, 0.42), Vector2(0.7, 0.36), Vector2(0.86, 0.42), Vector2(0.7, 0.48)], Color(0.92, 0.94, 0.98))
	_poly([Vector2(0.36, 0.42), Vector2(0.56, 0.42), Vector2(0.3, 0.68), Vector2(0.22, 0.68)], Color(0.7, 0.78, 0.9))
	_poly([Vector2(0.08, 0.42), Vector2(0.18, 0.42), Vector2(0.1, 0.26), Vector2(0.04, 0.26)], Color(0.7, 0.78, 0.9))
	_line(Vector2(0.78, 0.86), Vector2(0.8, 0.98), INK, 0.025)
	_dot(0.78, 0.76, 0.1, Color(0.98, 0.35, 0.6))


## A satellite with two solar panels and a ribbon of aurora.
func _edge() -> void:
	var aur := PackedVector2Array()
	for i in 9:
		aur.append(_p(i / 8.0, 0.86 + sin(i * 0.9) * 0.05))
	draw_polyline(aur, Color(0.45, 1.0, 0.7, 0.9), maxf(_s * 0.08, 2.0), true)
	_box(0.04, 0.34, 0.28, 0.2, Color(0.3, 0.5, 0.95))
	_box(0.68, 0.34, 0.28, 0.2, Color(0.3, 0.5, 0.95))
	_line(Vector2(0.32, 0.44), Vector2(0.68, 0.44), INK, 0.04)
	_box(0.38, 0.3, 0.24, 0.28, Color(0.85, 0.85, 0.9))
	_line(Vector2(0.5, 0.3), Vector2(0.5, 0.14), INK, 0.035)
	_dot(0.5, 0.12, 0.045, Color(1.0, 0.4, 0.4))


## The Moon, stars, and a little green alien waving.
func _space() -> void:
	for st in [Vector2(0.12, 0.14), Vector2(0.86, 0.2), Vector2(0.18, 0.62), Vector2(0.9, 0.7), Vector2(0.5, 0.08)]:
		_star(st, 0.05)
	_dot(0.62, 0.42, 0.24, Color(0.92, 0.92, 0.85))
	_dot(0.55, 0.36, 0.05, Color(0.75, 0.75, 0.7), false)
	_dot(0.7, 0.5, 0.04, Color(0.75, 0.75, 0.7), false)
	# The alien: head, eyes, waving arm.
	_dot(0.28, 0.8, 0.12, Color(0.45, 0.9, 0.4))
	_dot(0.24, 0.78, 0.03, INK, false)
	_dot(0.32, 0.78, 0.03, INK, false)
	_line(Vector2(0.38, 0.84), Vector2(0.46, 0.66), Color(0.45, 0.9, 0.4), 0.05)


func _star(c: Vector2, r: float) -> void:
	var pts := []
	for i in 8:
		var a := i * TAU / 8.0 - PI * 0.5
		var rr := r if i % 2 == 0 else r * 0.4
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	_poly(pts, Color(1.0, 0.95, 0.5), false)
