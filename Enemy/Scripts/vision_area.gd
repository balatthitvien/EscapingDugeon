class_name VisionArea
extends Area2D

signal player_entered
signal player_exited


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	var parent = get_parent()

	if parent is Enemy:
		parent.direction_changed.connect(_on_direction_changed)
		_on_direction_changed(parent.direction)


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		player_entered.emit()


func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		player_exited.emit()


func _on_direction_changed(new_direction: Vector2) -> void:
	match new_direction:
		Vector2.RIGHT:
			scale.x = 1
		Vector2.LEFT:
			scale.x = -1
		_:
			scale.x = 1
