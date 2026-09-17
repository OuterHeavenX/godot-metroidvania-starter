extends Node

## Every shipped area, built for real and checked.
##
## Two new areas were authored from a layout script; this is what stops that
## script's arithmetic from being the only thing standing behind them. It
## builds each level, lets the player fall, and confirms the ground is where
## the data says it is -- plus the structural things that make a level loadable
## at all, which a dangling id or a missing area_id quietly breaks.

const LEVELS := [
	"res://src/levels/level_01.tscn",
	"res://src/levels/level_02.tscn",
	"res://src/levels/level_03.tscn",
	"res://src/levels/level_04.tscn",
]
## From tools/recover/jumpsim.py. Anything past this cannot be jumped.
const DOUBLE_REACH := {0: 481.0, 60: 464.0, 120: 442.0, 180: 416.0, 240: 386.0, 295: 321.0}
const SAFE_FRACTION := 0.85

var failures: Array[String] = []
var index := 0
var level: Node = null
var t := 0


func check(cond: bool, label: String) -> void:
	if cond:
		print("  ok   ", label)
	else:
		failures.append(label)
		print("  FAIL ", label)


func _reach_for(rise: float) -> float:
	var best := 321.0
	var keys := DOUBLE_REACH.keys()
	keys.sort()
	for k in keys:
		if rise <= float(k):
			return float(DOUBLE_REACH[k])
	return best


func _ready() -> void:
	_load(0)


func _load(i: int) -> void:
	index = i
	t = 0
	if is_instance_valid(level):
		level.queue_free()
	level = load(LEVELS[i]).instantiate()
	add_child(level)


func _physics_process(_delta: float) -> void:
	t += 1
	if t < 30:
		return
	var name: String = LEVELS[index].get_file()
	var data = level.get("data")
	check(data != null, "%s carries level data" % name)
	if data != null:
		check(data.validation_errors().is_empty(),
			"%s validates: %s" % [name, str(data.validation_errors())])
		_check_gaps(name, data)
		_check_reachable(name, data)
	var player = level.get("player")
	check(player != null, "%s has a player" % name)
	if player != null:
		check(bool(player.call("is_on_floor")),
			"%s: the player starts on solid ground, not in a pit" % name)
		check(not bool(player.get("dead")), "%s: and is alive after settling" % name)
	var goal = get_tree().get_first_node_in_group("goal")
	check(goal != null, "%s has an exit" % name)

	if index + 1 < LEVELS.size():
		_load(index + 1)
	else:
		_finish()


## Consecutive ground surfaces, left to right, must be within a double jump.
func _check_gaps(name: String, data) -> void:
	var tops: Array = []
	for r in data.platforms:
		var rect: Rect2 = r
		# Tall narrow blocks are walls to jump off, not floors to land on.
		if rect.size.x >= 100.0:
			tops.append(rect)
	tops.sort_custom(func(a: Rect2, b: Rect2) -> bool: return a.position.x < b.position.x)
	var worst := 0.0
	var worst_at := 0.0
	for i in range(tops.size() - 1):
		var a: Rect2 = tops[i]
		var b: Rect2 = tops[i + 1]
		var gap: float = b.position.x - a.end.x
		if gap <= 0.0:
			continue
		var rise: float = a.position.y - b.position.y
		var limit: float = _reach_for(maxf(rise, 0.0)) if rise >= 0.0 else 503.0
		var frac: float = gap / limit
		if frac > worst:
			worst = frac
			worst_at = b.position.x
	check(worst < SAFE_FRACTION,
		"%s: hardest hop is %.0f%% of a double jump (at x=%.0f)" % [name, worst * 100.0, worst_at])


## Everything the player must touch has to sit over a platform, or it is
## floating in a pit where it cannot be collected or fought.
func _check_reachable(name: String, data) -> void:
	var spots: Array = []
	for e in data.enemies:
		spots.append(["enemy", e.position])
	for h in data.heart_spawns:
		spots.append(["heart", h.position])
	for c in data.checkpoint_spawns:
		spots.append(["checkpoint", c.position])
	for o in data.orbs:
		spots.append(["orb", o.position])
	spots.append(["exit", data.goal_position])
	var stranded: Array[String] = []
	for entry in spots:
		var pos: Vector2 = entry[1]
		var supported := false
		for r in data.platforms:
			var rect: Rect2 = r
			# Directly above a surface, within a fall the player survives.
			if pos.x >= rect.position.x - 20.0 and pos.x <= rect.end.x + 20.0 \
					and rect.position.y >= pos.y - 40.0 and rect.position.y <= pos.y + 520.0:
				supported = true
				break
		if not supported:
			stranded.append("%s at %s" % [entry[0], str(pos)])
	check(stranded.is_empty(), "%s: nothing is stranded over a pit %s" % [name, str(stranded)])


func _finish() -> void:
	if failures.is_empty():
		print("LEVELS TESTS ALL PASSED")
	else:
		print("LEVELS TESTS: %d FAILURES -> %s" % [failures.size(), str(failures)])
	get_tree().quit(1 if failures.size() > 0 else 0)
