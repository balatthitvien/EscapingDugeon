extends Node2D

@onready var main_tilemap: TileMapLayer = get_node_or_null("TileMapLayer") as TileMapLayer
@onready var slime_boss_music: AudioStreamPlayer = find_child("SlimeBossMusic", true, false) as AudioStreamPlayer
@onready var you_died_ui: CanvasLayer = get_node_or_null("YouDiedUI") as CanvasLayer
@export var extra_bound_margin: float = 250.0
@export var coop_spawn_offset_x: float = 22.0

@export var reset_map_padding_on_enter: bool = true
@export var base_left_map_padding: float = 0.0
@export var base_right_map_padding: float = 0.0

@export var slime_boss_music_volume_db: float = -7.5
@export var slime_boss_music_muted_db: float = -80.0
@export var slime_boss_music_fade_time: float = 0.8

@export var extra_bound_node_paths: Array[NodePath] = []

var target_spawn_position: Vector2 = Vector2.ZERO
var has_target_spawn_position: bool = false
var slime_boss_music_tween: Tween = null
var has_started_slime_boss_music: bool = false
var slime_boss_ref: Node = null
var has_handled_player_death: bool = false
func _ready() -> void:
	MusicManager.play_game_bgm(1.5)
	setup_slime_boss_music()
	await get_tree().process_frame
	await get_tree().process_frame

	setup_map_bounds()

	await get_tree().process_frame
	await get_tree().physics_frame

	reset_all_players_map_padding()
	extend_bounds_to_important_points()
	apply_player_spawn_point()

	await get_tree().create_timer(0.1).timeout
	recheck_player_spawn_position()
	connect_player_death_signals()

func setup_map_bounds() -> void:
	if main_tilemap == null:
		main_tilemap = get_node_or_null("World/TileMapLayer") as TileMapLayer

	if main_tilemap == null:
		push_warning("map_6: Không tìm thấy TileMapLayer chính để cập nhật giới hạn map.")
		return

	if LevelManager.has_method("update_tilemap_bounds"):
		LevelManager.update_tilemap_bounds(main_tilemap)
		print("map_6: Đã cập nhật giới hạn map theo TileMapLayer.")
		print("map_6 bounds: ", LevelManager.get_left_limit(), " -> ", LevelManager.get_right_limit())
	else:
		push_warning("LevelManager chưa có hàm update_tilemap_bounds.")


func reset_all_players_map_padding() -> void:
	if !reset_map_padding_on_enter:
		return

	for p in get_players():
		if p == null:
			continue

		if !is_instance_valid(p):
			continue

		set_player_bound_padding(p, base_left_map_padding, base_right_map_padding)


func set_player_bound_padding(target_player: Player, left_value: float, right_value: float) -> void:
	if target_player == null:
		return

	if has_object_property(target_player, "left_map_padding"):
		target_player.set("left_map_padding", left_value)

	if has_object_property(target_player, "right_map_padding"):
		target_player.set("right_map_padding", right_value)


func extend_bounds_to_important_points() -> void:
	if !LevelManager.has_bounds():
		return

	# Nới bounds theo toàn bộ SpawnPoints.
	var spawn_root := get_node_or_null("SpawnPoints")

	if spawn_root != null:
		for child in spawn_root.get_children():
			if child is Node2D:
				extend_all_players_bounds_to_include_position((child as Node2D).global_position)

	# Nới bounds theo các cửa chuyển map nếu cửa có group map_exit_area.
	for exit_node in get_tree().get_nodes_in_group("map_exit_area"):
		if exit_node is Node2D:
			extend_all_players_bounds_to_include_position((exit_node as Node2D).global_position)

	# Nới bounds theo node bạn kéo thủ công trong Inspector.
	for node_path in extra_bound_node_paths:
		if node_path == NodePath(""):
			continue

		var node := get_node_or_null(node_path) as Node2D

		if node != null:
			extend_all_players_bounds_to_include_position(node.global_position)


func apply_player_spawn_point() -> void:
	var spawn_name: String = LevelManager.get_next_spawn_point()
	spawn_name = spawn_name.strip_edges()

	print("map_6 nhận spawn point: [", spawn_name, "]")

	if spawn_name == "":
		return

	var spawn_point := find_spawn_point(spawn_name)

	if spawn_point == null:
		push_warning("map_6: Không tìm thấy spawn point: " + spawn_name)
		LevelManager.clear_next_spawn_point()
		return

	target_spawn_position = spawn_point.global_position
	has_target_spawn_position = true

	extend_all_players_bounds_to_include_position(target_spawn_position)

	if is_two_player_mode():
		force_set_all_players_position(target_spawn_position)
	else:
		var p := find_player()

		if p == null:
			push_warning("map_6: Không tìm thấy Player để đặt spawn point.")
			LevelManager.clear_next_spawn_point()
			return

		force_set_player_position(p, target_spawn_position)

	print("map_6: Đã đặt player tại ", spawn_name, " | vị trí: ", target_spawn_position)

	snap_shared_camera()

	LevelManager.clear_next_spawn_point()


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


func extend_all_players_bounds_to_include_position(position_to_include: Vector2) -> void:
	if !LevelManager.has_bounds():
		return

	for p in get_players():
		if p == null:
			continue

		if !is_instance_valid(p):
			continue

		extend_one_player_bounds_to_include_position(p, position_to_include)


func extend_one_player_bounds_to_include_position(target_player: Player, position_to_include: Vector2) -> void:
	if target_player == null:
		return

	if !LevelManager.has_bounds():
		return

	var half_width: float = 16.0

	if target_player.has_method("get_body_half_width"):
		half_width = float(target_player.get_body_half_width())

	var left_padding: float = get_object_float_property(target_player, "left_map_padding", 0.0)
	var right_padding: float = get_object_float_property(target_player, "right_map_padding", 0.0)

	var current_left_limit: float = LevelManager.get_left_limit() + half_width + left_padding
	var current_right_limit: float = LevelManager.get_right_limit() - half_width - right_padding

	print(
		"map_6 giới hạn của ",
		target_player.name,
		" trước khi nới: ",
		current_left_limit,
		" -> ",
		current_right_limit,
		" | cần chứa: ",
		position_to_include.x
	)

	if position_to_include.x > current_right_limit:
		var extra_right: float = position_to_include.x - current_right_limit + extra_bound_margin
		right_padding -= extra_right
		set_object_float_property(target_player, "right_map_padding", right_padding)
		print("map_6: Nới biên phải cho ", target_player.name, " thêm ", extra_right, " | right_map_padding mới = ", right_padding)

	if position_to_include.x < current_left_limit:
		var extra_left: float = current_left_limit - position_to_include.x + extra_bound_margin
		left_padding -= extra_left
		set_object_float_property(target_player, "left_map_padding", left_padding)
		print("map_6: Nới biên trái cho ", target_player.name, " thêm ", extra_left, " | left_map_padding mới = ", left_padding)


func recheck_player_spawn_position() -> void:
	if !has_target_spawn_position:
		return

	if is_two_player_mode():
		for p in get_players():
			if p == null:
				continue

			if !is_instance_valid(p):
				continue

			var expected_position: Vector2 = get_spawn_position_for_player(p, target_spawn_position)
			var player_distance_to_spawn: float = p.global_position.distance_to(expected_position)

			print("map_6 kiểm tra lại spawn ", p.name, " | Player: ", p.global_position, " | Spawn: ", expected_position, " | lệch: ", player_distance_to_spawn)

			if player_distance_to_spawn > 12.0:
				print("map_6: ", p.name, " bị lệch khỏi spawn, đặt lại lần nữa.")
				extend_all_players_bounds_to_include_position(target_spawn_position)
				force_set_player_position(p, expected_position)

		snap_shared_camera()
		return

	var p := find_player()

	if p == null:
		return

	var single_player_distance_to_spawn: float = p.global_position.distance_to(target_spawn_position)

	print("map_6 kiểm tra lại spawn. Player: ", p.global_position, " | Spawn: ", target_spawn_position, " | lệch: ", single_player_distance_to_spawn)

	if single_player_distance_to_spawn > 8.0:
		print("map_6: Player bị lệch khỏi spawn, đặt lại lần nữa.")
		extend_one_player_bounds_to_include_position(p, target_spawn_position)
		force_set_player_position(p, target_spawn_position)
		snap_shared_camera()
func force_set_all_players_position(spawn_position: Vector2) -> void:
	var players := get_players()

	if players.is_empty():
		push_warning("map_6: Không tìm thấy player nào để đặt spawn point.")
		return

	for p in players:
		if p == null:
			continue

		if !is_instance_valid(p):
			continue

		var final_position: Vector2 = get_spawn_position_for_player(p, spawn_position)
		force_set_player_position(p, final_position)


func get_spawn_position_for_player(target_player: Player, spawn_position: Vector2) -> Vector2:
	if !is_two_player_mode():
		return spawn_position

	var id_value: int = 1

	if has_object_property(target_player, "player_id"):
		id_value = int(target_player.get("player_id"))
	elif target_player.name == "Player2":
		id_value = 2

	if id_value == 1:
		return spawn_position + Vector2(-coop_spawn_offset_x, 0.0)

	return spawn_position + Vector2(coop_spawn_offset_x, 0.0)


func force_set_player_position(target_player: Player, new_position: Vector2) -> void:
	if target_player == null:
		return

	target_player.global_position = new_position
	target_player.velocity = Vector2.ZERO

	if target_player.has_method("set_control_enabled"):
		target_player.set_control_enabled(true)

	if has_object_property(target_player, "can_control"):
		target_player.set("can_control", true)

	if target_player.has_method("reset_physics_interpolation"):
		target_player.reset_physics_interpolation()


func snap_shared_camera() -> void:
	var shared_camera := get_node_or_null("SharedCamera")

	if shared_camera == null:
		shared_camera = get_node_or_null("World/SharedCamera")

	if shared_camera != null and shared_camera.has_method("force_snap_to_players"):
		shared_camera.force_snap_to_players()


func find_player() -> Player:
	var scene_player := get_node_or_null("Player") as Player

	if scene_player != null:
		return scene_player

	scene_player = get_node_or_null("World/Player") as Player

	if scene_player != null:
		return scene_player

	if PlayerManager.player != null and PlayerManager.player is Player:
		return PlayerManager.player as Player

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

			var id: int = detected_player.get_instance_id()

			if added_ids.has(id):
				continue

			added_ids[id] = true
			result.append(detected_player)

	var player_1_node := get_node_or_null("Player")
	var player_2_node := get_node_or_null("Player2")
	var world_player_1_node := get_node_or_null("World/Player")
	var world_player_2_node := get_node_or_null("World/Player2")

	for node in [player_1_node, player_2_node, world_player_1_node, world_player_2_node]:
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


func is_two_player_mode() -> bool:
	var game_mode := get_node_or_null("/root/GameMode")

	if game_mode == null:
		return false

	return game_mode.is_two_players()


func has_object_property(obj: Object, prop_name: String) -> bool:
	if obj == null:
		return false

	for prop in obj.get_property_list():
		if String(prop.get("name", "")) == prop_name:
			return true

	return false


func get_object_float_property(obj: Object, prop_name: String, default_value: float) -> float:
	if obj == null:
		return default_value

	if !has_object_property(obj, prop_name):
		return default_value

	return float(obj.get(prop_name))


func set_object_float_property(obj: Object, prop_name: String, value: float) -> void:
	if obj == null:
		return

	if !has_object_property(obj, prop_name):
		return

	obj.set(prop_name, value)
func setup_slime_boss_music() -> void:
	if slime_boss_music == null:
		push_warning("map_6: Không tìm thấy node AudioStreamPlayer tên SlimeBossMusic.")
	else:
		print("map_6: Đã tìm thấy SlimeBossMusic = ", slime_boss_music.name)
		slime_boss_music.stop()
		slime_boss_music.autoplay = false
		slime_boss_music.volume_db = slime_boss_music_muted_db

		if slime_boss_music.stream == null:
			push_warning("map_6: SlimeBossMusic chưa được gán file nhạc trong Inspector.")

	var slime_boss := find_slime_boss()
	slime_boss_ref = slime_boss
	if slime_boss == null:
		push_warning("map_6: Không tìm thấy SlimeBoss để nối signal nhạc.")
		return

	print("map_6: Đã tìm thấy SlimeBoss = ", slime_boss.name)

	if slime_boss.has_signal("slime_boss_detected_player"):
		if not slime_boss.slime_boss_detected_player.is_connected(_on_slime_boss_detected_player):
			slime_boss.slime_boss_detected_player.connect(_on_slime_boss_detected_player)
			print("map_6: Đã connect signal slime_boss_detected_player.")

	if slime_boss.has_signal("enemy_died"):
		if not slime_boss.enemy_died.is_connected(_on_slime_boss_died):
			slime_boss.enemy_died.connect(_on_slime_boss_died)


func find_slime_boss() -> Node:
	var boss := get_node_or_null("SlimeBoss")

	if boss != null:
		return boss

	boss = get_node_or_null("World/SlimeBoss")

	if boss != null:
		return boss

	boss = get_node_or_null("Enemy")

	if boss != null:
		return boss

	boss = get_node_or_null("World/Enemy")

	if boss != null:
		return boss

	for node in get_tree().get_nodes_in_group("enemy"):
		if node is SlimeBoss:
			return node

	return null


func _on_slime_boss_detected_player() -> void:
	start_slime_boss_music()


func _on_slime_boss_died(_death_position: Vector2 = Vector2.ZERO) -> void:
	stop_slime_boss_music(true)


func start_slime_boss_music() -> void:
	print("map_6: start_slime_boss_music() được gọi.")

	if has_started_slime_boss_music:
		print("map_6: Nhạc SlimeBoss đã bật rồi.")
		return

	if slime_boss_music == null:
		push_warning("map_6: Chưa có node AudioStreamPlayer tên SlimeBossMusic.")
		return

	if slime_boss_music.stream == null:
		push_warning("map_6: SlimeBossMusic chưa được gán file nhạc.")
		return

	print("map_6: Bắt đầu phát SlimeBossMusic.")

	has_started_slime_boss_music = true

	if slime_boss_music_tween != null:
		slime_boss_music_tween.kill()

	if MusicManager.has_method("fade_out"):
		MusicManager.fade_out(0.8, false)

	slime_boss_music.volume_db = slime_boss_music_muted_db
	slime_boss_music.play()

	slime_boss_music_tween = create_tween()
	slime_boss_music_tween.tween_property(
		slime_boss_music,
		"volume_db",
		slime_boss_music_volume_db,
		slime_boss_music_fade_time
	)


func stop_slime_boss_music(restore_normal_bgm: bool = true) -> void:
	has_started_slime_boss_music = false

	if slime_boss_music == null:
		return

	if slime_boss_music_tween != null:
		slime_boss_music_tween.kill()

	if !slime_boss_music.playing:
		if restore_normal_bgm and MusicManager.has_method("fade_in"):
			MusicManager.fade_in(1.0)
		return

	slime_boss_music_tween = create_tween()
	slime_boss_music_tween.tween_property(
		slime_boss_music,
		"volume_db",
		slime_boss_music_muted_db,
		slime_boss_music_fade_time
	)

	await slime_boss_music_tween.finished

	if slime_boss_music != null:
		slime_boss_music.stop()

	if restore_normal_bgm and MusicManager.has_method("fade_in"):
		MusicManager.fade_in(1.0)


func stop_slime_boss_music_immediate() -> void:
	has_started_slime_boss_music = false

	if slime_boss_music_tween != null:
		slime_boss_music_tween.kill()

	if slime_boss_music != null:
		slime_boss_music.stop()
		slime_boss_music.volume_db = slime_boss_music_muted_db


func _exit_tree() -> void:
	stop_slime_boss_music_immediate()

	if MusicManager.has_method("fade_in"):
		MusicManager.fade_in(0.8)
func _physics_process(_delta: float) -> void:
	check_slime_boss_music_by_state()
func check_slime_boss_music_by_state() -> void:
	if has_started_slime_boss_music:
		return

	if slime_boss_ref == null:
		return

	if !is_instance_valid(slime_boss_ref):
		return

	if has_object_property(slime_boss_ref, "is_dead"):
		if bool(slime_boss_ref.get("is_dead")):
			return

	if has_object_property(slime_boss_ref, "player"):
		var target_player = slime_boss_ref.get("player")

		if target_player != null:
			print("map_6: Phát hiện SlimeBoss đã có target player, bật nhạc.")
			start_slime_boss_music()
			return

	if has_object_property(slime_boss_ref, "current_state"):
		var state_value: int = int(slime_boss_ref.get("current_state"))

		if state_value != 0:
			print("map_6: SlimeBoss không còn IDLE, bật nhạc. State = ", state_value)
			start_slime_boss_music()
			return
func connect_player_death_signals() -> void:
	for p in get_players():
		if p == null:
			continue

		if !is_instance_valid(p):
			continue

		if p.has_signal("died"):
			if !p.died.is_connected(_on_player_died):
				p.died.connect(_on_player_died)
				print("map_6: Đã connect signal died của ", p.name)
		else:
			print("map_6: ", p.name, " không có signal died.")


func _on_player_died() -> void:
	if has_handled_player_death:
		return

	has_handled_player_death = true

	print("map_6: PLAYER DIED SIGNAL RECEIVED")

	set_all_players_control_enabled(false)

	await get_tree().create_timer(1.0).timeout

	if you_died_ui == null:
		you_died_ui = get_node_or_null("YouDiedUI") as CanvasLayer

	if you_died_ui != null and you_died_ui.has_method("show_you_died"):
		you_died_ui.show_you_died()
	else:
		push_warning("map_6: Không tìm thấy YouDiedUI hoặc YouDiedUI thiếu hàm show_you_died().")


func set_all_players_control_enabled(state: bool) -> void:
	for p in get_players():
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

		if !state and p.has_method("stop_hurt_box"):
			p.stop_hurt_box()
