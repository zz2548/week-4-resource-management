extends Node2D

@onready var sprite: AnimatedSprite2D = $Sprite2D

func _ready() -> void:
	sprite.play("idle")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
