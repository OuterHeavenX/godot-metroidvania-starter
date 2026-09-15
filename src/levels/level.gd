class_name MVLevel
extends Node2D

## Builds an area from an MVLevelData resource. The scene supplies the player,
## the HUD and the touch controls; everything about the area itself -- terrain,
## actors, bounds, signs -- comes from `data`, so a new area is a new .tres.

const EnemyScene := preload("res://src/enemies/skeleton.tscn")
const OrbScene := preload("res://src/pickups/orb.tscn")
const CheckpointScene := preload("res://src/checkpoint/checkpoint.tscn")
const GoalScene := preload("res://src/goal/goal.tscn")
const CrackedFloorScript := preload("res://src/world/cracked_floor.gd")
const HeartScript := preload("res://src/pickups/heart.gd")

@export var data: MVLevelData

var player: MVPlayer
var hud
var respawning := false
var elapsed := 0.0
var finished := false


func _ready() -> void:
	if data == null:
		push_error("MVLevel has no MVLevelData assigned; nothing to build.")
		return
	_build_background()
	_build_terrain()
	_build_hints()
	_spawn_actors()
	player = $Player
	hud = $HUD
	if data.player_start != Vector2.ZERO:
		player.position = data.player_start
	var cam: Camera2D = player.get_node("Camera2D")
	cam.limit_left = int(data.camera_limits.position.x)
	cam.limit_top = int(data.camera_limits.position.y)
	cam.limit_right = int(data.camera_limits.end.x)
	cam.limit_bottom = int(data.camera_limits.end.y)
	player.health_changed.connect(hud.set_hearts)
	player.ability_gained.connect(hud.on_ability_gained)
	player.ability_gained.connect(SaveMan.note_ability)
	player.checkpoint_set.connect(SaveMan.note_checkpoint)
	player.died.connect(_on_player_died)
	hud.set_hearts(player.hp, player.MAX_HP)
	_restore_progress()


## Only applied when the title screen asked to continue, so a level opened
## directly -- by a test, or from the editor -- always starts clean.
func _restore_progress() -> void:
	if not SaveMan.resume_requested:
		return
	SaveMan.resume_requested = false
	for ability_id in SaveMan.abilities:
		player.gain_ability(ability_id)
	if SaveMan.has_checkpoint:
		player.set_checkpoint(SaveMan.checkpoint)
		player.global_position = SaveMan.checkpoint


func _physics_process(delta: float) -> void:
	if not finished:
		elapsed += delta
	if player != null and not player.dead and player.global_position.y > data.kill_y:
		player.kill()


func _build_terrain() -> void:
	var visual := TerrainVisual.new()
	visual.rects = data.platforms
	add_child(visual)
	for rect in data.platforms:
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
	for rect in data.cracked:
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
	far_draw.span = data.background_span
	far_draw.position = Vector2(0, 120)
	far.add_child(far_draw)
	parallax.add_child(far)

	var near := ParallaxLayer.new()
	near.motion_scale = Vector2(0.5, 0.5)
	var near_draw := NearHills.new()
	near_draw.span = data.background_span
	near_draw.position = Vector2(0, 200)
	near.add_child(near_draw)
	parallax.add_child(near)


class FarMountains extends Node2D:
	var span := Vector2(-400, 4400)

	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 1234
		var pts := PackedVector2Array()
		pts.append(Vector2(span.x, 400))
		var x := span.x
		while x < span.y:
			pts.append(Vector2(x, -rng.randf_range(140.0, 330.0)))
			x += rng.randf_range(240.0, 430.0)
			pts.append(Vector2(x, -rng.randf_range(40.0, 130.0)))
			x += rng.randf_range(240.0, 430.0)
		pts.append(Vector2(span.y, 400))
		draw_colored_polygon(pts, Color("121829"))

		draw_circle(Vector2(2900, -420), 86, Color(0.88, 0.91, 0.96, 0.1))
		draw_circle(Vector2(2900, -420), 66, Color("dfe6f5"))
		draw_circle(Vector2(2878, -438), 12, Color("c9d2e6"))
		draw_circle(Vector2(2922, -402), 8, Color("c9d2e6"))

		var srng := RandomNumberGenerator.new()
		srng.seed = 77
		for i in range(90):
			var p := Vector2(srng.randf_range(span.x + 100.0, span.y - 100.0),
				srng.randf_range(-560.0, -40.0))
			draw_circle(p, srng.randf_range(1.0, 2.2), Color(1, 1, 1, srng.randf_range(0.25, 0.8)))


class NearHills extends Node2D:
	var span := Vector2(-400, 4400)

	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 555
		var pts := PackedVector2Array()
		pts.append(Vector2(span.x, 400))
		var x := span.x
		while x < span.y:
			pts.append(Vector2(x, -rng.randf_range(30.0, 130.0)))
			x += rng.randf_range(300.0, 520.0)
		pts.append(Vector2(span.y, 400))
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
	for h in data.hints:
		_make_hint(h.text, h.position)


func _spawn_actors() -> void:
	for spawn in data.enemies:
		var foe := EnemyScene.instantiate()
		foe.kind = spawn.kind
		foe.position = spawn.position
		add_child(foe)
	for spawn in data.orbs:
		var orb := OrbScene.instantiate()
		orb.position = spawn.position
		orb.ability_id = spawn.ability_id
		orb.tint = spawn.tint
		add_child(orb)
	for hpos in data.hearts:
		var heart: Area2D = HeartScript.new()
		heart.position = hpos
		add_child(heart)
	for pos in data.checkpoints:
		var c := CheckpointScene.instantiate()
		c.position = pos
		add_child(c)
	var goal := GoalScene.instantiate()
	goal.position = data.goal_position
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
	if finished:
		return
	finished = true
	var previous_best := SaveMan.best_time
	SaveMan.note_win(elapsed)
	hud.show_win(elapsed, previous_best)
