extends Node

var failures := 0
const LEVEL := "res://src/levels/level_01.tscn"

func check(ok: bool, message: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + message)
	if not ok:
		failures += 1

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	# Legacy migration and typed field validation are exercised without a level.
	var legacy := ConfigFile.new()
	legacy.set_value("progress", "abilities", PackedStringArray(["double_jump", "invalid", "double_jump"]))
	legacy.set_value("progress", "has_checkpoint", true)
	legacy.set_value("progress", "checkpoint", Vector2(1780, -70))
	legacy.set_value("stats", "best_time", 95.0)
	legacy.set_value("audio", "muted", true)
	legacy.save(SaveMan.PATH)
	SaveMan.load_progress()
	check(SaveMan.abilities == ["double_jump"], "legacy abilities migrate and unknown/duplicate IDs are filtered")
	check(SaveMan.checkpoint_for(LEVEL), "legacy checkpoint is assigned to its area")
	check(SaveMan.snapshot.area_time == 0.0 and SaveMan.best_time == 95.0, "legacy timing initializes while records survive")
	SaveMan.save_progress()
	var reread := ConfigFile.new()
	reread.load(SaveMan.PATH)
	check(reread.get_value("progress", "version") == 2 and reread.get_value("audio", "muted") == true, "versioned write preserves audio settings")
	var malformed := ConfigFile.new()
	malformed.set_value("progress", "checkpoint", "bad")
	malformed.set_value("progress", "run_time", -99)
	malformed.set_value("progress", "area_time", INF)
	malformed.set_value("progress", "world", {"hollowmere": "bad", 17: {"x": true}})
	var sanitized := MVRunSnapshot.read(malformed)
	check(not sanitized.has_checkpoint and sanitized.run_time == 0.0 and sanitized.area_time == 0.0 and sanitized.world.is_empty(), "malformed snapshot fields cannot poison gameplay")
	reread.set_value("progress", "version", 999)
	reread.save(SaveMan.PATH)
	var before := FileAccess.get_file_as_bytes(SaveMan.PATH)
	SaveMan.load_progress()
	SaveMan.clear_progress()
	check(not SaveMan.writable and FileAccess.get_file_as_bytes(SaveMan.PATH) == before, "future save version is never overwritten")
	reread.set_value("progress", "version", 2)
	reread.save(SaveMan.PATH)
	SaveMan.load_progress()
	SaveMan.clear_progress()
	# File corruption falls back to the previous complete snapshot.
	SaveMan.note_ability("double_jump")
	SaveMan.note_ability("ground_pound")
	var broken := FileAccess.open(SaveMan.PATH, FileAccess.WRITE)
	broken.store_string("[unterminated")
	broken.close()
	SaveMan.load_progress()
	check("double_jump" in SaveMan.abilities, "corrupt primary file recovers the previous snapshot")
	SaveMan.clear_progress()

	var level: MVLevel = load(LEVEL).instantiate()
	add_child(level)
	await get_tree().physics_frame
	level.set_physics_process(false)
	var player := level.player
	player.set_physics_process(false)
	player.invuln = 999.0
	check(level.data.validation_errors().is_empty() and level.terrain != null and level.encounters != null and level.pickups != null, "authored IDs validate and focused level systems are wired")
	level.elapsed = 42.5
	player.gain_ability("double_jump")
	player.gain_ability("ground_pound")
	var checkpoint: Node2D = get_tree().get_first_node_in_group("checkpoint")
	checkpoint.call("_on_body", player)
	var point := player.spawn_point
	var slab: MVCrackedFloor = get_tree().get_first_node_in_group("cracked")
	var slab_id: String = slab.get_meta("persistence_id")
	slab.break_floor()
	var heart: MVHeart = get_tree().get_first_node_in_group("heart")
	var heart_id: String = heart.get_meta("persistence_id")
	player.hp = 4
	heart._on_body(player)
	var enemy := level.encounters.enemies[0]
	var enemy_id: String = enemy.get_meta("persistence_id")
	enemy.die()
	var survivor := level.encounters.enemies[1]
	survivor.take_hit(survivor.global_position - Vector2(survivor.dir * 40, 0))
	var survivor_id: String = survivor.get_meta("persistence_id")
	level.encounters.boss.squash()
	var expected_enemies := level.encounters.enemies.size() - 1
	await get_tree().physics_frame
	check(SaveMan.snapshot.contains(level.data.area_id, slab_id) and SaveMan.snapshot.contains(level.data.area_id, heart_id) and SaveMan.snapshot.contains(level.data.area_id, enemy_id), "world events persist floor, reward and defeated enemy IDs")
	# Real death path, including its delay and encounter reset.
	player.kill()
	await get_tree().create_timer(1.1, true, false, true).timeout
	check(not player.dead and player.hp == player.MAX_HP and player.global_position == point, "death returns a healed player to the checkpoint")
	check(level.encounters.enemies.size() == expected_enemies and level.encounters.boss.guarded, "death retains kills and resets surviving boss guard")
	for foe in level.encounters.enemies:
		if foe.get_meta("persistence_id") == survivor_id:
			check(foe.hp == int(foe.cfg.hp), "surviving enemy health resets on retry")
	var moved: MVLevelData = level.data.duplicate(true)
	moved.heart_spawns.reverse()
	for spawn in moved.heart_spawns:
		if spawn.persistence_id == heart_id:
			spawn.position += Vector2(123, -45)
			check(SaveMan.snapshot.contains(moved.area_id, spawn.persistence_id), "moving and reordering authored content retains its saved identity")
	SaveMan.flush()
	remove_child(level)
	level.queue_free()
	await get_tree().process_frame
	SaveMan.load_progress()
	SaveMan.resume_requested = true
	level = load(LEVEL).instantiate()
	add_child(level)
	level.set_physics_process(false)
	level.player.set_physics_process(false)
	check(is_equal_approx(level.elapsed, 42.5), "Continue restores current-area time without resetting the record clock")
	check(level.player.spawn_point == point and level.player.has_double_jump and level.player.has_ground_pound, "Continue restores checkpoint and abilities")
	check(level.encounters.enemies.size() == expected_enemies and level.encounters.boss.guarded, "Continue and death use the same surviving encounter state")
	var restored_ids: Array[String] = []
	for group in ["cracked", "heart", "enemy"]:
		for node in get_tree().get_nodes_in_group(group):
			restored_ids.append(node.get_meta("persistence_id", ""))
	check(slab_id not in restored_ids and heart_id not in restored_ids and enemy_id not in restored_ids, "Continue does not resurrect opened floors, rewards or defeated enemies")
	var boss := level.encounters.boss
	boss.die()
	check(not level.encounters.goal.locked, "defeated boss unlocks its encounter")
	remove_child(level)
	level.queue_free()
	await get_tree().process_frame
	SaveMan.load_progress()
	SaveMan.resume_requested = true
	level = load(LEVEL).instantiate()
	add_child(level)
	level.set_physics_process(false)
	level.player.set_physics_process(false)
	check(level.encounters.boss == null and not level.encounters.goal.locked, "defeated boss and unlocked exit survive reload")
	level.elapsed = 43.5
	level._sync_clock()
	SaveMan._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	SaveMan.load_progress()
	check(SaveMan.snapshot.area_time == 43.5, "focus loss flushes the current clock")
	SaveMan.note_area_cleared("res://src/levels/level_02.tscn", 42.5)
	check(SaveMan.run_time == 43.5 and SaveMan.snapshot.area_time == 0.0 and not SaveMan.has_checkpoint, "transition banks elapsed time exactly once and clears area checkpoint")
	SaveMan.note_win(100.0)
	var wins := SaveMan.runs
	SaveMan.note_win(100.0)
	check(SaveMan.runs == wins and not SaveMan.has_run(), "completion is idempotent and cannot Continue for another record")
	SaveMan.clear_progress()
	check(SaveMan.snapshot.world.is_empty() and SaveMan.runs == wins, "new run clears world state but keeps records")
	remove_child(level)
	level.queue_free()
	await get_tree().process_frame
	if failures == 0:
		print("ARCHITECTURE TESTS ALL PASSED")
	get_tree().quit(failures)
