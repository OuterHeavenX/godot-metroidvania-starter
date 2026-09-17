class_name MVLevelData
extends Resource

## Everything that makes one area. A level scene is just this resource plus a
## player, a HUD and the touch controls, so a new area is a new .tres rather
## than new code.

@export var area_id := ""
@export var boss_id := "warden"
@export var level_name := "Untitled"
## Scene of the area this one leads to. Empty means this is the last area.
@export_file("*.tscn") var next_level := ""
## Optional per-area music; falls back to AudioMan's default when empty.
@export_file("*.res") var music := ""

@export_group("Terrain")
## Solid ground. Each rect is drawn and given a matching StaticBody2D.
@export var platforms: Array[Rect2] = []
## Ground that a ground pound shatters. Sits 30px proud of the floor it bridges.
@export var breakables: Array[MVWorldSpawn] = []
var cracked: Array[Rect2]:
	get:
		var result: Array[Rect2] = []
		for spawn in breakables:
			result.append(Rect2(spawn.position - spawn.size * 0.5, spawn.size))
		return result

@export_group("Actors")
@export var player_start := Vector2.ZERO
@export var enemies: Array[MVEnemySpawn] = []
@export var orbs: Array[MVOrbSpawn] = []
@export var checkpoint_spawns: Array[MVWorldSpawn] = []
var checkpoints: Array[Vector2]:
	get:
		var result: Array[Vector2] = []
		for spawn in checkpoint_spawns:
			result.append(spawn.position)
		return result
@export var heart_spawns: Array[MVWorldSpawn] = []
var hearts: Array[Vector2]:
	get:
		var result: Array[Vector2] = []
		for spawn in heart_spawns:
			result.append(spawn.position)
		return result
@export var goal_position := Vector2.ZERO
## When set, the goal stays locked until the Warden is defeated.
@export var has_boss := false
@export var boss_position := Vector2.ZERO

@export_group("Bounds")
## Camera clamp: position is the top-left corner, end is the bottom-right.
@export var camera_limits := Rect2(-40, -760, 6560, 1180)
## Falling past this kills the player.
@export var kill_y := 500.0

@export_group("Dressing")
## Picks the backdrop and how terrain is painted: "cemetery" or "castle".
@export_enum("cemetery", "castle", "ramparts") var theme := "cemetery"
@export var hints: Array[MVHint] = []
## Horizontal span of the world the backdrop has to cover. Each parallax
## layer scales this by its own motion scale to decide how wide to paint.
@export var background_span := Vector2(-400, 4400)


func validation_errors() -> Array[String]:
	var errors: Array[String] = []
	if area_id == "":
		errors.append("Missing stable area_id")
	var seen: Dictionary = {}
	var placements: Array = []
	placements.append_array(enemies)
	placements.append_array(orbs)
	placements.append_array(breakables)
	placements.append_array(heart_spawns)
	placements.append_array(checkpoint_spawns)
	for spawn in placements:
		if spawn == null:
			errors.append("Null placement")
			continue
		var id: String = spawn.persistence_id
		if id == "" or seen.has(id):
			errors.append("Missing or duplicate persistence ID: " + id)
		seen[id] = true
	if has_boss and (boss_id == "" or seen.has(boss_id)):
		errors.append("Missing or duplicate boss ID")
	return errors
