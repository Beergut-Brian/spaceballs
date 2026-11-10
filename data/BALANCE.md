# Balance: spaceballs upgrades

Content owns this file. Re-run `tests/test_simulation.gd` and update it whenever odds or multipliers change.

## Model (from `scripts/autoload/Run.gd`, Systems)

- Kick power = `BASE_POWER x product(power_mult of every upgrade picked) x run-up quality (0.8 to 1.2)`.
  Height = power² / 2g, so every x1.75 normal pick roughly triples the height.
- Card odds per slot: normal 60 %, strong 20 %, joke 12 %, curse 8 %. Every draw has a normal.
- Tier band: rounds 1-4 draw tier-1 cards, 5-8 tiers 1-2, 9+ all three (`c.tier <= band`).
- Catch-up: a player 2+ tiers behind gets normals of x1.7+ and 40 % strong slots.
- Round 14+: strong-only pool. Round 15: the kick is floored just over the space line.

## Target curve (GAME.md)

Median 11 rounds to space, 10 to 12 OK; two early strongs can do it in 7 or 8; three curses
stretch to 14 or 15; nobody passes round 15; P1 and P2 stay within 2 tiers after round 6.

### Best tier reached by round (1P, 400 random-pick runs)

| Round | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 | 15 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| median tier | 1 | 2 | 3 | 4 | 4 | 5 | 5 | 6 | 6 | 7 | 7 | 7 | 8 | 8 | 8 |
| p25 / p75 | 1/1 | 2/2 | 3/3 | 3/4 | 4/4 | 4/5 | 5/6 | 5/6 | 6/7 | 6/7 | 7/8 | 7/8 | 7/8 | 7/8 | 8/8 |

About one tier per round early, slowing through Clouds and Thin air so the space round is a big moment.

## Multiplier bands

| Kind | Count | Range used | GAME.md range | Notes |
| --- | --- | --- | --- | --- |
| normal | 16 | x1.6 to x1.9 | x1.6 to x1.9 | rises with tier: tier 1 x1.6-1.75, tier 2 x1.75-1.85, tier 3 x1.85-1.9 |
| strong | 11 | x2.3 to x2.65 | x2.3 to x2.8 | kept off the top of the band: a 2.8 strong let one player run 3 tiers ahead |
| joke | 10 | x1.1 to x1.3 | x1.0 to x1.3 | kept near the top: a kid who loves the jokes must still reach space by 15 |
| curse | 7 | x0.15 to x0.3 | x0.1 to x0.3 | one round only (Systems); the frog round also ignores all gear, so it is x0.25 flat |

## Tuning log

- 2026-11-09: 44 upgrades replace the 16 placeholders. First pass (normals x1.6-1.9, avg 1.74) gave median 12.
  Normals +0.05 -> median 11 but worst P1/P2 gap 3 (joke-heavy early picks). Jokes lifted to x1.1-1.3,
  strongs trimmed to x2.3-2.65 -> median 11, worst gap 2. Green.

## Simulation output (2026-11-09)

```
[sim] 1P, 400 runs, random picks: median 11.0, min 7, max 15
  round  7:    1 #
  round  8:    1 #
  round  9:   30 #####
  round 10:   80 ############
  round 11:  117 ##################
  round 12:   80 ############
  round 13:   56 #########
  round 14:   20 ###
  round 15:   15 ###
[sim] kicks lifted to space by the round-15 floor: 1 of 400 player-runs
[sim] 2P, 400 runs, random picks: median 11.0, min 8, max 15
  round  8:    2 #
  round  9:   41 ####
  round 10:  159 ############
  round 11:  258 ####################
  round 12:  211 ################
  round 13:   93 #######
  round 14:   31 ###
  round 15:    5 #
[sim] kicks lifted to space by the round-15 floor: 0 of 800 player-runs
[sim] max tier gap after round 6: median 1.0, worst 2, runs with gap > 2: 0
[sim] 1P, 400 runs, best picks: median 9.0, min 7, max 10
  round  7:    1 #
  round  8:  111 #################
  round  9:  243 #####################################
  round 10:   45 #######
[sim] kicks lifted to space by the round-15 floor: 0 of 400 player-runs
```

## Upgrade table

| Kind | Tier | x | Name | id | Visual | Description |
| --- | --- | --- | --- | --- | --- | --- |
| normal | 1 | 1.6 | Sweatband | `sweatband` | yes | Looks sporty. Is sporty. Smells sporty. |
| normal | 1 | 1.65 | Helium Ball | `helium_ball` | yes | Fill the ball with balloon gas. It wants to go up anyway. |
| normal | 1 | 1.65 | Lucky Sock | `lucky_sock` | yes | Never washed. That's where the luck lives. |
| normal | 1 | 1.7 | Trampoline Tee | `trampoline_tee` | yes | The ball sits on a tiny trampoline and is very excited about it. |
| normal | 1 | 1.75 | Big Boot | `big_boot` | yes | A boot the size of a bathtub. Plenty of room for the foot. |
| normal | 1 | 1.75 | Spring Shoes | `spring_shoes` | yes | Boing on the way in, boing on the way out. |
| normal | 2 | 1.75 | Foam Finger | `foam_finger` | yes | Number one kicker, says the giant foam hand. |
| normal | 2 | 1.8 | Coach's Whistle | `coachs_whistle` | yes | Tweet! The ball listens to the coach. |
| normal | 2 | 1.8 | Propeller Cap | `propeller_cap` | yes | The propeller spins so fast the whole kick gets lighter. |
| normal | 2 | 1.8 | Running Start | `running_start` | yes | A stopwatch on a string. Ready, steady, KICK. |
| normal | 2 | 1.8 | Super Strength | `super_strength` | yes | Lifts a dumbbell with one hand. Kicks with the other foot. |
| normal | 2 | 1.85 | Rocket Boots | `rocket_boots` | yes | Boots with little rockets on the heels. Mind the lawn. |
| normal | 2 | 1.85 | Super Cape | `super_cape` | yes | A cape made from a bath towel. Flaps heroically. |
| normal | 3 | 1.85 | Bouncy Knee Pads | `knee_pads` | yes | Rubber knees. Every kick comes back with a boing. |
| normal | 3 | 1.9 | Giant Foot | `giant_foot` | yes | One normal foot. One foot the size of a sofa. |
| normal | 3 | 1.9 | Wind-Up Key | `wind_up_key` | yes | Wind the kicker up like a toy, then let go. |
| strong | 1 | 2.3 | Dad Strength | `dad_strength` | yes | A tool belt, a mug of coffee and the power of every dad ever. |
| strong | 1 | 2.3 | Moon Gravity | `moon_gravity` | yes | A little moon follows you around and makes everything floaty. |
| strong | 1 | 2.35 | Slingshot Buddy | `slingshot_buddy` | yes | The other kicker holds the slingshot. Pull back... further... |
| strong | 2 | 2.4 | Kangaroo Tail | `kangaroo_tail` | yes | Sit on the tail, bounce, kick. Ask any kangaroo. |
| strong | 2 | 2.4 | Volcano Boots | `volcano_boots` | yes | Each boot is a tiny volcano. Hot feet, huge kick. |
| strong | 2 | 2.45 | Cannon Leg | `cannon_leg` | yes | A leg that is also a cannon. Kaboom, but friendly. |
| strong | 2 | 2.45 | Pogo Legs | `pogo_legs` | yes | Two pogo sticks where the legs used to be. |
| strong | 2 | 2.45 | Tornado Spin | `tornado_spin` | yes | Spin so fast you become a small, polite tornado. |
| strong | 2 | 2.5 | Jetpack | `jetpack` | yes | Two fizzing rockets on the back. Strap in. |
| strong | 3 | 2.6 | Thunder Hat | `thunder_hat` | yes | A grumpy little storm cloud. The kick comes with lightning. |
| strong | 3 | 2.65 | Turbo Fan | `turbo_fan` | yes | A fan the size of a fridge strapped to the back. Hair everywhere. |
| joke | 1 | 1.15 | Mustache | `mustache` | yes | A magnificent mustache. Strength unknown, style enormous. |
| joke | 1 | 1.2 | Honk Horn Shoes | `honk_horn_shoes` | yes | Every step honks. Every kick HONKS. |
| joke | 1 | 1.2 | Tiny Hat | `tiny_hat` | yes | A very small hat. Very dignified. |
| joke | 1 | 1.25 | Extra Shoes | `extra_shoes` | yes | Now with four shoes. Nobody knows where the extra feet came from. |
| joke | 2 | 1.2 | Balloon Animal Ball | `balloon_animal_ball` | yes | A balloon dog for company. It squeaks when you kick. |
| joke | 2 | 1.2 | Rubber Chicken | `rubber_chicken` | yes | It does nothing. It squawks anyway. |
| joke | 2 | 1.25 | Confetti Kick | `confetti_kick` | yes | Pop! The kick comes with a party. |
| joke | 2 | 1.3 | Opera Kick | `opera_kick` | yes | Hold the high note through the whole wind-up. LAAAA! |
| joke | 3 | 1.1 | Googly Eyes | `googly_eyes` | yes | Two enormous wobbly eyes stuck on the tummy. No help at all. |
| joke | 3 | 1.25 | Duck Floatie | `duck_floatie` | yes | Ready for the pool. The pool is not here. |
| curse | 1 | 0.25 | Banana Peel | `banana_peel` | yes | Whoops, a banana peel right by the tee. Slip, flip, plop. |
| curse | 1 | 0.25 | Kiss the Frog | `kiss_the_frog` | frog scene | Mwah. Ribbit. One round as a frog. |
| curse | 1 | 0.3 | Sneeze | `sneeze` | yes | Ah... ahh... AHHH-CHOO! Right on the kick. |
| curse | 2 | 0.2 | Shoelaces Tied | `shoelaces_tied` | yes | Somebody tied your laces together. Hop, hop, bonk. |
| curse | 2 | 0.2 | Too Much Lunch | `too_much_lunch` | yes | Three sandwiches and a pie. Too full to kick. |
| curse | 2 | 0.25 | Butterfly | `butterfly` | yes | Ooh, a butterfly! The kick can wait. |
| curse | 3 | 0.3 | Hiccups | `hiccups` | yes | Hic! The kick goes hic-wards. |
