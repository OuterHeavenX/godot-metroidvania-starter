extends Control

## The Warden's health and guard, on screen.
##
## Without this the fight is unreadable: the guard is the whole mechanic and it
## was invisible, so an ordinary hit and a hit that rang off the guard looked
## near enough identical, and there was no way to tell a landed blow from a
## wasted one. You could fight it correctly and have no idea you were winning.

const SEGMENT_GAP := 3.0
const PLATE_HATCH := 14.0

var boss_name := "THE WARDEN"
var hp := 0
var max_hp := 1
var guarded := true
var shown := false

## Counts down after a blow rings off the guard, so the plate flashes.
var clang := 0.0
## Counts down after the guard breaks, to hold the "STRIKE" call-out up.
var broke := 0.0


func _ready() -> void:
	visible = false
	set_process(true)
	get_viewport().size_changed.connect(_fit)
	_fit()


## A fixed 430px bar runs off the side of a phone, so take what the screen has.
func _fit() -> void:
	var w: float = minf(430.0, get_viewport_rect().size.x - 48.0)
	offset_left = -w * 0.5
	offset_right = w * 0.5


func _process(delta: float) -> void:
	if not shown:
		return
	if clang > 0.0:
		clang = maxf(0.0, clang - delta)
		queue_redraw()
	if broke > 0.0:
		broke = maxf(0.0, broke - delta)
		queue_redraw()


func engage(who: String, current: int, total: int, is_guarded: bool) -> void:
	boss_name = who
	hp = current
	max_hp = maxi(1, total)
	guarded = is_guarded
	shown = true
	visible = true
	queue_redraw()


func set_hp(current: int, total: int) -> void:
	hp = current
	max_hp = maxi(1, total)
	queue_redraw()


func set_guard(is_guarded: bool) -> void:
	# Only the break is worth a call-out. A guard going back up in phase two
	# announces itself loudly enough on the boss.
	if guarded and not is_guarded:
		broke = 1.6
	guarded = is_guarded
	queue_redraw()


## A blow turned aside. Flash the plate so the player can see why nothing
## happened, rather than concluding their attacks do not work.
func blocked() -> void:
	clang = 0.22
	queue_redraw()


func dismiss() -> void:
	shown = false
	visible = false


func _draw() -> void:
	if not shown:
		return
	var w := size.x
	var bar := Rect2(0, 22, w, 20)

	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(0, 16), boss_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 15,
		Color(0.86, 0.9, 1.0, 0.9))

	draw_rect(bar.grow(3.0), Color(0.03, 0.04, 0.08, 0.8))
	# One segment per point of health, so progress is countable rather than a
	# smooth slide you cannot read under pressure.
	var seg := (w + SEGMENT_GAP) / float(max_hp) - SEGMENT_GAP
	for i in range(max_hp):
		var x := float(i) * (seg + SEGMENT_GAP)
		var filled := i < hp
		var col := Color("c8384a") if filled else Color(0.16, 0.12, 0.18, 0.85)
		if filled and i >= hp - 1:
			col = Color("e8556a")
		draw_rect(Rect2(x, bar.position.y, seg, bar.size.y), col)

	if guarded:
		_plate(bar, font)
	elif broke > 0.0:
		var a: float = clampf(broke / 1.6, 0.0, 1.0)
		draw_string(font, Vector2(0, bar.end.y + 17), "GUARD BROKEN — STRIKE",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.72, 0.3, 0.35 + a * 0.65))


func _plate(bar: Rect2, font: Font) -> void:
	var lit: float = clang / 0.22
	var plate := bar.grow(3.0)
	draw_rect(plate, Color(0.42, 0.48, 0.66).lerp(Color.WHITE, lit * 0.8))
	# Hatching, so the plate reads as armour over the bar and not as a full
	# health bar in a different colour.
	var x := plate.position.x - plate.size.y
	while x < plate.end.x:
		draw_line(Vector2(maxf(x, plate.position.x), plate.end.y),
			Vector2(minf(x + plate.size.y, plate.end.x), plate.position.y),
			Color(0.22, 0.26, 0.4, 0.9), 2.0)
		x += PLATE_HATCH
	draw_rect(plate, Color(0.62, 0.7, 0.9, 0.9), false, 2.0)
	draw_string(font, Vector2(0, plate.end.y + 17), "GUARD UP — GROUND POUND TO BREAK",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
		Color(0.72, 0.8, 1.0, 0.75).lerp(Color.WHITE, lit))
