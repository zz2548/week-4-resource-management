@tool
extends PanelContainer

## Keeps BottomBar height in sync with Custom Minimum Size Y.
## Without this, anchor offset_top fixes the height and changing custom_minimum_size has no effect.

var _last_min_h: float = -1.0

func _ready() -> void:
	_apply_height()

func _process(_delta: float) -> void:
	var h: float = custom_minimum_size.y
	if h != _last_min_h:
		_last_min_h = h
		_apply_height()

func _apply_height() -> void:
	var h: float = custom_minimum_size.y
	if h > 0 and anchor_top == 1.0 and anchor_bottom == 1.0:
		offset_top = -h
