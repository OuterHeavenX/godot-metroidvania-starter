extends Area2D


signal won

var done := false
var t := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	body_entered.connect(_on_body)


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _on_body(body: Node2D) -> void:
	if done:
		return
	if body.is_in_group("player"):
		done = true
		AudioMan.play("goal_win")
		JuiceMan.shake(0.25)
		won.emit()


func _draw() -> void:
	var glow := 0.5 + 0.3 * sin(t * 3.0)

	draw_colored_polygon(PackedVector2Array( [
		Vector2(-26, 0), Vector2(-26, -110), Vector2(26, -110), Vector2(26, 0),
	]), Color(0.45, 0.8, 1.0, 0.1 + glow * 0.08))

	draw_rect(Rect2(-32, -116, 12, 116), Color("2e3a5c"))
	draw_rect(Rect2(20, -116, 12, 116), Color("2e3a5c"))
	draw_rect(Rect2(-32, -116, 12, 116), Color("0d1120"), false, 2.0)
	draw_rect(Rect2(20, -116, 12, 116), Color("0d1120"), false, 2.0)

	draw_rect(Rect2(-32, -128, 64, 14), Color("2e3a5c"))
	draw_rect(Rect2(-32, -128, 64, 14), Color("0d1120"), false, 2.0)

	var bob := sin(t * 3.0) * 4.0
	var chev := PackedVector2Array( [
		Vector2(-8 + bob, -70), Vector2(4 + bob, -58), Vector2(-8 + bob, -46),
	])
	draw_polyline(chev, Color(0.55, 0.95, 1.0, glow), 4.0)
