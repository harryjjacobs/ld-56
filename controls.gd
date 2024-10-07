extends VBoxContainer

@onready var pheromone_painter = $"../../PheromonePainter"
@onready var pheromone_type_dropdown = $MenuButton

func _ready() -> void:
	pheromone_painter.pheromone_type = pheromone_type_dropdown.selected

func _on_pheromone_type_dropdown_item_selected(index: int) -> void:
	pheromone_painter.pheromone_type = index
