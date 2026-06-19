extends Node2D

@onready var you_died_ui: CanvasLayer = get_node_or_null("YouDiedUI") as CanvasLayer

@export var coop_spawn_offset_x: float = 18.0

var player: Player = null
var has_connected_player_died: bool = false
var has_handled_player_death: bool = false


func _ready() -> void:
	MusicManager.play_game_bgm(1.5)
	await setup_player_death_handler()
	await apply_player_spawn_point()


func apply_player_spawn_point() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

	var spawn_name: String = LevelManager.get_next_spawn_point()

	if spawn_name == "":
		return

	var spawn_point := get_node_or_null("SpawnPoints/" + spawn_name) as Node2D

	if spawn_point == null:
		push_warning("map_4: Không tìm thấy spawn point: " + spawn_name)
		LevelManager.clear_next_spawn_point()
		return

	if is_two_player_mode():
		var players := get_players()

		for p in players:
			if p == null:
				continue

			if !is_instance_valid(p):
				continue

			var offset_x: float = 0.0
			var player_id_value: int = int(p.get("player_id"))

			if player_id_value == 1:
				offset_x = -coop_spawn_offset_x
			else:
				offset_x = coop_spawn_offset_x

			p.global_position = spawn_point.global_position + Vector2(offset_x, 0.0)
			p.velocity = Vector2.ZERO

			if p.has_method("set_control_enabled"):
				p.set_control_enabled(true)

			if p.has_method("reset_physics_interpolation"):
				p.reset_physics_interpolation()

			print("map_4: Đã đưa ", p.name, " tới spawn point: ", spawn_name, " tại ", p.global_position)
	else:
		if PlayerManager.player != null:
			PlayerManager.player.global_position = spawn_point.global_position
			PlayerManager.player.velocity = Vector2.ZERO

			if PlayerManager.player.has_method("set_control_enabled"):
				PlayerManager.player.set_control_enabled(true)

			if PlayerManager.player.has_method("reset_physics_interpolation"):
				PlayerManager.player.reset_physics_interpolation()

			print("map_4: Đã đưa Player tới spawn point: ", spawn_name, " tại ", spawn_point.global_position)

	LevelManager.clear_next_spawn_point()


func setup_player_death_handler() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

	if you_died_ui == null:
		you_died_ui = get_node_or_null("YouDiedUI") as CanvasLayer

	if you_died_ui == null:
		push_warning(name + ": Không tìm thấy YouDiedUI trong scene.")
		return

	if has_connected_player_died:
		return

	if is_two_player_mode():
		var players := get_players()

		if players.is_empty():
			push_warning(name + ": Không tìm thấy Player nào để bắt signal died.")
			return

		for p in players:
			if p == null:
				continue

			if !is_instance_valid(p):
				continue

			if !p.died.is_connected(_on_player_died):
				p.died.connect(_on_player_died)

		has_connected_player_died = true
		return

	player = get_node_or_null("Player") as Player

	if player == null:
		player = PlayerManager.player

	if player == null:
		push_warning(name + ": Không tìm thấy Player để bắt signal died.")
		return

	if !player.died.is_connected(_on_player_died):
		player.died.connect(_on_player_died)

	has_connected_player_died = true


func _on_player_died() -> void:
	if has_handled_player_death:
		return

	has_handled_player_death = true

	print(name + ": PLAYER DIED SIGNAL RECEIVED")

	lock_all_players_for_game_over()

	await get_tree().create_timer(1.0).timeout

	if you_died_ui != null and you_died_ui.has_method("show_you_died"):
		you_died_ui.show_you_died()


func lock_all_players_for_game_over() -> void:
	var players := get_players()

	for p in players:
		if p == null:
			continue

		if !is_instance_valid(p):
			continue

		if p.has_method("set_control_enabled"):
			p.set_control_enabled(false)

		if has_object_property(p, "can_control"):
			p.set("can_control", false)

		if has_object_property(p, "velocity"):
			var current_velocity: Vector2 = p.get("velocity")
			current_velocity.x = 0.0
			p.set("velocity", current_velocity)

		if p.has_method("stop_hurt_box"):
			p.stop_hurt_box()


func get_players() -> Array:
	var result: Array = []
	var added_ids: Dictionary = {}

	var groups_to_check: Array[String] = [
		"players",
		"player",
		"Player"
	]

	for group_name in groups_to_check:
		for node in get_tree().get_nodes_in_group(group_name):
			var detected_player := find_player_from_node(node)

			if detected_player == null:
				continue

			if !is_instance_valid(detected_player):
				continue

			var id: int = detected_player.get_instance_id()

			if added_ids.has(id):
				continue

			added_ids[id] = true
			result.append(detected_player)

	var player_1_node := get_node_or_null("Player")
	var player_2_node := get_node_or_null("Player2")

	for node in [player_1_node, player_2_node]:
		var detected_player := find_player_from_node(node)

		if detected_player == null:
			continue

		if !is_instance_valid(detected_player):
			continue

		var id: int = detected_player.get_instance_id()

		if added_ids.has(id):
			continue

		added_ids[id] = true
		result.append(detected_player)

	if result.is_empty():
		if PlayerManager.player != null and PlayerManager.player is Player:
			result.append(PlayerManager.player)

	return result


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

	return null


func is_two_player_mode() -> bool:
	var game_mode := get_node_or_null("/root/GameMode")

	if game_mode == null:
		return false

	return game_mode.is_two_players()


func has_object_property(obj: Object, prop_name: String) -> bool:
	if obj == null:
		return false

	for prop in obj.get_property_list():
		if String(prop.get("name", "")) == prop_name:
			return true

	return false
