extends Node

## Loads every GDScript in the project so a parse or compile error fails the
## build. Godot's exporter exits 0 on a broken script, and running
## `--check-only --script` per file cannot resolve class_name or autoload
## references, so neither is usable as a gate on its own. Running inside the
## project gives each script its real context.


func _collect(dir: String, acc: Array) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	d.list_dir_begin()
	var n := d.get_next()
	while n != "":
		var p := dir.path_join(n)
		if d.current_is_dir():
			_collect(p, acc)
		elif n.ends_with(".gd"):
			acc.append(p)
		n = d.get_next()
	d.list_dir_end()


func _ready() -> void:
	var scripts: Array = []
	_collect("res://src", scripts)
	_collect("res://tests", scripts)
	scripts.sort()
	var bad: Array = []
	for p in scripts:
		var r = ResourceLoader.load(p)
		# A script that failed to parse still comes back as a GDScript object,
		# so null is not the signal — can_instantiate() is.
		if r == null or not (r as GDScript).can_instantiate():
			bad.append(p)
	if bad.is_empty():
		print("SCRIPT CHECK OK: %d scripts loaded" % scripts.size())
		get_tree().quit(0)
	else:
		print("SCRIPT CHECK FAILED: %d of %d -> %s" % [bad.size(), scripts.size(), str(bad)])
		get_tree().quit(1)
