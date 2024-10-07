extends StaticBody2D
class_name Chamber

var worker_ant_scene = preload("res://ants/worker_ant.tscn")

const HUNGER_RATE = 0.02
const HUNGER_HEALTH_DECAY_THRESHOLD = 0.1
const HEALTH_DECAY_RATE = 0.04
const HEALTH_REGEN_RATE = 0.1
const WORKER_SPAWN_RATE = 0.001
# how much hunger is required to issue a food job
const FOOD_JOB_ISSUE_THRESHOLD = 0.1
const FOOD_JOB_COOLDOWN = 0.2

@onready var radius = $CollisionShape2D.shape.radius
@onready var health_label = $HealthLabel
@onready var hunger_label = $HungerLabel

var _job_queue: JobQueue
var _paths: PathPlanner
var _chambers: Node2D

var _hunger = 0.0
var _health = 1.0
var _food_job_cooldown = 0.0

func init(job_queue: JobQueue, paths: PathPlanner, chambers: Node2D) -> void:
	self._job_queue = job_queue
	self._paths = paths
	self._chambers = chambers
	spawn_worker_ant()

func is_point_inside(point: Vector2, tolerance = 0.0) -> bool:
	return point.distance_to(global_position) < (radius + tolerance)

func _random_inside_unit_circle() -> Vector2:
	var theta: float = randf() * 2 * PI
	return Vector2(cos(theta), sin(theta)) * sqrt(randf())

func spawn_worker_ant() -> Node2D:
	var worker_ant = worker_ant_scene.instantiate()
	worker_ant.init(_job_queue, _paths, _chambers)
	worker_ant.global_position = global_position + _random_inside_unit_circle() * radius * 0.8
	worker_ant.global_rotation = randf() * 2 * PI
	get_node("/root").add_child.call_deferred(worker_ant)
	return worker_ant

func find_food():
	# search for food pheromones
	var pheromones = get_tree().get_nodes_in_group("pheromones")
	var food_pheromones = []
	for pheromone in pheromones:
		if pheromone.type == Pheromone.PheromoneType.food:
			food_pheromones.append(pheromone)
	
	if food_pheromones.size() == 0:
		return null

	# find the closest food pheromone
	var closest_pheromone = food_pheromones[0]
	var closest_distance = global_position.distance_to(closest_pheromone.global_position)
	for pheromone in food_pheromones:
		var distance = global_position.distance_to(pheromone.global_position)
		if distance < closest_distance:
			closest_pheromone = pheromone
			closest_distance = distance
	
	return closest_pheromone

func add_food_job():
	var food = find_food()
	if food:
		var job = JobQueue.Job.new()
		job.type = Pheromone.PheromoneType.food
		job.target = food
		job.issuer = self
		_job_queue.add_job(job)
		_food_job_cooldown = FOOD_JOB_COOLDOWN
		print("Issued food job")

func deliver_food():
	_hunger = max(0, _hunger - 0.1)

func _process(_delta: float) -> void:
	if _hunger == 0:
		_health = min(1.0, _health + HEALTH_REGEN_RATE * _delta)
	elif _hunger > HUNGER_HEALTH_DECAY_THRESHOLD:
		_health = max(0, _health - HEALTH_DECAY_RATE * _hunger * _delta)

	_hunger = min(1, _hunger + HUNGER_RATE * _delta)

	if _health == 0:
		# dead
		push_error("Chamber is out of food!")
	
	if randf() < WORKER_SPAWN_RATE:
		spawn_worker_ant()

	if _hunger > FOOD_JOB_ISSUE_THRESHOLD and _food_job_cooldown <= 0:
		add_food_job()

	if _food_job_cooldown > 0:
		_food_job_cooldown -= _delta

	health_label.text = "Health: " + str(ceil(100 * _health)) + "/100"

	if _hunger > 0.0:
		hunger_label.text = "Hunger: " + str(floor(10 * (_hunger))) + "/10"
	else:
		hunger_label.text = "Hunger: 0/10"
