# Launch checklist: Spaceballs

Kaden (2026-11-10): "I would like to have Spaceballs, Junk Yard Zap, and the Launcher done besides
running it on the TV hardware." Written by the launch-ready-1 lane on 2026-11-10/11, from dev at `ea2712c`.
Evidence (frames, logs, soak samples) is in that lane's `handoff/` (git-excluded; Gary attaches it).

## Verified on the producer box

| Check | Result | How |
| --- | --- | --- |
| Every PLAN-STATUS row true | 119 built, 0 partial, 0 missing, 4 superseded, 1 dropped, 3 later (127) | rows recounted by script; the 3 `later` rows wait on Kaden or the TV (below) |
| Tests | gdUnit4 `--ignoreHeadlessMode --continue`: all green, 0 orphans | `handoff/test-output.txt` |
| Clean import, headless boot | 0 script errors, no leak lines | `godot --headless --path . -- --demo --screenshot-after=8` |
| Session flow, real frames | boot, lobby, chooser + catchphrase, lobby Settings, lobby leave question (stay), both ready, kick, pause, pause Settings, leave question (stay), resume, P2 pad unplugged mid-kick, pick, P2 back in from the next round, end card, lobby again, solo, kick, pause, leave: the process exits by itself, exit 0, no leak lines | scratch driver through the real screens; `handoff/frames/flow_*.png` |
| Never a softlock, a way back on every screen | lobby: B un-readies / closes Settings / stays at the leave question; pause: B backs out of Settings and the question, else resumes; end card: A plays again, the door leaves; pick: Start pauses (door there); a pad leaving never blocks the kick or the pick | flow frames + `tests/test_session_flow.gd`, `tests/test_lobby.gd`, `tests/test_solo.gd` |
| Quit at every screen | lobby door, pause door, end card door all ask, then `Game.quit()` (silences audio, exits clean) | `tests/test_lobby.gd::test_lobby_door_asks_then_quits`, `::test_pause_door_asks_then_quits`, `::test_end_card_a_goes_to_lobby_and_door_quits`; real exit in the flow run and both soaks |
| 30-minute soak (bots kick and pick; real lobby, pause, end card) | 0 script errors, 0 orphans, objects flat at round starts, audio players fixed, exit clean | `handoff/soak/`, numbers in `handoff/REPORT.md` |
| Version label | lobby footer shows the release tag CI writes to `data/build.json`, "dev" locally | `tests/test_build_info.gd`; local export with a stamped tag |
| Store art | `store/grid.png` 600x900, `store/hero.png` 920x430, `store/clip.mp4` (12 s, `art/tools/make_clip.sh`), `store/jar.glb` present and shipped next to the binary | release.yml `cp -r store build/` + `test -s build/store/jar.glb` |
| Credits | every committed asset has a line in `assets/CREDITS.md` (ElevenLabs music: Kaden's plan covers release) | `tests/test_launch_ready.gd::test_every_shipped_asset_has_a_credits_line` |
| No placeholders | no grey-box markers or beep tools ship | `tests/test_launch_ready.gd::test_no_grey_box_placeholder_markers_ship`; one designed placeholder sound left (below) |
| No personal info, no real places | landmarks are invented gags; no emails, addresses or surnames in shipped files | grep of `scenes/ scripts/ data/ store/ art/prompts/`; V-23 |
| README | play instructions for the couch, controls, run/test/export | `README.md` |
| Exported zip boots | export (Linux, embedded pck) + store, zipped and unzipped like CI, boots `--headless` with 0 script errors | `handoff/export-boot.txt` |

## Needs the TV box (this weekend)

- [ ] 60 fps at 1920x1080 on the GTX 1060 (F3 overlay), through a whole run and the space moment. Producer-box frame times are software rendering and mean nothing for this.
- [ ] Two real pads: first press is green P1, the second red P2; unplug and replug P2 mid-round.
- [ ] Sound through the TV: music layers, curse cues, catchphrases, barks at a living-room volume.
- [ ] Cold start from the launcher tile to playing in under 10 s; "Back to Open Jar" returns to the launcher.
- [ ] Readable from the sofa: round-counter balls, the P1 green ring on the grass, curse badges.
- [ ] Then S-15: Hermes promotes `dev` to `main` and tags the release.

## Needs Kaden

- Jeff's and Chuck's voices and personalities (D37, rows P-09 and A-06). The bark hook is built: every voiced roster character already says "cheer" / "oops" / "win" at its kicks; Jeff and Chuck stay quiet until their `voice/` files sync, and the crowd stands in.
- Physics ragdoll (S-05): still wanted? No playtest asked for it since authored animation + wobble shipped.
- Watch at playtest #3: curse odds 40 % / 20 % make almost every player get two curses, so a run is about 12 rounds at the median.

## Needs a sound

- `dragon_purr` (`assets/audio/sfx/dragon_purr.ogg`): a designed placeholder rumble-purr until `openjar-characters` renders the Dragon's own bark (her `voice/` folder has only a README at v0.5.1).
