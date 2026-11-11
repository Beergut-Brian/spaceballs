## Run: power math, phase machine, draw rules, tiers. Uses detached Run instances (not the
## autoload) with drive_game and save off, so nothing touches Game state or the save file.
class_name TestRun
extends GdUnitTestSuite

const RunScript := preload("res://scripts/autoload/Run.gd")
const P1 := 0
const P2 := 1
const Phase := RunScript.Phase

var _runs: Array = []


func after_test() -> void:
	for r in _runs:
		r.free()
	_runs.clear()


func _run(players: Array = [P1]) -> Node:
	var r: Node = RunScript.new()
	r.drive_game = false
	r.save_enabled = false
	r.rng.seed = 1
	_runs.append(r)
	r._ensure_data()
	r.start_run(players)
	return r


func _up(id: StringName, kind: String, mult: float, tier := 1, override: PackedScene = null) -> UpgradeData:
	var u := UpgradeData.new()
	u.id = id
	u.kind = kind
	u.power_mult = mult
	u.tier = tier
	u.scene_override = override
	return u


## Plays one kick for whoever's phase it is. Returns the player.
func _kick(r: Node, quality := 1.0, height := -1.0) -> int:
	var p: int = r.phase_player()
	var power: float = r.notify_kicked(p, quality)
	var h: float = height if height >= 0.0 else r.kick_height(p, power)
	r.notify_tier(p, r.tier_of_height(h))
	r.notify_stopped(p, h)
	r.end_flight(p)
	return p


# --- power -------------------------------------------------------------------

func test_power_is_base_times_product_times_quality() -> void:
	var r := _run([P1])
	assert_float(r.power_of(P1)).is_equal_approx(RunScript.BASE_POWER, 0.0001)
	_kick(r)
	r.pick(P1, _up(&"a", "normal", 1.5))
	_kick(r)
	r.pick(P1, _up(&"b", "strong", 2.0))
	assert_float(r.power_of(P1)).is_equal_approx(RunScript.BASE_POWER * 3.0, 0.0001)
	assert_float(r.power_of(P1, 1.2)).is_equal_approx(RunScript.BASE_POWER * 3.0 * 1.2, 0.0001)
	# quality is clamped to 0.8..1.2
	assert_float(r.power_of(P1, 5.0)).is_equal_approx(RunScript.BASE_POWER * 3.0 * 1.2, 0.0001)
	assert_float(r.power_of(P1, 0.0)).is_equal_approx(RunScript.BASE_POWER * 3.0 * 0.8, 0.0001)
	assert_int(r.upgrades_of(P1).size()).is_equal(2)


func test_curse_lasts_one_round_and_never_joins_upgrades() -> void:
	var r := _run([P1])
	_kick(r)
	r.pick(P1, _up(&"boot", "normal", 2.0))
	_kick(r)
	r.pick(P1, _up(&"peel", "curse", 0.25))
	assert_int(r.upgrades_of(P1).size()).is_equal(1)
	assert_object(r.curse_of(P1)).is_not_null()
	assert_float(r.power_of(P1)).is_equal_approx(RunScript.BASE_POWER * 2.0 * 0.25, 0.0001)
	_kick(r)
	r.pick(P1, _up(&"hat", "joke", 1.0))
	assert_object(r.curse_of(P1)).is_null()
	assert_float(r.power_of(P1)).is_equal_approx(RunScript.BASE_POWER * 2.0, 0.0001)


func test_frog_curse_suppresses_upgrades_for_that_round() -> void:
	var r := _run([P1])
	_kick(r)
	r.pick(P1, _up(&"boot", "normal", 2.0))
	_kick(r)
	r.pick(P1, _up(&"frog", "curse", 0.2, 1, PackedScene.new()))
	assert_float(r.power_of(P1)).is_equal_approx(RunScript.BASE_POWER * 0.2, 0.0001)
	_kick(r)
	r.pick(P1, _up(&"hat", "joke", 1.0))
	assert_float(r.power_of(P1)).is_equal_approx(RunScript.BASE_POWER * 2.0, 0.0001)


func test_height_for_power_is_ballistic() -> void:
	assert_float(RunScript.height_for_power(9.8 * 2.0)).is_equal_approx(19.6, 0.0001)


func test_round_15_always_reaches_space() -> void:
	var r := _run([P1])
	for i in 14:
		_kick(r, 1.0, 1.0)
		r.pick(P1, _up(StringName("h%d" % i), "joke", 1.0))
	assert_int(r.round_index).is_equal(15)
	assert_float(r.kick_height(P1, r.power_of(P1))).is_greater_equal(r.tiers.space_height())


# --- phase machine -------------------------------------------------------------

func test_phase_order_two_players() -> void:
	var r := _run([P1, P2])
	var seen: Array = []
	r.phase_changed.connect(func(_f, t): seen.append(t))
	assert_int(r.phase).is_equal(Phase.KICK_P1)
	_kick(r)
	_kick(r)
	assert_int(r.phase).is_equal(Phase.PICK)
	r.pick(P1, _up(&"a", "normal", 1.6))
	assert_int(r.phase).is_equal(Phase.PICK)   # waits for the slower player
	r.pick(P1, _up(&"b", "normal", 1.6))       # double pick is ignored
	assert_int(r.upgrades_of(P1).size()).is_equal(1)
	r.pick(P2, _up(&"c", "normal", 1.6))
	assert_int(r.phase).is_equal(Phase.KICK_P1)
	assert_int(r.round_index).is_equal(2)
	assert_array(seen).is_equal([Phase.FLIGHT_P1, Phase.KICK_P2, Phase.FLIGHT_P2, Phase.PICK, Phase.KICK_P1])


func test_single_player_skips_p2() -> void:
	var r := _run([P1])
	assert_bool(r.in_run(P2)).is_false()
	_kick(r)
	assert_int(r.phase).is_equal(Phase.PICK)
	assert_array(r.pickers()).is_equal([P1])
	r.pick(P1, _up(&"a", "normal", 1.6))
	assert_int(r.phase).is_equal(Phase.KICK_P1)


func test_player_in_space_is_skipped_and_run_ends_when_both_are() -> void:
	var r := _run([P1, P2])
	var space: float = r.tiers.space_height()
	var spaced: Array = []
	r.reached_space.connect(func(p): spaced.append(p))
	_kick(r, 1.0, space * 1.5)   # P1 to space in round 1
	_kick(r, 1.0, 2.0)
	assert_array(spaced).is_equal([P1])
	assert_array(r.pickers()).is_equal([P2])
	r.pick(P2, _up(&"a", "normal", 1.6))
	assert_int(r.phase).is_equal(Phase.KICK_P2)   # P1 skipped
	var finished := [false]
	r.run_finished.connect(func(): finished[0] = true)
	_kick(r, 1.0, space)
	assert_int(r.phase).is_equal(Phase.END)
	assert_bool(finished[0]).is_true()
	assert_int(r.space_round(P1)).is_equal(1)
	assert_int(r.space_round(P2)).is_equal(2)


func test_signals_carry_the_contract_values() -> void:
	var r := _run([P1])
	var got := {}
	r.kicked.connect(func(p, power): got["kicked"] = [p, power])
	r.ball_stopped.connect(func(p, h, t): got["stopped"] = [p, h, t])
	r.upgrade_picked.connect(func(p, id): got["picked"] = [p, id])
	_kick(r, 1.0, 20.0)
	r.pick(P1, _up(&"boot", "normal", 1.6))
	assert_array(got["kicked"]).is_equal([P1, RunScript.BASE_POWER])
	assert_array(got["stopped"]).is_equal([P1, 20.0, r.tier_of_height(20.0)])
	assert_array(got["picked"]).is_equal([P1, &"boot"])
	assert_float(r.best_height(P1)).is_equal(20.0)


func test_late_joiner_plays_from_next_round() -> void:
	var r := _run([P1])
	r.phase = Phase.KICK_P1
	r._on_player_joined(P2, 3)
	assert_bool(r.in_run(P2)).is_false()
	_kick(r)
	r.pick(P1, _up(&"a", "normal", 1.6))
	assert_bool(r.in_run(P2)).is_true()
	_kick(r)
	assert_int(r.phase).is_equal(Phase.KICK_P2)


# --- draw rules ----------------------------------------------------------------

func _pool() -> Array[UpgradeData]:
	var r := _run([P1])
	return r.pool


func test_every_draw_before_14_has_a_normal_card() -> void:
	var pool := _pool()
	var rng := RandomNumberGenerator.new()
	for s in 2000:
		rng.seed = s
		var cards := RunScript.draw_from(pool, 1 + s % 13, false, rng)
		assert_int(cards.size()).is_equal(3)
		assert_bool(cards.any(func(c): return c.kind == "normal")).is_true()
		var ids := cards.map(func(c): return c.id)
		assert_int(ids.size()).is_equal(3)
		assert_bool(ids[0] != ids[1] and ids[1] != ids[2] and ids[0] != ids[2]).is_true()


func test_kind_odds_never_roll_a_curse() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var counts := {"normal": 0, "strong": 0, "joke": 0, "curse": 0}
	for i in 20000:
		counts[RunScript.roll_kind(rng)] += 1
	assert_int(counts["curse"]).is_equal(0)
	assert_float(counts["normal"] / 20000.0).is_between(0.63, 0.67)


## Playtest 2026-11-09 #2: curses are never offered; they hide behind a pick instead.
func test_curses_never_offered_in_a_pick() -> void:
	var r: Node = RunScript.new()
	r._ensure_data()
	var rng := RandomNumberGenerator.new()
	for s in 3000:
		rng.seed = s
		for c in RunScript.draw_from(r.pool, 1 + s % 15, s % 4 == 0, rng):
			assert_bool(c.is_curse()).override_failure_message("offered %s" % c.id).is_false()
	r.free()


func test_hidden_curse_rules() -> void:
	# Playtest 2026-11-10 #2: from the very first pick, never for a player who is behind, never twice
	# in a row, never a third, never in the strong-only rounds; otherwise allowed.
	assert_bool(RunScript.curse_allowed(0, false, 0, false)).is_false()
	assert_bool(RunScript.curse_allowed(1, false, 0, false)).is_true()
	assert_bool(RunScript.curse_allowed(5, true, 0, false)).is_false()
	assert_bool(RunScript.curse_allowed(5, false, 0, true)).is_false()
	assert_bool(RunScript.curse_allowed(5, false, 1, false)).is_true()
	assert_bool(RunScript.curse_allowed(5, false, 2, false)).is_false()
	assert_bool(RunScript.curse_allowed(RunScript.STRONG_ONLY_AFTER - 1, false, 0, false)).is_false()


func test_reveal_gives_a_curse_from_the_band() -> void:
	var r: Node = RunScript.new()
	r._ensure_data()
	var rng := RandomNumberGenerator.new()
	for s in 200:
		rng.seed = s
		var c: UpgradeData = RunScript.pick_curse(r.pool, 3, rng)
		assert_bool(c.is_curse()).is_true()
		assert_int(c.tier).is_less_equal(RunScript.band_for_round(3))
	r.free()


func test_strong_only_after_round_14() -> void:
	var pool := _pool()
	var rng := RandomNumberGenerator.new()
	for s in 300:
		rng.seed = s
		for c in RunScript.draw_from(pool, 14 + s % 3, s % 2 == 0, rng):
			assert_str(c.kind).is_equal("strong")


func test_catch_up_draws_only_above_average() -> void:
	var pool := _pool()
	var rng := RandomNumberGenerator.new()
	for s in 500:
		rng.seed = s
		for c in RunScript.draw_from(pool, 1 + s % 13, true, rng):
			assert_bool(c.kind == "normal" or c.kind == "strong").is_true()
			assert_float(c.power_mult).is_greater_equal(RunScript.CATCH_UP_MIN_MULT)


func test_catch_up_when_two_tiers_behind() -> void:
	var r := _run([P1, P2])
	var t: TierSet = r.tiers
	_kick(r, 1.0, t.get_tier(5).threshold + 1.0)
	_kick(r, 1.0, t.get_tier(3).threshold + 1.0)
	assert_bool(r.catch_up_for(P2)).is_true()
	assert_bool(r.catch_up_for(P1)).is_false()
	var r2 := _run([P1, P2])
	_kick(r2, 1.0, t.get_tier(4).threshold + 1.0)
	_kick(r2, 1.0, t.get_tier(3).threshold + 1.0)
	assert_bool(r2.catch_up_for(P2)).is_false()
	var solo := _run([P1])
	_kick(solo, 1.0, 1.0)
	assert_bool(solo.catch_up_for(P1)).is_false()


# --- tiers -----------------------------------------------------------------------

func test_tier_lookup() -> void:
	var t: TierSet = load("res://data/tiers.tres")
	assert_int(t.tiers.size()).is_equal(8)
	assert_int(t.tier_for(0.0)).is_equal(1)
	assert_int(t.tier_for(-3.0)).is_equal(1)
	for i in range(1, 9):
		assert_int(t.tier_for(t.get_tier(i).threshold)).is_equal(i)
		if i > 1:
			assert_int(t.tier_for(t.get_tier(i).threshold - 0.01)).is_equal(i - 1)
	assert_int(t.tier_for(1e9)).is_equal(8)
	assert_float(t.space_height()).is_equal(t.get_tier(8).threshold)
	var prev := -1.0
	for h in [0.0, 1.0, 5.0, 30.0, 500.0, 9000.0, 50000.0, 200000.0]:
		var f := t.ladder_fraction(h)
		assert_float(f).is_between(0.0, 1.0)
		assert_float(f).is_greater_equal(prev)
		prev = f
	assert_float(TierSet.visual_y(10.0)).is_equal(10.0)
	assert_float(TierSet.visual_y(t.space_height())).is_less(1000.0)


func test_save_keys_best_height_runs_and_seen() -> void:
	Save.wipe()
	var r := _run([P1])
	r.save_enabled = true
	var cards: Array = r.draw_cards(P1)
	_kick(r, 1.0, r.tiers.space_height() * 2.0)
	assert_int(r.phase).is_equal(Phase.END)
	assert_float(float(Save.get_value("best_height", 0.0))).is_equal(r.tiers.space_height() * 2.0)
	assert_int(int(Save.get_value("runs_completed", 0))).is_equal(1)
	var seen: Array = Save.get_value("upgrades_seen", [])
	for c in cards:
		assert_bool(seen.has(String(c.id))).is_true()
	Save.wipe()
