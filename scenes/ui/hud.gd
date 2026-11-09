## HUD: vertical height strip (8 tier blocks, no numbers), a ball marker per player,
## the profile's best-height flag, and the round counter as a stack of small balls.
## Systems owns structure, Art the look (swap the blocks for landmark pictures).
extends Control

const P1 := 0
const P2 := 1
const MARKER := 34.0

var _balls := {}
var _tiers: TierSet

@onready var strip: Control = $Strip
@onready var blocks: VBoxContainer = $Strip/Blocks
@onready var markers := {P1: $Strip/Markers/P1, P2: $Strip/Markers/P2}
@onready var best_flag: Control = $Strip/BestFlag
@onready var rounds: VBoxContainer = $Rounds
@onready var restart_hint: Control = $RestartHint


func _ready() -> void:
	_tiers = load(Run.TIERS_PATH)
	for i in range(_tiers.tiers.size() - 1, -1, -1):
		var b := ColorRect.new()
		b.color = _tiers.tiers[i].color
		b.size_flags_vertical = Control.SIZE_EXPAND_FILL
		b.name = String(_tiers.tiers[i].id)
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		blocks.add_child(b)
	for p in markers:
		_style_circle(markers[p], Players.COLOR[p], MARKER)
	_style_circle(restart_hint, Color(1, 0.84, 0.2, 0.9), 60.0)
	restart_hint.modulate.a = 0.0
	Run.ball_stopped.connect(_on_ball_stopped)
	Run.ball_tier_reached.connect(_on_tier)
	Run.reached_space.connect(func(p: int) -> void: Fx.flash(markers[p], Color(1, 1, 0.6)))
	Game.round_started.connect(func(_i: int) -> void: _refresh_rounds())
	Game.restart_armed.connect(_on_restart_armed)
	_refresh_rounds()


func track(player: int, ball: Node3D) -> void:
	_balls[player] = ball


func _process(_delta: float) -> void:
	var h := strip.size.y
	for p in markers:
		var m: Control = markers[p]
		m.visible = Run.in_run(p) or Run.in_space(p)
		var height := Run.last_height(p)
		var ball: Node3D = _balls.get(p)
		if ball and Run.phase_player() == p and Run.phase in [Run.Phase.FLIGHT_P1, Run.Phase.FLIGHT_P2]:
			height = ball.get("height")
		if Run.in_space(p):
			height = _tiers.space_height()
		var y := h * (1.0 - _tiers.ladder_fraction(height)) - MARKER * 0.5
		m.position = Vector2((-MARKER - 6.0) if p == P1 else (strip.size.x + 6.0), y)
	var best := float(Save.get_value("best_height", 0.0))
	best_flag.visible = best > 0.0
	best_flag.position.y = h * (1.0 - _tiers.ladder_fraction(best)) - 12.0


func _on_tier(player: int, tier: int) -> void:
	var b := blocks.get_child(_tiers.tiers.size() - tier) as CanvasItem
	Fx.flash(b)
	Fx.flash(markers[player])


func _on_ball_stopped(player: int, _h: float, _t: int) -> void:
	Fx.flash(markers[player], Color(1, 1, 0.8))


func _on_restart_armed() -> void:
	restart_hint.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_property(restart_hint, "rotation", -TAU, 1.0).from(0.0)
	tw.parallel().tween_property(restart_hint, "modulate:a", 0.0, 1.0).set_delay(0.3)


func _refresh_rounds() -> void:
	for c in rounds.get_children():
		c.queue_free()
	for i in Run.round_index:
		var ball := Panel.new()
		ball.custom_minimum_size = Vector2(28, 28)
		_style_circle(ball, Color(1, 1, 1, 0.95), 28.0)
		ball.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rounds.add_child(ball)
		if i == Run.round_index - 1:
			ball.scale = Vector2.ONE * 0.1
			ball.pivot_offset = Vector2(14, 14)
			ball.create_tween().tween_property(ball, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK)


static func _style_circle(c: Control, color: Color, d: float) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(int(d * 0.5))
	sb.border_color = Color(1, 1, 1, 0.9)
	sb.set_border_width_all(3)
	c.add_theme_stylebox_override("panel", sb)
	c.size = Vector2(d, d)
