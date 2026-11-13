# Every press answers: menu kit (template) and Spaceballs' own screens

Spaceballs adopted the template's fix (template `feature/template-press-answers-1`, `9d99f29`) on
`feature/press-answers-adopt-1`. The sections down to "After" are the template's audit, kept as written;
"Spaceballs screens" at the end is this game's own (the upgrade pick and the end card).
Differences from the template here: the d-pad reaches the menus through the input map
(`Players.add_dpad()`, FR-01), so `MenuInput` has no d-pad reader of its own; the honk is this game's
`assets/audio/sfx/honk.ogg` (UiSound finds it, the synth stand-in never plays).

Kaden's standing rule 5: every press answers; a press that does nothing says so. The Hill's FR-5 audit
(`the-hill` `fix/hill-rules-audit-1`, REPORT.md "Template gaps" 2) found the template kit menus silent on
X, Y, the shoulders and left / right on the pause list. This is the full list, read from the code on
`origin/dev` `f737145` (`scenes/ui/kit/menu_input.gd`, `lobby.gd`, `pause_menu.gd`, `settings_panel.gd`,
`confirm_dialog.gd`, `scripts/autoload/Game.gd`, `Players.gd`).

`MenuInput.read()` reads only up / down / left / right (stick, keys, d-pad), A (`action`) and B (`jump`).
Nothing in the menus reads X, Y, LB, RB, LT, RT or the stick clicks. Start is `pause` (Game), Select is
`restart` (Game, only in PLAYING / ROUND_END); Select + Start held 2 s is the solo toggle (Players).
An unjoined pad's first press of any button joins it (Players, `player_join`): that answers everywhere.

**SILENT** = no sound and no visual.

| Input | Lobby (main) | Pause list | Settings (lobby or pause) | Leave the game? (lobby or pause) |
| --- | --- | --- | --- | --- |
| A | ready (sting, stamp); on Play when already ready: squash + hold-to-start fill (no sound, but not a no-op: the hold); Settings: open; Door: ask | press focused (Resume / Restart / Settings / Door asks) | step / toggle the row | Stay or Leave |
| B | un-ready (two notes); off Play: focus back to Play (`ui_back`); **not ready, on Play: SILENT** | resume (`ui_back`) | close (`ui_back`) | Stay (`ui_back`) |
| X | **SILENT** | **SILENT** | **SILENT** | **SILENT** |
| Y | **SILENT** | **SILENT** | **SILENT** | **SILENT** |
| LB / RB | **SILENT** | **SILENT** | **SILENT** | **SILENT** |
| LT / RT | **SILENT** | **SILENT** | **SILENT** | **SILENT** |
| L3 / R3 (stick clicks) | **SILENT** | **SILENT** | **SILENT** | **SILENT** |
| Up / down | move (`ui_move`; bumping an end sounds too) | move (same) | row (same) | move (same) |
| Left / right | chooser: swap (`char_swap`, poof); nobody free: head-shake + low tak; **ready, counting down, or the other podium in solo: SILENT** | **SILENT** | step the meter / ON-OFF (ticks at the ends too) | move (same as up / down) |
| Start | **SILENT** (Game ignores `pause` in LOBBY) | resume (Game) | in pause: resume (Game); **in the lobby: SILENT** | in pause: resume (Game); **in the lobby: SILENT** |
| Select | solo: switch podium (tick, name pop); **not solo: SILENT** | **SILENT** (restart is PLAYING only) | **SILENT** | **SILENT** |
| Select + Start held | solo toggle (Players) | same | same | same |

Silent presses to fix: X, Y, LB, RB, LT, RT, L3, R3 on every screen; Select everywhere except the solo
lobby; Start on the lobby and its submenus; B not ready on Play; left / right on a locked podium;
left / right on the pause list (cycle where there is a row, else refuse).

Left as they are (they already do something): every A; B where it backs out, un-readies or resumes;
up / down everywhere; left / right in Settings, the question and on an unlocked podium; Start in pause;
Select in solo; the Select + Start hold; a join press.

## After (feature/template-press-answers-1)

Every SILENT cell above now refuses: `MenuInput.refuse()` plays `honk` (a game's `assets/audio/sfx/honk.ogg`
through `Audio` when it has one, else `UiSound`'s synth stand-in) and wobbles the focused bar or icon.
Nothing else changes on a refusal: no focus move, no state, no setting, no pick.

| Input | Lobby (main) | Pause list | Settings | Leave the game? |
| --- | --- | --- | --- | --- |
| X, Y, LB, RB, LT, RT, L3, R3 | refuse | refuse | refuse | refuse |
| Start | refuse | resume (Game, unchanged) | in pause: resume; in the lobby: refuse | in pause: resume; in the lobby: refuse |
| Select | solo: switch (unchanged); else refuse | refuse | refuse | refuse |
| B | un-ready / back to Play (unchanged); not ready on Play: refuse | resume (unchanged) | close (unchanged) | Stay (unchanged) |
| Left / right | chooser (unchanged); locked podium: refuse | step the list (right = down); no row that way: refuse | unchanged | unchanged |

Details:
- A trigger counts once per pull (past 0.6, re-armed under 0.3).
- A press that joins a pad (B or X from a new pad) is the join, never also a refusal.
- A button already held when a menu opens (a trigger held through Start) is not a press: after a gap in
  reading, `MenuInput` only takes stock.
- Select pressed with Start held (or Start with Select held) is the solo hold, never refused. Start pressed
  first and then Select still honks once for the Start (Start alone does nothing in the lobby).
- Once the lobby's wipe has started (`_launched`) refusals are skipped: the screen is covered.
- Keyboard: only the mapped keys are read (no X / Y keys exist); the TV is pads.

## Spaceballs screens (feature/press-answers-adopt-1)

The kit screens above (lobby, pause, settings, the leave question) behave exactly as the template's
table. This game's own two screens, between rounds (`Game.State.ROUND_END`, so Start has no pause and
Select is Game's restart: arm, then restart):

| Input | Upgrade pick (`scenes/ui/upgrade_pick.gd`) | End card (`scenes/ui/end_card.gd`) |
| --- | --- | --- |
| X, Y, LB, RB, LT, RT, L3, R3 | refuse: honk, the presser's highlighted card rocks | refuse: honk, the focused button shakes (big button) or rocks (door), pink flash |
| Start | refuse (was silent) | refuse (was `nope` + flash; now the honk too, one refusal) |
| Select | Game's restart arm (unchanged) | Game's restart arm (unchanged) |
| B | solo, P2's turn: back to P1 (unchanged); otherwise refuse (was silent) | refuse (was `nope` + flash) |
| A | pick (unchanged); already picked: refuse (was silent) | press the focused button (unchanged); before the buttons show: refuse (was `nope`) |
| Left / right | step the cards; bump the end: flash + low tick (unchanged) | focus big button / door (unchanged) |
| Up / down | unchanged (silent; the stick's up / down drift while choosing would honk, so not refused) | focus / hold ring (unchanged) |

Left as they are: a player whose half shows no cards (already in space) has nothing to wobble, so their
presses stay quiet on the pick; in play, X / Y stay unbound (FR-05, a gameplay decision). The in-play
`nope` (B in the air) is gameplay and unchanged.
