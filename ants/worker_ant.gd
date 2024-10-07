extends Sprite2D
class_name WorkerAnt

# how far away from a known path point the worker can start digging a tunnel
const MAX_DIGGING_JUMP_DISTANCE: float = 20.0

@export var speed = 100.0

@onready var animation = $AnimationPlayer
@onready var food_shape_cast = $FoodShapeCast2D

var _job_queue: JobQueue
var _paths: PathPlanner
var _chambers: Node2D

var _carrying = null
var _job = null
var _started_job = false

var move_to_target_queue = []
var move_along_path_target_id = null

func init(job_queue: JobQueue, paths: PathPlanner, chambers: Node2D) -> void:
	self._job_queue = job_queue
	self._paths = paths
	self._chambers = chambers

func _process(delta: float) -> void:
	if _job == null and _job_queue.has_jobs():
		_stop_moving()
		var job = _job_queue.peek_next_job()
		if job != null:
			# print("Worker %s found a job of type %s" % [get_instance_id(), job.type])
			_bid_for_job(job)
	else:
		_move(delta)
		_check_job()

func award_job(job: JobQueue.Job) -> void:
	_job = job
	_start_job()

func _bid_for_job(job: JobQueue.Job):
	# check if the job is still valid
	if job.target == null:
		return
	if job.type == Pheromone.PheromoneType.tunnel:
		var route_to_trail = _find_route_to_trail(job.target.points)
		if route_to_trail.is_empty():
			return
		elif route_to_trail.size() == 1:
			# print("Worker %s is inside the chamber" % get_instance_id())
			_job_queue.bid_for_job(job, self, 0.0)
		else:
			var route = _plan_path_route(route_to_trail[0], route_to_trail[1])
			if route.is_empty():
				return
			var distance = 0
			for i in range(route.size() - 1):
				distance += _paths.astar.get_point_position(route[i]).distance_to(_paths.astar.get_point_position(route[i + 1]))
			_job_queue.bid_for_job(job, self, distance)
	elif job.type == Pheromone.PheromoneType.food:
		var result = _find_route_to_point(job.target.global_position)
		if result.is_empty():
			return
		var route_to_point = result[0]
		var distance = result[1]
		if route_to_point.is_empty():
			return
		_job_queue.bid_for_job(job, self, distance)

func _start_job():
	if _job.type == Pheromone.PheromoneType.tunnel:
		_start_tunnel_job()
		_started_job = true
	elif _job.type == Pheromone.PheromoneType.food:
		_start_food_job()
		_started_job = true

func _abandon_job():
	if _job != null:
		_job_queue.add_job(_job)
		_job = null
		_started_job = false
		_stop_moving()

func _check_job():
	if _job == null:
		return

	if _job.type == Pheromone.PheromoneType.tunnel:
		_check_tunnel_job()
	elif _job.type == Pheromone.PheromoneType.food:
		_check_food_job()

func _start_tunnel_job():
	var route_to_trail = _find_route_to_trail(_job.target.points)
	var trail_start
	if route_to_trail.is_empty():
		# print("Worker %s could not find a route to the trail start" % get_instance_id())
		_abandon_job()
		return
	elif route_to_trail.size() == 1:
		# the trail start is inside the current chamber
		# _move directly to the trail start and then start digging
		move_to_target_queue = [route_to_trail[0]]
		trail_start = route_to_trail[0]
	else:
		# we have a start and end id for path planning along known _paths
		# to get to the trail start
		var start_id = route_to_trail[0]
		var end_id = route_to_trail[1]
		trail_start = _paths.astar.get_point_position(end_id)
		var id_path = _plan_path_route(start_id, end_id)
		if id_path.is_empty():
			# print("Worker %s could not find a path to the trail start" % get_instance_id())
			_abandon_job()
			return
		else:
			move_to_target_queue = [_paths.astar.get_point_position(start_id)]
			move_along_path_target_id = end_id

	# add the trail points to the _move queue so the worker can dig the tunnel
	# once it reaches the trail start.
	# start with the trail point closest to the trail start and add all the
	# other points in a sensible order so that they're all covered by the worker

	# find the trail point closest to the trail start
	var closest_point = 0
	var shortest_distance = INF
	for i in range(_job.target.points.size()):
		var distance = _job.target.points[i].distance_to(trail_start)
		if distance < shortest_distance:
			closest_point = i
			shortest_distance = distance
	
	# add the closest point to the _move queue
	move_to_target_queue.append(_job.target.points[closest_point])

	# _move from closest point to the furthest trail end
	if closest_point == _job.target.points.size() - 1:
		for i in range(_job.target.points.size() - 2, 0, -1):
			move_to_target_queue.append(_job.target.points[i])
		# the trail end is the start point, so we're done
		return
	else:
		for i in range(closest_point, _job.target.points.size()):
			move_to_target_queue.append(_job.target.points[i])
		if closest_point == 0:
			# the trail start is the start point, so we're done
			return

	# _move from trail end to trail start
	for i in range(_job.target.points.size() - 1, 0, -1):
		move_to_target_queue.append(_job.target.points[i])

	# _move from trail start to closest point
	for i in range(0, closest_point):
		move_to_target_queue.append(_job.target.points[i])

func _check_tunnel_job():
	if _job == null:
		return

	if not _started_job:
		return

	if _job.type == Pheromone.PheromoneType.tunnel:
		if move_to_target_queue.is_empty():
			_finish_tunnel_job()

func _finish_tunnel_job():
	# the worker has dug the tunnel.
	# figure out where to connect the tunnel to the path planner
	# print("Worker %s has finished digging the tunnel" % get_instance_id())

	_job.target.default_color = Color(0.1255, 0.0745, 0.0627)
	_job.target.width = 20

	_paths.add_path(_job.target)

	_stop_moving()
	_job = null
	_started_job = false

func _start_food_job():
	if _job.target == null:
		_abandon_job()
		return
	var result = _find_route_to_point(_job.target.global_position)
	var route_to_point = result[0]
	if route_to_point.is_empty():
		# print("Worker %s could not find a route to the food" % get_instance_id())
		_abandon_job()
		return

	var start_position = _paths.astar.get_point_position(route_to_point[0])

	# move directly to the start point of the path
	move_to_target_queue.append(start_position)
	move_along_path_target_id = route_to_point[-1]

func _check_food_job():
	if _job == null:
		return

	if not _started_job:
		return

	if _job.type == Pheromone.PheromoneType.food:
		if not is_instance_valid(_job.target):
			_abandon_job()
			return
		if move_along_path_target_id == null:
			if _carrying == null:
				# are we at the food? is there food here?
				# check collision with the food item
				if food_shape_cast.is_colliding():
					var food = food_shape_cast.get_collider(0).get_parent()
					food.take() # take a bit of food
					# create small food item to carry
					var food_item = Sprite2D.new()
					food_item.texture = _job.target.texture
					food_item.scale = Vector2(0.15, 0.15)
					add_child(food_item)
					food_item.position = Vector2(0, 0)
					_carrying = food_item
					var result = _find_route_to_chamber(_job.issuer)
					if result.is_empty():
						# print("Worker %s could not find a route to the chamber" % get_instance_id())
						_abandon_job()
						return
					var route_to_chamber = result[0]
					if route_to_chamber.is_empty():
						# print("Worker %s could not find a route to the chamber" % get_instance_id())
						_abandon_job()
						return
					move_along_path_target_id = route_to_chamber[-1]
					move_to_target_queue = [_paths.astar.get_point_position(route_to_chamber[0])]
					# print("Worker %s has picked up the food" % get_instance_id())
				else:
					# print("Worker %s did not find food at the target position" % get_instance_id())
					_abandon_job()
					return
			else:
				# are we at the chamber? drop the food
				if is_inside_chamber(_job.issuer):
					_job.issuer.deliver_food()
					_throw_item_to_chamber(_job.issuer, _carrying)
					_job = null
					_started_job = false
					_stop_moving()
					_carrying = null
					# print("Worker %s has delivered the food" % get_instance_id())

func _throw_item_to_chamber(chamber: Chamber, item: Node2D) -> void:
	# tween the item to the chamber
	var tween = get_tree().create_tween()
	tween.parallel().tween_property(item, "global_position", chamber.global_position, 0.2).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(item, "scale", Vector2.ZERO, 0.2)
	tween.tween_callback(item.queue_free)

func _plan_path_route(start_id: int, end_id: int) -> PackedInt64Array:
	var id_path = _paths.astar.get_id_path(start_id, end_id)
	return id_path

func _move(delta: float) -> void:
	if move_to_target_queue.size() > 0:
		if animation.current_animation != "walk":
			animation.play("walk")
		var direction = move_to_target_queue.front() - global_position
		# print("Worker %s direction %s" % [get_instance_id(), direction])
		if direction.length() < speed * delta:
			global_position = move_to_target_queue.front()
			global_rotation = lerp_angle(global_rotation, direction.angle() + PI, 7.0 * delta)
			move_to_target_queue.pop_front()
			if move_along_path_target_id != null:
				if not is_on_path():
					print("Worker %s is not on a path" % get_instance_id())
					move_along_path_target_id = null
					return
				if _paths.astar.get_point_position(move_along_path_target_id).distance_to(global_position) < MAX_DIGGING_JUMP_DISTANCE:
					print("Worker %s has moved to target path point" % get_instance_id())
					move_along_path_target_id = null
					return
				print("Planning next path point")
				var path = _paths.astar.get_point_path(_paths.astar.get_closest_point(global_position), move_along_path_target_id)
				if path.size() < 2:
					print("Worker %s could not find a path to the target position" % get_instance_id())
					move_along_path_target_id = null
					move_to_target_queue.clear()
					_abandon_job()
					return
				# skip the first point in the path because it's the current position
				# and skip points that are too close to the current position
				var next_point = path[1]
				for i in range(1, path.size()):
					if path[i].distance_to(global_position) > MAX_DIGGING_JUMP_DISTANCE:
						next_point = path[i]
						break
				# print("Worker %s moving to next path point" % get_instance_id())
				move_to_target_queue.push_front(next_point)
		else:
			direction = direction.normalized()
			global_position += direction * speed * delta
			global_rotation = lerp_angle(global_rotation, direction.angle() + PI, 7.0 * delta)
	else:
		_stop_moving()

func _stop_moving():
	move_to_target_queue.clear()
	move_along_path_target_id = null
	if animation.current_animation != "idle":
		animation.play("idle")

func is_inside_chamber(chamber: Node2D) -> bool:
	return chamber.is_point_inside(global_position, MAX_DIGGING_JUMP_DISTANCE)

func get_current_chamber() -> Chamber:
	for chamber in _paths.chambers.get_children():
		if is_inside_chamber(chamber):
			return chamber
	return null

func is_on_path() -> bool:
	var segment_position = _paths.astar.get_closest_position_in_segment(global_position)
	return segment_position.distance_to(global_position) < MAX_DIGGING_JUMP_DISTANCE

func _closest_path_id() -> int:
	return _paths.astar.get_closest_point(global_position)

func _find_route_to_trail(trail: Array[Vector2]):
	# possible point IDs in the path planner to route the worker to
	var closest_ids = []

	# check if the trail end or start is inside a chamber
	for chamber in _paths.chambers.get_children():
		if chamber.is_point_inside(trail[0], MAX_DIGGING_JUMP_DISTANCE):
			if self.is_inside_chamber(chamber):
				return [trail[0]]
			var ids = _paths.get_ids_in_chamber(chamber)
			closest_ids += ids
		if chamber.is_point_inside(trail[-1], MAX_DIGGING_JUMP_DISTANCE):
			if self.is_inside_chamber(chamber):
				return [trail[-1]]
			var ids = _paths.get_ids_in_chamber(chamber)
			closest_ids += ids

	# check if any path points are close to the trail
	for path in _paths.paths:
		for i in range(path.line.points.size()):
			for j in range(trail.size()):
				if path.line.points[i].distance_to(trail[j]) < MAX_DIGGING_JUMP_DISTANCE:
					# print("Worker %s found a path point close to the trail" % get_instance_id())
					closest_ids.append(path.ids[i])

	var start_id = -1
	if is_on_path():
		# the worker is already on a path, so we can route it to the closest pointf
		start_id = _closest_path_id()
	else:
		var chamber = get_current_chamber()
		if chamber != null:
			# the worker is inside a chamber, so we can route it to the closest point
			var ids = _paths.get_ids_in_chamber(chamber)
			if ids.size() > 0:
				start_id = ids[0]
			else:
				print("Worker %s is inside a chamber but there are no path points in the chamber" % get_instance_id())
		else:
			push_error("Worker is lost")

	if start_id == -1:
		return []

	# see if we can route the worker to any of the closest points to the trail
	var best_end_id = null
	var shortest_distance = 0
	for i in range(closest_ids.size()):
		var id_path = _paths.astar.get_id_path(start_id, closest_ids[i])
		if id_path.is_empty():
			continue
		var distance = 0
		for j in range(id_path.size() - 1):
			distance += _paths.astar.get_point_position(id_path[j]).distance_to(_paths.astar.get_point_position(id_path[j + 1]))
		if best_end_id == null or distance < shortest_distance:
			best_end_id = closest_ids[i]
			shortest_distance = distance

	if best_end_id == null:
		return []

	return [start_id, best_end_id]

func _find_route_to_point(point: Vector2):
	var end_id = _paths.astar.get_closest_point(point)
	if end_id == -1:
		return []
	if _paths.astar.get_point_position(end_id).distance_to(point) > MAX_DIGGING_JUMP_DISTANCE:
		return []

	var start_ids = []
	var chamber = get_current_chamber()
	if chamber != null:
		start_ids = _paths.get_ids_in_chamber(chamber)
		if start_ids.is_empty():
			# print("Worker %s is inside a chamber but there are no path points in the chamber" % get_instance_id())
			return []
	elif is_on_path():
		start_ids = [_closest_path_id()]
	else:
		push_error("Worker is lost")
		return []

	var best_start_id = null
	var best_path = []
	var distance = 0
	for i in range(start_ids.size()):
		var id_path = _plan_path_route(start_ids[i], end_id)
		if id_path.is_empty():
			continue
		var path_distance = 0
		for j in range(id_path.size() - 1):
			path_distance += _paths.astar.get_point_position(id_path[j]).distance_to(_paths.astar.get_point_position(id_path[j + 1]))
		if best_start_id == null or path_distance < distance:
			best_start_id = start_ids[i]
			best_path = id_path
			distance = path_distance

	return [best_path, distance]

func _find_route_to_chamber(chamber: Chamber):
	var end_ids = _paths.get_ids_in_chamber(chamber)
	if end_ids.is_empty():
		return []
	
	var start_ids = []
	var current_chamber = get_current_chamber()
	if current_chamber != null:
		start_ids = _paths.get_ids_in_chamber(current_chamber)
		if start_ids.is_empty():
			# print("Worker %s is inside a chamber but there are no path points in the chamber" % get_instance_id())
			return []
	elif is_on_path():
		start_ids = [_closest_path_id()]
	else:
		push_error("Worker is lost")
		return []

	var best_path = []
	var distance = INF
	for i in range(start_ids.size()):
		for j in range(end_ids.size()):
			var id_path = _plan_path_route(start_ids[i], end_ids[j])
			if id_path.is_empty():
				continue
			var path_distance = 0
			for k in range(id_path.size() - 1):
				path_distance += _paths.astar.get_point_position(id_path[k]).distance_to(_paths.astar.get_point_position(id_path[k + 1]))
			if path_distance < distance:
				best_path = id_path
				distance = path_distance

	return [best_path, distance]
