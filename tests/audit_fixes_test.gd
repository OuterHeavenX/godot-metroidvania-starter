extends Node

var failures := 0

func check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		print("  FAIL ", label)

func _ready() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "version", MVRunSnapshot.VERSION)
	cfg.set_value("stats", "best_time", 12.0)
	cfg.set_value("stats", "runs", 7)
	cfg.save(SaveMan.PATH)
	SaveMan.load_progress()
	check(SaveMan.best_time == 0.0 and SaveMan.runs == 0, "legacy records do not compete with this campaign")
	SaveMan.note_win(120.0)
	SaveMan.load_progress()
	check(SaveMan.best_time == 120.0 and SaveMan.runs == 1, "current campaign records survive reload")
	cfg.load(SaveMan.PATH)
	check(cfg.get_value("stats", "best_time") == 12.0 and cfg.get_value("stats", "runs") == 7, "legacy records remain archived")
	SaveMan.clear_progress()
	SaveMan.note_win(150.0)
	check(SaveMan.best_time == 120.0 and SaveMan.runs == 2, "slower run does not replace current record")
	SaveMan.clear_progress()
	SaveMan.note_win(100.0)
	check(SaveMan.best_time == 100.0, "faster run updates current record")
	SaveMan.clear_progress()
	var level: MVLevel = load("res://src/levels/level_03.tscn").instantiate()
	add_child(level)
	await get_tree().process_frame
	level.player.global_position = Vector2(500, -600)
	level.player._throw_dagger()
	var dagger := get_tree().get_first_node_in_group("dagger")
	var arrow := MVArrow.new()
	level.encounters.add_child(arrow)
	# A different scene's projectile must not be removed by this encounter.
	var unrelated := MVDagger.new()
	add_child(unrelated)
	level.encounters.reset_survivors()
	level.player.respawn()
	check(not dagger.is_inside_tree() and not arrow.is_inside_tree(), "both projectile types detach before restarted enemies can be hit")
	check(unrelated.is_inside_tree(), "reset is scoped to this level")
	check(level.player.throw_cd == 0.0, "respawn clears throw cooldown")
	await get_tree().process_frame
	check(not is_instance_valid(dagger) and not is_instance_valid(arrow), "detached projectiles are freed")
	if failures == 0:
		print("AUDIT FIXES TESTS ALL PASSED")
	get_tree().quit(failures)
