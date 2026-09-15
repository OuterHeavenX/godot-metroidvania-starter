class_name MVPlayer
extends CharacterBody2D


signal health_changed(hp: int, max_hp: int)
signal died
signal ability_gained(ability_id: String)
signal checkpoint_set(pos: Vector2)

const SPEED := 260.0
const ACCEL := 2400.0
const FRICTION := 2800.0
const AIR_ACCEL := 1500.0
const JUMP_VELOCITY := -560.0
const JUMP_CUT := -220.0
const WALL_SLIDE_SPEED := 110.0
const WALL_JUMP_X := 400.0
const WALL_JUMP_Y := -500.0
const DASH_SPEED := 640.0
const DASH_TIME := 0.16
const DASH_COOLDOWN := 0.45
const COYOTE_TIME := 0.12
const JUMP_BUFFER := 0.14
const ATTACK_RANGE := 86.0
const ATTACK_HALF_HEIGHT := 58.0
const ATTACK_COOLDOWN := 0.38
const ATTACK_ACTIVE := 0.16
const POUND_WINDUP := 0.12
const POUND_FALL_SPEED := 1350.0
const POUND_IMPACT_RADIUS := 95.0
## How far above or below the player's feet an enemy's origin may sit and still
## be caught. Wide enough for anything standing on the same floor, tight enough
## that a pound does not reach a storey up.
const POUND_IMPACT_BAND := 120.0
const POUND_BREAK_RADIUS := 110.0
const MAX_HP := 5
const FALL_GRAVITY_MULT := 1.35
const APEX_SPEED := 90.0
const APEX_GRAVITY_MULT := 0.72
const MAX_FALL_SPEED := 1150.0
const ATTACK_BACK_GRACE := 14.0
const DASH_IFRAMES := true
# The camera's drag margin makes it trail the player, which shows where you
# have been rather than where you are going. Leading by roughly the same
# distance re-centres the view in the direction of travel.
const CAM_LOOKAHEAD := 60.0
const CAM_LOOKAHEAD_RATE := 4.0

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity", 980.0)
var hp := MAX_HP
var has_double_jump := false
var has_ground_pound := false
var pounding := false
var pound_t := 0.0
var jumps_used := 0
var coyote := 0.0
var buffer := 0.0
var dash_timer := 0.0
var dash_cd := 0.0
var dash_dir := 1.0
var dash_available := true
var invuln := 0.0
var hurt_t := 0.0
var dead := false
var facing := 1.0
var attack_cd := 0.0
var attack_t := 0.0
var _was_floor := false
var _fall_v := 0.0
var spawn_point := Vector2.ZERO

@onready var visual: Node2D = $Visual
@onready var camera: Camera2D = $Camera2D


func _ready() -> void:
	add_to_group("player")
	floor_snap_length = 6.0
	spawn_point = global_position


func max_jumps() -> int:
	return 2 if has_double_jump else 1


func is_dashing() -> bool:
	return dash_timer > 0.0


func is_pounding() -> bool:
	return pounding


func gain_ability(ability_id: String) -> void:
	if ability_id == "double_jump":
		has_double_jump = true
	elif ability_id == "ground_pound":
		has_ground_pound = true
	ability_gained.emit(ability_id)


func _do_attack() -> void:
	attack_cd = ATTACK_COOLDOWN
	attack_t = ATTACK_ACTIVE
	AudioMan.play("attack", -2.0, randf_range(0.95, 1.08))
	for e in get_tree().get_nodes_in_group("enemy"):
		var foe := e as Node2D
		if foe == null or not foe.has_method("take_hit"):
			continue
		var to: Vector2 = foe.global_position - global_position
		# Forward-biased box. The old signf(to.x) == facing test dropped any foe
		# standing exactly on the player's own x, where signf returns 0.
		#
		# Horizontal reach, not a radius. An enemy's origin is the centre of its
		# collision box, so a tall enemy carries its origin further above the
		# floor and a radius silently shortens the swing: against the Warden,
		# 39px up, ATTACK_RANGE 86 became 77 -- less than its own 84 reach, so
		# it outranged the player even after its reach was cut to match.
		# Enemies test their own reach horizontally; this now matches.
		if absf(to.y) < ATTACK_HALF_HEIGHT and to.x * facing > -ATTACK_BACK_GRACE \
				and absf(to.x) < ATTACK_RANGE:
			foe.take_hit(global_position)


func _physics_process(delta: float) -> void:
	if dead:
		return
	var dir := Input.get_axis("move_left", "move_right")
	if dir != 0.0:
		facing = sign(dir)


	var on_wall := is_on_wall_only()
	if is_on_floor():
		coyote = COYOTE_TIME
		jumps_used = 0
		dash_available = true
	else:
		coyote = maxf(coyote - delta, 0.0)
		if on_wall:
			dash_available = true
	buffer = maxf(buffer - delta, 0.0)
	dash_cd = maxf(dash_cd - delta, 0.0)
	invuln = maxf(invuln - delta, 0.0)
	hurt_t = maxf(hurt_t - delta, 0.0)
	attack_cd = maxf(attack_cd - delta, 0.0)
	attack_t = maxf(attack_t - delta, 0.0)

	if Input.is_action_just_pressed("jump"):
		buffer = JUMP_BUFFER
	if Input.is_action_just_released("jump") and velocity.y < JUMP_CUT:
		velocity.y = JUMP_CUT

	if Input.is_action_just_pressed("pound") and has_ground_pound \
			and not is_on_floor() and not pounding:
		pounding = true
		pound_t = POUND_WINDUP
		dash_timer = 0.0


	if Input.is_action_just_pressed("dash") and dash_cd <= 0.0 and dash_available \
			and not pounding:
		dash_timer = DASH_TIME
		dash_cd = DASH_COOLDOWN
		dash_available = false
		dash_dir = dir if dir != 0.0 else facing
		facing = dash_dir
		AudioMan.play("dash")
		JuiceMan.burst(global_position + Vector2(0, 8), Color(0.65, 0.8, 1.0),
			10, 220.0, 0.35, 250.0, 4.0)


	if Input.is_action_just_pressed("attack") and attack_cd <= 0.0:
		_do_attack()

	if pounding:

		if pound_t > 0.0:
			pound_t -= delta
			velocity = Vector2.ZERO
		else:
			velocity = Vector2(0.0, POUND_FALL_SPEED)
	elif is_dashing():
		dash_timer -= delta
		velocity = Vector2(dash_dir * DASH_SPEED, 0.0)
	else:

		if dir != 0.0:
			var grip := ACCEL if is_on_floor() else AIR_ACCEL
			velocity.x = move_toward(velocity.x, dir * SPEED, grip * delta)
		else:
			var drag := FRICTION if is_on_floor() else AIR_ACCEL * 0.4
			velocity.x = move_toward(velocity.x, 0.0, drag * delta)


		var n := get_wall_normal()
		var pressing_wall: bool = dir != 0.0 and n.x != 0.0 and sign(dir) == -sign(n.x)
		if on_wall and velocity.y > 0.0 and pressing_wall:
			velocity.y = WALL_SLIDE_SPEED
		else:
			velocity.y = minf(velocity.y + _gravity_now() * delta, MAX_FALL_SPEED)


		if buffer > 0.0:
			if on_wall and not is_on_floor():
				velocity = Vector2(n.x * WALL_JUMP_X, WALL_JUMP_Y)
				jumps_used = 1
				facing = sign(n.x)
				buffer = 0.0
				coyote = 0.0
				AudioMan.play("jump")
			elif is_on_floor() or coyote > 0.0:
				velocity.y = JUMP_VELOCITY
				jumps_used = 1
				buffer = 0.0
				coyote = 0.0
				AudioMan.play("jump")
			elif jumps_used < max_jumps():
				velocity.y = JUMP_VELOCITY * 0.92
				jumps_used += 1
				buffer = 0.0
				AudioMan.play("double_jump" if has_double_jump else "jump")

	if camera != null:
		var want: float = facing * CAM_LOOKAHEAD
		var k: float = 1.0 - exp(-CAM_LOOKAHEAD_RATE * delta)
		camera.offset.x = lerpf(camera.offset.x, want, k)

	_was_floor = is_on_floor()
	_fall_v = velocity.y
	move_and_slide()
	if pounding and is_on_floor():
		_pound_impact()
	elif not _was_floor and is_on_floor() and _fall_v > 520.0 and not dead:
		JuiceMan.burst(global_position + Vector2(0, 20), Color(0.55, 0.6, 0.75, 0.8),
			8, 150.0, 0.4, 500.0, 4.0)
		AudioMan.play("land", -6.0)


func _gravity_now() -> float:
	# Falling harder than you rise, with a little float through the apex, is
	# what makes a jump arc read as snappy rather than floaty. Rise height is
	# unchanged; only the descent and the hang at the top move.
	var g := gravity
	if velocity.y > 0.0:
		g *= FALL_GRAVITY_MULT
	if absf(velocity.y) < APEX_SPEED:
		g *= APEX_GRAVITY_MULT
	return g


func _pound_impact() -> void:

	pounding = false
	pound_t = 0.0
	AudioMan.play("pound")
	JuiceMan.shake(0.55)
	JuiceMan.hit_stop(0.08)
	var feet := global_position + Vector2(0, 22)
	JuiceMan.burst(feet, Color(0.75, 0.68, 0.55, 0.9), 22, 380.0, 0.5, 900.0, 6.0)
	JuiceMan.burst(feet, Color(1.0, 0.85, 0.5, 0.7), 10, 200.0, 0.3, 100.0, 8.0)
	for e in get_tree().get_nodes_in_group("enemy"):
		var foe := e as Node2D
		if foe == null or not foe.has_method("squash"):
			continue
		# Horizontal reach plus a band, not a circle around the enemy's origin.
		# An origin sits at the centre of the collision box, so a taller enemy
		# has its origin further above the floor and a circle quietly shrinks
		# the reach: the Warden is 138 tall, which left only 45px either side of
		# its body -- the guard was near enough impossible to break.
		var off := foe.global_position - feet
		if absf(off.x) < POUND_IMPACT_RADIUS and absf(off.y) < POUND_IMPACT_BAND:
			foe.squash()
	for c in get_tree().get_nodes_in_group("cracked"):
		var slab := c as Node2D
		if slab == null or not slab.has_method("break_floor"):
			continue
		if slab.global_position.distance_to(feet) < POUND_BREAK_RADIUS:
			slab.break_floor()


func set_checkpoint(pos: Vector2) -> void:
	spawn_point = pos
	checkpoint_set.emit(pos)


## Restores health. Returns false when nothing was healed, so a pickup can
## leave itself on the ground instead of being spent at full health.
func heal(amount: int) -> bool:
	if dead or amount <= 0 or hp >= MAX_HP:
		return false
	hp = mini(hp + amount, MAX_HP)
	health_changed.emit(hp, MAX_HP)
	return true


func take_damage(amount: int, from_pos: Vector2) -> void:
	if dead or invuln > 0.0 or (DASH_IFRAMES and is_dashing()):
		return
	hp = maxi(hp - amount, 0)
	invuln = 1.0
	hurt_t = 0.3
	health_changed.emit(hp, MAX_HP)
	var away: float = sign(global_position.x - from_pos.x)
	if away == 0.0:
		away = -facing
	velocity = Vector2(away * 330.0, -280.0)
	AudioMan.play("player_hurt")
	JuiceMan.shake(0.45)
	JuiceMan.hit_stop(0.05)
	if hp <= 0:
		_die()


func kill() -> void:

	if dead:
		return
	hp = 0
	health_changed.emit(hp, MAX_HP)
	_die()


func _die() -> void:
	dead = true
	velocity = Vector2.ZERO
	AudioMan.play("player_die")
	JuiceMan.shake(0.6)
	JuiceMan.burst(global_position, Color(0.75, 0.25, 0.35), 18, 300.0, 0.6, 600.0, 5.0)
	died.emit()


func respawn() -> void:
	global_position = spawn_point
	velocity = Vector2.ZERO
	hp = MAX_HP
	dead = false
	invuln = 1.0
	jumps_used = 0
	dash_timer = 0.0
	dash_cd = 0.0
	pounding = false
	pound_t = 0.0
	hurt_t = 0.0
	health_changed.emit(hp, MAX_HP)
