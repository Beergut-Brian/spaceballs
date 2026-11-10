## Sound on every action. Autoload: Audio.
## play("cue") looks for assets/audio/sfx/cue.ogg, or cue_1.ogg..cue_N.ogg and picks one.
## Missing cues warn once and never crash.
## music("track") plays assets/audio/music/track.ogg on a loop. If track_layer_1.ogg..N exist
## they play in sync on top (silent at first); music_level(n) fades layers 1..n in.
extends Node

const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"
const VOICE_DIR := "res://addons/openjar/characters/"
const POOL_SIZE := 12
## Template menu cues with no file of their own play one of ours: cue -> [our cue, pitch].
## A real file for the cue (Audio lane) wins over the alias.
const ALIASES := {
	"ui_move": ["card_move", 1.0], "ui_back": ["ui_confirm", 0.75],
	"player_ready": ["player_join", 1.0], "player_unready": ["player_join", 0.7],
	"count_tick": ["card_move", 1.5], "solo_on": ["player_join", 1.5], "solo_off": ["player_join", 0.6],
}

var _pool: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _warned := {}
var _cache := {}
var _silenced := false
var _track := ""
var _layers := 0
var _level := 0
var _level_tween: Tween
var _music_tween: Tween
const LAYER_OFF_DB := -60.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	add_child(_music)
	set_volume("Music", Save.get_setting("music_volume", 0.8))
	set_volume("SFX", Save.get_setting("sound_volume", 1.0))


## bus: "Music" or "SFX"; linear 0..1 (the Settings sliders). 0 mutes.
func set_volume(bus: String, linear: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i == -1:
		return
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(linear, 0.0001)))
	AudioServer.set_bus_mute(i, linear <= 0.0)


func get_volume(bus: String) -> float:
	var i := AudioServer.get_bus_index(bus)
	if i == -1 or AudioServer.is_bus_mute(i):
		return 0.0
	return db_to_linear(AudioServer.get_bus_volume_db(i))


## A player still playing at quit leaks its stream playback (the audio thread frees it later
## than the engine checks). Game.quit() awaits this before quitting.
func silence() -> void:
	_silenced = true
	await stop_all()


## Stops every player and waits for the audio thread to let go of the playbacks.
func stop_all() -> void:
	if _music_tween:
		_music_tween.kill()   # a fade still pending would start the track again
	_track = ""
	for p in _pool + [_music] + _other_players():
		p.stop()
		p.stream = null
	_cache.clear()
	# Real time, not frames: headless runs uncapped and the mix thread needs a buffer or two.
	await get_tree().create_timer(0.2, true, false, true).timeout


## Every other player in the tree too: the menu kit's synth cues (UiSound, its own pool under the
## root) and any scene's own players. One still ringing at quit leaks its playback.
func _other_players() -> Array:
	if not is_inside_tree():
		return []
	return get_tree().root.find_children("*", "AudioStreamPlayer", true, false).filter(
			func(c: Node) -> bool: return not c in _pool and c != _music)


func _exit_tree() -> void:
	for p in _pool + [_music] + _other_players():
		p.stop()
		p.stream = null
	_cache.clear()


func play(cue: String, _position = null, pitch: float = 1.0) -> void:
	if _silenced:
		return
	if ALIASES.has(cue) and not _has_file(cue):
		pitch *= ALIASES[cue][1]
		cue = ALIASES[cue][0]
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
	if _silenced or (track == _track and _music.playing):
		return
	var stream := _music_stream(track)
	if stream == null:
		return
	_track = track
	_level = 0
	if _music_tween:
		_music_tween.kill()
	_music_tween = create_tween()
	var tw := _music_tween
	if _music.playing:
		tw.tween_property(_music, "volume_db", -40.0, fade)
	tw.tween_callback(func():
		_music.stream = stream
		_music.volume_db = -40.0
		_music.play())
	tw.tween_property(_music, "volume_db", 0.0, fade)


## Layered music: layers 1..level audible, the rest silent. No-op for a single-file track.
func music_level(level: int, fade: float = 1.0) -> void:
	level = clampi(level, 0, _layers)
	if _layers == 0 or level == _level or not (_music.stream is AudioStreamSynchronized):
		_level = level
		return
	_level = level
	var sync: AudioStreamSynchronized = _music.stream
	if _level_tween:
		_level_tween.kill()
	_level_tween = create_tween().set_parallel()
	for i in range(1, _layers + 1):
		var to := 0.0 if i <= level else LAYER_OFF_DB
		_level_tween.tween_method(func(db: float): sync.set_sync_stream_volume(i, db),
				sync.get_sync_stream_volume(i), to, fade)


func _music_stream(track: String) -> AudioStream:
	var base := _resolve(MUSIC_DIR, track)
	_layers = 0
	if base == null:
		return null
	if base is AudioStreamOggVorbis:
		base.loop = true
	var layers: Array[AudioStream] = []
	while ResourceLoader.exists("%s%s_layer_%d.ogg" % [MUSIC_DIR, track, layers.size() + 1]):
		var s: AudioStream = load("%s%s_layer_%d.ogg" % [MUSIC_DIR, track, layers.size() + 1])
		if s is AudioStreamOggVorbis:
			s.loop = true
		layers.append(s)
	if layers.is_empty():
		return base
	var sync := AudioStreamSynchronized.new()
	sync.stream_count = layers.size() + 1
	sync.set_sync_stream(0, base)
	for i in layers.size():
		sync.set_sync_stream(i + 1, layers[i])
		sync.set_sync_stream_volume(i + 1, LAYER_OFF_DB)
	_layers = layers.size()
	return sync


func stop_music(fade: float = 0.5) -> void:
	var tw := create_tween()
	tw.tween_property(_music, "volume_db", -40.0, fade)
	tw.tween_callback(_music.stop)
	_track = ""


func _has_file(cue: String) -> bool:
	return ResourceLoader.exists(SFX_DIR + cue + ".ogg") or ResourceLoader.exists(SFX_DIR + cue + "_1.ogg")


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
