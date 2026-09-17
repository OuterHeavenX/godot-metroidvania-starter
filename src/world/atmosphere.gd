class_name MVAtmosphere
extends Node2D
## Full visual-overhaul rig for the metroidvania: gradient night sky with moon
## and twinkling stars, four parallax layers (mountains / dead forest / ruins /
## drifting fog), warm 2D lights (player lantern, torches, orb glows),
## a foreground silhouette layer, ambient embers + dust, and a vignette.
## All procedural; zero assets. Level01 drives it in two phases:
##   build_background(level)  — sky + parallax, must run BEFORE terrain
##   build_lighting(...)      — lights + foreground + particles + vignette
## No CanvasModulate: the palette is dark by hand and lights are additive,
## so the HUD and touch controls are never dimmed.

var _t := 0.0
var _sky: SkyDraw
var _torches: Array = [] # each: {light: PointLight2D, base: float, phase: float}
var _lantern: PointLight2D
var _lantern_base := 1.5


static func build_background(level: Node2D) -> void:
	var atmo: Node2D = load("res://src/world/atmosphere.gd").new()
	atmo.name = "Atmosphere"
	_build_sky_layer(atmo)
	_build_parallax(atmo)
	level.add_child(atmo)


static func build_v11(level: Node2D, player: Node2D, orbs: Array,
		torch_spots: Array, terrain_rects: Array, grassy: bool = true) -> Node2D:
	## v11: MVBackdrop paints the themed parallax background, so this builds
	## everything else — dark ambient, lights, torch posts, grass, god rays,
	## camera particles, foreground and vignette.
	var atmo = (load("res://src/world/atmosphere.gd") as GDScript).new()
	atmo.name = "Atmosphere"
	level.add_child(atmo)
	atmo._build_ambient(level)
	atmo._build_lights(player, orbs, torch_spots)
	atmo._build_camera_fx(player)
	atmo._build_vignette()
	atmo._build_god_rays()
	if grassy:
		var grass := PlatformGrass.new()
		grass.name = "PlatformGrass"
		grass.setup(terrain_rects)
		level.add_child(grass)
	var birds := Birds.new()
	birds.name = "Birds"
	level.add_child(birds)
	# drifting fog bands between the backdrop and the playfield
	var level_w := 4300.0
	for r in terrain_rects:
		var rr: Rect2 = r
		level_w = maxf(level_w, rr.end.x)
	var fog_pb := ParallaxBackground.new()
	fog_pb.name = "FogParallax"
	level.add_child(fog_pb)
	var fog_defs := [
		[101, 40.0, 0.10, 0.055],
		[202, -140.0, 0.13, 0.07],
		[303, 190.0, 0.09, 0.05],
	]
	for fd in fog_defs:
		var pl := ParallaxLayer.new()
		pl.motion_scale = Vector2(0.62, 1.0)
		var band := FogBand.new()
		band.band_seed = int(fd[0])
		band.base_y = float(fd[1])
		band.alpha = float(fd[2])
		band.speed = float(fd[3])
		band.x_span = level_w + 800.0
		pl.add_child(band)
		fog_pb.add_child(pl)
	return atmo


static func build_lighting(level: Node2D, player: Node2D, orbs: Array,
		torch_spots: Array, terrain_rects: Array, grassy: bool = true) -> Node2D:
	var atmo = level.get_node("Atmosphere")
	atmo._build_ambient(level)
	atmo._build_lights(player, orbs, torch_spots)
	atmo._build_camera_fx(player)
	atmo._build_vignette()
	atmo._build_god_rays()
	if grassy:
		var grass := PlatformGrass.new()
		grass.name = "PlatformGrass"
		grass.setup(terrain_rects)
		level.add_child(grass)
	var birds := Birds.new()
	birds.name = "Birds"
	atmo.get_node("Parallax/ForestLayer").add_child(birds)
	return atmo


func _build_ambient(level: Node2D) -> void:
	## True dark ambient: the world goes night-dark, the additive lights
	## carve pools out of it. CanvasLayers (HUD, touch, vignette) are untouched.
	var cm := CanvasModulate.new()
	cm.color = Color(0.60, 0.62, 0.72)
	level.add_child(cm)


func _process(delta: float) -> void:
	_t += delta
	if _sky != null:
		_sky.t = _t
		_sky.queue_redraw()
	for tc in _torches:
		var d: Dictionary = tc
		var l := d["light"] as PointLight2D
		var ph := float(d["phase"])
		l.energy = float(d["base"]) + sin(_t * 13.0 + ph) * 0.14 \
			+ sin(_t * 29.0 + ph * 2.3) * 0.07
	if _lantern != null:
		_lantern.energy = _lantern_base + sin(_t * 9.0) * 0.05 \
			+ sin(_t * 23.0) * 0.03


# ------------------------------------------------------------------ sky ---

static func _build_sky_layer(atmo: MVAtmosphere) -> void:
	var layer := CanvasLayer.new()
	# Named so the parallax test can tell a deliberate screen-pinned layer from
	# one that drifted in by accident.
	layer.name = "SkyLayer"
	layer.layer = -100
	atmo.add_child(layer)
	# vertical night gradient
	var grad := Gradient.new()
	grad.set_color(0, Color("03060e"))
	grad.set_color(1, Color("0e1828"))
	grad.add_point(0.55, Color("081120"))
	var gtex := GradientTexture2D.new()
	gtex.gradient = grad
	gtex.width = 4
	gtex.height = 256
	gtex.fill_from = Vector2(0.5, 0.0)
	gtex.fill_to = Vector2(0.5, 1.0)
	var sky := TextureRect.new()
	sky.texture = gtex
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sky.stretch_mode = TextureRect.STRETCH_SCALE
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(sky)
	# moon + twinkling stars, drawn in screen space
	var draw := SkyDraw.new()
	layer.add_child(draw)
	atmo._sky = draw


class SkyDraw extends Node2D:
	var t := 0.0

	func _draw() -> void:
		# positioned relative to the real viewport so any window/aspect works
		var size := get_viewport_rect().size
		# pale moon with halo, upper right
		var m := Vector2(size.x * 0.78, size.y * 0.12)
		var mr := size.y * 0.10
		draw_circle(m, mr * 2.1, Color(0.85, 0.9, 1.0, 0.05))
		draw_circle(m, mr * 1.5, Color(0.85, 0.9, 1.0, 0.07))
		draw_circle(m, mr, Color("dfe6f5"))
		draw_circle(m + Vector2(-mr * 0.3, -mr * 0.24), mr * 0.17, Color("c3cde2"))
		draw_circle(m + Vector2(mr * 0.27, mr * 0.2), mr * 0.12, Color("c9d2e6"))
		draw_circle(m + Vector2(mr * 0.07, -mr * 0.4), mr * 0.09, Color("ccd5e8"))
		# twinkling stars across the top two thirds
		var rng := RandomNumberGenerator.new()
		rng.seed = 4242
		for i in range(130):
			var p := Vector2(rng.randf_range(0.0, size.x), rng.randf_range(0.0, size.y * 0.66))
			var r := rng.randf_range(0.8, 2.1)
			var tw := 0.25 + 0.6 * absf(sin(t * rng.randf_range(0.6, 2.2) + rng.randf_range(0.0, 6.28)))
			draw_circle(p, r, Color(1, 1, 1, tw))


# -------------------------------------------------------------- parallax ---

static func _build_parallax(atmo: MVAtmosphere) -> void:
	var parallax := ParallaxBackground.new()
	parallax.name = "Parallax"
	atmo.add_child(parallax)

	var far := ParallaxLayer.new()
	# Horizontal parallax only. A y motion scale below 1 makes a layer scroll
	# slower than the world vertically, so it slides up the screen every time the
	# camera rises -- the backdrop visibly rode up with the player's jump. Depth
	# comes from the x scale; the y axis stays locked to the world.
	far.motion_scale = Vector2(0.12, 1.0)
	far.add_child(MountainsFar.new())
	parallax.add_child(far)

	var forest := ParallaxLayer.new()
	forest.name = "ForestLayer"
	forest.motion_scale = Vector2(0.3, 1.0)
	forest.add_child(DeadForest.new())
	parallax.add_child(forest)

	var ruins := ParallaxLayer.new()
	ruins.motion_scale = Vector2(0.5, 1.0)
	ruins.add_child(Ruins.new())
	parallax.add_child(ruins)

	# drifting fog bands between the ruins and the playfield
	var fog_defs := [
		[101, 40.0, 0.10, 0.055],
		[202, -140.0, 0.13, 0.07],
		[303, 190.0, 0.09, 0.05],
	]
	for fd in fog_defs:
		var pl := ParallaxLayer.new()
		pl.motion_scale = Vector2(0.62, 1.0)
		var band := FogBand.new()
		band.band_seed = int(fd[0])
		band.base_y = float(fd[1])
		band.alpha = float(fd[2])
		band.speed = float(fd[3])
		pl.add_child(band)
		parallax.add_child(pl)


class MountainsFar extends Node2D:
	func _draw() -> void:
		_range(Color("1a2547"), Color("2c3d6e"), -560.0, -380.0, 1234)
		_range(Color("111a33"), Color("22315c"), -380.0, -210.0, 987)

	func _range(col: Color, rim: Color, hi: float, lo: float, seed: int) -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed
		var ridge := PackedVector2Array()
		var x := -900.0
		while x < 5000.0:
			ridge.append(Vector2(x, rng.randf_range(hi, hi + 90.0)))
			x += rng.randf_range(260.0, 460.0)
			ridge.append(Vector2(x, rng.randf_range(lo, lo + 90.0)))
			x += rng.randf_range(260.0, 460.0)
		var pts := PackedVector2Array([Vector2(-900, 460)])
		pts.append_array(ridge)
		pts.append(Vector2(5000, 460))
		draw_colored_polygon(pts, col)
		# faint moonlit rim along the ridge
		draw_polyline(ridge, rim, 3.0)


class DeadForest extends Node2D:
	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 777
		var i := 0
		while i < 30:
			var x := -800.0 + i * 195.0 + rng.randf_range(-50.0, 50.0)
			_tree(x, 420.0, rng.randf_range(190.0, 330.0), rng)
			i += 1

	func _tree(x: float, ground: float, h: float, rng: RandomNumberGenerator) -> void:
		var col := Color("080d1a")
		var lean := rng.randf_range(-26.0, 26.0)
		var top := Vector2(x + lean, ground - h)
		# tapered trunk
		var w0 := rng.randf_range(10.0, 16.0)
		draw_colored_polygon(PackedVector2Array([
			Vector2(x - w0, ground), Vector2(x + w0, ground),
			top + Vector2(3, 0), top + Vector2(-3, 0),
		]), col)
		# branches: two-segment tapered lines reaching up and out
		var n := 5 + rng.randi_range(0, 2)
		for b in range(n):
			var f := rng.randf_range(0.35, 0.95) # height fraction along trunk
			var bx := lerpf(x, top.x, f)
			var by := lerpf(ground, top.y, f)
			var side := 1.0 if b % 2 == 0 else -1.0
			var blen := rng.randf_range(40.0, 95.0) * (1.15 - f * 0.5)
			var tip := Vector2(bx + side * blen, by - blen * rng.randf_range(0.5, 0.9))
			var bw := rng.randf_range(3.0, 5.5)
			var mid := Vector2(bx, by).lerp(tip, 0.55)
			draw_line(Vector2(bx, by), mid, col, bw * 2.2)
			draw_line(mid, tip, col, 2.5)
			# twig
			if rng.randf() < 0.6:
				var mf := rng.randf_range(0.4, 0.7)
				var mp := Vector2(bx, by).lerp(tip, mf)
				var ttip := mp + Vector2(side * rng.randf_range(12.0, 26.0),
					-rng.randf_range(14.0, 30.0))
				draw_line(mp, ttip, col, 2.0)


class Ruins extends Node2D:
	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 31337
		var ground := 430.0
		var i := 0
		while i < 13:
			var x := -700.0 + i * 400.0 + rng.randf_range(-70.0, 70.0)
			if rng.randf() < 0.3:
				_arch(x, ground, rng)
			else:
				_pillar(x, ground, rng.randf_range(90.0, 230.0),
					rng.randf_range(34.0, 58.0), rng.randf() < 0.45, rng)
			i += 1

	func _pillar(x: float, ground: float, h: float, w: float, broken: bool,
			rng: RandomNumberGenerator) -> void:
		var col := Color("121a2e")
		var edge := Color("22304f")
		var top := ground - h
		if broken:
			# jagged broken top
			var pts := PackedVector2Array([
				Vector2(x - w * 0.5, ground), Vector2(x - w * 0.5, top + 26),
				Vector2(x - w * 0.2, top), Vector2(x + w * 0.1, top + 18),
				Vector2(x + w * 0.5, top + 6), Vector2(x + w * 0.5, ground),
			])
			draw_colored_polygon(pts, col)
			# rubble at the base
			for k in range(3):
				var rx := x + rng.randf_range(-w, w)
				draw_colored_polygon(PackedVector2Array([
					Vector2(rx - 14, ground), Vector2(rx + 14, ground),
					Vector2(rx + rng.randf_range(-6, 6), ground - rng.randf_range(10, 26)),
				]), col)
		else:
			draw_rect(Rect2(x - w * 0.5, top, w, h), col)
			draw_rect(Rect2(x - w * 0.5, top, w, 5), edge) # worn top edge
			draw_rect(Rect2(x - w * 0.62, top - 12, w * 1.24, 12), col) # cap stone
			draw_rect(Rect2(x - w * 0.62, top - 12, w * 1.24, 4), edge)

	func _arch(x: float, ground: float, rng: RandomNumberGenerator) -> void:
		var w := rng.randf_range(120.0, 170.0)
		var h := rng.randf_range(150.0, 210.0)
		_pillar(x - w * 0.5, ground, h, 40.0, false, rng)
		_pillar(x + w * 0.5, ground, h, 40.0, rng.randf() < 0.5, rng)
		var col := Color("121a2e")
		draw_rect(Rect2(x - w * 0.5 - 20, ground - h, w + 40, 22), col)
		draw_rect(Rect2(x - w * 0.5 - 20, ground - h, w + 40, 5), Color("22304f"))


class FogBand extends Node2D:
	## Soft fog puffs: Sprite2Ds sharing the radial glow texture, drifting
	## sideways. Real soft edges — no hard circle outlines.
	var band_seed := 1
	var base_y := 0.0
	var alpha := 0.10
	var speed := 0.1
	var x_span := 4300.0
	var t := 0.0
	var _puffs: Array = []

	func _ready() -> void:
		var tex: Texture2D = load("res://src/world/atmosphere.gd").make_glow_texture()
		var rng := RandomNumberGenerator.new()
		rng.seed = band_seed
		var count := maxi(2, int(x_span / 430.0) + 1)
		for i in range(count):
			var s := Sprite2D.new()
			s.texture = tex
			var sc := rng.randf_range(2.5, 5.0)
			s.scale = Vector2(sc * rng.randf_range(1.7, 2.8), sc)
			s.modulate = Color(0.55, 0.7, 0.9, alpha)
			s.position = Vector2(-700.0 + x_span * float(i) / float(count - 1) + rng.randf_range(-80.0, 80.0),
				base_y + rng.randf_range(-30.0, 30.0))
			add_child(s)
			_puffs.append({"node": s, "phase": rng.randf_range(0.0, 6.28),
				"base_x": s.position.x, "amp": rng.randf_range(60.0, 140.0)})

	func _process(delta: float) -> void:
		t += delta
		for p in _puffs:
			var d: Dictionary = p
			var n := d["node"] as Sprite2D
			n.position.x = float(d["base_x"]) \
				+ sin(t * speed + float(d["phase"])) * float(d["amp"])


# ------------------------------------------------------ aaa-life classes ---

class TorchPost extends Node2D:
	## Wooden brand post with an animated flame; the light + particles are
	## added by _build_lights at the matching offsets.
	var t := 0.0
	var phase := 0.0

	func _init() -> void:
		add_to_group("torch_post")

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		# post
		draw_rect(Rect2(-4, -56, 8, 56), Color("2e2114"))
		draw_rect(Rect2(-4, -56, 3, 56), Color("4d3a22"))
		# iron bowl
		draw_colored_polygon(PackedVector2Array([
			Vector2(-10, -56), Vector2(10, -56),
			Vector2(6, -47), Vector2(-6, -47),
		]), Color("141824"))
		draw_line(Vector2(-10, -56), Vector2(10, -56), Color("3a4358"), 2.0)
		# flame: three layered flickering teardrops
		var f := 1.0 + sin(t * 13.0 + phase) * 0.16 + sin(t * 29.0 + phase * 2.0) * 0.09
		_flame(10.0, 24.0 * f, 0.0, Color(0.95, 0.38, 0.08, 0.85))
		_flame(6.0, 15.0 * f, 0.0, Color(1.0, 0.68, 0.18, 0.95))
		_flame(3.0, 8.0 * f, 0.0, Color(1.0, 0.93, 0.55, 1.0))

	func _flame(half_w: float, h: float, dx: float, col: Color) -> void:
		var sway := sin(t * 7.0 + phase) * 2.5
		draw_colored_polygon(PackedVector2Array([
			Vector2(dx - half_w, -56), Vector2(dx + half_w, -56),
			Vector2(dx + half_w * 0.4 + sway, -56 - h * 0.7),
			Vector2(dx + sway * 1.6, -56 - h),
		]), col)


class GodRays extends Node2D:
	## Soft additive moon-shafts drifting almost imperceptibly.
	var t := 0.0
	var _rays: Array = []

	func _ready() -> void:
		var tex: Texture2D = (load("res://src/world/atmosphere.gd") as GDScript).make_ray_texture()
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		for i in range(3):
			var s := Sprite2D.new()
			s.texture = tex
			s.material = mat
			s.centered = true
			s.scale = Vector2(2.4, 5.2)
			s.rotation = 0.20
			s.modulate = Color(0.72, 0.80, 1.0, 0.10)
			s.position = Vector2([760.0, 1950.0, 3050.0][i], -260.0)
			add_child(s)
			_rays.append({"node": s, "phase": i * 2.1})

	func _process(delta: float) -> void:
		t += delta
		for r in _rays:
			var d: Dictionary = r
			var s := d["node"] as Sprite2D
			s.rotation = 0.20 + sin(t * 0.10 + float(d["phase"])) * 0.022


class PlatformGrass extends Node2D:
	## Tufts growing along platform tops, swaying in the wind. One batched draw.
	var t := 0.0
	var _tufts: Array = []

	func setup(rects: Array) -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 20260714
		for entry in rects:
			var rc: Rect2 = entry
			var x := rc.position.x + 8.0
			while x < rc.end.x - 8.0:
				if rng.randf() < 0.72:
					_tufts.append({
						"x": x + rng.randf_range(-4.0, 4.0),
						"y": rc.position.y,
						"h": rng.randf_range(10.0, 20.0),
						"ph": rng.randf_range(0.0, 6.28),
						"c": Color(0.16 + rng.randf() * 0.08, 0.32 + rng.randf() * 0.1, 0.18),
					})
				x += rng.randf_range(16.0, 34.0)

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		for entry in _tufts:
			var d: Dictionary = entry
			var sway := sin(t * 1.6 + float(d["ph"])) * 4.5
			var x := float(d["x"])
			var y := float(d["y"])
			var h := float(d["h"])
			var c := d["c"] as Color
			for b in range(3):
				var bx := x + (b - 1) * 3.5
				var tip := Vector2(bx + sway * (0.6 + b * 0.2), y - h * (0.8 + b * 0.12))
				draw_colored_polygon(PackedVector2Array([
					Vector2(bx - 2.2, y + 1.0), Vector2(bx + 2.2, y + 1.0), tip,
				]), c)


class Birds extends Node2D:
	## Distant birds crossing the dead forest, wings flapping.
	var t := 0.0
	var _birds: Array = []

	func _ready() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 777
		for i in range(4):
			_birds.append({
				"x": rng.randf_range(-600.0, 4200.0),
				"y": rng.randf_range(-640.0, -380.0),
				"ph": rng.randf_range(0.0, 6.28),
				"s": rng.randf_range(9.0, 17.0),
				"spd": rng.randf_range(45.0, 85.0),
			})

	func _process(delta: float) -> void:
		t += delta
		for entry in _birds:
			var d: Dictionary = entry
			d["x"] = float(d["x"]) + float(d["spd"]) * delta
			if float(d["x"]) > 4400.0:
				d["x"] = -700.0
		queue_redraw()

	func _draw() -> void:
		var c := Color(0.05, 0.06, 0.10, 0.85)
		for entry in _birds:
			var d: Dictionary = entry
			var p := Vector2(float(d["x"]), float(d["y"]))
			var s := float(d["s"])
			var flap := sin(t * 8.0 + float(d["ph"])) * s * 0.55
			draw_line(p + Vector2(-s, -flap * 0.4), p, c, 2.5)
			draw_line(p, p + Vector2(s, -flap * 0.4), c, 2.5)
			draw_circle(p, 1.8, c)


# ---------------------------------------------------------------- lights ---

static func make_glow_texture(size: int = 128) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := size * 0.5
	for y in range(size):
		for x in range(size):
			var d := Vector2(x - c + 0.5, y - c + 0.5).length() / c
			var a := pow(clampf(1.0 - d, 0.0, 1.0), 2.2)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)


static var _ray_tex: ImageTexture

static func make_ray_texture() -> ImageTexture:
	## Vertical light-shaft gradient: bright core fading to soft edges,
	## stronger at the top, dissolving toward the bottom.
	if _ray_tex != null:
		return _ray_tex
	var w := 64
	var h := 256
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in range(h):
		for x in range(w):
			var ex := absf(x - w * 0.5) / (w * 0.5)
			var edge := pow(clampf(1.0 - ex, 0.0, 1.0), 1.8)
			var top := clampf(1.0 - float(y) / float(h), 0.0, 1.0)
			var a := edge * pow(top, 1.4) * 0.9
			img.set_pixel(x, y, Color(1, 1, 1, a))
	_ray_tex = ImageTexture.create_from_image(img)
	return _ray_tex


func _build_god_rays() -> void:
	var rays := GodRays.new()
	rays.name = "GodRays"
	add_child(rays)


func _build_lights(player: Node2D, orbs: Array, torch_spots: Array) -> void:
	var glow := make_glow_texture()
	# player's lantern: warm pool that travels with the hero
	_lantern = PointLight2D.new()
	_lantern.texture = glow
	_lantern.texture_scale = 4.2
	_lantern.color = Color(1.0, 0.78, 0.5)
	_lantern.energy = _lantern_base
	_lantern.position = Vector2(0, -36)
	player.add_child(_lantern)
	# torch posts at checkpoints and the goal
	for pos in torch_spots:
		var p: Vector2 = pos
		var post := TorchPost.new()
		post.position = p
		post.phase = randf_range(0.0, 6.28)
		add_child(post)
		var light := PointLight2D.new()
		light.texture = glow
		light.texture_scale = 3.6
		light.color = Color(1.0, 0.6, 0.26)
		light.energy = 2.4
		light.position = p + Vector2(0, -72)
		add_child(light)
		_torches.append({"light": light, "base": 2.4,
			"phase": randf_range(0.0, 6.28)})
		var flame := CPUParticles2D.new()
		flame.position = p + Vector2(0, -64)
		flame.amount = 14
		flame.lifetime = 0.55
		flame.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
		flame.emission_sphere_radius = 4.0
		flame.direction = Vector2(0, -1)
		flame.spread = 22.0
		flame.initial_velocity_min = 45.0
		flame.initial_velocity_max = 95.0
		flame.gravity = Vector2(0, -60)
		flame.texture = load("res://assets/particles/flame.png") as Texture2D
		flame.scale_amount_min = 0.010
		flame.scale_amount_max = 0.022
		flame.color = Color(1.0, 0.55, 0.2, 0.9)
		add_child(flame)
		flame.emitting = true
		# fireflies circling the torchlight
		var flies := CPUParticles2D.new()
		flies.position = p + Vector2(0, -60)
		flies.amount = 8
		flies.lifetime = 4.0
		flies.preprocess = 4.0
		flies.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		flies.emission_rect_extents = Vector2(70, 50)
		flies.direction = Vector2(0, -1)
		flies.spread = 180.0
		flies.initial_velocity_min = 8.0
		flies.initial_velocity_max = 26.0
		flies.gravity = Vector2.ZERO
		flies.scale_amount_min = 1.2
		flies.scale_amount_max = 2.2
		flies.color = Color(0.75, 1.0, 0.45, 0.85)
		add_child(flies)
		flies.emitting = true
	# ability orbs glow in their own tint
	for orb in orbs:
		var o := orb as Node2D
		if o == null:
			continue
		var light := PointLight2D.new()
		light.texture = glow
		light.texture_scale = 3.0
		light.color = o.get("tint")
		light.energy = 1.4
		o.add_child(light)


# ------------------------------------------------------------ camera fx ---

func _build_camera_fx(player: Node2D) -> void:
	var cam := player.get_node("Camera2D") as Camera2D
	if cam == null:
		return
	# embers rising through the air
	var embers := CPUParticles2D.new()
	embers.amount = 26
	embers.lifetime = 6.0
	embers.preprocess = 6.0
	embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	embers.emission_rect_extents = Vector2(576, 324)
	embers.direction = Vector2(0, -1)
	embers.spread = 30.0
	embers.initial_velocity_min = 18.0
	embers.initial_velocity_max = 55.0
	embers.gravity = Vector2(0, -12)
	embers.texture = load("res://assets/particles/dot.png") as Texture2D
	embers.scale_amount_min = 0.008
	embers.scale_amount_max = 0.018
	embers.color = Color(1.0, 0.58, 0.22, 0.75)
	cam.add_child(embers)
	embers.emitting = true
	# slow dust motes drifting sideways
	var dust := CPUParticles2D.new()
	dust.amount = 30
	dust.lifetime = 9.0
	dust.preprocess = 9.0
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents = Vector2(576, 324)
	dust.direction = Vector2(1, 0)
	dust.spread = 45.0
	dust.initial_velocity_min = 8.0
	dust.initial_velocity_max = 26.0
	dust.gravity = Vector2.ZERO
	dust.scale_amount_min = 1.0
	dust.scale_amount_max = 2.4
	dust.color = Color(0.75, 0.85, 1.0, 0.28)
	cam.add_child(dust)
	dust.emitting = true
	# dead leaves tumbling down through the moonlight
	var leaves := CPUParticles2D.new()
	leaves.amount = 14
	leaves.lifetime = 11.0
	leaves.preprocess = 11.0
	leaves.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	leaves.emission_rect_extents = Vector2(576, 324)
	leaves.direction = Vector2(0, 1)
	leaves.spread = 55.0
	leaves.initial_velocity_min = 22.0
	leaves.initial_velocity_max = 48.0
	leaves.gravity = Vector2(0, 26)
	leaves.angular_velocity_min = -160.0
	leaves.angular_velocity_max = 160.0
	leaves.scale_amount_min = 2.2
	leaves.scale_amount_max = 3.8
	leaves.color = Color(0.42, 0.46, 0.24, 0.65)
	cam.add_child(leaves)
	leaves.emitting = true


# --------------------------------------------------------------- vignette ---

func _build_vignette() -> void:
	var layer := CanvasLayer.new()
	layer.name = "VignetteLayer"
	layer.layer = 4 # above the world, below the HUD (layer 5)
	add_child(layer)
	var rect := TextureRect.new()
	rect.texture = _make_vignette_texture()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(rect)


static func _make_vignette_texture(size: int = 256) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := size * 0.5
	for y in range(size):
		for x in range(size):
			var d := Vector2(x - c, y - c).length() / c
			var a := smoothstep(0.58, 1.02, d) * 0.6
			img.set_pixel(x, y, Color(0, 0, 0, a))
	return ImageTexture.create_from_image(img)
