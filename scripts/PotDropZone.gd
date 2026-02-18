extends Control

signal ingredient_dropped(ingredient_id: String)

const DRAG_PREFIX := "ingredient:"

func _can_drop_data(_position: Vector2, data: Variant) -> bool:
	if data is not String:
		return false
	var s: String = data
	if not s.begins_with(DRAG_PREFIX):
		return false
	var id := s.substr(DRAG_PREFIX.length())
	return DataDb.ingredients.has(id) and GameState.inventory.get(id, 0) > 0

func _drop_data(_position: Vector2, data: Variant) -> void:
	if data is not String:
		return
	var s: String = data
	if not s.begins_with(DRAG_PREFIX):
		return
	var id := s.substr(DRAG_PREFIX.length())
	if DataDb.ingredients.has(id) and GameState.inventory.get(id, 0) > 0:
		ingredient_dropped.emit(id)
