class_name MVHeart
extends Area2D

signal collected

## A health pickup. Unlike the ability orbs it refuses to be spent at full
## health, so it stays on the ground until it is actually worth taking.

const AMOUNT := 1
const TINT := Color("ff5d73")
const RADIUS := 15.0

var t := 0.0
var base_y := 0.0


func _ready() -> void:
	var effects := preload("res://src/presentation/world_feedback.gd").new()
	effects.kind = "heart"
	add_child(effects)
	add_to_group("heart")
	collision_layer = 0
	collision_mask = 1
	base_y = position.y
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 20.0
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body)


func _process(delta: float) -> void:
	t += delta
	position.y = base_y + sin(t * 2.6) * 6.0
	queue_redraw()


func _on_body(body: Node2D) -> void:
	var p := body as MVPlayer
	if p == null or p.dead or is_queued_for_deletion():
		return
	if not p.heal(AMOUNT):
		return
	collected.emit()
	queue_free()


func _draw() -> void:
	var pulse := 1.0 + sin(t * 4.5) * 0.10
	var r := RADIUS * pulse
	draw_circle(Vector2.ZERO, r * 1.55, Color(TINT, 0.13))
	# two lobes and a point, which reads as a heart at this size
	draw_circle(Vector2(-r * 0.42, -r * 0.30), r * 0.52, TINT)
	draw_circle(Vector2(r * 0.42, -r * 0.30), r * 0.52, TINT)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-r * 0.92, -r * 0.14),
		Vector2(0.0, r * 0.95),
		Vector2(r * 0.92, -r * 0.14),
	]), TINT)
	draw_circle(Vector2(-r * 0.46, -r * 0.44), r * 0.17, Color(1, 1, 1, 0.75))
