extends Node2D

@onready var inventory_grid: GridContainer = $UI/BottomBar/Row/InventoryPanel/InventoryVBox/InventoryGrid
@onready var dish_satisfaction_label: Label = $UI/BottomBar/Row/DishPanel/DishVbox/DishStatsRow/SatisfactionLabel
@onready var dish_tag_count_label: Label = $UI/BottomBar/Row/DishPanel/DishVbox/DishStatsRow/TagCountLabel
@onready var selected_list: RichTextLabel = $UI/BottomBar/Row/DishPanel/DishVbox/SelectedDropZone/SelectedVbox/SelectedList
@onready var stage_label: Label = $UI/TopBar/EnemyVbox/StageLabel
@onready var enemy_name_label: Label = $UI/TopBar/EnemyVbox/EnemyNameLabel
@onready var enemy_hints_label: Label = $UI/TopBar/EnemyVbox/EnemyHintsLabel
@onready var pot_drop_zone: Control = $UI/BottomBar/Row/PotPanel/PotVBox/PotContainer/PotDropZone
@onready var selected_drop_target: Control = $UI/BottomBar/Row/DishPanel/DishVbox/SelectedDropZone/SelectedDropTarget
@onready var enemy_node: Node2D = $Enemy
@onready var result_overlay: Control = $ResultLayer/ResultOverlay
@onready var result_label: Label = $ResultLayer/ResultOverlay/CenterContainer/VBox/ResultLabel
# Buttons
@onready var end_btn: Button = $UI/BottomBar/Row/DishPanel/DishVbox/EndCookingButton
@onready var restart_btn: Button = $ResultLayer/ResultOverlay/CenterContainer/VBox/RestartButton
@onready var continue_btn: Button = $ResultLayer/ResultOverlay/CenterContainer/VBox/ContinueButton
@onready var undo_btn: Button = $UI/BottomBar/Row/DishPanel/DishVbox/UndoButton
# Sound effects
@onready var combine_sound: AudioStreamPlayer2D = $SFX/CombineSound
@onready var drop_off_sound: AudioStreamPlayer2D = $SFX/DropOffSound
@onready var win_sound: AudioStreamPlayer2D = $SFX/WinSound
@onready var lose_sound: AudioStreamPlayer2D = $SFX/LoseSound

const ING_CARD_SCENE := preload("res://scenes/IngredientCard.tscn")

var _last_pot_ingredients: Array = []

func _ready() -> void:
	_refresh_enemy_ui()
	_render_inventory()
	_refresh_dish_ui()
	end_btn.pressed.connect(_on_end_cooking_pressed)
	undo_btn.pressed.connect(_on_undo_pressed)
	if pot_drop_zone:
		pot_drop_zone.ingredient_dropped.connect(_on_ingredient_dropped_to_pot)
	if selected_drop_target:
		selected_drop_target.ingredient_dropped.connect(_on_ingredient_dropped_to_selected)
	restart_btn.pressed.connect(_on_restart_pressed)
	continue_btn.pressed.connect(_on_continue_pressed)
	_refresh_pot_highlights()

func _play_sfx(player: AudioStreamPlayer2D) -> void:
	var music_bus: int = AudioServer.get_bus_index("Music")
	# Fade music down
	var tween_down: Tween = create_tween()
	tween_down.tween_method(
		func(vol: float): AudioServer.set_bus_volume_db(music_bus, vol),
		0.0, -10.0, 0.3
	)
	await tween_down.finished
	player.play()
	await player.finished
	# Fade music back up
	var tween_up: Tween = create_tween()
	tween_up.tween_method(
		func(vol: float): AudioServer.set_bus_volume_db(music_bus, vol),
		-10.0, 0.0, 0.5
	)

func _render_inventory() -> void:
	# Clear old
	for c in inventory_grid.get_children():
		c.queue_free()
	# Create cards only for ingredients with count > 0
	for id in GameState.inventory.keys():
		var count: int = GameState.inventory[id]
		if count <= 0:
			continue
		var data = DataDb.ingredients[id]
		var card = ING_CARD_SCENE.instantiate()
		inventory_grid.add_child(card)
		var tags_arr: Array = data.get("tags", [])
		var sat: int = int(data.get("satisfaction", 0))
		card.setup(id, data["name"], data["icon"], count, tags_arr, sat)
	_refresh_pot_highlights()

func _on_ingredient_dropped_to_selected(id: String) -> void:
	if GameState.inventory.get(id, 0) <= 0:
		return
	GameState.last_result = ""
	GameState.inventory[id] -= 1
	GameState.dish_selected.append(id)
	_recompute_dish_stats()
	_render_inventory()
	_refresh_pot_highlights()
	_refresh_dish_ui()

func _on_ingredient_dropped_to_pot(id: String) -> void:
	if GameState.inventory.get(id, 0) <= 0:
		return
	if GameState.pot_contents.size() == 0:
		_play_sfx(drop_off_sound)
	# Stage 4: block merge if already at max pot combinations this round
	var idx: int = GameState.stage_index
	if idx < DataDb.enemies.size():
		var enemy: Dictionary = DataDb.enemies[idx]
		var max_merges: Variant = enemy.get("max_pot_combinations", -1)
		if max_merges >= 0 and GameState.pot_contents.size() == 1:
			if GameState.pot_merges_this_stage >= int(max_merges):
				return
	GameState.last_result = ""
	GameState.inventory[id] -= 1
	GameState.pot_contents.append(id)
	if GameState.pot_contents.size() == 2:
		_last_pot_ingredients = GameState.pot_contents.duplicate()
		GameState.pot_merges_this_stage += 1
		_play_sfx(combine_sound)
		var combo: Dictionary = DataDb.get_pot_combination(GameState.pot_contents)
		var result_id: String = combo.get("id", "trash")
		GameState.inventory[result_id] = GameState.inventory.get(result_id, 0) + 1
		GameState.pot_contents.clear()
	_recompute_dish_stats()
	_render_inventory()
	_refresh_dish_ui()

func _recompute_dish_stats() -> void:
	var satisfaction_sum: int = 0
	var tag_set: Dictionary = {}
	for id in GameState.dish_selected:
		var ing: Dictionary = DataDb.ingredients[id]
		satisfaction_sum += int(ing.get("satisfaction", 0))
		for t in ing["tags"]:
			tag_set[t] = true
	# Pot: combination result (one virtual ingredient)
	var pot_result: Dictionary = DataDb.get_pot_combination(GameState.pot_contents)
	satisfaction_sum += int(pot_result.get("satisfaction", 0))
	for t in pot_result.get("tags", []):
		tag_set[t] = true
	GameState.dish_stats["satisfaction"] = satisfaction_sum
	GameState.dish_stats["tag_count"] = tag_set.size()

func _refresh_enemy_ui() -> void:
	var total_stages: int = DataDb.enemies.size()
	var idx: int = GameState.stage_index
	if enemy_node:
		enemy_node.set_stage_index(idx)
	stage_label.text = "Stage %d / %d" % [idx + 1, total_stages]
	if idx >= total_stages:
		enemy_name_label.text = "—"
		enemy_hints_label.text = "All defeated!"
		return
	var enemy: Dictionary = DataDb.enemies[idx]
	enemy_name_label.text = enemy["name"]
	var hints: Array[String] = []
	var req: Dictionary = enemy.get("requirements", {})
	if req.has("min_satisfaction") and int(req["min_satisfaction"]) > 0:
		hints.append("satisfaction ≥ %s" % req["min_satisfaction"])
	if req.has("max_ingredients"):
		hints.append("max %d ingredients" % int(req["max_ingredients"]))
	if req.has("min_tag_count"):
		for tag_name in req["min_tag_count"].keys():
			hints.append("%s × %s" % [tag_name, req["min_tag_count"][tag_name]])
	if req.get("only_protein", false):
		hints.append("only protein")
	var max_pot: Variant = enemy.get("max_pot_combinations", null)
	if max_pot != null and int(max_pot) >= 0:
		hints.append("max %d pot merges" % int(max_pot))
	var known: bool = enemy.get("allergy_known", true)
	var allergy_hint: String = "?"
	if known and enemy.has("allergy_tags") and enemy["allergy_tags"].size() > 0:
		allergy_hint = ", ".join(enemy["allergy_tags"])
	else:
		allergy_hint = "none"
	enemy_hints_label.text = "Needs: %s  |  Allergy: %s" % [", ".join(hints) if hints.size() > 0 else "—", allergy_hint]

func _refresh_dish_ui() -> void:
	if GameState.last_result != "":
		dish_satisfaction_label.text = "Satisfaction: 0"
		dish_tag_count_label.text = " | Tag count: 0"
		selected_list.clear()
		selected_list.append_text(GameState.last_result)
		return
	var s: Dictionary = GameState.dish_stats
	dish_satisfaction_label.text = "Satisfaction: %d" % s["satisfaction"]
	dish_tag_count_label.text = " | Tag count: %d" % s["tag_count"]
	selected_list.clear()
	var lines: Array[String] = []
	# Selected panel contents
	var sel_counts := {}
	for id in GameState.dish_selected:
		sel_counts[id] = sel_counts.get(id, 0) + 1
	if sel_counts.is_empty():
		lines.append("Selected: (empty)")
	else:
		lines.append("Selected:")
		for id in sel_counts.keys():
			lines.append("  • %s x%d" % [DataDb.ingredients[id]["name"], sel_counts[id]])
	# Pot contents (combined)
	if GameState.pot_contents.is_empty():
		lines.append("Pot: (empty)")
	else:
		var pot_counts := {}
		for id in GameState.pot_contents:
			pot_counts[id] = pot_counts.get(id, 0) + 1
		lines.append("Pot (combined):")
		for id in pot_counts.keys():
			lines.append("  • %s x%d" % [DataDb.ingredients[id]["name"], pot_counts[id]])
		var combo: Dictionary = DataDb.get_pot_combination(GameState.pot_contents)
		lines.append("  → %s (sat %d)" % [combo["name"], combo["satisfaction"]])
	selected_list.append_text("\n".join(lines))

func _on_end_cooking_pressed() -> void:
	var total: int = DataDb.enemies.size()
	if GameState.stage_index >= total:
		GameState.last_result = "All enemies defeated. You win!"
		_refresh_dish_ui()
		_show_result_overlay(true)
		return
	var enemy: Dictionary = DataDb.enemies[GameState.stage_index]
	var result_text := _evaluate(enemy, GameState.dish_stats)
	GameState.last_result = result_text

	GameState.dish_selected.clear()
	GameState.pot_contents.clear()
	GameState.dish_stats = {"satisfaction": 0, "tag_count": 0}

	# Advance stage if defeated
	if result_text.begins_with("WIN"):
		GameState.stage_index = min(GameState.stage_index + 1, DataDb.enemies.size())
		GameState.pot_merges_this_stage = 0

	_refresh_enemy_ui()
	_render_inventory()
	_refresh_dish_ui()

	_show_result_overlay(result_text.begins_with("WIN"))

func _on_undo_pressed() -> void:
	# Undo ingredient sitting in pot (not yet combined)
	if not GameState.pot_contents.is_empty():
		var last_id: String = GameState.pot_contents.back()
		GameState.pot_contents.remove_at(GameState.pot_contents.size() - 1)
		GameState.inventory[last_id] = GameState.inventory.get(last_id, 0) + 1
	# Undo a completed pot combination
	elif not _last_pot_ingredients.is_empty():
		var combo: Dictionary = DataDb.get_pot_combination(_last_pot_ingredients)
		var result_id: String = combo.get("id", "trash")
		GameState.inventory[result_id] = max(0, GameState.inventory.get(result_id, 0) - 1)
		for id in _last_pot_ingredients:
			GameState.inventory[id] = GameState.inventory.get(id, 0) + 1
		GameState.pot_merges_this_stage = max(0, GameState.pot_merges_this_stage - 1)
		_last_pot_ingredients.clear()
	# Undo last dish selection
	elif not GameState.dish_selected.is_empty():
		var last_id: String = GameState.dish_selected.back()
		GameState.dish_selected.remove_at(GameState.dish_selected.size() - 1)
		GameState.inventory[last_id] = GameState.inventory.get(last_id, 0) + 1
	_recompute_dish_stats()
	_render_inventory()
	_refresh_dish_ui()

func _evaluate(enemy: Dictionary, stats: Dictionary) -> String:
	# Dish = selected + one pot result (if any)
	var pot_result: Dictionary = DataDb.get_pot_combination(GameState.pot_contents)
	var pot_result_id: String = pot_result.get("id", "")
	var dish_ids: Array = []
	for id in GameState.dish_selected:
		dish_ids.append(id)
	if GameState.pot_contents.size() > 0:
		dish_ids.append(pot_result_id if not pot_result_id.is_empty() else "trash")

	# Tag counts (for min_tag_count and allergy)
	var tag_counts: Dictionary = {}
	for id in dish_ids:
		if not DataDb.ingredients.has(id):
			continue
		for t in DataDb.ingredients[id]["tags"]:
			tag_counts[t] = tag_counts.get(t, 0) + 1

	# Allergy: for stages with an allergy, player must drop an ingredient with that tag to pass
	var allergy_tags: Array = enemy.get("allergy_tags", [])
	if allergy_tags.size() > 0:
		var has_allergy_tag := false
		for a in allergy_tags:
			if tag_counts.get(a, 0) > 0:
				has_allergy_tag = true
				break
		if not has_allergy_tag:
			return "LOSE: You must use an ingredient with %s to pass." % [", ".join(allergy_tags)]

	var req: Dictionary = enemy.get("requirements", {})

	# max_ingredients: total dish slots <= max
	var max_ing: Variant = req.get("max_ingredients", null)
	if max_ing != null and dish_ids.size() > int(max_ing):
		return "LOSE: Too many ingredients for %s (max %d)." % [enemy["name"], int(max_ing)]

	# min_tag_count: e.g. spicy >= 3
	var min_tag: Dictionary = req.get("min_tag_count", {})
	for tag_name in min_tag.keys():
		var need: int = int(min_tag[tag_name])
		if tag_counts.get(tag_name, 0) < need:
			return "LOSE: %s needs %s × %d." % [enemy["name"], tag_name, need]

	# only_protein: every ingredient must have "protein" tag
	if req.get("only_protein", false):
		for id in dish_ids:
			if not DataDb.ingredients.has(id):
				continue
			var ing_tags: Array = DataDb.ingredients[id].get("tags", [])
			if not "protein" in ing_tags:
				return "LOSE: %s accepts only protein." % enemy["name"]

	# Satisfaction
	var min_sat: int = int(req.get("min_satisfaction", 0))
	if stats["satisfaction"] < min_sat:
		return "LOSE: Satisfaction too low for %s (need %d)." % [enemy["name"], min_sat]
	# Win: if this stage had an allergy and dish included it, use allergy message
	if allergy_tags.size() > 0:
		for a in allergy_tags:
			if tag_counts.get(a, 0) > 0:
				return "WIN: Allergy triggered (%s) — %s defeated." % [a, enemy["name"]]
	return "WIN: %s satisfied — defeated." % enemy["name"]

func _show_result_overlay(is_win: bool) -> void:
	result_label.text = "WIN" if is_win else "LOSE"
	if is_win:
		result_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
		restart_btn.visible = false
		continue_btn.visible = true
		_play_sfx(win_sound)
	else:
		result_label.add_theme_color_override("font_color", Color(0.95, 0.3, 0.3))
		restart_btn.visible = true
		continue_btn.visible = false
		_play_sfx(lose_sound)
	result_overlay.visible = true

func _on_restart_pressed() -> void:
	GameState.reset_for_restart()
	result_overlay.visible = false
	_refresh_enemy_ui()
	_render_inventory()
	_refresh_dish_ui()

func _on_continue_pressed() -> void:
	result_overlay.visible = false
	_refresh_dish_ui()

func _refresh_pot_highlights() -> void:
	for card in inventory_grid.get_children():
		if not card is Button:
			continue
		if GameState.pot_contents.size() == 1:
			var test_combo := [GameState.pot_contents[0], card.ingredient_id]
			var result: Dictionary = DataDb.get_pot_combination(test_combo)
			card.set_highlight(result.get("id", "trash") != "trash")
		else:
			card.set_highlight(false)
