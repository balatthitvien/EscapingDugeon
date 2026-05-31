extends Node

const SAVE_DIR: String = "user://saves"
const MAX_SAVE_SLOTS: int = 4

var pending_load_data: Dictionary = {}
var is_loading_game: bool = false


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)


func get_save_file_path(slot: int) -> String:
	return SAVE_DIR + "/save_%d.json" % slot


func get_screenshot_path(slot: int) -> String:
	return SAVE_DIR + "/save_%d.png" % slot


func is_valid_slot(slot: int) -> bool:
	return slot >= 1 and slot <= MAX_SAVE_SLOTS


func save_slot(slot: int) -> bool:
	if not is_valid_slot(slot):
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
		push_error("Không thể mở file để lưu dữ liệu.")
		return false

	file.store_string(JSON.stringify(data, "\t"))
	file.close()

	print("Đã lưu dữ liệu vào slot ", slot)
	return true


func build_save_data(slot: int) -> Dictionary:
	var current_scene_path: String = ""

	if get_tree().current_scene != null:
		current_scene_path = get_tree().current_scene.scene_file_path

	var player_node: Node2D = get_player_node()

	var player_position := Vector2.ZERO
	var player_data: Dictionary = {}

	if player_node != null:
		player_position = player_node.global_position
		player_data = serialize_script_vars(player_node)

	var data := {
		"version": 1,
		"slot": slot,
		"saved_at": get_current_datetime_text(),
		"scene_path": current_scene_path,
		"player_position": make_json_safe(player_position),
		"player_data": player_data,
		"player_manager_data": serialize_script_vars(PlayerManager),
		"level_manager_data": serialize_script_vars(LevelManager)
	}

	return data


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

	if data.has("level_manager_data"):
		restore_script_vars(LevelManager, data["level_manager_data"])

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

	if pending_load_data.has("player_manager_data"):
		restore_script_vars(PlayerManager, pending_load_data["player_manager_data"])

	var player_node: Node2D = get_player_node()

	if player_node != null:
		if pending_load_data.has("player_data"):
			restore_script_vars(player_node, pending_load_data["player_data"])

		if pending_load_data.has("player_position"):
			player_node.global_position = restore_variant(pending_load_data["player_position"])

		if has_object_property(player_node, "velocity"):
			player_node.set("velocity", Vector2.ZERO)

		if player_node.has_method("update_hud"):
			player_node.call("update_hud")

		if player_node.has_method("update_ui"):
			player_node.call("update_ui")

	pending_load_data.clear()
	is_loading_game = false


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


func find_node_recursive(parent: Node, target_name: String) -> Node:
	if parent.name == target_name:
		return parent

	for child in parent.get_children():
		var found := find_node_recursive(child, target_name)

		if found != null:
			return found

	return null


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
