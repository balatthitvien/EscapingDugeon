extends Area2D

@export_file("*.tscn") var target_scene_path: String
@export var target_spawn_point_name: String = ""

@export var fade_out_time: float = 0.7
@export var fade_in_time: float = 0.7

# Nếu để trống thì cửa luôn hoạt động.
# Nếu có flag thì chỉ hoạt động khi flag = true.
@export var required_flag: String = ""

# =========================
# CO-OP SETTINGS
# =========================
@export var coop_required_radius: float = 95.0
@export var coop_required_player_distance: float = 160.0
@export var coop_required_message: String = "Cả hai cần đứng gần cửa để tiếp tục.\nĐừng bỏ lại đồng đội của mình."

# Nếu muốn kiểm tra tại một điểm chính xác hơn tâm Area2D,
# tạo Marker2D gần cửa rồi kéo vào đây.
@export var coop_check_point_path: NodePath = NodePath("")

var is_changing_scene: bool = false
var is_exit_enabled: bool = true


func _ready() -> void:
	monitoring = true
	monitorable = true

	add_to_group("map_exit_area")

	update_exit_enabled()

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func _process(_delta: float) -> void:
	# Nếu ban đầu bị khóa, sau khi flag được bật thì tự kích hoạt lại.
	if !is_exit_enabled:
		update_exit_enabled()


func update_exit_enabled() -> void:
	if required_flag == "":
		is_exit_enabled = true
	else:
		is_exit_enabled = LevelManager.get_game_flag(required_flag)

	# Không tắt monitoring để tránh lỗi Area2D không bắt lại khi bật giữa game.
	# Chỉ chặn logic đổi map bằng is_exit_enabled.
	monitoring = true
	monitorable = true


func _on_body_entered(body: Node2D) -> void:
	if is_changing_scene:
		return

	update_exit_enabled()

	if !is_exit_enabled:
		print("MapExitArea đang bị khóa. Thiếu flag: ", required_flag)
		return

	var player := find_player_from_node(body)

	if player == null:
		return

	if target_scene_path == "":
		push_warning("MapExitArea chưa set Target Scene Path.")
		return

	if !can_use_exit_as_team():
		show_need_teammate_message()
		return

	is_changing_scene = true

	if target_spawn_point_name != "":
		LevelManager.set_next_spawn_point(target_spawn_point_name)

	await SceneTransition.change_scene_with_fade(
		target_scene_path,
		fade_out_time,
		fade_in_time
	)


func can_use_exit_as_team() -> bool:
	# Nếu không phải chế độ 2 người thì giữ nguyên logic cũ.
	if !is_two_player_mode():
		return true

	# Cần có Autoload CoopRules.
	if get_node_or_null("/root/CoopRules") == null:
		push_warning("Chưa có Autoload CoopRules. Cửa sẽ cho qua để tránh kẹt game.")
		return true

	return CoopRules.can_use_team_point(
		get_coop_check_position(),
		coop_required_radius,
		coop_required_player_distance
	)


func get_coop_check_position() -> Vector2:
	if coop_check_point_path != NodePath(""):
		var check_point := get_node_or_null(coop_check_point_path) as Node2D

		if check_point != null:
			return check_point.global_position

	return global_position


func show_need_teammate_message() -> void:
	if get_node_or_null("/root/CoopRules") == null:
		return

	CoopRules.show_team_required_message(coop_required_message)


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
