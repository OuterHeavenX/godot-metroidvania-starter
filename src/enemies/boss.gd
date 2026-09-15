class_name MVBoss
extends MVSkeleton

## The Warden. A warrior skeleton scaled up, with a guard that ordinary attacks
## bounce off: the only way through it is a ground pound, which is the ability
## the Undercroft spends its whole length teaching.

signal defeated
## The HUD listens to these. The fight was unreadable without them: an ordinary
## hit and one that rang off the guard looked near enough the same.
signal engaged(who: String, hp: int, max_hp: int, guarded: bool)
signal hp_changed(hp: int, max_hp: int)
signal guard_changed(guarded: bool)
signal blocked

const MAX_HP := 12
## The guard does not come back on a timer. Breaking it opens the Warden for
## the rest of the phase, and it raises a fresh one when phase two begins. On a
## timer the fight was all-or-nothing -- kill it inside one window or lose,
## because re-breaking cost more health than the player could spare.
const PHASE_TWO_AT := 6
const GUARD_STAGGER := 0.6
const VISUAL_SCALE := 1.7

var guarded := true
var phase := 1
var guard_visual: GuardAura = null


func _ready() -> void:
	kind = "warrior"
	super._ready()
	add_to_group("boss")
	hp = MAX_HP
	visual.scale = Vector2(VISUAL_SCALE, VISUAL_SCALE)
	cfg = cfg.duplicate()
	cfg["hp"] = MAX_HP
	cfg["speed"] = 70.0
	# The player's ATTACK_RANGE is 86. Anything longer means a band where the
	# Warden can hit you and you cannot hit back, which is what made the fight
	# unwinnable rather than hard.
	cfg["melee_range"] = 84.0
	cfg["attack_cd"] = 1.7
	cfg["dmg"] = 1
	# A shield you can see on the boss itself, so the state is readable without
	# looking away from the fight.
	guard_visual = GuardAura.new()
	guard_visual.z_index = 1
	add_child(guard_visual)
	engaged.emit("THE WARDEN", hp, MAX_HP, guarded)


## Ordinary hits ring off the guard. Only a pound opens it.
func take_hit(from_pos: Vector2) -> void:
	if dead:
		return
	if guarded:
		hit_flash = 0.12
		AudioMan.play("hit_enemy", -10.0, 0.55)
		JuiceMan.burst(global_position + Vector2(0, -60), Color(0.75, 0.8, 0.95),
			6, 120.0, 0.3, 160.0, 3.0)
		blocked.emit()
		if guard_visual != null:
			guard_visual.clang(global_position.x - from_pos.x)
		return
	hp -= 1
	hp_changed.emit(hp, MAX_HP)
	hit_flash = 0.16
	AudioMan.play("hit_enemy", -2.0, randf_range(0.85, 1.0))
	var away: float = signf(global_position.x - from_pos.x)
	knock_v = (away if away != 0.0 else dir) * 120.0
	if hp <= PHASE_TWO_AT and phase == 1:
		_enter_phase_two()
	if hp <= 0:
		die()
		return
	state = "hurt"
	state_t = 0.2
	visual.play("hurt")


## A ground pound (or a stomp) breaks the guard instead of killing outright.
func squash() -> void:
	if dead:
		return
	if not guarded:
		return
	guarded = false
	guard_changed.emit(false)
	if guard_visual != null:
		guard_visual.shatter()
	# Stagger it, so breaking the guard buys a real opening rather than just a
	# state change.
	state = "hurt"
	state_t = GUARD_STAGGER
	knock_v = 0.0
	visual.play("hurt")
	AudioMan.play("pound", -4.0, 0.85)
	JuiceMan.shake(0.35)
	JuiceMan.hit_stop(0.07)
	JuiceMan.burst(global_position + Vector2(0, -60), Color(1.0, 0.85, 0.5),
		20, 300.0, 0.6, 500.0, 5.0)


func _enter_phase_two() -> void:
	phase = 2
	# A fresh guard: the mechanic gets asked for a second time, at a moment the
	# player can see coming rather than on a hidden timer.
	guarded = true
	guard_changed.emit(true)
	if guard_visual != null:
		guard_visual.raise()
	cfg["speed"] = 110.0
	cfg["attack_cd"] = 1.15
	JuiceMan.shake(0.4)
	JuiceMan.burst(global_position + Vector2(0, -60), Color(1.0, 0.45, 0.4),
		24, 330.0, 0.7, 600.0, 5.0)


func die() -> void:
	if dead:
		return
	defeated.emit()
	JuiceMan.shake(0.7)
	JuiceMan.hit_stop(0.12)
	JuiceMan.burst(global_position + Vector2(0, -60), Color(1.0, 0.8, 0.45),
		34, 420.0, 0.9, 700.0, 7.0)
	super.die()


## The guard, drawn on the boss. Ordinary blows spark off it; a pound shatters
## it and it stays down for the phase.
class GuardAura extends Node2D:
	const R := 74.0

	var up := true
	var t := 0.0
	var spark := 0.0
	var spark_side := 1.0

	func _ready() -> void:
		set_process(true)

	func _process(delta: float) -> void:
		if not up:
			return
		t += delta
		if spark > 0.0:
			spark = maxf(0.0, spark - delta * 4.0)
		queue_redraw()

	func clang(side: float) -> void:
		spark = 1.0
		spark_side = 1.0 if side >= 0.0 else -1.0

	func shatter() -> void:
		up = false
		queue_redraw()
		JuiceMan.burst(global_position + Vector2(0, -60), Color(0.7, 0.82, 1.0),
			18, 260.0, 0.55, 240.0, 4.0)

	func raise() -> void:
		up = true
		t = 0.0
		queue_redraw()

	func _draw() -> void:
		if not up:
			return
		var mid := Vector2(0, -60)
		var pulse: float = 0.14 + 0.05 * sin(t * 3.2)
		draw_circle(mid, R, Color(0.55, 0.72, 1.0, pulse))
		draw_arc(mid, R, 0.0, TAU, 40, Color(0.7, 0.85, 1.0, 0.55 + spark * 0.45),
			2.0 + spark * 3.0)
		if spark > 0.0:
			# Sparks fly off the side the blow came from.
			var from: float = -0.6 if spark_side > 0.0 else PI - 0.6
			draw_arc(mid, R, from, from + 1.2, 16, Color(1.0, 0.95, 0.8, spark), 5.0)
			draw_circle(mid + Vector2(spark_side * R, 0.0), 7.0 * spark,
				Color(1.0, 0.95, 0.75, spark))
