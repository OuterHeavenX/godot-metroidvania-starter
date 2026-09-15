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
const BossScene := preload("res://src/enemies/boss.tscn")

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
	AudioMan.play_music(data.music)
	_build_background()
	_build_terrain()
	_build_hints()
	# The boss wires itself to the HUD as it spawns, so resolve these first.
	player = $Player
	hud = $HUD
	_spawn_actors()
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
	player.checkpoint_set.connect(_on_checkpoint_set)
	player.died.connect(_on_player_died)
	hud.set_hearts(player.hp, player.MAX_HP)
	_restore_progress()


func scene_path() -> String:
	return scene_file_path


func _on_checkpoint_set(pos: Vector2) -> void:
	SaveMan.note_checkpoint(pos, scene_path())


## Only applied when the title screen asked to continue, or when arriving from
## the previous area. A level opened directly -- by a test, or from the editor
## -- always starts clean.
func _restore_progress() -> void:
	if not SaveMan.resume_requested:
		return
	SaveMan.resume_requested = false
	for ability_id in SaveMan.abilities:
		player.gain_ability(ability_id)
	# A checkpoint only means something inside the area it was set in.
	if SaveMan.checkpoint_for(scene_path()):
		player.set_checkpoint(SaveMan.checkpoint)
		player.global_position = SaveMan.checkpoint


func _physics_process(delta: float) -> void:
	if not finished:
		elapsed += delta
	if player != null and not player.dead and player.global_position.y > data.kill_y:
		player.kill()


func _build_terrain() -> void:
	var visual := TerrainVisual.new()
	visual.theme = data.theme
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
		slab.theme = data.theme
		slab.rect = rect
		slab.position = rect.get_center()
		add_child(slab)


class TerrainVisual extends Node2D:
	var rects: Array = []
	var theme := "cemetery"

	func _draw() -> void:
		for r in rects:
			var rect: Rect2 = r
			if theme == "castle":
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


func _build_background() -> void:
	MVBackdrop.build(self, data.theme, data.background_span)


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
	if data.has_boss:
		var boss := BossScene.instantiate()
		boss.position = data.boss_position
		# Connect before adding: the boss announces itself from _ready(), which
		# runs the moment it enters the tree.
		boss.engaged.connect(hud.boss_engaged)
		boss.hp_changed.connect(hud.boss_hp)
		boss.guard_changed.connect(hud.boss_guard)
		boss.blocked.connect(hud.boss_blocked)
		boss.defeated.connect(hud.boss_defeated)
		add_child(boss)
		goal.lock()
		boss.defeated.connect(goal.unlock)


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
	if data.next_level != "":
		SaveMan.note_area_cleared(data.next_level, elapsed)
		hud.show_area_cleared(data.next_level, SaveMan.run_time)
		return
	var total := SaveMan.run_time + elapsed
	var previous_best := SaveMan.best_time
	SaveMan.note_win(total)
	hud.show_win(total, previous_best)
