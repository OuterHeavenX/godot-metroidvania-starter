extends Node


const SFX_NAMES :=  [
	"jump", "double_jump", "dash", "attack", "hit_enemy", "enemy_die",
	"player_hurt", "player_die", "land", "checkpoint", "orb_pickup",
	"goal_win", "ui_click", "pound",
]
const POOL_SIZE := 8
const MUSIC_DB := -17.0
const AUDIO_DIR := "res://assets/audio/"


const THROTTLE := {
	"hit_enemy": 0.07,
	"enemy_die": 0.05,
	"jump": 0.05,
	"land": 0.08,
}

var muted := false
var _sfx := {}
var _pool: Array[AudioStreamPlayer] = []
var _pool_i := 0
var _music: AudioStreamPlayer
var _last_play := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_muted()
	for n in SFX_NAMES:
		var path: String = AUDIO_DIR + n + ".res"
		if ResourceLoader.exists(path):
			_sfx[n] = load(path)
		else:
			push_warning("AudioMan: missing " + path)
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = &"Master"
		add_child(p)
		_pool.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = &"Master"
	add_child(_music)
	var mpath := AUDIO_DIR + "music_loop.res"
	if ResourceLoader.exists(mpath):
		var stream: AudioStreamWAV = load(mpath)
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		# data.size() is a frame count only for uncompressed 16-bit PCM. The
		# imported stream is QOA-compressed, so this looped a 40s track at ~8s.
		stream.loop_end = int(stream.get_length() * stream.mix_rate)
		_music.stream = stream
		_music.volume_db = MUSIC_DB
		_music.play()
	_apply_mute()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).keycode == KEY_M:
			toggle_mute()


func play(sfx_name: String, vol_db: float = 0.0, pitch: float = 1.0) -> void:
	if muted or not _sfx.has(sfx_name):
		return
	var now := Time.get_ticks_msec() / 1000.0
	var gap: float = THROTTLE.get(sfx_name, 0.0)
	if gap > 0.0 and now - float(_last_play.get(sfx_name, -99.0)) < gap:
		return
	_last_play[sfx_name] = now
	var p := _pool[_pool_i]
	_pool_i = (_pool_i + 1) % POOL_SIZE
	p.stream = _sfx[sfx_name]
	p.volume_db = vol_db
	p.pitch_scale = pitch
	p.play()


func toggle_mute() -> void:
	muted = not muted
	_apply_mute()
	_save_muted()


func is_muted() -> bool:
	return muted


func _apply_mute() -> void:
	AudioServer.set_bus_mute(0, muted)


func _load_muted() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://metroidvania_starter.cfg") == OK:
		muted = bool(cfg.get_value("audio", "muted", false))


func _save_muted() -> void:
	var cfg := ConfigFile.new()
	cfg.load("user://metroidvania_starter.cfg")
	cfg.set_value("audio", "muted", muted)
	cfg.save("user://metroidvania_starter.cfg")
