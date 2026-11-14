# launch-ready-3 report (Spaceballs)

Branch `feature/sb-launch-ready-3` off `origin/dev` at `6ed52cf` (merge of #54). Not pushed (Gary ships).
Goal: launch-ready apart from the TV-hardware checks, re-checked against the dev head after the
2026-11-13 merges (#52 rules audit, #53 pause door, #54 press answers).

## What changed

- `docs/launch-checklist.md` rewritten against `6ed52cf`. It has each standing rule with yes / no / n/a and
  its proof, every TV-box check written as the exact thing to do, the build load steps, and the
  dev head it was checked against.
- `scenes/ui/lobby.gd`: the `--ui=` preview hook is now deferred through a lobby method
  (`_preview`). Before, a static `UiPreview.run.call_deferred(self)` fired after a test had freed the
  lobby and printed `ERROR: Error calling deferred method: 'GDScript::run'` twice per full run
  (test_chooser, test_build_info). Behaviour for players: none.
- `tests/test_lobby.gd`, `tests/test_picks_isolation.gd` use the roster fixture
  (`tests/fixtures/roster_three.json`) instead of the vendored `data/roster.json` (brief step 7).
  Every roster or chooser suite now does, except two that check the real roster on purpose:
  `test_roster.gd::test_real_roster_is_jeff_and_chuck` and `test_character_spawn.gd::test_defaults_are_jeff_and_chuck`
  (the CLAUDE.md default rule), plus `test_launch_ready*.gd` (the shipped voices).
- `PLAN-STATUS.md`: a launch-ready-3 audit paragraph; Next up notes the re-check.

## Rows

- **Moved: none.** On dev, no row is partial or missing (140 built, 0 partial, 0 missing,
  4 superseded, 1 dropped, 3 later, 1 n/a; 149 rows, recounted by script).
- **Skipped, and why:**
  - S-05 ragdoll (later): needs Kaden's pick.
  - PF-7 pause Restart goes to the lobby (later): needs Kaden's pick.
  - S-15 v1.0.0 on the TV main tile (later): needs the TV box.
  - V-22 `dragon_purr` placeholder: waits on the library's Dragon voice.
  - FR-02 Continue / New (n/a): no run is saved.
  - Art rows, per the brief (Art Director process): V-01, V-02, V-03, V-04, V-15, V-16, V-17, V-18, V-20,
    V-21, V-24, U-13. Store art, logo, palette and `store/jar.glb` were not re-checked either.

## Placeholder text, debug prints, dev switches

- Title, lobby, pause and leave text read as finished in frames (`main_01`, `main_06`, `quit_02`).
  The `.tscn` defaults "v0.0.1" and "Open Jar Game" are replaced at runtime (version tag, title).
- No dev switch can be reached from a pad. `--demo`, `--solo`, `--gear=`, `--dragon`, `--ui=`,
  `--roster=` and `--timescale=` are command-line only. F3 and F12 are keyboard-only template debug keys.
- The one stdout print in play, `Chooser voice: ...`, was left in: `docs/ui.md` documents it as the log
  for the chooser voice, and a player never sees it.

## Session flow frames (godot-render, editor build, software GPU)

Driver: `handoff/drivers/flow3.gd` (`--mode=main|quit|solo`). Logs: `handoff/flow_*.log`.
Every frame is in `handoff/frames/` (contact sheets `sheet_*.png`), and I looked at each one.

| Frame | What it shows |
| --- | --- |
| main_01_boot_lobby_nobody | Main menu: SPACEBALLS title, Play / Settings / Back to Open Jar, both podiums "A JOIN", "WHO'S PLAYING? Press A on a controller to join", footer "dev" |
| main_02_p1_joined_ready | P1 joined (the join press readies): Jeff on a green podium |
| main_03_p1_holding_a_alone | P1 holds A alone: "STARTING SOLO" stamp, "PLAYER 1 READY / Hold A on Play to start solo", 1P chip |
| main_04_p1_alone_countdown | The hold finished: countdown "3", "Starting in 3, B Cancel" |
| main_05_solo_player_kick | 1-player round: Jeff and the green ring, the height ladder on the right, round dot |
| main_06_pause_open | PAUSED, "PLAYER 1 PAUSED", Resume / Restart / Settings, the big door icon with "BACK TO OPEN JAR" beneath it |
| main_07_pause_door_focused | After three downs the door is focused (bigger and brighter); hints Move / Select / Resume |
| main_08_pause_door_asks | "LEAVE THE GAME? This run ends. Best kick and cards are kept." Stay focused first |
| main_09_p2_drop_in | P2 joins mid-run (pad assigned): a second round dot. P2 plays from the next round (in_run false) |
| main_10_p2_kicks | Next round: Chuck on the red ring kicks |
| main_11_p2_drop_out | P2's pad unplugged during his kick: play goes on with Jeff's kick |
| main_12_end_card | Space end card: both on the planet, the A button and the door |
| main_13_lobby_again | Back in the lobby, P1 still joined, P2 "A JOIN" |
| main_14_both_joined_not_ready | Both joined and un-readied: "PRESS A ON PLAY", 2P chip |
| main_15_p1_ready_waiting_p2 | P1 ready: "WAITING FOR PLAYER 2, or hold A to start solo" |
| main_16_both_ready_countdown | Both pressed A: "BOTH PLAYERS READY 3" |
| main_17_two_player_kick | 2-player round: Jeff kicks, P2's red marker at the edge |
| main_18_select_start_solo_on | Select + Start held 2.01 s: the solo icon top left, both ready and the countdown "2" (see Needs Kaden) |
| quit_01_lobby_door_focused | Lobby, Back to Open Jar focused |
| quit_02_lobby_door_asks | "LEAVE THE GAME? Progress is saved. You'll go back to Open Jar." Stay focused |
| quit_03_lobby_leave_focused | Leave focused, then A: **the process exits by itself, exit 0, no leak lines** |
| solo_01_boot_solo_flag | Booted with `--solo`: the solo icon top left and "ROUND 1 / JEFF KICKS FIRST". The run started about 2 s after boot with no press |
| solo_02..04 | Solo round 1: Jeff kicks, the icon stays |
| solo_05_solo_pause_door_asks | Pause door asks under solo; Leave: **exit 0, no leak lines** |

Driver notes: Select + Start is fed into `Players.hold_step` each frame, because synthetic pads don't count as
"connected" so `Players._process` doesn't poll them. This is the same rule `tests/test_lobby.gd::test_select_start_hold_toggles_solo` checks.
The first main run's lobby-door step was lost: solo had launched a round. It was re-shot as `--mode=quit`.

## Soak

`handoff/soak/soak30.log` (launch-ready-2's driver, real lobby, end card and pause; bots kick and pick):
`--soak-secs=1830`, headless, 6 sessions, 61 rounds, 5 runs ended through the end card.
**Script errors: 0.** Orphans 0 at every sample. Objects at round 1 per session: 4521, 4886, 5164, 5225,
5276, 5276 (flat; the same warm-up as earlier soaks). The run ended through the pause door → Leave
with exit 0. Two godot-render runs shared the box for part of it, so the process-time numbers are inflated;
the error count is not affected.

## Tests

On dev before any change: 361/361 passed (`--ignoreHeadlessMode --continue`), 0 orphans.
After this lane's changes, a clean import (`.godot/` removed, `--import`), then the full suite:
**361 test cases, 0 errors, 0 failures, 0 flaky, 0 orphans, exit 0** in 55 suites (`handoff/test-output.txt`).
The two `GDScript::run` deferred-call ERROR lines from the baseline run are gone.

Physics-outcome tests: Spaceballs has no piles. The kick and flight suites pin 60 Hz, the seed and Run
through `tests/physics_pin.gd` (18 suites). The sky-hit test seeds the field and counts objects on the
ball's path, so geometry decides the result.

## Needs Kaden

- **Screen shake setting:** it is saved and comes back at boot, but the rule says saved toggles never
  restore. Reset it every boot, or keep it as a comfort setting?
- **Solo starts by itself:** turning solo on readies both podiums, and the countdown starts with no press
  (contract: "solo mode readies both"). A `--solo` boot is in round 1 about 2 s later, so the chooser is skipped.
  Keep this, or wait for A on Play?
- PF-7 (Restart → lobby: rename or restart in place), S-05 (ragdoll still wanted?), FR-02 (offer
  "clear my records"?): unchanged.

## For Gary

- The newest release tag, `v0.1.5`, is on `d3d3ef2`. It predates the d-pad, the pause door and the refused-press
  honks. Tag the dev head after this merge (`v0.1.6`) so the TV tile gets them for the weekend.
- After the clean `--import`, the vendored characters' extracted textures appear as untracked files under
  `assets/characters/*/`. They were not committed.
