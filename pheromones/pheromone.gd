extends Node2D
class_name Pheromone

enum PheromoneType {none, tunnel, food, fight}

var _decay_rate = 0.01
var _intensity = 1.0
var _decay_callback = null
var _initial_alpha = 0.5

var type: PheromoneType = PheromoneType.none

func init(_type: PheromoneType, intensity: float, decay_rate: float, decay_callback: Callable) -> void:
	self.type = _type
	_intensity = intensity
	_decay_rate = decay_rate
	_decay_callback = decay_callback
	_initial_alpha = self_modulate.a

func _process(_delta: float) -> void:
	_intensity = max(0, _intensity - _decay_rate * _delta)
	self_modulate.a = _initial_alpha * _intensity
	if _intensity == 0:
		_decay_callback.call(self)
