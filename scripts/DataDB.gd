extends Node

# 8 basic ingredients: tag and satisfaction per spec; icons from assets
var ingredients := {
	"pepper": {"name": "Pepper", "icon": "res://assets/ingredients/Green/green (50).png", "satisfaction": 2, "tags": ["spicy", "vegetable"]},
	"garlic": {"name": "Garlic", "icon": "res://assets/ingredients/Green/green (9).png", "satisfaction": 1, "tags": ["stinky", "vegetable"]},
	"egg": {"name": "Egg", "icon": "res://assets/ingredients/Protein/Protein (108).png", "satisfaction": 3, "tags": ["protein"]},
	"meat": {"name": "Meat", "icon": "res://assets/ingredients/Protein/Protein (19).png", "satisfaction": 4, "tags": ["protein", "heavy"]},
	"squid": {"name": "Squid", "icon": "res://assets/ingredients/Protein/Protein (2).png", "satisfaction": 3, "tags": ["seafood", "protein"]},
	"nuts_oil": {"name": "Nuts Oil", "icon": "res://assets/ingredients/Condiment/Condiment (68).png", "satisfaction": 2, "tags": ["nuts"]},
	"magic_flower": {"name": "Magic Flower", "icon": "res://assets/ingredients/Condiment/Condiment (47).png", "satisfaction": 2, "tags": ["cute"]},
	"magic_mushroom": {"name": "Magic Mushroom", "icon": "res://assets/ingredients/Green/green (88).png", "satisfaction": 2, "tags": ["dizzy"]},
	# Combined results (correct images per spec)
	"garlic_oil": {"name": "Garlic Oil", "icon": "res://assets/ingredients/Condiment/Condiment (115).png", "satisfaction": 5, "tags": ["stinky"]},
	"fire_squid": {"name": "Fire Squid", "icon": "res://assets/ingredients/Protein/Protein (8).png", "satisfaction": 8, "tags": ["spicy", "spicy", "spicy", "seafood"]},
	"magical_egg": {"name": "Magical Egg", "icon": "res://assets/ingredients/Protein/Protein (105).png", "satisfaction": 10, "tags": ["magic", "protein"]},
	"sus_meat": {"name": "Sus Meat", "icon": "res://assets/ingredients/Protein/Protein (23).png", "satisfaction": 6, "tags": ["protein", "dizzy"]},
	"darkmatter": {"name": "Darkmatter", "icon": "res://assets/ingredients/Carb/carb (41).png", "satisfaction": 15, "tags": ["dark magic"]},
	"trash": {"name": "Trash", "icon": "res://assets/ingredients/Condiment/Condiment (126).png", "satisfaction": 1, "tags": []},
	"egg_plus5": {"name": "Egg (+5)", "icon": "res://assets/ingredients/Protein/Protein (108).png", "satisfaction": 8, "tags": ["protein"]},
	"meat_plus5": {"name": "Meat (+5)", "icon": "res://assets/ingredients/Protein/Protein (19).png", "satisfaction": 9, "tags": ["protein", "heavy"]},
	"squid_plus5": {"name": "Squid (+5)", "icon": "res://assets/ingredients/Protein/Protein (2).png", "satisfaction": 8, "tags": ["seafood", "protein"]},
}

# Enemy display: "image" (single texture) OR "frames" (animation).
# Frames: array of strings (path → 1.0s) or dicts {"path": "res://...", "duration": 0.1}.
# Optional: "fps" (overrides duration when frames are strings), "frame_duration" (default s per frame), "animation_speed" (playback multiplier).
# Stage 1: nut allergy, max 3 ingredients. Stage 2: needs spicy × 3. Stage 3: only protein, high satisfaction. Stage 4: dark magic allergy, max 5 pot combinations this round.
# Use "sprite_frames": "res://resources/enemies/xxx_sprite_frames.tres" to edit animations in the AnimatedSprite2D GUI (SpriteFrames editor). Else "image" or "frames" in code.
var enemies := [
	{"id": "flying_eye", "name": "Flying Eye", "sprite_frames": "res://resources/enemies/flying_eye_sprite_frames.tres", "scale": 6.0, "allergy_tags": ["nuts"], "allergy_known": true, "requirements": {"min_satisfaction": 1, "max_ingredients": 3}},
	{"id": "blob_minion", "name": "Blob Minion", "sprite_frames": "res://resources/enemies/blob_minion_sprite_frames.tres", "scale": 10.0, "allergy_tags": [], "allergy_known": true, "requirements": {"min_satisfaction": 0, "min_tag_count": {"spicy": 3}}},
	{"id": "knight", "name": "Knight", "sprite_frames": "res://resources/enemies/knight_sprite_frames.tres", "scale": 10.0, "allergy_tags": [], "allergy_known": true, "requirements": {"min_satisfaction": 12, "only_protein": true}},
	{"id": "summoner", "name": "The Summoner", "sprite_frames": "res://resources/enemies/summoner_sprite_frames.tres", "scale": 10.0, "allergy_tags": ["dark magic"], "allergy_known": true, "requirements": {"min_satisfaction": 1}, "max_pot_combinations": 5},
]

# Returns combined result for pot contents: { id?, name, satisfaction, tags } (id for 2-item so result goes to inventory)
func get_pot_combination(pot_ids: Array) -> Dictionary:
	var arr: Array = pot_ids.duplicate()
	arr.sort()
	# 4 base items: egg+magic_flower + meat+magic_mushroom -> darkmatter (for dish stats only; normally we merge 2→magical_egg+sus_meat then 2→darkmatter)
	if arr.size() == 4:
		var set4 := _to_set(arr)
		if set4.has("egg") and set4.has("magic_flower") and set4.has("meat") and set4.has("magic_mushroom"):
			return {"id": "darkmatter", "name": "Darkmatter", "satisfaction": 15, "tags": ["dark magic"]}
	# 3 items: garlic + nuts_oil + protein -> same protein +5 (for dish stats)
	if arr.size() == 3:
		var set3 := _to_set(arr)
		if set3.has("garlic") and set3.has("nuts_oil"):
			if set3.has("egg"):
				return {"id": "egg_plus5", "name": "Egg (+5)", "satisfaction": 8, "tags": ["protein"]}
			if set3.has("meat"):
				return {"id": "meat_plus5", "name": "Meat (+5)", "satisfaction": 9, "tags": ["protein", "heavy"]}
			if set3.has("squid"):
				return {"id": "squid_plus5", "name": "Squid (+5)", "satisfaction": 8, "tags": ["seafood", "protein"]}
	# 2 items
	if arr.size() == 2:
		var a: String = arr[0]
		var b: String = arr[1]
		# garlic + nuts_oil -> garlic oil (Condiment 115)
		if (a == "garlic" and b == "nuts_oil") or (a == "nuts_oil" and b == "garlic"):
			return {"id": "garlic_oil", "name": "Garlic Oil", "satisfaction": 5, "tags": ["stinky"]}
		# pepper + squid -> fire squid (Protein 8; spicy x3, seafood)
		if (a == "pepper" and b == "squid") or (a == "squid" and b == "pepper"):
			return {"id": "fire_squid", "name": "Fire Squid", "satisfaction": 8, "tags": ["spicy", "spicy", "spicy", "seafood"]}
		# egg + magic_flower -> magical egg (Protein 105)
		if (a == "egg" and b == "magic_flower") or (a == "magic_flower" and b == "egg"):
			return {"id": "magical_egg", "name": "Magical Egg", "satisfaction": 10, "tags": ["magic", "protein"]}
		# meat + magic_mushroom -> sus meat (Protein 23)
		if (a == "meat" and b == "magic_mushroom") or (a == "magic_mushroom" and b == "meat"):
			return {"id": "sus_meat", "name": "Sus Meat", "satisfaction": 6, "tags": ["protein", "dizzy"]}
		# magical egg + sus meat -> darkmatter (carb 41)
		if (a == "magical_egg" and b == "sus_meat") or (a == "sus_meat" and b == "magical_egg"):
			return {"id": "darkmatter", "name": "Darkmatter", "satisfaction": 15, "tags": ["dark magic"]}
		# garlic oil + protein -> same protein +5
		if (a == "garlic_oil" and b == "egg") or (a == "egg" and b == "garlic_oil"):
			return {"id": "egg_plus5", "name": "Egg (+5)", "satisfaction": 8, "tags": ["protein"]}
		if (a == "garlic_oil" and b == "meat") or (a == "meat" and b == "garlic_oil"):
			return {"id": "meat_plus5", "name": "Meat (+5)", "satisfaction": 9, "tags": ["protein", "heavy"]}
		if (a == "garlic_oil" and b == "squid") or (a == "squid" and b == "garlic_oil"):
			return {"id": "squid_plus5", "name": "Squid (+5)", "satisfaction": 8, "tags": ["seafood", "protein"]}
		# no valid combination -> trash (Condiment 126)
		return {"id": "trash", "name": "Trash", "satisfaction": 1, "tags": []}
	# 0 or 1 item
	return {"id": "trash", "name": "Trash", "satisfaction": 1, "tags": []}

func _to_set(arr: Array) -> Dictionary:
	var d := {}
	for x in arr:
		d[x] = true
	return d
