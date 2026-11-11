## Physics-outcome suites stage their own world instead of inheriting one. CI runs suites in a
## different order and on slower machines, so a test must not depend on:
## - the physics step: a manual `_physics_process(1.0 / 60.0)` or a "within 0.5 s" contact window
##   only means what the test says at 60 ticks a second (move_and_slide steps by the engine's tick);
## - the global RNG: Ball.launch spins the ball and picks a curve side with randf();
## - what another suite left in Run: a curse left on P1 (test_playtest2's banana peel, the frog
##   round, a random curse from a played round) makes Ball.launch dribble instead of fly.
## enter() pins all three (the project's own 60 / 8, written down here); leave() undoes them.
class_name PhysicsPin
extends RefCounted

const TICKS := 60
const MAX_STEPS := 8
const SEED := 20261111

static var _ticks := -1
static var _steps := -1


static func enter(time_scale := 1.0) -> void:
	if _ticks < 0:
		_ticks = Engine.physics_ticks_per_second
		_steps = Engine.max_physics_steps_per_frame
	Engine.physics_ticks_per_second = TICKS
	Engine.max_physics_steps_per_frame = MAX_STEPS
	Engine.time_scale = time_scale
	seed(SEED)
	Run._clear()   # no curse, upgrade, space or best height from another suite


static func leave() -> void:
	Run._clear()
	Engine.time_scale = 1.0
	if _ticks >= 0:
		Engine.physics_ticks_per_second = _ticks
		Engine.max_physics_steps_per_frame = _steps
	_ticks = -1
	_steps = -1


## A booted main.tscn plays with two more RNGs: Run.rng draws the cards (and the curses) and each
## kicker's own _rng steers the demo bots. Seed both right after add_child, before round 1.
static func seed_main(main: Node) -> void:
	Run.rng.seed = SEED
	for p in main.kickers:
		var k: Kicker = main.kickers[p]
		k._rng.seed = SEED + 1 + p
		k._phase = k._rng.randf() * TAU   # _ready() rolled it from an unseeded RNG
