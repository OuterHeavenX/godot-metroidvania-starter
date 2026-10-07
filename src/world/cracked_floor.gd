class_name MVCrackedFloor
extends StaticBody2D

signal broken


var rect := Rect2(0, 0, 136, 30)
## Set by the level so the slab matches its surroundings: turned earth in the
## cemetery, cut flagstone inside the castle.
var theme := "cemetery"
var _broken := false


func _ready() -> void:
	var effects := preload("res://src/presentation/world_feedback.gd").new()
	effects.kind = "floor"
	add_child(effects)
	add_to_group("cracked")
	collision_layer = 4
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = rect.size
	shape.shape = rs
	add_child(shape)
	queue_redraw()


func break_floor() -> void:

	if _broken:
		return
	_broken = true
	broken.emit()
	queue_free()


func _draw() -> void:
	var r := Rect2(-rect.size * 0.5, rect.size)

	var body: Color
	var lip: Color
	var edge: Color
	if theme == "winter":
		body = Color("c8dff0")
		lip = Color("e0ebf8")
		edge = Color("0d1120")
	elif theme != "cemetery":
		body = Color("3c4463")
		lip = Color("5b689a")
		edge = Color("10131f")
	else:
		body = Color("4a3d2c")
		lip = Color("6b5a40")
		edge = Color("141008")
	draw_rect(r, body)
	draw_rect(Rect2(r.position, Vector2(r.size.x, 5)), lip)
	draw_rect(r, edge, false, 2.5)

	var rng := RandomNumberGenerator.new()
	rng.seed = int(rect.size.x * 13.0 + rect.size.y)
	var crack_color := Color("a8c5e0") if theme == "winter" else Color("141008")
	for i in range(5):
		var x0 := rng.randf_range(-r.size.x * 0.42, r.size.x * 0.42)
		var pts := PackedVector2Array()
		pts.append(Vector2(x0, -r.size.y * 0.5 + 2.0))
		var y := - r.size.y * 0.5 + 2.0
		var x := x0
		while y < r.size.y * 0.5 - 2.0:
			y += rng.randf_range(4.0, 9.0)
			x += rng.randf_range(-7.0, 7.0)
			pts.append(Vector2(x, y))
		draw_polyline(pts, crack_color, 2.0)

	var glint := 0.35 + 0.3 * sin(Time.get_ticks_msec() / 1000.0 * 3.0)
	var glint_color: Color
	if theme == "winter":
		glint_color = Color(0.8, 0.95, 1.0, glint)
	else:
		glint_color = Color(1.0, 0.6, 0.25, glint)
	for gx in [-r.size.x * 0.25, r.size.x * 0.25]:
		draw_circle(Vector2(gx, 0), 3.0, glint_color)
