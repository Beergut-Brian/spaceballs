## One run of Spaceballs: per-player upgrades, power, heights, and the round phase machine.
## Autoload: Run. Scenes report with notify_*(); everybody else listens to the signals.
## See docs/contracts.md "Run". Systems lane owns.
extends Node

enum Phase { IDLE, KICK_P1, FLIGHT_P1, KICK_P2, FLIGHT_P2, PICK, END }

signal kick_started(player: int)
signal kicked(player: int, power: float)
signal ball_tier_reached(player: int, tier: int)
signal ball_stopped(player: int, height: float, tier: int)
signal upgrade_picked(player: int, upgrade_id: StringName)
signal reached_space(player: int)

signal phase_changed(from: Phase, to: Phase)
signal run_started()
signal run_finished()
signal player_benched(player: int)
signal player_will_join(player: int)

const P1 := 0
const P2 := 1
const PLAYERS := [P1, P2]
const KICK_PHASE := { P1: Phase.KICK_P1, P2: Phase.KICK_P2 }
const FLIGHT_PHASE := { P1: Phase.FLIGHT_P1, P2: Phase.FLIGHT_P2 }

const BASE_POWER := 8.0
const GRAVITY := 9.8
const MAX_ROUNDS := 15
const STRONG_ONLY_AFTER := 14
const QUALITY_MIN := 0.8
const QUALITY_MAX := 1.2
const KIND_ODDS := { "normal": 0.60, "strong": 0.20, "joke": 0.12, "curse": 0.08 }
const CATCH_UP_TIERS := 2
const CATCH_UP_MIN_MULT := 1.7
const CATCH_UP_STRONG_ODDS := 0.6
const SPACE_FLOOR := 1.02   # the round-15 kick peaks at least this far over the space line

const TIERS_PATH := "res://data/tiers.tres"
const UPGRADES_DIR := "res://data/upgrades/"

var phase: Phase = Phase.IDLE
var round_index: int = 0

## Off in tests: the run steps itself instead of going through Game, and never touches Save.
var drive_game := true
var save_enabled := true
## --demo: the pick UI picks by itself so a headless run plays end to end.
var demo := false

var tiers: TierSet
var pool: Array[UpgradeData] = []
var rng := RandomNumberGenerator.new()

var _requested: Array = []
var _in_run := {}
var _join_next := {}
var _in_space := {}
var _space_round := {}
var _upgrades := {}
var _pending_curse := {}
var _active_curse := {}
var _best := {}
var _last := {}
var _picked := {}


func _init() -> void:
	_clear()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.randomize()
	_ensure_data()
	Game.round_started.connect(_on_round_started)
	Players.player_joined.connect(_on_player_joined)
	Players.player_left.connect(_on_player_left)


# --- queries ---------------------------------------------------------------

func power_of(player: int, run_up_quality: float = 1.0) -> float:
	var curse: UpgradeData = _active_curse[player]
	var mult := 1.0
	if curse == null or curse.scene_override == null:
		for u: UpgradeData in _upgrades[player]:
			mult *= u.power_mult
	if curse != null:
		mult *= curse.power_mult
	return BASE_POWER * mult * clampf(run_up_quality, QUALITY_MIN, QUALITY_MAX)


func upgrades_of(player: int) -> Array[UpgradeData]:
	var out: Array[UpgradeData] = []
	out.assign(_upgrades[player])
	return out


## Everything the player's gear does this kick (docs/contracts.md "UpgradeData": stats add up,
## the look is what you wear). The frog round switches all of it off.
func effects_of(player: int) -> Dictionary:
	return resolve_effects(upgrades_of(player), curse_of(player))


static func resolve_effects(ups: Array[UpgradeData], curse: UpgradeData = null) -> Dictionary:
	var fx := {
		"run_speed_mult": 1.0, "accel_mult": 1.0, "jump_mult": 1.0, "gravity_mult": 1.0,
		"runup_bonus": 0.0, "kick_style": &"normal", "ball_effects": [] as Array[StringName],
		"run_fx": [] as Array[StringName], "bulk": 1.0, "shake": 0.0, "worn": {},
	}
	if curse != null and curse.scene_override != null:
		return fx
	var worn := {}
	var loose: Array[UpgradeData] = []
	for u in ups:
		fx.run_speed_mult *= u.run_speed_mult
		fx.accel_mult *= u.accel_mult
		fx.jump_mult *= u.jump_mult
		fx.gravity_mult *= u.gravity_mult
		fx.runup_bonus += u.runup_bonus
		if u.slot == "none":
			loose.append(u)
		else:
			worn[u.slot] = u
	fx.worn = worn
	# The looks: worn items in pick order (a replaced item's look is gone), then this kick's curse.
	var looks: Array[UpgradeData] = []
	looks.assign(ups.filter(func(u: UpgradeData) -> bool: return loose.has(u) or worn.values().has(u)))
	if curse != null:
		looks.append(curse)
		fx.run_speed_mult *= curse.run_speed_mult
		fx.accel_mult *= curse.accel_mult
		fx.jump_mult *= curse.jump_mult
		fx.gravity_mult *= curse.gravity_mult
	for u in looks:
		if u.kick_style != &"normal":
			fx.kick_style = u.kick_style
		if u.ball_effect != &"none" and not fx.ball_effects.has(u.ball_effect):
			fx.ball_effects.append(u.ball_effect)
		if u.run_fx != &"none" and not fx.run_fx.has(u.run_fx):
			fx.run_fx.append(u.run_fx)
		fx.bulk *= u.bulk
		fx.shake = maxf(fx.shake, u.shake)
	fx.bulk = minf(fx.bulk, 1.6)
	return fx


static func height_for_power(power: float) -> float:
	return power * power / (2.0 * GRAVITY)


func kick_height(player: int, power: float) -> float:
	var h := height_for_power(power)
	if round_index >= MAX_ROUNDS and _in_run.get(player, false):
		h = maxf(h, _tiers().space_height() * SPACE_FLOOR)
	return h


func tier_of_height(height: float) -> int:
	return _tiers().tier_for(height)


func in_run(player: int) -> bool:
	return _in_run.get(player, false)


func in_space(player: int) -> bool:
	return _in_space.get(player, false)


func space_round(player: int) -> int:
	return _space_round.get(player, 0)


func curse_of(player: int) -> UpgradeData:
	return _active_curse.get(player)


func best_height(player: int) -> float:
	return _best.get(player, 0.0)


func last_height(player: int) -> float:
	return _last.get(player, 0.0)


func phase_player() -> int:
	match phase:
		Phase.KICK_P1, Phase.FLIGHT_P1:
			return P1
		Phase.KICK_P2, Phase.FLIGHT_P2:
			return P2
	return -1


func pickers() -> Array[int]:
	var out: Array[int] = []
	for p in PLAYERS:
		if in_run(p) and not in_space(p):
			out.append(p)
	return out


func has_picked(player: int) -> bool:
	return _picked.get(player, false)


func catch_up_for(player: int) -> bool:
	var other := P2 if player == P1 else P1
	if not in_run(other):
		return false
	var other_tier := _tiers().tiers.size() if in_space(other) else tier_of_height(last_height(other))
	return other_tier - tier_of_height(last_height(player)) >= CATCH_UP_TIERS


func draw_cards(player: int, with_rng: RandomNumberGenerator = null) -> Array[UpgradeData]:
	_ensure_data()
	var cards := draw_from(pool, round_index, catch_up_for(player), with_rng if with_rng else rng,
			upgrades_of(player))
	if save_enabled:
		var seen: Array = Save.get_value("upgrades_seen", [])
		for c in cards:
			if not seen.has(String(c.id)):
				seen.append(String(c.id))
		Save.set_value("upgrades_seen", seen)
	return cards


# --- draw rules (static so tests and the simulation share them) ------------

static func band_for_round(r: int) -> int:
	return 1 if r <= 4 else (2 if r <= 8 else 3)


static func roll_kind(r: RandomNumberGenerator) -> String:
	var x := r.randf()
	for kind in KIND_ODDS:
		x -= KIND_ODDS[kind]
		if x < 0.0:
			return kind
	return "normal"


## `owned`: the player's gear. Never offered again (curses can repeat).
static func draw_from(all: Array[UpgradeData], r_index: int, catch_up: bool,
		r: RandomNumberGenerator, owned: Array[UpgradeData] = []) -> Array[UpgradeData]:
	var from: Array[UpgradeData] = []
	from.assign(all.filter(func(c: UpgradeData) -> bool: return c.is_curse() or not owned.has(c)))
	var band := band_for_round(r_index)
	var out: Array[UpgradeData] = []
	var strong_only := r_index >= STRONG_ONLY_AFTER
	for i in 3:
		var kind := roll_kind(r)
		if strong_only:
			kind = "strong"
		elif catch_up:
			kind = "strong" if r.randf() < CATCH_UP_STRONG_ODDS else "normal"
		var card := _pick_card(from, kind, band, out, catch_up and not strong_only, r)
		if card == null and not strong_only:
			card = _pick_card(from, "normal", band, out, catch_up, r)
		# Gear running out (no duplicates): any other gear, best first.
		for k in ["strong", "normal", "joke"]:
			if card == null:
				card = _pick_card(from, k, band, out, false, r)
		if card != null:
			out.append(card)
	if not strong_only and not out.any(func(c: UpgradeData) -> bool: return c.kind == "normal"):
		var normal := _pick_card(from, "normal", band, out, catch_up, r)
		if normal != null and out.is_empty():
			out.append(normal)
		elif normal != null:
			var slot := r.randi() % out.size()
			for i in out.size():
				if out[i].kind == "curse":
					slot = i
			out[slot] = normal
	return out


static func _pick_card(from: Array[UpgradeData], kind: String, band: int, taken: Array[UpgradeData],
		catch_up: bool, r: RandomNumberGenerator) -> UpgradeData:
	var ok := func(c: UpgradeData) -> bool:
		return c.kind == kind and not taken.has(c) and (not catch_up or c.power_mult >= CATCH_UP_MIN_MULT)
	var cands := from.filter(func(c: UpgradeData) -> bool: return ok.call(c) and c.tier <= band)
	if cands.is_empty():
		cands = from.filter(ok)
	if cands.is_empty():
		return null
	return cands[r.randi() % cands.size()]


# --- reporting -------------------------------------------------------------

func notify_kick_started(player: int) -> void:
	kick_started.emit(player)


func notify_kicked(player: int, run_up_quality: float) -> float:
	var power := power_of(player, run_up_quality)
	_set_phase(FLIGHT_PHASE[player])
	kicked.emit(player, power)
	return power


func notify_tier(player: int, tier: int) -> void:
	ball_tier_reached.emit(player, tier)
	if tier >= _tiers().tiers.size():
		_mark_space(player)


func notify_stopped(player: int, height: float) -> void:
	_last[player] = height
	_best[player] = maxf(best_height(player), height)
	if save_enabled and height > float(Save.get_value("best_height", 0.0)):
		Save.set_value("best_height", height)
	if height >= _tiers().space_height():
		_mark_space(player)
	ball_stopped.emit(player, height, tier_of_height(height))


func end_flight(player: int) -> void:
	if phase != FLIGHT_PHASE[player]:
		return
	_go_next_after(player)


func pick(player: int, upgrade: UpgradeData) -> void:
	if phase != Phase.PICK or not pickers().has(player) or has_picked(player) or upgrade == null:
		return
	if upgrade.is_curse():
		_pending_curse[player] = upgrade
	else:
		_upgrades[player].append(upgrade)
	_picked[player] = true
	upgrade_picked.emit(player, upgrade.id)
	if pickers().all(has_picked):
		_advance_round()


## Debug / playtest (`-- --gear=<ids>`): wear an upgrade from the start, no pick needed.
func give(player: int, upgrade: UpgradeData) -> void:
	if upgrade != null and not upgrade.is_curse() and not _upgrades[player].has(upgrade):
		_upgrades[player].append(upgrade)


func upgrade_by_id(id: StringName) -> UpgradeData:
	_ensure_data()
	for u in pool:
		if u.id == id:
			return u
	return null


## players: who plays from round 1. Empty = P1, plus P2 if a pad is joined.
func start_run(players: Array = []) -> void:
	_requested = players
	if drive_game:
		Game.restart()   # -> Game.round_started(1) -> _begin_round(1)
	else:
		_begin_round(1)


# --- flow ------------------------------------------------------------------

func _on_round_started(index: int) -> void:
	_begin_round(index)


func _begin_round(index: int) -> void:
	if index <= 1:
		_clear()
		var players := _requested if not _requested.is_empty() else _default_players()
		for p in players:
			_in_run[p] = true
		_requested = []
	round_index = index
	for p in PLAYERS:
		if _join_next[p]:
			_in_run[p] = true
			_join_next[p] = false
		_active_curse[p] = _pending_curse[p]
		_pending_curse[p] = null
		_picked[p] = false
	if index <= 1:
		run_started.emit()
	for p in PLAYERS:
		if not _in_run[p]:
			player_benched.emit(p)
	_go_next_after(-1)


func _default_players() -> Array:
	var out := [P1]
	if Players.is_active(P2):
		out.append(P2)
	return out


func _go_next_after(player: int) -> void:
	for p in PLAYERS:
		if p > player and in_run(p) and not in_space(p):
			_set_phase(KICK_PHASE[p])
			return
	if pickers().is_empty():
		_finish()
	else:
		for p in PLAYERS:
			_picked[p] = false
		_set_phase(Phase.PICK)


func _advance_round() -> void:
	if drive_game:
		Game.end_round({"round": round_index})
		Game.start_round()   # -> Game.round_started(n + 1)
	else:
		_begin_round(round_index + 1)


func _finish() -> void:
	_set_phase(Phase.END)
	if save_enabled:
		Save.set_value("runs_completed", int(Save.get_value("runs_completed", 0)) + 1)
	run_finished.emit()
	if drive_game:
		Game.end_round({"space": true})


func _mark_space(player: int) -> void:
	if in_space(player):
		return
	_in_space[player] = true
	_space_round[player] = round_index
	reached_space.emit(player)


func _set_phase(to: Phase) -> void:
	var from := phase
	phase = to
	phase_changed.emit(from, to)


func _on_player_joined(player: int, _device: int) -> void:
	if player == P1 or phase == Phase.IDLE or in_run(player):
		return
	_join_next[player] = true
	player_will_join.emit(player)


func _on_player_left(player: int) -> void:
	_join_next[player] = false
	if player != P1 and in_run(player) and not in_space(player):
		_in_run[player] = false
		# Never leave the round waiting on a pad that is gone.
		if phase == KICK_PHASE[player]:
			_go_next_after(player)
		elif phase == Phase.PICK and pickers().all(has_picked) and not pickers().is_empty():
			_advance_round()


func _clear() -> void:
	for p in PLAYERS:
		_in_run[p] = false
		_join_next[p] = false
		_in_space[p] = false
		_space_round[p] = 0
		_upgrades[p] = []
		_pending_curse[p] = null
		_active_curse[p] = null
		_best[p] = 0.0
		_last[p] = 0.0
		_picked[p] = false
	round_index = 0


func _tiers() -> TierSet:
	_ensure_data()
	return tiers


func _ensure_data() -> void:
	if tiers == null and ResourceLoader.exists(TIERS_PATH):
		tiers = load(TIERS_PATH)
	if pool.is_empty():
		for f in ResourceLoader.list_directory(UPGRADES_DIR):
			if f.ends_with(".tres") or f.ends_with(".res"):
				var u := load(UPGRADES_DIR + f) as UpgradeData
				if u != null:
					pool.append(u)
