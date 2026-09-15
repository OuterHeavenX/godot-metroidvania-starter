extends Node

## Progress that outlives a page reload. Shares the config file AudioMan uses
## for the mute flag -- both load before they save, so neither clobbers the
## other's section.

const PATH := "user://metroidvania_starter.cfg"

var abilities: Array[String] = []
var checkpoint := Vector2.ZERO
var has_checkpoint := false
var completed := false
var best_time := 0.0
var runs := 0

## Levels only restore progress when this is set, which the title screen does
## for Continue. A level launched directly -- by a test, or by the editor --
## therefore always starts clean, whatever happens to be on disk.
var resume_requested := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_progress()


func load_progress() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	abilities.clear()
	for a in PackedStringArray(cfg.get_value("progress", "abilities", PackedStringArray())):
		abilities.append(String(a))
	has_checkpoint = bool(cfg.get_value("progress", "has_checkpoint", false))
	checkpoint = cfg.get_value("progress", "checkpoint", Vector2.ZERO)
	completed = bool(cfg.get_value("progress", "completed", false))
	best_time = float(cfg.get_value("stats", "best_time", 0.0))
	runs = int(cfg.get_value("stats", "runs", 0))


func save_progress() -> void:
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	cfg.set_value("progress", "abilities", PackedStringArray(abilities))
	cfg.set_value("progress", "has_checkpoint", has_checkpoint)
	cfg.set_value("progress", "checkpoint", checkpoint)
	cfg.set_value("progress", "completed", completed)
	cfg.set_value("stats", "best_time", best_time)
	cfg.set_value("stats", "runs", runs)
	cfg.save(PATH)


## True when there is something worth resuming.
func has_run() -> bool:
	return has_checkpoint or not abilities.is_empty()


func clear_progress() -> void:
	abilities.clear()
	checkpoint = Vector2.ZERO
	has_checkpoint = false
	save_progress()


func note_ability(ability_id: String) -> void:
	if ability_id in abilities:
		return
	abilities.append(ability_id)
	save_progress()


func note_checkpoint(pos: Vector2) -> void:
	checkpoint = pos
	has_checkpoint = true
	save_progress()


func note_win(seconds: float) -> void:
	completed = true
	runs += 1
	if best_time <= 0.0 or seconds < best_time:
		best_time = seconds
	save_progress()


static func format_time(seconds: float) -> String:
	var m := int(seconds) / 60
	var s := int(seconds) % 60
	var cs := int(seconds * 100.0) % 100
	return "%d:%02d.%02d" % [m, s, cs]
