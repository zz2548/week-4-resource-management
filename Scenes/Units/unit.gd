extends Node2D
class_name Unit

@onready var sprite: AnimatedSprite2D = $Sprite2D
@onready var selection_indicator: Sprite2D = $SelectionIndicator

enum State {IDLE, MOVING, ATTACKING, DEAD}
var current_state: State = State.IDLE
var current_direction: String = "down"

# Unit stats
@export var max_health: int = 100
@export var current_health: int = 100
@export var attack_damage: int = 10
@export var move_range: int = 3
@export var attack_range: int = 1
@export var team: String = "player"  # "player" or "enemy"
@export var has_acted: bool = false  # For turn-based system

signal unit_died(unit: Unit)
signal health_changed(new_health: int, max_health: int)

func _ready():
	print("[", name, "] Unit _ready() called")
	if sprite == null:
		push_error("[", name, "] Sprite2D not found!")
	else:
		sprite.play("idle")
	
	if selection_indicator:
		selection_indicator.visible = false
	
	current_health = max_health

func set_moving(direction: String):
	current_state = State.MOVING
	current_direction = direction
	
	if sprite == null:
		push_error("[", name, "] Cannot animate - sprite is null!")
		return
	
	var anim_name = get_movement_animation(direction)
	sprite.play(anim_name)

func get_movement_animation(direction: String) -> String:
	match direction:
		"right", "down", "right_and_down", "down_and_right":
			return "run_right_and_down"
		"left", "up", "left_and_up", "up_and_left":
			return "run_left_and_up"
		_:
			return "run_right_and_down"

func set_idle():
	current_state = State.IDLE
	if sprite:
		sprite.play("idle")

func set_selected(selected: bool):
	if selection_indicator:
		selection_indicator.visible = selected

func take_damage(amount: int):
	current_health -= amount
	current_health = max(0, current_health)
	health_changed.emit(current_health, max_health)
	
	if current_health <= 0:
		die()

func heal(amount: int):
	current_health += amount
	current_health = min(max_health, current_health)
	health_changed.emit(current_health, max_health)

func die():
	current_state = State.DEAD
	unit_died.emit(self)
	queue_free()

func can_attack(target: Unit) -> bool:
	return target.team != team and current_state != State.DEAD

func attack(target: Unit):
	if not can_attack(target):
		return
	
	current_state = State.ATTACKING
	target.take_damage(attack_damage)
	
	await get_tree().create_timer(0.5).timeout
	set_idle()

func get_tile_position(grid: TileMapLayer) -> Vector2i:
	return grid.local_to_map(global_position)

func reset_turn():
	has_acted = false
