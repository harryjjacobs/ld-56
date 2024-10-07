extends Node2D
class_name PheromonePainter

var pheromone_script = preload("res://pheromones/pheromone.gd")
var food_brush_icon = preload("res://food_brush.tres")
var tunnel_brush_icon = preload("res://tunnel_brush.tres")

@onready var paths = $"../Navigation/Paths"
@onready var chambers = $"../Navigation/Chambers"
@onready var job_queue = $"../JobQueue"


@export var min_point_distance = 15
@export var pheromone_colors: Dictionary = {
	Pheromone.PheromoneType.none: Color(0.5, 0.5, 0.5, 0.5),
	Pheromone.PheromoneType.tunnel: Color(0.5, 0.5, 0.5, 0.5),
	Pheromone.PheromoneType.food: Color(0.5, 0.5, 0.5, 0.5),
	Pheromone.PheromoneType.fight: Color(0.5, 0.5, 0.5, 0.5),
}

@onready var temp_line = $TemporaryLine
@onready var temp_splodge = $TemporarySplodge

var pheromone_type: Pheromone.PheromoneType
var line_drawing = false

func _ready() -> void:
	pheromone_type = Pheromone.PheromoneType.none

func _process(_delta: float) -> void:
	temp_line.self_modulate = pheromone_colors[pheromone_type]
	temp_splodge.self_modulate = pheromone_colors[pheromone_type]
	temp_splodge.visible = pheromone_type == Pheromone.PheromoneType.food
	if pheromone_type == Pheromone.PheromoneType.food:
		temp_splodge.global_position = get_global_mouse_position()

	if pheromone_type == Pheromone.PheromoneType.food:
		Input.set_custom_mouse_cursor(food_brush_icon, Input.CURSOR_ARROW, Vector2(0, 0))
	elif pheromone_type == Pheromone.PheromoneType.tunnel:
		Input.set_custom_mouse_cursor(tunnel_brush_icon, Input.CURSOR_ARROW, Vector2(0, 0))
	else:
		Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW, Vector2(0, 0))

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("draw"):
		if pheromone_type == Pheromone.PheromoneType.tunnel:
			if line_drawing:
				end_line_drawing()
			else:
				begin_line_drawing()
		elif pheromone_type == Pheromone.PheromoneType.food:
			add_food_splodge()
	elif event.is_action_released("draw"):
		if pheromone_type == Pheromone.PheromoneType.tunnel:
			if line_drawing:
				end_line_drawing()
	elif event.is_action_pressed("cancel_draw"):
		reset_line_drawing()
	if event is InputEventMouseMotion:
		if pheromone_type == Pheromone.PheromoneType.tunnel:
			if line_drawing:
				var pos = get_global_mouse_position()
				if should_undo_point(pos):
					temp_line.remove_point(temp_line.points.size() - 1)
				elif should_add_point(pos):
					temp_line.add_point(pos)

func should_add_point(point: Vector2) -> bool:
	if temp_line.points.size() == 0:
		return true
	if self.is_point_in_chamber(temp_line.points[-1]):
		if temp_line.get_point_count() == 1:
			if self.is_point_in_chamber(point):
				# only allow a single start point in a chamber
				temp_line.remove_point(0)
			return true
		return false
	if point.distance_to(temp_line.points[-1]) < min_point_distance:
		return false
	return true

func should_undo_point(pos: Vector2) -> bool:
	if temp_line.points.size() < 2:
		return false
	var min_distance = temp_line.points[-2].distance_to(temp_line.points[-1])
	if pos.distance_to(temp_line.points[-2]) < min_distance:
		return true
	return false

func add_food_splodge():
	var splodge = temp_splodge.duplicate()
	splodge.add_to_group("pheromones")
	splodge.set_script(pheromone_script)
	splodge.init(Pheromone.PheromoneType.food, 1.0, 0.03, func(p): p.queue_free())
	add_child(splodge)

func begin_line_drawing():
	line_drawing = true
	temp_line.clear_points()
	temp_line.self_modulate = pheromone_colors[pheromone_type]
	temp_line.add_point(get_global_mouse_position())

func end_line_drawing():
	if temp_line.points.size() < 2:
		reset_line_drawing()
		return
	var job = JobQueue.Job.new()
	job.type = Pheromone.PheromoneType.tunnel
	job.target = temp_line.duplicate()
	job.target.add_to_group("pheromones")
	job.target.set_script(pheromone_script)
	job.target.init(Pheromone.PheromoneType.tunnel, 1.0, 0.0, func(p): p.queue_free())
	add_child(job.target)
	job_queue.add_job(job)
	print("Added tunnel job")
	reset_line_drawing()

func reset_line_drawing():
	line_drawing = false
	temp_line.clear_points()

func is_point_in_chamber(point: Vector2) -> bool:
	for chamber in chambers.get_children():
		if chamber.is_point_inside(point):
			return true
	return false
