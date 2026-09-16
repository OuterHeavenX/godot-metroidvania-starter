class_name MVSkeleton
extends CharacterBody2D


signal feedback(event: StringName, details: Dictionary)
signal died
var combat := MVCombat.new()

const CFG := {
	"warrior": {"speed": 85.0, "hp": 2, "melee_range": 70.0, "attack_cd": 1.25, "patrol": true, "dmg": 1},
	"spearman": {"speed": 62.0, "hp": 3, "melee_range": 128.0, "attack_cd": 1.6, "patrol": true, "dmg": 1},
	# shoot_range is bounded by what the camera shows. At zoom 1.54 the narrowest
	# landscape view is 748 world px wide, and the camera's drag margin lets the
	# player sit off-centre, leaving ~310px before an archer would be shooting
	# from off screen. Re-check this if the camera zoom changes -- it went 1.4 ->
	# 1.54 to frame the character larger, and this came down with it.
	"archer": {"speed": 0.0, "hp": 2, "shoot_range": 305.0, "shoot_cd": 2.4, "patrol": false, "dmg": 1},
	# Holds a shield toward you: blades from the front are turned aside, so come
	# round it or pound it. Slow enough that going round is realistic.
	"shielder": {"speed": 48.0, "hp": 3, "melee_range": 96.0, "attack_cd": 1.9,
		"patrol": true, "dmg": 1, "blocks_front": true},
	# Winds up, then commits to a run. The recovery afterwards is the opening.
	"charger": {"speed": 80.0, "hp": 2, "melee_range": 64.0, "attack_cd": 2.4,
		"patrol": true, "dmg": 1, "charge_range": 280.0, "charge_speed": 330.0},
}
const CHARGE_WINDUP := 0.45
const CHARGE_TIME := 0.55
const CHARGE_RECOVER := 0.85
const ArrowScript := preload("res://src/enemies/arrow.gd")

@export var kind := "warrior"

var cfg: Dictionary
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity", 980.0)
var dir := -1.0
var dead := false
var hp: int:
	get: return combat.hp
	set(value): combat.hp = value
var hit_flash := 0.0
var state := "patrol"
var state_t := 0.0
var cd_t := 0.0
var struck := false
var knock_v := 0.0
var visual_scale := 1.0

@onready var sensors: Node2D = $Sensors
@onready var wall_check: RayCast2D = $Sensors / WallCheck
@onready var floor_check: RayCast2D = $Sensors / FloorCheck
@onready var visual: Node2D = $Visual


func _ready() -> void:
	add_to_group("enemy")
	if not CFG.has(kind):
		kind = "warrior"
	cfg = CFG[kind]
	combat.name = "Combat"
	combat.configure(int(cfg["hp"]))
	combat.damage_policy = _damage_policy
	combat.damaged.connect(_on_damaged)
	combat.blocked.connect(_on_blocked)
	combat.staggered.connect(_on_staggered)
	combat.depleted.connect(die)
	add_child(combat)
	add_child(preload("res://src/presentation/enemy_feedback.gd").new())
	floor_snap_length = 4.0
	sensors.scale.x = dir
	visual.setup(kind)
	$Stompbox.body_entered.connect(_on_stomp)
	$Hurtbox.body_entered.connect(_on_hurt)


func _physics_process(delta: float) -> void:
	if dead:
		return
	combat.tick(delta)
	hit_flash = maxf(hit_flash - delta, 0.0)
	cd_t = maxf(cd_t - delta, 0.0)
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0.0
	var player := _player()
	match state:
		"hurt":
			state_t -= delta
			velocity.x = knock_v
			knock_v = lerpf(knock_v, 0.0, delta * 8.0)
			if state_t <= 0.0:
				state = "patrol"
				feedback.emit(&"animation", {"name": "idle" if not bool(cfg["patrol"]) else "walk"})
		"attack":
			velocity.x = 0.0
			state_t -= delta
			var total: float = 0.55
			if not struck and state_t < total * 0.55:
				struck = true
				_melee_strike()
			if state_t <= 0.0:
				state = "patrol"
				cd_t = float(cfg["attack_cd"])
				feedback.emit(&"animation", {"name": "walk" if bool(cfg["patrol"]) else "idle"})
		"windup":
			velocity.x = 0.0
			state_t -= delta
			if state_t <= 0.0:
				state = "charge"
				state_t = CHARGE_TIME
				feedback.emit(&"animation", {"name": "runattack"})
				feedback.emit(&"charge", {})
		"charge":
			state_t -= delta
			velocity.x = dir * float(cfg.get("charge_speed", 300.0))
			if wall_check.is_colliding() or not floor_check.is_colliding():
				state_t = 0.0
			if state_t <= 0.0:
				state = "recover"
				state_t = CHARGE_RECOVER
				feedback.emit(&"animation", {"name": "idle"})
		"recover":
			velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
			state_t -= delta
			if state_t <= 0.0:
				state = "patrol"
				cd_t = float(cfg["attack_cd"])
				feedback.emit(&"animation", {"name": "walk"})
		"shoot":
			velocity.x = 0.0
			state_t -= delta
			if not struck and state_t < 0.45:
				struck = true
				_fire_arrow()
			if state_t <= 0.0:
				state = "patrol"
				cd_t = float(cfg["shoot_cd"])
				feedback.emit(&"animation", {"name": "idle"})
		_:
			_patrol(delta, player)
	move_and_slide()
	visual.scale.x = dir * visual_scale


func _patrol(delta: float, player: Node2D) -> void:
	if bool(cfg["patrol"]):
		velocity.x = dir * float(cfg["speed"])
		if wall_check.is_colliding() or not floor_check.is_colliding():
			dir = -dir
			sensors.scale.x = dir
		feedback.emit(&"animation", {"name": "protect" if bool(cfg.get("blocks_front", false)) else "walk"})
	else:
		velocity.x = 0.0
		feedback.emit(&"animation", {"name": "idle"})
	if player == null or cd_t > 0.0:
		return
	var to_p: Vector2 = player.global_position - global_position
	if kind == "archer":
		if absf(to_p.x) < float(cfg["shoot_range"]) and absf(to_p.y) < 130.0:
			dir = signf(to_p.x)
			if dir == 0.0:
				dir = 1.0
			sensors.scale.x = dir
			state = "shoot"
			state_t = 0.95
			struck = false
			feedback.emit(&"animation", {"name": "shot1"})
			feedback.emit(&"shoot", {})
	elif kind == "charger" and absf(to_p.x) < float(cfg["charge_range"]) \
			and absf(to_p.x) > float(cfg["melee_range"]) and absf(to_p.y) < 70.0:
		dir = signf(to_p.x)
		if dir == 0.0:
			dir = 1.0
		sensors.scale.x = dir
		state = "windup"
		state_t = CHARGE_WINDUP
		feedback.emit(&"animation", {"name": "protect"})
		feedback.emit(&"windup", {})
	else:
		if absf(to_p.x) < float(cfg["melee_range"]) and absf(to_p.y) < 70.0:
			dir = signf(to_p.x)
			if dir == 0.0:
				dir = 1.0
			sensors.scale.x = dir
			state = "attack"
			state_t = 0.55
			struck = false
			feedback.emit(&"animation", {"name": "attack1"})
			feedback.emit(&"attack", {})


func _melee_strike() -> void:
	var player := _player()
	if player == null or not (player is MVPlayer):
		return
	var reach: float = float(cfg["melee_range"])
	var to_p: Vector2 = player.global_position - global_position
	if signf(to_p.x) == dir and absf(to_p.x) < reach and absf(to_p.y) < 80.0:
		MVDamage.deliver(player, MVDamage.new(int(cfg["dmg"]), global_position, MVDamage.Kind.CONTACT))


func _fire_arrow() -> void:
	if dead:
		return
	var a: Area2D = ArrowScript.new()
	a.setup(dir, global_position + Vector2(dir * 40.0, -52.0))
	get_parent().add_child(a)


func _player() -> Node2D:
	return get_tree().get_first_node_in_group("player") as Node2D


func _on_stomp(body: Node2D) -> void:
	if dead:
		return
	var p := body as MVPlayer
	if p == null:
		return
	if p.velocity.y > 60.0 and p.global_position.y < global_position.y - 8.0:
		squash()
		p.bounce_from_stomp()


func _on_hurt(body: Node2D) -> void:
	if dead:
		return
	var p := body as MVPlayer
	if p != null:
		# At pound speed the player can cross both areas in one physics tick.
		# Resolve the top-down hit first regardless of signal delivery order.
		if p.velocity.y > 60.0 and p.global_position.y < global_position.y - 8.0:
			_on_stomp(p)
			return
		# A slam in progress does not get punished for touching what it is
		# slamming. The pound is the taught answer to a guard, and reaching one
		# means passing through the enemy: charging for that made the intended
		# solution cost a heart every time it was used.
		if p.is_pounding():
			return
		MVDamage.deliver(p, MVDamage.new(int(cfg["dmg"]), global_position, MVDamage.Kind.CONTACT))


## True when a blow lands on the shield rather than the skeleton.
func blocks(from_pos: Vector2) -> bool:
	if not bool(cfg.get("blocks_front", false)):
		return false
	if state in ["hurt", "dead"]:
		return false
	# Only the side it is facing is covered.
	return signf(from_pos.x - global_position.x) == dir


func _damage_policy(hit: MVDamage) -> int:
	if dead:
		return 0
	if hit.kind == MVDamage.Kind.IMPACT:
		return hp
	return 0 if blocks(hit.origin) else hit.amount


func take_hit(from_pos: Vector2) -> void:
	combat.receive(MVDamage.new(1, from_pos))


func _on_blocked(_hit: MVDamage) -> void:
	hit_flash = 0.1
	feedback.emit(&"block", {})


func _on_staggered(_hit: MVDamage) -> void:
	pass # Bosses define guard-break behavior without replacing health handling.


func _on_damaged(hit: MVDamage) -> void:
	hit_flash = 0.16
	feedback.emit(&"hit", {})
	knock_v = MVCombat.knockback(hit.origin, global_position, dir, 240.0, 0.0).x
	if hp > 0:
		state = "hurt"
		state_t = 0.28
		feedback.emit(&"animation", {"name": "hurt"})


func squash() -> void:
	combat.receive(MVDamage.new(1, global_position, MVDamage.Kind.IMPACT))


func die() -> void:
	if dead:
		return
	dead = true
	state = "dead"
	combat.hp = 0
	died.emit()
	feedback.emit(&"death", {})
	$CollisionShape2D.set_deferred("disabled", true)
	$Hurtbox.set_deferred("monitoring", false)
	$Stompbox.set_deferred("monitoring", false)
	velocity = Vector2.ZERO
	feedback.emit(&"animation", {"name": "dead"})
	await get_tree().create_timer(0.55).timeout
	queue_free()
