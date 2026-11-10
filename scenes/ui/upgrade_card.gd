## One big icon card, no text. Systems owns the structure, Art the theme (StyleBox, glow).
## The kind reads from the card's back, never from text: normal is clean ice, strong has gold trim and a
## turning sunburst, joke is scattered with confetti, curse is a tempting violet full of twinkles.
## Player colours are only ever the highlight border.
extends PanelContainer

const INSET := 14.0   # the widest highlight border: the kind's back is drawn inside it
const LOOK := {
	"normal": {"edge": Color("eef8ff"), "back": Color("c9e8ff"), "trim": Color(1, 1, 1, 0.6),
		"glow": Color(0, 0, 0, 0.25), "glow_size": 8},
	"strong": {"edge": Color("ffc93c"), "back": Color("fff0b0"), "trim": Color("e89a00"),
		"glow": Color(1.0, 0.8, 0.2, 0.75), "glow_size": 20},
	"joke": {"edge": Color("ffffff"), "back": Color("ffe6f5"), "trim": Color(1, 1, 1, 0.6),
		"glow": Color(0, 0, 0, 0.25), "glow_size": 8},
	"curse": {"edge": Color("2e1470"), "back": Color("6628ff"), "trim": Color("ff4fd8"),
		"glow": Color(0.8, 0.3, 1.0, 0.7), "glow_size": 16},
}
const CONFETTI: Array[Color] = [Color("38c6ff"), Color("ff4fd8"), Color("ffd84d"), Color("1cc9a6"),
	Color("ff9f2e"), Color("7a6cff")]
const TWINKLES: Array[Color] = [Color("ffffff"), Color("ff8ee6"), Color("ffd84d")]

var upgrade: UpgradeData
var _style: StyleBoxFlat
var _back := StyleBoxFlat.new()
var _look: Dictionary = LOOK["normal"]
## Confetti and twinkles: [unit position, angle, phase], the same for a card every time it is drawn.
var _bits: Array = []
var _t := 0.0
var bounce := false
var highlighted := false

@onready var icon: TextureRect = $Icon


func _ready() -> void:
	_style = (get_theme_stylebox("panel") as StyleBoxFlat).duplicate()
	add_theme_stylebox_override("panel", _style)
	_back.set_corner_radius_all(16)
	pivot_offset = size * 0.5
	resized.connect(func() -> void: pivot_offset = size * 0.5)


func set_upgrade(u: UpgradeData) -> void:
	upgrade = u
	icon.texture = u.icon if u else null
	visible = u != null
	modulate = Color.WHITE
	scale = Vector2.ONE
	_look = LOOK.get(u.kind if u else "normal", LOOK["normal"])
	_style.bg_color = _look["edge"]
	_style.shadow_color = _look["glow"]
	_style.shadow_size = _look["glow_size"]
	_scatter()
	set_highlight(highlighted, _style.border_color)
	queue_redraw()


func set_highlight(on: bool, color: Color) -> void:
	highlighted = on
	_style.border_color = color if on else _look["trim"]
	_style.set_border_width_all(14 if on else 4)


## Confetti and twinkles keep to the top, the bottom and the corners: the middle belongs to the icon.
func _scatter() -> void:
	_bits.clear()
	if upgrade == null or (upgrade.kind != "joke" and upgrade.kind != "curse"):
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(upgrade.id)
	while _bits.size() < (26 if upgrade.kind == "joke" else 14):
		var p := Vector2(rng.randf_range(0.05, 0.95), rng.randf_range(0.04, 0.96))
		var d := (p - Vector2(0.5, 0.5)) / Vector2(0.52, 0.36)
		if d.length() > 1.0:
			_bits.append([p, rng.randf() * TAU, rng.randf() * TAU])


func _draw() -> void:
	if upgrade == null:
		return
	var r := Rect2(Vector2.ZERO, size).grow(-INSET)
	var c := size * 0.5
	var rad := minf(r.size.x, r.size.y) * 0.5
	_back.bg_color = _look["back"]
	_back.border_color = _look["trim"]
	_back.set_border_width_all(6 if upgrade.kind == "strong" else 0)
	draw_style_box(_back, r)
	match upgrade.kind:
		"strong":
			for i in 12:
				var a := TAU * i / 12.0 + _t * 0.3
				draw_colored_polygon(PackedVector2Array([c, c + Vector2.from_angle(a - 0.13) * rad * 0.93,
						c + Vector2.from_angle(a + 0.13) * rad * 0.93]), Color(1.0, 0.76, 0.2, 0.6))
			draw_circle(c, rad * 0.62, Color(1.0, 0.98, 0.86, 0.8))
		"joke":
			draw_circle(c, rad * 0.86, Color(1, 1, 1, 0.6))
			for i in _bits.size():
				var bit: Array = _bits[i]
				draw_set_transform(r.position + bit[0] * r.size, bit[1] + sin(_t * 2.0 + bit[2]) * 0.5)
				if i % 3 == 0:
					draw_circle(Vector2.ZERO, 6.0, CONFETTI[i % CONFETTI.size()])
				else:
					draw_rect(Rect2(-9, -4.5, 18, 9), CONFETTI[i % CONFETTI.size()])
			draw_set_transform(Vector2.ZERO)
		"curse":
			draw_circle(c, rad * 0.95, Color(0.85, 0.5, 1.0, 0.28))
			draw_circle(c, rad * 0.68, Color(1.0, 0.78, 1.0, 0.3))
			for i in _bits.size():
				var bit: Array = _bits[i]
				var s := 5.0 + 11.0 * (0.5 + 0.5 * sin(_t * 3.0 + bit[2]))
				var pts := PackedVector2Array()
				for k in 8:
					pts.append(r.position + bit[0] * r.size
							+ Vector2.from_angle(TAU * k / 8.0) * (s if k % 2 == 0 else s * 0.3))
				draw_colored_polygon(pts, TWINKLES[i % TWINKLES.size()])
		_:
			draw_circle(c, rad * 0.86, Color(1, 1, 1, 0.55))


func _process(delta: float) -> void:
	_t += delta
	var target := 1.15 if highlighted else 0.95
	if bounce and highlighted:
		target += absf(sin(_t * 5.0)) * 0.12
	scale = scale.lerp(Vector2.ONE * target, clampf(delta * 12.0, 0.0, 1.0))
	# Curses look tempting: the twinkles on the back do the work, the icon only breathes a little.
	if upgrade and upgrade.is_curse():
		icon.modulate = Color(1, 1, 1).lerp(Color(1.15, 1.08, 1.2), 0.5 + 0.5 * sin(_t * 8.0))
	else:
		icon.modulate = Color.WHITE
	if upgrade and upgrade.kind != "normal":
		queue_redraw()
