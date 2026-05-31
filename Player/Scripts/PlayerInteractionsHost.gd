class_name PlayerInteractionsHost
extends Node2D

@onready var player: Player = $".."


func _ready() -> void:
	player.DirectionChanged.connect(UpdateDirection)
	UpdateDirection(player.direction_vector)


func UpdateDirection(new_direction: Vector2) -> void:
	rotation_degrees = 0

	match new_direction:
		Vector2.RIGHT:
			scale.x = 1
		Vector2.LEFT:
			scale.x = -1
		_:
			scale.x = 1
