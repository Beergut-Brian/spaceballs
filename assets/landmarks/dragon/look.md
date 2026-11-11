# The Dragon: look

## Must survive every art style
- A giant round beanbag shape: never scary.
- No visible teeth, no sharp claws, no fire.
- Sleepy half-closed eyes, pink cheeks, two rounded cream horn nubs.
- Wings far too small, stubby arms, big round feet.
- A thick tail curling round to the front, with a soft peach puff tip.
- Round cream belly with soft stripes.

## Silhouette
A big round head on a bigger round body, with tiny wings and a curled tail. Identifiable in outline alone.

## Face
Sleepy (neutral), yawn, happy, sorry, hopeful. Her mouth is never open wide enough to show teeth, even in a yawn.

## Fixed colours
- Body: #A88BE0, shade #8C6FC8
- Belly and horns: #FFF0C9
- Wings, spines and tail puff: #FFB37A
- Cheeks: #F7A6C0
- Smoke rings: #C9C4D4
- Outline in pixel art: #2A1E2C

## Signature props
Smoke rings, sometimes heart-shaped. Gnome lanterns, once they have hung them on her.

## Jarling 3D
Status of the 3D form: **approved (Kaden 2026-11-10, D49 a with the Gnome whistle fix)**: 3.5 players tall (`body.height` 3.5, about 3.85 m), not 6. The 3D master is the source of truth for silhouette, proportions and colours; the pixel form is traced from it (3D-first, `tools/pixel/retrace.sh`).
- **Body type: `giant`** (`avatar/kit/body_giant.py`): a huge sitting beanbag creature, reusable for later landmark-sized creatures. This replaces the earlier note that she would be a bespoke prop: Kaden's 2026-11-10 direction asks for a named body type. `jarling.json`: `body.type` giant, `body.height` 3.5 (3.5 standard Jarlings, about 3.85 m to the top of the horn nubs; Kaden 2026-11-10: match the approved sprite, 3.5 players tall, not 6).
- Shape: a big round head sunk into a bigger round body, stubby arms with mitten hands, big round feet out front with cream sole pads, tiny peach wings high on the back, peach spines down the back and tail, a thick tail curling round to the front with the peach puff tip, round cream belly with soft stripes, two round cream horn nubs. No teeth, no claws, no fire.
- Face (atlas, six cells): `sleepy` (resting, heavy `#8C6FC8` lids), `yawn` (eyes shut, small round mouth), `happy`, `sorry`, `hopeful`, plus `asleep` (closed lines, for the `sleep` action).
- Bones: the shared eleven plus `tail.1` > `tail.2` > `tail.3` and `wing.L/R`. Actions, all slow: `idle`, `run` (a slow waddle in place), `cheer`, `yawn`, `wave` (the signature slow wave), `flap` (the tiny wings; nothing happens), `sleep`.
- Equipment slots: head, face, back, waist, both hands, both feet, with the fit scale baked in, so the same hat that fits Jeff comes out dragon-sized. No knees.
- Files: `jarling.json`, `refs/jarling/dragon.glb`, `dragon_turnaround.png`, `dragon_expressions.png`, `dragon_yawn.png`, `dragon_side.png`, `dragon_side_sprite.png`.
- Changes from the 2D look and colours not on the fixed list: the muzzle is a shaped bump in the body colour (the sprite tints it lighter); the belly stripes use the sprite's `#F0DAA6`. Size: the 3D master is 3.5 Jarlings tall, the same as the approved Hill sprite (112 px); the side-view sprite sheet is at that scale (96 x 112 sprite px). Not built: the curled-asleep pose (the `sleep` action is a sitting nap), smoke rings and lanterns (game effects and props), the "in pieces on the elevator" pose.

## 2D pixel (The Hill)
- **3D-first redraw, 2026-11-10** (Kaden: the 3D master is the source of truth). Traced from the 3D master: `avatar/kit/render_trace.py` (flat colour, orthographic, 512 px per 1.2 m) -> `tools/pixel/trace3d.py` (palette-snapped, 32 px = 1.2 m) -> hand-clean passes in `tools/pixel/residents.py`; 1 px #2A1E2C outline, fixed colours only. Re-run: `tools/pixel/retrace.sh`. Read check at game size (x2): `characters/read_check.png`.
- Sitting awake: 112 px tall (3.5 players) on a 128 x 112 frame, with a 1 px #2A1E2C outline. Yawn: traced from the 3D `yawn` and fitted to the same frame.
- Traced: everything in sit and yawn (body, belly stripes, horns, wings, tail puff, the sleepy face). Hand-cleaned: the eyes and mouth for happy, sorry, hopeful.
- Curled asleep (about 160 x 72 px): still hand-drawn, because the 3D master has no curled pose (its `sleep` is a sitting nap).
- Must still read at 16 px: the round purple mass, the cream belly and the peach tail puff.
- Poses: asleep (curled), awake and sitting, yawn. Views: front, side, back (sitting).
- Expressions: sleepy (neutral), yawn, happy, sorry, hopeful.

## Refs
`refs/look_sheet.png` (turnaround, key poses, expressions, arc pictograms) and `characters/residents_lineup.png` for scale.
