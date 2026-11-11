# Contracts

Shared signals and APIs that lanes code against. Systems lane owns this file. Change it in its
own PR before changing code; every other lane reads the merged version.

## Autoloads (always available)

### `Game` (`scripts/autoload/Game.gd`)

State machine for the whole session. Boots into `LOBBY` (the start screen / main menu,
`scenes/ui/lobby.tscn`) unless `--demo` is passed, which skips straight to a round.

```gdscript
enum State { LOBBY, PLAYING, PAUSED, ROUND_END, TITLE = 0 }   # TITLE: old name of LOBBY, deprecated
var state: State
var round_index: int
var demo: bool                  # --demo: skip the lobby, both players join as virtual players
signal state_changed(from: State, to: State)
signal round_started(round_index: int)
signal round_ended(round_index: int, result: Dictionary)   # result is game-defined
signal lobby_ready(players: Array)   # the lobby countdown finished; players = who readied up
signal back_to_lobby()               # pause menu Restart: clear the level, show the lobby
signal quit_requested()              # emitted just before a clean quit; last chance to save

func start_round() -> void
func end_round(result: Dictionary = {}) -> void
func pause() -> void
func resume() -> void
func restart() -> void          # Select twice: a fresh run from round 1 (see restarted below)
func to_lobby() -> void         # back to the start screen; round_index resets to 0
func finish_lobby(players: Array) -> void   # the lobby calls this: emits lobby_ready, starts round 1
func quit(code: int = 0) -> void            # Save.flush(), silence audio (no exit leaks), exit; the launcher resumes
```

Start (`pause`) toggles `PLAYING` <-> `PAUSED`. The pause menu (`scenes/ui/pause_menu.tscn`) is a
text menu over the blurred game: Resume, Restart (`to_lobby()`), Settings, Back to Open Jar
("Leave the game?" Stay / Leave, then `quit()`). It shows who paused (`paused_by`). Either pad
moves the cursor; A selects; B backs out of Settings / the question, else resumes; Start resumes.
Window close also goes through `quit()`. Menus are for the grown-up: see `docs/ui.md`.

### Lobby (`scenes/ui/lobby.tscn`, `scenes/ui/lobby.gd`)

Start screen and main menu in one, the Showtime menu kit (`docs/ui.md`): the game's slanted title
over a stage (sunburst, and the game's world blurred behind it if the skin asks), each player's
`Roster` pick (P1 green ring, left; P2 red, right; Jeff and Chuck by default) on podiums with name
plates and READY! stamps, and a wedge of slanted bars: Play / Settings / Back to Open Jar.

- A on a new pad: that pad joins and is ready; its podium lights up and its character waves.
- Left / right while joined and not ready: the character chooser (`Roster`, above).
- B: un-ready (or back out of Settings / the question). Both ready: a 3-beat countdown; on the last
  beat the stamps say GO!, both characters cheer, the three-stripe wipe covers the screen and
  `Game.finish_lobby(ready_players)` starts round 1 (with the skin's "ROUND 1" card). Un-readying
  cancels, except during the last beat.
- A held on Play for 1.5 s by a ready player starts without the other (Play fills up).
- Back to Open Jar asks "Leave the game?" (Stay focused first), Leave calls `Game.quit()`.
- Solo mode readies both. A pad that joins mid-game plays from the next round. Solo is never
  turned on at boot by the saved setting (playtest only): only `--solo` or Select + Start.

The look per game comes from one resource, `MenuSkin` (`scenes/ui/kit/menu_skin.gd`): title,
accent / sunburst / deep colours, the two character scenes and names, the backdrop
(`SUNBURST`, `SCENE` live world, `TEXTURE` still, `SCREEN` the level behind), the round card.
`res://data/menu_skin.tres` is used automatically; or `UiStyle.use_skin(skin)` in code.

```gdscript
@export var title_texture: Texture2D        # wins over the skin's title
@export var title_text: String              # wins over the skin's title
var round_card_subtitle: String             # "JEFF KICKS FIRST" under ROUND 1; set in code
var round_card_color: Color                 # its strip colour (default the skin's accent2)
signal player_readied(player: int, ready: bool)
signal countdown_started()
signal countdown_cancelled()
signal launching()                          # the last beat: the wipe is starting
# Spots/P1/Character, Spots/P2/Character: CharacterSlots hosting the skin's characters, by default
# the player's Roster pick; the lobby calls set_joined(on: bool), wave() and cheer() on the
# character if it has them, and set_character(id: String) when the pick changes.
# Backdrop, Wedge, TitleArt, Buttons/Play, Buttons/Settings, Buttons/Door, Settings, Confirm.
```

`ShowtimeWipe.run(on_cover, title, subtitle, color)` plays the same wipe anywhere (between rounds).
`UiSound.play(cue, pitch)` plays a menu cue: the `.ogg` in `assets/audio/sfx/` if there is one,
else a synthesized stand-in (cue list in `docs/ui.md`).

### Settings (`scenes/ui/settings_panel.gd`, class `SettingsPanel`)

Music volume, sound volume, screen shake, solo playtest mode; in the lobby and the pause menu.
Per install, through `Save.set_setting()`, written the moment a value changes.

```gdscript
const MUSIC := "music_volume"     # 0..1, default 0.8 -> Audio "Music" bus
const SOUND := "sound_volume"     # 0..1, default 1.0 -> Audio "SFX" bus
const SHAKE := "screen_shake"     # bool, default true
const SOLO := "solo_playtest"     # bool, default false; the toggle in Settings. Not restored at boot
static func screen_shake() -> bool  # games check this before shaking the camera
```

### `Roster` (`scripts/autoload/Roster.gd`)

Who each player is: the playable characters (from `openjar-characters`, vendored by
`scripts/tools/sync_characters.sh` into `assets/characters/<id>/` and `data/roster.json`) and each
slot's pick. Player colours stay with the slot (`Players.COLOR`), never the character.

```gdscript
signal pick_changed(player: int, id: String)
signal said(player: int, id: String, path: String)   # a voice line started; player -1: shared voice

var data_path := "res://data/roster.json"   # tests point this at a fixture, then reload()
var picks_path: String                       # the shared file; tests point this at user://
var characters_tag: String                   # the openjar-characters tag the roster came from

func roster() -> Array[String]               # playable ids in chooser order
func has(id: String) -> bool
func info(id: String) -> Dictionary          # {} if unknown, else:
	# id, name ("Jeff"), glb ("res://assets/characters/jeff/jeff.glb" or ""),
	# pixel ("res://assets/characters/jeff/pixel.png" or ""), voice ("res://.../voice/" or ""),
	# barks (Array of file stems in voice/), catchphrase ("res://.../voice/catchphrase.ogg" or ""),
	# default_for (1, 2 or 0)
func default_for(player: int) -> String      # data/roster.json defaults.P1 / .P2
func pick(player: int) -> String             # never "" while the roster has a character
func set_pick(player: int, id: String) -> bool   # false (no change) if unknown or the other's pick
func next_free(player: int, dir: int) -> String  # dir +1 / -1 through roster(), skipping the
                                                 # other player's pick; pick(player) if none free
func taken(id: String, by_other_than: int) -> bool
func reload() -> void                        # re-read roster.json, args, the shared file
func bark(id: String, player := -1) -> bool  # plays a random voice bark; false if it has none
func catchphrase(id: String, player := -1) -> bool  # the catchphrase, else bark(); false if neither
func voice_player(player := -1) -> AudioStreamPlayer  # P1 / P2: that slot's own panned voice
                                                 # (VoiceP1 / VoiceP2 bus); -1: the shared one.
                                                 # A new line cuts off only that voice's last one
var last_said: Dictionary                    # voice (player or -1) -> res:// path of its last line
```

**Resolving a slot** at start (`reload()`), first hit that is in `roster()`:
1. `--p1-char=<id>` / `--p2-char=<id>` (either side of `--`)
2. the shared file `players.json[Save.profile]["P1" | "P2"]`
3. `defaults.P1` / `defaults.P2`
4. the first roster id the other player has not got

Unknown, removed or resident ids are skipped, never an error. If both slots resolve to the same
id, P2 moves to `next_free(P2, 1)`. No two players are ever the same character.

**The shared picks file** (`picks_path`): `OS.get_data_dir() + "/openjar/players.json"` (Linux
`~/.local/share/openjar/players.json`), outside every game's `user://`. Shared with every Open Jar
game and the launcher:

```json
{ "p1": { "P1": "jeff", "P2": "chuck" }, "kid": { "P1": "chuck", "P2": "jeff" } }
```

Keyed by save profile, then slot. Written the moment a pick changes (`set_pick`): read the file,
change only this profile's slot, keep every other key, write `players.json.tmp`, rename over
`players.json` (folder created if missing). A missing or broken file reads as empty. Roster never
touches the game's own `user://` saves.

**Launch args**: the launcher passes `--profile=<id> --p1-char=<id> --p2-char=<id>`. They win over
the file; a pick changed in the game is still written to the file.

**Spawning the chosen character** (game code; `docs/ui.md` "Per game"):

```gdscript
var who := Roster.info(Roster.pick(player))
var body: Node = load(who.glb).instantiate()      # 3D; a pixel game uses load(who.pixel)
add_child(body)
```

**The chooser** (lobby): joined and not ready, left / right (stick or D-pad) calls
`Roster.set_pick(p, Roster.next_free(p, dir))`; the podium swaps with a squash/pop and a poof, the
plate shows the new name, the `char_swap` cue plays, and `SAY_SETTLE` (0.3 s) after the last step
the character says `Roster.catchphrase(id, p)` once (`docs/ui.md` "Chooser voice"). Ready: left / right does
nothing; B un-readies. Solo: Select picks which podium the pad drives (A, B and left / right).

### `Players` (`scripts/autoload/Players.gd`)

Who is holding which controller. Never read device ids directly.

```gdscript
const P1 := 0
const P2 := 1
const COLOR := { P1: Color("3cc24a"), P2: Color("e4393c") }   # green, red
const VIRTUAL := -2             # device of a keyboard or --demo player

signal player_joined(player: int, device: int)
signal player_left(player: int)
signal solo_changed(on: bool)

var solo: bool                  # playtest only: one pad plays both players
var solo_focus: int             # the player the solo pad drives right now; the game sets it

func is_active(player: int) -> bool
func device_of(player: int) -> int
func active_players() -> Array[int]
func action(player: int, action: String) -> String   # "p1_move_left" etc. for Input.*
func move_vector(player: int) -> Vector2
func join_virtual(player: int) -> void
func set_solo(on: bool, device: int = VIRTUAL) -> void
func set_solo_focus(player: int) -> void   # the game calls this when the other player's turn comes
func reset() -> void                       # tests: nobody joined, solo off, InputMap restored
```

Solo mode: `--solo` on the command line, or hold Select + Start together for 2 s on a pad (again
to turn it off). Both players join on that pad; only `solo_focus`'s actions get its events. A
two-heads icon shows top-left while it is on. A keyboard key from a player's action joins that player.

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

# Per install, not per profile: user://settings.json, written on every set_setting().
var settings_path: String                    # tests point this elsewhere
func get_setting(key: String, default = null)
func set_setting(key: String, value) -> void
func reload_settings() -> void
func wipe_settings() -> void
```

### `Audio` (`scripts/autoload/Audio.gd`)

```gdscript
func play(cue: String, position = null, pitch: float = 1.0) -> void   # cue = file stem in assets/audio/sfx/
func music(track: String, fade: float = 0.5) -> void   # no-op if that track is already playing
func music_level(level: int, fade: float = 1.0) -> void   # layered tracks: layers 1..level audible
func stop_music(fade: float = 0.5) -> void
func stop_all() -> void                 # await: stop everything, let the audio thread release it
func silence() -> void                  # await: stop_all() and ignore play() from now on (quit)
func bark(character: String, bark: String) -> void   # from openjar-characters voice packs
func set_volume(bus: String, linear: float) -> void  # "Music" / "SFX", 0..1; Settings calls it
func get_volume(bus: String) -> float
```

Audio creates the `Music` and `SFX` buses at start if the project has no bus layout, and applies
the saved volumes.

Every action must call `Audio.play`. Missing cue files log a warning, never crash.

Menu cues (Audio lane supplies the files): `ui_move`, `ui_confirm`, `ui_back`, `player_join`,
`player_ready`, `player_unready`, `count_tick`, `round_start`, `pause`, `solo_on`, `solo_off`.
Spaceballs: `Audio.ALIASES` maps the ones with no file to an existing cue and pitch
(`ui_move`/`count_tick` -> `card_move`, `ui_back` -> `ui_confirm`, `player_ready`/`player_unready`/
`solo_on`/`solo_off` -> `player_join`). A real file for the cue wins over its alias.

### `Debug` (`scripts/autoload/Debug.gd`)

F3 toggles the overlay (fps, state, player count). F12 saves `user://screenshots/<timestamp>.png`
and prints the path. `--screenshot-after=<seconds>` CLI flag does it headlessly for the Reviewer.

## Launcher handshake

The launcher starts a game with `--profile=<id>` and expects the game to:

- read `store/openjar.json` at export time (name, version, card art, clip) — produced by CI;
- exit with code 0 on a clean quit (`Game.quit()`: the door button in the lobby or the pause menu);
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
  (pitched up for on, down for off) and pops a small two-heads icon in the top-left corner,
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
func reveal_curse(player: int, rng = null) -> UpgradeData  # after a pick: the curse it secretly was, or null
func curses_of(player: int) -> int        # curses this player has had this run
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
func start_run(players: Array = []) -> void                       # Game.restart() calls through here
func plan_run(players: Array) -> void       # the lobby's ready players play from the next round 1
func join_next_round(player: int) -> void   # joined but not in the run: plays from the next round
func stop_run() -> void                     # back to the lobby: run cleared, phase IDLE
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

Draw rules (`draw_cards`): three different cards. Per card the kind is rolled 65 % normal,
22 % strong, 13 % joke; **curses are never offered** (playtest 2026-11-09 #2); an upgrade of `tier` <= the round band (1: rounds 1-4,
2: 5-8, 3: 9+) is picked, falling back to any tier. At least one `normal` card in every draw
before round 14. Catch-up (2+ tiers behind): only `normal` / `strong` cards with
`power_mult >= 1.7`. Picks after round 14: `strong` only.

Hidden curses: after a pick, `main.gd` asks `reveal_curse(p)`. With `CURSE_REVEAL_ODDS` (14 %) the
card turns out to be a curse of the round's band: the pick UI flips it (`UpgradePick.reveal_curse`,
awaitable) and `main.gd` calls `pick(p, curse)` instead of the picked card. Never on the first pick
(round 1), never for a player on catch-up, never two rounds running, at most `CURSE_MAX` (2) per
player, none in the strong-only rounds. About two per two-player run (`tests/test_simulation.gd`).

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
@export var visual: PackedScene         # wearable cards (slot not none/ball): the gear glb assets/gear/<id>.glb,
                                        # worn through JarlingEquipment (Kicker, "Worn gear"). Other cards: a prop
                                        # scene for the kicker's attach points.
@export var windup_anim: StringName     # optional
@export var kick_sfx: StringName        # optional, replaces kick_1..4 for that kick
@export var scene_override: PackedScene # round-takeover curses (the frog)
@export var description: String         # one line
# Gameplay effects (Gameplay, 2026-11-09 playtest): every pick is felt and seen, not just a number.
@export_enum("head", "face", "back", "hands", "waist", "knees", "feet", "ball", "none") var slot: String = "none"
@export var run_speed_mult: float = 1.0 # top run speed (stacks by product)
@export var accel_mult: float = 1.0     # how fast he gets to top speed (product)
@export var jump_mult: float = 1.0      # B hop height (product)
@export var gravity_mult: float = 1.0   # the kicker's own gravity: < 1 is floaty hops (product)
@export var runup_bonus: float = 0.0    # added to run-up quality (sum; the 1.2 cap stays)
@export var kick_style: StringName = &"normal"  # normal|stomp|cannon|spin|pogo|jet|zap: the kick move + fx
@export var ball_effect: StringName = &"none"   # none|bouncy|floaty|rocket|curve|split|sparkle|confetti
@export var run_fx: StringName = &"none"        # none|flame|bounce|honk|wind|sparkle|squeak: while running
@export var bulk: float = 1.0           # body scale while worn (Super Strength bulks up)
@export var shake: float = 0.0          # camera shake on the kick, 0..1
```

Effects rule: **stats add up, the look is what you wear.** Every non-curse pick stays in
`Run.upgrades_of` and its `power_mult` and stat multipliers (`run_speed_mult`, `accel_mult`,
`jump_mult`, `gravity_mult`, `runup_bonus`) apply for the rest of the run. One item per `slot`
(`none` never conflicts): a new item in an occupied slot replaces the old one *visually*, and only
worn items drive the looks (`kick_style`, `ball_effect`, `run_fx`, `bulk`, `shake`); the newest
worn item with a non-default `kick_style` wins, `ball_effect`s combine. A curse's fields act on its
one kick (Systems rule above), on top of the gear. `Run.effects_of(player) -> Dictionary` resolves
all of it (keys: the field names above plus `worn: Dictionary slot -> UpgradeData`).

Draw rule: `draw_cards` never offers a non-curse card the player already has (`Run.draw_from`
takes the owned list); curses can repeat.

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

`jarling_kicker.tscn` inherits it: `Body/Jarling` (`art/scripts/jarling_rig.gd`) holds the player's
**Roster pick** (docs/roster.md), its vendored `.glb` as `Body/Jarling/Model`, same rig, collision and
gear for any standard-body Jarling. `main.tscn` spawns two of them as `Kickers/P1` / `Kickers/P2`
(no Jeff/Chuck scenes); `jeff.tscn` / `chuck.tscn` inherit it with a fixed `character_id`
(previews, tests). Keep the node names below.

```gdscript
enum State { IDLE, APPROACH, WINDUP, FOLLOW_THROUGH, CHEER, CHAIR, CLOUD, GAG }   # GAG: Gameplay polish, appended
@export var player: int
@export var character_id: String   # Roster id; "" at spawn = Roster.pick(player) (then default, then any)
func set_character(id: String) -> bool   # become `id` in place; worn gear moves over at its level; false = unknown id
func character_name() -> String          # Roster name ("Jeff"), "Player N" if none
static func voice_cue(base: String, id: String) -> String   # "<base>_<id>" if sfx has it, else "<base>"; never another character's
# main.gd: Roster.pick_changed -> kickers[p].set_character(id) (the chooser changes the field kicker too).
# jarling_rig.gd: set_model(scene, detach) swaps the .glb; "<id>_hat" pops on the kick if the model has it.
# Frog form: Jeff's hood / Chuck's hat only on that character; anyone else is a frog in the player tint.
var state: State
signal state_changed(state: State)
signal kick_contact(run_up_quality: float)   # the moment the foot meets the ball
signal hopped(player: int)                    # B
signal shouted(player: int)                   # A (harmless shout-hop; also the waiting cheer)

func begin_approach(ball_position: Vector3) -> void   # arms free roam (state APPROACH) for this kick
func start_windup() -> void                   # the ball's KickZone calls this through main.gd
func set_waiting(chair: bool) -> void         # sideline cheer, or the lawn chair
func set_cloud() -> void                      # finished: cheers from a cloud, no gravity
func cheer() -> void                          # sound + hop + puff (waiting player's A, kick reactions)
func set_space_suit(on: bool) -> void         # end card
func dance(on: bool) -> void                  # end card: cheer state plus a sway and a spin now and then
# Wind-up gags (Gameplay polish, 2026-11-09)
const GAGS: Array[StringName] = [&"slip", &"chase", &"waddle", &"trip", &"sneeze"]
var windup: UpgradeData                       # set before begin_approach: this kick's gag source, or null
signal gag_started(gag: StringName)           # state GAG: the full-body gag runs before (or instead of) WINDUP
func gag_of(upgrade: UpgradeData) -> StringName   # the upgrade's windup_anim if it is one of GAGS
var stick_override: Variant                   # a Vector2 steers instead of the pad (tests, bots)
func set_frog(on: bool, override: PackedScene = null) -> void   # this round only
func attach_point(slot: StringName) -> Node3D # head, back, feet, hands, body: props only (curses, ball cards)
var equipment: JarlingEquipment              # worn gear (see "Worn gear" below)
static func gear_for(upgrade: UpgradeData) -> JarlingGear   # assets/gear/<upgrade.id>.json, null if not wearable
func worn_piece(slot: String) -> Node3D      # what is worn for an UpgradeData.slot, or null
func add_upgrade_visual(upgrade: UpgradeData) -> void
func clear_upgrade_visuals() -> void
static func run_up_quality(path_length: float, straight_distance: float,
		avg_speed: float, max_speed: float, hopped: bool) -> float   # 0.8..1.2
# Run styles and the short run-up (Polish, 2026-11-10: P-03, P-04, K-08)
var run_style: RunStyle                       # RunStyle.for_character(character_id); set_character updates it
var run_amount: float                         # 0..1 of top speed while running (APPROACH / roaming), else 0
var stride: float                             # step phase: +1 per step, for the rig's arms
signal footfall(hard: float)                  # a foot lands on the run; hard > 0 = a stomp (thud + dust)
func has_run_up() -> bool                     # covered RUNUP_PACE x top speed x RUNUP_SHORT m straight, just now
var poking: bool                              # this kick is a toe-poke (set by start_windup)
```

Run style (`scripts/gameplay/run_style.gd`, `data/run_styles/<character id>.tres`, else
`default.tres`): per Roster character, not per player. `bob`, `cadence`, `sway`, `lean`, `stomp`
(lift slow, drop hard) and `land_squash` move the kicker's Body; `arm_swing`, `windmill`, `arm_keep`
and `flap` move the Jarling's arms and comb through `art/scripts/run_style_modifier.gd`
(`SkeletonModifier3D` under the Skeleton3D, added by `jarling_rig.gd`), and `anim_speed` scales the
run clip. Jeff: windmilling arms, flapping comb, a big loose bob. Chuck: stiff arms, slow heavy steps,
a hard landing with a squash, a thud (`land`, low) and a dust puff on every step.

Short run-up (K-08): `start_windup()` checks `has_run_up()` (straight-line distance over the last
`RUNUP_SHORT` = 0.6 s at least `RUNUP_PACE` = 0.45 of his top speed, about 1.5 m at base speed). Without
one (a stick wiggle at the ball, a nudge from standing) the kick is a toe-poke: `poking`, a quick tap
(squeak) instead of the lunatic wind-up, quality `QUALITY_MIN`. It still kicks, every time. Gags and
the frog are never a poke.

Free movement (2026-11-09 playtest, supersedes auto-steer): in `APPROACH` the kicker runs where the
stick points (acceleration, turn-in-place, B hop), with no pull toward the ball and no movement with
no input. The kick starts when *his own* armed ball's `KickZone` sees him (`main.gd` checks the
body). `effects: Dictionary` (from `Run.effects_of`, set by `main.gd` before `begin_approach`)
scales speed/accel/hop/gravity and picks the run fx and kick style. Run-up quality is measured over
the last `RUNUP_WINDOW` seconds before contact (roaming first costs nothing). The field is bounded by
a soft wall (`bounds: Rect2` on XZ, default inside the fence; the spawns are 30 m from the tees,
about 5.6 s of running at base speed). `bot: bool` (demo) swerves once, then runs in. The bystander
(`CHEER` with `roam`) runs at full speed with all his gear, his own ball is hidden until his turn,
and touching the kicker's ball only bumps him off it. A hop over his own ball no higher than
`main.gd` `SNAP_OVER` above its top snaps him down in front of it and kicks; higher, he flies over.
Banana peel (`slip`): the peel lies `PEEL_GAP` before the ball; stepping on it emits `slipped()`
and `main.gd` starts the kick there: he slides into the ball, which dribbles (`ball.dribbles()`).

Wind-up gags: `main.gd` sets `windup` to the round's curse, else the newest upgrade with a
`windup_anim`. `start_windup()` then enters `GAG` (emits `gag_started`), plays the full-body gag on
`Body` (and the upgrade's `visual` as a temporary prop for curses, which never join the stack),
and always ends in `kick_contact` exactly once: the gag changes the approach, never the result.
`slip` and `trip` boot the ball on the way down (GAG -> FOLLOW_THROUGH); `chase`, `waddle` and
`sneeze` finish with a short `WINDUP`. The frog's flop wins over any gag. `waddle` also slows the
approach to 70 %.

Nodes: `Body` (placeholder capsule), `Accent` (player-colour band), `Attach/{Head,Back,Feet,Hands,Body}`
(`Marker3D`), `FrogSlot`, `Shape`. An upgrade `visual` scene picks its slot with root metadata
`attach_point` (StringName, default `body`).

**Worn gear (Gear Art, 2026-11-09 playtest).** Jeff and Chuck are the rigged Jarling glbs from
`openjar-characters` v0.1.0, with ten `slot_<name>` markers on their bones (head, face, back, hand_l/r,
waist, knee_l/r, foot_l/r) and separable body parts. `scripts/equipment/jarling_equipment.gd` and
`jarling_gear.gd` are vendored from that repo (its `docs/equipment.md` is the format contract; do not
fork it here). Every card whose `slot` is not `none`/`ball` has a gear item in `assets/gear/`:
`<id>.glb` (the card's `visual`) + `<id>.json`, built by `art/tools/build_gear_spaceballs.py`.
`add_upgrade_visual(upgrade)` equips it through `kicker.equipment`: a pick for an occupied slot swaps
the item (poof + sound), a repeat pick levels it up (a little bigger, trim shown), nothing ever
stacks. A card slot is one item even when the pieces sit on other body slots (a foam finger on one
hand replaces gloves on both). Shoes and gloves hide the feet and hands they replace. Effect hooks in
a gear glb, driven by the kicker: `fx_flame*` nodes show while running or kicking, `fx_spin*` nodes
turn around their local Y (faster while running or kicking), `fx_orbit*` nodes turn slowly. The
grey-box `kicker.tscn` has no Jarling, so it gets plain markers for the same ten slots.
Exports must include `assets/gear/*.json` (non-resource filter).

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

Sky hook (Sky lane, 2026-11-09): the only way sky objects touch the ball.

```gdscript
signal launched(peak_height: float)       # after launch() starts a real flight (not the frog dribble)
# every ball is in group &"balls"
const SKY_MAX_OFFSET := 0.04              # reaction offset <= 4 % of the ball's visual height ...
const SKY_MIN_OFFSET := 0.6               # ... or 0.6 m, whichever is bigger
const SKY_MAX_HOLD := 0.6                 # total hit-stop seconds per flight
func sky_react(push: Vector3, hold: float = 0.0, spin: float = 0.0) -> void
var sky_offset: Vector3                   # the Mesh's current world-space offset (read only)
```

**The balance rule:** a sky reaction never changes the outcome. `peak_height`, the scripted arc,
the physics velocity and `height` are untouched. `push` (m/s) kicks a damped spring that offsets
only the `Mesh` child, clamped to `max(SKY_MIN_OFFSET, SKY_MAX_OFFSET * visual height)`, back to
zero in about a second. `hold` pauses the scripted arc's clock (hit-stop; ignored in the physics
phase), capped at `SKY_MAX_HOLD` per flight, so a flight lasts at most 0.6 s longer and peaks at
exactly the planned height. `spin` adds a little extra spin to the mesh.

### Sky objects (`scenes/sky/`, Sky lane)

- `data/sky.tres` is a `SkySet` (`scripts/gameplay/sky_set.gd`): one `SkyTier` per ladder tier id
  with `count_min..count_max` objects per kick, a world `scale`, and weighted `SkyEntry`s
  (`scene`, `weight`, `on_path` = may be placed in the ball's path).
- `SkyField` (`scripts/gameplay/sky_field.gd`, a child of `HeightLadder`) listens to every ball's
  `launched`, rolls a seeded plan for that flight (`plan(peak, seed)`), spawns each object shortly
  before the ball reaches it, frees objects that drop far below the ball, and frees everything on
  the ball's `returned` or next `launched`.
- Every object scene's root is a `SkyObject` (`scenes/sky/sky_object.gd`): `@export var cue`,
  `hit_radius`, `near_radius`; `hit(ball)` plays the cue, does its gag and calls `ball.sky_react`;
  `near(ball)` is an optional startle when the ball only passes by.
- Aim: `SkyField.hits_for(tiers)` objects per flight are put on the ball's path (1 for a backyard
  kick, up to 5 for space); the rest sit beside it as scenery.

### Camera phases (`CameraRig` in `main.tscn`, script `scripts/gameplay/camera_rig.gd`)

```gdscript
enum Mode { FIELD, FOLLOW, PEAK, SPLIT, SPACE }
func frame_field(kicker: Node3D, tee: Vector3) -> void   # TV-sports framing of the run-up
func follow(ball: Node3D) -> void                         # zooms out with speed
func hold_peak() -> void
func split(on: bool) -> void                              # the pick; main viewport stops drawing 3D
func orbit(center: Vector3, radius: float = 7.0, height: float = 2.5) -> void   # space / end card
func frame_close(on: bool) -> void                        # tighter FIELD framing (the frog round)
signal mode_changed(mode: Mode)
```

### UI

- `scenes/ui/upgrade_pick.tscn`: `open(draws: Dictionary, shown: Array)` (player -> Array[UpgradeData];
  the halves to show), `frame(player, target, from)` points a half's camera, `close()`,
  `signal picked(player, upgrade)`, `signal closed()`. Halves: `Halves/P1`, `Halves/P2`, each with
  `View/SubViewport/Camera3D` and `Cards/Card1..3`. Never times out.
- `scenes/ui/hud.tscn`: `Strip/Blocks` (8 `TierIcon` blocks, top = space), `Strip/Markers/P1|P2`, `Strip/BestFlag`,
  `Rounds` (ball stack), `RestartHint`, `Stamp`. `track(player, ball)` makes a marker follow a flying ball.
  `show_stamp(player, tier)` (also on every `Run.ball_stopped` while the HUD shows): the tier's badge
  slams in at the top, ~1.4 s. The best flag rides up with a ball that beats `Save` `best_height`.
- `TierIcon` (`scenes/ui/tier_icon.gd`, `Control`): `tier_id` (a `TierData.id`), `bg`, `round_badge`,
  `ring`; draws the tier's landmark picture. `TierIcon.has_picture(id)`.
- `SlowMo` (`scripts/gameplay/slow_mo.gd`, child of main): `trigger()` = `Engine.time_scale` x0.25 for
  0.5 real s (overlaps extend; leaving the tree restores); `SlowMo.wants(tier, cursed)` = tier >= 7, uncursed.
- `main.gd`: `frog_kiss(player, scene)` (await, ~1.3 s; the pick runs it after a Kiss the Frog reveal),
  `visitor` (the waving saucer at an orbit moment, or null).
- `scenes/ui/end_card.tscn`: `open()`, `close()`, `signal restart_requested()` (A, after 1.2 s).
  `open()` builds `shelves` (player -> GridContainer, a tile per `Run.upgrades_of(player)`, meta
  `upgrade_id`) and `collection` (GridContainer, a badge per `Run.pool` card, meta `seen` from `Save`
  `upgrades_seen`, which `Run` fills on every draw and every revealed curse).
  Two icon buttons: A on the big one (focused) goes back to the lobby (`Game.to_lobby()`), the door
  (stick right, A) to the launcher (`Game.quit()`); `--demo` skips the lobby and restarts straight away.
- Lobby (`UI/Lobby`, template Showtime kit): skinned by `data/menu_skin.tres` (title, colours,
  backdrop `SCREEN` = the live field behind it, blurred). Both podiums host
  `scenes/ui/lobby_jarling.tscn` (`lobby_jarling.gd`: the field rig, idle/cheer, `set_character(id)`
  with the Roster pick, `dress(items)` with the run's `--gear`, kept across a swap). Names come from
  the Roster (`p1_name` / `p2_name` empty). `main.gd` sets the round card line ("<NAME> KICKS FIRST",
  the picked character's name, in the player's colour). `Game.lobby_ready` -> `Run.plan_run(players)`, round 1.
  A pad joined but not readied when the countdown ends sits out round 1 and plays from round 2.
- `scenes/ui/upgrade_card.tscn`: one card (`Icon`), themed by Art.

### Debug / CLI (after `--`)

`--screenshot-after=<s>` (template), `--solo` (one pad plays both, see Solo mode), `--demo` (two virtual players, auto-picks, auto-restarts: the game
plays itself), `--timescale=<x>` (0.1 to 8), `--log-phases` (prints phases, heights, picks).
`--gear=<id,id>` / `--gear2=<id>`: P1 / P2 start every run wearing those upgrades (`Run.give`), for
playtests and screenshots. `--p1-char=<id>` / `--p2-char=<id>`: who plays (Roster, as the launcher
passes it). Dev only: `--roster=<res path>` reads another roster file before the kickers spawn
(`tests/fixtures/roster_standin.json`: Jeff, Chuck and a generic stand-in; `tests/` never ships).
