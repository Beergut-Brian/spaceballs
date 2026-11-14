# press-answers-adopt-1 report (Spaceballs)

Branch `feature/press-answers-adopt-1` off `origin/dev` at `96f99ca` (`git merge origin/dev`: already up to date).
Not pushed (Gary ships). Kaden's rule 5: every press answers; a menu press that does nothing says so.

## What changed

**Template kit adopted** (template `feature/template-press-answers-1` at `9d99f29`, cherry-picked from the
`template` remote and merged by hand):

- `scenes/ui/kit/menu_input.gd`: `read()` now also reports `other` (the player) and `button` ("x", "lt",
  "select", ...) for buttons the menus don't use. Adds `MenuInput.refuse(item, button)` (the `honk` + a wobble
  on `item`) and `owned_elsewhere()` (Start while paused is Game's resume). **Kept the game's own d-pad path**:
  Spaceballs puts the d-pad in the input map at boot (`Players.add_dpad()`, FR-01), so the template's d-pad
  reader was left out. A second `read()` in the same frame gets the same `other` answer.
- `menu_item.gd` (`wobble()`, a 16 px side-to-side shake), `icon_button.gd` (`wobble()`, a rock),
  `ui_sound.gd` (`honk` cue; this game has `assets/audio/sfx/honk.ogg`, so the real file plays, never the synth),
  `lobby.gd`, `pause_menu.gd` (left / right step the list, refusing at the ends), `settings_panel.gd`,
  `confirm_dialog.gd`: taken as the template has them. The game's own edits in these files are unchanged
  (the in-run leave body text, the door glyph size, the pitch-through-Audio line, the lobby preview binding).
- `ui_preview.gd` + `scripts/tools/shots.sh`: `--ui=lobby-refuse`, `--ui=pause-door`, `--ui=pause-refuse`.
- `docs/ui.md` ("Every press answers"), `docs/press-answers.md` (the template's table, plus a "Spaceballs
  screens" section).

**This game's own screens** (customised in their own scripts, no `.tscn` edits):

- `scenes/ui/upgrade_pick.gd` + `upgrade_card.gd`: refusals on the pick; the card gets `wobble()` (a rock, skipped
  while the curse flip owns the card).
- `scenes/ui/end_card.gd`: unused buttons refuse; the existing B / Start / early-A refusal now uses the menus'
  `honk` (was `nope`) plus a wobble, keeping the pink flash. The big button is round, so it **shakes sideways**
  (a rock didn't show in the first frame); the door rocks.
- `tests/test_feel_rules.gd::test_end_card_b_and_start_refuse`: now expects `MenuInput.REFUSE_CUE` instead of
  `nope` (the end card is a menu now). The in-play `nope` (B in the air) is gameplay and unchanged.

Not touched: gameplay code, art, audio files, the save format, `project.godot`, any `.tscn`, the template repo.

## Screen by screen

| Screen | Silent before | Now | Kept their job |
| --- | --- | --- | --- |
| Lobby (start menu) | X, Y, LB/RB, LT/RT, L3/R3, Start, Select (not solo), B on Play when not ready, left/right on a ready podium | honk + focused bar shakes | join press, solo Select, Select + Start hold, A, B un-ready |
| Pause | X, Y, shoulders, triggers, stick clicks, Select, left/right | unused: honk + wobble; left/right step the list, refuse past the ends | Start resumes, B resumes, A |
| Settings | X, Y, shoulders, triggers, stick clicks, Select, Start in the lobby | honk + the row shakes, no value changes | Start in pause resumes |
| Leave the game? | same set | honk + the focused button shakes | Start in pause resumes |
| Upgrade pick (game) | X, Y, shoulders, triggers, stick clicks, Start, B (not solo P2's turn), A after picking | honk + the presser's card rocks | Select = Game's restart arm, solo B, A picks, left/right |
| End card (game) | X, Y, shoulders, triggers, stick clicks (B, Start, early A already said `nope`) | all: honk + the big button shakes / the door rocks + pink flash | Select = Game's restart arm, A, left/right/hold ring |

Left quiet on purpose (in `docs/press-answers.md`): up / down on the pick (the stick drifts up / down while
choosing, it would honk); presses from a player who is in space during a pick (no cards in their half).

## Tests

- New: `tests/test_press_answers.gd` (template suite, 10 tests: lobby x5, pause x3, settings, leave question),
  adapted to this game's `SettingsSandbox` (`user://test_press_answers_settings.json`, asserted).
  `tests/test_press_answers_game.gd` (5 tests: pick x3, end card x2; `user://test_press_answers_game_settings.json`,
  asserted). Every screen has a silent-press test that checks the refusal fired and nothing else changed.
- Checked the new suite bites: with the pick's refusal stubbed out, `test_pick_unused_buttons_refuse_and_change_nothing` fails (7 failures); restored.
- Full suite on a clean import (`rm -rf .godot`, `--import`, then
  `godot --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a tests`):
  **361 / 361 passed, 53 suites, 0 orphans, exit 0** (346 before + 15 new). Log: `handoff/test-output.log`.

## Frames (godot-render, 1920x1080; looked at each)

- `handoff/frames/press_01_lobby_x_refused_play_wobbles.png`: `--ui=lobby-refuse`, X refused, PLAY held mid-shake.
- `handoff/frames/press_03_lobby_play_still_vs_refused_crop.png`: PLAY bar still (top) vs refused (bottom):
  15 px shift at the held pose (a still frame can't show the motion otherwise).
- `handoff/frames/press_02_pause_right_on_door_refused.png`: `--ui=pause-refuse`, right on the door refused, door mid-rock.
- `handoff/frames/press_04_pick_x_refused_p1_card_rocks.png`: the pick on its own (no 3D views behind), P1's card rocked.
- `handoff/frames/press_05_endcard_y_refused_button_shakes.png`: the end card on its own, the big button shifted
  ~22 px mid-shake (subtle in a still; the motion is three quick shakes over 0.32 s).
  Pick / end card driver: `.scratch/press_drive.gd` + `.tscn` (git-excluded).

## PLAN-STATUS

Added and moved to built in the same commit (`42e613c`): **FR-05.1, FR-05.2, FR-05.3, FR-05.4, FR-05.5, FR-05.6**.
New source S13. FR-05 stays built. Totals, recounted: 140 built, 0 partial, 0 missing, 4 superseded,
1 dropped, 3 later, 1 n/a (149 rows).

## For Gary

- The clean `--import` leaves ~45 untracked `assets/characters/*/*_face.png` / `*_pattern.png` and two
  `assets/landmarks/dragon/*.png` (textures pulled from the vendored models). Not committed, not deleted.
- `tests/test_gap_close_7.gd.uid`, `_8`, `_9` are untracked on dev (Godot writes them on import); I left them out
  of this lane's commit.
- Kid-design check: every refusal is a sound and a visual, no text, nothing changes state; the honk is the
  game's own soft "can't do that" sound.
