# Palette

`cool_arcade.json` / `.gpl`: the Open Jar master palette candidate **C, Cool Arcade**, copied from
`openjar-launcher/art/palettes/` (generated there by `make_palettes.py`). Provisional until Kaden
picks (D36). Spaceballs uses its five sky colours for the eight-tier sky ramp (`data/tiers.tres`,
blended by `art/scripts/sky_ramp.gd`) and its accents for props, landmarks and juice
(`art/tools/build_scenes.gd` constants). Player green `#3CC24A` and red `#E4393C` appear only on
Jeff, Chuck, their balls, their ground rings and the frog's hood / hat.

If D36 picks another palette, swap the constants at the top of `art/tools/build_scenes.gd` and the
sky gradients in `data/tiers.tres`, then re-run `godot --headless --path . -s art/tools/build_scenes.gd`.
