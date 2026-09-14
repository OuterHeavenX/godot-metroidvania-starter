extends Node


var frames := 0
var fails := 0
var phase := 0
var skels: Array = []
var warrior: MVSkeleton
var archer: MVSkeleton
var x0 := 0.0
var hp0 := 0
var player_hp0 := 0
var done := false
var saw_arrow := false


func _ready() -> void:
	print("== skeleton enemy boot")


func check(cond: bool, label: String) -> void:
	if cond:
		print("  ok   " + label)
	else:
		fails += 1
		print("  FAIL " + label)


func _physics_process(_d: float) -> void:
	if done:
		return
	frames += 1
	if phase == 3 and _find_arrows(get_tree().current_scene).size() > 0:
		saw_arrow = true
	if phase == 0 and frames > 90:
		skels = get_tree().get_nodes_in_group("enemy")
		# Counts are level content, not behaviour: assert every kind is present
		# and well-formed so new encounters can be added without editing this.
		check(skels.size() >= 4, "skeletons spawned (%d)" % skels.size())
		var kinds: Array = []
		for s in skels:
			kinds.append(s.kind)
			if s.kind == "warrior" and warrior == null:
				warrior = s
			if s.kind == "archer":
				archer = s
		check(kinds.count("warrior") >= 1, "warriors present (%d)" % kinds.count("warrior"))
		check(kinds.count("spearman") >= 1, "spearmen present (%d)" % kinds.count("spearman"))
		check(kinds.count("archer") >= 1, "archers present (%d)" % kinds.count("archer"))
		var known := ["warrior", "spearman", "archer"]
		var unknown: Array = []
		for k in kinds:
			if not known.has(k):
				unknown.append(k)
		check(unknown.is_empty(), "every skeleton has a known kind, got %s" % str(unknown))
		for s in skels:
			var spr: AnimatedSprite2D = s.get_node("Visual/Sprite")
			var fr: SpriteFrames = spr.sprite_frames
			check(fr.has_animation("idle") and fr.has_animation("walk")
				and fr.has_animation("hurt") and fr.has_animation("dead"),
				"%s has core anims" % s.kind)
			if s.kind == "archer":
				check(fr.has_animation("shot1"), "archer has shot1")
				check(fr.get_frame_count("shot1") == 15, "archer shot1 = 15 frames")
			else:
				check(fr.has_animation("attack1"), "%s has attack1" % s.kind)
		check(warrior != null and archer != null, "warrior + archer refs")
		x0 = warrior.global_position.x
		phase = 1
	elif phase == 1 and frames > 150:
		check(absf(warrior.global_position.x - x0) > 20.0, "warrior patrols (moved %.0f)" % absf(warrior.global_position.x - x0))
		hp0 = warrior.hp
		warrior.take_hit(warrior.global_position + Vector2(50, 0))
		check(warrior.hp == hp0 - 1, "take_hit drops hp")
		check(warrior.state == "hurt", "take_hit -> hurt state")
		check(warrior.hit_flash > 0.0, "hit flash set")
		phase = 2
	elif phase == 2 and frames > 200:
		check(warrior.state == "patrol" or warrior.state == "attack", "recovers from hurt (state=%s)" % warrior.state)
		var p := get_tree().get_first_node_in_group("player")
		p.global_position = archer.global_position + Vector2(-300, 0)
		p.velocity = Vector2.ZERO
		player_hp0 = p.hp
		phase = 3
	elif phase == 3 and frames > 330:
		check(saw_arrow, "archer fired an arrow")
		check(archer.state == "shoot" or archer.cd_t > 0.0, "archer in shoot cycle")
		phase = 4
	elif phase == 4 and frames > 380:

		var p := get_tree().get_first_node_in_group("player")
		p.invuln = 0.0
		p.hp = 6
		player_hp0 = p.hp
		var guard: MVSkeleton = null
		for s in get_tree().get_nodes_in_group("enemy"):
			if s.kind == "warrior" and s.global_position.y > 100.0:
				guard = s
		if guard != null:
			p.global_position = guard.global_position + Vector2(40, -10)
			p.velocity = Vector2.ZERO
		phase = 5
	elif phase == 5 and frames > 500:
		var p := get_tree().get_first_node_in_group("player")
		check(p.hp < player_hp0, "skeleton melee/hurtbox damages player")
		warrior.squash()
		phase = 6
	elif phase == 6 and frames > 560:
		check(not is_instance_valid(warrior), "squash() frees the skeleton")
		done = true
		if fails == 0:
			print("SKELETON TESTS ALL PASSED")
		else:
			print("SKELETON TESTS: %d FAILURES" % fails)
		get_tree().quit(fails)


func _find_arrows(n: Node) -> Array:
	var out: Array = []
	_collect_arrows(n, out)
	return out


func _collect_arrows(n: Node, out: Array) -> void:
	if n is MVArrow:
		out.append(n)
	for c in n.get_children():
		_collect_arrows(c, out)
