extends Unit  # Inherit from Unit
class_name Knight

# Knight-specific properties
# Just placeholders
# @export var attack_damage: int = 20
# @export var armor: int = 5

func _ready():
	super._ready()  # ← Call parent's _ready()
	print("[", name, "] Knight ready!")

# You can override methods if knights behave differently
func set_moving(direction: String):
	super.set_moving(direction)  # Call parent behavior
	# Add knight-specific behavior here if needed
