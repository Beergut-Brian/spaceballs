# Spaceballs

> Design doc and source of truth for this game. Hermes owns this file. Lanes read it before
> starting and quote it in PRs. If the game drifts from this doc, fix the doc or fix the game.

## Pitch

One or two sentences. What is it, why is it funny, why will a 5-year-old want to play it again.

## Players

- 2 players, co-op, couch, one TV.
- P1 (green): <character or "any universal character">
- P2 (red): <character or "any universal character">
- Drop-in / drop-out for P2 at any time.

## Controls

Three buttons matter at most. Everything else does something harmless and funny or nothing.

| Input | Does |
| --- | --- |
| Left stick | Move |
| A (south) | Action |
| B (east) | Jump / secondary (or unused) |
| Start | Pause |
| Select | Restart round |

## Core loop

One paragraph. What happens in a round, how long a round lasts (target: 2 to 5 minutes),
what the natural stopping point is.

## Progression

How the game changes over time, if at all. Rounds, tiers, upgrades, growth. If the game is a
pure sandbox, say so and delete the rest of this section.

## Camera

Shared full-screen, split, or mixed. State when it switches and why.

## Art direction

- Technique: <pixel art 16 to 32 px tiles / low-poly flat-shaded 3D / flat vector>
- Palette: <name of the chosen palette file in `art/`>
- Reference feel: <two or three existing games or shows, for vibe only>
- Characters from the library: <list>
- New characters proposed: <list, or none>

## Audio

- Music: <one loop, mood>
- Signature sounds: <the three or four cues that define the game's feel>
- Voices: <which library characters speak, which stock barks are used>

## Lanes for this game

| Lane | Active | Definition of done for this game |
| --- | --- | --- |
| Systems | yes | |
| Gameplay | yes | |
| Design / Art | yes | |
| Content | | |
| Audio | yes | |
| Reviewer | yes | |

## First playable

The smallest build Kaden should sit down and play with his son. Usually: two players move,
one interaction works, a round ends and restarts, one sound and one visual on every action.
Tag it `v0.1.0`.

## Out of scope

Things that sound fun and are not in this game. Keep the list; it stops scope creep in PRs.

## Decisions made without Kaden

Dated. Hermes logs choices here that did not need Kaden. He can override any of them later.

- YYYY-MM-DD: 

## Open questions

- 
