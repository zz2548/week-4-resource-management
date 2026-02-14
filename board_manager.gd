extends Node2D

@onready var grid: TileMapLayer = $Grid
@onready var player_units: Node = $Units/PlayerGroup

var selected_unit: Node2D = null
var unit_move_speed: float = 300.0
var astar = AStarGrid2D.new()
var is_moving: bool = false
var unit_paths: Dictionary = {}

const UNIT_Y_OFFSET = -16

func _ready():
	astar.region = Rect2i(0, 0, 5, 5)
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.update()

func _unhandled_input(event: InputEvent):
	if event.is_action_pressed("left_click"):
		print("=== UNHANDLED INPUT FIRED ===")
		print("LClick")
		var tile_pos = grid.local_to_map(grid.to_local(get_global_mouse_position()))
		print("Tile pos: ", tile_pos)
		print("Player units node: ", player_units)
		print("Player units children count: ", player_units.get_child_count())
		
		if selected_unit == null:
			print("Trying to select unit...")
			selected_unit = get_unit_at_tile(tile_pos)
			if selected_unit:
				print("✓ SELECTED: ", selected_unit.name)
			else:
				print("✗ NO UNIT FOUND at tile ", tile_pos)
		else:
			print("Unit already selected: ", selected_unit.name)
			if not is_moving:
				if is_valid_move_target(tile_pos):
					is_moving = true
					move_unit_to(selected_unit, tile_pos)
					selected_unit = null

func get_unit_at_tile(tile_pos: Vector2i) -> Node2D:
	print("  Searching for unit at tile: ", tile_pos)
	for unit in player_units.get_children():
		var unit_tile = grid.local_to_map(unit.global_position)
		print("    - ", unit.name, " is at tile ", unit_tile, " (global pos: ", unit.global_position, ")")
		if unit_tile == tile_pos:
			print("    -> MATCH!")
			return unit
	print("  No match found")
	return null
	

func is_valid_move_target(tile_pos: Vector2i) -> bool:
	return get_unit_at_tile(tile_pos) == null and grid.get_cell_tile_data(tile_pos) != null

func move_unit_to(unit: Node2D, target_tile: Vector2i):
	var start_tile = grid.local_to_map(unit.global_position)
	
	var path = astar.get_id_path(start_tile, target_tile).slice(1)
	
	if path.is_empty():
		return
	
	unit_paths[unit] = path
	move_unit_along_path(unit)
	is_moving = false
	
func move_unit_along_path(unit: Node2D):
	if not unit_paths.has(unit) or unit_paths[unit].is_empty():
		print("[MOVEMENT] Path complete for ", unit.name)
		# Stop animation
		if unit.has_method("set_idle"):
			print("  Calling set_idle() on ", unit.name)
			unit.set_idle()
		else:
			print("  WARNING: ", unit.name, " doesn't have set_idle() method!")
		return
	
	var current_path = unit_paths[unit]
	var target_pos = grid.map_to_local(current_path[0])
	target_pos.y += UNIT_Y_OFFSET
	
	# Get direction
	var current_tile = grid.local_to_map(unit.global_position)
	var next_tile = current_path[0]
	var direction = get_movement_direction(current_tile, next_tile)
	
	print("[MOVEMENT] Moving ", unit.name, " from ", current_tile, " to ", next_tile, " (direction: ", direction, ")")
	
	# Play animation
	if unit.has_method("set_moving"):
		print("  Calling set_moving('", direction, "') on ", unit.name)
		unit.set_moving(direction)
	else:
		print("  WARNING: ", unit.name, " doesn't have set_moving() method!")
		print("  Available methods: ", unit.get_method_list().map(func(m): return m.name))
	
	var tween = create_tween()
	tween.tween_property(unit, "global_position", target_pos, 0.3)
	tween.tween_callback(func():
		current_path.pop_front()
		if current_path.is_empty():
			unit_paths.erase(unit)
			if unit.has_method("set_idle"):
				unit.set_idle()
		else:
			move_unit_along_path(unit)
	)

func get_movement_direction(from: Vector2i, to: Vector2i) -> String:
	var delta = to - from
	
	# Check for diagonal movement first
	if delta.x != 0 and delta.y != 0:
		# Diagonal movement
		var horizontal = "right" if delta.x > 0 else "left"
		var vertical = "down" if delta.y > 0 else "up"
		return horizontal + "_and_" + vertical
	
	# Cardinal directions
	if delta.y > 0:
		return "down"
	elif delta.y < 0:
		return "up"
	elif delta.x > 0:
		return "right"
	elif delta.x < 0:
		return "left"
	
	return "down"  # Default
