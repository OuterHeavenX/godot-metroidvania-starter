class_name MVPlayer
extends CharacterBody2D


signal feedback(event: StringName, details: Dictionary)
signal action_changed(previous: int, current: int)

enum Action { NORMAL, DASH, POUND_WINDUP, POUND_FALL, HURT, DEAD }
const TRANSITIONS := {
	Action.NORMAL: [Action.DASH, Action.POUND_WINDUP, Action.HURT, Action.DEAD],
	Action.DASH: [Action.NORMAL, Action.POUND_WINDUP, Action.HURT, Action.DEAD],
	Action.POUND_WINDUP: [Action.POUND_FALL, Action.NORMAL, Action.HURT, Action.DEAD],
	Action.POUND_FALL: [Action.NORMAL, Action.HURT, Action.DEAD],
	Action.HURT: [Action.NORMAL, Action.DEAD],
	Action.DEAD: [],
}
var action_state: Action = Action.NORMAL
var combat := MVCombat.new()
var melee := MVMeleeAttack.new()
var _dash_time := 0.0
var _hurt_time := 0.0

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
## The sword reached less far than half the enemy roster. At 86 the player was
## third shortest of six -- shorter than a shielder -- which is what made
## trading blows feel cramped.
const ATTACK_RANGE := 112.0
const ATTACK_HALF_HEIGHT := 58.0
const ATTACK_COOLDOWN := 0.38
const ATTACK_ACTIVE := 0.16
const ATTACK_BUFFER := 0.14
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
## Slower than the sword's 0.38 so range costs something.
const THROW_COOLDOWN := 0.55
const DASH_IFRAMES := true
# The camera's drag margin makes it trail the player, which shows where you
# have been rather than where you are going. Leading by roughly the same
# distance re-centres the view in the direction of travel.
const CAM_LOOKAHEAD := 60.0
const CAM_LOOKAHEAD_RATE := 4.0

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity", 980.0)
var hp: int:
	get: return combat.hp
	set(value): combat.hp = value
var has_double_jump := false
var has_ground_pound := false
var has_dagger := false
var throw_cd := 0.0
var pounding: bool:
	get: return action_state in [Action.POUND_WINDUP, Action.POUND_FALL]
	set(value):
		if value: _transition(Action.POUND_WINDUP)
		elif pounding: _transition(Action.NORMAL)
var pound_t := 0.0
var jumps_used := 0
var coyote := 0.0
var buffer := 0.0
var dash_timer: float:
	get: return _dash_time
	set(value):
		if value > 0.0:
			_transition(Action.DASH)
			_dash_time = value if action_state == Action.DASH else 0.0
		else:
			_dash_time = 0.0
			if action_state == Action.DASH: _transition(Action.NORMAL)
var dash_cd := 0.0
var dash_dir := 1.0
var dash_available := true
var invuln: float:
	get: return combat.invulnerability
	set(value): combat.invulnerability = value
var hurt_t: float:
	get: return _hurt_time
	set(value):
		_hurt_time = maxf(value, 0.0)
		if value > 0.0: _transition(Action.HURT)
		elif action_state == Action.HURT: _transition(Action.NORMAL)
var dead: bool:
	get: return action_state == Action.DEAD
	set(value):
		if value: _transition(Action.DEAD)
		elif dead: _transition(Action.NORMAL, true)
var facing := 1.0
var attack_cd: float:
	get: return melee.cooldown
	set(value): melee.cooldown = value
var attack_t: float:
	get: return melee.active
	set(value): melee.active = value
var attack_buffer: float:
	get: return melee.buffered
	set(value): melee.buffered = value
var _was_floor := false
var _fall_v := 0.0
var spawn_point := Vector2.ZERO

@onready var visual: Node2D = $Visual

@onready var camera: MVCameraRig = $Camera2D


func _ready() -> void:
	add_to_group("player")
	combat.name = "Combat"
	combat.configure(MAX_HP, 1.0)
	combat.damage_policy = _damage_policy
	combat.health_changed.connect(func(value: int, maximum: int) -> void: health_changed.emit(value, maximum))
	combat.damaged.connect(_on_damaged)
	combat.depleted.connect(_die)
	add_child(combat)
	melee.name = "MeleeAttack"
	melee.reach = ATTACK_RANGE
	melee.half_height = ATTACK_HALF_HEIGHT
	melee.back_grace = ATTACK_BACK_GRACE
	melee.started.connect(func() -> void: feedback.emit(&"attack", {}))
	add_child(melee)
	add_child(preload("res://src/presentation/player_feedback.gd").new())
	floor_snap_length = 6.0
	spawn_point = global_position


func max_jumps() -> int:
	return 2 if has_double_jump else 1


func is_dashing() -> bool:
	return action_state == Action.DASH and dash_timer > 0.0


func is_pounding() -> bool:
	return pounding


func gain_ability(ability_id: String) -> void:
	if ability_id not in MVRunSnapshot.ABILITIES:
		return
	if ability_id == "double_jump":
		has_double_jump = true
	elif ability_id == "ground_pound":
		has_ground_pound = true
	elif ability_id == "dagger":
		has_dagger = true
	ability_gained.emit(ability_id)


func _transition(next: Action, force: bool = false) -> void:
	if next == action_state or (not force and next not in TRANSITIONS[action_state]):
		return
	var previous := action_state
	action_state = next
	if next != Action.DASH:
		_dash_time = 0.0
	if next not in [Action.POUND_WINDUP, Action.POUND_FALL]:
		pound_t = 0.0
	if next != Action.HURT:
		_hurt_time = 0.0
	if next in [Action.POUND_WINDUP, Action.HURT, Action.DEAD]:
		melee.reset()
		buffer = 0.0
	action_changed.emit(previous, next)


func _do_attack() -> void:
	if action_state not in [Action.NORMAL, Action.DASH]:
		return
	melee.begin()
	_resolve_attack_hits()


func _resolve_attack_hits() -> void:
	melee.resolve(self, facing)


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
		# Leaving a ledge consumes the grounded jump after the grace window.
		if coyote <= 0.0:
			jumps_used = maxi(jumps_used, 1)
		if on_wall:
			dash_available = true
	buffer = maxf(buffer - delta, 0.0)
	dash_cd = maxf(dash_cd - delta, 0.0)
	combat.tick(delta)
	hurt_t = maxf(hurt_t - delta, 0.0)
	throw_cd = maxf(throw_cd - delta, 0.0)
	melee.tick(delta)

	if Input.is_action_just_pressed("jump"):
		buffer = JUMP_BUFFER
	if Input.is_action_just_released("jump") and action_state == Action.NORMAL and velocity.y < JUMP_CUT:
		velocity.y = JUMP_CUT

	if Input.is_action_just_pressed("pound") and has_ground_pound \
			and not is_on_floor() and action_state in [Action.NORMAL, Action.DASH]:
		pounding = true
		pound_t = POUND_WINDUP
		dash_timer = 0.0


	if Input.is_action_just_pressed("dash") and dash_cd <= 0.0 and dash_available \
			and action_state == Action.NORMAL:
		dash_timer = DASH_TIME
		dash_cd = DASH_COOLDOWN
		dash_available = false
		dash_dir = dir if dir != 0.0 else facing
		facing = dash_dir
		feedback.emit(&"dash", {})


	if Input.is_action_just_pressed("throw") and has_dagger and throw_cd <= 0.0 \
			and action_state in [Action.NORMAL, Action.DASH]:
		_throw_dagger()

	if Input.is_action_just_pressed("attack"):
		melee.request()
	melee.try_start(action_state in [Action.NORMAL, Action.DASH])

	if action_state == Action.HURT:
		velocity.y = minf(velocity.y + _gravity_now() * delta, MAX_FALL_SPEED)
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * 0.2 * delta)
	elif pounding:

		if pound_t > 0.0:
			pound_t -= delta
			velocity = Vector2.ZERO
		else:
			_transition(Action.POUND_FALL)
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
				feedback.emit(&"jump", {})
			elif is_on_floor() or coyote > 0.0:
				velocity.y = JUMP_VELOCITY
				jumps_used = 1
				buffer = 0.0
				coyote = 0.0
				feedback.emit(&"jump", {})
			elif jumps_used < max_jumps():
				velocity.y = JUMP_VELOCITY * 0.92
				jumps_used += 1
				buffer = 0.0
				feedback.emit(&"double_jump" if has_double_jump else &"jump", {})

	if camera != null:
		camera.update_view(delta, facing)

	_was_floor = is_on_floor()
	_fall_v = velocity.y
	move_and_slide()
	if attack_t > 0.0:
		_resolve_attack_hits()
	if pounding and is_on_floor():
		_pound_impact()
	elif not _was_floor and is_on_floor() and _fall_v > 520.0 and not dead:
		feedback.emit(&"land", {})


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


## Thrown from the hand, in the direction faced. Deliberately slower to repeat
## than the sword: at range you trade damage rate for not being in reach.
func _throw_dagger() -> void:
	throw_cd = THROW_COOLDOWN
	var blade := MVDagger.new()
	blade.setup(facing, global_position + Vector2(facing * 22.0, -18.0))
	get_parent().add_child(blade)
	feedback.emit(&"throw", {})


func _pound_impact() -> void:

	pounding = false
	pound_t = 0.0
	var feet := global_position + Vector2(0, 22)
	feedback.emit(&"pound", {"feet": feet})
	for foe in MVMeleeAttack.nearby(self, feet, POUND_IMPACT_RADIUS, 2):
		# Horizontal reach plus a band, not a circle around the enemy's origin:
		# an origin sits at the centre of the collision box, so a taller enemy
		# has its origin further above the floor and a circle quietly shrinks
		# the reach.
		var off := foe.global_position - feet
		if absf(off.x) < POUND_IMPACT_RADIUS and absf(off.y) < POUND_IMPACT_BAND:
			MVDamage.deliver(foe, MVDamage.new(1, feet, MVDamage.Kind.IMPACT))
	for body in MVMeleeAttack.nearby(self, feet, POUND_BREAK_RADIUS, 4):
		var slab := body as MVCrackedFloor
		if slab != null and slab.global_position.distance_to(feet) < POUND_BREAK_RADIUS:
			slab.break_floor()


func set_checkpoint(pos: Vector2) -> void:
	spawn_point = pos
	checkpoint_set.emit(pos)


## Restores health. Returns false when nothing was healed, so a pickup can
## leave itself on the ground instead of being spent at full health.
func heal(amount: int) -> bool:
	return combat.heal(amount) if not dead else false


func _damage_policy(hit: MVDamage) -> int:
	return 0 if dead or (DASH_IFRAMES and is_dashing()) else hit.amount


func take_damage(amount: int, from_pos: Vector2) -> void:
	combat.receive(MVDamage.new(amount, from_pos, MVDamage.Kind.CONTACT))


func _on_damaged(hit: MVDamage) -> void:
	hurt_t = 0.3
	velocity = MVCombat.knockback(hit.origin, global_position, -facing, 330.0, -280.0)
	feedback.emit(&"hurt", {})


func kill() -> void:

	if dead:
		return
	combat.defeat()


func _die() -> void:
	if dead:
		return
	dead = true
	velocity = Vector2.ZERO
	feedback.emit(&"death", {})
	died.emit()


func respawn() -> void:
	global_position = spawn_point
	velocity = Vector2.ZERO
	dead = false
	combat.reset(1.0)
	jumps_used = 0
	dash_timer = 0.0
	dash_cd = 0.0
	pounding = false
	pound_t = 0.0
	hurt_t = 0.0
	coyote = 0.0
	buffer = 0.0
	melee.reset()
	dash_available = true
	_was_floor = false
	_fall_v = 0.0
	if camera != null:
		camera.reset_smoothing()


func bounce_from_stomp() -> void:
	if dead:
		return
	pounding = false
	velocity.y = JUMP_VELOCITY * 0.7
	jumps_used = 1
	# Stomp and contact areas may both enter on this tick, in either order.
	invuln = maxf(invuln, 0.12)
