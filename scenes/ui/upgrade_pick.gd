## The upgrade pick: vertical split, green left, red right, three icon cards per half.
## Stick moves, A picks, waits for both, never times out. Systems owns structure, Art the theme.
## Solo (playtest): one pad picks for P1, then P2 (the waiting half is dimmed); B on P2's turn
## goes back to P1's choice. Both picks are emitted together when P2 picks.
## Every press answers (docs/press-answers.md): X, Y, shoulders, triggers, stick clicks and Start, B
## outside solo P2's turn, and A or B from a player who has already picked, refuse: the honk and a
## wobble on that player's card (MenuInput.refuse()). Select keeps its job (Game's restart).
extends Control

signal picked(player: int, upgrade: UpgradeData)
signal closed()

const P1 := 0
const P2 := 1
const STICK_PRESS := 0.6
const STICK_RELEASE := 0.3
const DEMO_PICK_AFTER := 0.8
const WAITING_DIM := Color(0.45, 0.45, 0.45)
const CURSE_PURPLE := Color(0.62, 0.32, 0.95)

var _draws := {}
var _sel := {P1: 1, P2: 1}
var _done := {P1: false, P2: false}
var _latched := {P1: false, P2: false}
var _demo_t := 0.0
var _open := false
## Solo: whose turn it is (-1 = not sequencing) and P1's choice, held until P2 picks.
var _solo_turn := -1
var _solo_held: UpgradeData = null

@onready var halves := {P1: $Halves/P1, P2: $Halves/P2}


func _ready() -> void:
	visible = false
	set_process(false)
	Players.solo_changed.connect(_on_solo_changed)


func cards_of(player: int) -> Array:
	return halves[player].get_node("Cards").get_children()


func camera_of(player: int) -> Camera3D:
	return halves[player].get_node("View/SubViewport/Camera3D")


## Point a half's camera at a character.
func frame(player: int, target: Vector3, from: Vector3) -> void:
	var cam := camera_of(player)
	cam.global_position = from
	cam.look_at(target)


## draws: player -> Array[UpgradeData]. shown: the halves to show (a finished player's half
## shows him cheering, with no cards).
func open(draws: Dictionary, shown: Array) -> void:
	_draws = draws
	_open = true
	_demo_t = 0.0
	for p in [P1, P2]:
		halves[p].visible = shown.has(p)
		halves[p].get_node("View").visible = shown.has(p)
		_done[p] = not draws.has(p)
		_sel[p] = 1
		_latched[p] = true   # the stick has to come back to centre first
		var list: Array = draws.get(p, [])
		var cards := cards_of(p)
		for i in cards.size():
			cards[i].set_upgrade(list[i] if i < list.size() else null)
			cards[i].bounce = false
		_refresh(p)
	_solo_held = null
	_solo_turn = -1
	if Players.solo:
		var turn := P1 if draws.has(P1) else P2
		if draws.has(P1) and draws.has(P2):
			_solo_turn = P1
		Players.set_solo_focus(turn)
	_refresh_halves()
	visible = true
	set_process(true)


func close() -> void:
	if not _open:
		return
	_open = false
	_solo_turn = -1
	_solo_held = null
	_refresh_halves()
	visible = false
	set_process(false)
	closed.emit()


## Solo: whose turn it is, or -1 when both halves read their own input.
func solo_turn() -> int:
	return _solo_turn


func _process(delta: float) -> void:
	_demo_t += delta
	var input := MenuInput.read()
	for p in _draws:
		if _solo_turn != -1 and p != _solo_turn:
			continue
		if _done[p]:
			if not Run.demo and _solo_turn == -1 and _reads_input(p):
				if Input.is_action_just_pressed(Players.action(p, "action")):
					refuse(p, "a")
				elif Input.is_action_just_pressed(Players.action(p, "jump")):
					refuse(p, "b")
			continue
		if Run.demo and _demo_t > DEMO_PICK_AFTER:
			_sel[p] = randi() % _draws[p].size()
			_pick(p)
			continue
		if not _reads_input(p):
			continue
		var x := Players.move_vector(p).x
		if absf(x) < STICK_RELEASE:
			_latched[p] = false
		elif absf(x) > STICK_PRESS and not _latched[p]:
			_latched[p] = true
			_move(p, 1 if x > 0.0 else -1)
		if Input.is_action_just_pressed(Players.action(p, "action")):
			_pick(p)
		elif Input.is_action_just_pressed(Players.action(p, "jump")):
			if _solo_turn == P2:
				solo_back()
			elif not Run.demo:
				refuse(p, "b")
	if input.other != -1 and not Run.demo and not owned_elsewhere(input.button):
		var who: int = _solo_turn if _solo_turn != -1 else input.other
		if _draws.has(who):
			refuse(who, input.button)


## A press that does nothing on the pick: the honk and a wobble on this player's card.
func refuse(p: int, button := "") -> void:
	MenuInput.refuse(cards_of(p)[_sel[p]], button)


## Buttons another owner answers while the pick is up: Select is Game's restart (arm, then restart).
## Start is the pause only in PLAYING; the pick runs between rounds, so Start refuses here.
static func owned_elsewhere(button: String) -> bool:
	if button == "select":
		return Game.state in [Game.State.PLAYING, Game.State.ROUND_END]
	if button == "start":
		return Game.state in [Game.State.PLAYING, Game.State.PAUSED]
	return false


func _move(p: int, step: int) -> void:
	var n: int = _draws[p].size()
	var to := clampi(_sel[p] + step, 0, n - 1)
	if to == _sel[p]:
		Fx.flash(cards_of(p)[_sel[p]], Color(1, 0.8, 0.8))   # bump the edge: still a reaction
		Audio.play("card_move", null, 0.8)
		return
	_sel[p] = to
	Audio.play("card_move")
	_refresh(p)
	Fx.flash(cards_of(p)[to])


func _pick(p: int) -> void:
	var u: UpgradeData = _draws[p][_sel[p]]
	_done[p] = true
	Audio.play("card_pick")
	var cards := cards_of(p)
	_refresh_prompts(p)
	for i in cards.size():
		if i != _sel[p]:
			cards[i].modulate = Color(1, 1, 1, 0.25)
	Fx.flash(cards[_sel[p]], Players.COLOR[p])
	if _solo_turn == P1:
		# Hold P1's choice; the same pad now picks for P2.
		_solo_held = u
		_solo_turn = P2
		_latched[P2] = true
		_demo_t = 0.0
		Players.set_solo_focus(P2)
		_refresh_halves()
		return
	if _solo_turn == P2:
		_solo_turn = -1
		_refresh_halves()
		var held := _solo_held
		_solo_held = null
		picked.emit(P1, held)
	for q in _draws:
		if not _done[q]:
			for c in cards_of(q):
				c.bounce = true   # gently nudge the slower side, never a timer
	picked.emit(p, u)


## Hidden curse (playtest 2026-11-09 #2): the picked card shivers, flips over and turns out to be
## `curse`. Await it; about 1.9 s.
func reveal_curse(p: int, curse: UpgradeData) -> void:
	var card: Control = cards_of(p)[_sel[p]]
	card.flipping = true
	card.pivot_offset = card.size * 0.5
	var tw := create_tween()
	tw.tween_interval(0.3)
	# Uh oh: it shivers first.
	tw.tween_callback(Audio.play.bind("uh_oh"))
	for i in 6:
		tw.tween_property(card, "rotation", 0.09 * (1.0 if i % 2 == 0 else -1.0), 0.06)
	tw.tween_property(card, "rotation", 0.0, 0.05)
	tw.tween_property(card, "scale", Vector2(0.0, 1.25), 0.16).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		card.set_upgrade(curse)
		card.scale = Vector2(0.0, 1.25)
		card.set_highlight(true, CURSE_PURPLE)
		Audio.play("curse")
		Fx.flash(card, CURSE_PURPLE))
	tw.tween_property(card, "scale", Vector2.ONE * 1.3, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(Audio.play.bind("crowd_aww"))
	tw.tween_property(card, "scale", Vector2.ONE * 1.15, 0.3)
	tw.tween_interval(0.75)
	await tw.finished
	card.flipping = false


## Solo, P2's turn: B undoes P1's held choice and hands the pad back to P1.
func solo_back() -> void:
	if _solo_turn != P2:
		return
	_solo_turn = P1
	_solo_held = null
	_done[P1] = false
	_latched[P1] = true
	for c in cards_of(P1):
		c.modulate = Color.WHITE
	Players.set_solo_focus(P1)
	Audio.play("card_move", null, 0.7)
	_refresh(P1)
	_refresh_halves()
	Fx.flash(cards_of(P1)[_sel[P1]], Players.COLOR[P1])


func _on_solo_changed(on: bool) -> void:
	if on or _solo_turn == -1:
		return
	# Solo ended mid-pick: P1's held choice counts, P2 goes back to normal.
	var held := _solo_held
	_solo_turn = -1
	_solo_held = null
	_refresh_halves()
	if held != null:
		picked.emit(P1, held)


func _refresh_halves() -> void:
	for p in [P1, P2]:
		var waiting: bool = _solo_turn != -1 and p != _solo_turn
		halves[p].modulate = WAITING_DIM if waiting else Color.WHITE


func _refresh(p: int) -> void:
	var cards := cards_of(p)
	for i in cards.size():
		cards[i].set_highlight(i == _sel[p] and not _done[p], Players.COLOR[p])
	_refresh_prompts(p)


## The A button sits on the highlighted card until that player has picked.
func _refresh_prompts(p: int) -> void:
	var cards := cards_of(p)
	for i in cards.size():
		cards[i].prompt = i == _sel[p] and not _done[p]


func _reads_input(p: int) -> bool:
	return p == P1 or Players.is_active(p)
