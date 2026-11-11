# Spaceballs

> Design doc and source of truth for this game. Gary (producer, the maker profile) owns this file.
> Lanes read it before starting and quote it in PRs. If the game drifts from this doc, fix the doc or fix the game.
> Source: Kaden's "Spaceballs — Game Design & Build Plan" (2026-11-09) plus his art direction in chat the same day. Where they differ, the chat direction wins (see Art direction).

## Pitch

Two goofballs each have a ball and one goal: kick it into space. Walk your character up to the ball and he winds up like a lunatic and boots it as hard as he can, **automatically**. It goes nowhere. Then each of you picks a ridiculous upgrade (rocket boots, super strength, a cannon for a leg) and kicks again, higher. Ten to twelve rounds later, if your picks were good and you didn't kiss the frog, your ball is in orbit.

Kerbal Space Program energy with none of the engineering, dressed like a sunny TV sports game. Co-op, not versus: both balls climb the same ladder.

**Kaden's north star (verbatim):** Kerbal Space Project inspired. We each have a ball we are trying to kick into space. Walk a funny-looking character up to the ball and they kick it automatically. The kicker should walk crazily up to the ball and try to kick it as hard as possible. Easy: no kick button, automatically kicks when close. Starts wimpy. After every kick, choose from some incredibly wacky upgrades: rocket boots, super strength, crazy stuff. Every upgrade lets you kick higher until you can kick it into space. Probably 10 to 12 rounds to get it into space with a normal upgrade path. Some upgrades should be better than others. Some, like kissing a frog, turn you into a frog for that round and you lose all your upgrades for that round. Keep it humorous. Camera: full screen for kicks (players kick one after the other), split screen for the upgrade pick. P1 is Jeff, P2 is Chuck.

## Players

- 2 players, co-op, couch, one TV.
- P1 (green `#3CC24A`): **Jeff** (player-locked, from `openjar-characters`). Loose, flailing barefoot run, arms windmilling, chicken costume flapping.
- P2 (red `#E4393C`): **Chuck** (player-locked). Stiff stomping trucker run; hat flies off on every kick and lands back on his head.
- Drop-in / drop-out: with one pad active, the other character sits on a lawn chair at the side and cheers. Any button on the second pad stands him up and gives him a ball at the start of the next round.
- **Auto-kick:** no kick button. Steer with the stick; entering kicking range fires the kick. The approach is deliberately silly and partly out of the player's control. One small skill element: a straight, fast run-up gives up to +20 % power (run-up quality 0.8 to 1.2); a wobbly one still launches.
- **Frog form:** on a curse, the character is a frog for that round (keeps his green or red accents: tiny chicken-costume frog, frog in a trucker hat), hops, and the "kick" is a flop or a tongue-boop. The ball goes a few feet. Upgrades return next round.

## Controls

| Input | Kick phase | Upgrade pick | Anywhere |
| --- | --- | --- | --- |
| Left stick | Steer toward the ball | Move between the three cards | |
| A (action) | Not needed; shout + little hop (harmless, funny) | Pick the highlighted card | Skip the end card |
| B (jump) | Hop (toy); a hop in the run-up gives a tiny power bonus | Nothing | |
| Start | Pause | Pause | Pause |
| Select | Restart the run (two presses within 1 s) | | |

~~The whole game can be played with the stick alone.~~ **Dropped** (Kaden, 2026-11-10: "menus needing a button is totally fine. If you have Stick Only Play as a requirement for games that needs gone.") Buttons are fine anywhere, menus included. Kicks still trigger on contact (the standing no-auto-steer rule), but no feature has to work stick-only.

## Core loop

A run is 10 to 12 rounds, 8 to 12 minutes; a round is under a minute. No losing.

1. **Kick, Jeff.** Full screen. Steer to the tee, auto-kick, camera follows the ball up the height ladder until it stops; landmarks whoosh past, height strip ticks. Chuck cheers at the side.
2. **Kick, Chuck.** Same. Jeff cheers.
3. **Upgrade pick.** Vertical split (green left, red right). Each half: three big icon cards, no text. Stick to highlight, A to pick; the item animates onto the character. Both pick at once; the round waits for the slower player with a gentle bounce, never a timer.
4. **Repeat.** Round counter is a stack of balls on the HUD, not a number. Balls return to the tee with a comedy drop from the sky.
5. **Space.** A ball crossing the space line ends that player's run: ball floats, victory dance, a satellite or alien waves. The other keeps kicking; the finished character cheers from a cloud. End card: both in space suits, confetti, restart.

**Catch-up:** a player two or more tiers behind gets only above-average cards on their next pick.

## Progression: the height ladder

Eight tiers, about one per round on a normal run. Sky colour steps per tier and is the main progress signal. Tiers are data (`data/tiers.tres`): threshold height, landmark scene, sky gradient, `tier_up` gag cue.

1. Backyard (fence, washing line) · 2. Rooftops (chimney, a startled cat) · 3. Treetops and birds · 4. Kite and hot-air balloon height · 5. Clouds (a plane drones past) · 6. Thin air (jet, a lost party balloon) · 7. Edge of space (aurora, a satellite) · 8. Space (stars, the Moon, an alien who waves).

Landmarks are generic, invented gags only. Kaden (2026-11-09): no personal info or real local places in any game, so there is no private content pack.

## Upgrades

Data, not code: one `UpgradeData` `.tres` per upgrade in `data/upgrades/`. Fields: `id` (snake_case, stable), `name` (release notes and end card only), `icon` (Texture2D, no text), `tier` (1 to 3: rounds 1-4, 5-8, 9+), `kind` (`normal|strong|joke|curse`), `power_mult` (float; curses < 1.0), `visual` (PackedScene attached to the character), `windup_anim` (StringName, optional), `kick_sfx` (StringName, optional), `scene_override` (PackedScene, for round-takeover curses like the frog), `description` (one line).

| Kind | Odds per card | Power | Examples |
| --- | --- | --- | --- |
| normal | 60 % | x1.6 to x1.9 | Big Boot, Spring Shoes, Rocket Boots, Super Strength, Running Start, Lucky Sock, Trampoline Tee, Helium Ball, Coach's Whistle, Giant Foot |
| strong | 20 % | x2.3 to x2.8 | Cannon Leg, Jetpack, Pogo Legs, Tornado Spin, Dad Strength, Moon Gravity (that kick only), Slingshot Buddy (the other character helps) |
| joke | 12 % | x1.0 to x1.3, very funny | Tiny Hat, Extra Shoes (now four), Confetti Kick, Balloon Animal Ball, Mustache, Honk Horn Shoes, Opera Kick |
| curse | 8 % | x0.1 to x0.3 + special scene | Kiss the Frog, Banana Peel, Sneeze, Shoelaces Tied, Too Much Lunch, Butterfly |

- Median 11 rounds to space; two strong picks in a row can do it in 7 or 8; three curses stretch to 14 or 15. After round 14 the pool is strong-only, so no run passes round 15.
- Every draw has at least one `normal` card. Curses are a choice and look tempting (sparkly frog).
- Upgrades stack visually: by round 10 the character is a walking pile of boots, hats and jetpacks.
- Some upgrades are plainly better, and the game doesn't hide it.
- `data/BALANCE.md` holds the target curve; Content updates it whenever odds or multipliers change.

## Camera

| Phase | Layout | Camera |
| --- | --- | --- |
| Approach and kick | Full screen | TV-sports framing: side-on 3D, slightly behind and above the kicker, tee and character in frame, the waiting character cheering at the edge |
| Flight | Full screen | Follows the ball up; zooms out as speed rises; landmarks pass; height strip on the right edge |
| Landing / stop | Full screen | Holds on the peak for a beat, a stamp shows the tier reached (icon), quick comedy drop back to the tee |
| Upgrade pick | Vertical split, green left, red right | Each half frames its character with three floating cards |
| Space | Full screen | Slow orbit around the floating ball and the celebrating character |

Height strip: vertical, landmark pictures, no numbers; the best-ever height per profile is a little flag on it.

## Art direction

**Kaden, 2026-11-09 (chat), supersedes the plan doc's low-poly/flat-shaded/outline section:** "a 3d style, Wii bowling inspired game. Let's get our own version of 'Miis' set up for the style ... use those Wii sports games as the visual reference and inspiration."

- Technique: clean, smooth-shaded 3D in a bright TV-sports look: soft sunlight, soft shadows, gentle rim light instead of outlines (the house style allows rim light), simple rounded shapes, squash-and-stretch on everything that moves.
- Characters: **Jarlings**, our own original avatar system (working name), built in `openjar-characters/avatar/`: big round heads with swappable face parts, simple bodies, mitten hands, chunky shoes. Jeff and Chuck are Jarlings in their costumes from their look sheets; generic Jarlings fill the crowd. Original designs only: no Nintendo assets, no shapes copied from Miis, no Nintendo names anywhere.
- Kicker animation: authored actions (idle, run, kick, cheer) with procedural wobble and per-upgrade overrides. The plan doc's ragdoll flail is optional polish, not v0.1.0.
- Palette: the Open Jar master palette Kaden picks (D36; **C Cool Arcade provisional**). The sky ramp must step clearly through the eight tiers. Nothing else in the scene is pure player green or player red.
- Reference feel: Wii Sports / Wii Sports Resort (look and TV-sports presentation), Kerbal Space Program (escalation), Katamari (joyful scale). Vibe only.
- Characters from the library: Jeff (P1), Chuck (P2), generic Jarlings (crowd). New characters proposed: none. The frog, the alien and the satellite are game content (a class of thing), not library characters.
- Props: tee, two balls with reacting faces, lawn chair, landmarks, upgrade attachments.
- Juice: screen shake scaled to power, dust puff, speed lines, star burst at tier boundaries, half-second slow-motion on the strongest kicks.
- Store art: grid (600x900) both characters mid-wind-up with a ball leaving frame; hero (920x430) the two balls in orbit with the planet below.

## Audio

Sound on every action. SFX synthesised locally until Soundbox is reachable; Chatterbox barks for Jeff and Chuck once D37 is approved and the voice service exists; music loop by the Audio lane (ElevenLabs only with Kaden's yes, it costs money).

| Cue | Plays when |
| --- | --- |
| `windup` | run-up starts (rising whistle, footsteps that match the silly run) |
| `kick_1..4` | kick lands, variant by power tier (thwack, cannon, sonic boom) |
| `whoosh` | ball in flight, pitch rises with speed |
| `tier_up` | ball crosses a tier (sparkle + landmark gag) |
| `land` | ball stops |
| `card_move`, `card_pick` | upgrade UI |
| `upgrade_on` | item attaches |
| `curse`, `frog` | curse chosen; frog round |
| `space` | ball reaches space |
| `cheer` | waiting character reacts (bark pack) |

Music: one upbeat loop that gains a layer per height tier and drops to a sparse pad in space.

## Technical plan

Godot 4.7.2 from `openjar-template`, 3D, Jolt physics, content in `.tres`. C# only if profiling demands it.

- Ball: `RigidBody3D`. Kick impulse = base × product of upgrade multipliers × run-up quality (0.8 to 1.2). Simulate the first seconds, then hand off to a scripted, deterministic arc once above the clouds so very high kicks stay stable.
- Kicker: `CharacterBody3D`, steering, auto-kick trigger (`Area3D` around the ball), wind-up state machine (`AnimationTree`), attach points for upgrade visuals, frog variant.
- Scenes: `scenes/main.tscn` (Systems), `scenes/levels/field.tscn` (Gameplay), `scenes/players/kicker.tscn` (Systems), `scenes/players/jeff.tscn` / `chuck.tscn` (Art, inherit kicker), `scenes/ball.tscn` (Gameplay), `scenes/levels/height_ladder.tscn` (Gameplay), `scenes/ui/upgrade_pick.tscn` (Systems structure, Art theme), `scenes/ui/hud.tscn` (Systems), `scenes/curses/frog.tscn` (Gameplay).
- Game-specific contract (goes in `docs/contracts.md`):

```gdscript
signal kick_started(player: int)
signal kicked(player: int, power: float)
signal ball_tier_reached(player: int, tier: int)
signal ball_stopped(player: int, height: float, tier: int)
signal upgrade_picked(player: int, upgrade_id: StringName)
signal reached_space(player: int)
func Run.power_of(player: int) -> float
func Run.upgrades_of(player: int) -> Array[UpgradeData]
```

- Save (per profile): best height, runs completed, upgrades ever seen (for the end card's collection).

## Lanes for this game

| Lane | Active | Definition of done for this game |
| --- | --- | --- |
| Systems | yes | Grey-box first, alone: two capsule kickers steer and auto-kick spheres, height counts, round loop, split-screen pick with three blank cards, every action beeps; then HUD, save, drop-in, `Run` autoload, contracts |
| Gameplay | yes | Field, tiers, flight hand-off, frog scene, camera phases, catch-up rule |
| Design / Art | yes | Jarling Jeff and Chuck in-game (from `openjar-characters`), props, landmarks, sky ramp, juice, upgrade visuals, store art |
| Content | yes | 40+ upgrades, `tiers.tres`, `BALANCE.md` hitting 10 to 12 rounds median |
| Audio | yes | All cues above, tiered music loop, barks once available |
| Reviewer | yes | Template checklist + this game's kid-design checks |

## First playable

Both characters complete a run to space in 10 to 12 rounds, the frog curse works, every action has a sound and a visual, nothing on the kid-design checklist is red. Art may be boxes. Tag `v0.1.0`.

### Kid-design checks specific to this game
- A player who only wiggles the stick still kicks every round.
- A curse is never the only choice; every draw has a normal card.
- No run lasts past round 15.
- The waiting player always has something to look at and something to do (their character cheers on a button press).
- The upgrade pick never times out.
- Catch-up keeps the two balls within two tiers after round 6.
- Height is shown with pictures, not numbers.
- The frog round reads as a joke: both characters laugh, upgrades return next round.

## Out of scope

Versus or scoring between players; aiming the kick (it always goes up); online, more than two players, custom characters; persistent upgrades across runs (every run starts wimpy, that's the joke).

## Playtest 2026-11-09 changes (Kaden; these supersede the sections above)

Source: `playtests/2026-11-09.md`.

- **Free movement (supersedes "Controls" steer row and the auto-approach in Pitch/Core loop):** "I really don't like that it forces you to the ball... I'd love to just be able to run around and then get to the ball when you're ready." The kicker runs freely on the field; the kick fires on its own when the player runs into their ball (still no kick button). The funny wind-up stays, starting when they reach the ball.
- **Menus and ready-up (every game, from the template):** a main menu with a way back to the launcher, a pause menu with "back to the launcher", and a start screen where both players ready up before round 1.
- **Upgrades change the play, not just the number (supersedes "power_mult only"):** "Like some shoes might make you run faster, or have some impact on the gameplay." Each upgrade has a visible effect (run speed, run-up, jump, kick style, ball behaviour) that explains the extra height.
- **Gear is worn, not piled (supersedes "Upgrades stack visually: a walking pile"):** one item per body slot (head, face, back, hands, knees, feet, waist), fitted to the Jarling and following its animation. A new item in a slot replaces the old one; gear you already wear isn't offered again. Built as a shared equipment system in `openjar-characters`.
- **Upgrade art gets a full redo** (card icons and gear): "The design of the upgrades is really poor though."

## Playtest 2026-11-09 #2 changes (Kaden; these supersede the sections above)

Source: `playtests/2026-11-09-2.md`.

- **A long run-up:** the ball sits "way further away", so the run to it lasts long enough to enjoy the upgrade effects (bouncing, trails, jets). The camera follows the run.
- **Curses are not cards you pick** (supersedes "curse 8 % per card, a choice that looks tempting"): curse cards never appear in the pick. Instead, a picked card has a chance to turn out to be a curse (a reveal: the card flips to the curse). It should average **two curses per run**.
- **Banana peel:** the peel lies further out from the ball; you visibly slip, slide/tumble into the ball, and it barely goes anywhere.
- **The sky is busier and the ball interacts with it:** more objects per tier, and the ball pops balloons, bonks planes, scatters birds, bounces off things, each with a sound and a little reaction.
- **The other player is a bystander, not benched:** during the other's turn they run around with all their upgrades and effects, but can't kick any ball.
- **The crowd reacts:** spectators cheer and celebrate a good kick (bigger kick, bigger celebration).
- **Camera on the kicker only** (Kaden, after playtest #2): the camera frames the active kicker and their ball; the bystander may run off-screen (a colour arrow at the edge shows where).
- **The camera follows big jumps** (rocket boots, jetpack) up and settles back down.
- **No accidental jump-overs:** a low hop over your own ball snaps you in front of it and kicks; a big jump far above it still flies over.

## Playtest 2026-11-10 changes (Kaden; these supersede the sections above)

Notes quoted in `playtests/2026-11-10.md`.

1. **Every curse is obvious** (Kaden: "Curses should be obvious why they're impacting you. Like I got a butterfly curse, and I had no idea what happened. Or why it would cause me to fail."). For every curse (Kiss the Frog, Banana Peel, Sneeze, Shoelaces Tied, Too Much Lunch, Butterfly and any others):
   - **Reveal shows what it will do:** when the picked card flips to a curse, a 2-3 s picture-only demo plays on the card or over the character (the butterflies swarm the ball and nudge it off course; the laces knot and he trips), with its own sound.
   - **The effect is visible at the moment it bites:** during the run-up and kick, the cause is on screen and the camera gives it a beat (butterflies land on the ball and pull it sideways; the banana peel is right there under the foot).
   - **A "that's why" beat after the kick:** a short picture callback (the curse icon pops over the ball's landing spot with the cause animation) so a weak kick is never a mystery.
   - The cursed player wears a small curse icon above them until the cursed kick is done.
2. **New curse odds** (supersedes "average two curses per run"; Kaden: "a 40% chance from the start to get curse 1. 20% after that to get curse 2. Then 0% chance after that."). Gary's reading: per player, each picked card has a **40%** chance to flip into a curse until that player's first curse, then **20%** per pick until their second, then **0%**. So curses arrive early (not in the last rounds) and never more than two per player per run. Kept in data (`data/curse_odds.tres` or the tier set) so it can be tuned.
3. **Dragon cameo** (Kaden: "get the dragon cameo flying in some layer"): The Hill's Dragon (library resident, `openjar-characters` v0.5.1, giant body) glides through the **Clouds** tier (tier 5), big, sleepy and friendly. The ball can bonk her: a happy sleepy roll, a puff of cloud, a rumble-purr, maybe a tiny height boost. Not every run: a tuned chance, so seeing her is a treat. She is not a playable character and never blocks a run.

## Decisions made without Kaden

- 2026-11-09: each player draws their own three cards (the plan's proposal), not a shared draw. It keeps the split screen independent and lets catch-up apply per player.
- 2026-11-09: the avatar system's working name is "Jarlings". Rename any time.
- 2026-11-09: authored animations plus procedural wobble for the kicker in v0.1.0; physics ragdoll flail is later polish if it's still wanted. Fits the clean TV-sports look and keeps every run-up readable.
- 2026-11-09: generic landmarks only in this public repo (no real places).
- 2026-11-09: the repo is pushed from the producer's local copy of the template (shared history), so Kaden creates it empty instead of with "Use this template".

- 2026-11-09 (Systems grey-box): Systems wrote **placeholders** in other lanes' folders so the grey-box runs: `scenes/levels/field.tscn`, `scenes/levels/height_ladder.tscn`, `scenes/ball.tscn`, `scenes/curses/frog.tscn`, `scripts/gameplay/` (`upgrade_data.gd`, `tier_data.gd`, `tier_set.gd`, `camera_rig.gd`, `height_ladder.gd`), `data/tiers.tres`, `data/upgrades/*.tres` (16), `assets/audio/sfx/*.ogg` (beeps). Each is marked `PLACEHOLDER (systems grey-box)` (a `#` comment in scripts, `metadata/_placeholder` in scenes, `data/PLACEHOLDER.md` for `.tres`). The owning lanes replace them; the APIs are in `docs/contracts.md`.
- 2026-11-09 (Systems): a curse acts on the **next kick only** and never joins the upgrade list; the frog (a curse with `scene_override`) also switches every upgrade off for that kick. A curse therefore costs about one round, which is what makes "three curses stretch to 14 or 15" true.
- 2026-11-09 (Systems): "no run passes round 15" is guaranteed, not just likely: picks after round 14 are strong-only (as written) **and** the round-15 kick always peaks just over the space line.
- 2026-11-09 (Systems): catch-up ("only above-average cards") = only `normal` / `strong` cards with `power_mult >= 1.7`, 40 % strong. It compares the tiers of the two balls' last kicks; a ball already in space counts as tier 8.
- 2026-11-09 (Systems): an upgrade's `tier` (1 to 3) means "available from that band on" (tier <= band), falling back to any tier if a kind has none in the band yet.
- 2026-11-09 (Systems): height is ballistic, `h = power^2 / 2g`, base power 8 (about 3 m on round 1), space line at 100 km. Above 20 m the scene is log-compressed so a 100 km kick is a few hundred metres of world and stays stable.
- 2026-11-09 (Systems): P2 joining mid-run starts from zero upgrades at the next round; the catch-up rule pulls P2 up fast. A pad that drops out during the pick no longer blocks it.
- 2026-11-09 (Systems): the first Select press shows a small spinning marker and beeps; a second within 1 s restarts. Keyboard keys join players for development, and `-- --demo` plays the game by itself.
- 2026-11-09 (Systems): **solo mode, playtest only** (Kaden asked so he can test alone). Hold Select + Start together for 2 s on any pad (or launch with `-- --solo`) and that one pad plays both Jeff and Chuck; the same hold turns it off and Chuck goes back to normal drop-in. The pad steers whoever's kick it is, and in the pick it chooses for Jeff then Chuck (B goes back to Jeff's card). A small two-heads icon sits top-left while it is on. Never on by default, and a short or one-button press does nothing, so a kid can't trip it.
- 2026-11-10 (Showtime menus): the lobby backdrop is `SCREEN` (the live field main.tscn already draws, blurred), not `SCENE` (a second field.tscn in a SubViewport). A second field would run its own crowd, juice and shot-director scripts on the run's signals (double cheers and confetti) and cost a second world.
- 2026-11-10: the podium Jeff and Chuck are the field's own rigged Jarlings (same rig, Chuck's hat) wearing what they will wear on the field: nothing at the start of a run, or the `--gear` / `--gear2` items. Readied, they cheer until un-readied.
- 2026-11-10: the round card says "ROUND 1" with "JEFF KICKS FIRST" (or "CHUCK KICKS FIRST" when Chuck starts alone) in the kicker's colour.
- 2026-11-10: the upgrade pick and the end card keep their own look. They never used the kit's menu bars, so the kit did not restyle them; frames show both still read with big icons and no text. Left alone on playtest night rather than restyled.
- 2026-11-10: the kit saves "Solo playtest" when it changes, including Select+Start. Kept as the kit designed it (it shows in Settings), flagged for playtest #3.
- 2026-11-10 (Systems, chooser adoption): each player kicks as their **Roster pick** (the start-menu chooser, shared with the launcher); Jeff and Chuck are only the defaults. The slot keeps the player colour (rings, arrows, HUD, round card); names come from the pick ("<NAME> KICKS FIRST"). A character's own wind-up voice plays if recorded, else the generic wind-up; never another character's. The frog wears Jeff's hood / Chuck's hat only on Jeff / Chuck; anyone else is a plain frog in the player tint.
- 2026-11-10 (plan gaps): the height strip's pictures are drawn in code (`scenes/ui/tier_icon.gd`: fence, house + cat, tree + bird, hot-air balloon, plane + cloud, jet + party balloon, satellite + aurora, moon + alien) on the tier's sky colour, not painted icons, so they stay crisp at 90 px and on the peak stamp; Art can swap them for renders any time. The peak stamp is that picture on a badge in the kicker's colour.
- 2026-11-10: the best-ever flag stands inside the strip on a white line (the ball markers sit either side); a ball that beats it pops it with a sparkle and carries it up until it stops.
- 2026-11-10: "strongest kicks" for the half-second slow motion = a kick peaking in tier 7 or 8 (the sonic-boom kick), never a curse or the frog. 0.25x speed for 0.5 real seconds; sound isn't slowed. (gap-close-4: 0.4x, Kaden's audit asked for about 0.4.)
- 2026-11-10: the music layers are synthesised in-repo on `field_loop.ogg`'s measured grid (120 BPM, not the 112 its prompt asked for; C major): shaker at tiers 3-4, kick + claps at 5-6, bell arpeggio on the loop's chords + a slide-whistle "whee" at 7-8. No ElevenLabs spend. They fade out at every kick and back in as the ball climbs.
- 2026-11-10: the space moment is ball first (2 s orbit, a little saucer pops in and its alien waves), then the kicker's victory dance on the field (2 s orbit round him with the crowd); he keeps dancing on his cloud.
- 2026-11-10: the end card shows the run's picks per player (a shelf each, P1 left, P2 right) and, across the top, the profile's whole collection: every card, the ones ever drawn in colour, the rest dark silhouettes. A revealed hidden curse counts as seen. `runs_completed` is saved but still not shown.
- 2026-11-10: Kiss the Frog gets the plan's frog scene at the pick: after the card flips, a little frog hops in, kisses him and poofs. The frog round is still his next kick.
- 2026-11-10 (gap-close-4): the music grows over the run, not just inside one flight: between kicks it keeps one layer less than the run's highest tier, and each flight climbs on top of that.
- 2026-11-10 (gap-close-4): besides the gold best-ever flag, each player has a pennant in their colour at their highest peak this session (since the game started; not saved): P1 left of the strip, P2 right.
- 2026-11-10 (gap-close-4): a waiting player's cheer gets a few fans hopping and clapping back. Crowd feedback only.
- 2026-11-10: the lawn chair stays as scenery and as the seat of a P2 who hasn't joined; Kaden: "the Lawn Chair obviously isn't relevant since the other player can now run around" (PLAN-STATUS P-05 superseded).

## Open questions

- Chuck's personality and both voices: D37 on Docket.
- Palette: D36 (C provisional).
- The Jarling style itself: Kaden approves from the style mock (Docket, once the renders are in).
- Name: Spaceballs is fine while private; pick another if it ever goes public.
