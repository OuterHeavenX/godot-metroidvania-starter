class_name MVCombat
extends Node

signal health_changed(hp: int, maximum: int)
signal damaged(hit: MVDamage)
signal blocked(hit: MVDamage)
signal staggered(hit: MVDamage)
signal depleted

const STAGGER := -1
var max_hp := 5
var hp := 5
var invulnerability := 0.0
var immunity_on_hit := 0.0
var immune := false
## Returns damage amount, zero for block, or STAGGER for a guard break.
var damage_policy: Callable

func configure(maximum: int, immunity: float = 0.0) -> void:
	max_hp = maxi(maximum, 1)
	hp = max_hp
	immunity_on_hit = immunity

func tick(delta: float) -> void:
	invulnerability = maxf(invulnerability - delta, 0.0)

func receive(hit: MVDamage) -> bool:
	if hit == null or hit.amount <= 0 or hp <= 0 or immune or invulnerability > 0.0:
		return false
	var amount := hit.amount
	if damage_policy.is_valid():
		amount = int(damage_policy.call(hit))
	if amount == STAGGER:
		staggered.emit(hit)
		return true
	if amount <= 0:
		blocked.emit(hit)
		return false
	hp = maxi(hp - amount, 0)
	invulnerability = immunity_on_hit
	health_changed.emit(hp, max_hp)
	damaged.emit(hit)
	if hp == 0:
		depleted.emit()
	return true

func heal(amount: int) -> bool:
	if amount <= 0 or hp <= 0 or hp >= max_hp:
		return false
	hp = mini(hp + amount, max_hp)
	health_changed.emit(hp, max_hp)
	return true

func reset(immunity: float = 0.0) -> void:
	hp = max_hp
	invulnerability = immunity
	immune = false
	health_changed.emit(hp, max_hp)

static func knockback(origin: Vector2, target: Vector2, fallback: float, horizontal: float, vertical: float) -> Vector2:
	var direction := signf(target.x - origin.x)
	return Vector2((direction if direction != 0.0 else fallback) * horizontal, vertical)


func defeat() -> void:
	if hp <= 0:
		return
	hp = 0
	health_changed.emit(hp, max_hp)
	depleted.emit()
