extends Node

## The fight as an ordinary player fights it.
##
## bossfair proves a bot with frame-perfect timing can win, which says nothing
## about a person. This bot is handicapped on purpose: it only reconsiders every
## REACTION frames, it aims for a position it cannot hold precisely, it fumbles
## a share of its inputs outright, and its pound timing wobbles. If THIS wins
## with health to spare, across several seeds, the fight is humane.
##
## Seeds are swept rather than fixed so the result is a hit rate, not one lucky
## run. SEEDS and the pass threshold are the difficulty contract: if a tuning
## change drops the win rate, this test says so.

const REACTION := 11             # ~180ms before it reacts to anything
const AIM_ERROR := 28.0          # px it can be off its intended spot
const FUMBLE := 0.12             # share of inputs simply missed
## Six rather than eight: this has to finish inside the 120s verify.py allows a
## suite, and rebuilding the arena per attempt is most of the cost. Still a win
## rate over several seeds rather than one lucky run.
const SEEDS := [1, 2, 3, 4, 5, 6]
const MAX_FRAMES := 2700         # 45s per attempt; wins take 14-19s
const NEED_WINS := 5             # of 6

## The test owns the level rather than living inside it, so an attempt can be
## torn down and rebuilt without taking the test down with it.
const LevelScene := preload("res://tests/fixtures/warden_arena.tscn")

var level: Node = null
var rng := RandomNumberGenerator.new()
var results: Array = []
var seed_i := 0
var failures: Array[String] = []

var player: Node = null
var boss: Node = null
var t := 0
var started := false
var held := {}
var decision := {}
var aim := 0.0
var hp_low := 99


func _ready() -> void:
	rng.seed = SEEDS[0]
	_build()


func _build() -> void:
	level = LevelScene.instantiate()
	add_child(level)


func check(cond: bool, label: String) -> void:
	if cond:
		print("  ok   ", label)
	else:
		failures.append(label)
		print("  FAIL ", label)


func hold(action: String, down: bool) -> void:
	if bool(held.get(action, false)) == down:
		return
	# A fumbled input is simply not sent. The bot believes it pressed the key.
	if down and rng.randf() < FUMBLE:
		return
	held[action] = down
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = down
	Input.parse_input_event(ev)


func tap(action: String) -> void:
	hold(action, false)
	hold(action, true)


func _release_all() -> void:
	for a in ["move_left", "move_right", "attack", "pound", "jump"]:
		held[a] = true
		hold(a, false)


func _physics_process(_delta: float) -> void:
	t += 1
	if t < 6:
		return
	if not started:
		started = true
		_begin()
		return
	if player == null:
		return

	if not is_instance_valid(boss) or bool(boss.get("dead")):
		_record(true)
		return
	if bool(player.get("dead")):
		_record(false)
		return
	hp_low = mini(hp_low, int(player.get("hp")))
	if t > MAX_FRAMES:
		_record(false)
		return

	# Reaction delay: the plan is refreshed only every REACTION frames, and the
	# bot acts on a stale picture in between, which is what a person does.
	if t % REACTION == 0:
		_think()
	_act()


func _begin() -> void:
	player = get_tree().get_first_node_in_group("player")
	boss = get_tree().get_first_node_in_group("boss")
	if player == null or boss == null:
		check(false, "player and Warden in the arena")
		_finish()
		return
	player.call("gain_ability", "double_jump")
	player.call("gain_ability", "ground_pound")
	player.global_position = Vector2(5860, -20)


func _think() -> void:
	var me: Vector2 = (player as Node2D).global_position
	var it: Vector2 = (boss as Node2D).global_position
	decision["dx"] = it.x - me.x
	decision["guarded"] = bool(boss.get("guarded"))
	decision["swinging"] = String(boss.get("state")) == "attack"
	aim = rng.randf_range(-AIM_ERROR, AIM_ERROR)


func _act() -> void:
	if decision.is_empty():
		return
	var me: Vector2 = (player as Node2D).global_position
	var it: Vector2 = (boss as Node2D).global_position
	var dx: float = it.x - me.x
	var toward: float = 1.0 if dx > 0.0 else -1.0
	var on_floor: bool = bool(player.call("is_on_floor"))

	if bool(decision["guarded"]):
		hold("attack", false)
		if bool(player.get("pounding")):
			hold("move_left", false)
			hold("move_right", false)
			return
		if on_floor:
			hold("pound", false)
			if absf(dx) > 210.0 + aim:
				hold("move_right", dx > 0.0)
				hold("move_left", dx < 0.0)
				return
			hold("move_right", false)
			hold("move_left", false)
			if absf(dx) < 95.0 + aim:
				tap("jump")
			return
		hold("move_right", dx > 20.0)
		hold("move_left", dx < -20.0)
		if absf(dx) < 80.0 and me.y < it.y - 90.0 \
				and float(player.get("velocity").y) > -140.0:
			tap("pound")
		return

	hold("pound", false)
	# Poke from the edge of your own reach -- the natural way to play it, and
	# the reason a reach change has to be re-measured rather than assumed.
	var reach: float = float(player.get("ATTACK_RANGE"))
	var want: float = (reach + 66.0 if bool(decision["swinging"]) else reach - 12.0) + aim
	var err: float = absf(dx) - want
	if absf(err) > 8.0:
		var go: float = toward if err > 0.0 else -toward
		hold("move_right", go > 0.0)
		hold("move_left", go < 0.0)
		hold("attack", false)
		return
	if float(player.get("facing")) != toward:
		hold("move_right", toward > 0.0)
		hold("move_left", toward < 0.0)
		return
	hold("move_right", false)
	hold("move_left", false)
	if not bool(decision["swinging"]) and float(player.get("attack_cd")) <= 0.0:
		tap("attack")
	else:
		hold("attack", false)


func _record(won: bool) -> void:
	var hp: int = 0 if player == null else int(player.get("hp"))
	results.append({"seed": SEEDS[seed_i], "won": won, "hp": hp,
		"secs": t / 60.0, "boss_hp": _boss_hp()})
	print("  seed %d: %s  (%.1fs, player hp %d, Warden hp %d)"
		% [SEEDS[seed_i], "WON " if won else "lost", t / 60.0, hp, _boss_hp()])
	seed_i += 1
	if seed_i >= SEEDS.size():
		_report()
		return
	_reset()


func _boss_hp() -> int:
	if boss == null or not is_instance_valid(boss):
		return 0
	return int(boss.get("hp"))


## Each attempt gets a fresh level, so a run cannot inherit the last one's
## wreckage.
func _reset() -> void:
	_release_all()
	rng.seed = SEEDS[seed_i]
	t = 0
	started = false
	hp_low = 99
	decision.clear()
	player = null
	boss = null
	# A win panel pauses the tree; make sure an attempt never starts frozen.
	get_tree().paused = false
	if is_instance_valid(level):
		level.queue_free()
	level = null
	await get_tree().process_frame
	_build()


func _report() -> void:
	var wins := 0
	var total_hp := 0
	for r in results:
		if bool(r["won"]):
			wins += 1
			total_hp += int(r["hp"])
	print("  %d of %d attempts won" % [wins, results.size()])
	if wins > 0:
		print("  average hearts left on a win: %.1f of 6" % (float(total_hp) / float(wins)))
	check(wins >= NEED_WINS,
		"a clumsy player wins %d of %d (need %d)" % [wins, results.size(), NEED_WINS])
	_finish()


func _finish() -> void:
	if failures.is_empty():
		print("BOSSCLUMSY TESTS ALL PASSED")
	else:
		print("BOSSCLUMSY TESTS: %d FAILURES -> %s" % [failures.size(), str(failures)])
	get_tree().quit(1 if failures.size() > 0 else 0)
