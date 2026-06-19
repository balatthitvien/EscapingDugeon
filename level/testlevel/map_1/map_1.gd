extends Node2D

@onready var talk_hint_ui: CanvasLayer = $TalkHintUI
@onready var talk_hint_label: Label = $TalkHintUI/TalkHintLabel
@onready var you_died_ui: CanvasLayer = get_node_or_null("YouDiedUI") as CanvasLayer

# Gán 4 NPC ở đây trong Inspector
@export var hint_npc_paths: Array[NodePath] = [
	^"NPC-Mission",
	^"NPC-Blacksmith",
	^"NPC-Witcher",
	^"NPC-Shop"
]

@export var interact_hint_trigger_distance: float = 65.0
@export var interact_hint_offset: Vector2 = Vector2(-55, -58)
@export var interact_hint_font_size: int = 10
@export var coop_spawn_offset_x: float = 18.0
var player: Player = null

var hint_npcs: Array[Node2D] = []
var hint_labels: Dictionary = {}

var has_connected_player_died: bool = false


func _ready() -> void:
	MusicManager.stop_boss_music()
	MusicManager.play_map_1_music(1.5, true)

	setup_talk_hint_ui()

	setup_player_death_handler()
	apply_player_spawn_point()
	setup_hint_npcs()


func _process(_delta: float) -> void:
	update_first_interact_hints()


func setup_talk_hint_ui() -> void:
	talk_hint_ui.visible = true
	talk_hint_ui.layer = 1000

	# Ẩn label gốc, label này chỉ dùng làm mẫu để duplicate
	talk_hint_label.visible = false
	talk_hint_label.text = get_interact_hint_text()
	talk_hint_label.modulate.a = 0.0
	talk_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	talk_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	talk_hint_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	talk_hint_label.size = Vector2(220, 42)
	talk_hint_label.add_theme_font_size_override("font_size", interact_hint_font_size)


func setup_hint_npcs() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

	hint_npcs.clear()

	for npc_path in hint_npc_paths:
		var npc := get_node_or_null(npc_path) as Node2D

		if npc == null:
			push_warning("map_1: Không tìm thấy NPC hướng dẫn tương tác: " + str(npc_path))
			continue

		hint_npcs.append(npc)
		create_hint_label_for_npc(npc)


func create_hint_label_for_npc(npc: Node2D) -> void:
	if hint_labels.has(npc):
		return

	var label := talk_hint_label.duplicate() as Label
	label.name = "TalkHintLabel_" + npc.name
	label.text = get_interact_hint_text()
	label.visible = false
	label.modulate.a = 1.0

	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	label.size = Vector2(220, 42)
	label.add_theme_font_size_override("font_size", interact_hint_font_size)

	talk_hint_ui.add_child(label)
	hint_labels[npc] = label


func update_first_interact_hints() -> void:
	# Nếu đã hướng dẫn xong lần đầu thì ẩn toàn bộ
	if LevelManager.has_shown_map_1_interact_hint:
		hide_all_interact_hints()
		return

	var player_is_near_any_npc: bool = false
	var player_pressed_interact_near_npc: bool = false

	for npc in hint_npcs:
		if npc == null or !is_instance_valid(npc):
			continue

		var label: Label = hint_labels.get(npc, null)

		if label == null:
			continue

		var near_player := get_near_player_for_npc(npc)
		var player_is_near_npc: bool = near_player != null

		if player_is_near_npc:
			player_is_near_any_npc = true
			update_hint_label_position(npc, label)

			label.text = get_interact_hint_text()

			label.visible = true

			if is_near_player_pressed_interact(npc):
				player_pressed_interact_near_npc = true
		else:
			label.visible = false

	if player_is_near_any_npc and player_pressed_interact_near_npc:
		LevelManager.has_shown_map_1_interact_hint = true
		hide_all_interact_hints()

func update_hint_label_position(npc: Node2D, label: Label) -> void:
	var target_node: Node2D = npc.get_node_or_null("TalkHintPoint") as Node2D

	var screen_position: Vector2

	if target_node != null:
		screen_position = target_node.get_global_transform_with_canvas().origin
	else:
		screen_position = npc.get_global_transform_with_canvas().origin + interact_hint_offset

	label.position = screen_position - Vector2(label.size.x * 0.5, label.size.y)


func hide_all_interact_hints() -> void:
	for key in hint_labels.keys():
		var label: Label = hint_labels[key]

		if label != null:
			label.visible = false


func apply_player_spawn_point() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

	var spawn_name: String = LevelManager.get_next_spawn_point()

	if spawn_name == "":
		return

	var spawn_point := find_spawn_point(spawn_name)

	if spawn_point == null:
		push_warning("map_1: Không tìm thấy spawn point: " + spawn_name)
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

			print("map_1: Đã đưa ", p.name, " tới spawn point: ", spawn_name, " tại ", p.global_position)
	else:
		if PlayerManager.player != null:
			PlayerManager.player.global_position = spawn_point.global_position
			PlayerManager.player.velocity = Vector2.ZERO

			if PlayerManager.player.has_method("set_control_enabled"):
				PlayerManager.player.set_control_enabled(true)

			if PlayerManager.player.has_method("reset_physics_interpolation"):
				PlayerManager.player.reset_physics_interpolation()

	LevelManager.clear_next_spawn_point()

func setup_player_death_handler() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

	player = get_node_or_null("Player") as Player

	if player == null:
		player = PlayerManager.player

	if player == null:
		push_warning("map_1: Không tìm thấy Player để bắt signal died.")
		return

	if you_died_ui == null:
		you_died_ui = get_node_or_null("YouDiedUI") as CanvasLayer

	if you_died_ui == null:
		push_warning("map_1: Không tìm thấy YouDiedUI trong scene.")
		return

	if has_connected_player_died:
		return

	if not player.died.is_connected(_on_player_died):
		player.died.connect(_on_player_died)

	has_connected_player_died = true
	print("map_1: Đã kết nối Player died với YouDiedUI.")


func _on_player_died() -> void:
	print("map_1: PLAYER DIED SIGNAL RECEIVED")

	await get_tree().create_timer(1.0).timeout

	if you_died_ui != null and you_died_ui.has_method("show_you_died"):
		you_died_ui.show_you_died()
func is_player_in_npc_talk_area(npc: Node2D) -> bool:
	if player == null:
		return false

	var talk_area: Area2D = npc.get_node_or_null("TalkArea") as Area2D

	if talk_area == null:
		talk_area = npc.get_node_or_null("Area2D") as Area2D

	if talk_area == null:
		# Nếu NPC không có TalkArea thì mới dùng khoảng cách dự phòng
		var distance_to_npc: float = player.global_position.distance_to(npc.global_position)
		return distance_to_npc <= interact_hint_trigger_distance

	for body in talk_area.get_overlapping_bodies():
		if find_player_from_node(body) == player:
			return true

	for area in talk_area.get_overlapping_areas():
		if find_player_from_node(area) == player:
			return true

	return false


func find_player_from_node(node: Node) -> Player:
	var current: Node = node

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

	var player_1_node: Node = get_node_or_null("Player")
	var player_2_node: Node = get_node_or_null("Player2")

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


func get_near_player_for_npc(npc: Node2D) -> Player:
	var talk_area: Area2D = npc.get_node_or_null("TalkArea") as Area2D

	if talk_area == null:
		talk_area = npc.get_node_or_null("Area2D") as Area2D

	if talk_area == null:
		var players := get_players()

		for p in players:
			if p == null:
				continue

			if !is_instance_valid(p):
				continue

			if !(p is Player):
				continue

			var distance_to_npc: float = (p as Player).global_position.distance_to(npc.global_position)

			if distance_to_npc <= interact_hint_trigger_distance:
				return p as Player

		return null

	for body in talk_area.get_overlapping_bodies():
		var found_player := find_player_from_node(body)

		if found_player != null:
			return found_player

	for area in talk_area.get_overlapping_areas():
		var found_player := find_player_from_node(area)

		if found_player != null:
			return found_player

	return null


func is_near_player_pressed_interact(npc: Node2D) -> bool:
	var near_player := get_near_player_for_npc(npc)

	if near_player == null:
		return false

	if near_player.has_method("is_interact_just_pressed"):
		return near_player.is_interact_just_pressed()

	if is_two_player_mode():
		if int(near_player.get("player_id")) == 1:
			return Input.is_action_just_pressed("p1_interact")
		else:
			return Input.is_action_just_pressed("p2_interact")

	return Input.is_action_just_pressed("interact")
func get_interact_hint_text() -> String:
	if is_two_player_mode():
		return "P1: Ấn E để nói chuyện\nP2: Ấn Chuột phải để nói chuyện"

	return "Ấn E để nói chuyện"

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
