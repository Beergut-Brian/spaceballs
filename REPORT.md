# sb-rules-audit-1: standing feel rules on Spaceballs (2026-11-13)

Lane: feel-rules audit. Branch `fix/sb-rules-audit-1` off `origin/dev` at `d3d3ef2` (merge of origin/dev: already up to date).
Not pushed: Gary pushes.

## Rules table

| # | Rule | Before (dev `d3d3ef2`) | Now | Where |
| --- | --- | --- | --- | --- |
| 1 | D-pad everywhere | **FAIL.** `project.godot` binds `p1_/p2_move_*` to the left stick and keys only. Gameplay reads `Players.move_vector()` (`kicker.gd::_stick_world`), the pause / settings / confirm read `MenuInput.read()`, the end card and the upgrade pick read the `move_*` actions, so the d-pad moved nothing in play, the pause, the end card or the pick. Only the lobby chooser read the d-pad itself (`lobby.gd::_left_right`) | **PASS.** `Players.add_dpad()` runs at boot and adds `JOY_BUTTON_DPAD_*` to each player's `move_*` on the same device as the stick, so `_rebind`, `reset` and solo carry it like the stick. The lobby's own d-pad read still works and does not double-step (it assigns the same `dir`) | `scripts/autoload/Players.gd` (`DPAD`, `add_dpad`), `tests/test_dpad_moves.gd` (7 tests; red with `add_dpad()` taken out of `_ready`: 8 assertion failures), frames `dpad_01..03`, `pause_02_dpad_down_x3_on_door`, `endcard_03_dpad_right_door_focused` |
| 2 | Start fresh | N/A | N/A | `Save.gd` keeps `user://saves/<profile>.json` with `best_height`, `runs_completed`, `upgrades_seen`: records, not progress. No run is ever saved (every run starts wimpy, GAME.md), so there is nothing to Continue. See "Needs a gameplay decision" |
| 3 | Pause and back out | **PARTIAL.** The pause has "Back to Open Jar" (asks first), a big bar (96 px, 140 px focused) but **text, no icon**. Quit path is clean: `Game._ready` turns `auto_accept_quit` off, a window close calls `Game.quit()`, which flushes the save, waits 0.2 s real time on a pause-proof timer (`Audio.silence`) and exits 0 | unchanged (partial) | `scenes/ui/pause_menu.tscn` (identical to the template's), frame `pause_01_open_door_is_text_bar`; `scripts/autoload/Game.gd:31-37, 115-121`. Template gap below |
| 4 | Solo mode | PASS | PASS (now tested) | `--solo` (`Players.solo_from_args`), Select + Start 2 s real time (`Players.hold_step`), small icon top-left (`solo_marker.gd`, frame `solo_01_marker_on`). Off by default. The kit writes `solo_playtest` to settings but nothing reads it at boot: `tests/test_feel_rules.gd::test_a_remembered_solo_setting_does_not_turn_solo_on_at_boot` (sandboxed settings file) |
| 5 | Every action beeps | **PARTIAL.** Silent presses: B while in the air, B during the wind-up or a gag (`kicker.gd::_buttons` played nothing when `_hop` refused), and B, Start, or an A before the buttons show (first 1.2 s) on the end card | **PASS.** Those presses play `nope` and show a reaction (a small squash of the kicker; a pink flash of the end card's big button). Everything else already beeped: A shout / cheer, B hop, Select arm / restart, Start pause, pick moves (edge bump too), lobby, pause, settings, confirm, end card | `kicker.gd::refuse` + signal `refused`, `end_card.gd::refused_press / refuse`, `Audio.gd` alias `nope` -> `card_move` at 0.5 pitch; `tests/test_feel_rules.gd` (5 tests); frame `endcard_02_b_refused_flash` |
| 6 | No forced movement | PASS | PASS | `kicker.gd::_approach`: velocity eases toward the stick only; `test_kicker.gd::test_no_input_stays_put`. The demo bot steers only under `--demo`. Two scripted moves listed under decisions |
| 7 | Show the buttons | PASS | PASS | Pause hint line with glyphs (Move / A Select / B Resume), A badge under the focused button on the pick card, end card and lobby (PF-3, PF-4). In play only the stick matters (kick on contact; A / B are toys), so there is no in-play hint |
| 8 | Every cause shown | PASS | PASS | Curses: U-15..U-19 (reveal, badge, beat, "that's why"). Since then: the toe-poke (no run-up) has its own startled animation (`kicker.gd::_toe_poke`); landmarks (PT1112-1) and the Dragon cameo (V-22) change nothing in play |

## Tests

Clean import (`rm -rf .godot && godot --headless --import --path .`), then the full suite:

`Overall Summary: 341 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans |` (50/50 suites; dev had 327 before this lane, +7 d-pad, +7 feel rules).

New: `tests/test_dpad_moves.gd` (7), `tests/test_feel_rules.gd` (7). Both use `SettingsSandbox` with their own settings and picks files.

## Frames

`handoff/frames/` (git-excluded; godot-render, 960x540, two synthetic pads on devices 0 / 1; driver `.scratch/fr_drive.gd` + `.tscn`, run with `-- --sandbox`):
- `dpad_01_p1_before_dpad_right.png`, `dpad_02_p1_after_1s_dpad_right.png`, `dpad_03_p1_after_1s_dpad_up.png`: P1 walks on the d-pad alone (log: (-2, 30) -> (1.3, 24.9) -> (-1.6, 23.2)).
- `pause_01_open_door_is_text_bar.png`, `pause_02_dpad_down_x3_on_door.png`: P2's Start pauses, three d-pad downs reach "Back to Open Jar".
- `endcard_01_open.png`, `endcard_02_b_refused_flash.png`, `endcard_03_dpad_right_door_focused.png`.
- `solo_01_marker_on.png`: the solo icon top-left.

## Template gaps (openjar-template, not changed here)

- `project.godot`: `move_*` has no d-pad. Every game needs its own `add_dpad()` (The Hill, Worm, now Spaceballs). Belongs in the template's `Players.gd` or input map.
- `scenes/ui/pause_menu.tscn` + `scenes/ui/kit/menu_item.gd`: the pause's way back to the launcher is a text bar with no icon. The template has `scenes/ui/icon_button.gd` with a DOOR icon (the end card uses it); the pause bar could draw it.
- The template has no refusal cue (`ui_nope` or similar) in `UiSound.CUES`; games alias one.

## Needs a gameplay decision (not decided here)

1. **X and Y are unbound** and do nothing, silently. kid-design says extra buttons are "ignored or harmless and funny"; the new rule says a press that does nothing says so. Beep a refusal on X / Y, or leave them ignored?
2. **Start fresh / records.** No run is saved, so Continue / New does not apply. Should Settings offer "clear my records" (best-ever flag, card collection) with a hold-A confirm and a kept backup, or stay as is?
3. **The field edge's soft wall** (`kicker.gd::_soft_wall`) eases the kicker back inside when he stands in the edge band with no input. It is a cushion, not a pull to a target, but it is movement without input.
4. **`nope` sound**: an alias of `card_move` at half pitch. The Audio lane may want a real file (a soft "bonk").
5. The banana-peel slide (a curse, S4) moves him without input on purpose; listed only so it is a known exception.

## Notes for Gary

- A fresh `--import` leaves ~45 untracked `assets/characters/*/*_face.png` / `*_pattern.png` and `tests/test_gap_close_7..9.gd.uid`; not committed (vendored / not this lane's).
- PLAN-STATUS: source S12, section FR (FR-01..FR-08), totals recounted from the rows: 133 built, 1 partial, 0 missing, 4 superseded, 1 dropped, 3 later, 1 n/a (143 rows).
- The full-suite log prints `ERROR: Error calling deferred method: 'GDScript::run': Cannot convert argument 1 from Object to Object.` twice, during `test_chooser.gd::test_pick_persists_across_a_relaunch` and `test_build_info.gd::test_the_lobby_footer_shows_it` (suites this lane did not touch). gdUnit counts 0 errors; not chased here.
