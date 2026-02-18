extends Button

signal ingredient_pressed(id: String)

const DRAG_PREFIX := "ingredient:"
const DRAG_THRESHOLD := 6

@onready var icon_texture: TextureRect = $Row/Icon
@onready var name_label: Label = $Row/TextVBox/NameLabel
@onready var count_label: Label = $Row/TextVBox/CountLabel
@onready var tags_label: Label = $Row/RightVBox/TagsLabel
@onready var satisfaction_label: Label = $Row/RightVBox/SatisfactionLabel

var ingredient_id: String = ""
var _drag_pending := false
var _drag_start_pos := Vector2.ZERO

func setup(id: String, display_name: String, icon_path: String, count: int, tags: Array = [], satisfaction: int = 0) -> void:
	ingredient_id = id
	name_label.text = display_name
	count_label.text = "x%d" % count
	icon_texture.texture = load(icon_path)
	tags_label.text = ", ".join(tags) if tags.size() > 0 else "—"
	satisfaction_label.text = str(satisfaction)
	satisfaction_label.add_theme_color_override("font_color", Color.GREEN)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_drag_pending = true
				_drag_start_pos = mb.position
			else:
				_drag_pending = false
	if event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event
		if _drag_pending and (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			if mm.position.distance_to(_drag_start_pos) >= DRAG_THRESHOLD:
				_drag_pending = false
				call_deferred("_do_force_drag")
				accept_event()

func _do_force_drag() -> void:
	if ingredient_id.is_empty() or GameState.inventory.get(ingredient_id, 0) <= 0:
		return
	var data: String = DRAG_PREFIX + ingredient_id
	var preview := duplicate()
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	force_drag(data, preview)
	
func set_highlight(active: bool) -> void:
	if active:
		modulate = Color(1.0, 1.0, 0.4)  # yellow tint
	else:
		modulate = Color.WHITE
