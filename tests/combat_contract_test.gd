extends Node

var failures := 0

class Target extends StaticBody2D:
	var hits := 0
	func _ready() -> void:
		collision_layer = 2
		collision_mask = 0
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 12.0
		shape.shape = circle
		add_child(shape)
		var receiver := MVCombat.new()
		receiver.name = "Combat"
		receiver.configure(100)
		receiver.damaged.connect(func(_hit: MVDamage) -> void: hits += 1)
		add_child(receiver)

func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		failures += 1

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	var p: MVPlayer = preload("res://src/player/player.tscn").instantiate()
	add_child(p)
	p.set_physics_process(false)
	p.set_process(false)
	p.position = Vector2(0, -1000)
	p.coyote = 0.0
	p.buffer = 0.1
	p._physics_process(1.0 / 60.0)
	check(p.velocity.y >= 0.0, "walking off a ledge does not grant a locked air jump")
	p.has_double_jump = true
	p.buffer = 0.1
	p._physics_process(1.0 / 60.0)
	check(p.velocity.y < 0.0 and p.jumps_used == 2, "double jump provides exactly one ledge recovery")
	var foe := Target.new()
	add_child(foe)
	foe.add_to_group("enemy")
	foe.position = p.position + Vector2(150, 0)
	await get_tree().physics_frame
	p.facing = 1.0
	p._do_attack()
	check(foe.hits == 0, "swing misses targets outside reach")
	foe.position = p.position + Vector2(40, 0)
	await get_tree().physics_frame
	p._physics_process(1.0 / 60.0)
	check(foe.hits == 1, "entering an active swing takes damage")
	p._physics_process(1.0 / 60.0)
	check(foe.hits == 1, "active swing never damages the same target twice")
	p.attack_cd = 0.02
	p.attack_buffer = 0.1
	p._physics_process(0.03)
	check(p.attack_cd == p.ATTACK_COOLDOWN, "buffered attack fires when cooldown ends")
	p.invuln = 0.0
	p.pounding = true
	p.take_damage(1, p.position + Vector2.RIGHT)
	check(not p.pounding and p.velocity.y < 0.0, "damage interrupts pound so knockback survives")
	p.buffer = 0.1
	p.coyote = 0.1
	p.dash_available = false
	p.respawn()
	check(p.buffer == 0.0 and p.coyote == 0.0 and p.attack_t == 0.0 and p.dash_available,
		"respawn clears queued actions and restores dash")
	JuiceMan._trauma = 0.0
	JuiceMan._process(0.1)
	p._physics_process(0.1)
	check(p.camera.offset.x > 0.0 and p.camera.offset.y == 0.0, "camera retains lookahead after shake settles")
	p.invuln = 0.0
	p.dash_timer = p.DASH_TIME
	var health := p.hp
	MVDamage.deliver(p, MVDamage.new(1, p.position))
	check(p.hp == health and p.action_state == p.Action.DASH, "typed damage respects dash immunity")
	p.dash_timer = 0.0
	MVDamage.deliver(p, MVDamage.new(1, p.position))
	MVDamage.deliver(p, MVDamage.new(1, p.position))
	check(p.hp == health - 1 and p.action_state == p.Action.HURT, "repeated damage respects invulnerability and enters Hurt")
	p.pounding = true
	p.dash_timer = p.DASH_TIME
	check(p.action_state == p.Action.HURT and not p.pounding and p.dash_timer == 0.0, "Hurt rejects dash and pound transitions")
	p.kill()
	p.pounding = true
	p.dash_timer = p.DASH_TIME
	p._do_attack()
	check(p.action_state == p.Action.DEAD and not p.pounding and p.attack_t == 0.0 and not p.is_dashing(), "Dead rejects movement and attacks")
	p.respawn()
	check(p.action_state == p.Action.NORMAL and p.hp == p.MAX_HP, "respawn is the explicit exit from Dead")
	p._do_attack()
	p.pounding = true
	check(p.action_state == p.Action.POUND_WINDUP and p.attack_t == 0.0, "pound windup cancels active melee")
	p.pound_t = 0.0
	p._physics_process(0.01)
	check(p.action_state == p.Action.POUND_FALL, "pound windup transitions to falling")
	p.bounce_from_stomp()
	check(p.action_state == p.Action.NORMAL and p.velocity.y < 0.0, "enemy stomp exits pound and allows a follow-up attack")
	if failures == 0:
		print("ALL TESTS PASSED")
	get_tree().quit(failures)
