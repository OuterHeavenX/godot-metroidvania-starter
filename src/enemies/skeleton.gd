class_name MVSkeleton
extends CharacterBody2D


const CFG := {
	"warrior": {"speed": 85.0, "hp": 2, "melee_range": 70.0, "attack_cd": 1.25, "patrol": true, "dmg": 1},
	"spearman": {"speed": 62.0, "hp": 3, "melee_range": 104.0, "attack_cd": 1.6, "patrol": true, "dmg": 1},
	"archer": {"speed": 0.0, "hp": 2, "shoot_range": 470.0, "shoot_cd": 2.4, "patrol": false, "dmg": 1},
}
const ArrowScript := preload("res://src/enemies/arrow.gd")

@export var kind := "warrior"

var cfg: Dictionary
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity", 980.0)
var dir := -1.0
var dead := false
var hp := 2
var hit_flash := 0.0
var state := "patrol"
var state_t := 0.0
var cd_t := 0.0
var struck := false
var knock_v := 0.0

@onready var sensors: Node2D = $Sensors
@onready var wall_check: RayCast2D = $Sensors / WallCheck
@onready var floor_check: RayCast2D = $Sensors / FloorCheck
@onready var visual: Node2D = $Visual


func _ready() -> void:
	add_to_group("enemy")
	if not CFG.has(kind):
		kind = "warrior"
	cfg = CFG[kind]
	hp = int(cfg["hp"])
	floor_snap_length = 4.0
	sensors.scale.x = dir
	visual.setup(kind)
	$Stompbox.body_entered.connect(_on_stomp)
	$Hurtbox.body_entered.connect(_on_hurt)


func _physics_process(delta: float) -> void:
	if dead:
		return
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
				visual.play("idle" if not bool(cfg["patrol"]) else "walk")
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
				visual.play("walk" if bool(cfg["patrol"]) else "idle")
		"shoot":
			velocity.x = 0.0
			state_t -= delta
			if not struck and state_t < 0.45:
				struck = true
				_fire_arrow()
			if state_t <= 0.0:
				state = "patrol"
				cd_t = float(cfg["shoot_cd"])
				visual.play("idle")
		_:
			_patrol(delta, player)
	move_and_slide()
	visual.scale.x = dir


func _patrol(delta: float, player: Node2D) -> void:
	if bool(cfg["patrol"]):
		velocity.x = dir * float(cfg["speed"])
		if wall_check.is_colliding() or not floor_check.is_colliding():
			dir = -dir
			sensors.scale.x = dir
		visual.play("walk")
	else:
		velocity.x = 0.0
		visual.play("idle")
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
			visual.play("shot1")
			AudioMan.play("attack", -8.0, 0.7)
	else:
		if absf(to_p.x) < float(cfg["melee_range"]) and absf(to_p.y) < 70.0:
			dir = signf(to_p.x)
			if dir == 0.0:
				dir = 1.0
			sensors.scale.x = dir
			state = "attack"
			state_t = 0.55
			struck = false
			visual.play("attack1")
			AudioMan.play("attack", -6.0, 0.8)


func _melee_strike() -> void:
	var player := _player()
	if player == null or not (player is MVPlayer):
		return
	var reach: float = float(cfg["melee_range"])
	var to_p: Vector2 = player.global_position - global_position
	if signf(to_p.x) == dir and absf(to_p.x) < reach and absf(to_p.y) < 80.0:
		player.take_damage(int(cfg["dmg"]), global_position)
		JuiceMan.burst(player.global_position, Color(0.8, 0.2, 0.2), 8, 200.0, 0.4, 500.0, 4.0)


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
		p.velocity.y = p.JUMP_VELOCITY * 0.7
		p.jumps_used = 1


func _on_hurt(body: Node2D) -> void:
	if dead:
		return
	var p := body as MVPlayer
	if p != null:
		p.take_damage(int(cfg["dmg"]), global_position)


func take_hit(from_pos: Vector2) -> void:

	if dead:
		return
	hp -= 1
	hit_flash = 0.16
	AudioMan.play("hit_enemy", -2.0, randf_range(0.9, 1.1))
	var away: float = signf(global_position.x - from_pos.x)
	if away == 0.0:
		away = dir
	knock_v = away * 240.0
	if hp <= 0:
		die()
		return
	state = "hurt"
	state_t = 0.28
	visual.play("hurt")


func squash() -> void:

	die()


func die() -> void:
	if dead:
		return
	dead = true
	state = "dead"
	AudioMan.play("enemy_die", -2.0, randf_range(0.9, 1.15))
	JuiceMan.shake(0.22)
	JuiceMan.hit_stop(0.06)
	JuiceMan.burst(global_position + Vector2(0, -30), Color(0.85, 0.82, 0.7), 16, 260.0, 0.5, 700.0, 5.0)
	$CollisionShape2D.set_deferred("disabled", true)
	$Hurtbox.set_deferred("monitoring", false)
	$Stompbox.set_deferred("monitoring", false)
	velocity = Vector2.ZERO
	visual.play("dead")
	await get_tree().create_timer(0.55).timeout
	queue_free()
