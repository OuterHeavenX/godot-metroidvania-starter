class_name MVCrackedFloor
extends StaticBody2D


var rect := Rect2(0, 0, 136, 30)
## Set by the level so the slab matches its surroundings: turned earth in the
## cemetery, cut flagstone inside the castle.
var theme := "cemetery"
var _broken := false


func _ready() -> void:
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
	AudioMan.play("pound", -2.0, 0.7)
	JuiceMan.shake(0.4)
	var dust := Color(0.45, 0.50, 0.68) if theme == "castle" else Color(0.62, 0.52, 0.38)
	var chips := Color(0.70, 0.76, 0.92) if theme == "castle" else Color(0.9, 0.75, 0.5)
	JuiceMan.burst(global_position, dust, 26, 360.0, 0.7, 1100.0, 6.0)
	JuiceMan.burst(global_position, chips, 10, 200.0, 0.4, 500.0, 4.0)
	queue_free()


func _draw() -> void:
	var r := Rect2(-rect.size * 0.5, rect.size)

	var body := Color("3c4463") if theme == "castle" else Color("4a3d2c")
	var lip := Color("5b689a") if theme == "castle" else Color("6b5a40")
	var edge := Color("10131f") if theme == "castle" else Color("141008")
	draw_rect(r, body)
	draw_rect(Rect2(r.position, Vector2(r.size.x, 5)), lip)
	draw_rect(r, edge, false, 2.5)

	var rng := RandomNumberGenerator.new()
	rng.seed = int(rect.size.x * 13.0 + rect.size.y)
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
		draw_polyline(pts, Color("141008"), 2.0)

	var glint := 0.35 + 0.3 * sin(Time.get_ticks_msec() / 1000.0 * 3.0)
	for gx in [-r.size.x * 0.25, r.size.x * 0.25]:
		draw_circle(Vector2(gx, 0), 3.0, Color(1.0, 0.6, 0.25, glint))
