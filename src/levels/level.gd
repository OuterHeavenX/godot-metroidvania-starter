class_name MVLevel
extends Node2D

## Composition root: wires gameplay, content builders, presentation and saving.
@export var data: MVLevelData
var player: MVPlayer
var hud: CanvasLayer
var respawning := false
var elapsed := 0.0
var finished := false
var encounters: MVEncounterController
var terrain: MVTerrainBuilder
var pickups: MVPickupBuilder

func _ready() -> void:
	if data == null:
		push_error("MVLevel requires MVLevelData")
		return
	var problems := data.validation_errors()
	if not problems.is_empty():
		push_error("Invalid level data: " + str(problems))
		return
	player = $Player
	hud = $HUD
	var continuing := SaveMan.resume_requested
	SaveMan.resume_requested = false
	SaveMan.begin_area(scene_path(), continuing)
	elapsed = SaveMan.snapshot.area_time
	if data.player_start != Vector2.ZERO:
		player.position = data.player_start
	player.spawn_point = player.global_position
	if continuing:
		for id in SaveMan.abilities:
			player.gain_ability(id)
		if SaveMan.checkpoint_for(scene_path()) and data.camera_limits.grow(128.0).has_point(SaveMan.checkpoint):
			player.spawn_point = SaveMan.checkpoint
			player.global_position = SaveMan.checkpoint
	var cam := player.camera
	cam.limit_left = int(data.camera_limits.position.x)
	cam.limit_top = int(data.camera_limits.position.y)
	cam.limit_right = int(data.camera_limits.end.x)
	cam.limit_bottom = int(data.camera_limits.end.y)
	cam.reset_smoothing()
	player.health_changed.connect(hud.set_hearts)
	player.ability_gained.connect(hud.on_ability_gained)
	player.ability_gained.connect(_on_ability_gained)
	player.checkpoint_set.connect(_on_checkpoint_set)
	player.died.connect(_on_player_died)
	hud.set_hearts(player.hp, player.MAX_HP)
	for id in SaveMan.abilities:
		hud.on_ability_gained(id)
	MVLevelPresentation.background(self, data)
	var cleared: Dictionary = SaveMan.snapshot.world.get(data.area_id, {})
	terrain = MVTerrainBuilder.new()
	terrain.name = "Terrain"
	terrain.world_changed.connect(_on_world_changed)
	add_child(terrain)
	terrain.build(data, cleared)
	pickups = MVPickupBuilder.new()
	pickups.name = "Pickups"
	pickups.world_changed.connect(_on_world_changed)
	add_child(pickups)
	pickups.build(data, cleared, SaveMan.abilities)
	encounters = MVEncounterController.new()
	encounters.name = "Encounters"
	encounters.world_changed.connect(_on_world_changed)
	encounters.won.connect(_on_won)
	encounters.boss_spawned.connect(func(boss: MVBoss) -> void: hud.bind_boss(boss, player))
	add_child(encounters)
	encounters.build(data, cleared)
	MVLevelPresentation.dress(self, data, player, pickups.orbs)

func scene_path() -> String:
	return scene_file_path

func _sync_clock() -> void:
	if not finished:
		SaveMan.level_path = scene_path()
		SaveMan.update_area_time(scene_path(), elapsed)

func _on_world_changed(id: String) -> void:
	_sync_clock()
	SaveMan.note_world(data.area_id, id)

func _on_ability_gained(id: String) -> void:
	_sync_clock()
	SaveMan.note_ability(id)

func _on_checkpoint_set(pos: Vector2) -> void:
	_sync_clock()
	SaveMan.note_checkpoint(pos, scene_path())

func _physics_process(delta: float) -> void:
	if player == null:
		return
	if not finished:
		elapsed += delta
		SaveMan.update_area_time(scene_path(), elapsed)
	if not player.dead and player.global_position.y > data.kill_y:
		player.kill()

func _exit_tree() -> void:
	SaveMan.flush()

func _on_player_died() -> void:
	if respawning:
		return
	respawning = true
	await get_tree().create_timer(0.9, false).timeout
	encounters.reset_survivors()
	player.respawn()
	respawning = false

func _on_won() -> void:
	if finished:
		return
	_sync_clock()
	finished = true
	if data.next_level != "":
		SaveMan.note_area_cleared(data.next_level, elapsed)
		hud.show_area_cleared(data.next_level, SaveMan.run_time)
		return
	var total := SaveMan.run_time + elapsed
	var previous_best := SaveMan.best_time
	SaveMan.note_win(total)
	hud.show_win(total, previous_best)
