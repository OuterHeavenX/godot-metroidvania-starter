extends Control


var hp := 5
var max_hp := 5


func set_values(p_hp: int, p_max_hp: int) -> void:
	hp = p_hp
	max_hp = p_max_hp
	queue_redraw()


func _draw() -> void:
	for i in range(max_hp):
		var c := Vector2(18 + i * 36, 18)
		var col := Color("e6394f") if i < hp else Color("2a2f45")
		draw_circle(c + Vector2(-6.5, -2), 8.5, col)
		draw_circle(c + Vector2(6.5, -2), 8.5, col)
		draw_colored_polygon(PackedVector2Array( [
			c + Vector2(-14, 2), c + Vector2(14, 2), c + Vector2(0, 16),
		]), col)
