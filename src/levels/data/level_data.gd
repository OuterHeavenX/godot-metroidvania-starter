class_name MVLevelData
extends Resource

## Everything that makes one area. A level scene is just this resource plus a
## player, a HUD and the touch controls, so a new area is a new .tres rather
## than new code.

@export var level_name := "Untitled"
## Scene of the area this one leads to. Empty means this is the last area.
@export_file("*.tscn") var next_level := ""
## Optional per-area music; falls back to AudioMan's default when empty.
@export_file("*.res") var music := ""

@export_group("Terrain")
## Solid ground. Each rect is drawn and given a matching StaticBody2D.
@export var platforms: Array[Rect2] = []
## Ground that a ground pound shatters. Sits 30px proud of the floor it bridges.
@export var cracked: Array[Rect2] = []

@export_group("Actors")
@export var player_start := Vector2.ZERO
@export var enemies: Array[MVEnemySpawn] = []
@export var orbs: Array[MVOrbSpawn] = []
@export var checkpoints: Array[Vector2] = []
@export var hearts: Array[Vector2] = []
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
@export var hints: Array[MVHint] = []
## Horizontal span the parallax hills are drawn across, in layer space.
@export var background_span := Vector2(-400, 4400)
