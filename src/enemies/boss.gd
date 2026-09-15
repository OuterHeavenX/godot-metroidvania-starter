class_name MVBoss
extends MVSkeleton

signal defeated
signal guard_changed(guarded: bool)
signal phase_changed(phase: int)
const MAX_HP := 12
const PHASE_TWO_AT := 6
const GUARD_STAGGER := 0.6
const VISUAL_SCALE := 1.7
var guarded := true
var phase := 1

func _ready() -> void:
	kind = "warrior"
	super._ready()
	add_to_group("boss")
	combat.configure(MAX_HP)
	visual_scale = VISUAL_SCALE
	visual.scale = Vector2(VISUAL_SCALE, VISUAL_SCALE)
	cfg = cfg.duplicate()
	cfg.merge({"hp": MAX_HP, "speed": 70.0, "melee_range": 84.0, "attack_cd": 1.7, "dmg": 1}, true)

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
	state = "hurt"
	state_t = GUARD_STAGGER
	knock_v = 0.0
	feedback.emit(&"animation", {"name": "hurt"})
	feedback.emit(&"guard_break", {})

func _enter_phase_two() -> void:
	phase = 2
	guarded = true
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
