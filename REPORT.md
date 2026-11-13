# sb-pause-door-1: the template's door icon in the Spaceballs pause (2026-11-13)

Lane: pause-door adoption. Branch `feature/sb-pause-door-1` off `origin/dev` at `773604c`
(merge of origin/dev: already up to date). Not pushed: Gary pushes.

## Read this first: the template change is not on the template's `origin/dev`
The brief says the template door is merged on `openjar-template` `dev` with door art under
`art/ui/`. In `~/openjar/openjar-template` (read only, not modified):
- `origin/dev` (and local `dev`) is at `e57d4ec`; its `pause_menu.tscn` still has the text bar,
  identical to this game's. `git fetch` failed (no GitHub credentials on the box), so the remote
  may have moved since; I could not check.
- The door lives on the unmerged local branch `feature/template-pause-door-1` at `69ab14a`
  (worktree `~/openjar/work/openjar-template--feature_template-pause-door-1`). Its own
  PLAN-STATUS says "adoption lane queued after this merge".
- There is **no door art file** and no `art/ui/` in any template ref: the door is drawn in code
  (`icon_button.gd`, `Icon.DOOR`). So there was nothing to copy into `assets/` and no CREDITS line.

I adopted from that branch (`69ab14a`), not from an invented scene. If the template branch changes
before it merges, re-sync these two files from it.

## What changed
- `scenes/ui/pause_menu.tscn`, `pause_menu.gd`: the template patch applied as is (3-way, clean).
  The text bar `Card/Buttons/Door` is gone; `Card/Door/Icon` is a 128 px `IconButton` (DOOR,
  `focus_scale` 140/128) with `Card/Door/Label` "Back to Open Jar" (uppercase) beneath it.
  The door is the last stop of the cursor. Accent: `apply_skin()` tints the icon `UiStyle.accent`
  (code, not a `.tscn` override); the label is styled in `_style_door_label()` (cream, bigger
  when focused). Title "PAUSED" and the pauser's colour are unchanged. Kept: Resume, Restart
  (lobby), Settings, B resumes / backs out, A on the door opens the confirm with this game's
  `ConfirmDialog.BODY_IN_RUN` wording, then `Game.quit()` (saves, exits 0; no force-close).
- `scenes/ui/icon_button.gd`: the template's additive bits only (`class_name IconButton`,
  `disabled`, `focus_scale`, `slam_in()`), so the icon can sit in the `MenuItem` focus list.
  I left out the template's bigger door glyph: the end card shares this script and its door is
  outside this lane. The end card's look is unchanged (default `focus_scale` 1.15 as before).
- Not taken: the template's `MenuInput.dpad()`. This game already gets the d-pad into the move
  actions (`Players.add_dpad()`, FR-01), and `test_dpad_reaches_the_door` proves the pause reads it.
- Solo icon: this game's pause has none (solo is in Settings and the pauser tag follows
  `Players.solo_focus`); that is unchanged.
- `docs/ui.md` pause bullet updated. `project.godot` untouched.

## Tests
`tests/test_pause_door.gd` (sandboxed settings + picks via `SettingsSandbox`, real pad events on
pads 5/6): `test_door_icon_is_in_the_pause_scene`, `test_door_icon_takes_the_focus`,
`test_dpad_reaches_the_door`, `test_a_on_the_door_asks_first_then_quits_saved`, `test_b_resumes`.

Clean import, then the full suite:
`Overall Summary: 346 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans |`
(the usual exit-time leak lines follow; see the audio exit-leak note, not new).

## Frame
`handoff/frames/pause_door_focused.png` (godot-render, driver `.scratch/pause_door_drive.tscn`:
boots main, two pads join, round starts, pause, cursor to the door, 2 s settle). What I saw:
the blue wedge with PAUSED / "PLAYER 1 PAUSED" in green, the three bars, then the door below them:
a yellow (accent) disc with a cream focus ring and a brown door with an ink frame and knob, all of
it inside the frame, not clipped. "BACK TO OPEN JAR" sits centred under it in large cream
letters and reads cleanly. Hint strip bottom right: Move / Select / Resume. The door glyph is fairly
small inside its disc (this game's glyph size, see above); the template's bigger glyph would fill it
more if Gary wants it on the end card too.

## PLAN-STATUS
FR-03 partial -> built (proof: `tests/test_pause_door.gd`, `handoff/frames/pause_door_focused.png`).
Totals recounted: **134 built, 0 partial, 0 missing, 4 superseded, 1 dropped, 3 later, 1 n/a (143 rows)**.

## Leftovers
- A fresh `--import` left untracked `assets/characters/*/*_face.png` / `*_pattern.png` (vendored
  folder); not committed, not deleted.
