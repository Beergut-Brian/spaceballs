# Plan status: Spaceballs

Sources (newest last):
- S1 `~/openjar/SPACEBALLS-PLAN-2026-11-09.md` (Kaden's original brief)
- S2 `GAME.md` (Pitch .. Kid-design checks, derived from S1 plus Kaden's art-direction chat)
- S3 `GAME.md` "Playtest 2026-11-09 changes" (`playtests/2026-11-09.md`)
- S4 `GAME.md` "Playtest 2026-11-09 #2 changes" (`playtests/2026-11-09-2.md`)
- S5 Kaden's chat 2026-11-10: "a couple of those Spaceballs features are done, but may not be polished. And the Lawn Chair obviously isn't relevant since the other player can now run around."
- S6 Kaden's chat 2026-11-10: "on the character selector, whenever choosing a new character or scrolling through the list of characters, when a character is up on the screen, I'd like it to say it's catchphrase once. Give a little audio queue of who they are if that makes sense."
- S7 Gary's build-label-1 packet 2026-11-10: dev.13's menu showed "v0.0.1-dev.1"; a scripted chooser run wrote the real shared picks file and broke tests/test_lobby.gd::test_jeff_left_chuck_right_and_ready_cheers

Audit 2026-11-10 (plan-gaps lane, `feature/plan-gaps` off `dev` at `46f115f`). Totals after this lane: 97 built, 6 partial, 0 missing, 3 superseded, 4 later (110 rows); after polish-2 (2026-11-10): 100 built, 3 partial, 0 missing, 3 superseded, 4 later (110 rows); after gap-close-2 sync (2026-11-10): 101 built, 2 partial, 0 missing, 3 superseded, 4 later (110 rows); after chooser-catchphrase (2026-11-10, recounted from the rows, which the stick-only docs change had moved): 102 built, 1 partial, 0 missing, 4 superseded, 1 dropped, 3 later (111 rows); after build-label-1 (2026-11-10): 104 built, 1 partial, 0 missing, 4 superseded, 1 dropped, 3 later (113 rows). Every row was checked
against the code and the tests on this branch, not against earlier reports. Frames are under
`handoff/shots/` (git-excluded; Gary attaches them to the PR). Tests are `tests/<file>.gd::<test>`.
When S1 and S2 say the same thing it is one row, sourced "S1/S2".

## C: core loop

| ID | Source | Item (short, Kaden's words where possible) | Status | Proof | Notes |
| --- | --- | --- | --- | --- | --- |
| C-01 | S1/S2 Pitch | Each player has a ball; the goal is to kick it into space | built | tests/test_run.gd::test_player_in_space_is_skipped_and_run_ends_when_both_are | |
| C-02 | S1/S2 Pitch | "No kick button, automatically kicks when close" | built | tests/test_upgrade_effects.gd::test_kick_fires_on_contact_with_own_ball_only, tests/test_playtest2.gd::test_long_run_up_then_kick_on_contact | |
| C-03 | S1/S2 Pitch | "Starts wimpy"; every upgrade kicks higher | built | tests/test_run.gd::test_power_is_base_times_product_times_quality | round 1 is about 3 m (Decisions 2026-11-09) |
| C-04 | S1/S2 Core loop | Run of 10 to 12 rounds, 8 to 12 min; median 11 rounds | built | tests/test_simulation.gd::test_two_players_random_picks, data/BALANCE.md | minutes not measured on a real pad |
| C-05 | S1/S2 Core loop | Round under a minute | built | tests/test_lobby.gd::test_round_one_waits_for_the_run_up | long run-up (S4) is ~6-10 s per kick in demo frames |
| C-06 | S1/S2 Core loop | No losing; a bad round is just a shorter kick | built | tests/test_run.gd::test_round_15_always_reaches_space | |
| C-07 | S1/S2 Core loop | Kick, Jeff; kick, Chuck (one after the other, full screen) | built | tests/test_run.gd::test_phase_order_two_players, handoff/shots/base/t090.0s.png | |
| C-08 | S1/S2 Core loop | Camera follows the ball up the height ladder until it stops; landmarks whoosh past | built | scripts/gameplay/camera_rig.gd::follow, tests/test_sky.gd::test_a_flight_hits_things_and_frees_them | |
| C-09 | S1/S2 Core loop | Height strip / meter ticks during the flight | built | scenes/ui/hud.gd::_process (marker rides the live height) | pictures: see V-07 |
| C-10 | S1/S2 Core loop | Upgrade pick: split screen, three big icon cards, no text, stick + A | built | tests/test_main_flow.gd::test_round_one_plays_through_pick_into_round_two, handoff/shots/base/t040.0s.png | |
| C-11 | S1/S2 Core loop | The item animates onto the character | built | scenes/main.gd::_on_picked (add_upgrade_visual + PICK_BEAT), tests/test_gear.gd | |
| C-12 | S1/S2 Core loop | Both pick at once; the round waits with a gentle bounce, never a timer | built | scenes/ui/upgrade_pick.gd (bounce on the slower side), tests/test_solo.gd::test_solo_pick_takes_p1_then_p2_from_one_pad | |
| C-13 | S1/S2 Core loop | Round counter is a stack of balls on the HUD, not a number | built | scenes/ui/hud.gd::_refresh_rounds, handoff/shots/base/t090.0s.png (4 balls bottom-left) | |
| C-14 | S1/S2 Core loop | Balls return to the tee with a comedy drop from the sky | built | scenes/ball.gd::_drop (bounce ease + land + puff) | |
| C-15 | S1/S2 Core loop | Space: a ball crossing the space line ends that player's run | built | tests/test_run.gd::test_player_in_space_is_skipped_and_run_ends_when_both_are | |
| C-16 | S1/S2 Core loop | Space: the ball floats | built | scenes/ball.gd::_reach_peak (orbit ring, smiling ball), main.gd::_on_ball_stopped (camera orbit) | |
| C-17 | S1/S2 Core loop | Space: the character does a victory dance | built | tests/test_plan_gaps.gd::test_ball_in_orbit_gets_a_dance_and_a_waving_visitor, handoff/shots/space/victory_dance.png | 2026-11-10: he dances from the orbit on, and keeps dancing on his cloud |
| C-18 | S1/S2 Core loop | Space: a little satellite or alien waves | built | tests/test_plan_gaps.gd::test_ball_in_orbit_gets_a_dance_and_a_waving_visitor, handoff/shots/space/orbit_visitor.png | 2026-11-10: the Sky lane's saucer pops in beside every orbiting ball (alien theremin), its alien waving; gone when the flight ends |
| C-19 | S1/S2 Core loop | The other keeps kicking; the finished player cheers from a cloud | built | main.gd::_to_cloud, tests/test_run.gd::test_player_in_space_is_skipped_and_run_ends_when_both_are | |
| C-20 | S1/S2 Core loop | End card: both in space suits, confetti, restart | built | tests/test_rounds_polish.gd::test_end_card_flow, tests/test_lobby.gd::test_end_card_a_goes_to_lobby_and_door_quits | A goes to the lobby (Showtime), the door to the launcher |
| C-21 | S1 Save / S2 Tech | End card shows the run's / the collection of silly items | built | tests/test_plan_gaps.gd::test_end_card_shelves_hold_each_players_picks, ::test_end_card_collection_shows_every_card_seen_ones_in_colour, handoff/shots/space/end_card_collection.png | 2026-11-10: the run's picks per player (P1 shelf left, P2 right, tiles in the player colour, no text) pop in one by one; across the top the profile's whole collection: every card, the ones ever drawn in colour, the rest dark silhouettes to find |
| C-22 | S1/S2 Core loop | Catch-up: two or more tiers behind gets only above-average cards | built | tests/test_run.gd::test_catch_up_when_two_tiers_behind, ::test_catch_up_draws_only_above_average | |
| C-23 | S1 Core loop | Both players must finish (co-op, not race) | built | tests/test_run.gd::test_player_in_space_is_skipped_and_run_ends_when_both_are | |
| C-24 | S3 | Free movement: run around, kick fires when you run into your ball | built | tests/test_free_roam.gd (8 tests) | |
| C-25 | S3 | Funny wind-up starts when they reach the ball | built | tests/test_gags.gd::test_every_gag_kicks_exactly_once | |
| C-26 | S4 | Long run-up: ball "way further away"; camera follows the run | built | tests/test_playtest2.gd::test_long_run_up_then_kick_on_contact, camera_rig.gd::field_frame | |
| C-27 | S4 | No accidental jump-overs: low hop snaps in front and kicks; big jump flies over | built | tests/test_playtest2.gd::test_low_hop_over_the_ball_snaps_in_front_and_kicks, ::test_high_jump_flies_over_the_ball | |

## P: players

| ID | Source | Item | Status | Proof | Notes |
| --- | --- | --- | --- | --- | --- |
| P-01 | S1/S2 Players | 2 players, co-op, couch, one TV | built | tests/test_run.gd::test_phase_order_two_players | |
| P-02 | S1/S2 Players | P1 Jeff green `#3CC24A`, P2 Chuck red `#E4393C` | built | tests/test_smoke.gd::test_players_colors_are_green_and_red, tests/test_character_spawn.gd::test_defaults_are_jeff_and_chuck | since the chooser (2026-11-10) Jeff/Chuck are the defaults, any Roster pick plays |
| P-03 | S1/S2 Players | Jeff: loose flailing barefoot run, arms windmilling, chicken costume flapping | built | data/run_styles/jeff.tres, art/scripts/run_style_modifier.gd, tests/test_run_style.gd::test_jeff_windmills_and_chuck_keeps_his_arms_stiff, handoff/frames/jeff_run_cycle.png, handoff/frames/p03_jeff_run_cycle.png | polish-2 lane: per-character RunStyle (bob 0.17, arms windmill, comb flaps). gap-close-2 re-checked on dev: three demo frames 0.2 s apart show the chicken hood bobbing and the arms out and flailing |
| P-04 | S1/S2 Players | Chuck: stiff stomping run; hat flies off on every kick and lands back | built | data/run_styles/chuck.tres, tests/test_run_style.gd::test_chuck_stomps_with_a_landing_and_jeff_does_not, handoff/frames/chuck_run_cycle.png, handoff/frames/p04_chuck_run_cycle.png | polish-2 lane: stomp (lift slow, drop hard, squash, thud, dust), stiff arms; hat pop unchanged. gap-close-2 re-checked on dev (`--p1-char=chuck`): the frames show the drop with squash and a dust puff on each landing |
| P-05 | S1/S2 Players | Drop-in: one pad active, the other sits on a lawn chair and cheers | superseded | S4 bystander + S5 "the Lawn Chair obviously isn't relevant" | the chair is still where an unjoined P2 waits (main.gd::_bench); harmless |
| P-06 | S1/S2 Players | Any button on the 2nd pad joins; ball at the start of the next round | built | tests/test_lobby.gd::test_late_joiner_plays_from_next_round, tests/test_run.gd::test_late_joiner_plays_from_next_round | |
| P-07 | S1/S2 Players | Run-up quality 0.8 to 1.2: straight fast run-up up to +20 % | built | tests/test_kicker.gd::test_run_up_quality_bounds, tests/test_free_roam.gd::test_runup_bonus_lifts_a_lazy_run | |
| P-08 | S1/S2 Players | Frog form: frog for the round, keeps accents, hops, flop/tongue-boop, ball goes a few feet | built | tests/test_rounds_polish.gd::test_frog_round, tests/test_character_spawn.gd::test_frog_wears_only_its_own_characters_costume | |
| P-09 | S1 Players | Personalities (Jeff hippy, Chuck overconfident) | later | GAME.md Open questions (D37) | needs barks / voices |
| P-10 | S4 | The other player is a bystander: runs around with all his upgrades, can't kick | built | tests/test_playtest2.gd::test_bystander_roams_with_gear_and_cannot_kick | |
| P-11 | S4 | Bystander may run off-screen; a colour arrow at the edge shows where | built | scripts/gameplay/offscreen_arrow.gd, handoff/shots/base/t009.0s.png (red arrow bottom) | |

## K: controls and kid-design checks

| ID | Source | Item | Status | Proof | Notes |
| --- | --- | --- | --- | --- | --- |
| K-01 | S1/S2 Controls | Left stick steers (now: runs freely) | built | tests/test_free_roam.gd::test_no_auto_steer_with_no_input | steer-to-ball superseded by C-24 |
| K-02 | S1/S2 Controls | A in kick phase: shout + little hop | built | kicker.gd::_buttons (shout, hop, puff) | |
| K-03 | S1/S2 Controls | B: hop; a hop in the run-up gives a tiny power bonus | built | tests/test_free_roam.gd::test_spring_shoes_hop_higher, kicker.gd::_hopped_t in _quality_now | |
| K-04 | S1/S2 Controls | Start pauses anywhere | built | tests/test_lobby.gd::test_pause_shows_menu_and_resume | |
| K-05 | S1/S2 Controls | Select twice within 1 s restarts | built | tests/test_game_restart.gd::test_two_presses_within_a_second_restart | |
| K-06 | S1/S2 Controls | A skips the end card | built | tests/test_lobby.gd::test_end_card_a_goes_to_lobby_and_door_quits | |
| K-07 | S1/S2 Controls | Whole game playable with the stick alone | dropped | kick, pick, run all stick-only; end card: tests/test_gap_close.gd::test_holding_the_stick_onto_the_big_button_goes_back_to_the_lobby, handoff/frames/k07_end_card_stick_hold.png | Kaden, 2026-11-10: "menus needing a button is totally fine. If you have Stick Only Play as a requirement for games that needs gone." |
| K-08 | S1/S2 Kid checks | Only wiggling the stick still kicks every round | built | tests/test_run_style.gd::test_wiggle_at_the_ball_is_a_toe_poke_that_still_kicks, ::test_short_real_run_up_is_the_full_kick, handoff/frames/k08_poke_vs_full_kick.png | polish-2 lane: a wiggle still kicks, as a toe-poke at the lowest run-up quality; the full kick needs a short real run-up (Kicker.has_run_up) |
| K-09 | S1/S2 Kid checks | A curse is never the only choice; every draw has a normal card | built | tests/test_run.gd::test_every_draw_before_14_has_a_normal_card, ::test_curses_never_offered_in_a_pick | |
| K-10 | S1/S2 Kid checks | No run lasts past round 15 | built | tests/test_run.gd::test_round_15_always_reaches_space, ::test_strong_only_after_round_14 | |
| K-11 | S1/S2 Kid checks | Waiting player has something to look at and to do (cheers on a button press) | built | kicker.gd::_buttons, tests/test_plan_gaps.gd::test_bystander_cheers_on_a_button_press | 2026-11-10: test added (A on the bystander's pad = cheer hop, puff and "yaaay", never a kick) |
| K-12 | S1/S2 Kid checks | Upgrade pick never times out | built | upgrade_pick.gd (no timer), tests/test_solo.gd::test_solo_pick_takes_p1_then_p2_from_one_pad | |
| K-13 | S1/S2 Kid checks | Catch-up keeps the balls within two tiers after round 6 | built | tests/test_simulation.gd::test_two_players_random_picks | |
| K-14 | S1/S2 Kid checks | Height shown with pictures, not numbers | built | tests/test_plan_gaps.gd::test_strip_blocks_are_landmark_pictures_top_down, handoff/shots/strip/strip_closeup.png | 2026-11-10 plan-gaps |
| K-15 | S1/S2 Kid checks | Frog round reads as a joke: both laugh, upgrades return next round | built | tests/test_rounds_polish.gd::test_frog_round, tests/test_upgrade_effects.gd::test_frog_switches_effects_off | |

## U: upgrades

| ID | Source | Item | Status | Proof | Notes |
| --- | --- | --- | --- | --- | --- |
| U-01 | S1/S2 Upgrades | Data, not code: one UpgradeData .tres per upgrade, spec fields | built | tests/test_upgrades_data.gd::test_fields_follow_the_spec | |
| U-02 | S1/S2 Upgrades | 40+ upgrades, every kind and tier | built | tests/test_upgrades_data.gd::test_forty_plus_upgrades_cover_every_kind_and_tier | 44 cards |
| U-03 | S1/S2 Upgrades | Every GAME.md example exists | built | tests/test_upgrades_data.gd::test_every_game_md_example_exists | |
| U-04 | S1/S2 Upgrades | Odds 60/20/12/8 and power bands per kind | built | data/BALANCE.md, tests/test_run.gd::test_kind_odds_never_roll_a_curse | curse 8 % superseded by U-11 |
| U-05 | S1/S2 Upgrades | Two strong in a row: 7-8 rounds; three curses: 14-15 | built | tests/test_simulation.gd::test_best_picks_are_faster_but_capped | |
| U-06 | S1/S2 Upgrades | Some upgrades are plainly better and it isn't hidden | built | upgrade_card.gd strong cards have a gold sunburst back, handoff/shots/base/t040.0s.png | |
| U-07 | S1/S2 Upgrades | Curses are a choice and look tempting (sparkly frog) | superseded | S4 "curses are not cards you pick" | |
| U-08 | S1/S2 Upgrades | Upgrades stack visually (a walking pile) | superseded | S3 "gear is worn, not piled" | |
| U-09 | S3 | Upgrades change the play (run speed, run-up, jump, kick style, ball) | built | tests/test_upgrade_effects.gd::test_named_cards_do_what_they_say, tests/test_free_roam.gd::test_rocket_boots_run_faster | |
| U-10 | S3 | Gear worn one per slot; new replaces old; owned gear not offered again | built | tests/test_gear.gd::test_swap_on_an_occupied_slot, tests/test_upgrade_effects.gd::test_owned_gear_is_never_offered_again | |
| U-11 | S4 | Curses are hidden: a picked card may flip to a curse, about two per run | built | tests/test_playtest2.gd::test_curse_reveal_flips_the_picked_card, tests/test_run.gd::test_hidden_curse_rules | |
| U-12 | S4 | Banana peel further out: slip, slide into the ball, barely goes | built | tests/test_playtest2.gd::test_banana_peel_slips_him_a_few_metres_out | |
| U-13 | S3 | Upgrade art full redo (cards and gear) | built | assets/sprites/upgrades (44 rendered icons, one per card), assets/gear (34 glbs), scenes/upgrades (9 vignette pieces), tests/test_gear.gd::test_every_wearable_card_resolves_to_gear, handoff/frames/u13_pick_cards.png | gap-close-2 sync: every card in data/upgrades has a rendered icon (no grey-box GradientTexture2D left) and a worn visual (gear glb, vignette scene, or the frog scene for Kiss the Frog); art-card-icons and art-gear-finish lanes did the work. The pick frame shows final icons on all six cards. (The row's old proof path assets/icons never existed.) |
| U-14 | S1 Upgrades | Frog scene: card flips, a frog hops in and kisses him, poof | built | main.gd::frog_kiss, tests/test_plan_gaps.gd::test_frog_kiss_hops_in_kisses_and_poofs, handoff/shots/frog/frog_kiss.png | 2026-11-10: after the card flips to Kiss the Frog, a little frog hops in (two ribbits), jumps to his cheek (smooch squeak, pink puff), poofs; the frog round is his next kick as before |

## V: visuals, camera, juice

| ID | Source | Item | Status | Proof | Notes |
| --- | --- | --- | --- | --- | --- |
| V-01 | S2 Art | Clean smooth-shaded 3D TV-sports look, rim light (supersedes S1 low-poly + outlines) | built | handoff/shots/base/t090.0s.png | S1 "low-poly flat-shaded, outlines" superseded by Kaden's chat |
| V-02 | S2 Art | Jarlings: Jeff and Chuck from openjar-characters | built | tests/test_character_spawn.gd::test_defaults_are_jeff_and_chuck | |
| V-03 | S2 Art | Authored actions + procedural wobble (ragdoll later) | built | art/scripts/jarling_rig.gd | ragdoll flail: later (Decisions 2026-11-09) |
| V-04 | S1/S2 Art | Sky ramp steps clearly through eight tiers | built | art/scripts/sky_ramp.gd, data/tiers.tres | |
| V-05 | S1/S2 Progression | Eight tiers with landmark gags, as data | built | data/tiers.tres, scenes/levels/landmarks/*.tscn, tests/test_run.gd::test_tier_lookup | |
| V-06 | S4 | Busier sky; ball pops balloons, bonks planes, scatters birds, each with a sound | built | tests/test_sky.gd (8 tests) | |
| V-07 | S1/S2 Camera | Height strip on the right edge with landmark pictures, no numbers | built | scenes/ui/tier_icon.gd, tests/test_plan_gaps.gd::test_every_tier_has_a_picture, handoff/shots/strip/strip_closeup.png | 2026-11-10: each block is its landmark drawn on the tier's sky colour (fence, house + cat, tree + bird, hot-air balloon, plane + cloud, jet + balloon, satellite + aurora, moon + alien); strip 50 -> 90 px wide |
| V-08 | S1/S2 Camera | Best-ever height per profile is a little flag on the strip | built | tests/test_plan_gaps.gd::test_best_flag_rides_with_a_ball_that_beats_it, tests/test_run.gd::test_save_keys_best_height_runs_and_seen, handoff/shots/strip/strip_closeup.png | 2026-11-10: bigger flag on a white line inside the strip (clear of the ball markers); a ball that beats it pops it (sparkle cue) and carries it up |
| V-09 | S1/S2 Camera | Approach and kick: TV-sports framing, side-on, behind and above | built | camera_rig.gd::field_frame, handoff/shots/base/t090.0s.png | |
| V-10 | S1/S2 Camera | Flight: follows the ball, zooms out as speed rises | built | camera_rig.gd (follow_zoom) | |
| V-11 | S1/S2 Camera | Landing: hold the peak a beat, a stamp shows the tier reached (icon) | built | tests/test_plan_gaps.gd::test_peak_shows_the_tier_stamp_in_the_kickers_colour, handoff/shots/strip/peak_stamp.png | 2026-11-10: round badge of the tier's picture in the kicker's colour slams in at the top, 1.4 s, with a bonk |
| V-12 | S1/S2 Camera | Upgrade pick: vertical split, each half frames its character | built | handoff/shots/base/t040.0s.png | |
| V-13 | S1/S2 Camera | Space: slow orbit round the floating ball and the celebrating character | built | main.gd::_on_ball_stopped, ::_on_ball_returned, handoff/shots/space/orbit_visitor.png, handoff/shots/space/victory_dance.png | 2026-11-10: 2 s orbit round the ball, then 2 s orbit round the dancing kicker with the crowd |
| V-14 | S4 | Camera on the kicker only; follows big jumps up and down | built | camera_rig.gd (jump look-ahead) | |
| V-15 | S1/S2 Art | Juice: screen shake scaled to power, dust puff, speed lines, star burst at tiers | built | art/scripts/juice.gd | |
| V-16 | S1/S2 Art | Half-second slow motion on the strongest kicks | built | scripts/gameplay/slow_mo.gd, tests/test_plan_gaps.gd::test_slow_mo_lasts_half_a_real_second_then_restores, ::test_slow_mo_only_for_the_strongest_uncursed_kicks | 2026-11-10: kicks peaking at tier 7-8 (the sonic-boom kick), never a curse or the frog; 0.25x for 0.5 real s; a still frame can't show it |
| V-17 | S1/S2 Art | Balls with reacting faces | built | art/scripts/ball_look.gd | |
| V-18 | S1/S2 Art | Props: tee, two balls, lawn chair, landmarks, upgrade attachments | built | scenes/levels/field.tscn | lawn chair kept as scenery |
| V-19 | S4 | Crowd cheers a good kick (bigger kick, bigger celebration) | built | tests/test_playtest2.gd::test_crowd_reaction_scales_with_the_kick | |
| V-20 | S1/S2 Art | Store art: grid 600x900, hero 920x430 | built | store/grid.png, store/hero.png | |
| V-21 | S2 Art | Palette D36 (C Cool Arcade provisional) | superseded | GAME.md Open questions | D36 (one master palette) withdrawn 2026-11-10: palettes are picked per game now |

## A: audio

| ID | Source | Item | Status | Proof | Notes |
| --- | --- | --- | --- | --- | --- |
| A-01 | S1/S2 Audio | Sound on every action | built | tests/test_audio_cues.gd::test_every_documented_cue_resolves, ::test_every_sfx_file_is_used | |
| A-02 | S1/S2 Audio | Cues windup, kick_1..4, whoosh (pitch by speed), tier_up, land, card_move/pick, upgrade_on, curse, frog, space, cheer | built | assets/audio/CUES.md, tests/test_audio_cues.gd::test_every_cue_resolves_to_a_stream | |
| A-03 | S1/S2 Audio | Music: one upbeat loop | built | assets/audio/music/field_loop.ogg | |
| A-04 | S1/S2 Audio | Music gains a layer per height tier | built | assets/audio/music/field_loop_layer_1..3.ogg (assets/audio/tools/make_music_layers.py), tests/test_plan_gaps.gd::test_field_loop_layers_wrap_with_the_base_loop, ::test_music_level_fades_the_layers_in_and_out, ::test_a_level_asked_for_during_the_swap_is_kept, handoff/audio/music_level_0..3.ogg | 2026-11-10: three synthesised stems on the loop's measured grid (120 BPM, C major): shaker (tiers 3-4), kick + claps (5-6), bell arpeggio + whee (7-8); 1 s crossfades; back to the base loop at every kick. Fixed: a level asked for while a track was fading in was lost |
| A-05 | S1/S2 Audio | Music drops to a sparse pad in space | built | assets/audio/music/space_pad.ogg, main.gd::_on_reached_space | |
| A-06 | S1/S2 Audio | Barks from the kicker and a reaction bark from the watcher (Chatterbox) | later | Audio.bark, GAME.md Open questions D37 | the crowd "yaaay" stands in |
| A-07 | S1 Audio | tier_up has a landmark gag per tier | built | CUES.md gag_rooftops..gag_space | |

## S: systems and tech

| ID | Source | Item | Status | Proof | Notes |
| --- | --- | --- | --- | --- | --- |
| S-01 | S1/S2 Tech | Godot 4.7.2, 3D, Jolt | built | tests/test_smoke.gd::test_physics_is_jolt_and_display_is_1080p | |
| S-02 | S1/S2 Tech | Ball RigidBody3D; impulse = base x product x run-up quality | built | tests/test_run.gd::test_power_is_base_times_product_times_quality | |
| S-03 | S1/S2 Tech | Flight hand-off to a scripted deterministic arc above the clouds | built | scenes/ball.gd::_hand_off | |
| S-04 | S1/S2 Tech | Kicker CharacterBody3D, Area3D auto-kick, wind-up state machine, attach points, frog variant | built | tests/test_kicker.gd::test_attach_points_exist, ::test_frog_mode_hides_upgrades_and_comes_back | state machine is in code, not an AnimationTree |
| S-05 | S1 Tech | PhysicalBone3D ragdoll upper body | later | Decisions 2026-11-09 | |
| S-06 | S1/S2 Tech | Contract signals + Run.power_of / upgrades_of | built | docs/contracts.md, tests/test_run.gd::test_signals_carry_the_contract_values | |
| S-07 | S1/S2 Tech | Save per profile: best height, runs completed, upgrades ever seen | built | tests/test_run.gd::test_save_keys_best_height_runs_and_seen, tests/test_plan_gaps.gd::test_a_revealed_curse_joins_the_collection | best height drives the strip's flag (V-08), upgrades seen the end card's collection (C-21; revealed curses now count too); `runs_completed` is saved but nothing shows it |
| S-08 | S1/S2 Tech | Scenes as listed (main, field, kicker, jeff/chuck, ball, height_ladder, upgrade_pick, hud, frog) | built | scenes/ | |
| S-09 | S1/S2 First playable | Full run to space in 10-12 rounds, frog works, sound+visual everywhere, no red kid check | built | tests/test_simulation.gd, tests/test_rounds_polish.gd::test_frog_round | |
| S-10 | S1/S2 Lanes | data/BALANCE.md holds the curve | built | data/BALANCE.md | |
| S-11 | S1 Out of scope | No versus, no aiming, no online, no persistent upgrades | built | tests/test_run.gd::test_curse_lasts_one_round_and_never_joins_upgrades | every run starts wimpy |
| S-12 | S7 | The menu's version label is the release tag, not project.godot's version | built | tests/test_build_info.gd::test_the_stamped_tag_is_the_label, ::test_no_file_or_a_broken_one_says_dev, ::test_the_lobby_footer_shows_it, handoff/shots/build-label/lobby_stamped_v0.0.2-dev.14.png | template 4906571 port: release.yml "Stamp the version" writes data/build.json (git-ignored, exported via data/*.json) from GITHUB_REF_NAME; BuildInfo.label() (scripts/autoload/build_info.gd, a class_name like the template, no autoload entry needed) reads it, "dev" without it. Local export with a stamped v0.0.2-dev.14 booted clean and the frame shows the tag top right |
| S-13 | S7 | Tests and scripted runs never read or write the real shared picks file or settings | built | tests/test_picks_isolation.gd::test_a_preexisting_real_picks_file_does_not_change_the_defaults, ::test_test_and_scripted_runs_are_sandboxed_from_boot, ::test_the_real_shared_file_is_not_written_by_this_run, handoff/REPORT.md (stale-file run) | RunSandbox.active() (gdUnit runner, --demo/--shots=/--shot-dir=/--screenshot-after=/--ui=/--timescale=/--log-phases or --sandbox) points Roster.picks_path and Save.settings_path at user://sandbox/ from boot. Root cause of the red test_lobby: its before() redirected picks_path but never reloaded, so boot's picks from the real file stayed; it now re-resolves. Checked with a stale real file (P1 bloom) under a scratch XDG_DATA_HOME: test_lobby green, file byte-identical, --demo boot too |

## M: menus

| ID | Source | Item | Status | Proof | Notes |
| --- | --- | --- | --- | --- | --- |
| M-01 | S3 | Main menu with a way back to the launcher | built | tests/test_lobby.gd::test_lobby_door_asks_then_quits | |
| M-02 | S3 | Pause menu with "back to the launcher" | built | tests/test_lobby.gd::test_pause_door_asks_then_quits | |
| M-03 | S3 | Start screen where both players ready up before round 1 | built | tests/test_lobby.gd::test_both_ready_counts_down_then_starts | |
| M-04 | S5 | Polish counts: features that exist but feel rough get finished | partial | this file: every `partial` row | 2026-11-10 audit found 3 missing + 15 partial; this lane built the 3 missing and finished 9 partial (K-11, K-14, U-14, V-07, V-08, V-11, V-13, A-04, C-18). Left: P-03/P-04 run styles (Art), K-07/K-08 (by design since free roam), U-13 (gear-art lane). polish-2 lane (2026-11-10) finished P-03, P-04, K-08; left K-07 (template menus), U-13. gap-close-2 sync (2026-11-10): U-13 was finished by the art-card-icons and art-gear-finish lanes (moved to built); then made the end card stick-only (K-07 half) and gave the gear-on poof the card's colour (it was always white since the painted icons replaced the grey-box gradients; tests/test_gap_close.gd::test_gear_poof_wears_the_card_colour, handoff/frames/poof_card_colours.png). Left: K-07 lobby ready-up (template) |
| M-05 | S6 | Chooser says the character's catchphrase once (Kaden 2026-11-10) | built | tests/test_chooser_voice.gd (12 tests: ::test_three_fast_steps_say_only_the_last_after_the_settle, ::test_standing_still_never_repeats, ::test_scrolling_back_says_it_again, ::test_joining_says_the_pick_once, ::test_two_players_each_on_their_own_voice, ::test_leaving_cancels_a_pending_line, ...), tests/test_sync_characters.gd::test_vendors_the_catchphrase, handoff/chooser-run.log | template port (docs/ui.md "Chooser voice"): each step plays `char_swap` at once; 0.3 s after the last step the podium's character says `voice/catchphrase.ogg` (a bark without one; Jeff, Chuck, Bloom, Old Reel have neither in v0.5.0, so only the swap sound); also on join; cancelled on leave / round start; one panned voice per player. 17 of 21 characters have a catchphrase |
