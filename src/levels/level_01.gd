extends Node2D


const EnemyScene := preload("res://src/enemies/skeleton.tscn")
const OrbScene := preload("res://src/pickups/orb.tscn")
const CheckpointScene := preload("res://src/checkpoint/checkpoint.tscn")
const GoalScene := preload("res://src/goal/goal.tscn")
const CrackedFloorScript := preload("res://src/world/cracked_floor.gd")


const PLATFORMS: Array = [
	Rect2(0, 0, 560, 160),
	Rect2(680, 0, 380, 160),
	Rect2(1140, -70, 260, 230),
	Rect2(1460, -140, 260, 300),
	Rect2(1720, 0, 520, 160),
	Rect2(1900, -320, 70, 320),
	Rect2(2170, -320, 70, 320),


	Rect2(2360, -300, 300, 60),
	Rect2(2760, -560, 360, 60),
	Rect2(2760, 0, 360, 160),
	Rect2(3240, 0, 280, 160),
	Rect2(2820, -120, 100, 32),
	Rect2(3080, 160, 40, 160),
	Rect2(3240, 160, 40, 70),
	Rect2(3080, 320, 200, 40),

	# --- The Undercroft: opened up by pounding the cracked span above ---
	Rect2(3280, 320, 420, 40),
	Rect2(3520, 140, 180, 20),
	Rect2(3900, 320, 660, 40),
	Rect2(4150, -40, 70, 360),
	Rect2(4420, -40, 70, 360),
	Rect2(4620, -100, 220, 30),
	Rect2(4980, -220, 130, 26),
	Rect2(5240, -340, 130, 26),
	Rect2(5500, -460, 130, 26),
	Rect2(5630, -460, 420, 160),
	Rect2(6150, -460, 300, 160),
	Rect2(6010, -300, 40, 160),
	Rect2(6150, -300, 40, 160),
	Rect2(6010, -140, 180, 40),
]


const CRACKED: Array = [
	Rect2(3112, -30, 136, 30),
	Rect2(6050, -490, 100, 30),
]

const ENEMIES: Array = [
	[Vector2(800, -60), "warrior"],
	[Vector2(2950, -60), "spearman"],
	[Vector2(3250, -60), "archer"],
	[Vector2(3150, 260), "warrior"],

	# --- The Undercroft ---
	[Vector2(3520, 260), "warrior"],
	[Vector2(4000, 260), "spearman"],
	[Vector2(4320, 260), "warrior"],
	[Vector2(4760, -160), "archer"],
	[Vector2(5800, -520), "warrior"],
	[Vector2(5960, -520), "spearman"],
	[Vector2(6300, -520), "archer"],
]
const CHECKPOINTS: Array = [
	Vector2(1780, -60), Vector2(2440, -360), Vector2(2900, -60),
	Vector2(3380, 260), Vector2(3960, 260), Vector2(4660, -160), Vector2(5700, -520),
]
const ORB_POS := Vector2(2510, -380)
const POUND_ORB_POS := Vector2(2870, -180)
const POUND_ORB_TINT := Color("ff9a3c")
const GOAL_POS := Vector2(6100, -200)
const KILL_Y := 500.0

var player: MVPlayer
var hud
var respawning := false


func _ready() -> void:
	_build_background()
	_build_terrain()
	_build_hints()
	_spawn_actors()
	player = $Player
	hud = $HUD
	var cam: Camera2D = player.get_node("Camera2D")
	cam.limit_left = -40
	cam.limit_right = 6520
	cam.limit_top = -760
	cam.limit_bottom = 420
	player.health_changed.connect(hud.set_hearts)
	player.ability_gained.connect(hud.on_ability_gained)
	player.died.connect(_on_player_died)
	hud.set_hearts(player.hp, player.MAX_HP)


func _physics_process(_delta: float) -> void:
	if player != null and not player.dead and player.global_position.y > KILL_Y:
		player.kill()


func _build_terrain() -> void:
	var visual := TerrainVisual.new()
	visual.rects = PLATFORMS
	add_child(visual)
	for r in PLATFORMS:
		var rect: Rect2 = r
		var body := StaticBody2D.new()
		body.collision_layer = 4
		body.collision_mask = 0
		body.position = rect.get_center()
		var shape := CollisionShape2D.new()
		var rect_shape := RectangleShape2D.new()
		rect_shape.size = rect.size
		shape.shape = rect_shape
		body.add_child(shape)
		add_child(body)
	for r in CRACKED:
		var rect: Rect2 = r
		var slab: StaticBody2D = CrackedFloorScript.new()
		slab.rect = rect
		slab.position = rect.get_center()
		add_child(slab)


class TerrainVisual extends Node2D:
	var rects: Array = []

	func _draw() -> void:
		for r in rects:
			var rect: Rect2 = r
			draw_rect(rect, Color("1a2033"))

			draw_rect(Rect2(rect.position, Vector2(rect.size.x, 6)), Color("33406a"))

			draw_rect(rect, Color("0d1120"), false, 2.0)


func _build_background() -> void:

	var sky_layer := CanvasLayer.new()
	sky_layer.layer = -100
	var sky := ColorRect.new()
	sky.color = Color("0a0d18")
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	sky_layer.add_child(sky)
	add_child(sky_layer)

	var parallax := ParallaxBackground.new()
	add_child(parallax)

	var far := ParallaxLayer.new()
	far.motion_scale = Vector2(0.25, 0.25)
	var far_draw := FarMountains.new()
	far_draw.position = Vector2(0, 120)
	far.add_child(far_draw)
	parallax.add_child(far)

	var near := ParallaxLayer.new()
	near.motion_scale = Vector2(0.5, 0.5)
	var near_draw := NearHills.new()
	near_draw.position = Vector2(0, 200)
	near.add_child(near_draw)
	parallax.add_child(near)


class FarMountains extends Node2D:
	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 1234
		var pts := PackedVector2Array()
		pts.append(Vector2(-400, 400))
		var x := -400.0
		while x < 4400.0:
			pts.append(Vector2(x, -rng.randf_range(140.0, 330.0)))
			x += rng.randf_range(240.0, 430.0)
			pts.append(Vector2(x, -rng.randf_range(40.0, 130.0)))
			x += rng.randf_range(240.0, 430.0)
		pts.append(Vector2(4400, 400))
		draw_colored_polygon(pts, Color("121829"))

		draw_circle(Vector2(2900, -420), 86, Color(0.88, 0.91, 0.96, 0.1))
		draw_circle(Vector2(2900, -420), 66, Color("dfe6f5"))
		draw_circle(Vector2(2878, -438), 12, Color("c9d2e6"))
		draw_circle(Vector2(2922, -402), 8, Color("c9d2e6"))

		var srng := RandomNumberGenerator.new()
		srng.seed = 77
		for i in range(90):
			var p := Vector2(srng.randf_range(-300.0, 4300.0), srng.randf_range(-560.0, -40.0))
			draw_circle(p, srng.randf_range(1.0, 2.2), Color(1, 1, 1, srng.randf_range(0.25, 0.8)))


class NearHills extends Node2D:
	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 555
		var pts := PackedVector2Array()
		pts.append(Vector2(-400, 400))
		var x := -400.0
		while x < 4400.0:
			pts.append(Vector2(x, -rng.randf_range(30.0, 130.0)))
			x += rng.randf_range(300.0, 520.0)
		pts.append(Vector2(4400, 400))
		draw_colored_polygon(pts, Color("1a2340"))


func _make_hint(text: String, pos: Vector2) -> void:
	var hint := Label.new()
	hint.text = text
	hint.position = pos
	hint.add_theme_font_size_override("font_size", 26)
	hint.add_theme_color_override("font_color", Color("cfe0ff"))
	hint.add_theme_color_override("font_outline_color", Color("0a0d18"))
	hint.add_theme_constant_override("outline_size", 8)
	add_child(hint)


func _build_hints() -> void:

	_make_hint("WALL JUMP:\nhold toward the wall\n+ press JUMP", Vector2(1660, -250))

	_make_hint("GROUND POUND:\npress S / ↓ in midair", Vector2(2640, -240))
	_make_hint("CRACKED STONE:\npound it to smash\nthrough", Vector2(2960, -190))

	_make_hint("THE UNDERCROFT", Vector2(3300, 196))
	_make_hint("WALL JUMP the shaft\nto climb out", Vector2(3900, 60))
	_make_hint("One more cracked span\nstands between you\nand the way out", Vector2(5660, -600))


func _spawn_actors() -> void:
	for entry in ENEMIES:
		var w := EnemyScene.instantiate()
		w.kind = entry[1]
		w.position = entry[0]
		add_child(w)
	var orb := OrbScene.instantiate()
	orb.position = ORB_POS
	add_child(orb)
	var porb := OrbScene.instantiate()
	porb.position = POUND_ORB_POS
	porb.ability_id = "ground_pound"
	porb.tint = POUND_ORB_TINT
	add_child(porb)
	for pos in CHECKPOINTS:
		var c := CheckpointScene.instantiate()
		c.position = pos
		add_child(c)
	var goal := GoalScene.instantiate()
	goal.position = GOAL_POS
	goal.won.connect(_on_won)
	add_child(goal)


func _on_player_died() -> void:
	if respawning:
		return
	respawning = true
	await get_tree().create_timer(0.9).timeout
	player.respawn()
	respawning = false


func _on_won() -> void:
	hud.show_win()
