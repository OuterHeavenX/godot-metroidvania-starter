class_name MVBoss
extends MVSkeleton

## The Warden. A warrior skeleton scaled up, with a guard that ordinary attacks
## bounce off: the only way through it is a ground pound, which is the ability
## the Undercroft spends its whole length teaching.

signal defeated

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


## Ordinary hits ring off the guard. Only a pound opens it.
func take_hit(from_pos: Vector2) -> void:
	if dead:
		return
	if guarded:
		hit_flash = 0.12
		AudioMan.play("hit_enemy", -10.0, 0.55)
		JuiceMan.burst(global_position + Vector2(0, -60), Color(0.75, 0.8, 0.95),
			6, 120.0, 0.3, 160.0, 3.0)
		return
	hp -= 1
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
