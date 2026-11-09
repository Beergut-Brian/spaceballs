# Audio cues

PLACEHOLDER (systems grey-box): every file below is a synthesised beep from
`scripts/tools/make_beeps.py`. The Audio lane replaces the files; keep the cue names.

| Cue name (`Audio.play`) | Files | Plays when |
| --- | --- | --- |
| ui_move | sfx/ui_move_1.ogg, sfx/ui_move_2.ogg | menu cursor moves |
| ui_confirm | sfx/ui_confirm.ogg | menu select, restart |
| player_join | sfx/player_join.ogg | a pad joins (P2 stands up from the lawn chair) |
| round_start | sfx/round_start.ogg | Game.start_round |
| round_end | sfx/round_end.ogg | Game.end_round |
| pause | sfx/pause.ogg | pause / resume |
| windup | sfx/windup.ogg | run-up starts, and again at the auto-kick wind-up |
| kick_1 .. kick_4 | sfx/kick_1.ogg .. sfx/kick_4.ogg | kick lands; 1: peak tiers 1-2, 2: 3-4, 3: 5-6, 4: 7-8 |
| whoosh | sfx/whoosh.ogg | ball in flight; pitch rises with speed (played at launch and at the hand-off) |
| tier_up | sfx/tier_up.ogg | ball crosses a tier (`TierData.tier_up_cue`) |
| land | sfx/land.ogg | ball stops at the peak, and its comedy landing on the tee |
| card_move | sfx/card_move.ogg | upgrade pick highlight moves |
| card_pick | sfx/card_pick.ogg | upgrade picked |
| upgrade_on | sfx/upgrade_on.ogg | item attaches to the kicker |
| curse | sfx/curse.ogg | a curse is picked |
| frog | sfx/frog.ogg | frog round: on the approach start, every hop, and the flop |
| space | sfx/space.ogg | a ball reaches space; the end card |
| cheer | sfx/cheer.ogg | the waiting character presses A, or reacts to a kick |
| hop | sfx/hop.ogg | B hop |
| shout | sfx/shout.ogg | A shout-hop during the run-up |
| restart_arm | sfx/restart_arm.ogg | first Select press (a second within 1 s restarts) |
