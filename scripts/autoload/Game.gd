## Session state machine. Autoload: Game.
extends Node

enum State { TITLE, PLAYING, PAUSED, ROUND_END }

signal state_changed(from: State, to: State)
signal round_started(round_index: int)
signal round_ended(round_index: int, result: Dictionary)
signal restarted()
signal restart_armed()

## Select restarts the run on two presses within this many seconds (GAME.md Controls).
const RESTART_WINDOW := 1.0

var state: State = State.TITLE
var round_index: int = 0
var _restart_armed_at := -INF


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().auto_accept_quit = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit()


## Clean exit (code 0 for the launcher): save, silence audio so nothing leaks, quit.
func quit(code: int = 0) -> void:
	Save.flush()
	await Audio.silence()
	get_tree().quit(code)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if state == State.PLAYING:
			pause()
		elif state == State.PAUSED:
			resume()
	elif event.is_action_pressed("restart") and state != State.TITLE:
		press_restart(Time.get_ticks_msec() / 1000.0)


## One Select press arms (a sound and a blink), a second within RESTART_WINDOW restarts.
func press_restart(now_s: float) -> bool:
	if now_s - _restart_armed_at <= RESTART_WINDOW:
		_restart_armed_at = -INF
		restart()
		return true
	_restart_armed_at = now_s
	Audio.play("restart_arm")
	restart_armed.emit()
	return false


func start_round() -> void:
	round_index += 1
	get_tree().paused = false
	_set_state(State.PLAYING)
	Audio.play("round_start")
	round_started.emit(round_index)


func end_round(result: Dictionary = {}) -> void:
	_set_state(State.ROUND_END)
	Audio.play("round_end")
	Save.flush()
	round_ended.emit(round_index, result)


func pause() -> void:
	get_tree().paused = true
	Audio.play("pause")
	_set_state(State.PAUSED)


func resume() -> void:
	get_tree().paused = false
	Audio.play("pause")
	_set_state(State.PLAYING)


func restart() -> void:
	get_tree().paused = false
	Audio.play("ui_confirm")
	round_index = 0
	restarted.emit()
	start_round()


func _set_state(to: State) -> void:
	if to == state:
		return
	var from := state
	state = to
	state_changed.emit(from, to)
