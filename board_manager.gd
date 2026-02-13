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
		var tile_pos = grid.local_to_map(grid.to_local(get_global_mouse_position()))
		
		if selected_unit == null:
			selected_unit = get_unit_at_tile(tile_pos)
		else:
			if not is_moving:
				if is_valid_move_target(tile_pos):
					is_moving = true
					move_unit_to(selected_unit, tile_pos)
					selected_unit = null

func get_unit_at_tile(tile_pos: Vector2i) -> Node2D:
	for unit in player_units.get_children():
		if grid.local_to_map(unit.global_position) == tile_pos:
			return unit
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
		return
	
	var current_path = unit_paths[unit]
	var target_pos = grid.map_to_local(current_path[0])
	target_pos.y += UNIT_Y_OFFSET
	
	var tween = create_tween()
	tween.tween_property(unit, "global_position", target_pos, 0.3)
	tween.tween_callback(func():
		current_path.pop_front()
		if current_path.is_empty():
			unit_paths.erase(unit)
		else:
			move_unit_along_path(unit)
	)
