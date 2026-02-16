extends Node2D

@onready var grid: TileMapLayer = $Grid
@onready var player_units: Node = $Units/PlayerGroup
@onready var enemy_units: Node = $Units/OpponentGroup
@onready var ui: CanvasLayer = get_parent().get_node("TurnUI")

var selected_unit: Unit = null
var unit_move_speed: float = 300.0
var astar = AStarGrid2D.new()
var is_moving: bool = false
var unit_paths: Dictionary = {}
var move_range_highlights: Array[ColorRect] = []
var attack_range_highlights: Array[ColorRect] = []

const UNIT_Y_OFFSET = -16
const TILE_SIZE = 32  # Adjust to match your tile size

enum Turn {PLAYER, ENEMY}
var current_turn: Turn = Turn.PLAYER

func _ready():
	print("=== BOARD MANAGER READY ===")
	
	# Setup A* grid
	astar.region = Rect2i(0, 0, 5, 5)
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.update()
	
	print("Waiting for units...")
	await get_tree().process_frame
	print("Units ready!")
	
	# Connect signals
	if player_units:
		for unit in player_units.get_children():
			if unit is Unit:
				unit.unit_died.connect(_on_unit_died)
				unit.health_changed.connect(_on_unit_health_changed)
	
	if enemy_units:
		for unit in enemy_units.get_children():
			if unit is Unit:
				unit.unit_died.connect(_on_unit_died)
	
	print("Waiting for UI...")
	await get_tree().process_frame
	print("UI should be ready now!")
	
	# Connect UI
	print("Checking UI connection...")
	if ui:
		print("  UI exists: ", ui)
		print("  UI has signal: ", ui.has_signal("end_turn_pressed"))
		ui.end_turn_pressed.connect(end_player_turn)
		print("  ✓ Connected signal")
		ui.set_turn(true)
	else:
		push_warning("  No UI found!")
	
	print("=== SETUP COMPLETE ===")

func _unhandled_input(event: InputEvent):
	if current_turn != Turn.PLAYER or is_moving:
		return
		
	if event.is_action_pressed("left_click"):
		var tile_pos = grid.local_to_map(grid.to_local(get_global_mouse_position()))
		
		if selected_unit == null:
			# Try to select a unit
			selected_unit = get_unit_at_tile(tile_pos)
			if selected_unit and selected_unit.team == "player" and not selected_unit.has_acted:
				select_unit(selected_unit)
			elif selected_unit:
				selected_unit = null
		else:
			# Unit is already selected
			var target_unit = get_unit_at_tile(tile_pos)
			
			if target_unit:
				# Clicked on another unit
				if target_unit.team != selected_unit.team:
					# Attack enemy
					attempt_attack(selected_unit, target_unit)
				else:
					# Switch selection
					deselect_current_unit()
					if not target_unit.has_acted:
						select_unit(target_unit)
			else:
				# Move to empty tile
				if is_tile_in_move_range(tile_pos):
					is_moving = true
					await move_unit_to(selected_unit, tile_pos)
					selected_unit.has_acted = true
					deselect_current_unit()

	elif event.is_action_pressed("right_click"):
		deselect_current_unit()

func select_unit(unit: Unit):
	selected_unit = unit
	selected_unit.set_selected(true)
	show_unit_ranges(selected_unit)
	if ui:
		ui.show_unit_info(selected_unit)
	print("✓ Selected: ", selected_unit.name)

func show_unit_ranges(unit: Unit):
	clear_range_highlights()
	
	var unit_tile = unit.get_tile_position(grid)
	
	# Show movement range
	var move_tiles = get_tiles_in_range(unit_tile, unit.move_range)
	for tile in move_tiles:
		if is_valid_move_target(tile):
			create_highlight(tile, Color(0, 1, 0, 0.3), move_range_highlights)
	
	# Show attack range from current position
	var attack_tiles = get_tiles_in_range(unit_tile, unit.attack_range)
	for tile in attack_tiles:
		var target = get_unit_at_tile(tile)
		if target and target.team != unit.team:
			create_highlight(tile, Color(1, 0, 0, 0.3), attack_range_highlights)

func is_tile_in_move_range(tile_pos: Vector2i) -> bool:
	if not selected_unit or not is_valid_move_target(tile_pos):
		return false
	
	var unit_tile = selected_unit.get_tile_position(grid)
	var distance = abs(tile_pos.x - unit_tile.x) + abs(tile_pos.y - unit_tile.y)
	return distance <= selected_unit.move_range

func create_highlight(tile_pos: Vector2i, color: Color, array: Array):
	var highlight = ColorRect.new()
	highlight.color = color
	highlight.size = Vector2(TILE_SIZE, TILE_SIZE)
	highlight.position = grid.map_to_local(tile_pos) - Vector2(TILE_SIZE/2, TILE_SIZE/2)
	highlight.z_index = -1  # Behind units
	highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE  # ← ADD THIS LINE
	add_child(highlight)
	array.append(highlight)

func clear_range_highlights():
	for highlight in move_range_highlights:
		highlight.queue_free()
	move_range_highlights.clear()
	
	for highlight in attack_range_highlights:
		highlight.queue_free()
	attack_range_highlights.clear()

func get_tiles_in_range(center: Vector2i, range: int) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	
	for x in range(-range, range + 1):
		for y in range(-range, range + 1):
			var tile = center + Vector2i(x, y)
			var distance = abs(x) + abs(y)
			if distance <= range and distance > 0:
				tiles.append(tile)
	
	return tiles

func get_unit_at_tile(tile_pos: Vector2i) -> Unit:
	if player_units:
		for unit in player_units.get_children():
			if unit is Unit and unit.get_tile_position(grid) == tile_pos:
				return unit
	
	if enemy_units:
		for unit in enemy_units.get_children():
			if unit is Unit and unit.get_tile_position(grid) == tile_pos:
				return unit
	
	return null

func is_valid_move_target(tile_pos: Vector2i) -> bool:
	return get_unit_at_tile(tile_pos) == null and grid.get_cell_tile_data(tile_pos) != null

func deselect_current_unit():
	if selected_unit:
		selected_unit.set_selected(false)
		selected_unit = null
		clear_range_highlights()
		if ui:
			ui.hide_unit_info()

func attempt_attack(attacker: Unit, target: Unit):
	var attacker_tile = attacker.get_tile_position(grid)
	var target_tile = target.get_tile_position(grid)
	var distance = abs(attacker_tile.x - target_tile.x) + abs(attacker_tile.y - target_tile.y)
	
	if distance <= attacker.attack_range:
		await attacker.attack(target)
		attacker.has_acted = true
		deselect_current_unit()
	else:
		print("Target out of range! Distance:", distance, "Range:", attacker.attack_range)

func move_unit_to(unit: Unit, target_tile: Vector2i):
	var start_tile = unit.get_tile_position(grid)
	var path = astar.get_id_path(start_tile, target_tile).slice(1)
	
	if path.is_empty():
		is_moving = false
		return
	
	unit_paths[unit] = path
	await move_unit_along_path(unit)
	is_moving = false

func move_unit_along_path(unit: Unit):
	if not unit_paths.has(unit) or unit_paths[unit].is_empty():
		if unit.has_method("set_idle"):
			unit.set_idle()
		return
	
	var current_path = unit_paths[unit]
	var target_pos = grid.map_to_local(current_path[0])
	target_pos.y += UNIT_Y_OFFSET
	
	var current_tile = unit.get_tile_position(grid)
	var next_tile = current_path[0]
	var direction = get_movement_direction(current_tile, next_tile)
	
	if unit.has_method("set_moving"):
		unit.set_moving(direction)
	
	var tween = create_tween()
	tween.tween_property(unit, "global_position", target_pos, 0.3)
	await tween.finished
	
	current_path.pop_front()
	if current_path.is_empty():
		unit_paths.erase(unit)
		if unit.has_method("set_idle"):
			unit.set_idle()
	else:
		await move_unit_along_path(unit)

func get_movement_direction(from: Vector2i, to: Vector2i) -> String:
	var delta = to - from
	
	if delta.x != 0 and delta.y != 0:
		var horizontal = "right" if delta.x > 0 else "left"
		var vertical = "down" if delta.y > 0 else "up"
		return horizontal + "_and_" + vertical
	
	if delta.y > 0:
		return "down"
	elif delta.y < 0:
		return "up"
	elif delta.x > 0:
		return "right"
	elif delta.x < 0:
		return "left"
	
	return "down"

func end_player_turn():
	print("=== ENDING PLAYER TURN ===")
	current_turn = Turn.ENEMY
	deselect_current_unit()
	
	if ui:
		ui.set_turn(false)
	
	# Reset player units
	if player_units:
		for unit in player_units.get_children():
			if unit is Unit:
				unit.reset_turn()
	
	# Execute enemy turn
	await execute_enemy_turn()
	
	# Start player turn
	current_turn = Turn.PLAYER
	if ui:
		ui.set_turn(true)
	print("=== PLAYER TURN START ===")

func execute_enemy_turn():
	print("=== ENEMY TURN ===")
	
	if not enemy_units:
		return
	
	for unit in enemy_units.get_children():
		if unit is Unit and not unit.has_acted:
			await execute_enemy_unit_action(unit)
	
	for unit in enemy_units.get_children():
		if unit is Unit:
			unit.reset_turn()
	
	await get_tree().create_timer(0.5).timeout

func execute_enemy_unit_action(enemy: Unit):
	var closest_player = find_closest_player_unit(enemy)
	if not closest_player:
		return
	
	var enemy_tile = enemy.get_tile_position(grid)
	var player_tile = closest_player.get_tile_position(grid)
	var distance = abs(enemy_tile.x - player_tile.x) + abs(enemy_tile.y - player_tile.y)
	
	if distance <= enemy.attack_range:
		await enemy.attack(closest_player)
	else:
		var move_target = get_tile_toward_target(enemy_tile, player_tile, enemy.move_range)
		if move_target != enemy_tile:
			await move_unit_to(enemy, move_target)
	
	enemy.has_acted = true

func find_closest_player_unit(from_unit: Unit) -> Unit:
	if not player_units:
		return null
		
	var closest: Unit = null
	var min_distance = 999999
	var from_tile = from_unit.get_tile_position(grid)
	
	for unit in player_units.get_children():
		if unit is Unit:
			var unit_tile = unit.get_tile_position(grid)
			var distance = abs(from_tile.x - unit_tile.x) + abs(from_tile.y - unit_tile.y)
			if distance < min_distance:
				min_distance = distance
				closest = unit
	
	return closest

func get_tile_toward_target(from: Vector2i, to: Vector2i, max_distance: int) -> Vector2i:
	var path = astar.get_id_path(from, to)
	if path.size() <= 1:
		return from
	
	var move_distance = min(max_distance, path.size() - 1)
	return path[move_distance]

func _on_unit_died(unit: Unit):
	print("Unit died: ", unit.name)
	if unit == selected_unit:
		deselect_current_unit()
	check_game_over()

func _on_unit_health_changed(new_health: int, max_health: int):
	# Update UI if the damaged unit is selected
	if selected_unit and ui:
		ui.show_unit_info(selected_unit)

func check_game_over():
	var player_alive = false
	var enemy_alive = false
	
	if player_units:
		for unit in player_units.get_children():
			if unit is Unit:
				player_alive = true
				break
	
	if enemy_units:
		for unit in enemy_units.get_children():
			if unit is Unit:
				enemy_alive = true
				break
	
	if not player_alive:
		print("=== GAME OVER - DEFEAT ===")
		show_game_over(false)
	elif not enemy_alive:
		print("=== VICTORY ===")
		show_game_over(true)

func show_game_over(victory: bool):
	# Simple game over - you can make this fancier
	if victory:
		print("YOU WIN!")
	else:
		print("YOU LOSE!")
	
	# Disable input
	set_process_unhandled_input(false)
