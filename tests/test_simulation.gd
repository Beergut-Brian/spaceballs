## Headless balance simulation: plays whole runs through the real Run phase machine with
## scripted (random) picks and checks GAME.md's promises: every run reaches space by round 15,
## the median is 10 to 12 rounds. Prints the distribution; Content re-runs this after tuning.
class_name TestSimulation
extends GdUnitTestSuite

const RunScript := preload("res://scripts/autoload/Run.gd")
const RUNS := 400


## policy: "random" picks any card (a five-year-old), "best" the highest power_mult.
static func simulate(seed: int, players: Array, policy := "random") -> Dictionary:
	var r: Node = RunScript.new()
	r.drive_game = false
	r.save_enabled = false
	r._ensure_data()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	r.rng.seed = seed * 7919 + 1
	r.start_run(players)
	var max_gap_after_6 := 0
	var curses := {0: 0, 1: 0}
	var floored := 0
	while r.phase != RunScript.Phase.END and r.round_index <= 20:
		if r.phase == RunScript.Phase.PICK:
			# Progress gap: best heights while both are still climbing (a curse dip is not progress).
			if players.size() == 2 and r.round_index > 6 and r.pickers().size() == 2:
				var t1: int = r.tier_of_height(r.best_height(0))
				var t2: int = r.tier_of_height(r.best_height(1))
				max_gap_after_6 = maxi(max_gap_after_6, absi(t1 - t2))
			for p in r.pickers():
				var cards: Array[UpgradeData] = r.draw_cards(p, rng)
				var card: UpgradeData = cards[rng.randi() % cards.size()]
				if policy == "best":
					for c in cards:
						if c.power_mult > card.power_mult:
							card = c
				if card.is_curse():
					curses[p] += 1
				r.pick(p, card)
			continue
		var p: int = r.phase_player()
		var hopped := rng.randf() < 0.3
		var quality: float = RunScript.QUALITY_MIN + rng.randf() * 0.35 + (0.03 if hopped else 0.0)
		var power: float = r.notify_kicked(p, quality)
		var h: float = r.kick_height(p, power)
		if RunScript.height_for_power(power) < r.tiers.space_height() and h >= r.tiers.space_height():
			floored += 1
		r.notify_tier(p, r.tier_of_height(h))
		r.notify_stopped(p, h)
		r.end_flight(p)
	var out := {
		"ended": r.phase == RunScript.Phase.END,
		"rounds": players.map(func(p): return r.space_round(p)),
		"gap": max_gap_after_6,
		"curses": curses,
		"floored": floored,
	}
	r.free()
	return out


static func median(xs: Array) -> float:
	var s := xs.duplicate()
	s.sort()
	var n := s.size()
	return s[n / 2] if n % 2 == 1 else (s[n / 2 - 1] + s[n / 2]) / 2.0


static func histogram(xs: Array) -> String:
	var counts := {}
	for x in xs:
		counts[x] = counts.get(x, 0) + 1
	var keys := counts.keys()
	keys.sort()
	var lines := PackedStringArray()
	for k in keys:
		lines.append("  round %2d: %4d %s" % [k, counts[k], "#".repeat(ceili(counts[k] * 60.0 / xs.size()))])
	return "\n".join(lines)


func _check(label: String, players: Array, policy: String) -> Array:
	var rounds: Array = []
	var gaps: Array = []
	var floored := 0
	for s in RUNS:
		var res := simulate(s + 1, players, policy)
		assert_bool(res["ended"]).override_failure_message("%s run %d never ended" % [label, s]).is_true()
		for x in res["rounds"]:
			assert_int(x).is_between(1, RunScript.MAX_ROUNDS)
			rounds.append(x)
		gaps.append(res["gap"])
		floored += res["floored"]
	print("\n[sim] %s, %d runs, %s picks: median %.1f, min %d, max %d\n%s" % [
		label, RUNS, policy, median(rounds), rounds.min(), rounds.max(), histogram(rounds)])
	print("[sim] kicks lifted to space by the round-15 floor: %d of %d player-runs" % [floored, rounds.size()])
	if players.size() == 2:
		print("[sim] max tier gap after round 6: median %.1f, worst %d, runs with gap > 2: %d" % [
			median(gaps), gaps.max(), gaps.filter(func(g): return g > 2).size()])
		assert_int(gaps.max()).override_failure_message("catch-up let the balls drift > 2 tiers").is_less_equal(2)
	return rounds


func test_single_player_random_picks() -> void:
	var rounds := _check("1P", [0], "random")
	assert_float(median(rounds)).is_between(10.0, 12.0)


func test_two_players_random_picks() -> void:
	var rounds := _check("2P", [0, 1], "random")
	assert_float(median(rounds)).is_between(10.0, 12.0)


func test_best_picks_are_faster_but_capped() -> void:
	var rounds := _check("1P", [0], "best")
	assert_float(median(rounds)).is_less(10.0)
