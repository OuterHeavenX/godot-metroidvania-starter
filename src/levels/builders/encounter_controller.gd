class_name MVEncounterController
extends Node2D

signal world_changed(id: String)
signal won
signal boss_spawned(boss: MVBoss)
const EnemyScene := preload("res://src/enemies/skeleton.tscn")
const BossScene := preload("res://src/enemies/boss.tscn")
const GoalScene := preload("res://src/goal/goal.tscn")
var data: MVLevelData
var cleared: Dictionary = {}
var goal: Area2D
var boss: MVBoss
var enemies: Array[MVSkeleton] = []

func build(definition: MVLevelData, completed: Dictionary) -> void:
	data = definition
	cleared = completed.duplicate()
	goal = GoalScene.instantiate()
	goal.position = data.goal_position
	goal.won.connect(func() -> void: won.emit())
	add_child(goal)
	_spawn_enemies()

func _spawn_enemies() -> void:
	for spawn in data.enemies:
		if cleared.has(spawn.persistence_id):
			continue
		var foe: MVSkeleton = EnemyScene.instantiate()
		foe.kind = spawn.kind
		foe.position = spawn.position
		_register(foe, spawn.persistence_id)
	boss = null
	if data.has_boss and not cleared.has(data.boss_id):
		boss = BossScene.instantiate()
		boss.position = data.boss_position
		_register(boss, data.boss_id)
		goal.lock()
		boss.defeated.connect(goal.unlock)
		boss_spawned.emit(boss)
	else:
		goal.unlock()

func _register(foe: MVSkeleton, id: String) -> void:
	foe.set_meta("persistence_id", id)
	foe.died.connect(func() -> void:
		cleared[id] = true
		world_changed.emit(id))
	add_child(foe)
	enemies.append(foe)

## Same rule as Continue: defeated enemies stay gone; survivors restart intact.
func reset_survivors() -> void:
	for foe in enemies:
		if is_instance_valid(foe):
			remove_child(foe)
			foe.queue_free()
	enemies.clear()
	for child in get_children():
		if child is MVArrow:
			remove_child(child)
			child.queue_free()
	_spawn_enemies()
