class_name VisionArea
extends Area2D

signal player_entered(player: Player)
signal player_exited(player: Player)


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)

	var parent = get_parent()

	if parent is Enemy:
		parent.direction_changed.connect(_on_direction_changed)
		_on_direction_changed(parent.direction)


func _on_body_entered(body: Node2D) -> void:
	var detected_player := find_player_from_node(body)

	if detected_player == null:
		return

	player_entered.emit(detected_player)


func _on_body_exited(body: Node2D) -> void:
	var detected_player := find_player_from_node(body)

	if detected_player == null:
		return

	player_exited.emit(detected_player)


func _on_area_entered(area: Area2D) -> void:
	var detected_player := find_player_from_node(area)

	if detected_player == null and area.get_parent() != null:
		detected_player = find_player_from_node(area.get_parent())

	if detected_player == null:
		return

	player_entered.emit(detected_player)


func _on_area_exited(area: Area2D) -> void:
	var detected_player := find_player_from_node(area)

	if detected_player == null and area.get_parent() != null:
		detected_player = find_player_from_node(area.get_parent())

	if detected_player == null:
		return

	player_exited.emit(detected_player)


func find_player_from_node(node: Node) -> Player:
	var current := node

	while current != null:
		if current is Player:
			return current as Player

		if current.is_in_group("players"):
			return current as Player

		if current.is_in_group("player"):
			return current as Player

		if current.is_in_group("Player"):
			return current as Player

		if current.name == "Player":
			return current as Player

		if current.name == "Player2":
			return current as Player

		current = current.get_parent()

	if node != null and node.owner != null:
		var owner_node := node.owner

		if owner_node is Player:
			return owner_node as Player

		if owner_node.is_in_group("players"):
			return owner_node as Player

		if owner_node.is_in_group("player"):
			return owner_node as Player

		if owner_node.is_in_group("Player"):
			return owner_node as Player

		if owner_node.name == "Player":
			return owner_node as Player

		if owner_node.name == "Player2":
			return owner_node as Player

	return null


func _on_direction_changed(new_direction: Vector2) -> void:
	match new_direction:
		Vector2.RIGHT:
			scale.x = 1
		Vector2.LEFT:
			scale.x = -1
		_:
			scale.x = 1
