# Contracts

Shared signals and APIs that lanes code against. Systems lane owns this file. Change it in its
own PR before changing code; every other lane reads the merged version.

## Autoloads (always available)

### `Game` (`scripts/autoload/Game.gd`)

State machine for the whole session.

```gdscript
enum State { TITLE, PLAYING, PAUSED, ROUND_END }
var state: State
signal state_changed(from: State, to: State)
signal round_started(round_index: int)
signal round_ended(round_index: int, result: Dictionary)   # result is game-defined

func start_round() -> void
func end_round(result: Dictionary = {}) -> void
func pause() -> void
func resume() -> void
func restart() -> void          # back to a fresh round, no questions asked
func quit(code: int = 0) -> void   # save, silence audio (no exit leaks), quit; use instead of get_tree().quit()
```

### `Players` (`scripts/autoload/Players.gd`)

Who is holding which controller. Never read device ids directly.

```gdscript
const P1 := 0
const P2 := 1
const COLOR := { P1: Color("3cc24a"), P2: Color("e4393c") }   # green, red

signal player_joined(player: int, device: int)
signal player_left(player: int)

func is_active(player: int) -> bool
func device_of(player: int) -> int
func action(player: int, action: String) -> String   # "p1_move_left" etc. for Input.*
```

Input map actions (defined in `project.godot`, per player, prefix `p1_` / `p2_`):
`move_left`, `move_right`, `move_up`, `move_down`, `action`, `jump`.
Global: `pause`, `restart`, `debug_overlay`, `debug_screenshot`.

### `Save` (`scripts/autoload/Save.gd`)

JSON under `user://saves/<profile>.json`. Autosave at every natural stopping point.

```gdscript
var profile: String                 # set by the launcher via --profile=<id>, default "p1"
signal saved()
signal loaded()

func get_value(key: String, default = null)
func set_value(key: String, value) -> void   # marks dirty
func flush() -> void                         # writes if dirty; Game.end_round() calls this
func wipe() -> void
```

### `Audio` (`scripts/autoload/Audio.gd`)

```gdscript
func play(cue: String, position = null) -> void   # cue = file stem in assets/audio/sfx/
func music(track: String, fade: float = 0.5) -> void
func stop_music(fade: float = 0.5) -> void
func stop_all() -> void                 # await: stop everything, let the audio thread release it
func silence() -> void                  # await: stop_all() and ignore play() from now on (quit)
func bark(character: String, bark: String) -> void   # from openjar-characters voice packs
```

Every action must call `Audio.play`. Missing cue files log a warning, never crash.

### `Debug` (`scripts/autoload/Debug.gd`)

F3 toggles the overlay (fps, state, player count). F12 saves `user://screenshots/<timestamp>.png`
and prints the path. `--screenshot-after=<seconds>` CLI flag does it headlessly for the Reviewer.

## Launcher handshake

The launcher starts a game with `--profile=<id>` and expects the game to:

- read `store/openjar.json` at export time (name, version, card art, clip) — produced by CI;
- exit with code 0 on a clean quit (Start → Quit on the pause menu);
- not change display mode (the launcher owns fullscreen).

## Game-specific contracts

Add this game's own signals and APIs below. Keep the same format.

### Template changes for this game (Systems, 2026-11-09)

```gdscript
# Game
signal restarted()                  # emitted by restart() before the fresh round 1 starts
signal restart_armed()              # first Select press; a second within 1 s restarts
const RESTART_WINDOW := 1.0
func press_restart(now_s: float) -> bool   # the two-presses-in-1-s rule; true = restarted
# restart() now resets round_index, so the round after a restart is always 1.

# Players
const VIRTUAL := -2                 # device id for keyboard / --demo players (no pad rebinding)
func join_virtual(player: int) -> void

# Audio
func play(cue: String, position = null, pitch: float = 1.0) -> void   # pitch is new, optional

# Fx (scripts/autoload/Fx.gd): placeholder visuals for "a visual on every action".
# Art replaces the insides with particles; the calls stay.
func puff(where: Vector3, color: Color = Color.WHITE, size: float = 1.0) -> void   # 3D burst
func flash(item: CanvasItem, color: Color = Color.WHITE) -> void                 # 2D blink
func pop(node: Node3D, amount: float = 1.3) -> void                              # squash-stretch
```

Physics layers (3D): 1 `world`, 2 `players`, 3 `pickups`, 4 `hazards`, 5 `balls`.
Kickers collide with `world`. Balls collide with `world` only. The ball's `KickZone` masks `players`.

### Solo mode (Players, Systems, 2026-11-09): playtest only

One pad (or the keyboard) plays both P1 and P2. Never on by default.

```gdscript
# Players
signal solo_changed(on: bool)         # emitted before the player_joined / player_left it causes
const SOLO_HOLD := 2.0                # seconds of Select (Back/View) + Start held together, real time
var solo := false
var solo_focus: int                   # P1 or P2: the player the solo device drives right now
func set_solo(on: bool, device: int = VIRTUAL) -> void   # VIRTUAL = keyboard + any pad (the --solo flag)
func set_solo_focus(player: int) -> void
func hold_step(device: int, both_down: bool, delta: float) -> bool   # the 2 s hold rule; true = toggled
static func solo_from_args(args: PackedStringArray) -> bool          # "--solo" after --
func reset() -> void                  # tests: solo off, nobody joined, InputMap as in project.godot
```

- Turn on with `-- --solo`, or by holding Select + Start together for 2 s on any pad; the same hold
  turns it off. A short press or a single button never toggles. Toggling plays `player_join`
  (pitched up for on, down for off) and pops a small two-heads icon in the bottom-right corner,
  which stays while solo is on. A Start press that paused the game as part of the hold is undone.
- While on: both players are active and `device_of` both is the solo device. Only the focused
  player's `p1_*` / `p2_*` actions have events (the solo pad, plus WASD and arrows, Space and Enter,
  Shift and Ctrl), so `Input.*(Players.action(p, ...))` and `move_vector(p)` keep working unchanged
  and the unfocused player reads nothing. Esc still pauses. Focus defaults to P1.
- Turning it off restores the InputMap; P1 keeps the solo device and P2 leaves (`player_left`), so
  P2 drops in again with the normal rules.
- Spaceballs: `main.gd` focuses the kicker whose turn it is (`KICK_P1` -> P1, `KICK_P2` -> P2).
  The pick takes P1 first, then P2 (the waiting half is dimmed); B on P2's turn goes back to P1's
  choice. Both `picked` signals are emitted when P2 picks. Turning solo on during round 1 before
  P1's kick restarts the run so both play from round 1. A player who leaves during their own
  `KICK_Px` is skipped (`Run`), so the round never waits on a pad that is gone.

### `Run` (`scripts/autoload/Run.gd`): one run of Spaceballs

Owns the per-player run state and the round phase machine. Scenes report events to it with the
`notify_*` calls; everybody else listens to the signals. Nothing else stores upgrades or heights.

```gdscript
enum Phase { IDLE, KICK_P1, FLIGHT_P1, KICK_P2, FLIGHT_P2, PICK, END }

# From GAME.md
signal kick_started(player: int)                       # auto-kick triggered, wind-up begins
signal kicked(player: int, power: float)               # foot meets ball
signal ball_tier_reached(player: int, tier: int)       # tier is 1..8, emitted once per new tier per flight
signal ball_stopped(player: int, height: float, tier: int)   # at the peak (height in metres)
signal upgrade_picked(player: int, upgrade_id: StringName)
signal reached_space(player: int)                      # once per run per player
func power_of(player: int, run_up_quality: float = 1.0) -> float
func upgrades_of(player: int) -> Array[UpgradeData]    # permanent upgrades, pick order, no curses

# Phase machine
signal phase_changed(from: Phase, to: Phase)
signal run_started()                                   # round 1 of a fresh run
signal run_finished()                                  # everyone in the run reached space -> END
signal player_benched(player: int)                     # P2 on the lawn chair (not in this round)
signal player_will_join(player: int)                   # P2 pressed a button; plays from next round
var phase: Phase
var round_index: int                                   # 1-based, mirrors Game.round_index
const MAX_ROUNDS := 15                                 # the round-15 kick always reaches space
const STRONG_ONLY_AFTER := 14                          # picks after round 14 are strong-only
const BASE_POWER := 8.0                                # round-1 kick, m/s at quality 1.0

func in_run(player: int) -> bool          # playing this round (P1 always; P2 if active at round start)
func in_space(player: int) -> bool
func curse_of(player: int) -> UpgradeData # the curse acting on this round's kick, or null
func best_height(player: int) -> float    # this run
func last_height(player: int) -> float
func tier_of_height(height: float) -> int # 1..8 via data/tiers.tres
func kick_height(player: int, power: float) -> float  # peak for this power (with the round-15 floor)
static func height_for_power(power: float) -> float   # v^2 / 2g
func pickers() -> Array[int]              # who picks this PICK phase (in run, not in space)
func draw_cards(player: int, rng: RandomNumberGenerator = null) -> Array[UpgradeData]  # 3 cards
func catch_up_for(player: int) -> bool    # 2+ tiers behind the other ball

# Reporting (called by the scenes, in this order per kick)
func notify_kick_started(player: int) -> void
func notify_kicked(player: int, run_up_quality: float) -> float   # returns power; KICK_Px -> FLIGHT_Px
func notify_tier(player: int, tier: int) -> void                  # may emit reached_space
func notify_stopped(player: int, height: float) -> void
func end_flight(player: int) -> void                              # after the comedy drop; next phase
func pick(player: int, upgrade: UpgradeData) -> void              # PICK; next round when all picked
func start_run() -> void                                          # Game.restart() calls through here
```

Rules the code implements (tests in `tests/test_run.gd`):
- power = `BASE_POWER` x product of `power_mult` of `upgrades_of` x run-up quality (0.8..1.2).
- A curse acts on the **next round's kick only** and is never added to `upgrades_of`. A curse with
  `scene_override` (the frog) also suppresses every upgrade for that kick: power = base x curse mult.
- Phase order per round: `KICK_P1 -> FLIGHT_P1 -> KICK_P2 -> FLIGHT_P2 -> PICK`, skipping a player
  who is not in the run or already in space. When nobody is left to pick: `END`.
- `Game.start_round()` at the start of every round, `Game.end_round({"round": n})` after the pick
  (that saves), `Game.end_round({"space": true})` at `END`.
- Save keys (per profile): `best_height` (float, metres), `runs_completed` (int),
  `upgrades_seen` (Array of `id` strings, every card ever drawn).

Draw rules (`draw_cards`): three different cards. Per card the kind is rolled 60 % normal,
20 % strong, 12 % joke, 8 % curse; an upgrade of `tier` <= the round band (1: rounds 1-4,
2: 5-8, 3: 9+) is picked, falling back to any tier. At least one `normal` card in every draw
before round 14. Catch-up (2+ tiers behind): only `normal` / `strong` cards with
`power_mult >= 1.7`. Picks after round 14: `strong` only.

### `UpgradeData` (`scripts/gameplay/upgrade_data.gd`, `class_name UpgradeData extends Resource`)

The schema Content fills (`data/upgrades/<id>.tres`). **Gameplay owns future changes to it**
(contract PR first). Fields exactly as GAME.md:

```gdscript
@export var id: StringName              # snake_case, stable
@export var name: String                # release notes and end card only
@export var icon: Texture2D             # no text
@export_range(1, 3) var tier: int = 1   # 1: rounds 1-4, 2: 5-8, 3: 9+
@export_enum("normal", "strong", "joke", "curse") var kind: String = "normal"
@export var power_mult: float = 1.0     # curses < 1.0
@export var visual: PackedScene         # attached to the kicker (see attach points)
@export var windup_anim: StringName     # optional
@export var kick_sfx: StringName        # optional, replaces kick_1..4 for that kick
@export var scene_override: PackedScene # round-takeover curses (the frog)
@export var description: String         # one line
```

### Tiers: `TierData` / `TierSet` (`scripts/gameplay/tier_data.gd`, `tier_set.gd`)

`data/tiers.tres` is a `TierSet` with exactly 8 `TierData`, lowest first; tier 8's
`threshold` is the space line. Content owns the numbers, Gameplay owns the classes.

```gdscript
# TierData
@export var id: StringName              # backyard, rooftops, treetops, kites, clouds, thin_air, edge, space
@export var threshold: float            # metres; the ball is in this tier at height >= threshold
@export var color: Color                # HUD block and placeholder landmark
@export var sky: Gradient               # top -> horizon
@export var landmark: PackedScene       # placed by height_ladder.tscn
@export var icon: Texture2D             # HUD strip picture and the peak stamp
@export var tier_up_cue: StringName = &"tier_up"

# TierSet
@export var tiers: Array[TierData]
func tier_for(height: float) -> int     # 1..8
func space_height() -> float
static func visual_y(height: float) -> float      # world Y for a real height (log-compressed above 20 m)
static func real_height(visual: float) -> float     # inverse of visual_y
func ladder_fraction(height: float) -> float   # 0..1 on the HUD strip, one equal block per tier
```

### Kicker (`scenes/players/kicker.tscn`, `CharacterBody3D`, script `kicker.gd`)

`jeff.tscn` / `chuck.tscn` inherit it. Art replaces `Body` (and adds an `AnimationTree` driven by
`state`); keep the node names below.

```gdscript
enum State { IDLE, APPROACH, WINDUP, FOLLOW_THROUGH, CHEER, CHAIR, CLOUD }
@export var player: int
var state: State
signal state_changed(state: State)
signal kick_contact(run_up_quality: float)   # the moment the foot meets the ball
signal hopped(player: int)                    # B
signal shouted(player: int)                   # A (harmless shout-hop; also the waiting cheer)

func begin_approach(ball_position: Vector3) -> void
func start_windup() -> void                   # the ball's KickZone calls this through main.gd
func set_waiting(chair: bool) -> void         # sideline cheer, or the lawn chair
func set_cloud() -> void                      # finished: cheers from a cloud, no gravity
func cheer() -> void                          # sound + hop + puff (waiting player's A, kick reactions)
func set_space_suit(on: bool) -> void         # end card
var stick_override: Variant                   # a Vector2 steers instead of the pad (tests, bots)
func set_frog(on: bool, override: PackedScene = null) -> void   # this round only
func attach_point(slot: StringName) -> Node3D # head, back, feet, hands, body
func add_upgrade_visual(upgrade: UpgradeData) -> void
func clear_upgrade_visuals() -> void
static func run_up_quality(path_length: float, straight_distance: float,
		avg_speed: float, max_speed: float, hopped: bool) -> float   # 0.8..1.2
```

Nodes: `Body` (placeholder capsule), `Accent` (player-colour band), `Attach/{Head,Back,Feet,Hands,Body}`
(`Marker3D`), `FrogSlot`, `Shape`. An upgrade `visual` scene picks its slot with root metadata
`attach_point` (StringName, default `body`).

### Ball (`scenes/ball.tscn`, `RigidBody3D`, Gameplay owns; grey-box placeholder)

```gdscript
signal kick_zone_entered(body: Node3D)   # the KickZone Area3D, while armed
signal returned()                         # comedy drop finished, ball back on the tee
@export var player: int
func place_on_tee(tee: Vector3) -> void
func arm(on: bool) -> void
func launch(power: float, peak_height: float) -> void
var height: float                         # real height in metres right now
```

Physics for the first 2 s or below 18 m (`HANDOFF_TIME`, `HANDOFF_HEIGHT`), then a scripted
deterministic ease-out arc to the peak, `PEAK_HOLD` 0.8 s, then the drop. The ball calls
`Run.notify_tier` / `Run.notify_stopped` itself; `main.gd` calls `Run.end_flight` on `returned`.

### Camera phases (`CameraRig` in `main.tscn`, script `scripts/gameplay/camera_rig.gd`)

```gdscript
enum Mode { FIELD, FOLLOW, PEAK, SPLIT, SPACE }
func frame_field(kicker: Node3D, tee: Vector3) -> void   # TV-sports framing of the run-up
func follow(ball: Node3D) -> void                         # zooms out with speed
func hold_peak() -> void
func split(on: bool) -> void                              # the pick; main viewport stops drawing 3D
func orbit(center: Vector3) -> void                       # space / end card
signal mode_changed(mode: Mode)
```

### UI

- `scenes/ui/upgrade_pick.tscn`: `open(draws: Dictionary, shown: Array)` (player -> Array[UpgradeData];
  the halves to show), `frame(player, target, from)` points a half's camera, `close()`,
  `signal picked(player, upgrade)`, `signal closed()`. Halves: `Halves/P1`, `Halves/P2`, each with
  `View/SubViewport/Camera3D` and `Cards/Card1..3`. Never times out.
- `scenes/ui/hud.tscn`: `Strip/Blocks` (8 tier blocks, top = space), `Strip/Markers/P1|P2`, `Strip/BestFlag`,
  `Rounds` (ball stack), `RestartHint`. `track(player, ball)` makes a marker follow a flying ball.
- `scenes/ui/end_card.tscn`: `open()`, `close()`, `signal restart_requested()` (A, after 1.2 s).
- `scenes/ui/upgrade_card.tscn`: one card (`Icon`), themed by Art.

### Debug / CLI (after `--`)

`--screenshot-after=<s>` (template), `--solo` (one pad plays both, see Solo mode), `--demo` (two virtual players, auto-picks, auto-restarts: the game
plays itself), `--timescale=<x>` (0.1 to 8), `--log-phases` (prints phases, heights, picks).
