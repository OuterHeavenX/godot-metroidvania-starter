extends Node2D


const CELL := 128
const ANIMS := {
	"warrior": {"idle": 7, "walk": 7, "attack1": 5, "attack2": 6, "hurt": 2, "dead": 4},
	"spearman": {"idle": 7, "walk": 7, "attack1": 4, "attack2": 4, "hurt": 3, "dead": 4},
	"archer": {"idle": 7, "walk": 8, "attack1": 5, "hurt": 2, "dead": 5, "shot1": 15},
}
const FILES := {"idle": "Idle.png", "walk": "Walk.png", "attack1": "Attack_1.png",
	"attack2": "Attack_2.png", "hurt": "Hurt.png", "dead": "Dead.png", "shot1": "Shot_1.png"}
const FPS := {"idle": 8, "walk": 10, "attack1": 13, "attack2": 13,
	"hurt": 10, "dead": 9, "shot1": 16}

var kind := "warrior"
var sprite: AnimatedSprite2D
var _ready_done := false


func setup(p_kind: String) -> void:
	kind = p_kind
	_build()


func _build() -> void:
	var frames := SpriteFrames.new()
	var dir := "res://assets/sprites/enemies/skeleton_%s/" % kind
	var names: Dictionary = ANIMS[kind]
	for anim_name in names.keys():
		var file: String = dir + FILES[anim_name]
		var tex := load(file) as Texture2D
		if tex == null:
			push_warning("skeleton_visual: missing strip " + file)
			continue
		frames.add_animation(anim_name)
		frames.set_animation_speed(anim_name, FPS.get(anim_name, 10))
		frames.set_animation_loop(anim_name, anim_name == "idle" or anim_name == "walk")
		var count: int = names[anim_name]
		for i in range(count):
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(i * CELL, 0, CELL, CELL)
			frames.add_frame(anim_name, at)
	sprite = AnimatedSprite2D.new()
	sprite.name = "Sprite"
	sprite.sprite_frames = frames
	sprite.position = Vector2(0, -12)
	sprite.play("idle")
	add_child(sprite)
	_ready_done = true


func play(anim_name: String) -> void:
	if sprite != null and sprite.sprite_frames.has_animation(anim_name):
		if sprite.animation != anim_name:
			sprite.play(anim_name)


func frame() -> int:
	return sprite.frame if sprite != null else 0


func _process(_delta: float) -> void:
	if not _ready_done:
		return

	var e := get_parent()
	if e != null and "hit_flash" in e and e.hit_flash > 0.0:
		sprite.modulate = Color(2.4, 1.1, 1.1)
	else:
		sprite.modulate = Color.WHITE
