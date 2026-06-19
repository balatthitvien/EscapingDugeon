extends Camera2D

@export var player_1_path: NodePath = NodePath("../Player")
@export var player_2_path: NodePath = NodePath("../Player2")

# Camera mẫu để copy zoom / limit đẹp từ camera 1 player.
@export var template_camera_path: NodePath = NodePath("../Player/Camera2D")

# Zoom bình thường giống bản 1 player.
@export var normal_zoom: Vector2 = Vector2(1.0, 1.0)

# Zoom xa nhất. Số càng nhỏ thì nhìn càng xa.
@export var min_zoom: Vector2 = Vector2(0.35, 0.35)

# Khoảng trống thêm quanh 2 player.
# Tăng horizontal_margin nếu muốn camera dãn ra sớm hơn.
@export var horizontal_margin: float = 420.0
@export var vertical_margin: float = 160.0

# Camera mượt.
# Số thấp hơn = mượt hơn nhưng theo chậm hơn.
# Số cao hơn = bám nhanh hơn nhưng dễ giật hơn.
@export var follow_smooth_speed: float = 4.5
@export var zoom_smooth_speed: float = 3.2

# Chặn rung zoom rất nhỏ.
@export var zoom_dead_zone: float = 0.012

# Nếu muốn camera hơi cao hơn player thì để âm, ví dụ -18.
@export var vertical_offset: float = 0.0

# Dùng limit lấy từ camera mẫu, nhưng clamp thủ công để tránh giật.
@export var use_template_limits: bool = true

var player_1: Player = null
var player_2: Player = null

var map_limit_left: float = -1000000.0
var map_limit_top: float = -1000000.0
var map_limit_right: float = 1000000.0
var map_limit_bottom: float = 1000000.0


func _ready() -> void:
	if !is_coop_mode():
		enabled = false
		return

	enabled = true
	make_current()

	copy_template_camera_settings()

	# Quan trọng:
	# Không dùng smoothing/limit mặc định của Camera2D nữa.
	# Mình tự smooth và tự clamp để tránh giật.
	position_smoothing_enabled = false
	rotation_smoothing_enabled = false
	limit_smoothed = false

	disable_builtin_camera_limits()

	await get_tree().process_frame
	await get_tree().process_frame

	find_players()

	if player_1 != null and player_2 != null:
		zoom = normal_zoom
		global_position = get_clamped_camera_position(get_players_center(), zoom.x)


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

	normal_zoom = template_camera.zoom
	zoom = normal_zoom

	map_limit_left = float(template_camera.limit_left)
	map_limit_top = float(template_camera.limit_top)
	map_limit_right = float(template_camera.limit_right)
	map_limit_bottom = float(template_camera.limit_bottom)

	ignore_rotation = template_camera.ignore_rotation
	anchor_mode = template_camera.anchor_mode


func disable_builtin_camera_limits() -> void:
	# Nếu để limit thật ở Camera2D, Godot sẽ tự clamp theo zoom hiện tại.
	# Khi zoom thay đổi liên tục sẽ gây giật.
	limit_left = -1000000
	limit_top = -1000000
	limit_right = 1000000
	limit_bottom = 1000000


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


func _physics_process(delta: float) -> void:
	if !is_coop_mode():
		return

	if player_1 == null or player_2 == null:
		find_players()

	if player_1 == null or player_2 == null:
		return

	update_camera_zoom(delta)
	update_camera_position(delta)


func get_players_center() -> Vector2:
	var center_position: Vector2 = (player_1.global_position + player_2.global_position) * 0.5
	center_position.y += vertical_offset
	return center_position


func update_camera_position(delta: float) -> void:
	var target_position: Vector2 = get_players_center()
	target_position = get_clamped_camera_position(target_position, zoom.x)

	var smooth_weight: float = get_smooth_weight(follow_smooth_speed, delta)

	global_position = global_position.lerp(target_position, smooth_weight)


func update_camera_zoom(delta: float) -> void:
	var target_zoom_value: float = get_target_zoom_value()

	# Chặn rung zoom nhỏ.
	# Nếu target zoom chỉ lệch rất ít thì giữ nguyên, tránh camera thở liên tục.
	if abs(target_zoom_value - zoom.x) < zoom_dead_zone:
		target_zoom_value = zoom.x

	var smooth_weight: float = get_smooth_weight(zoom_smooth_speed, delta)
	var new_zoom_value: float = lerp(zoom.x, target_zoom_value, smooth_weight)

	zoom = Vector2(new_zoom_value, new_zoom_value)


func get_target_zoom_value() -> float:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size

	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return normal_zoom.x

	var min_x: float = min(player_1.global_position.x, player_2.global_position.x)
	var max_x: float = max(player_1.global_position.x, player_2.global_position.x)

	var min_y: float = min(player_1.global_position.y, player_2.global_position.y)
	var max_y: float = max(player_1.global_position.y, player_2.global_position.y)

	var needed_width: float = max_x - min_x + horizontal_margin
	var needed_height: float = max_y - min_y + vertical_margin

	needed_width = max(needed_width, 1.0)
	needed_height = max(needed_height, 1.0)

	# Godot Camera2D:
	# zoom = 1.0 là bình thường
	# zoom nhỏ hơn 1.0 thì nhìn xa hơn
	var target_zoom_x: float = viewport_size.x / needed_width
	var target_zoom_y: float = viewport_size.y / needed_height

	var target_zoom_value: float = min(target_zoom_x, target_zoom_y)

	# Không cho zoom to hơn camera thường.
	target_zoom_value = min(target_zoom_value, normal_zoom.x)

	# Không cho zoom xa quá min_zoom.
	target_zoom_value = max(target_zoom_value, min_zoom.x)

	return target_zoom_value


func get_clamped_camera_position(target_position: Vector2, zoom_value: float) -> Vector2:
	if !use_template_limits:
		return target_position

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size

	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return target_position

	zoom_value = max(zoom_value, 0.001)

	# Kích thước nửa màn hình tính theo world unit.
	var half_visible_size: Vector2 = (viewport_size * 0.5) / zoom_value

	var min_camera_x: float = map_limit_left + half_visible_size.x
	var max_camera_x: float = map_limit_right - half_visible_size.x

	var min_camera_y: float = map_limit_top + half_visible_size.y
	var max_camera_y: float = map_limit_bottom - half_visible_size.y

	var clamped_position: Vector2 = target_position

	if max_camera_x < min_camera_x:
		clamped_position.x = (map_limit_left + map_limit_right) * 0.5
	else:
		clamped_position.x = clamp(clamped_position.x, min_camera_x, max_camera_x)

	if max_camera_y < min_camera_y:
		clamped_position.y = (map_limit_top + map_limit_bottom) * 0.5
	else:
		clamped_position.y = clamp(clamped_position.y, min_camera_y, max_camera_y)

	return clamped_position


func get_smooth_weight(speed: float, delta: float) -> float:
	# Cách smooth này ổn định hơn speed * delta thường.
	# FPS cao/thấp đều mượt hơn.
	return 1.0 - exp(-speed * delta)



func force_snap_to_players() -> void:
	find_players()

	if player_1 == null or player_2 == null:
		return

	var target_position: Vector2 = get_players_center()

	# Nếu bản SharedCamera của bạn có hàm clamp thủ công thì dùng.
	if has_method("get_clamped_camera_position"):
		target_position = get_clamped_camera_position(target_position, zoom.x)

	global_position = target_position
	reset_smoothing()

	# Cho chắc thêm 1 frame sau vẫn giữ đúng vị trí.
	await get_tree().process_frame

	if player_1 != null and player_2 != null:
		target_position = get_players_center()

		if has_method("get_clamped_camera_position"):
			target_position = get_clamped_camera_position(target_position, zoom.x)

		global_position = target_position
		reset_smoothing()
