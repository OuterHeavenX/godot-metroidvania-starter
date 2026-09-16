class_name MVBoss
extends MVSkeleton

signal defeated
signal guard_changed(guarded: bool)
signal phase_changed(phase: int)
const MAX_HP := 9
const PHASE_TWO_AT := 4
## Breaking the guard is the hard half of the fight, so it has to buy a real
## opening. At 0.6 the Warden was swinging again before the player had landed.
## Retuned after the combat refactor: the same numbers no longer bought the
## same fight, which is what bossclumsy is for.
const GUARD_STAGGER := 1.7
const VISUAL_SCALE := 1.7
var guarded := true
var phase := 1
var guard_visual: GuardAura = null

func _ready() -> void:
	kind = "warrior"
	super._ready()
	add_to_group("boss")
	combat.configure(MAX_HP)
	visual_scale = VISUAL_SCALE
	visual.scale = Vector2(VISUAL_SCALE, VISUAL_SCALE)
	# A shield you can see on the boss itself, so the guard is readable without
	# looking away from the fight.
	guard_visual = GuardAura.new()
	guard_visual.z_index = 1
	add_child(guard_visual)
	cfg = cfg.duplicate()
	cfg.merge({"hp": MAX_HP, "speed": 70.0, "melee_range": 96.0, "attack_cd": 1.7, "dmg": 1}, true)

func _damage_policy(hit: MVDamage) -> int:
	if dead:
		return 0
	if hit.kind == MVDamage.Kind.IMPACT:
		return MVCombat.STAGGER if guarded else 0
	return 0 if guarded else hit.amount

func _on_damaged(hit: MVDamage) -> void:
	super._on_damaged(hit)
	knock_v = MVCombat.knockback(hit.origin, global_position, dir, 120.0, 0.0).x
	state_t = 0.2
	if hp > 0 and hp <= PHASE_TWO_AT and phase == 1:
		_enter_phase_two()

func _on_staggered(_hit: MVDamage) -> void:
	guarded = false
	guard_changed.emit(guarded)
	if guard_visual != null:
		guard_visual.shatter()
	# Breaking the guard pays for itself. It is the hard half of the fight and
	# reaching one costs height, position and usually a hit on the way in.
	var p := _player()
	if p != null and p.has_method("heal"):
		p.call("heal", 1)
	state = "hurt"
	state_t = GUARD_STAGGER
	knock_v = 0.0
	feedback.emit(&"animation", {"name": "hurt"})
	feedback.emit(&"guard_break", {})

func _enter_phase_two() -> void:
	phase = 2
	guarded = true
	guard_changed.emit(true)
	if guard_visual != null:
		guard_visual.raise()
	cfg["speed"] = 110.0
	cfg["attack_cd"] = 1.15
	guard_changed.emit(guarded)
	phase_changed.emit(phase)
	feedback.emit(&"phase_two", {})

func die() -> void:
	if dead:
		return
	feedback.emit(&"boss_death", {})
	super.die()
	defeated.emit()


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
