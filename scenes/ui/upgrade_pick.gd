## The upgrade pick: vertical split, green left, red right, three icon cards per half.
## Stick moves, A picks, waits for both, never times out. Systems owns structure, Art the theme.
extends Control

signal picked(player: int, upgrade: UpgradeData)
signal closed()

const P1 := 0
const P2 := 1
const STICK_PRESS := 0.6
const STICK_RELEASE := 0.3
const DEMO_PICK_AFTER := 0.8

var _draws := {}
var _sel := {P1: 1, P2: 1}
var _done := {P1: false, P2: false}
var _latched := {P1: false, P2: false}
var _demo_t := 0.0
var _open := false

@onready var halves := {P1: $Halves/P1, P2: $Halves/P2}


func _ready() -> void:
	visible = false
	set_process(false)


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
	visible = true
	set_process(true)


func close() -> void:
	if not _open:
		return
	_open = false
	visible = false
	set_process(false)
	closed.emit()


func _process(delta: float) -> void:
	_demo_t += delta
	for p in _draws:
		if _done[p]:
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
	for i in cards.size():
		if i != _sel[p]:
			cards[i].modulate = Color(1, 1, 1, 0.25)
	Fx.flash(cards[_sel[p]], Players.COLOR[p])
	for q in _draws:
		if not _done[q]:
			for c in cards_of(q):
				c.bounce = true   # gently nudge the slower side, never a timer
	picked.emit(p, u)


func _refresh(p: int) -> void:
	var cards := cards_of(p)
	for i in cards.size():
		cards[i].set_highlight(i == _sel[p] and not _done[p], Players.COLOR[p])


func _reads_input(p: int) -> bool:
	return p == P1 or Players.is_active(p)
