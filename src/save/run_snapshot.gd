class_name MVRunSnapshot
extends RefCounted

const VERSION := 2
const ABILITIES := ["double_jump", "ground_pound"]
var abilities: Array[String] = []
var checkpoint := Vector2.ZERO
var has_checkpoint := false
var level_path := ""
var checkpoint_level := ""
var run_time := 0.0
var area_time := 0.0
var completed := false
## area_id -> {permanent authored object ID: true}. No positions or indexes.
var world: Dictionary = {}

func contains(area: String, id: String) -> bool:
	return id != "" and bool(world.get(area, {}).get(id, false))

func mark(area: String, id: String) -> void:
	if area == "" or id == "":
		return
	if not world.has(area):
		world[area] = {}
	world[area][id] = true

func write(cfg: ConfigFile) -> void:
	cfg.set_value("progress", "version", VERSION)
	for key in ["checkpoint", "has_checkpoint", "level_path", "checkpoint_level", "run_time", "area_time", "completed", "world"]:
		cfg.set_value("progress", key, get(key))
	cfg.set_value("progress", "abilities", PackedStringArray(abilities))

## Legacy (unversioned) saves migrate with empty world state and area time.
## Reject malformed fields rather than allowing Variant conversion crashes.
static func read(cfg: ConfigFile) -> MVRunSnapshot:
	var result := MVRunSnapshot.new()
	var raw = cfg.get_value("progress", "abilities", PackedStringArray())
	if raw is Array or raw is PackedStringArray:
		for id in raw:
			if id is String and id in ABILITIES and id not in result.abilities:
				result.abilities.append(id)
	for key in ["level_path", "checkpoint_level"]:
		var value = cfg.get_value("progress", key, "")
		if value is String and (value == "" or (value.begins_with("res://src/levels/") and value.ends_with(".tscn") and ResourceLoader.exists(value))):
			result.set(key, value)
	var point = cfg.get_value("progress", "checkpoint", Vector2.ZERO)
	if point is Vector2 and point.is_finite():
		result.checkpoint = point
		var has_point = cfg.get_value("progress", "has_checkpoint", false)
		result.has_checkpoint = has_point is bool and has_point
	var is_complete = cfg.get_value("progress", "completed", false)
	result.completed = is_complete is bool and is_complete
	result.run_time = nonnegative(cfg.get_value("progress", "run_time", 0.0))
	result.area_time = nonnegative(cfg.get_value("progress", "area_time", 0.0))
	var world_value = cfg.get_value("progress", "world", {})
	if world_value is Dictionary:
		for area in world_value:
			if not area is String or not world_value[area] is Dictionary:
				continue
			for id in world_value[area]:
				if id is String and world_value[area][id] == true:
					result.mark(area, id)
	if result.level_path == "" and (result.has_checkpoint or not result.abilities.is_empty()):
		result.level_path = "res://src/levels/level_01.tscn"
	if result.has_checkpoint and result.checkpoint_level == "":
		result.checkpoint_level = result.level_path
	return result

static func nonnegative(value: Variant) -> float:
	if (value is float or value is int) and is_finite(float(value)):
		return maxf(float(value), 0.0)
	return 0.0
