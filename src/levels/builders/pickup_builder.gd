class_name MVPickupBuilder
extends Node2D

signal world_changed(id: String)
var orbs: Array[Node2D] = []

func build(data: MVLevelData, cleared: Dictionary, abilities: Array[String]) -> void:
	for spawn in data.orbs:
		if cleared.has(spawn.persistence_id) or spawn.ability_id in abilities:
			continue
		var orb: Area2D = preload("res://src/pickups/orb.tscn").instantiate()
		orb.position = spawn.position
		orb.ability_id = spawn.ability_id
		orb.tint = spawn.tint
		_wire(orb, &"collected", spawn.persistence_id)
		add_child(orb)
		orbs.append(orb)
	for spawn in data.heart_spawns:
		if cleared.has(spawn.persistence_id):
			continue
		var heart := MVHeart.new()
		heart.position = spawn.position
		_wire(heart, &"collected", spawn.persistence_id)
		add_child(heart)
	for spawn in data.checkpoint_spawns:
		var point: Area2D = preload("res://src/checkpoint/checkpoint.tscn").instantiate()
		point.position = spawn.position
		point.activated = cleared.has(spawn.persistence_id)
		_wire(point, &"claimed", spawn.persistence_id)
		add_child(point)

func _wire(actor: Node2D, event: StringName, id: String) -> void:
	actor.set_meta("persistence_id", id)
	actor.connect(event, func() -> void: world_changed.emit(id))
