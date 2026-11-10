## Start screen and main menu in one, no text. Shown while Game.state == LOBBY.
## Each pad presses A to join and be ready (its spot lights up, its character waves), B un-readies.
## Both ready: a 3-dot countdown, then Game.finish_lobby(). A ready player holding A on Play for
## HOLD_TO_START s starts alone. Two icon buttons: Play and Back to the launcher (Game.quit()).
## Games: set title_texture (or replace TitleArt), swap Spots/P*/Character for their own; the lobby
## calls set_joined(on) and wave() on it if it has them. Keep the node names.
extends Control

signal player_readied(player: int, ready: bool)
signal countdown_started()
signal countdown_cancelled()

enum Choice { PLAY, DOOR }

const HOLD_TO_START := 1.5
const COUNT_STEP := 0.7
const COUNT_DOTS := 3
const P1 := Players.P1
const P2 := Players.P2

@export var title_texture: Texture2D:
	set(v):
		title_texture = v
		if is_node_ready():
			$TitleArt.texture = v

var readied := { P1: false, P2: false }
var focus := Choice.PLAY
var counting := false

var _hold := { P1: 0.0, P2: 0.0 }
var _count_t := 0.0
var _dots_lit := 0

@onready var _spots := { P1: $Spots/P1, P2: $Spots/P2 }
@onready var _buttons := { Choice.PLAY: $Buttons/Play, Choice.DOOR: $Buttons/Door }
@onready var _countdown: Control = $Countdown


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if title_texture:
		$TitleArt.texture = title_texture
	_countdown.draw.connect(_draw_countdown)
	Players.player_joined.connect(_on_player_joined)
	Players.player_left.connect(_on_player_left)
	Players.solo_changed.connect(_on_solo_changed)
	Game.state_changed.connect(_on_state_changed)
	visible = Game.state == Game.State.LOBBY
	open()


## Fresh lobby: nobody ready, Play focused. Joined pads keep their spots; solo readies both.
func open() -> void:
	counting = false
	_dots_lit = 0
	_countdown.queue_redraw()
	for p in [P1, P2]:
		readied[p] = false
		_hold[p] = 0.0
		_spots[p].readied = false
		_spots[p].hold = 0.0
		_set_joined(p, Players.is_active(p))
	_set_focus(Choice.PLAY, false)
	if Players.solo and _live():
		_ready_both()


func _live() -> bool:
	return Game.state == Game.State.LOBBY and not Game.demo


func _process(delta: float) -> void:
	if not _live():
		return
	var move := 0
	for p in Players.active_players():
		if Input.is_action_just_pressed(Players.action(p, "move_up")) \
				or Input.is_action_just_pressed(Players.action(p, "move_left")):
			move = -1
		elif Input.is_action_just_pressed(Players.action(p, "move_down")) \
				or Input.is_action_just_pressed(Players.action(p, "move_right")):
			move = 1
	if move != 0:
		_set_focus(Choice.PLAY if move < 0 else Choice.DOOR)
	for p in Players.active_players():
		if Input.is_action_just_pressed(Players.action(p, "action")):
			press_a(p)
		elif Input.is_action_just_pressed(Players.action(p, "jump")):
			press_b(p)
	for p in [P1, P2]:
		hold_step(p, Players.is_active(p) and Input.is_action_pressed(Players.action(p, "action")), delta)
	count_step(delta)


func press_a(player: int) -> void:
	_buttons[focus].press()
	if focus == Choice.DOOR:
		Audio.play("ui_back")
		Game.quit()
	elif not readied[player]:
		set_ready(player, true)


func press_b(player: int) -> void:
	if readied[player]:
		set_ready(player, false)
	elif focus == Choice.DOOR:
		_set_focus(Choice.PLAY)


func set_ready(player: int, on: bool, quiet := false) -> void:
	if readied[player] == on:
		return
	readied[player] = on
	_hold[player] = 0.0
	_spots[player].hold = 0.0
	_spots[player].readied = on
	if on:
		_set_joined(player, true)
		var who: Node = _spots[player].get_node_or_null("Character")
		if who and who.has_method("wave"):
			who.wave()
	if not quiet:
		Audio.play("player_ready" if on else "player_unready")
	player_readied.emit(player, on)
	if on and readied[P1] and readied[P2]:
		start_countdown()
	elif not on and counting:
		cancel_countdown()


## The hold-to-start-alone rule, fed once a frame per player. Returns true when it started.
func hold_step(player: int, down: bool, delta: float) -> bool:
	if counting or not readied[player] or not down or focus != Choice.PLAY:
		if _hold[player] > 0.0:
			_hold[player] = 0.0
			_spots[player].hold = 0.0
		return false
	_hold[player] += delta
	_spots[player].hold = _hold[player] / HOLD_TO_START
	if _hold[player] < HOLD_TO_START:
		return false
	_hold[player] = 0.0
	_spots[player].hold = 0.0
	start_countdown()
	return true


func start_countdown() -> void:
	if counting:
		return
	counting = true
	_count_t = 0.0
	_dots_lit = 0
	countdown_started.emit()
	_light_next_dot()


func cancel_countdown() -> void:
	if not counting:
		return
	counting = false
	_dots_lit = 0
	_countdown.queue_redraw()
	countdown_cancelled.emit()


func count_step(delta: float) -> void:
	if not counting:
		return
	_count_t += delta
	if _count_t >= COUNT_STEP * COUNT_DOTS:
		counting = false
		Game.finish_lobby(ready_players())
	elif _count_t >= COUNT_STEP * _dots_lit:
		_light_next_dot()


func ready_players() -> Array:
	return [P1, P2].filter(func(p: int) -> bool: return readied[p])


func _light_next_dot() -> void:
	_dots_lit += 1
	Audio.play("count_tick")
	_countdown.queue_redraw()
	_countdown.scale = Vector2.ONE * 1.15
	var tw := _countdown.create_tween()
	tw.tween_property(_countdown, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _ready_both() -> void:
	set_ready(P1, true)
	set_ready(P2, true)


func _set_focus(to: Choice, sound := true) -> void:
	if sound and to != focus:
		Audio.play("ui_move")
	focus = to
	for c in _buttons:
		_buttons[c].focused = c == focus


func _set_joined(player: int, on: bool) -> void:
	_spots[player].joined = on
	var who: Node = _spots[player].get_node_or_null("Character")
	if who and who.has_method("set_joined"):
		who.set_joined(on)


func _on_player_joined(player: int, device: int) -> void:
	if not _live():
		return
	_set_joined(player, true)
	# The join press readies too (whatever is focused), unless it was B.
	if device >= 0 and Input.is_joy_button_pressed(device, JOY_BUTTON_B):
		return
	_set_focus(Choice.PLAY)
	set_ready(player, true)


func _on_player_left(player: int) -> void:
	set_ready(player, false, true)
	_set_joined(player, false)


func _on_solo_changed(on: bool) -> void:
	if on and _live():
		_ready_both()


func _on_state_changed(_from: int, to: int) -> void:
	visible = to == Game.State.LOBBY
	if visible:
		open()


func _draw_countdown() -> void:
	if _dots_lit == 0:
		return
	var c := _countdown.size * 0.5
	var gap := 110.0
	for i in COUNT_DOTS:
		var pos := c + Vector2((i - 1) * gap, 0)
		var lit := i < _dots_lit
		_countdown.draw_circle(pos, 46.0 if lit else 30.0, Color.WHITE if lit else Color(1, 1, 1, 0.2), true, -1.0, true)
