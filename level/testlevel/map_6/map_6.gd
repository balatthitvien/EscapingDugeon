extends Node2D

@onready var main_tilemap: TileMapLayer = $TileMapLayer
@onready var player: Player = get_node_or_null("Player") as Player

@export var extra_bound_margin: float = 250.0

var target_spawn_position: Vector2 = Vector2.ZERO
var has_target_spawn_position: bool = false


func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

	setup_map_bounds()

	await get_tree().process_frame
	await get_tree().physics_frame

	apply_player_spawn_point()

	await get_tree().create_timer(0.1).timeout
	recheck_player_spawn_position()


func setup_map_bounds() -> void:
	if main_tilemap == null:
		push_warning("map_6: Không tìm thấy TileMapLayer chính để cập nhật giới hạn map.")
		return

	if LevelManager.has_method("update_tilemap_bounds"):
		LevelManager.update_tilemap_bounds(main_tilemap)
		print("map_6: Đã cập nhật giới hạn map theo TileMapLayer.")
		print("map_6 bounds: ", LevelManager.get_left_limit(), " -> ", LevelManager.get_right_limit())
	else:
		push_warning("LevelManager chưa có hàm update_tilemap_bounds.")


func apply_player_spawn_point() -> void:
	var spawn_name: String = LevelManager.get_next_spawn_point()
	spawn_name = spawn_name.strip_edges()

	print("map_6 nhận spawn point: [", spawn_name, "]")

	if spawn_name == "":
		return

	var spawn_point := get_node_or_null("SpawnPoints/" + spawn_name) as Node2D

	if spawn_point == null:
		push_warning("map_6: Không tìm thấy spawn point: " + spawn_name)
		LevelManager.clear_next_spawn_point()
		return

	player = find_player()

	if player == null:
		push_warning("map_6: Không tìm thấy Player để đặt spawn point.")
		LevelManager.clear_next_spawn_point()
		return

	target_spawn_position = spawn_point.global_position
	has_target_spawn_position = true

	extend_player_bounds_to_include_position(target_spawn_position)

	force_set_player_position(target_spawn_position)

	print("map_6: Đã đặt Player tại ", spawn_name, " | vị trí: ", target_spawn_position)

	LevelManager.clear_next_spawn_point()


func extend_player_bounds_to_include_position(position_to_include: Vector2) -> void:
	if player == null:
		return

	if !LevelManager.has_bounds():
		return

	var half_width: float = player.get_body_half_width()

	var current_left_limit: float = LevelManager.get_left_limit() + half_width + player.left_map_padding
	var current_right_limit: float = LevelManager.get_right_limit() - half_width - player.right_map_padding

	print("map_6 giới hạn trước khi nới: ", current_left_limit, " -> ", current_right_limit)
	print("map_6 vị trí cần chứa: ", position_to_include.x)

	if position_to_include.x > current_right_limit:
		var extra_right: float = position_to_include.x - current_right_limit + extra_bound_margin
		player.right_map_padding -= extra_right
		print("map_6: Nới biên phải thêm ", extra_right, " | right_map_padding mới = ", player.right_map_padding)

	if position_to_include.x < current_left_limit:
		var extra_left: float = current_left_limit - position_to_include.x + extra_bound_margin
		player.left_map_padding -= extra_left
		print("map_6: Nới biên trái thêm ", extra_left, " | left_map_padding mới = ", player.left_map_padding)


func recheck_player_spawn_position() -> void:
	if !has_target_spawn_position:
		return

	player = find_player()

	if player == null:
		return

	var distance_to_spawn: float = player.global_position.distance_to(target_spawn_position)

	print("map_6 kiểm tra lại spawn. Player: ", player.global_position, " | Spawn: ", target_spawn_position, " | lệch: ", distance_to_spawn)

	if distance_to_spawn > 8.0:
		print("map_6: Player bị lệch khỏi spawn, đặt lại lần nữa.")
		extend_player_bounds_to_include_position(target_spawn_position)
		force_set_player_position(target_spawn_position)


func force_set_player_position(new_position: Vector2) -> void:
	if player == null:
		return

	player.global_position = new_position
	player.velocity = Vector2.ZERO

	if player.has_method("set_control_enabled"):
		player.set_control_enabled(true)

	if player.has_method("reset_physics_interpolation"):
		player.reset_physics_interpolation()


func find_player() -> Player:
	var scene_player := get_node_or_null("Player") as Player

	if scene_player != null:
		return scene_player

	if PlayerManager.player != null and PlayerManager.player is Player:
		return PlayerManager.player as Player

	return null
