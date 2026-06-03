extends Camera2D

# 1.0 là giống camera 1 player.
@export var normal_zoom: Vector2 = Vector2(1.0, 1.0)

# Khi 2 player cách xa nhau thì zoom nhỏ xuống để nhìn rộng hơn.
# 0.85 nghĩa là nhìn xa hơn 1 chút.
@export var far_zoom: Vector2 = Vector2(0.85, 0.85)

@export var zoom_distance_start: float = 220.0
@export var zoom_distance_end: float = 520.0

@export var smooth_speed: float = 8.0
@export var zoom_smooth_speed: float = 5.0
@export var vertical_offset: float = -20.0

var player_1: Node2D = null
var player_2: Node2D = null


func _ready() -> void:
	if !is_coop_mode():
		enabled = false
		return

	enabled = true
	make_current()

	zoom = normal_zoom

	await get_tree().process_frame
	await get_tree().process_frame

	find_players()
	apply_camera_limits()

	if player_1 != null and player_2 != null:
		global_position = get_coop_target_position().round()


func is_coop_mode() -> bool:
	var game_mode := get_node_or_null("/root/GameMode")

	if game_mode == null:
		return false

	return game_mode.is_two_players()


func find_players() -> void:
	player_1 = null
	player_2 = null

	var players := get_tree().get_nodes_in_group("players")

	for p in players:
		if !(p is Node2D):
			continue

		var id_value: int = int(p.get("player_id"))

		if id_value == 1:
			player_1 = p as Node2D
		elif id_value == 2:
			player_2 = p as Node2D


func _process(delta: float) -> void:
	if !is_coop_mode():
		return

	if player_1 == null or player_2 == null:
		find_players()

	if player_1 == null or player_2 == null:
		return

	apply_camera_limits()
	follow_players(delta)
	update_zoom(delta)


func get_coop_target_position() -> Vector2:
	var middle_position: Vector2 = (player_1.global_position + player_2.global_position) * 0.5
	middle_position.y += vertical_offset
	return middle_position


func follow_players(delta: float) -> void:
	var target_position := get_coop_target_position()

	global_position = global_position.lerp(
		target_position,
		smooth_speed * delta
	).round()


func update_zoom(delta: float) -> void:
	var distance: float = player_1.global_position.distance_to(player_2.global_position)

	var t: float = inverse_lerp(
		zoom_distance_start,
		zoom_distance_end,
		distance
	)

	t = clamp(t, 0.0, 1.0)

	# Quan trọng:
	# normal_zoom = 1.0
	# far_zoom = 0.85
	# Khi xa nhau thì zoom nhỏ đi, nhìn rộng hơn.
	var target_zoom: Vector2 = normal_zoom.lerp(far_zoom, t)

	zoom = zoom.lerp(
		target_zoom,
		zoom_smooth_speed * delta
	)


func apply_camera_limits() -> void:
	if !LevelManager.has_bounds():
		return

	limit_left = int(LevelManager.get_left_limit())
	limit_right = int(LevelManager.get_right_limit())
	limit_top = int(LevelManager.get_top_limit())
	limit_bottom = int(LevelManager.get_bottom_limit())
