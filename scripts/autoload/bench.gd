## Built-in benchmark: `game -- --bench [--graphics=low|high] [--bench-secs=60] [--bench-warmup=3]`.
## Plays the fixed demo route (both players as bots, seed BENCH_SEED: kicks, flights, the
## split-screen card picks, a new run after the end card) for `secs` after `warmup`, prints a
## window line every 5 s and one final line, then quits:
##   BENCH t=5 avg=58.3 low1=41.2 ft_avg=17.15ms ft_max=31.02ms
##   BENCH avg=57.9 low1=39.8 ft_avg=17.27ms ft_max=48.10ms frames=3474 secs=60 tier=low adapter="..."
## avg = frames / seconds; low1 = 1% low (fps of the mean of the slowest 1% of frame times).
## A scripted run: RunSandbox keeps it off the shared picks file and settings. Added by Graphics.
class_name Bench
extends Node

const BENCH_SEED := 20261114
const WINDOW := 5.0

var secs := 60.0
var warmup := 3.0
## Tests swap this so the bench "quits" without ending the test run.
var quit_fn: Callable = func() -> void: Game.quit()
## Every line printed (tests read them).
var lines: PackedStringArray = []
var done := false

var _clock := 0.0
var _all: PackedFloat32Array = []
var _win: PackedFloat32Array = []
var _next_window := WINDOW
var _last_us := 0


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--bench-secs="):
			secs = maxf(1.0, float(a.trim_prefix("--bench-secs=")))
		elif a.begins_with("--bench-warmup="):
			warmup = maxf(0.0, float(a.trim_prefix("--bench-warmup=")))


func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = -1000
	# Before main.tscn's _ready: it reads Game.demo and starts a two-player bot run.
	Game.demo = true
	Run.demo = true
	seed(BENCH_SEED)
	Engine.time_scale = 1.0


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	if _last_us == 0:
		_last_us = now
		return
	step((now - _last_us) / 1000.0)
	_last_us = now


## One frame of `ms` real milliseconds (tests feed these by hand).
func step(ms: float) -> void:
	if done:
		return
	_clock += ms / 1000.0
	if _clock < warmup:
		return
	_all.append(ms)
	_win.append(ms)
	var t := _clock - warmup
	if t >= _next_window:
		_say("BENCH t=%d %s" % [roundi(_next_window), stats(_win)])
		_win.clear()
		_next_window += WINDOW
	if t >= secs:
		done = true
		_say("BENCH %s frames=%d secs=%d tier=%s adapter=\"%s\"" % [stats(_all), _all.size(),
				roundi(secs), Graphics.tier, Graphics.adapter])
		quit_fn.call()


## "avg=… low1=… ft_avg=…ms ft_max=…ms" for a list of frame times in ms.
static func stats(ms: PackedFloat32Array) -> String:
	if ms.is_empty():
		return "avg=0.0 low1=0.0 ft_avg=0.00ms ft_max=0.00ms"
	var total := 0.0
	for m in ms:
		total += m
	var sorted := ms.duplicate()
	sorted.sort()
	var n := maxi(1, ceili(sorted.size() * 0.01))
	var worst := 0.0
	for i in n:
		worst += sorted[sorted.size() - 1 - i]
	worst /= n
	var avg := 1000.0 * ms.size() / maxf(total, 0.001)
	return "avg=%.1f low1=%.1f ft_avg=%.2fms ft_max=%.2fms" % [avg, 1000.0 / maxf(worst, 0.001),
			total / ms.size(), sorted[sorted.size() - 1]]


func _say(line: String) -> void:
	lines.append(line)
	print(line)
