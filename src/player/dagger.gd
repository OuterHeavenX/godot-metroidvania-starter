class_name MVDagger
extends Area2D

## A thrown dagger. The player's answer to anything out of sword reach: an
## archer across a gap, a shielder you would rather not walk into, a charger
## mid-wind-up.
##
## It stops on the first thing it hits. Passing through a crowd would make it
## strictly better than the sword at every range, which would retire the sword.

const SPEED := 620.0
const LIFE := 2.0
const DAMAGE := 1
## Enemies are layer 2, terrain layer 4. Hitting terrain is what keeps the
## dagger from being a free poke through a wall.
const HITS := 2 | 4

var dir := 1.0
var life := LIFE
var spent := false
var spin := 0.0

var _visual: Node2D


func setup(p_dir: float, pos: Vector2) -> void:
	dir = signf(p_dir)
	if dir == 0.0:
		dir = 1.0
	position = pos


func _ready() -> void:
	add_to_group("projectile")
	add_to_group("dagger")
	collision_layer = 0
	collision_mask = HITS
	monitoring = true
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(26, 10)
	shape.shape = rect
	add_child(shape)
	_visual = Blade.new()
	add_child(_visual)
	body_entered.connect(_on_body)


func _physics_process(delta: float) -> void:
	if spent:
		return
	position.x += dir * SPEED * delta
	spin += delta * 18.0 * dir
	_visual.rotation = spin
	_visual.queue_redraw()
	life -= delta
	if life <= 0.0:
		_fizzle()


func _on_body(body: Node2D) -> void:
	if spent:
		return
	if body.is_in_group("enemy"):
		spent = true
		# A SLASH, like the sword, so a raised guard turns it aside rather than
		# letting the dagger be the one thing that ignores the mechanic.
		MVDamage.deliver(body, MVDamage.new(DAMAGE, global_position))
		_burst(Color(1.0, 0.85, 0.55))
		queue_free()
		return
	spent = true
	_burst(Color(0.7, 0.75, 0.9))
	queue_free()


func _fizzle() -> void:
	spent = true
	_burst(Color(0.6, 0.65, 0.8, 0.6))
	queue_free()


func _burst(col: Color) -> void:
	JuiceMan.burst(global_position, col, 7, 150.0, 0.28, 320.0, 3.0)


class Blade extends Node2D:
	func _draw() -> void:
		var steel := Color("c9d4e8")
		var edge := Color("6d7793")
		var grip := Color("3a2a22")
		draw_colored_polygon(PackedVector2Array([
			Vector2(13, 0), Vector2(1, -4), Vector2(-5, -3), Vector2(-5, 3), Vector2(1, 4),
		]), steel)
		draw_line(Vector2(-5, 0), Vector2(13, 0), edge, 1.0)
		draw_rect(Rect2(-11, -2, 6, 4), grip)
		draw_rect(Rect2(-6, -5, 2, 10), edge)
