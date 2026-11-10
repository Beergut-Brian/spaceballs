# Kid-design checklist

Every PR that touches gameplay or UI is checked against this list by the Reviewer lane.
Copy it into the PR description and tick what applies. An unticked item that applies blocks merge.

## Menus are for grown-ups

The kid plays; the grown-up drives the menus. The start screen (lobby), pause, settings, the leave
question and any other front-end screen are designed for the adult holding the pad: text labels,
normal menu conventions (a focused item, A selects, B backs out, a confirm before leaving) and a
polished look (`docs/ui.md`). Text is fine there. The rules below still apply to **gameplay**:
everything that happens once the round starts. The menus still follow: a sound and a visual on
every input, P1 green / P2 red, readable from the sofa, Pause and Restart reachable in one press.

- [ ] No reading required anywhere in gameplay. (Menus may use text: see above.)
- [ ] At most three buttons matter: move, action, maybe jump. Everything else is ignored or does something harmless and funny.
- [ ] No fail state that ends the fun. Losing is a silly animation and an instant retry, never a game-over screen.
- [ ] Round or loop length 2 to 5 minutes. A natural stopping point every few minutes.
- [ ] Co-op never leaves one player stuck: rubber-banding, a camera that never loses a player, respawn next to the other player.
- [ ] Big hitboxes, forgiving timing. If it looks like it should have hit, it hit.
- [ ] Instant feedback on every input: a sound and a visual every time a button does something.
- [ ] Drop-in, drop-out for Player 2 at any time without going through a menu.
- [ ] Pause and restart reachable from the controller in one press; neither asks a question.
- [ ] No timers that create pressure. Counting up is fine; counting down is not.
- [ ] Nothing scary. Enemies are goofy, defeat is a pop or a boing, no blood, no screaming.
- [ ] Player 1 is green, Player 2 is red, everywhere.
- [ ] Runs at 60 fps at 1080p on a GTX 1060.
- [ ] Cold start to playing in under 10 seconds.
- [ ] Saves at every natural stopping point; a crash loses at most one round.
