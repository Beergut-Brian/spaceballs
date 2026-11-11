## Test and scripted runs never touch the real per-install files: the shared picks file
## (~/.local/share/openjar/players.json, read by the launcher and every Open Jar game) and
## user://settings.json. Save and Roster ask this at boot and point their paths at
## user://sandbox/ instead. Not an autoload: static helpers.
## A sandboxed run: the gdUnit4 runner, or any scripted / screenshot flag (--demo, --shots=,
## --shot-dir=, --screenshot-after=, --ui=, --timescale=, --log-phases), or --sandbox.
class_name RunSandbox
extends RefCounted

const DIR := "user://sandbox"
const PICKS := DIR + "/players.json"
const SETTINGS := DIR + "/settings.json"
const FLAGS := ["--sandbox", "--demo", "--shots=", "--shot-dir=", "--screenshot-after=", "--ui=",
		"--timescale=", "--log-phases"]


## True when `args` (default: the real command line) are a test or scripted run.
static func active(args: PackedStringArray = PackedStringArray()) -> bool:
	if args.is_empty():
		args = OS.get_cmdline_args() + OS.get_cmdline_user_args()
	for a in args:
		if a.contains("GdUnitCmdTool") or a.contains("gdUnit4/bin"):
			return true
		for f in FLAGS:
			if a == f or (f.ends_with("=") and a.begins_with(f)):
				return true
	return false
