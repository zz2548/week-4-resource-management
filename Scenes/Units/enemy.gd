extends Unit
class_name Enemy

# Enemy-specific properties
@export var enemy_type: String = "basic"

func _ready():
	super._ready()
	team = "enemy"  # Make sure this is set
	print("[", name, "] Enemy ready! Type: ", enemy_type)

# You can override behavior for different enemy types
func get_movement_animation(direction: String) -> String:
	# Enemies might have different animations
	return super.get_movement_animation(direction)
