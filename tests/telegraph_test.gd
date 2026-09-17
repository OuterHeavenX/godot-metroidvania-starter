extends Node

## How long you get between an enemy deciding to hit you and the blow landing.
##
## Reported as: "I usually can't get a chance to attack before they attack me."
## The wind-up was 0.247s, about fifteen frames, which is roughly human
## reaction time -- the tell was over before it could be acted on. Worse, the
## attack cooldown only started after a swing, so the first enemy you walked up
## to swung on the frame you entered its reach.
##
## These are floors, not exact values: tuning may lengthen them, but dropping
## back under a reactable window is the regression this catches.

const LevelScene := preload("res://tests/fixtures/warden_arena.tscn")
## Comfortably above the ~0.25s a person needs to see a tell and respond.
const MIN_WINDUP_FRAMES := 22
## A swing must not land on the frame the player steps into reach.
const MIN_NOTICE_FRAMES := 14

var failures: Array[String] = []
var level: Node = null
var player: Node = null
var boss: Node = null
var t := 0
var entered_range_at := -1
var attack_began_at := -1
var struck_at := -1
var hp_before := 0


func check(cond: bool, label: String) -> void:
	if cond:
		print("  ok   ", label)
	else:
		failures.append(label)
		print("  FAIL ", label)


func _ready() -> void:
	level = LevelScene.instantiate()
	add_child(level)


func _physics_process(_delta: float) -> void:
	t += 1
	if t < 8:
		return
	if player == null:
		player = get_tree().get_first_node_in_group("player")
		boss = get_tree().get_first_node_in_group("boss")
		if player == null or boss == null:
			check(false, "player and an enemy to be hit by")
			_finish()
			return
		# Park well outside its reach so the clock starts when we step in.
		player.set_physics_process(false)
		(player as Node2D).global_position = (boss as Node2D).global_position \
			- Vector2(400.0, 0.0)
		return

	if entered_range_at < 0:
		if t < 40:
			return
		# Step into reach. Everything after this is measured in frames.
		hp_before = int(player.get("hp"))
		(player as Node2D).global_position = (boss as Node2D).global_position \
			- Vector2(70.0, 0.0)
		entered_range_at = t
		return

	if attack_began_at < 0 and String(boss.get("state")) == "attack":
		attack_began_at = t
	# The enemy's own strike flag, not the player's health: health can drop from
	# a contact hit or a later swing, which measures something other than the
	# wind-up. This flips the instant the blow is delivered.
	if struck_at < 0 and attack_began_at > 0 and bool(boss.get("struck")):
		struck_at = t

	if struck_at > 0 or t > entered_range_at + 300:
		_report()


func _report() -> void:
	check(attack_began_at > 0, "the enemy committed to a swing")
	check(struck_at > 0, "and delivered the blow, so the timings are real")
	if attack_began_at > 0:
		var notice: int = attack_began_at - entered_range_at
		check(notice >= MIN_NOTICE_FRAMES,
			"it squares up for %d frames before swinging (need %d)"
			% [notice, MIN_NOTICE_FRAMES])
	if attack_began_at > 0 and struck_at > 0:
		var windup: int = struck_at - attack_began_at
		check(windup >= MIN_WINDUP_FRAMES,
			"the swing telegraphs for %d frames before it lands (need %d)"
			% [windup, MIN_WINDUP_FRAMES])
	if entered_range_at > 0 and struck_at > 0:
		var total: int = struck_at - entered_range_at
		print("  note: %d frames (%.2fs) from stepping into reach to the blow"
			% [total, total / 60.0])
	_finish()


func _finish() -> void:
	if failures.is_empty():
		print("TELEGRAPH TESTS ALL PASSED")
	else:
		print("TELEGRAPH TESTS: %d FAILURES -> %s" % [failures.size(), str(failures)])
	get_tree().quit(1 if failures.size() > 0 else 0)
