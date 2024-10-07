extends Node2D

var food_remaining = 10

func take():
	food_remaining -= 1
	if food_remaining == 0:
		queue_free()
