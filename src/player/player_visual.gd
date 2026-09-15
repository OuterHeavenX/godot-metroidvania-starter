extends Node2D
## Martial Hero sprite look for the player (CC0 "Martial Hero" pixel-art pack).
## AnimatedSprite2D built from 200x200 sprite strips; keeps the old juice:
## facing flip, squash & stretch, hurt blink, slash arc, pound streaks.

const CELL := 200
const SPRITE_SCALE := 0.85
# Sprite-local offset so the body's feet plant at y=+22, centered on x=0.
const SPRITE_POS := Vector2(5.1, 4.15)

var player: MVPlayer
var t := 0.0
var sprite: AnimatedSprite2D
var _attack_alt := false
var _attacking := false
var _ghost_cd := 0.0


func _ready() -> void:
	player = get_parent() as MVPlayer
	sprite = AnimatedSprite2D.new()
	sprite.name = "HeroSprite"
	sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	sprite.position = SPRITE_POS
	sprite.sprite_frames = _build_frames()
	add_child(sprite)
	sprite.play("idle")


func _build_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	# name -> [file, frame_count, fps, loop]
	var defs := {
		"idle": ["Idle.png", 8, 8.0, true],
		"run": ["Run.png", 8, 12.0, true],
		"jump": ["Jump.png", 2, 6.0, true],
		"fall": ["Fall.png", 2, 6.0, true],
		"attack1": ["Attack1.png", 6, 14.0, false],
		"attack2": ["Attack2.png", 6, 14.0, false],
		"hurt": ["Take Hit.png", 4, 10.0, false],
		"death": ["Death.png", 6, 8.0, false],
	}
	for anim_name in defs:
		var d: Array = defs[anim_name]
		sf.add_animation(anim_name)
		var tex := load("res://assets/sprites/hero/" + String(d[0])) as Texture2D
		for i in int(d[1]):
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(i * CELL, 0, CELL, CELL)
			sf.add_frame(anim_name, at)
		sf.set_animation_speed(anim_name, float(d[2]))
		sf.set_animation_loop(anim_name, bool(d[3]))
	return sf


func _play(anim_name: String, speed_scale: float = 1.0) -> void:
	if sprite.animation == anim_name and sprite.is_playing():
		sprite.speed_scale = speed_scale
		return
	sprite.speed_scale = speed_scale
	sprite.play(anim_name)


func _process(delta: float) -> void:
	t += delta
	if player == null:
		return
	if player.invuln > 0.0 and not player.dead:
		modulate.a = 0.45 + 0.35 * sin(t * 40.0)
	else:
		modulate.a = 1.0

	# --- animation state ---
	if player.dead:
		_play("death")
	elif player.hurt_t > 0.0:
		_play("hurt")
	elif player.attack_t > 0.0:
		if not _attacking:
			_attacking = true
			_attack_alt = not _attack_alt
		_play("attack2" if _attack_alt else "attack1")
	elif player.is_pounding():
		_play("fall")
	elif player.is_dashing():
		_play("run", 1.7)
	elif not player.is_on_floor():
		_play("jump" if player.velocity.y < 0.0 else "fall")
	elif absf(player.velocity.x) > 20.0:
		_play("run")
	else:
		_play("idle")
	if player.attack_t <= 0.0:
		_attacking = false
	if not player.dead and sprite.animation == "death":
		sprite.play("idle")

	# --- squash & stretch (whole Visual flips with facing, so +x stays forward) ---
	var target := Vector2.ONE
	if player.is_pounding():
		target = Vector2(0.82, 1.32) # tucked for the slam
	elif player.is_dashing():
		target = Vector2(1.3, 0.75)
	elif not player.is_on_floor():
		target = Vector2(0.88, 1.12)
	scale = scale.lerp(Vector2(target.x * player.facing, target.y), 12.0 * delta)
	# dash afterimages: fading ghosts of the current frame
	if player.is_dashing():
		_ghost_cd -= delta
		if _ghost_cd <= 0.0:
			_ghost_cd = 0.045
			_spawn_ghost()
	else:
		_ghost_cd = 0.0
	queue_redraw()


func _spawn_ghost() -> void:
	var tex := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	if tex == null:
		return
	var g := Sprite2D.new()
	g.texture = tex
	var scene := get_tree().current_scene
	if scene == null:
		return
	scene.add_child(g)
	g.global_transform = sprite.get_global_transform()
	g.modulate = Color(0.55, 0.85, 1.0, 0.45)
	var tw := g.create_tween()
	tw.tween_property(g, "modulate:a", 0.0, 0.28)
	tw.tween_callback(g.queue_free)


func _draw() -> void:
	# speed streaks while slamming down
	if player != null and player.is_pounding() and player.pound_t <= 0.0:
		for i in range(3):
			var sx := -14.0 + i * 14.0
			var sway := sin(t * 30.0 + i * 2.1) * 3.0
			draw_line(Vector2(sx + sway, -52), Vector2(sx + sway, -30),
				Color(1.0, 0.8, 0.45, 0.55), 3.0)
	# slash trail on top of the sprite's sword swing
	# (node is flipped by facing, so +x is always forward)
	if player != null and player.attack_t > 0.0:
		var a: float = player.attack_t / player.ATTACK_ACTIVE
		var slash := Color(1.0, 0.92, 0.65, 0.9 * a)
		draw_arc(Vector2(40, -6), 30, -1.15, 1.15, 18, slash, 3.0 + 6.0 * a)
		draw_arc(Vector2(40, -6), 22, -0.9, 0.9, 14, Color(1, 1, 1, 0.5 * a), 2.0)
