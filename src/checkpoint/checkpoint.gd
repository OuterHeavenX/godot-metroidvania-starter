extends Area2D

signal claimed


var activated := false


func _ready() -> void:
	var effects := preload("res://src/presentation/world_feedback.gd").new()
	effects.kind = "checkpoint"
	add_child(effects)
	add_to_group("checkpoint")
	collision_layer = 0
	collision_mask = 1
	body_entered.connect(_on_body)


func _on_body(body: Node2D) -> void:
	if activated:
		return
	var p := body as MVPlayer
	if p != null and not p.dead:
		activated = true
		claimed.emit()
		p.set_checkpoint(global_position + Vector2(0, -10))
		# Dying was the only way to recover health, which does not hold up over
		# a level this long. Reaching a new checkpoint restores it.
		p.heal(p.MAX_HP)
		queue_redraw()


func _draw() -> void:

	draw_line(Vector2.ZERO, Vector2(0, -58), Color("6b4a2f"), 5.0)
	draw_circle(Vector2(0, -60), 4, Color("8a6238"))

	var col := Color("e8b53a") if activated else Color("5a6274")
	var wave := sin(Time.get_ticks_msec() / 180.0) * 3.0 if activated else 0.0
	draw_colored_polygon(PackedVector2Array( [
		Vector2(2, -56), Vector2(34, -48 + wave), Vector2(2, -38),
	]), col)
