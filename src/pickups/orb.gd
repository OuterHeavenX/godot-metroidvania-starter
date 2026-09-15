extends Area2D


@export var ability_id := "double_jump"
@export var tint := Color("6ee7ff")

var t := 0.0
var base_y := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	base_y = position.y
	body_entered.connect(_on_body)


func _process(delta: float) -> void:
	t += delta
	position.y = base_y + sin(t * 2.2) * 8.0
	queue_redraw()


func _on_body(body: Node2D) -> void:
	var p := body as MVPlayer
	if p == null:
		return
	p.gain_ability(ability_id)
	AudioMan.play("orb_pickup")
	JuiceMan.burst(global_position, tint, 18, 240.0, 0.7, 200.0, 5.0, "magic")
	JuiceMan.shake(0.2)
	queue_free()


func _draw() -> void:
	var pulse := 1.0 + sin(t * 4.0) * 0.12

	draw_circle(Vector2.ZERO, 26.0 * pulse, Color(tint, 0.15))
	draw_circle(Vector2.ZERO, 17.0 * pulse, Color(tint, 0.25))

	draw_colored_polygon(PackedVector2Array( [
		Vector2(0, -14), Vector2(9, 0), Vector2(0, 14), Vector2(-9, 0),
	]), tint)
	draw_colored_polygon(PackedVector2Array( [
		Vector2(0, -14), Vector2(9, 0), Vector2(0, 4),
	]), Color(1, 1, 1, 0.85))
	if ability_id == "ground_pound":

		var c := Color(1, 1, 1, 0.9)
		draw_line(Vector2(-8, -7), Vector2(0, 1), c, 3.0)
		draw_line(Vector2(8, -7), Vector2(0, 1), c, 3.0)
		draw_line(Vector2(-8, 1), Vector2(0, 9), c, 3.0)
		draw_line(Vector2(8, 1), Vector2(0, 9), c, 3.0)
	else:

		var w := Color(tint, 0.9)
		draw_arc(Vector2(-12, -4), 8, 2.6, 4.4, 10, w, 2.5)
		draw_arc(Vector2(12, -4), 8, -1.4, 0.4, 10, w, 2.5)
