## HUD: vertical height strip (8 tier blocks, each a landmark picture on its sky colour, no
## numbers), a ball marker per player, the profile's best-height flag (it rides up with a ball
## that beats it), a pennant per player in their colour at their best peak this session, the tier stamp at every peak, and the round counter as a stack of small balls.
## Systems owns structure, Art the look (TierIcon draws the pictures).
extends Control

const P1 := 0
const P2 := 1
const MARKER := 34.0
## The peak stamp: a round badge of the tier reached, slammed in at the top of the screen.
const STAMP_SIZE := 220.0
const STAMP_HOLD := 1.1
## The best flag's x inside the strip (its pole is 24 px left of that).
const BEST_X := 30.0
## The session-best pennants: one per player in their colour, in that player's marker column
## (P1 left of the strip, P2 right), pointing outwards so the strip stays clear. The pole's foot
## is the height; the flag flies at its top, clear above that player's ball marker.
const PENNANT := Vector2(40, 30)
const PENNANT_POLE_H := 50.0
const PENNANT_POLE := 6.0

## Each player's highest peak since the game started (survives play-again; not saved).
static var session_best := {}

var _balls := {}
var _tiers: TierSet
## The profile's best when this flight started, and whether this flight has beaten it yet.
var _best_at_kick := 0.0
var _beaten := false
var stamp: TierIcon
var _stamp_tween: Tween
## Player -> the session-best pennant Control.
var pennants := {}

@onready var strip: Control = $Strip
@onready var blocks: VBoxContainer = $Strip/Blocks
@onready var markers := {P1: $Strip/Markers/P1, P2: $Strip/Markers/P2}
@onready var best_flag: Control = $Strip/BestFlag
## The round counter: one ball per round played, bottom-left (C-13: 28 px dots were easy to miss).
const ROUND_BALL := 44.0
@onready var rounds: VBoxContainer = $Rounds
@onready var restart_hint: Control = $RestartHint


func _ready() -> void:
	_tiers = load(Run.TIERS_PATH)
	for i in range(_tiers.tiers.size() - 1, -1, -1):
		var b := TierIcon.new()
		b.tier_id = _tiers.tiers[i].id
		b.bg = _tiers.tiers[i].color
		b.size_flags_vertical = Control.SIZE_EXPAND_FILL
		b.name = String(_tiers.tiers[i].id)
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		blocks.add_child(b)
	for p in markers:
		_style_circle(markers[p], Players.COLOR[p], MARKER)
	_style_circle(restart_hint, Color(1, 0.84, 0.2, 0.9), 60.0)
	restart_hint.modulate.a = 0.0
	Run.ball_stopped.connect(_on_ball_stopped)
	Run.kicked.connect(_on_kicked)
	# The best flag stands inside the strip (the ball markers sit either side of it) on a white line
	# right across it.
	var line := ColorRect.new()
	line.name = "Line"
	line.color = Color(1, 1, 1, 0.95)
	line.position = Vector2(-BEST_X, 9.5)
	line.size = Vector2(strip.size.x if strip.size.x > 0.0 else 90.0, 5.0)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	best_flag.add_child(line)
	best_flag.move_child(line, 0)
	for p in [P1, P2]:
		pennants[p] = _make_pennant(p)
	stamp = TierIcon.new()
	stamp.name = "Stamp"
	stamp.round_badge = true
	stamp.size = Vector2.ONE * STAMP_SIZE
	stamp.pivot_offset = stamp.size * 0.5
	stamp.visible = false
	add_child(stamp)
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
	var live := _live_height()
	if live > best and _best_at_kick > 0.0:
		if not _beaten:
			_beat_best()
		best = live   # the flag rides up with the ball that beat it
	best_flag.visible = best > 0.0
	best_flag.position = Vector2(BEST_X, h * (1.0 - _tiers.ladder_fraction(best)) - 12.0)
	for p in pennants:
		var pen: Control = pennants[p]
		var sb := float(session_best.get(p, 0.0))
		pen.visible = sb > 0.0
		pen.position = Vector2(-PENNANT_POLE if p == P1 else strip.size.x, h * (1.0 - _tiers.ladder_fraction(sb)) - PENNANT_POLE_H)


## A pole and a flag in the player's colour (white edge), pointing away from the strip.
func _make_pennant(p: int) -> Control:
	var pen := Control.new()
	pen.name = "SessionBest%d" % (p + 1)
	pen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pen.visible = false
	var dir := -1.0 if p == P1 else 1.0
	var pole := ColorRect.new()
	pole.color = Color.WHITE
	pole.size = Vector2(PENNANT_POLE, PENNANT_POLE_H)
	pole.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pen.add_child(pole)
	var x0 := 0.0 if p == P1 else PENNANT_POLE
	var edge := Polygon2D.new()
	edge.color = Color.WHITE
	edge.polygon = PackedVector2Array([Vector2(x0, -3), Vector2(x0 + dir * (PENNANT.x + 6.0), PENNANT.y * 0.5), Vector2(x0, PENNANT.y + 3)])
	pen.add_child(edge)
	var flag := Polygon2D.new()
	flag.name = "Flag"
	flag.color = Players.COLOR[p]
	flag.polygon = PackedVector2Array([Vector2(x0, 0), Vector2(x0 + dir * PENNANT.x, PENNANT.y * 0.5), Vector2(x0, PENNANT.y)])
	pen.add_child(flag)
	strip.add_child(pen)
	strip.move_child(pen, $Strip/Markers.get_index())   # under the ball markers
	return pen


## A peak above this player's session best moves their pennant up to it with a pop.
func note_peak(player: int, height: float) -> void:
	if height <= float(session_best.get(player, 0.0)):
		return
	session_best[player] = height
	var pen: Control = pennants.get(player)
	if pen == null:
		return
	Fx.flash(pen, Color(1, 1, 0.7))
	pen.pivot_offset = Vector2(0, PENNANT_POLE_H)   # grows from the foot of the pole
	pen.create_tween().tween_property(pen, "scale", Vector2.ONE, 0.35).from(Vector2.ONE * 1.6) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## The height of the ball in flight now, or 0 when nothing is flying.
func _live_height() -> float:
	var p := Run.phase_player()
	if p < 0 or not Run.phase in [Run.Phase.FLIGHT_P1, Run.Phase.FLIGHT_P2] or Run.curse_of(p) != null:
		return 0.0
	var ball: Node3D = _balls.get(p)
	return float(ball.get("height")) if ball else 0.0


func _on_kicked(_player: int, _power: float) -> void:
	_best_at_kick = float(Save.get_value("best_height", 0.0))
	_beaten = false


## A new best ever: the flag pops and flashes and goes up with the ball.
func _beat_best() -> void:
	_beaten = true
	Audio.play("tier_up", null, 1.8)
	Fx.flash(best_flag, Color(1, 1, 0.5))
	best_flag.pivot_offset = Vector2(-18, 12)
	best_flag.create_tween().tween_property(best_flag, "scale", Vector2.ONE, 0.35).from(Vector2.ONE * 1.8) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## The peak's stamp: the tier's picture on a badge in the kicker's colour, slammed in, then gone.
func show_stamp(player: int, tier: int) -> void:
	var t := _tiers.get_tier(tier)
	stamp.tier_id = t.id
	stamp.bg = t.color
	stamp.ring = Players.COLOR[player]
	stamp.position = Vector2((size.x - STAMP_SIZE) * 0.5, 110.0)
	stamp.visible = true
	stamp.modulate.a = 1.0
	if _stamp_tween:
		_stamp_tween.kill()
	_stamp_tween = create_tween()
	_stamp_tween.tween_property(stamp, "scale", Vector2.ONE, 0.22).from(Vector2.ONE * 2.4) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_stamp_tween.parallel().tween_property(stamp, "rotation", -0.14, 0.22).from(0.3)
	_stamp_tween.tween_interval(STAMP_HOLD)
	_stamp_tween.tween_property(stamp, "modulate:a", 0.0, 0.3)
	_stamp_tween.tween_callback(stamp.hide)
	Audio.play("land", null, 0.75)


func _on_tier(player: int, tier: int) -> void:
	var b := blocks.get_child(_tiers.tiers.size() - tier) as CanvasItem
	Fx.flash(b)
	Fx.flash(markers[player])


func _on_ball_stopped(player: int, h: float, tier: int) -> void:
	Fx.flash(markers[player], Color(1, 1, 0.8))
	note_peak(player, _tiers.space_height() if Run.in_space(player) else h)
	if visible:
		show_stamp(player, tier)


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
		ball.custom_minimum_size = Vector2(ROUND_BALL, ROUND_BALL)
		ball.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN   # round, not stretched to the column
		var now := i == Run.round_index - 1
		# Big ink-outlined balls, readable from the sofa; this round's ball is golden and bigger.
		_style_ball(ball, Color(1.0, 0.85, 0.25) if now else Color(1, 1, 1, 0.97), ROUND_BALL)
		ball.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rounds.add_child(ball)
		ball.pivot_offset = Vector2.ONE * ROUND_BALL * 0.5
		if now:
			ball.scale = Vector2.ONE * 0.1
			var tw := ball.create_tween()
			tw.tween_property(ball, "scale", Vector2.ONE * 1.2, 0.3).set_trans(Tween.TRANS_BACK)
			tw.tween_property(ball, "scale", Vector2.ONE, 0.2)


## A round-counter ball: fill, a dark ink rim and a soft shadow (it sits on bright sky and grass).
static func _style_ball(c: Control, color: Color, d: float) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(int(d * 0.5))
	sb.border_color = Color(0.12, 0.1, 0.2, 0.95)
	sb.set_border_width_all(4)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(0, 3)
	c.add_theme_stylebox_override("panel", sb)
	c.size = Vector2(d, d)


static func _style_circle(c: Control, color: Color, d: float) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(int(d * 0.5))
	sb.border_color = Color(1, 1, 1, 0.9)
	sb.set_border_width_all(3)
	c.add_theme_stylebox_override("panel", sb)
	c.size = Vector2(d, d)
