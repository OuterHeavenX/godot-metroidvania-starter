class_name MVTerrainVisual
extends Node2D
var rects: Array = []
var theme := "cemetery"

func _draw() -> void:
	for r in rects:
		var rect: Rect2 = r
		# Ramparts are cut stone like the castle; only the cemetery is earth.
		if theme == "castle" or theme == "ramparts":
			_castle_slab(rect)
		else:
			_graveyard_earth(rect)

## Cut stone: block courses with a bright worn top edge.
func _castle_slab(rect: Rect2) -> void:
	draw_rect(rect, Color("1d2440"))
	var y := rect.position.y + 10.0
	var row := 0
	while y < rect.end.y:
		draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y),
			Color("161c33"), 2.0)
		var off := 0.0 if row % 2 == 0 else 34.0
		var x := rect.position.x + off
		while x < rect.end.x:
			draw_line(Vector2(x, y), Vector2(x, minf(y + 22.0, rect.end.y)),
				Color("161c33"), 2.0)
			x += 68.0
		y += 22.0
		row += 1
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 7)), Color("46548a"))
	draw_rect(Rect2(rect.position + Vector2(0, 7), Vector2(rect.size.x, 3)),
		Color("2b355c"))
	draw_rect(rect, Color("0d1120"), false, 2.0)

## Turned earth under a lip of graveyard grass.
func _graveyard_earth(rect: Rect2) -> void:
	draw_rect(rect, Color("1b1a26"))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(absf(rect.position.x) * 7.0 + absf(rect.position.y) * 13.0) + 1
	for i in range(int(rect.size.x / 46.0) + 1):
		var p := rect.position + Vector2(rng.randf_range(0.0, rect.size.x),
			rng.randf_range(14.0, maxf(16.0, rect.size.y - 4.0)))
		draw_circle(p, rng.randf_range(1.5, 3.4), Color("241f2c"))
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 6)), Color("2f4a34"))
	draw_rect(Rect2(rect.position + Vector2(0, 6), Vector2(rect.size.x, 4)),
		Color("23351f"))
	# tufts along the lip
	var gx := rect.position.x + 4.0
	while gx < rect.end.x - 4.0:
		var h := rng.randf_range(4.0, 11.0)
		draw_line(Vector2(gx, rect.position.y + 1.0),
			Vector2(gx + rng.randf_range(-3.0, 3.0), rect.position.y - h),
			Color("3c5b3f"), 2.0)
		gx += rng.randf_range(9.0, 22.0)
	draw_rect(rect, Color("0d1120"), false, 2.0)
