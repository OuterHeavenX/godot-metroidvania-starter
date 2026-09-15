extends Area2D


signal won

var done := false
var locked := false
var t := 0.0


func _ready() -> void:
	add_to_group("goal")
	collision_layer = 0
	collision_mask = 1
	body_entered.connect(_on_body)


## Held shut until the Warden falls. Dimmed so it reads as inert.
func lock() -> void:
	locked = true
	modulate = Color(0.5, 0.55, 0.68)


func unlock() -> void:
	if not locked:
		return
	locked = false
	modulate = Color.WHITE
	AudioMan.play("checkpoint", 0.0, 0.7)
	JuiceMan.shake(0.3)
	JuiceMan.burst(global_position + Vector2(0, -40), Color(0.6, 0.95, 1.0),
		22, 280.0, 0.7, 260.0, 5.0)
	queue_redraw()


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _on_body(body: Node2D) -> void:
	if done:
		return
	if locked:
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
