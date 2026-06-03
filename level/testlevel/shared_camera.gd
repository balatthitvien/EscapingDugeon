extends Camera2D

@export var player_1_path: NodePath = NodePath("../Player")
@export var player_2_path: NodePath = NodePath("../Player2")

# Camera mẫu để copy limit/zoom đẹp từ camera 1 player.
@export var template_camera_path: NodePath = NodePath("../Player/Camera2D")

# Zoom bình thường giống bản 1 player.
@export var normal_zoom: Vector2 = Vector2(1.0, 1.0)

# Zoom nhỏ nhất khi 2 player đứng rất xa nhau.
# Số càng nhỏ thì nhìn càng xa.
@export var min_zoom: Vector2 = Vector2(0.65, 0.65)

# Khoảng trống thêm quanh 2 player.
@export var horizontal_margin: float = 170.0
@export var vertical_margin: float = 120.0

# Camera mượt.
@export var follow_smooth_speed: float = 8.0
@export var zoom_smooth_speed: float = 6.0

# Nếu muốn camera hơi cao hơn player thì để âm, ví dụ -20.
@export var vertical_offset: float = 0.0

var player_1: Player = null
var player_2: Player = null


func _ready() -> void:
	if !is_coop_mode():
		enabled = false
		return

	enabled = true
	make_current()

	copy_template_camera_settings()

	await get_tree().process_frame
	await get_tree().process_frame

	find_players()

	if player_1 != null and player_2 != null:
		global_position = get_players_center().round()
		zoom = normal_zoom


func is_coop_mode() -> bool:
	var game_mode := get_node_or_null("/root/GameMode")

	if game_mode == null:
		return false

	return game_mode.is_two_players()


func copy_template_camera_settings() -> void:
	var template_camera := get_node_or_null(template_camera_path) as Camera2D

	if template_camera == null:
		zoom = normal_zoom
		return

	# Copy thông số đẹp từ camera Player 1.
	normal_zoom = template_camera.zoom
	zoom = template_camera.zoom

	limit_left = template_camera.limit_left
	limit_top = template_camera.limit_top
	limit_right = template_camera.limit_right
	limit_bottom = template_camera.limit_bottom

	limit_smoothed = template_camera.limit_smoothed
	position_smoothing_enabled = template_camera.position_smoothing_enabled
	position_smoothing_speed = template_camera.position_smoothing_speed

	rotation_smoothing_enabled = template_camera.rotation_smoothing_enabled
	rotation_smoothing_speed = template_camera.rotation_smoothing_speed

	ignore_rotation = template_camera.ignore_rotation
	anchor_mode = template_camera.anchor_mode
	process_callback = template_camera.process_callback


func find_players() -> void:
	player_1 = get_node_or_null(player_1_path) as Player
	player_2 = get_node_or_null(player_2_path) as Player

	if player_1 != null and player_2 != null:
		return

	var players := get_tree().get_nodes_in_group("players")

	for p in players:
		if !(p is Player):
			continue

		var id_value: int = int(p.get("player_id"))

		if id_value == 1:
			player_1 = p as Player
		elif id_value == 2:
			player_2 = p as Player


func _process(delta: float) -> void:
	if !is_coop_mode():
		return

	if player_1 == null or player_2 == null:
		find_players()

	if player_1 == null or player_2 == null:
		return

	update_camera_position(delta)
	update_camera_zoom(delta)


func get_players_center() -> Vector2:
	var center_position: Vector2 = (player_1.global_position + player_2.global_position) * 0.5
	center_position.y += vertical_offset
	return center_position


func update_camera_position(delta: float) -> void:
	var target_position := get_players_center()

	global_position = global_position.lerp(
		target_position,
		follow_smooth_speed * delta
	).round()


func update_camera_zoom(delta: float) -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size

	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	var min_x: float = min(player_1.global_position.x, player_2.global_position.x)
	var max_x: float = max(player_1.global_position.x, player_2.global_position.x)

	var min_y: float = min(player_1.global_position.y, player_2.global_position.y)
	var max_y: float = max(player_1.global_position.y, player_2.global_position.y)

	var needed_width: float = max_x - min_x + horizontal_margin
	var needed_height: float = max_y - min_y + vertical_margin

	# Godot Camera2D:
	# zoom = 1.0 là bình thường
	# zoom nhỏ hơn 1.0 thì nhìn xa hơn
	var target_zoom_x: float = viewport_size.x / needed_width
	var target_zoom_y: float = viewport_size.y / needed_height

	var target_zoom_value: float = min(target_zoom_x, target_zoom_y)

	# Không cho zoom to hơn camera thường.
	target_zoom_value = min(target_zoom_value, normal_zoom.x)

	# Không cho zoom xa quá.
	target_zoom_value = max(target_zoom_value, min_zoom.x)

	var target_zoom := Vector2(target_zoom_value, target_zoom_value)

	zoom = zoom.lerp(
		target_zoom,
		zoom_smooth_speed * delta
	)
