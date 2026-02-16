extends CanvasLayer

@onready var turn_label: Label = $Panel/TurnLabel
@onready var end_turn_button: Button = $Panel/EndTurnButton
@onready var unit_info: Panel = $UnitInfo
@onready var unit_name_label: Label = $UnitInfo/VBoxContainer/NameLabel
@onready var health_bar: ProgressBar = $UnitInfo/VBoxContainer/HealthBar
@onready var health_label: Label = $UnitInfo/VBoxContainer/HealthLabel

signal end_turn_pressed

func _ready():
	print("=== TurnUI _ready() ===")
	print("End turn button exists: ", end_turn_button != null)
	
	if end_turn_button:
		end_turn_button.pressed.connect(_on_end_turn_pressed)
		print("✓ Connected button signal")
	else:
		push_error("End turn button is NULL!")
	
	if unit_info:
		unit_info.visible = false

func _on_end_turn_pressed():
	print("!!! END TURN BUTTON PRESSED !!!")
	end_turn_pressed.emit()

func set_turn(is_player_turn: bool):
	print("set_turn called: ", "PLAYER" if is_player_turn else "ENEMY")
	
	if turn_label:
		if is_player_turn:
			turn_label.text = "PLAYER TURN"
			turn_label.modulate = Color.GREEN
		else:
			turn_label.text = "ENEMY TURN"
			turn_label.modulate = Color.RED
	
	if end_turn_button:
		end_turn_button.disabled = not is_player_turn
		print("Button disabled: ", end_turn_button.disabled)

func show_unit_info(unit: Unit):
	if unit == null:
		if unit_info:
			unit_info.visible = false
		return
	
	if not unit_info:
		return
	
	unit_info.visible = true
	
	if unit_name_label:
		unit_name_label.text = unit.name
	
	if health_bar:
		health_bar.max_value = unit.max_health
		health_bar.value = unit.current_health
		
		# Color the health bar based on health percentage
		var health_percent = float(unit.current_health) / float(unit.max_health)
		if health_percent > 0.6:
			health_bar.modulate = Color.GREEN
		elif health_percent > 0.3:
			health_bar.modulate = Color.YELLOW
		else:
			health_bar.modulate = Color.RED
	
	if health_label:
		health_label.text = str(unit.current_health) + " / " + str(unit.max_health)

func hide_unit_info():
	if unit_info:
		unit_info.visible = false
