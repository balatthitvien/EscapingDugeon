extends Area2D

@export_file("*.tscn") var target_scene_path: String
@export var target_spawn_point_name: String = ""

@export var fade_out_time: float = 0.7
@export var fade_in_time: float = 0.7

# Nếu để trống thì cửa luôn hoạt động.
# Nếu có flag thì chỉ hoạt động khi flag = true.
@export var required_flag: String = ""
@export var locked_message: String = "Cửa đang bị khóa."

# CO-OP
@export var coop_required_player_distance: float = 180.0
@export var coop_required_message: String = "Cả hai cần đứng gần cửa để tiếp tục.\nĐừng bỏ lại đồng đội của mình."

@export var message_font_size: int = 14
@export var message_interval: float = 1.2

var is_changing_scene: bool = false
var is_exit_enabled: bool = true
var players_in_exit: Dictionary = {}

var message_timer: float = 0.0
var message_layer: CanvasLayer = null
var message_label: Label = null
var message_tween: Tween = null


func _ready() -> void:
	monitoring = true
	monitorable = true

	add_to_group("map_exit_area")

	update_exit_enabled()
	create_message_ui()

	if !body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	if !body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)

	if !area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

	if !area_exited.is_connected(_on_area_exited):
		area_exited.connect(_on_area_exited)



func _process(delta: float) -> void:
	if message_timer > 0.0:
		message_timer -= delta

	if !is_exit_enabled:
		update_exit_enabled()


func update_exit_enabled() -> void:
	if required_flag == "":
		is_exit_enabled = true
	else:
		is_exit_enabled = LevelManager.get_game_flag(required_flag)


func _on_body_entered(body: Node2D) -> void:
	add_player_from_node(body)
	await try_use_exit()


func _on_body_exited(body: Node2D) -> void:
	remove_player_from_node(body)


func _on_area_entered(area: Area2D) -> void:
	add_player_from_node(area)

	if area.get_parent() != null:
		add_player_from_node(area.get_parent())

	await try_use_exit()


func _on_area_exited(area: Area2D) -> void:
	remove_player_from_node(area)

	if area.get_parent() != null:
		remove_player_from_node(area.get_parent())


func add_player_from_node(node: Node) -> void:
	var detected_player := find_player_from_node(node)

	if detected_player == null:
		return

	players_in_exit[detected_player.get_instance_id()] = detected_player


func remove_player_from_node(node: Node) -> void:
	var detected_player := find_player_from_node(node)

	if detected_player == null:
		return

	var id: int = detected_player.get_instance_id()

	if players_in_exit.has(id):
		players_in_exit.erase(id)


func try_use_exit() -> void:
	if is_changing_scene:
		return

	update_exit_enabled()

	if !is_exit_enabled:
		show_bottom_message(locked_message)
		return

	if target_scene_path == "":
		push_warning("MapExitArea chưa set Target Scene Path.")
		return

	if is_two_player_mode():
		if !can_use_exit_as_team():
			show_need_teammate_message()
			return

	await start_change_scene()


func can_use_exit_as_team() -> bool:
	if !is_two_player_mode():
		return true

	var player_1 := get_inside_player_by_id(1)
	var player_2 := get_inside_player_by_id(2)

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

	return true


func get_inside_player_by_id(target_id: int) -> Player:
	for key in players_in_exit.keys():
		var p := players_in_exit[key] as Player

		if p == null:
			continue

		if !is_instance_valid(p):
			continue

		if has_object_property(p, "player_id"):
			if int(p.get("player_id")) == target_id:
				return p

		if target_id == 1 and p.name == "Player":
			return p

		if target_id == 2 and p.name == "Player2":
			return p

	return null


func start_change_scene() -> void:
	if is_changing_scene:
		return

	is_changing_scene = true

	if target_spawn_point_name != "":
		LevelManager.set_next_spawn_point(target_spawn_point_name)

	set_all_players_control_enabled(false)

	await SceneTransition.change_scene_with_fade(
		target_scene_path,
		fade_out_time,
		fade_in_time
	)


func show_need_teammate_message() -> void:
	if message_timer > 0.0:
		return

	message_timer = message_interval
	show_bottom_message(coop_required_message)


func create_message_ui() -> void:
	message_layer = CanvasLayer.new()
	message_layer.layer = 2000
	add_child(message_layer)

	message_label = Label.new()
	message_layer.add_child(message_label)

	message_label.visible = false
	message_label.text = ""
	message_label.modulate.a = 0.0

	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	message_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	message_label.offset_left = -210
	message_label.offset_right = 210
	message_label.offset_top = -80
	message_label.offset_bottom = -25

	message_label.add_theme_font_size_override("font_size", message_font_size)
	message_label.add_theme_color_override("font_color", Color.WHITE)
	message_label.add_theme_color_override("font_outline_color", Color.BLACK)
	message_label.add_theme_constant_override("outline_size", 2)


func show_bottom_message(text: String) -> void:
	if message_label == null:
		return

	if message_tween != null:
		message_tween.kill()

	message_label.text = text
	message_label.visible = true
	message_label.modulate.a = 0.0

	message_tween = create_tween()
	message_tween.tween_property(message_label, "modulate:a", 1.0, 0.18)
	message_tween.tween_interval(1.2)
	message_tween.tween_property(message_label, "modulate:a", 0.0, 0.25)

	await message_tween.finished

	if message_label != null:
		message_label.visible = false


func set_all_players_control_enabled(state: bool) -> void:
	var players := get_players()

	for p in players:
		if p == null:
			continue

		if !is_instance_valid(p):
			continue

		if p.has_method("set_control_enabled"):
			p.set_control_enabled(state)

		if has_object_property(p, "can_control"):
			p.set("can_control", state)

		if !state and has_object_property(p, "velocity"):
			var current_velocity: Vector2 = p.get("velocity")
			current_velocity.x = 0.0
			p.set("velocity", current_velocity)


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

	var scene := get_tree().current_scene

	if scene != null:
		var player_1_node := scene.get_node_or_null("Player")
		var player_2_node := scene.get_node_or_null("Player2")

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


func is_two_player_mode() -> bool:
	var game_mode := get_node_or_null("/root/GameMode")

	if game_mode == null:
		return false

	return game_mode.is_two_players()


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


func has_object_property(obj: Object, prop_name: String) -> bool:
	if obj == null:
		return false

	for prop in obj.get_property_list():
		if String(prop.get("name", "")) == prop_name:
			return true

	return false
