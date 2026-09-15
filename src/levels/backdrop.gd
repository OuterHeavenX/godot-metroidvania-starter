class_name MVBackdrop
extends RefCounted

## Builds a themed, multi-layer parallax backdrop. Each theme is a sky gradient
## plus three painted layers at different motion scales, so the world reads as
## having depth rather than a flat silhouette behind it.
##
## Everything is drawn with primitives: no art needed beyond what the project
## already ships, and it scales to any level width.

const THEMES := ["cemetery", "castle"]


static func build(host: Node2D, theme: String, span: Vector2) -> void:
	if not THEMES.has(theme):
		theme = "cemetery"
	var sky_layer := CanvasLayer.new()
	sky_layer.layer = -100
	sky_layer.add_child(_sky(theme))
	host.add_child(sky_layer)

	var parallax := ParallaxBackground.new()
	host.add_child(parallax)
	for spec in _layers(theme):
		var layer := ParallaxLayer.new()
		# Parallax horizontally, but anchor the near layers vertically. With a
		# y-scale below 1 their baseline drifts with the camera, which put the
		# headstones below the ground line. Sky keeps a small y-scale so it
		# still floats.
		layer.motion_scale = Vector2(spec["scale"], spec["yscale"])
		var painter: Node2D = spec["painter"]
		# A layer scrolls at motion_scale, so the slice of its local space the
		# camera ever sees is the world span times that scale. Painting across
		# the full world span instead would spread everything so wide that most
		# of it -- the moon, the chapel -- never comes on screen at all.
		var s: float = float(spec["scale"])
		painter.set("span", Vector2(span.x * s - 200.0, span.y * s + 200.0))
		painter.position = Vector2(0, spec["y"])
		layer.add_child(painter)
		parallax.add_child(layer)


static func _sky(theme: String) -> Control:
	var grad := Gradient.new()
	if theme == "castle":
		grad.set_color(0, Color("07090f"))
		grad.set_color(1, Color("161b2c"))
	else:
		grad.set_color(0, Color("05070f"))
		grad.set_color(1, Color("1a2138"))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	tex.width = 8
	tex.height = 256
	var rect := TextureRect.new()
	rect.texture = tex
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	return rect


static func _layers(theme: String) -> Array:
	if theme == "castle":
		return [
			{"scale": 0.18, "yscale": 0.25, "y": -40.0, "painter": CastleDepth.new()},
			{"scale": 0.38, "yscale": 1.0, "y": 0.0, "painter": CastleWall.new()},
			{"scale": 0.62, "yscale": 1.0, "y": 0.0, "painter": CastleColumns.new()},
		]
	return [
		{"scale": 0.16, "yscale": 0.12, "y": -60.0, "painter": CemeteryRidge.new()},
		{"scale": 0.34, "yscale": 1.0, "y": 0.0, "painter": CemeteryChapel.new()},
		{"scale": 0.60, "yscale": 1.0, "y": 0.0, "painter": CemeteryGraves.new()},
	]


# ---------------------------------------------------------------- cemetery --

class CemeteryRidge extends Node2D:
	## Distant hills, the moon and a field of stars.
	var span := Vector2(-400, 4400)

	func _draw() -> void:
		var srng := RandomNumberGenerator.new()
		srng.seed = 77
		for i in range(140):
			var p := Vector2(srng.randf_range(span.x, span.y), srng.randf_range(-620.0, -60.0))
			draw_circle(p, srng.randf_range(0.8, 2.2), Color(1, 1, 1, srng.randf_range(0.2, 0.75)))

		# Early in the span so it is in view from the opening, and it drifts
		# slowly enough to stay up for a long stretch.
		var moon := Vector2(span.x + (span.y - span.x) * 0.22, -430.0)
		draw_circle(moon, 96.0, Color(0.85, 0.89, 0.97, 0.07))
		draw_circle(moon, 70.0, Color(0.88, 0.91, 0.98, 0.12))
		draw_circle(moon, 54.0, Color("e6ecfa"))
		draw_circle(moon + Vector2(-19, -15), 9.0, Color("cdd6ea"))
		draw_circle(moon + Vector2(16, 12), 6.0, Color("cdd6ea"))
		draw_circle(moon + Vector2(4, -26), 4.0, Color("cdd6ea"))

		var rng := RandomNumberGenerator.new()
		rng.seed = 1234
		var pts := PackedVector2Array()
		pts.append(Vector2(span.x, 420))
		var x := span.x
		while x < span.y:
			pts.append(Vector2(x, -rng.randf_range(120.0, 300.0)))
			x += rng.randf_range(260.0, 460.0)
			pts.append(Vector2(x, -rng.randf_range(40.0, 120.0)))
			x += rng.randf_range(260.0, 460.0)
		pts.append(Vector2(span.y, 420))
		draw_colored_polygon(pts, Color("151d31"))


class CemeteryChapel extends Node2D:
	## A chapel, bare trees and a far line of crosses.
	var span := Vector2(-400, 4400)

	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 909
		var x := span.x + 180.0
		while x < span.y:
			var kind := rng.randi_range(0, 2)
			if kind == 0:
				_chapel(Vector2(x, 0))
				x += rng.randf_range(1500.0, 2200.0)
			elif kind == 1:
				_tree(Vector2(x, 0), rng)
				x += rng.randf_range(420.0, 760.0)
			else:
				_cross(Vector2(x, 0), rng.randf_range(34.0, 58.0))
				x += rng.randf_range(260.0, 520.0)

	func _chapel(at: Vector2) -> void:
		var body := Color("1c2540")
		draw_rect(Rect2(at.x - 120, at.y - 190, 240, 190), body)
		draw_colored_polygon(PackedVector2Array([
			Vector2(at.x - 140, at.y - 190), Vector2(at.x, at.y - 290),
			Vector2(at.x + 140, at.y - 190),
		]), body)
		draw_rect(Rect2(at.x - 26, at.y - 400, 52, 214), body)
		draw_colored_polygon(PackedVector2Array([
			Vector2(at.x - 38, at.y - 400), Vector2(at.x, at.y - 470),
			Vector2(at.x + 38, at.y - 400),
		]), body)
		# lit windows
		for w in [-70.0, 0.0, 70.0]:
			draw_rect(Rect2(at.x + w - 13, at.y - 140, 26, 46), Color(0.95, 0.78, 0.42, 0.30))
		draw_rect(Rect2(at.x - 8, at.y - 350, 16, 30), Color(0.95, 0.78, 0.42, 0.24))

	func _tree(at: Vector2, rng: RandomNumberGenerator) -> void:
		var col := Color("1a2338")
		var h := rng.randf_range(150.0, 250.0)
		draw_line(at, at + Vector2(0, -h), col, 9.0)
		for i in range(5):
			var t := rng.randf_range(0.45, 0.95)
			var base := at + Vector2(0, -h * t)
			var dir := -1.0 if i % 2 == 0 else 1.0
			var tip := base + Vector2(dir * rng.randf_range(40.0, 90.0), -rng.randf_range(20.0, 60.0))
			draw_line(base, tip, col, 5.0)
			draw_line(tip, tip + Vector2(dir * 26.0, -18.0), col, 3.0)

	func _cross(at: Vector2, h: float) -> void:
		var col := Color("1b2438")
		draw_rect(Rect2(at.x - 4, at.y - h, 8, h), col)
		draw_rect(Rect2(at.x - 16, at.y - h * 0.72, 32, 8), col)


class CemeteryGraves extends Node2D:
	## Headstones, iron railings and a low band of mist.
	var span := Vector2(-400, 4400)

	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 555
		var x := span.x
		while x < span.y:
			var roll := rng.randi_range(0, 3)
			if roll == 0:
				_railing(x, rng.randf_range(150.0, 320.0))
				x += rng.randf_range(200.0, 380.0)
			else:
				_stone(Vector2(x, 0), rng)
				x += rng.randf_range(90.0, 190.0)
		# mist
		for i in range(3):
			var a := 0.05 - i * 0.012
			draw_rect(Rect2(span.x, -30.0 + i * 14.0, span.y - span.x, 30.0),
				Color(0.75, 0.82, 0.95, a))

	func _stone(at: Vector2, rng: RandomNumberGenerator) -> void:
		var col := Color("36426a")
		var edge := Color("46548a")
		var w := rng.randf_range(26.0, 46.0)
		var h := rng.randf_range(44.0, 96.0)
		var lean := rng.randf_range(-0.09, 0.09)
		var top := at + Vector2(lean * h, -h)
		if rng.randi_range(0, 3) == 0:
			draw_rect(Rect2(at.x - 5, at.y - h, 10, h), col)
			draw_rect(Rect2(at.x - 19, at.y - h * 0.74, 38, 9), col)
			return
		draw_colored_polygon(PackedVector2Array([
			Vector2(at.x - w * 0.5, at.y), Vector2(top.x - w * 0.5, top.y),
			Vector2(top.x + w * 0.5, top.y), Vector2(at.x + w * 0.5, at.y),
		]), col)
		draw_circle(Vector2(top.x, top.y), w * 0.5, col)
		draw_arc(Vector2(top.x, top.y), w * 0.5, PI, TAU, 12, edge, 2.0)

	func _railing(x: float, w: float) -> void:
		var col := Color("2b3757")
		draw_rect(Rect2(x, -58, w, 5), col)
		draw_rect(Rect2(x, -30, w, 4), col)
		var b := x
		while b < x + w:
			draw_rect(Rect2(b, -72, 4, 72), col)
			draw_circle(Vector2(b + 2, -74), 3.5, col)
			b += 22.0


# ------------------------------------------------------------------ castle --

class CastleDepth extends Node2D:
	## The far end of the hall: receding arches lost in the dark.
	var span := Vector2(-400, 4400)

	func _draw() -> void:
		draw_rect(Rect2(span.x, -700, span.y - span.x, 1200), Color("0b0f1a"))
		var x := span.x
		var i := 0
		while x < span.y:
			var w := 220.0
			var h := 430.0
			var col := Color("121829") if i % 2 == 0 else Color("0f1423")
			_arch(Vector2(x + w * 0.5, 0), w * 0.42, h, col)
			x += w
			i += 1

	func _arch(at: Vector2, r: float, h: float, col: Color) -> void:
		draw_rect(Rect2(at.x - r, at.y - h + r, r * 2.0, h - r), col)
		draw_circle(Vector2(at.x, at.y - h + r), r, col)


class CastleWall extends Node2D:
	## Block masonry with tall arched windows letting the night in.
	var span := Vector2(-400, 4400)

	func _draw() -> void:
		var stone := Color("161c30")
		var mortar := Color("0e1322")
		draw_rect(Rect2(span.x, -640, span.y - span.x, 1100), stone)
		# courses
		var y := -640.0
		var row := 0
		while y < 420.0:
			draw_line(Vector2(span.x, y), Vector2(span.y, y), mortar, 2.0)
			var off := 0.0 if row % 2 == 0 else 60.0
			var x := span.x + off
			while x < span.y:
				draw_line(Vector2(x, y), Vector2(x, y + 44.0), mortar, 2.0)
				x += 120.0
			y += 44.0
			row += 1
		# windows
		var wx := span.x + 260.0
		while wx < span.y:
			_window(Vector2(wx, -30))
			wx += 620.0
		# The great door the player comes in by. It sits where the camera is
		# looking when the level opens, so the hall reads as an entrance lobby
		# rather than an anonymous stretch of corridor.
		_gate(Vector2(300, 60))

	func _gate(at: Vector2) -> void:
		var r := 96.0
		var h := 300.0
		var surround := Color("2c375c")
		var door := Color("0b0e19")
		var iron := Color("39456b")
		draw_rect(Rect2(at.x - r - 26, at.y - h + r - 26, r * 2.0 + 52, h - r + 26), surround)
		draw_circle(Vector2(at.x, at.y - h + r), r + 26.0, surround)
		draw_rect(Rect2(at.x - r, at.y - h + r, r * 2.0, h - r), door)
		draw_circle(Vector2(at.x, at.y - h + r), r, door)
		# planking and the two ring handles
		var px := at.x - r + 16.0
		while px < at.x + r:
			draw_line(Vector2(px, at.y - h + 10.0), Vector2(px, at.y), Color("13182a"), 3.0)
			px += 32.0
		draw_line(Vector2(at.x, at.y - h - r * 0.3), Vector2(at.x, at.y), Color("161d33"), 6.0)
		draw_arc(Vector2(at.x - 26, at.y - 168), 11.0, 0.0, TAU, 14, iron, 3.0)
		draw_arc(Vector2(at.x + 26, at.y - 168), 11.0, 0.0, TAU, 14, iron, 3.0)
		# steps up to it
		for i in range(3):
			var w := r * 2.0 + 70.0 - float(i) * 34.0
			draw_rect(Rect2(at.x - w * 0.5, at.y - float(i) * 14.0, w, 14.0), surround)

	func _window(at: Vector2) -> void:
		var r := 44.0
		var h := 250.0
		var frame := Color("0d1120")
		var glow := Color(0.62, 0.72, 0.95, 0.20)
		draw_rect(Rect2(at.x - r - 10, at.y - h + r - 10, r * 2.0 + 20, h - r + 10), frame)
		draw_circle(Vector2(at.x, at.y - h + r), r + 10.0, frame)
		draw_rect(Rect2(at.x - r, at.y - h + r, r * 2.0, h - r), glow)
		draw_circle(Vector2(at.x, at.y - h + r), r, glow)
		draw_line(Vector2(at.x, at.y - h - r * 0.2), Vector2(at.x, at.y), frame, 5.0)
		# moonlight spilling down the wall
		draw_colored_polygon(PackedVector2Array([
			Vector2(at.x - r, at.y), Vector2(at.x + r, at.y),
			Vector2(at.x + r * 2.6, at.y + 300.0), Vector2(at.x - r * 0.4, at.y + 300.0),
		]), Color(0.66, 0.76, 0.98, 0.045))


class CastleColumns extends Node2D:
	## Near columns and hanging banners, the lobby foreground.
	var span := Vector2(-400, 4400)

	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 4242
		var x := span.x + 120.0
		var i := 0
		while x < span.y:
			_column(x)
			if i % 2 == 1:
				_banner(x + 155.0, rng)
			else:
				_brazier(x + 155.0)
			x += 310.0
			i += 1

	func _column(x: float) -> void:
		var shaft := Color("1b2238")
		var trim := Color("2f3a5f")
		draw_rect(Rect2(x - 26, -560, 52, 620), shaft)
		draw_rect(Rect2(x - 34, -560, 68, 26), trim)   # capital
		draw_rect(Rect2(x - 34, 34, 68, 26), trim)     # base
		draw_line(Vector2(x - 12, -534), Vector2(x - 12, 34), Color("141a2c"), 3.0)
		draw_line(Vector2(x + 12, -534), Vector2(x + 12, 34), Color("141a2c"), 3.0)

	func _brazier(x: float) -> void:
		## A standing fire bowl between the columns. The warm pool of light is
		## what keeps the hall from reading as a plain blue corridor.
		var iron := Color("222a44")
		var y := 34.0
		draw_rect(Rect2(x - 4, y - 96, 8, 96), iron)
		draw_rect(Rect2(x - 20, y - 4, 40, 8), iron)
		draw_colored_polygon(PackedVector2Array([
			Vector2(x - 26, y - 118), Vector2(x + 26, y - 118),
			Vector2(x + 16, y - 92), Vector2(x - 16, y - 92),
		]), iron)
		draw_circle(Vector2(x, y - 124), 22.0, Color(1.0, 0.55, 0.22, 0.22))
		draw_circle(Vector2(x, y - 126), 13.0, Color(1.0, 0.72, 0.34, 0.55))
		draw_circle(Vector2(x, y - 128), 7.0, Color(1.0, 0.9, 0.6, 0.85))
		draw_colored_polygon(PackedVector2Array([
			Vector2(x - 66, y - 190), Vector2(x + 66, y - 190),
			Vector2(x + 30, y + 10), Vector2(x - 30, y + 10),
		]), Color(1.0, 0.6, 0.28, 0.05))

	func _banner(x: float, rng: RandomNumberGenerator) -> void:
		var cloth := Color("55202c") if rng.randi_range(0, 1) == 0 else Color("1f2c55")
		var gold := Color("b8963f")
		var top := -470.0
		var h := rng.randf_range(210.0, 280.0)
		draw_rect(Rect2(x - 34, top, 68, h), cloth)
		draw_rect(Rect2(x - 38, top - 8, 76, 10), gold)
		draw_colored_polygon(PackedVector2Array([
			Vector2(x - 34, top + h), Vector2(x, top + h - 26), Vector2(x + 34, top + h),
		]), cloth)
		draw_circle(Vector2(x, top + h * 0.42), 15.0, gold)
		draw_circle(Vector2(x, top + h * 0.42), 10.0, cloth)
