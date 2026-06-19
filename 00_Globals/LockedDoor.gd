extends Area2D

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var talk_indicator: Sprite2D = $TalkIndicator

@export var required_flag: String = "map_2_skeleton_killed"
@export var locked_message: String = "Bạn chưa thể đến khu vực này"

@export_file("*.tscn") var target_scene_path: String
@export var target_spawn_point_name: String = ""

@export var fade_out_time: float = 0.7
@export var fade_in_time: float = 0.7
@export var message_font_size: int = 16

@export var coop_need_teammate_message: String = "Cần cả 2 người đứng gần cửa.\nĐừng bỏ lại đồng đội của mình."
@export var coop_required_player_distance: float = 140.0

var player_in_range: bool = false
var player: Player = null
var players_near: Dictionary = {}

var is_changing_scene: bool = false

var message_layer: CanvasLayer
var message_label: Label
var message_tween: Tween = null


func _ready() -> void:
	monitoring = true
	monitorable = true

	if collision_shape != null:
		collision_shape.disabled = false

	if talk_indicator != null:
		talk_indicator.visible = false
		talk_indicator.z_index = 100
		talk_indicator.z_as_relative = false

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)

	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

	if not area_exited.is_connected(_on_area_exited):
		area_exited.connect(_on_area_exited)

	create_message_ui()


func _unhandled_input(event: InputEvent) -> void:
	if not player_in_range:
		return

	if is_changing_scene:
		return

	var action_player := get_player_pressed_interact_event(event)

	if action_player == null:
		return

	player = action_player
	get_viewport().set_input_as_handled()

	await try_use_door(action_player)


func try_use_door(action_player: Player = null) -> void:
	if required_flag != "" and not LevelManager.get_game_flag(required_flag):
		show_bottom_message(locked_message)
		return

	if is_two_player_mode():
		if not can_use_door_as_team(action_player):
			show_bottom_message(coop_need_teammate_message)
			return

	if target_scene_path == "":
		show_bottom_message("Cửa đã mở, nhưng chưa gán map đích.")
		return

	is_changing_scene = true

	if target_spawn_point_name != "":
		LevelManager.set_next_spawn_point(target_spawn_point_name)

	await SceneTransition.change_scene_with_fade(
		target_scene_path,
		fade_out_time,
		fade_in_time
	)


func can_use_door_as_team(action_player: Player = null) -> bool:
	var player_1 := get_near_player_by_id(1)
	var player_2 := get_near_player_by_id(2)

	if player_1 == null:
		return false

	if player_2 == null:
		return false

	if !is_instance_valid(player_1):
		return false

	if !is_instance_valid(player_2):
		return false

	var distance_between_players: float = player_1.global_position.distance_to(player_2.global_position)

	if distance_between_players > coop_required_player_distance:
		return false

	if action_player != null:
		if action_player != player_1 and action_player != player_2:
			return false

	return true


func get_near_player_by_id(target_id: int) -> Player:
	for key in players_near.keys():
		var p := players_near[key] as Player

		if p == null:
			continue

		if !is_instance_valid(p):
			continue

		if int(p.get("player_id")) == target_id:
			return p

	return null


func _on_body_entered(body: Node2D) -> void:
	try_set_player_in_range(body)


func _on_body_exited(body: Node2D) -> void:
	try_remove_player_from_range(body)


func _on_area_entered(area: Area2D) -> void:
	try_set_player_in_range(area)

	if area.get_parent() != null:
		try_set_player_in_range(area.get_parent())


func _on_area_exited(area: Area2D) -> void:
	try_remove_player_from_range(area)

	if area.get_parent() != null:
		try_remove_player_from_range(area.get_parent())


func try_set_player_in_range(target: Node) -> void:
	var detected_player: Player = find_player_from_node(target)

	if detected_player == null:
		return

	players_near[detected_player.get_instance_id()] = detected_player
	player_in_range = !players_near.is_empty()
	player = detected_player

	if talk_indicator != null:
		talk_indicator.visible = true

	print("Player đã vào vùng cửa: ", detected_player.name)


func try_remove_player_from_range(target: Node) -> void:
	var detected_player: Player = find_player_from_node(target)

	if detected_player == null:
		return

	var id := detected_player.get_instance_id()

	if players_near.has(id):
		players_near.erase(id)

	player_in_range = !players_near.is_empty()

	if player == detected_player:
		player = get_any_near_player()

	if !player_in_range and talk_indicator != null:
		talk_indicator.visible = false

	print("Player đã rời vùng cửa: ", detected_player.name)


func get_any_near_player() -> Player:
	for key in players_near.keys():
		var p := players_near[key] as Player

		if p != null and is_instance_valid(p):
			return p

	return null


func get_player_pressed_interact_event(event: InputEvent) -> Player:
	for key in players_near.keys():
		var p := players_near[key] as Player

		if p == null:
			continue

		if !is_instance_valid(p):
			continue

		if p.has_method("is_interact_event_pressed"):
			if p.is_interact_event_pressed(event):
				return p
		else:
			var action_name := get_interact_action_for_player(p)

			if event.is_action_pressed(action_name):
				return p

	return null


func get_interact_action_for_player(target_player: Player) -> StringName:
	if !is_two_player_mode():
		return &"interact"

	var id_value: int = int(target_player.get("player_id"))

	if id_value == 1:
		return &"p1_interact"

	return &"p2_interact"


func is_two_player_mode() -> bool:
	var game_mode := get_node_or_null("/root/GameMode")

	if game_mode == null:
		return false

	return game_mode.is_two_players()


func create_message_ui() -> void:
	message_layer = CanvasLayer.new()
	message_layer.layer = 1000
	add_child(message_layer)

	message_label = Label.new()
	message_layer.add_child(message_label)

	message_label.visible = false
	message_label.text = ""
	message_label.modulate.a = 0.0

	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	message_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	message_label.offset_left = -360
	message_label.offset_right = 360
	message_label.offset_top = -120
	message_label.offset_bottom = -55

	message_label.add_theme_font_size_override("font_size", message_font_size)


func show_bottom_message(text: String) -> void:
	if message_label == null:
		return

	if message_tween != null:
		message_tween.kill()

	message_label.text = text
	message_label.visible = true
	message_label.modulate.a = 0.0

	message_tween = create_tween()
	message_tween.tween_property(message_label, "modulate:a", 1.0, 0.2)
	message_tween.tween_interval(1.8)
	message_tween.tween_property(message_label, "modulate:a", 0.0, 0.3)

	await message_tween.finished

	if message_label != null:
		message_label.visible = false


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
