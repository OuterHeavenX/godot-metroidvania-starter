class_name MVArrow
extends Area2D

signal impacted


var dir := 1.0
var speed := 520.0
var life := 3.0
var dead := false

var _sprite: Sprite2D


func setup(p_dir: float, pos: Vector2) -> void:
	dir = signf(p_dir)
	if dir == 0.0:
		dir = 1.0
	position = pos


func _ready() -> void:
	var effects := preload("res://src/presentation/world_feedback.gd").new()
	effects.kind = "arrow"
	add_child(effects)
	add_to_group("projectile")
	collision_layer = 0
	collision_mask = 1 | 4
	monitoring = true
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(36, 10)
	shape.shape = rect
	add_child(shape)
	_sprite = Sprite2D.new()
	_sprite.texture = load("res://assets/sprites/enemies/skeleton_archer/Arrow.png")
	_sprite.scale.x = dir
	add_child(_sprite)
	body_entered.connect(_on_body)


func _physics_process(delta: float) -> void:
	if dead:
		return
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	position.x += dir * speed * delta


func _on_body(body: Node2D) -> void:
	if dead:
		return
	var p := body as MVPlayer
	if p != null:
		MVDamage.deliver(p, MVDamage.new(1, global_position, MVDamage.Kind.CONTACT))
	else:
		impacted.emit()
	dead = true
	queue_free()
