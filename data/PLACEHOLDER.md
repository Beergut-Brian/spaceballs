# PLACEHOLDER (systems grey-box)

Everything in `data/` right now is grey-box placeholder from the Systems lane (2026-11-09),
written by `scripts/tools/make_placeholder_data.gd`. Content owns `data/` and replaces it:

- `tiers.tres`: a `TierSet` of 8 `TierData` (see `docs/contracts.md`). Thresholds in metres:
  0, 4, 14, 55, 350, 2500, 18000, 100000 (space line). Icons are flat colour squares.
- `upgrades/*.tres`: 16 `UpgradeData` (6 normal, 4 strong, 3 joke, 3 curse) at mid-range
  multipliers from GAME.md. Icons are flat colour squares; no visuals yet.

Balance check: `tests/test_simulation.gd` plays 400 runs per case through the real `Run`
and asserts median 10 to 12 rounds and nothing past round 15. Re-run it after every change.
