# Asset credits

| File | Tool / source | Prompt or notes | License |
| --- | --- | --- | --- |
| refs/look_sheet.png | Python 3 + Pillow, `tools/pixel/make_sheets.py` (drawn in code, no external assets, no AI image model) | look sheet (approved by Kaden 2026-11-09, D46 a): turnaround, key poses, expressions, arc pictograms | Original work, Open Jar Games |
| `characters/residents_lineup.png` | Python 3 + Pillow, `tools/pixel/make_sheets.py` (drawn in code, no external assets, no AI image model) | lineup for scale: Jeff and Chuck pixel forms plus the four Hill residents | Original work, Open Jar Games |
| refs/jarling/dragon.glb | Blender 5.2.3, `avatar/kit/build_jarling.py` with the `giant` body type (`avatar/kit/body_giant.py`), procedural, no external assets, no AI image model | 3D master from `jarling.json`: ~3.85 m sitting giant (3.5 Jarlings), rig, 7 actions, 8 slots, 6-expression face atlas | Original work, Open Jar Games |
| refs/jarling/dragon_turnaround.png | Blender 5.2.3 Cycles, `avatar/kit/render_refs.py` + `label_sheet.py` | turnaround of the 3D master: front, 3/4, side, back | Original work, Open Jar Games |
| refs/jarling/dragon_expressions.png | Blender 5.2.3 Cycles, `avatar/kit/render_refs.py` + `label_sheet.py` | sleepy, yawn, happy, sorry, hopeful, asleep | Original work, Open Jar Games |
| refs/jarling/dragon_yawn.png | Blender 5.2.3 Cycles, `avatar/kit/render_refs.py` | ref action: yawn at its peak, expression yawn | Original work, Open Jar Games |
| refs/jarling/dragon_side.png | Blender 5.2.3 Cycles, `avatar/kit/render_refs.py` | orthographic side view, 512 px per 1.2 m, tracing base for 2D | Original work, Open Jar Games |
| refs/jarling/dragon_side_sprite.png | Python 3 + Pillow, `avatar/kit/sprite_side.py` | side view at The Hill's sprite scale (tracing base, not the sprite) | Original work, Open Jar Games |
| `characters/residents_3d_lineup.png` | Blender 5.2.3 Cycles (CPU) via `avatar/kit/render_residents.py --only lineup` (procedural Jarling kit, no external assets, no AI image model) | Jeff, Chuck and the four Hill residents in 3D at true relative scale on one ground line (3D forms approved 2026-11-10, D49 a) | Original work, Open Jar Games |
| `characters/residents_3d_compare.png` | `avatar/kit/render_residents.py --only fronts` + Pillow `avatar/kit/compare_sheet.py` | each resident's 3D master (front, idle) beside its 3D-first pixel redraw from `tools/pixel/residents.py` | Original work, Open Jar Games |
