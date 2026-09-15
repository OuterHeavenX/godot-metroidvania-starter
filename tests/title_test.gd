extends Node

## Title screen. Setup runs in _enter_tree, which fires for every node before
## any _ready, so SaveMan is already in the wanted state when the title reads it.

const META := "title_test_run"

var failures: Array[String] = []
var t := 0
var run := 0


func check(cond: bool, label: String) -> void:
	if cond:
		print("  ok   ", label)
	else:
		failures.append(label)
		print("  FAIL ", label)


func _enter_tree() -> void:
	run = int(get_tree().get_meta(META, 0))
	if run == 0:
		SaveMan.clear_progress()
		SaveMan.best_time = 0.0
		SaveMan.runs = 0
	else:
		SaveMan.abilities = ["double_jump"]
		SaveMan.has_checkpoint = true
		SaveMan.checkpoint = Vector2(1780, -70)
		SaveMan.best_time = 91.25
		SaveMan.runs = 2
	SaveMan.save_progress()


func _process(_delta: float) -> void:
	t += 1
	if t < 4:
		return
	var title := get_parent().get_node_or_null("Title")
	check(title != null, "title screen built (run %d)" % run)
	if title == null:
		_finish()
		return
	var cont: Button = title.get_node("Center/VBox/Continue")
	var stats: Label = title.get_node("Center/VBox/Stats")
	if run == 0:
		check(not cont.visible, "continue hidden with no progress")
		check(stats.text == "", "no stats line on a fresh save")
		get_tree().set_meta(META, 1)
		get_tree().reload_current_scene()
		return # The replacement scene owns the next test phase.
	else:
		check(cont.visible, "continue shown when progress exists")
		check("1:31.25" in stats.text, "best time shown, got %s" % stats.text)
		check("2 clears" in stats.text, "clear count shown, got %s" % stats.text)
		SaveMan.clear_progress()
		SaveMan.best_time = 0.0
		SaveMan.runs = 0
		SaveMan.save_progress()
		_finish()


func _finish() -> void:
	get_tree().set_meta(META, 0)
	if failures.is_empty():
		print("TITLE TESTS ALL PASSED")
	else:
		print("TITLE TESTS: %d FAILURES -> %s" % [failures.size(), str(failures)])
	get_tree().quit(1 if failures.size() > 0 else 0)
