# Audio cues

Every SFX file is synthesised by `assets/audio/tools/make_cues.py` (Python stdlib + ffmpeg,
seeded, reproducible). Regenerate everything with `python3 assets/audio/tools/make_cues.py`
(add `--spectrograms <dir>` for spectrogram + waveform PNGs). Loudness: -16 LUFS integrated
for cues of 0.6 s or more, short cues matched on their looped loudness, true peak <= -1 dBTP;
frequent cues sit 1 to 3 dB under (trim column in `FILES`).

`Audio.play("cue")` plays `sfx/cue.ogg`, or picks one of `sfx/cue_1.ogg .. cue_N.ogg` at random
(plus a ±5 % pitch wobble). Never leave a `cue.ogg` next to `cue_N.ogg` variants: it wins.

| Cue (`Audio.play`) | Files | Plays when | Sounds like |
| --- | --- | --- | --- |
| windup_jeff | sfx/windup_jeff_1..2.ogg | Jeff (P1) starts his run-up (`Kicker.begin_approach`) | bare feet slapping faster and faster under a rising slide whistle |
| windup_chuck | sfx/windup_chuck_1..2.ogg | Chuck (P2) starts his run-up | heavy boot clonks under a lower slide whistle |
| windup | sfx/windup_1..2.ogg | the wind-up itself (`Kicker.start_windup`, pitch 1.3) | short slide-whistle zwiiip and a knee-bend boing |
| kick_1 | sfx/kick_1_1..2.ogg | kick lands, peak tiers 1-2 | thwack: crack + woody body |
| kick_2 | sfx/kick_2_1..2.ogg | kick lands, tiers 3-4 | bigger thwack with a low thud |
| kick_3 | sfx/kick_3.ogg | kick lands, tiers 5-6 | cannon boom with crackly debris |
| kick_4 | sfx/kick_4.ogg | kick lands, tiers 7-8 | cartoon sonic boom: double crack, rumble, falling "zeeeow", sparkles |
| whoosh | sfx/whoosh_1..2.ogg | ball launches and the flight hand-off; code sets pitch from speed / height | airy swoosh that swells and fades (2 has a faint tone) |
| tier_up | sfx/tier_up_1..2.ogg | ball crosses a tier (`TierData.tier_up_cue`), pitch rises per tier | glockenspiel arpeggio up + sparkles |
| gag_rooftops | sfx/gag_rooftops.ogg | crossing into Rooftops (`Ball.TIER_GAGS`) | a startled cat: "mi-a-ow?" |
| gag_treetops | sfx/gag_treetops.ogg | crossing into Treetops | bird squawk and two tweets |
| gag_clouds | sfx/gag_clouds.ogg | crossing into Clouds | a propeller plane drones past (Doppler dip) |
| gag_edge | sfx/gag_edge.ogg | crossing into Edge of space | satellite beeps: bee-boo-bee-biip |
| gag_space | sfx/gag_space.ogg | crossing into Space | friendly alien theremin: "boop be-doop" |
| land | sfx/land_1..2.ogg | ball stops at the peak; comedy landing on the tee (pitch 1.3) | 1: soft thud, 2: wooden bonk |
| card_move | sfx/card_move_1..2.ogg | upgrade pick highlight moves | xylophone tick (two pitches) |
| card_pick | sfx/card_pick.ogg | upgrade picked | card "fwip" + two-note marimba ding |
| upgrade_on | sfx/upgrade_on_1..3.ogg | item attaches to the kicker | 1: metal clank, 2: spring boing, 3: zip + ding |
| curse | sfx/curse.ogg | a curse is picked, and the cursed kick starts | sad trombone: wah, wah, wah, waaaah |
| frog | sfx/frog_1..3.ogg | frog round: approach start, every hop, the flop | 1-2: "rib-bit" croaks, 3: tongue thwip + boop |
| space | sfx/space.ogg | a ball reaches space; the end card | fanfare chord + timpani + sparkles, then radio: beep, crackle, chatter, beep |
| cheer | sfx/cheer_1..3.ogg | the waiting character presses A or reacts to a kick; end card | the sideline crowd of Jarlings: "yaaay!" voices and claps |
| confetti | sfx/confetti.ogg | end card opens (confetti burst) | party popper + paper rustling down + sparkles |
| honk | sfx/honk_1..2.ogg | **needs data:** `kick_sfx = &"honk"` on Honk Horn Shoes | clown bike horn (1 honk / honk-honk) |
| opera | sfx/opera.ogg | **needs data:** `kick_sfx = &"opera"` on Opera Kick | a diva's "la-LAAAA" with vibrato |
| hop | sfx/hop_1..2.ogg | B hop | tiny rising boing |
| shout | sfx/shout_1..2.ogg | A shout-hop in the run-up | a Jarling "hup!" / "hey!" |
| ui_confirm | sfx/ui_confirm.ogg | menu select, restart | two-note marimba up |
| player_join | sfx/player_join.ogg | a pad joins (pitch 1.5) / leaves (pitch 0.6) | pop + four-note arpeggio up |
| round_start | sfx/round_start.ogg | `Game.start_round` | soft pea-whistle toot-tooot |
| round_end | sfx/round_end.ogg | `Game.end_round` | marimba "ta-da" |
| pause | sfx/pause.ogg | pause / resume | two soft xylophone notes down |
| restart_arm | sfx/restart_arm.ogg | first Select press (a second within 1 s restarts) | wood-block tick-tock |

`honk` and `opera` are rendered but only play once the Upgrades lane sets `kick_sfx` in
`data/upgrades/` (`main.gd::_kick_cue` already honours it). `confetti` also suits a Confetti
Kick's `kick_sfx`. Barks for Jeff and Chuck (`Audio.bark`) come later from Chatterbox.

## Music (drop-in spec, not made here)

The code already asks for these; until the files exist `Audio` warns once and stays quiet.

| File | Called from | Length | Loop |
| --- | --- | --- | --- |
| `music/field_loop.ogg` | title (`main._ready`) and every kick (`main._begin_kick`) | 16 bars at 120 to 132 BPM (about 30 to 32 s), whole bars | seamless, no fade in/out, no reverb tail cut |
| `music/field_loop_layer_1.ogg` | fades in at tier 3-4 (`Audio.music_level(1)`) | exactly the same sample length as `field_loop.ogg` | same |
| `music/field_loop_layer_2.ogg` | fades in at tier 5-6 | same length | same |
| `music/field_loop_layer_3.ogg` | fades in at tier 7-8 | same length | same |
| `music/space_pad.ogg` | a ball reaches space; the end card | 20 to 30 s | seamless |

- The base + 3 layers play in sync (`AudioStreamSynchronized`); a level fades the layers 1..n in
  over 1 s and back to silent at the next kick. Suggested split: base = drums + bass + chords
  (playable on its own), layer 1 = melody/lead, layer 2 = counter-melody or brass stabs,
  layer 3 = big percussion / claps / "whee" synth. The space pad is sparse: pad + bells, no drums.
- Stems must be rendered from the same session, same start sample, 44.1 kHz stereo, Ogg Vorbis
  q5 (`ffmpeg -i in.wav -c:a libvorbis -q:a 5 out.ogg`). Base + all layers together at about
  -20 LUFS integrated (music sits under the -16 LUFS SFX), true peak <= -1 dBTP.
- With just `field_loop.ogg` (no layers) everything still works; the layers simply never appear.
