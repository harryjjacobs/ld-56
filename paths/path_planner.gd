extends Node2D
class_name PathPlanner

# how far away a point can be from a path point to be considered connectable
const MAX_PATH_CONNECTION_DISTANCE = 20

class Path:
	var line = null
	var ids = []

var astar = AStar2D.new()

@onready var chambers = $"../Chambers"
@onready var astar_viz = $Visualiser

var id = 0
var paths = []

func add_path(line: Line2D) -> void:
	line.get_parent().remove_child(line)
	add_child(line)
	var path = Path.new()
	path.line = line
	for i in range(path.line.points.size()):
		astar.add_point(id, path.line.points[i])
		if i > 0:
			astar.connect_points(id - 1, id)
		path.ids.append(id)
		id += 1
	paths.append(path)
	self._form_connections(path)

	astar_viz.visualise(astar)

func _form_connections(new_path: Path) -> void:
	# try to detect intersections with chambers and other paths
	# and join them at the intersection

	# connect path to other paths in the same chamber
	for chamber in chambers.get_children():
		if chamber.is_point_inside(new_path.line.points[0], MAX_PATH_CONNECTION_DISTANCE):
			var other_ids_in_chamber = get_ids_in_chamber(chamber)
			for other_id in other_ids_in_chamber:
				if other_id != new_path.ids[0]:
					astar.connect_points(other_id, new_path.ids[0])
		if chamber.is_point_inside(new_path.line.points[-1], MAX_PATH_CONNECTION_DISTANCE):
			var other_ids_in_chamber = get_ids_in_chamber(chamber)
			for other_id in other_ids_in_chamber:
				if other_id != new_path.ids[-1]:
					astar.connect_points(other_id, new_path.ids[-1])

	# connect path with itself if it intersects itself
	for i in range(new_path.line.points.size() - 1):
		for j in range(new_path.line.points.size() - 1):
			if abs(i - j) < 2:
				continue
			var segment_intersection = Geometry2D.segment_intersects_segment(new_path.line.points[i], new_path.line.points[i + 1], new_path.line.points[j], new_path.line.points[j + 1])
			if segment_intersection:
				# insert a new point at the intersection for both paths
				var new_point = segment_intersection
				new_path.line.add_point(new_point, i + 1)
				new_path.ids.insert(i + 1, id)
				i += 1
				astar.add_point(id, new_point)
				astar.connect_points(new_path.ids[i], id)
				astar.connect_points(new_path.ids[i + 1], id)
				astar.connect_points(new_path.ids[j], id)
				astar.connect_points(new_path.ids[j + 1], id)
				id += 1

	# connect paths at intersections
	for path in paths:
		for i in range(path.line.points.size() - 1):
			for j in range(new_path.line.points.size() - 1):
				if path == new_path:
					continue
				var segment_intersection = Geometry2D.segment_intersects_segment(path.line.points[i], path.line.points[i + 1], new_path.line.points[j], new_path.line.points[j + 1])
				if segment_intersection:
					# insert a new point at the intersection for both paths
					var new_point = segment_intersection
					path.line.add_point(new_point, i + 1)
					new_path.line.add_point(new_point, j + 1)
					astar.add_point(id, new_point)
					# remove the old connections
					astar.disconnect_points(path.ids[i], path.ids[i + 1])
					astar.disconnect_points(new_path.ids[j], new_path.ids[j + 1])
					astar.connect_points(path.ids[i], id)
					astar.connect_points(path.ids[i + 1], id)
					astar.connect_points(new_path.ids[j], id)
					astar.connect_points(new_path.ids[j + 1], id)
					path.ids.insert(i + 1, id)
					new_path.ids.insert(j + 1, id)
					id += 1
	
	for path in paths:
		if path == new_path:
			continue
		for i in range(path.line.points.size() - 1):
			for j in [0, -1]:
				# print("Checking path %s point %s against path %s point %s" % [new_path, new_path.line.points[j], path, path.line.points[i]])
				var circle_intersection = Geometry2D.segment_intersects_circle(path.line.points[i], path.line.points[i + 1], new_path.line.points[j], MAX_PATH_CONNECTION_DISTANCE)
				if circle_intersection != -1:
					# insert a new point at the intersection in the existing path
					var new_point = path.line.points[i].lerp(path.line.points[i + 1], circle_intersection)
					path.line.add_point(new_point, i + 1)
					path.ids.insert(i + 1, new_path.ids[j])
					# remove the old connection
					astar.disconnect_points(path.ids[i], path.ids[i + 1])
					# add a new connection
					astar.connect_points(path.ids[i], new_path.ids[j])
					astar.connect_points(new_path.ids[j], path.ids[i + 1])

					# print("Connected end of path %s to path %s at point %s" % [new_path, path, new_point])

func get_ids_in_chamber(chamber: Chamber) -> Array[int]:
	var ids: Array[int] = []
	for path in paths:
		for i in range(path.line.points.size()):
			if chamber.is_point_inside(path.line.points[i], MAX_PATH_CONNECTION_DISTANCE):
				ids.append(path.ids[i])
	return ids
