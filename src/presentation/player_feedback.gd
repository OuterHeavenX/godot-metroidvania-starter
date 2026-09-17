extends Node

## Cosmetic effects observe local player events; they never change combat state.
var player: MVPlayer
var _spark_t := 0.0
var _run_dust_t := 0.0

func _ready() -> void:
	player = get_parent() as MVPlayer
	player.feedback.connect(_on_feedback)

func _on_feedback(event: StringName, details: Dictionary) -> void:
	var pos := player.global_position
	match event:
		&"attack": AudioMan.play("attack", -2.0, randf_range(0.95, 1.08))
		# Reuses the swing sample pitched up: a thrown blade is a lighter, faster
		# version of the same sound, and the asset set has no separate throw.
		&"throw": AudioMan.play("attack", -6.0, randf_range(1.3, 1.45))
		&"jump", &"double_jump": AudioMan.play(String(event))
		&"dash":
			AudioMan.play("dash")
			JuiceMan.burst(pos + Vector2(0, 8), Color(0.65, 0.8, 1.0), 10, 220.0, 0.35, 250.0, 4.0)
		&"land":
			AudioMan.play("land", -6.0)
			JuiceMan.burst(pos + Vector2(0, 20), Color(0.55, 0.6, 0.75, 0.8), 8, 150.0, 0.5, 500.0, 4.0, "smoke")
		&"pound":
			var feet: Vector2 = details.feet
			AudioMan.play("pound")
			JuiceMan.shake(0.55)
			JuiceMan.hit_stop(0.08)
			JuiceMan.burst(feet, Color(0.75, 0.68, 0.55, 0.9), 22, 380.0, 0.6, 900.0, 6.0, "smoke")
			JuiceMan.burst(feet, Color(1.0, 0.85, 0.5, 0.7), 10, 200.0, 0.3, 100.0, 8.0)
			JuiceMan.ring(feet, Color(1.0, 0.88, 0.6), 170.0, 0.5, 10.0)
		&"hurt":
			AudioMan.play("player_hurt")
			JuiceMan.shake(0.45)
			JuiceMan.hit_stop(0.05)
		&"death":
			AudioMan.play("player_die")
			JuiceMan.shake(0.6)
			JuiceMan.burst(pos, Color(0.75, 0.25, 0.35), 18, 300.0, 0.6, 600.0, 5.0)

func _process(delta: float) -> void:
	if player.dead:
		return
	if player.is_on_wall_only() and player.velocity.y > 60.0:
		_spark_t -= delta
		if _spark_t <= 0.0:
			_spark_t = 0.09
			var normal := player.get_wall_normal()
			JuiceMan.burst(player.global_position + Vector2(-normal.x * 14.0, -6.0), Color(1.0, 0.8, 0.4, 0.9), 3, 160.0, 0.25, 500.0, 3.5)
	else:
		_spark_t = 0.0
	if player.is_on_floor() and absf(player.velocity.x) >= player.SPEED * 0.9 and not player.is_dashing():
		_run_dust_t -= delta
		if _run_dust_t <= 0.0:
			_run_dust_t = 0.16
			JuiceMan.burst(player.global_position + Vector2(-player.facing * 12.0, 20.0), Color(0.55, 0.6, 0.75, 0.55), 3, 90.0, 0.35, 350.0, 3.5)
	else:
		_run_dust_t = 0.0
