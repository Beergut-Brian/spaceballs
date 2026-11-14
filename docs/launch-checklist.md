# Launch checklist: Spaceballs

Kaden (2026-11-10): "I would like to have Spaceballs, Junk Yard Zap, and the Launcher done besides
running it on the TV hardware."

**Checked against dev at `6ed52cf`** (merge of #54 press-answers-adopt-1, 2026-11-13) by the
launch-ready-3 lane on 2026-11-14 (`feature/sb-launch-ready-3`). This replaces launch-ready-2's
checklist (dev at `930a8d4`), which came before the rules audit (#52: d-pad, refused presses), the
pause door (#53) and press answers (#54).
Frames and logs: this lane's `handoff/` (git-excluded; Gary attaches it). Frame names below are
`handoff/frames/<name>.png`.

## Before the weekend: the TV needs a new build

The newest release tag is **`v0.1.5` on `d3d3ef2`** (gap-close-9). It does **not** have the d-pad in
play, the pause door icon, or the refused-press honks. After this branch merges, Gary or Hermes
tags the dev head (`v0.1.6`) so `release.yml` builds the zip the TV tile installs.

### Load steps (TV box)

1. On GitHub Releases, check that `spaceballs-v0.1.6-linux.zip` is attached (release.yml: tests,
   export, smoke boot, manifest, zip). The lobby footer shows `v0.1.6`, not `dev`.
2. In the launcher, the Spaceballs tile installs or updates to that release. To do it by hand, unzip into
   the launcher's games folder and keep `openjar.json`, `game.x86_64` and `store/` together.
3. Launch from the tile. No flags: `--solo`, `--demo`, `--gear=`, `--dragon`, `--ui=` are dev
   switches that only the command line can set.

## Standing rules

| Rule | Yes / no | Proof |
| --- | --- | --- |
| No stick-only requirement (menus may need a button) | yes | d-pad moves the kicker, pause, end card, every menu: `tests/test_dpad_moves.gd` (4 tests, FR-01); pause door reached with 3 downs: frame `main_07_pause_door_focused` |
| No auto-steering the player | yes | `tests/test_kicker.gd::test_no_input_stays_put`, `tests/test_free_roam.gd::test_no_auto_steer_with_no_input` (FR-06, K-01) |
| Gear is worn | yes | every wearable card has a gear scene on a body slot: `tests/test_gear.gd`; on whoever was picked: `tests/test_character_spawn.gd::test_gear_equips_on_the_picked_body` (C-11) |
| Progress is earned behind visible barriers | yes | power only comes from cards picked after each kick (`tests/test_run.gd::test_power_is_base_times_product_times_quality`); the eight height tiers each have a picture on the HUD ladder (`tests/test_plan_gaps.gd::test_every_tier_has_a_picture`, V-07) and a landmark band (PT1112-1); frame `main_05_solo_player_kick` (the ladder on the right) |
| Each vehicle or tool has a job only it can do | n/a | no vehicles or tools. Every card has one job, a higher kick ("every upgrade kicks higher", C-03); cards differ by power band, gag and look (`tests/test_upgrade_effects.gd::test_every_card_has_a_slot_and_an_effect`) |
| Anything that changes play shows its cause | yes | curses: reveal, badge, beat, "that's why" (`tests/test_curse_show.gd`, U-15..U-19, FR-08); no run-up = a visible toe-poke; landmarks and the Dragon change nothing |
| No real places or personal details | yes | invented landmarks (V-23); grep of `scenes/ scripts/ data/ store/ art/prompts/` for emails and surnames: none (one first name in a tools script's licence note, not shipped) |
| Solo is session-only and never restored at boot | yes | `tests/test_feel_rules.gd::test_a_remembered_solo_setting_does_not_turn_solo_on_at_boot`, `tests/test_lobby.gd::test_saved_solo_stays_off_at_boot`; `--solo`: frame `solo_01_boot_solo_flag`; Select + Start 2 s: frame `main_18_select_start_solo_on` (marker top left) |
| Saved toggles never restore at boot | **partly** | solo: yes (above). **Screen shake** (Settings) is saved and comes back at boot: needs Kaden (below) |
| A game with a save offers Continue and New (New asks, old save kept) | n/a | no run is ever saved; the save is records only (best kick, card collection) (FR-02) |
| The pause menu has a big icon back to the launcher | yes | `tests/test_pause_door.gd` (5 tests, FR-03); frames `main_06_pause_open`, `main_07_pause_door_focused`, `main_08_pause_door_asks` |
| Every press answers (sound and a visual) | yes | `tests/test_press_answers.gd`, `tests/test_press_answers_game.gd`, `tests/test_feel_rules.gd` (FR-05, FR-05.1..6) |
| Quit never needs a force-close | yes | lobby door → Leave: exit 0, no leak lines (frames `quit_01..03`); pause door → Leave under `--solo`: exit 0 (frame `solo_05_solo_pause_door_asks`); 30-min soak ends through the pause door: exit 0 |

## Verified on the producer box (this pass)

| Check | Result | How |
| --- | --- | --- |
| PLAN-STATUS | 140 built, 0 partial, 0 missing, 4 superseded, 1 dropped, 3 later, 1 n/a (149 rows) | rows recounted by script; `later`: S-05 (Kaden), S-15 (TV box), PF-7 (Kaden's pick) |
| Tests | full gdUnit suite after a clean `--import` (`.godot/` removed), `--ignoreHeadlessMode --continue`: 361/361, 0 errors, 0 orphans, exit 0 | `handoff/test-output.txt` |
| Session flow, real frames | ready-up (hold A alone; both press A), lobby, pause and its door, drop-in, drop-out, end card, solo both ways, quit from the lobby and from the pause | `handoff/frames/` (godot-render, software GPU), described in REPORT.md |
| 30-minute soak | 0 script errors, 0 orphans, 6 sessions / 61 rounds, objects flat at 5276 by session 5, exit 0 through the pause door | `handoff/soak/soak30.log` |
| Title, lobby and pause text | final: "SPACEBALLS", Play / Settings / Back to Open Jar, "WHO'S PLAYING?", "Press A on a controller to join", PAUSED, "PLAYER 1 PAUSED", "LEAVE THE GAME?" with a body that fits where you are | frames `main_01`, `main_06`, `quit_02` |
| Dev switches a player can reach | none from a pad. F3 (fps overlay) and F12 (screenshot) are keyboard-only template debug keys; every other switch needs the command line | `scripts/autoload/Debug.gd`, `scenes/main.gd` |
| Store art, credits, version label, exported zip | unchanged since launch-ready-2 (art rows skipped this pass) | launch-ready-2 evidence; `tests/test_launch_ready.gd`, `tests/test_build_info.gd` |

## Needs the TV box (Kaden's weekend item)

- [ ] **Frame rate:** on the GTX 1060 at 1920x1080, press F3 on a keyboard. Play a whole run to space
  with both pads. The fps number stays at 60 through the round-1 kick, a strong kick with slow-mo,
  the sky tiers, and the space end card with confetti. Producer-box numbers are software rendering
  and mean nothing here.
- [ ] **8BitDo pads:** with both pads off, switch on pad A and press A: the green P1 podium joins.
  Pad B, any button: red P2. Steer the kicker with the **d-pad** as well as the stick. Pull P2's
  power mid-kick: the round carries on. Switch it back on: P2 joins from the next round.
- [ ] **Solo on a real pad:** hold Select + Start for 2 s. The small two-pad icon shows at the top
  left, both podiums ready and the countdown starts (B cancels it). Hold again: it goes off.
  Quit and relaunch: it is off.
- [ ] **Pause door:** Start, then d-pad down three times to the door, then A, then Leave. You are
  back at the launcher with no hang and no force-close.
- [ ] **Sound through the TV:** music layers build with height; curse cues; catchphrases in the
  chooser; the honk on a press that does nothing (X in the lobby). All at living-room volume.
- [ ] **Cold start:** from the launcher tile to the lobby in under 10 s.
- [ ] **Readable from the sofa:** the round dots, the P1 green ring on the grass, curse badges, the
  pause door label.
- [ ] Then S-15: Hermes promotes `dev` to `main` and tags the release.

## Needs Kaden

- **Screen shake setting:** it is saved and comes back on the next boot, but the rule says saved
  toggles never restore. Should it reset to on at every boot, or stay as a comfort setting that is kept?
- **Solo starts by itself:** turning solo on readies both podiums, and the countdown starts round 1 with
  no press (contract: "solo mode readies both"). Booting with `--solo` is in round 1 about 2 s after
  boot, so the chooser is skipped (frame `solo_01_boot_solo_flag`). Keep this, or have solo wait for A on Play?
- **Pause > Restart (PF-7):** it goes back to the lobby. Rename it "New run", or restart in place?
- **Physics ragdoll (S-05):** still wanted? No playtest has asked for it.
- **Clear my records (FR-02):** offer a "clear best kick and cards" in Settings, or not?
- Watch at the next playtest: curse odds of 40 % / 20 % give most players two curses, so a run is
  about 12 rounds at the median.

## Needs a sound

- `dragon_purr`: a designed placeholder until `openjar-characters` renders the Dragon's bark.
- `nope` (FR-05) is still an alias of `card_move` at half pitch; the menus use the template honk.
