extends Node
signal tilemap_bounds_changed(bounds: Array[Vector2])
signal arrow_changed(has_bow: bool, arrow_count: int)
const WITCHER_ITEM_BASE_PRICE: int = 30
const WITCHER_ITEM_PRICE_MULTIPLIER: float = 1.3
var current_tilemap_bounds: Array[Vector2] = []

var has_shown_map_1_interact_hint: bool = false

var next_spawn_point_name: String = ""
var opened_chests: Dictionary = {}
var npc_talk_counts: Dictionary = {}
var npc_interact_flags: Dictionary = {}
var game_flags: Dictionary = {}
var has_played_map_1_eye_open: bool = false
var witcher_strength_buy_count: int = 0
var witcher_defense_buy_count: int = 0
var witcher_speed_buy_count: int = 0
var weapon_upgrade_level: int = 0
var weapon_base_upgrade_cost: int = 30
var weapon_upgrade_cost_multiplier: float = 1.5
var saved_campfire_id: String = ""
var saved_respawn_scene_path: String = ""
var saved_respawn_spawn_point_name: String = ""
var map_transition_locked_until_msec: int = 0
var has_bow: bool = false
var arrow_count: int = 0
var has_shown_bow_hint: bool = false
func change_tilemap_bounds(bounds: Array[Vector2]) -> void:
	current_tilemap_bounds = bounds
	tilemap_bounds_changed.emit(bounds)


func has_bounds() -> bool:
	return current_tilemap_bounds.size() == 2


func get_left_limit() -> float:
	if !has_bounds():
		return -999999.0

	return current_tilemap_bounds[0].x


func get_right_limit() -> float:
	if !has_bounds():
		return 999999.0

	return current_tilemap_bounds[1].x


func get_top_limit() -> float:
	if !has_bounds():
		return -999999.0

	return current_tilemap_bounds[0].y


func get_bottom_limit() -> float:
	if !has_bounds():
		return 999999.0

	return current_tilemap_bounds[1].y


func set_next_spawn_point(spawn_name: String) -> void:
	next_spawn_point_name = spawn_name


func get_next_spawn_point() -> String:
	return next_spawn_point_name


func clear_next_spawn_point() -> void:
	next_spawn_point_name = ""


func get_npc_talk_count(npc_id: String) -> int:
	if npc_talk_counts.has(npc_id):
		return npc_talk_counts[npc_id]

	return 0


func set_npc_talk_count(npc_id: String, value: int) -> void:
	npc_talk_counts[npc_id] = value


func has_npc_pressed_interact_once(npc_id: String) -> bool:
	if npc_interact_flags.has(npc_id):
		return npc_interact_flags[npc_id]

	return false


func set_npc_pressed_interact_once(npc_id: String, value: bool) -> void:
	npc_interact_flags[npc_id] = value
func is_chest_opened(chest_id: String) -> bool:
	if opened_chests.has(chest_id):
		return opened_chests[chest_id]

	return false


func set_chest_opened(chest_id: String, value: bool) -> void:
	opened_chests[chest_id] = value
func set_game_flag(flag_name: String, value: bool) -> void:
	game_flags[flag_name] = value


func get_game_flag(flag_name: String) -> bool:
	if game_flags.has(flag_name):
		return game_flags[flag_name]

	return false
func consume_map_1_eye_open_once() -> bool:
	if has_played_map_1_eye_open:
		return false

	has_played_map_1_eye_open = true
	return true


func is_map_1_scene(scene_path: String) -> bool:
	return scene_path == "res://level/testlevel/map_1/map_1.tscn"
func get_weapon_upgrade_level() -> int:
	return weapon_upgrade_level


func get_weapon_bonus_attack() -> int:
	return weapon_upgrade_level


func get_weapon_upgrade_cost() -> int:
	return int(ceil(float(weapon_base_upgrade_cost) * pow(weapon_upgrade_cost_multiplier, float(weapon_upgrade_level))))


func upgrade_weapon() -> void:
	weapon_upgrade_level += 1
func save_campfire_respawn(
	campfire_id: String,
	scene_path: String,
	spawn_point_name: String
) -> void:
	saved_campfire_id = campfire_id
	saved_respawn_scene_path = scene_path
	saved_respawn_spawn_point_name = spawn_point_name


func has_saved_campfire(campfire_id: String) -> bool:
	return saved_campfire_id == campfire_id


func has_any_saved_campfire() -> bool:
	return saved_respawn_scene_path != ""


func get_saved_respawn_scene_path(default_scene_path: String = "") -> String:
	if saved_respawn_scene_path == "":
		return default_scene_path

	return saved_respawn_scene_path


func get_saved_respawn_spawn_point_name() -> String:
	return saved_respawn_spawn_point_name
func lock_map_transition(seconds: float = 1.0) -> void:
	map_transition_locked_until_msec = Time.get_ticks_msec() + int(seconds * 1000.0)


func can_use_map_transition() -> bool:
	return Time.get_ticks_msec() >= map_transition_locked_until_msec


func unlock_map_transition() -> void:
	map_transition_locked_until_msec = 0
func clear_tilemap_bounds() -> void:
	current_tilemap_bounds.clear()
	tilemap_bounds_changed.emit(current_tilemap_bounds)


func set_bounds_from_tilemap_layer(tilemap: TileMapLayer) -> void:
	if tilemap == null:
		clear_tilemap_bounds()
		return

	if tilemap.tile_set == null:
		clear_tilemap_bounds()
		return

	var used_rect: Rect2i = tilemap.get_used_rect()

	if used_rect.size.x <= 0 or used_rect.size.y <= 0:
		clear_tilemap_bounds()
		return

	var tile_size: Vector2 = Vector2(tilemap.tile_set.tile_size)
	var half_tile: Vector2 = tile_size * 0.5

	var top_left_cell: Vector2i = used_rect.position
	var bottom_right_cell: Vector2i = used_rect.position + used_rect.size - Vector2i.ONE

	var top_left: Vector2 = tilemap.to_global(tilemap.map_to_local(top_left_cell) - half_tile)
	var bottom_right: Vector2 = tilemap.to_global(tilemap.map_to_local(bottom_right_cell) + half_tile)

	change_tilemap_bounds([top_left, bottom_right])

	print("MAP BOUNDS SET: ", top_left, " -> ", bottom_right)
func unlock_bow(start_arrow_count: int = 10) -> void:
	has_bow = true
	arrow_count += max(start_arrow_count, 0)

	arrow_changed.emit(has_bow, arrow_count)


func add_arrows(amount: int) -> void:
	if amount <= 0:
		return

	has_bow = true
	arrow_count += amount

	arrow_changed.emit(has_bow, arrow_count)


func can_shoot_arrow() -> bool:
	if !has_bow:
		return false

	return arrow_count > 0


func consume_arrow() -> bool:
	if !can_shoot_arrow():
		return false

	arrow_count -= 1
	arrow_count = max(arrow_count, 0)

	arrow_changed.emit(has_bow, arrow_count)

	return true


func consume_bow_hint_once() -> bool:
	if has_shown_bow_hint:
		return false

	has_shown_bow_hint = true
	return true
func reset_bow_data() -> void:
	has_bow = false
	arrow_count = 0
	has_shown_bow_hint = false

	arrow_changed.emit(has_bow, arrow_count)
func refresh_arrow_data() -> void:
	arrow_count = max(arrow_count, 0)
	arrow_changed.emit(has_bow, arrow_count)
func get_witcher_item_price(item_id: String) -> int:
	var buy_count := get_witcher_item_buy_count(item_id)
	return int(round(float(WITCHER_ITEM_BASE_PRICE) * pow(WITCHER_ITEM_PRICE_MULTIPLIER, float(buy_count))))


func get_witcher_item_buy_count(item_id: String) -> int:
	match item_id:
		"strength":
			return witcher_strength_buy_count
		"defense":
			return witcher_defense_buy_count
		"speed":
			return witcher_speed_buy_count

	return 0


func increase_witcher_item_buy_count(item_id: String) -> void:
	match item_id:
		"strength":
			witcher_strength_buy_count += 1
		"defense":
			witcher_defense_buy_count += 1
		"speed":
			witcher_speed_buy_count += 1


func reset_witcher_shop_data() -> void:
	witcher_strength_buy_count = 0
	witcher_defense_buy_count = 0
	witcher_speed_buy_count = 0
