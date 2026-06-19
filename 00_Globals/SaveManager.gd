extends Node

const SAVE_DIR: String = "user://saves"
const MAX_SAVE_SLOTS: int = 4

var pending_load_data: Dictionary = {}
var is_loading_game: bool = false
var last_save_error: String = ""

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)


func get_save_file_path(slot: int) -> String:
	return SAVE_DIR + "/save_%d.json" % slot


func get_screenshot_path(slot: int) -> String:
	return SAVE_DIR + "/save_%d.png" % slot


func is_valid_slot(slot: int) -> bool:
	return slot >= 1 and slot <= MAX_SAVE_SLOTS


func save_slot(slot: int) -> bool:
	last_save_error = ""

	if not is_valid_slot(slot):
		last_save_error = "Slot lưu không hợp lệ."
		return false

	if !can_save_now():
		return false

	DirAccess.make_dir_recursive_absolute(SAVE_DIR)

	var data: Dictionary = build_save_data(slot)

	await RenderingServer.frame_post_draw

	var image: Image = get_viewport().get_texture().get_image()
	var screenshot_path: String = get_screenshot_path(slot)
	image.save_png(screenshot_path)

	data["screenshot_path"] = screenshot_path

	var file := FileAccess.open(get_save_file_path(slot), FileAccess.WRITE)

	if file == null:
		last_save_error = "Không thể mở file để lưu dữ liệu."
		push_error(last_save_error)
		return false

	file.store_string(JSON.stringify(data, "\t"))
	file.close()

	print("Đã lưu dữ liệu vào slot ", slot)
	return true

func build_save_data(slot: int) -> Dictionary:
	var current_scene_path: String = ""

	if get_tree().current_scene != null:
		current_scene_path = get_tree().current_scene.scene_file_path

	var players_data: Dictionary = build_players_save_data()
	var main_player_position: Vector2 = Vector2.ZERO
	var main_player_data: Dictionary = {}

	var player_1 := get_player_by_id(1)

	if player_1 == null:
		player_1 = get_player_node() as Player

	if player_1 != null:
		main_player_position = player_1.global_position
		main_player_data = serialize_script_vars(player_1)

	var data := {
		"version": 2,
		"slot": slot,
		"saved_at": get_current_datetime_text(),
		"scene_path": current_scene_path,

		# Giữ lại key cũ để save cũ / code cũ không bị gãy.
		"player_position": make_json_safe(main_player_position),
		"player_data": main_player_data,

		# Dữ liệu mới cho 2 người chơi.
		"is_two_player_mode": is_two_player_mode(),
		"players_data": players_data,

		"player_manager_data": serialize_script_vars(PlayerManager),
		"level_manager_data": serialize_script_vars(LevelManager)
	}

	var game_mode := get_game_mode_node()

	if game_mode != null:
		data["game_mode_data"] = serialize_script_vars(game_mode)

	return data


func build_players_save_data() -> Dictionary:
	var result: Dictionary = {}

	for p in get_players():
		if p == null:
			continue

		if !is_instance_valid(p):
			continue

		var player_id_value: int = get_player_id_value(p)
		var key: String = str(player_id_value)

		result[key] = {
			"name": p.name,
			"player_id": player_id_value,
			"position": make_json_safe(p.global_position),
			"data": serialize_script_vars(p)
		}

	return result


func load_slot(slot: int) -> bool:
	if not is_valid_slot(slot):
		return false

	var data: Dictionary = read_save_data(slot)

	if data.is_empty():
		return false

	var scene_path: String = String(data.get("scene_path", ""))

	if scene_path == "":
		push_error("File save không có scene_path.")
		return false

	is_loading_game = true
	pending_load_data = data

	get_tree().paused = false

	if data.has("game_mode_data"):
		var game_mode := get_game_mode_node()

		if game_mode != null:
			restore_script_vars(game_mode, data["game_mode_data"])

	if data.has("level_manager_data"):
		restore_script_vars(LevelManager, data["level_manager_data"])
		if LevelManager.has_method("refresh_arrow_data"):
			LevelManager.refresh_arrow_data()
		refresh_level_manager_after_load()

	var transition := get_node_or_null("/root/SceneTransition")

	if transition != null and transition.has_method("change_scene_with_fade"):
		await transition.change_scene_with_fade(scene_path, 0.5, 0.7)
	else:
		get_tree().change_scene_to_file(scene_path)

	await apply_pending_load_to_scene()

	return true


func apply_pending_load_to_scene() -> void:
	if pending_load_data.is_empty():
		is_loading_game = false
		return

	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	if pending_load_data.has("game_mode_data"):
		var game_mode := get_game_mode_node()

		if game_mode != null:
			restore_script_vars(game_mode, pending_load_data["game_mode_data"])

	if pending_load_data.has("player_manager_data"):
		restore_script_vars(PlayerManager, pending_load_data["player_manager_data"])
		fix_player_manager_after_bad_load()

	if pending_load_data.has("level_manager_data"):
		restore_script_vars(LevelManager, pending_load_data["level_manager_data"])
		if LevelManager.has_method("refresh_arrow_data"):
			LevelManager.refresh_arrow_data()
		refresh_level_manager_after_load()
		fix_player_manager_after_bad_load()
	if pending_load_data.has("players_data"):
		restore_players_from_save_data(pending_load_data["players_data"])
	else:
		restore_legacy_single_player_save()

	pending_load_data.clear()
	is_loading_game = false


func restore_players_from_save_data(players_data) -> void:
	if typeof(players_data) != TYPE_DICTIONARY:
		restore_legacy_single_player_save()
		return

	for key in players_data.keys():
		var one_player_data = players_data[key]

		if typeof(one_player_data) != TYPE_DICTIONARY:
			continue

		var player_id_value: int = int(one_player_data.get("player_id", int(String(key))))
		var target_player := get_player_by_id(player_id_value)

		if target_player == null:
			target_player = get_player_by_name(String(one_player_data.get("name", "")))

		if target_player == null:
			continue

		if one_player_data.has("data"):
			restore_script_vars(target_player, one_player_data["data"])

		if one_player_data.has("position"):
			target_player.global_position = restore_variant(one_player_data["position"])

		reset_player_after_load(target_player)

	update_all_player_ui_after_load()


func restore_legacy_single_player_save() -> void:
	var player_node: Node2D = get_player_node()

	if player_node == null:
		return

	if pending_load_data.has("player_data"):
		restore_script_vars(player_node, pending_load_data["player_data"])

	if pending_load_data.has("player_position"):
		player_node.global_position = restore_variant(pending_load_data["player_position"])

	reset_player_after_load(player_node)
	update_all_player_ui_after_load()


func reset_player_after_load(player_node: Node) -> void:
	if player_node == null:
		return

	# Chống load lại save bị lưu trong lúc YOU DIED.
	if has_object_property(player_node, "is_dead"):
		player_node.set("is_dead", false)

	if has_object_property(player_node, "is_dying"):
		player_node.set("is_dying", false)
	if has_object_property(player_node, "is_shooting_arrow"):
		player_node.set("is_shooting_arrow", false)
	if has_object_property(player_node, "is_respawning"):
		player_node.set("is_respawning", false)

	if has_object_property(player_node, "is_hurt"):
		player_node.set("is_hurt", false)

	if has_object_property(player_node, "is_attacking"):
		player_node.set("is_attacking", false)

	if has_object_property(player_node, "can_control"):
		player_node.set("can_control", true)

	if has_object_property(player_node, "control_enabled"):
		player_node.set("control_enabled", true)

	if has_object_property(player_node, "velocity"):
		player_node.set("velocity", Vector2.ZERO)

	if player_node.has_method("set_control_enabled"):
		player_node.set_control_enabled(true)

	if player_node.has_method("reset_physics_interpolation"):
		player_node.reset_physics_interpolation()

	if player_node.has_method("update_hud"):
		player_node.call("update_hud")

	if player_node.has_method("update_ui"):
		player_node.call("update_ui")

func update_all_player_ui_after_load() -> void:
	for p in get_players():
		if p == null:
			continue

		if !is_instance_valid(p):
			continue

		if p.has_method("update_hud"):
			p.call("update_hud")

		if p.has_method("update_ui"):
			p.call("update_ui")


func read_save_data(slot: int) -> Dictionary:
	var path: String = get_save_file_path(slot)

	if not FileAccess.file_exists(path):
		return {}

	var file := FileAccess.open(path, FileAccess.READ)

	if file == null:
		return {}

	var text: String = file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(text)

	if typeof(parsed) != TYPE_DICTIONARY:
		return {}

	return parsed


func get_slot_info(slot: int) -> Dictionary:
	var data: Dictionary = read_save_data(slot)

	if data.is_empty():
		return {
			"exists": false,
			"slot": slot
		}

	var screenshot_path: String = get_screenshot_path(slot)

	data["exists"] = true
	data["slot"] = slot
	data["screenshot_path"] = screenshot_path
	data["has_screenshot"] = FileAccess.file_exists(screenshot_path)

	return data


func get_all_slots_info() -> Array:
	var result: Array = []

	for slot in range(1, MAX_SAVE_SLOTS + 1):
		result.append(get_slot_info(slot))

	return result


func get_current_datetime_text() -> String:
	var time := Time.get_datetime_dict_from_system()

	return "%02d/%02d/%04d %02d:%02d:%02d" % [
		time["day"],
		time["month"],
		time["year"],
		time["hour"],
		time["minute"],
		time["second"]
	]


func get_player_node() -> Node2D:
	if PlayerManager.player != null and is_instance_valid(PlayerManager.player):
		if PlayerManager.player is Node2D:
			return PlayerManager.player as Node2D

	if get_tree().current_scene == null:
		return null

	var found := find_node_recursive(get_tree().current_scene, "Player")

	if found is Node2D:
		return found as Node2D

	return null


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

			var instance_id: int = detected_player.get_instance_id()

			if added_ids.has(instance_id):
				continue

			added_ids[instance_id] = true
			result.append(detected_player)

	if get_tree().current_scene != null:
		var player_1_node := find_node_recursive(get_tree().current_scene, "Player")
		var player_2_node := find_node_recursive(get_tree().current_scene, "Player2")

		for node in [player_1_node, player_2_node]:
			var detected_player := find_player_from_node(node)

			if detected_player == null:
				continue

			if !is_instance_valid(detected_player):
				continue

			var instance_id_2: int = detected_player.get_instance_id()

			if added_ids.has(instance_id_2):
				continue

			added_ids[instance_id_2] = true
			result.append(detected_player)

	if result.is_empty():
		if PlayerManager.player != null and PlayerManager.player is Player:
			result.append(PlayerManager.player)

	return result


func get_player_by_id(target_id: int) -> Player:
	for p in get_players():
		if p == null:
			continue

		if !is_instance_valid(p):
			continue

		if get_player_id_value(p) == target_id:
			return p

	return null


func get_player_by_name(target_name: String) -> Player:
	if target_name == "":
		return null

	for p in get_players():
		if p == null:
			continue

		if !is_instance_valid(p):
			continue

		if p.name == target_name:
			return p

	return null


func get_player_id_value(player_node: Node) -> int:
	if player_node == null:
		return 1

	if has_object_property(player_node, "player_id"):
		return int(player_node.get("player_id"))

	if player_node.name == "Player2":
		return 2

	return 1


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


func find_node_recursive(parent: Node, target_name: String) -> Node:
	if parent == null:
		return null

	if parent.name == target_name:
		return parent

	for child in parent.get_children():
		var found := find_node_recursive(child, target_name)

		if found != null:
			return found

	return null


func get_game_mode_node() -> Node:
	return get_node_or_null("/root/GameMode")


func is_two_player_mode() -> bool:
	var game_mode := get_game_mode_node()

	if game_mode == null:
		return false

	if game_mode.has_method("is_two_players"):
		return game_mode.is_two_players()

	return false


func serialize_script_vars(obj: Object) -> Dictionary:
	var result: Dictionary = {}

	if obj == null:
		return result

	for prop in obj.get_property_list():
		var usage: int = int(prop.get("usage", 0))

		if (usage & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
			continue

		var prop_name: String = String(prop.get("name", ""))

		if prop_name == "":
			continue

		var value = obj.get(prop_name)

		if not can_save_variant(value):
			continue

		result[prop_name] = make_json_safe(value)

	return result


func restore_script_vars(obj: Object, data: Dictionary) -> void:
	if obj == null:
		return

	if typeof(data) != TYPE_DICTIONARY:
		return

	for key in data.keys():
		var prop_name: String = String(key)

		if not has_object_property(obj, prop_name):
			continue

		obj.set(prop_name, restore_variant(data[key]))


func has_object_property(obj: Object, prop_name: String) -> bool:
	if obj == null:
		return false

	for prop in obj.get_property_list():
		if String(prop.get("name", "")) == prop_name:
			return true

	return false


func can_save_variant(value) -> bool:
	var type_id := typeof(value)

	if type_id in [
		TYPE_NIL,
		TYPE_BOOL,
		TYPE_INT,
		TYPE_FLOAT,
		TYPE_STRING,
		TYPE_VECTOR2,
		TYPE_VECTOR2I,
		TYPE_ARRAY,
		TYPE_DICTIONARY
	]:
		return true

	return false


func make_json_safe(value):
	match typeof(value):
		TYPE_VECTOR2:
			return {
				"__type": "Vector2",
				"x": value.x,
				"y": value.y
			}

		TYPE_VECTOR2I:
			return {
				"__type": "Vector2",
				"x": float(value.x),
				"y": float(value.y)
			}

		TYPE_ARRAY:
			var arr: Array = []

			for item in value:
				if can_save_variant(item):
					arr.append(make_json_safe(item))

			return arr

		TYPE_DICTIONARY:
			var dict: Dictionary = {}

			for key in value.keys():
				var item = value[key]

				if can_save_variant(item):
					dict[String(key)] = make_json_safe(item)

			return dict

		_:
			return value


func restore_variant(value):
	if typeof(value) == TYPE_DICTIONARY:
		if value.has("__type"):
			if value["__type"] == "Vector2":
				return Vector2(float(value["x"]), float(value["y"]))

		var dict: Dictionary = {}

		for key in value.keys():
			dict[key] = restore_variant(value[key])

		return dict

	if typeof(value) == TYPE_ARRAY:
		var arr: Array = []

		for item in value:
			arr.append(restore_variant(item))

		return arr

	return value


func clear_pending_load() -> void:
	pending_load_data.clear()
	is_loading_game = false
func can_save_now() -> bool:
	if is_you_died_ui_visible():
		last_save_error = "Không thể lưu khi màn hình YOU DIED đang hiển thị."
		push_warning(last_save_error)
		return false

	for p in get_players():
		if p == null:
			continue

		if !is_instance_valid(p):
			continue

		if has_object_property(p, "is_dead") and bool(p.get("is_dead")):
			last_save_error = "Không thể lưu khi nhân vật đã chết."
			push_warning(last_save_error)
			return false

	if is_player_manager_health_zero():
		last_save_error = "Không thể lưu khi nhân vật đã hết máu."
		push_warning(last_save_error)
		return false

	return true


func get_last_save_error() -> String:
	return last_save_error
func is_player_manager_health_zero() -> bool:
	var hp_property_names: Array[String] = [
		"current_health",
		"health",
		"current_hp",
		"hp",
		"player_health"
	]

	for prop_name in hp_property_names:
		if !has_object_property(PlayerManager, prop_name):
			continue

		var value: int = int(PlayerManager.get(prop_name))

		if value <= 0:
			return true

	return false

func is_you_died_ui_visible() -> bool:
	var current_scene := get_tree().current_scene

	if current_scene == null:
		return false

	var you_died_ui := find_node_recursive(current_scene, "YouDiedUI")

	if you_died_ui == null:
		return false

	if you_died_ui is CanvasItem:
		return (you_died_ui as CanvasItem).visible

	return false
func fix_player_manager_after_bad_load() -> void:
	if PlayerManager == null:
		return

	var hp_property_names: Array[String] = [
		"current_health",
		"health",
		"current_hp",
		"hp",
		"player_health"
	]

	for prop_name in hp_property_names:
		if !has_object_property(PlayerManager, prop_name):
			continue

		var value: int = int(PlayerManager.get(prop_name))

		if value <= 0:
			PlayerManager.set(prop_name, 1)
func delete_slot(slot: int) -> bool:
	last_save_error = ""

	if not is_valid_slot(slot):
		last_save_error = "Slot lưu không hợp lệ."
		return false

	var save_path: String = get_save_file_path(slot)
	var screenshot_path: String = get_screenshot_path(slot)

	var has_any_file: bool = false

	if FileAccess.file_exists(save_path):
		has_any_file = true

		var save_error: int = DirAccess.remove_absolute(save_path)

		if save_error != OK:
			last_save_error = "Không thể xóa file lưu."
			return false

	if FileAccess.file_exists(screenshot_path):
		has_any_file = true

		var screenshot_error: int = DirAccess.remove_absolute(screenshot_path)

		if screenshot_error != OK:
			last_save_error = "Không thể xóa ảnh lưu."
			return false

	if not has_any_file:
		last_save_error = "File này chưa có dữ liệu để xóa."
		return false

	print("Đã xóa dữ liệu slot ", slot)
	return true
func refresh_level_manager_after_load() -> void:
	if LevelManager == null:
		return

	if LevelManager.has_signal("arrow_changed"):
		LevelManager.arrow_changed.emit(
			bool(LevelManager.get("has_bow")),
			int(LevelManager.get("arrow_count"))
		)
