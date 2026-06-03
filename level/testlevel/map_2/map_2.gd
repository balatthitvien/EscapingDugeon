extends Node2D

@onready var you_died_ui: CanvasLayer = get_node_or_null("YouDiedUI") as CanvasLayer

@export var coop_spawn_offset_x: float = 18.0
@export var enemy_target_detect_distance: float = 420.0

var player: Player = null
var has_connected_player_died: bool = false
var has_handled_player_death: bool = false


func _ready() -> void:
	MusicManager.stop_boss_music()
	MusicManager.play_map_1_music()

	await setup_player_death_handler()
	await apply_player_spawn_point()


func apply_player_spawn_point() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

	var spawn_name: String = LevelManager.get_next_spawn_point()

	if spawn_name == "":
		return

	var spawn_point := find_spawn_point(spawn_name)

	if spawn_point == null:
		push_warning("Không tìm thấy spawn point: " + spawn_name)
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

			if int(p.get("player_id")) == 1:
				offset_x = -coop_spawn_offset_x
			else:
				offset_x = coop_spawn_offset_x

			p.global_position = spawn_point.global_position + Vector2(offset_x, 0.0)
			p.velocity = Vector2.ZERO

			if p.has_method("set_control_enabled"):
				p.set_control_enabled(true)
	else:
		if PlayerManager.player != null:
			PlayerManager.player.global_position = spawn_point.global_position
			PlayerManager.player.velocity = Vector2.ZERO

	LevelManager.clear_next_spawn_point()


func find_spawn_point(spawn_name: String) -> Node2D:
	var spawn_point := get_node_or_null("SpawnPoints/" + spawn_name) as Node2D

	if spawn_point != null:
		return spawn_point

	spawn_point = get_node_or_null("SpawnPoints2/" + spawn_name) as Node2D

	if spawn_point != null:
		return spawn_point

	var found_node := find_node_by_name_recursive(self, spawn_name)

	if found_node is Node2D:
		return found_node as Node2D

	return null


func find_node_by_name_recursive(parent: Node, target_name: String) -> Node:
	if parent.name == target_name:
		return parent

	for child in parent.get_children():
		var found := find_node_by_name_recursive(child, target_name)

		if found != null:
			return found

	return null


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

		for p in players:
			if p == null:
				continue

			if !is_instance_valid(p):
				continue

			if p.has_signal("died"):
				if not p.died.is_connected(_on_player_died):
					p.died.connect(_on_player_died)

		has_connected_player_died = true
		return

	player = get_node_or_null("Player") as Player

	if player == null:
		player = PlayerManager.player

	if player == null:
		push_warning(name + ": Không tìm thấy Player để bắt signal died.")
		return

	if not player.died.is_connected(_on_player_died):
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


func is_two_player_mode() -> bool:
	var game_mode := get_node_or_null("/root/GameMode")

	if game_mode == null:
		return false

	return game_mode.is_two_players()


func get_players() -> Array:
	var result: Array = []
	var nodes := get_tree().get_nodes_in_group("players")

	for n in nodes:
		if n == null:
			continue

		if !is_instance_valid(n):
			continue

		if n is Player:
			result.append(n as Player)

	if result.is_empty():
		if PlayerManager.player != null and PlayerManager.player is Player:
			result.append(PlayerManager.player)

	return result


func is_any_player_targeted_by_enemy() -> bool:
	var players := get_players()

	if players.is_empty():
		return false

	var enemies := get_enemy_nodes()

	for enemy in enemies:
		if enemy == null:
			continue

		if !is_instance_valid(enemy):
			continue

		for p in players:
			if p == null:
				continue

			if !is_instance_valid(p):
				continue

			if is_enemy_targeting_player(enemy, p):
				return true

	return false


func get_enemy_nodes() -> Array:
	var result: Array = []
	var added_ids: Dictionary = {}

	var enemy_groups: Array[String] = [
		"enemies",
		"enemy",
		"monsters",
		"monster"
	]

	for group_name in enemy_groups:
		var nodes := get_tree().get_nodes_in_group(group_name)

		for n in nodes:
			if n == null:
				continue

			if !is_instance_valid(n):
				continue

			var id := n.get_instance_id()

			if added_ids.has(id):
				continue

			added_ids[id] = true
			result.append(n)

	return result


func is_enemy_targeting_player(enemy: Node, target_player: Player) -> bool:
	if enemy == null or target_player == null:
		return false

	# Cách chắc nhất: enemy có biến target/player/current_target trỏ thẳng vào Player.
	var target_property_names: Array[String] = [
		"player",
		"target",
		"target_player",
		"current_target",
		"chase_target",
		"attack_target"
	]

	for prop_name in target_property_names:
		if has_object_property(enemy, prop_name):
			var value = enemy.get(prop_name)

			if value == target_player:
				return true

	# Cách dự phòng: enemy đang ở state chase/attack và đứng gần player.
	var enemy_state_text: String = ""

	if has_object_property(enemy, "state"):
		enemy_state_text = str(enemy.get("state")).to_lower()

	if enemy_state_text == "" and has_object_property(enemy, "current_state"):
		enemy_state_text = str(enemy.get("current_state")).to_lower()

	if enemy_state_text.contains("chase") or enemy_state_text.contains("attack") or enemy_state_text.contains("dive"):
		if enemy is Node2D:
			var distance_to_player: float = (enemy as Node2D).global_position.distance_to(target_player.global_position)

			if distance_to_player <= enemy_target_detect_distance:
				return true

	# Cách dự phòng nữa: một số enemy dùng bool is_chasing / is_attacking / player_detected.
	var bool_property_names: Array[String] = [
		"is_chasing",
		"is_attacking",
		"player_detected",
		"can_see_player"
	]

	for bool_prop in bool_property_names:
		if has_object_property(enemy, bool_prop):
			if bool(enemy.get(bool_prop)):
				if enemy is Node2D:
					var distance: float = (enemy as Node2D).global_position.distance_to(target_player.global_position)

					if distance <= enemy_target_detect_distance:
						return true

	return false


func show_cannot_open_chest_message() -> void:
	var text := "Không thể mở rương khi đang bị quái nhắm tới."

	if get_node_or_null("/root/CoopRules") != null:
		CoopRules.show_team_required_message(text)
		return

	print(text)


func has_object_property(obj: Object, prop_name: String) -> bool:
	if obj == null:
		return false

	for prop in obj.get_property_list():
		if String(prop.get("name", "")) == prop_name:
			return true

	return false
