## Hidden-curse odds (playtest 2026-11-10 #2, designer: "a 40% chance from the start to get curse 1.
## 20% after that to get curse 2. Then 0% chance after that."). Per player: each picked card flips
## into a curse with `by_curses_so_far[n]`, n = that player's curses this run; past the end it is 0.
## Data: data/curse_odds.tres (tune it there). Run loads it; tests/test_curse_odds.gd proves it.
class_name CurseOdds
extends Resource

## Chance per pick, indexed by how many curses the player already had this run.
@export var by_curses_so_far: PackedFloat32Array = PackedFloat32Array([0.4, 0.2])
## The first pick that may flip: after this round (1 = the very first pick).
@export var from_round: int = 1


func chance(so_far: int) -> float:
	return by_curses_so_far[so_far] if so_far >= 0 and so_far < by_curses_so_far.size() else 0.0


## Most curses a player can get in a run (the first zero ends it).
func max_curses() -> int:
	for i in by_curses_so_far.size():
		if by_curses_so_far[i] <= 0.0:
			return i
	return by_curses_so_far.size()
