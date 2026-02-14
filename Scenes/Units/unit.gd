extends Node2D
class_name Unit

@onready var sprite: AnimatedSprite2D = $Sprite2D

enum State {IDLE, MOVING, ATTACKING}
var current_state: State = State.IDLE
var current_direction: String = "down"

func _ready():
	print("[", name, "] Unit _ready() called")
	if sprite == null:
		push_error("[", name, "] Sprite2D not found!")
	else:
		print("[", name, "] Sprite found, playing idle")
		sprite.play("idle")

func set_moving(direction: String):
	print("[", name, "] set_moving('", direction, "')")
	current_state = State.MOVING
	current_direction = direction
	
	if sprite == null:
		push_error("[", name, "] Cannot animate - sprite is null!")
		return
	
	# Map any direction to your two available run animations
	var anim_name = ""
	
	match direction:
		"right", "down", "right_and_down", "down_and_right":
			anim_name = "run_right_and_down"
		"left", "up", "left_and_up", "up_and_left":
			anim_name = "run_left_and_up"
		_:
			anim_name = "run_right_and_down"  # Default
	
	print("  Direction '", direction, "' -> Playing: ", anim_name)
	sprite.play(anim_name)

func set_idle():
	print("[", name, "] set_idle()")
	current_state = State.IDLE
	if sprite:
		sprite.play("idle")
