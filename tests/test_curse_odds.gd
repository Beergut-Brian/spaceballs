## Playtest 2026-11-10 #2: hidden-curse odds per player are 40 % per pick until the first curse,
## 20 % until the second, then 0 %. In data (data/curse_odds.tres), proven here over seeded runs.
class_name TestCurseOdds
extends GdUnitTestSuite

const RunScript := preload("res://scripts/autoload/Run.gd")
const RUNS := 600


func test_odds_live_in_data() -> void:
	var o := load("res://data/curse_odds.tres") as CurseOdds
	assert_object(o).is_not_null()
	assert_float(o.chance(0)).is_equal_approx(0.4, 0.0001)
	assert_float(o.chance(1)).is_equal_approx(0.2, 0.0001)
	assert_float(o.chance(2)).is_equal(0.0)
	assert_float(o.chance(7)).is_equal(0.0)
	assert_int(o.max_curses()).is_equal(2)
	assert_int(o.from_round).is_equal(1)


func test_each_roll_matches_its_odds() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for so_far in [0, 1, 2]:
		var hits := 0
		for i in 20000:
			hits += 1 if RunScript.rolls_curse(5, false, so_far, false, rng) else 0
		var want: float = [0.4, 0.2, 0.0][so_far]
		assert_float(hits / 20000.0).override_failure_message("after %d curses" % so_far) \
				.is_between(want - 0.012, want + 0.012)


## Tuning the data really changes the game: 0 % everywhere means no curse ever.
func test_tuned_odds_are_used() -> void:
	var off := CurseOdds.new()
	off.by_curses_so_far = PackedFloat32Array([0.0])
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 2000:
		assert_bool(RunScript.rolls_curse(3, false, 0, false, rng, off)).is_false()


## Whole seeded runs through the real phase machine (random picks, both players): curses arrive
## early, nobody ever gets a third, and the first-curse round follows 40 % per allowed pick.
func test_seeded_runs_bring_curses_early_and_never_a_third() -> void:
	var firsts: Array = []
	var seconds: Array = []
	var counts := {0: 0, 1: 0, 2: 0}
	for s in RUNS:
		var res: Dictionary = TestSimulation.simulate(s + 1, [0, 1], "random")
		for p in [0, 1]:
			var rounds: Array = res["curse_rounds"][p]
			assert_int(rounds.size()).override_failure_message("run %d P%d: %s" % [s, p + 1, rounds]) \
					.is_less_equal(2)
			counts[rounds.size()] += 1
			if rounds.size() > 0:
				firsts.append(rounds[0])
			if rounds.size() > 1:
				seconds.append(rounds[1])
				assert_int(rounds[1]).is_greater(rounds[0] + 1)   # never two rounds running
	var n := RUNS * 2
	var by3 := firsts.filter(func(r: int) -> bool: return r <= 4).size() / float(n)
	print("[curse odds] %d player-runs: 0 curses %d, 1 curse %d, 2 curses %d; first curse median round %.1f, second %.1f; first by round 4: %.0f %%" % [
		n, counts[0], counts[1], counts[2], TestSimulation.median(firsts), TestSimulation.median(seconds), by3 * 100.0])
	# 40 % per pick from the first pick (a catch-up round skips a roll): about 1 - 0.6^3 = 78 % by
	# the third pick (round 4), the median first curse in round 3, nearly everyone gets one.
	assert_float(by3).is_between(0.65, 0.85)
	assert_float(TestSimulation.median(firsts)).is_less_equal(3.0)
	assert_int(counts[0]).is_less(n / 50)
	# The second comes later (20 %), well before the last rounds for most.
	assert_float(TestSimulation.median(seconds)).is_between(5.0, 9.0)
