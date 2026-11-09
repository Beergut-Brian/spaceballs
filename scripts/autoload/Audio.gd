## Sound on every action. Autoload: Audio.
## play("cue") looks for assets/audio/sfx/cue.ogg, or cue_1.ogg..cue_N.ogg and picks one.
## Missing cues warn once and never crash.
extends Node

const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"
const VOICE_DIR := "res://addons/openjar/characters/"
const POOL_SIZE := 12

var _pool: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _warned := {}
var _cache := {}
var _silenced := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"
		add_child(p)
		_pool.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music" if AudioServer.get_bus_index("Music") != -1 else "Master"
	add_child(_music)


## A player still playing at quit leaks its stream playback (the audio thread frees it later
## than the engine checks). Game.quit() awaits this before quitting.
func silence() -> void:
	_silenced = true
	await stop_all()


## Stops every player and waits for the audio thread to let go of the playbacks.
func stop_all() -> void:
	for p in _pool + [_music]:
		p.stop()
		p.stream = null
	_cache.clear()
	# Real time, not frames: headless runs uncapped and the mix thread needs a buffer or two.
	await get_tree().create_timer(0.2, true, false, true).timeout


func _exit_tree() -> void:
	for p in _pool + [_music]:
		p.stop()
		p.stream = null
	_cache.clear()


func play(cue: String, _position = null, pitch: float = 1.0) -> void:
	if _silenced:
		return
	var stream := _resolve(SFX_DIR, cue)
	if stream == null:
		return
	for p in _pool:
		if not p.playing:
			p.stream = stream
			p.pitch_scale = pitch * randf_range(0.95, 1.05)
			p.play()
			return
	_pool[0].stream = stream
	_pool[0].pitch_scale = pitch
	_pool[0].play()


func music(track: String, fade: float = 0.5) -> void:
	if _silenced:
		return
	var stream := _resolve(MUSIC_DIR, track)
	if stream == null:
		return
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	var tw := create_tween()
	if _music.playing:
		tw.tween_property(_music, "volume_db", -40.0, fade)
	tw.tween_callback(func():
		_music.stream = stream
		_music.volume_db = -40.0
		_music.play())
	tw.tween_property(_music, "volume_db", 0.0, fade)


func stop_music(fade: float = 0.5) -> void:
	var tw := create_tween()
	tw.tween_property(_music, "volume_db", -40.0, fade)
	tw.tween_callback(_music.stop)


func bark(character: String, bark_name: String) -> void:
	if _silenced:
		return
	var stream := _resolve("%s%s/voice/" % [VOICE_DIR, character], bark_name)
	if stream == null:
		return
	for p in _pool:
		if not p.playing:
			p.stream = stream
			p.pitch_scale = 1.0
			p.play()
			return


func _resolve(dir: String, cue: String) -> AudioStream:
	var key := dir + cue
	if _cache.has(key):
		var variants: Array = _cache[key]
		return variants.pick_random() if not variants.is_empty() else null
	var variants: Array = []
	if ResourceLoader.exists(dir + cue + ".ogg"):
		variants.append(load(dir + cue + ".ogg"))
	else:
		var i := 1
		while ResourceLoader.exists("%s%s_%d.ogg" % [dir, cue, i]):
			variants.append(load("%s%s_%d.ogg" % [dir, cue, i]))
			i += 1
	_cache[key] = variants
	if variants.is_empty():
		if not _warned.has(key):
			_warned[key] = true
			push_warning("Audio: no file for cue '%s' in %s" % [cue, dir])
		return null
	return variants.pick_random()
