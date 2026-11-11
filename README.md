# Spaceballs (Open Jar Games #1)

Two goofballs each have a ball and one goal: kick it into space. Run up to your ball and your
character winds up like a lunatic and boots it, all by himself. It goes nowhere. Then you each pick a
ridiculous upgrade (rocket boots, a cannon for a leg, a jetpack) and kick again, higher. About ten to
twelve rounds later your ball is in orbit. Co-op, not versus: both balls climb the same sky.
Made for a grown-up and a five-year-old on the living-room TV with two pads.

## How to play

1. **Start screen.** Each player presses any button on their pad to join (first pad is green P1,
   the second red P2). Left / right on your podium picks who you play as (each says their catchphrase);
   **A** readies you. Both ready starts the run; **hold A** to start alone. The door icon goes back
   to the launcher.
2. **Your kick.** Run around with the left stick. Run into your ball and you kick it, no button needed.
   The camera follows it up past the rooftops, kites, clouds and planes. **B** hops, **A** shouts.
   While the other player kicks, you can run around too (you just can't kick).
3. **Pick an upgrade.** The screen splits, green left, red right. Stick to choose one of three cards,
   **A** to pick. Your character wears it from the next kick. Sometimes a card flips into a curse
   (a frog kiss, a banana peel, butterflies...): it spoils just your next kick, then it's gone.
4. **Space.** A ball over the space line is done: it orbits, a little alien waves, and you dance on a
   cloud while the other player keeps kicking. The end card shows everyone's picks; **A** plays again.

| Pad | Does |
| --- | --- |
| Left stick | Run / choose |
| A | Ready, pick a card, shout |
| B | Hop, back |
| Start | Pause (resume, settings, back to the launcher) |
| Select twice | Restart the run |
| Select + Start held 2 s | Solo playtest: one pad plays both players (again to turn off) |

A second pad can join or leave at any time; a new player gets a ball from the next round.

## Run, test, export

```
godot --path .                                                              # play
godot --path . -- --demo                                                    # plays itself
godot --path . -- --solo                                                    # one pad plays both
godot --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd -a tests  # tests
godot --headless --path . --export-release "Linux" build/game.x86_64       # export
```

Releases are built by `.github/workflows/release.yml` on a `v*` tag: tests, export, a smoke boot of
the binary, the launcher manifest (`openjar.json`, store art and `store/jar.glb`) and a zip on the
GitHub Release. The version label on the start screen comes from that tag (`data/build.json`);
a local build says "dev".

## Where things are

`GAME.md` is the design doc (playtest sections supersede older text), `PLAN-STATUS.md` tracks every
item from the brief and the playtests, `docs/launch-checklist.md` is the release checklist, and
`CLAUDE.md` holds the rules for the agent lanes. Asset credits: `assets/CREDITS.md`.
