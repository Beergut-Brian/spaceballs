## One big icon card, no text. Systems owns the structure, Art the theme (StyleBox, glow).
extends PanelContainer

var upgrade: UpgradeData
var _style: StyleBoxFlat
var _t := 0.0
var bounce := false
var highlighted := false

@onready var icon: TextureRect = $Icon


func _ready() -> void:
	_style = (get_theme_stylebox("panel") as StyleBoxFlat).duplicate()
	add_theme_stylebox_override("panel", _style)
	pivot_offset = size * 0.5
	resized.connect(func() -> void: pivot_offset = size * 0.5)


func set_upgrade(u: UpgradeData) -> void:
	upgrade = u
	icon.texture = u.icon if u else null
	visible = u != null
	modulate = Color.WHITE
	scale = Vector2.ONE


func set_highlight(on: bool, color: Color) -> void:
	highlighted = on
	_style.border_color = color if on else Color(1, 1, 1, 0.6)
	_style.set_border_width_all(14 if on else 4)


func _process(delta: float) -> void:
	_t += delta
	var target := 1.15 if highlighted else 0.95
	if bounce and highlighted:
		target += absf(sin(_t * 5.0)) * 0.12
	scale = scale.lerp(Vector2.ONE * target, clampf(delta * 12.0, 0.0, 1.0))
	# Curses look tempting: a sparkle pulse.
	if upgrade and upgrade.is_curse():
		icon.modulate = Color(1, 1, 1).lerp(Color(1.6, 1.3, 1.8), 0.5 + 0.5 * sin(_t * 8.0))
	else:
		icon.modulate = Color.WHITE
