class_name MVTerrainBuilder
extends Node2D

signal world_changed(id: String)

func build(data: MVLevelData, cleared: Dictionary) -> void:
	var visual := MVTerrainVisual.new()
	visual.theme = data.theme
	visual.rects = data.platforms
	add_child(visual)
	for rect in data.platforms:
		var body := StaticBody2D.new()
		body.collision_layer = 4
		body.collision_mask = 0
		body.position = rect.get_center()
		var shape := CollisionShape2D.new()
		var rectangle := RectangleShape2D.new()
		rectangle.size = rect.size
		shape.shape = rectangle
		body.add_child(shape)
		add_child(body)
	for spawn in data.breakables:
		if cleared.has(spawn.persistence_id):
			continue
		var slab := MVCrackedFloor.new()
		slab.theme = data.theme
		slab.rect = Rect2(spawn.position - spawn.size * 0.5, spawn.size)
		slab.position = spawn.position
		slab.set_meta("persistence_id", spawn.persistence_id)
		slab.broken.connect(func() -> void: world_changed.emit(spawn.persistence_id))
		add_child(slab)
