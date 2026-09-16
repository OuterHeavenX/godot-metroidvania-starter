extends Node

## Progress that outlives a page reload. Shares the config file AudioMan uses
## for the mute flag -- both load before they save, so neither clobbers the
## other's section.

const PATH := "user://metroidvania_starter.cfg"

var snapshot := MVRunSnapshot.new()
var best_time := 0.0
var runs := 0
var writable := true
var _dirty := false
var _pending_mute: Variant = null
var _flush_t := 0.0
signal save_failed(error: int)

var abilities: Array[String]:
	get: return snapshot.abilities
	set(value): snapshot.abilities = value
var checkpoint: Vector2:
	get: return snapshot.checkpoint
	set(value): snapshot.checkpoint = value
var has_checkpoint: bool:
	get: return snapshot.has_checkpoint
	set(value): snapshot.has_checkpoint = value
var level_path: String:
	get: return snapshot.level_path
	set(value): snapshot.level_path = value
var checkpoint_level: String:
	get: return snapshot.checkpoint_level
	set(value): snapshot.checkpoint_level = value
var run_time: float:
	get: return snapshot.run_time
	set(value): snapshot.run_time = value
var completed: bool:
	get: return snapshot.completed
	set(value): snapshot.completed = value

## Levels only restore progress when this is set, which the title screen does
## for Continue. A level launched directly -- by a test, or by the editor --
## therefore always starts clean, whatever happens to be on disk.
var resume_requested := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_progress()


func load_progress() -> void:
	var cfg := ConfigFile.new()
	var error := cfg.load(PATH)
	if error != OK:
		# A backup is only a recovery source; never partially apply a corrupt file.
		if cfg.load(PATH + ".bak") != OK:
			return
	var version = cfg.get_value("progress", "version", 1)
	writable = version is int and version >= 1 and version <= MVRunSnapshot.VERSION
	if not writable:
		push_warning("Save version is newer than this game; progress will not be overwritten.")
		return
	snapshot = MVRunSnapshot.read(cfg)
	best_time = MVRunSnapshot.nonnegative(cfg.get_value("stats", "best_time", 0.0))
	runs = int(MVRunSnapshot.nonnegative(cfg.get_value("stats", "runs", 0)))
	_dirty = false


func save_progress() -> void:
	if not writable:
		return
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		cfg.load(PATH + ".bak") # Keep settings when recovering a corrupt primary.
	if _pending_mute != null:
		cfg.set_value("audio", "muted", _pending_mute)
	snapshot.write(cfg)
	cfg.set_value("stats", "best_time", best_time)
	cfg.set_value("stats", "runs", runs)
	var error := cfg.save(PATH + ".tmp")
	if error == OK:
		if FileAccess.file_exists(PATH):
			var old := ConfigFile.new()
			if old.load(PATH) == OK:
				error = DirAccess.copy_absolute(PATH, PATH + ".bak")
		if error == OK:
			error = DirAccess.rename_absolute(PATH + ".tmp", PATH)
	if error != OK:
		_dirty = true
		save_failed.emit(error)
		push_warning("Unable to save progress: %s" % error_string(error))
	else:
		_dirty = false
		_flush_t = 0.0
		_pending_mute = null


func _process(delta: float) -> void:
	_flush_t += delta
	if _dirty and _flush_t >= 1.0:
		save_progress()


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_PAUSED]:
		flush()


func flush() -> void:
	if _dirty:
		save_progress()


func update_area_time(scene: String, seconds: float) -> void:
	if scene != level_path or completed:
		return
	snapshot.area_time = maxf(snapshot.area_time, seconds)
	_dirty = true


func note_world(area: String, id: String) -> void:
	if snapshot.contains(area, id):
		return
	snapshot.mark(area, id)
	save_progress()


func begin_area(scene: String, continuing: bool) -> void:
	if not continuing:
		snapshot = MVRunSnapshot.new()
	level_path = scene
	completed = false
	save_progress()


## True when there is something worth resuming.
func has_run() -> bool:
	return not completed and (has_checkpoint or not abilities.is_empty() or level_path != "")


## The checkpoint only applies inside the area it was set in.
func checkpoint_for(scene_path: String) -> bool:
	return has_checkpoint and checkpoint_level == scene_path


func clear_progress() -> void:
	snapshot = MVRunSnapshot.new()
	resume_requested = false
	save_progress()


## Moving on: the next area starts without the previous area's checkpoint.
func note_area_cleared(next_scene: String, seconds: float) -> void:
	run_time += maxf(seconds, snapshot.area_time)
	snapshot.area_time = 0.0
	level_path = next_scene
	has_checkpoint = false
	checkpoint_level = ""
	save_progress()


func note_ability(ability_id: String) -> void:
	if ability_id not in MVRunSnapshot.ABILITIES or ability_id in abilities:
		return
	abilities.append(ability_id)
	save_progress()


func note_checkpoint(pos: Vector2, scene_path: String = "") -> void:
	if not pos.is_finite():
		return
	checkpoint = pos
	has_checkpoint = true
	checkpoint_level = scene_path
	save_progress()


## `seconds` is the whole run, including areas banked before this one.
func note_win(seconds: float) -> void:
	if completed:
		return
	completed = true
	runs += 1
	if best_time <= 0.0 or seconds < best_time:
		best_time = seconds
	run_time = 0.0
	snapshot.area_time = 0.0
	save_progress()


static func format_time(seconds: float) -> String:
	var m := int(seconds) / 60
	var s := int(seconds) % 60
	var cs := int(seconds * 100.0) % 100
	return "%d:%02d.%02d" % [m, s, cs]


func set_audio_muted(value: bool) -> void:
	_pending_mute = value
	save_progress()
