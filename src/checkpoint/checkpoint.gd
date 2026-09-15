extends Area2D


var activated := false


func _ready() -> void:
	add_to_group("checkpoint")
	collision_layer = 0
	collision_mask = 1
	body_entered.connect(_on_body)


func _on_body(body: Node2D) -> void:
	if activated:
		return
	var p := body as MVPlayer
	if p != null:
		activated = true
		p.set_checkpoint(global_position + Vector2(0, -10))
		# Dying was the only way to recover health, which does not hold up over
		# a level this long. Reaching a new checkpoint restores it.
		var healed: bool = p.heal(p.MAX_HP)
		AudioMan.play("checkpoint")
		if healed:
			JuiceMan.burst(p.global_position, Color(0.95, 0.35, 0.45),
				14, 170.0, 0.5, 220.0, 4.0)
		JuiceMan.burst(global_position + Vector2(0, -48), Color(0.95, 0.75, 0.3),
			12, 200.0, 0.5, 300.0, 4.0)
		queue_redraw()
		var tw := create_tween()
		tw.tween_property(self, "scale", Vector2(1.25, 1.25), 0.12)
		tw.tween_property(self, "scale", Vector2.ONE, 0.14)


func _draw() -> void:

	draw_line(Vector2.ZERO, Vector2(0, -58), Color("6b4a2f"), 5.0)
	draw_circle(Vector2(0, -60), 4, Color("8a6238"))

	var col := Color("e8b53a") if activated else Color("5a6274")
	var wave := sin(Time.get_ticks_msec() / 180.0) * 3.0 if activated else 0.0
	draw_colored_polygon(PackedVector2Array( [
		Vector2(2, -56), Vector2(34, -48 + wave), Vector2(2, -38),
	]), col)
