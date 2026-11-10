#!/usr/bin/env python3
"""Writes data/upgrades/<id>.tres from upgrades_table.py (run from the repo root).
Icon: assets/sprites/upgrades/<id>.png; visual: scenes/upgrades/<id>.tscn; both only if present.
Deletes .tres files whose id is no longer in the table."""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from upgrades_table import UPGRADES, KIND_RANGES  # noqa: E402

OUT = "data/upgrades"
OVERRIDES = {"kiss_the_frog": "res://scenes/curses/frog.tscn"}


def esc(s):
    return s.replace("\\", "\\\\").replace('"', '\\"')


def write(row):
    uid, name, kind, tier, mult, desc, windup, sfx = row
    lo, hi = KIND_RANGES[kind]
    assert lo <= mult <= hi, row
    ext, fields = [], []
    ext.append(("Script", "res://scripts/gameplay/upgrade_data.gd"))
    icon = f"res://assets/sprites/upgrades/{uid}.png"
    visual = f"res://scenes/upgrades/{uid}.tscn"
    has_icon = os.path.exists(icon[6:])
    has_visual = os.path.exists(visual[6:])
    if has_icon:
        ext.append(("Texture2D", icon))
    if has_visual:
        ext.append(("PackedScene", visual))
    if uid in OVERRIDES:
        ext.append(("PackedScene", OVERRIDES[uid]))
    lines = ['[gd_resource type="Resource" script_class="UpgradeData" format=3]', ""]
    for i, (t, p) in enumerate(ext, 1):
        lines.append(f'[ext_resource type="{t}" path="{p}" id="{i}"]')
    lines += ["", "[resource]", 'script = ExtResource("1")', f'id = &"{uid}"', f'name = "{esc(name)}"']
    n = 2
    if has_icon:
        lines.append(f'icon = ExtResource("{n}")')
        n += 1
    lines.append(f"tier = {tier}")
    lines.append(f'kind = "{kind}"')
    lines.append(f"power_mult = {mult}")
    if has_visual:
        lines.append(f'visual = ExtResource("{n}")')
        n += 1
    if windup:
        lines.append(f'windup_anim = &"{windup}"')
    if sfx:
        lines.append(f'kick_sfx = &"{sfx}"')
    if uid in OVERRIDES:
        lines.append(f'scene_override = ExtResource("{n}")')
    lines.append(f'description = "{esc(desc)}"')
    with open(f"{OUT}/{uid}.tres", "w") as f:
        f.write("\n".join(lines) + "\n")
    return has_icon, has_visual


def main():
    ids = {r[0] for r in UPGRADES}
    assert len(ids) == len(UPGRADES), "duplicate id"
    for f in os.listdir(OUT):
        if f.endswith(".tres") and f[:-5] not in ids:
            os.remove(f"{OUT}/{f}")
            print("removed", f)
    missing = []
    for r in UPGRADES:
        icon, vis = write(r)
        if not icon:
            missing.append(r[0] + ":icon")
        if not vis and r[2] != "curse":
            missing.append(r[0] + ":visual")
    print(f"wrote {len(UPGRADES)} upgrades; missing: {', '.join(missing) or 'none'}")


if __name__ == "__main__":
    main()
