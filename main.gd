extends Node2D

const MAX_CHAMBERS = 10
const CHAMBER_SPAWN_RATE = 0.1
const CHAMBER_SPAWN_COOLDOWN_TIME = 10.0
const MAX_FOOD = 20
const FOOD_SPAWN_RATE = 0.3
const FOOD_SPAWN_COOLDOWN_TIME = 5.0

const VIEWPORT_MIN = -Vector2(640, 360)
const VIEWPORT_MAX = Vector2(640, 360)

var chamber_scene = preload("res://chambers/chamber.tscn")
var food_scene = preload("res://resources/food.tscn")

@onready var _chambers: Node2D = $Navigation/Chambers
@onready var _food: Node2D = $Navigation/Food
@onready var paths: PathPlanner = $Navigation/Paths
@onready var job_queue: JobQueue = $"JobQueue"

var _chamber_spawn_cooldown = CHAMBER_SPAWN_COOLDOWN_TIME
var _food_spawn_cooldown = FOOD_SPAWN_COOLDOWN_TIME

func _ready() -> void:
	_chambers.get_child(0).init(job_queue, paths, _chambers)

func _process(_delta: float) -> void:
	if _chambers.get_children().size() < MAX_CHAMBERS and randf() < CHAMBER_SPAWN_RATE and _chamber_spawn_cooldown == 0:
		print("Spawning chamber")
		var chamber = chamber_scene.instantiate()
		var pos = _find_free_space_for_chamber()
		print("Spawning chamber at %s" % pos)
		if pos == Vector2.ZERO:
			chamber.queue_free()
		else:
			_chambers.add_child(chamber)
			chamber.global_position = pos
			chamber.init(job_queue, paths, _chambers)
		_chamber_spawn_cooldown = CHAMBER_SPAWN_COOLDOWN_TIME

	if _food.get_children().size() < MAX_FOOD and randf() < FOOD_SPAWN_RATE and _food_spawn_cooldown == 0:
		var food = food_scene.instantiate()
		var pos = _find_free_space_for_food()
		print("Spawning food at %s" % pos)
		if pos == Vector2.ZERO:
			food.queue_free()
		else:
			_food.add_child(food)
			food.global_position = pos
		_food_spawn_cooldown = FOOD_SPAWN_COOLDOWN_TIME

	_chamber_spawn_cooldown = max(0, _chamber_spawn_cooldown - _delta)
	_food_spawn_cooldown = max(0, _food_spawn_cooldown - _delta)

func _find_free_space_for_chamber() -> Vector2:
	var pos = _get_random_point_in_viewport()
	var attempts = 0
	while not _is_free_space_for_chamber(pos) and attempts < 100:
		pos = _get_random_point_in_viewport()
		attempts += 1
	if attempts == 100:
		return Vector2.ZERO
	return pos

func _is_free_space_for_chamber(pos: Vector2) -> bool:
	var chambers = _chambers.get_children()
	for chamber in chambers:
		if chamber.global_position.distance_to(pos) < chamber.radius * 2:
			return false
	return true

func _find_free_space_for_food() -> Vector2:
	var pos = _get_random_point_in_viewport()
	var attempts = 0
	while not _is_free_space_for_food(pos) and attempts < 100:
		pos = _get_random_point_in_viewport()
		attempts += 1
	if attempts == 100:
		return Vector2.ZERO
	return pos

func _is_free_space_for_food(pos: Vector2) -> bool:
	var chambers = _chambers.get_children()
	for chamber in chambers:
		if chamber.global_position.distance_to(pos) < chamber.radius:
			return false
	return true

func _get_random_point_in_viewport() -> Vector2:
	return Vector2(randf_range(VIEWPORT_MIN.x, VIEWPORT_MAX.x), randf_range(VIEWPORT_MIN.y, VIEWPORT_MAX.y))
