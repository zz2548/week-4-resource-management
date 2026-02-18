extends Node

var stage_index: int = 0

const INITIAL_INVENTORY := {
	"pepper": 2,
	"garlic": 2,
	"egg": 2,
	"meat": 2,
	"squid": 2,
	"nuts_oil": 2,
	"magic_flower": 2,
	"magic_mushroom": 2,
}

# inventory counts (shared across stages; limited for multi-stage planning)
var inventory: Dictionary = {}

# ingredients dropped on Selected panel (direct to dish)
var dish_selected: Array[String] = []
# ingredients dropped in Pot (combined into one virtual ingredient)
var pot_contents: Array[String] = []
var dish_stats := {"satisfaction": 0, "tag_count": 0}

# last evaluation result (cleared when adding an ingredient)
var last_result: String = ""

# number of pot merges done this stage (for stages with max_pot_combinations)
var pot_merges_this_stage: int = 0

func _ready() -> void:
	reset_for_restart()

func reset_for_restart() -> void:
	stage_index = 0
	pot_merges_this_stage = 0
	inventory = INITIAL_INVENTORY.duplicate()
	dish_selected.clear()
	pot_contents.clear()
	dish_stats = {"satisfaction": 0, "tag_count": 0}
	last_result = ""
