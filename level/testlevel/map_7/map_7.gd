extends Node2D

@onready var boss_health_bar: Node = get_node_or_null("BossHealthBar")
@onready var you_died_ui: CanvasLayer = get_node_or_null("YouDiedUI") as CanvasLayer
@onready var rescue_npcs: Node2D = get_node_or_null("RescueNPCs") as Node2D

@export var player_portrait: Texture2D

@export var map_7_intro_flag_name: String = "has_seen_map_7_intro"
@export var map_7_boss_defeated_flag_name: String = "map_7_enemy_killed"
@export var camp_called_flag_name: String = "map_7_has_called_camp"
@export var mission_final_dialog_flag_name: String = "map_7_mission_final_dialog_unlocked"

@export var play_intro_only_once: bool = true
@export var intro_start_delay: float = 3.0

@export var main_tilemap_path: NodePath = NodePath("World/TileMapLayer")
@export var auto_extend_bounds_to_important_points: bool = true
@export var extra_bound_margin: float = 300.0
@export var portal_node_path: NodePath = NodePath("World/Portal")
@export var exit_node_path: NodePath = NodePath("ExitToMap6")

@export var final_mission_npc_path: NodePath = NodePath("RescueNPCs/NPC-Mission")

# Nếu map_7 có SpawnPoints/FromMap6 thì 2 player sẽ đứng lệch nhau quanh spawn này.
@export var coop_spawn_offset_x: float = 22.0

var player: Player = null
var boss: Node = null
var story_dialog: Node = null
var main_tilemap: TileMapLayer = null
var final_mission_npc: Node = null
var final_mission_talk_area: Area2D = null

var players_near_final_mission: Dictionary = {}

var has_handled_player_death: bool = false
var is_intro_running: bool = false
var has_started_intro: bool = false
var player_near_final_mission: bool = false
var is_final_mission_talking: bool = false


func _ready() -> void:
	MusicManager.play_game_bgm(1.5)
	print("map_7 ready")

	find_player()
	find_story_dialog()
	find_final_mission_npc()

	if should_play_intro():
		print("map_7: Khóa toàn bộ player ngay khi vào map.")
		is_intro_running = true
		force_lock_players()

	await get_tree().process_frame
	await get_tree().process_frame

	find_player()
	find_story_dialog()
	find_boss()
	find_final_mission_npc()

	await apply_player_spawn_point()

	if is_intro_running:
		force_lock_players()

	setup_map_bounds()
	extend_player_bounds_for_map7()

	connect_player_signals()
	connect_boss_signals()
	setup_boss_health_bar()
	setup_rescue_npcs()

	await run_intro_flow()


func _physics_process(_delta: float) -> void:
	if is_intro_running:
		force_lock_players()


func _unhandled_input(event: InputEvent) -> void:
	if is_intro_running:
		return

	if is_final_mission_talking:
		return

	if !player_near_final_mission:
		return

	if !LevelManager.get_game_flag(mission_final_dialog_flag_name):
		return

	var action_player := get_player_pressed_interact_event(event)

	if action_player == null:
		return

	player = action_player
	get_viewport().set_input_as_handled()

	await start_final_mission_dialog(action_player)


# =========================
# SPAWN POINT
# =========================

func apply_player_spawn_point() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

	var spawn_name: String = LevelManager.get_next_spawn_point()

	if spawn_name == "":
		return

	var spawn_point := find_spawn_point(spawn_name)

	if spawn_point == null:
		push_warning("map_7: Không tìm thấy spawn point: " + spawn_name)
		LevelManager.clear_next_spawn_point()
		return

	if is_two_player_mode():
		for p in get_players():
			if p == null:
				continue

			if !is_instance_valid(p):
				continue

			var offset_x: float = 0.0
			var player_id_value: int = get_player_id(p)

			if player_id_value == 1:
				offset_x = -coop_spawn_offset_x
			else:
				offset_x = coop_spawn_offset_x

			p.global_position = spawn_point.global_position + Vector2(offset_x, 0.0)
			p.velocity = Vector2.ZERO

			if p.has_method("set_control_enabled"):
				p.set_control_enabled(!is_intro_running)

			if p.has_method("reset_physics_interpolation"):
				p.reset_physics_interpolation()

			print("map_7: Đã đưa ", p.name, " tới spawn point: ", spawn_name, " tại ", p.global_position)
	else:
		if PlayerManager.player != null:
			PlayerManager.player.global_position = spawn_point.global_position
			PlayerManager.player.velocity = Vector2.ZERO

			if PlayerManager.player.has_method("set_control_enabled"):
				PlayerManager.player.set_control_enabled(!is_intro_running)

			if PlayerManager.player.has_method("reset_physics_interpolation"):
				PlayerManager.player.reset_physics_interpolation()

			print("map_7: Đã đưa Player tới spawn point: ", spawn_name, " tại ", spawn_point.global_position)

	LevelManager.clear_next_spawn_point()
	snap_shared_camera_to_players()


func find_spawn_point(spawn_name: String) -> Node2D:
	var spawn_point := get_node_or_null("SpawnPoints/" + spawn_name) as Node2D

	if spawn_point != null:
		return spawn_point

	spawn_point = get_node_or_null("World/SpawnPoints/" + spawn_name) as Node2D

	if spawn_point != null:
		return spawn_point

	var found_node := find_node_by_name_recursive(self, spawn_name)

	if found_node is Node2D:
		return found_node as Node2D

	return null


func snap_shared_camera_to_players() -> void:
	var shared_camera := get_node_or_null("SharedCamera")

	if shared_camera == null:
		shared_camera = get_node_or_null("World/SharedCamera")

	if shared_camera != null and shared_camera.has_method("force_snap_to_players"):
		shared_camera.force_snap_to_players()


# =========================
# MAP BOUNDS
# =========================

func setup_map_bounds() -> void:
	main_tilemap = null

	if main_tilemap_path != NodePath(""):
		main_tilemap = get_node_or_null(main_tilemap_path) as TileMapLayer

	if main_tilemap == null:
		main_tilemap = get_node_or_null("World/TileMapLayer") as TileMapLayer

	if main_tilemap == null:
		main_tilemap = get_node_or_null("TileMapLayer") as TileMapLayer

	if main_tilemap == null:
		print("map_7: Không tìm thấy TileMapLayer chính, bỏ qua cập nhật giới hạn map.")
		return

	if LevelManager.has_method("update_tilemap_bounds"):
		LevelManager.update_tilemap_bounds(main_tilemap)
		print("map_7: Đã cập nhật giới hạn map theo ", main_tilemap.name)

		if LevelManager.has_method("get_left_limit") and LevelManager.has_method("get_right_limit"):
			print("map_7 bounds: ", LevelManager.get_left_limit(), " -> ", LevelManager.get_right_limit())

		return

	print("map_7: LevelManager chưa có update_tilemap_bounds(), giữ nguyên bounds hiện tại.")

func extend_player_bounds_for_map7() -> void:
	if !auto_extend_bounds_to_important_points:
		return

	if !LevelManager.has_bounds():
		return

	for p in get_players():
		if p == null:
			continue

		if !is_instance_valid(p):
			continue

		extend_specific_player_bounds_to_include_position(p, p.global_position)
		include_node_in_specific_player_bounds(p, portal_node_path)
		include_node_in_specific_player_bounds(p, exit_node_path)
		include_node_in_specific_player_bounds(p, NodePath("SpawnPoints/FromMap6"))


func include_node_in_specific_player_bounds(target_player: Player, node_path: NodePath) -> void:
	if node_path == NodePath(""):
		return

	var node := get_node_or_null(node_path) as Node2D

	if node == null:
		node = get_node_or_null("World/" + String(node_path)) as Node2D

	if node == null:
		return

	extend_specific_player_bounds_to_include_position(target_player, node.global_position)


func extend_specific_player_bounds_to_include_position(target_player: Player, position_to_include: Vector2) -> void:
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

	if position_to_include.x > current_right_limit:
		var extra_right: float = position_to_include.x - current_right_limit + extra_bound_margin
		set_object_float_property(target_player, "right_map_padding", right_padding - extra_right)
		print("map_7: Nới biên phải cho ", target_player.name, " thêm ", extra_right)

	if position_to_include.x < current_left_limit:
		var extra_left: float = current_left_limit - position_to_include.x + extra_bound_margin
		set_object_float_property(target_player, "left_map_padding", left_padding - extra_left)
		print("map_7: Nới biên trái cho ", target_player.name, " thêm ", extra_left)


# =========================
# FIND NODES
# =========================

func find_player() -> void:
	player = get_node_or_null("Player") as Player

	if player == null:
		player = get_node_or_null("World/Player") as Player

	if player == null:
		player = get_player_by_id(1)

	if player == null:
		player = PlayerManager.player

	if player == null:
		push_error("map_7: Không tìm thấy Player. Kiểm tra node Player trong scene.")
		return

	print("map_7: Player found: ", player.name)


func find_boss() -> void:
	boss = get_node_or_null("Enemy")

	if boss == null:
		boss = get_node_or_null("World/Enemy")

	if boss == null:
		push_warning("map_7: Không tìm thấy Enemy/Boss.")
		return

	print("map_7: Boss found: ", boss.name)


func find_story_dialog() -> void:
	story_dialog = get_node_or_null("StoryDialog")

	if story_dialog == null:
		story_dialog = get_node_or_null("World/StoryDialog")

	if story_dialog == null:
		push_warning("map_7: Không tìm thấy StoryDialog.")


func find_final_mission_npc() -> void:
	final_mission_npc = null

	if final_mission_npc_path != NodePath(""):
		final_mission_npc = get_node_or_null(final_mission_npc_path)

	if final_mission_npc == null and rescue_npcs != null:
		final_mission_npc = rescue_npcs.get_node_or_null("NPC-Mission")

	if final_mission_npc == null:
		return

	final_mission_talk_area = find_first_area_by_names(
		final_mission_npc,
		[
			"TalkArea",
			"InteractionArea",
			"Area2D"
		]
	)

	if final_mission_talk_area != null:
		if not final_mission_talk_area.body_entered.is_connected(_on_final_mission_body_entered):
			final_mission_talk_area.body_entered.connect(_on_final_mission_body_entered)

		if not final_mission_talk_area.body_exited.is_connected(_on_final_mission_body_exited):
			final_mission_talk_area.body_exited.connect(_on_final_mission_body_exited)

		if not final_mission_talk_area.area_entered.is_connected(_on_final_mission_area_entered):
			final_mission_talk_area.area_entered.connect(_on_final_mission_area_entered)

		if not final_mission_talk_area.area_exited.is_connected(_on_final_mission_area_exited):
			final_mission_talk_area.area_exited.connect(_on_final_mission_area_exited)


# =========================
# INTRO
# =========================

func should_play_intro() -> bool:
	if play_intro_only_once and LevelManager.get_game_flag(map_7_intro_flag_name):
		return false

	return true


func run_intro_flow() -> void:
	if player == null:
		find_player()

	if player == null:
		return

	if has_started_intro:
		return

	has_started_intro = true

	var has_seen_intro: bool = LevelManager.get_game_flag(map_7_intro_flag_name)

	print("map_7 intro flag: ", map_7_intro_flag_name, " = ", has_seen_intro)

	if play_intro_only_once and has_seen_intro:
		print("map_7: Đã xem intro rồi, bỏ qua hội thoại.")
		unlock_players()
		return

	LevelManager.set_game_flag(map_7_intro_flag_name, true)

	print("map_7: Khóa toàn bộ Player và đợi ", intro_start_delay, " giây trước khi bắt đầu hội thoại.")

	is_intro_running = true
	force_lock_players()

	await get_tree().create_timer(intro_start_delay).timeout

	force_lock_players()

	if story_dialog == null:
		find_story_dialog()

	if story_dialog == null:
		push_warning("map_7: Không tìm thấy StoryDialog. Hãy thêm node StoryDialog vào map_7.")
		finish_intro_without_dialog()
		return

	if not story_dialog.has_method("start_story"):
		push_warning("map_7: StoryDialog không có hàm start_story().")
		finish_intro_without_dialog()
		return

	if story_dialog is CanvasLayer:
		story_dialog.visible = true
	elif story_dialog is Control:
		story_dialog.visible = true

	var intro_dialog: Array = [
		{
			"speaker": "player",
			"portrait": player_portrait,
			"text": "Cuối cùng thì mình cũng quay lại nơi này."
		},
		{
			"speaker": "player",
			"portrait": player_portrait,
			"text": "Lần này, mình sẽ kết thúc tất cả và đưa mọi người rời khỏi đây."
		}
	]

	if story_dialog.has_signal("story_finished"):
		if not story_dialog.story_finished.is_connected(_on_intro_story_finished):
			story_dialog.story_finished.connect(_on_intro_story_finished, CONNECT_ONE_SHOT)

	story_dialog.start_story(intro_dialog)


func force_lock_players() -> void:
	set_all_players_control_enabled(false)


func unlock_players() -> void:
	is_intro_running = false
	set_all_players_control_enabled(true)


func finish_intro_without_dialog() -> void:
	print("map_7: Không chạy được hội thoại, mở khóa Player.")
	unlock_players()


func _on_intro_story_finished() -> void:
	print("map_7: Hội thoại intro kết thúc.")
	unlock_players()


# =========================
# RESCUE NPCS
# =========================

func setup_rescue_npcs() -> void:
	if rescue_npcs == null:
		push_warning("map_7: Không tìm thấy node RescueNPCs.")
		return

	var should_show_npcs: bool = LevelManager.get_game_flag(camp_called_flag_name)

	set_rescue_npcs_active(should_show_npcs)

	if should_show_npcs:
		LevelManager.set_game_flag(mission_final_dialog_flag_name, true)


func reveal_rescue_npcs() -> void:
	if rescue_npcs == null:
		push_warning("map_7: Không tìm thấy node RescueNPCs để hiện NPC.")
		return

	LevelManager.set_game_flag(camp_called_flag_name, true)
	LevelManager.set_game_flag(mission_final_dialog_flag_name, true)

	set_rescue_npcs_active(true)


func set_rescue_npcs_active(state: bool) -> void:
	if rescue_npcs == null:
		return

	rescue_npcs.visible = state
	player_near_final_mission = false
	players_near_final_mission.clear()

	for child in rescue_npcs.get_children():
		disable_all_interaction_recursive(child)

	if !state:
		return

	find_final_mission_npc()
	disable_original_npc_input_scripts()
	enable_final_mission_talk_area()


func disable_original_npc_input_scripts() -> void:
	if rescue_npcs == null:
		return

	for child in rescue_npcs.get_children():
		child.set_process_input(false)
		child.set_process_unhandled_input(false)

		if has_object_property(child, "player_in_range"):
			child.set("player_in_range", false)

		if has_object_property(child, "player_near"):
			child.set("player_near", false)

		if has_object_property(child, "is_talking"):
			child.set("is_talking", false)


func disable_all_interaction_recursive(node: Node) -> void:
	if node is Area2D:
		node.monitoring = false
		node.monitorable = false

	if node is CollisionShape2D:
		node.disabled = true

	if node is CollisionPolygon2D:
		node.disabled = true

	for child in node.get_children():
		disable_all_interaction_recursive(child)


func enable_final_mission_talk_area() -> void:
	if final_mission_talk_area == null:
		find_final_mission_npc()

	if final_mission_talk_area == null:
		push_warning("map_7: Không tìm thấy TalkArea/InteractionArea của NPC-Mission.")
		return

	final_mission_talk_area.monitoring = true
	final_mission_talk_area.monitorable = true

	for child in final_mission_talk_area.get_children():
		if child is CollisionShape2D:
			child.disabled = false

		if child is CollisionPolygon2D:
			child.disabled = false

	var indicator := find_child_by_name(final_mission_npc, "TalkIndicator")

	if indicator != null and indicator is CanvasItem:
		(indicator as CanvasItem).visible = false


# =========================
# FINAL NPC-MISSION DIALOG
# =========================

func _on_final_mission_body_entered(body: Node2D) -> void:
	try_set_player_near_final_mission(body)


func _on_final_mission_body_exited(body: Node2D) -> void:
	try_remove_player_near_final_mission(body)


func _on_final_mission_area_entered(area: Area2D) -> void:
	try_set_player_near_final_mission(area)

	if area.get_parent() != null:
		try_set_player_near_final_mission(area.get_parent())


func _on_final_mission_area_exited(area: Area2D) -> void:
	try_remove_player_near_final_mission(area)

	if area.get_parent() != null:
		try_remove_player_near_final_mission(area.get_parent())


func try_set_player_near_final_mission(target: Node) -> void:
	var detected_player := find_player_from_node(target)

	if detected_player == null:
		return

	players_near_final_mission[detected_player.get_instance_id()] = detected_player
	player = detected_player
	player_near_final_mission = !players_near_final_mission.is_empty()

	update_final_mission_indicator()


func try_remove_player_near_final_mission(target: Node) -> void:
	var detected_player := find_player_from_node(target)

	if detected_player == null:
		return

	var id: int = detected_player.get_instance_id()

	if players_near_final_mission.has(id):
		players_near_final_mission.erase(id)

	player_near_final_mission = !players_near_final_mission.is_empty()

	if player == detected_player:
		player = get_any_player_near_final_mission()

	update_final_mission_indicator()


func get_any_player_near_final_mission() -> Player:
	for key in players_near_final_mission.keys():
		var p := players_near_final_mission[key] as Player

		if p != null and is_instance_valid(p):
			return p

	return null


func update_final_mission_indicator() -> void:
	var indicator := find_child_by_name(final_mission_npc, "TalkIndicator")

	if indicator != null and indicator is CanvasItem:
		(indicator as CanvasItem).visible = player_near_final_mission


func start_final_mission_dialog(action_player: Player = null) -> void:
	if story_dialog == null:
		find_story_dialog()

	if story_dialog == null:
		return

	if not story_dialog.has_method("start_story"):
		return

	if action_player != null:
		player = action_player

	is_final_mission_talking = true
	set_player_control_for_dialog(false)

	var final_dialog: Array = [
		{
			"speaker": "npc",
			"text": "Cảm ơn cậu. Nhờ cậu, tên trùm Sừng Vàng đã bị đánh bại."
		},
		{
			"speaker": "npc",
			"text": "Cuối cùng, chúng ta cũng có cơ hội rời khỏi nơi địa ngục này."
		},
		{
			"speaker": "npc",
			"text": "Nào, hãy cùng nhau rời khỏi đây."
		}
	]

	story_dialog.start_story(final_dialog)

	if story_dialog.has_signal("story_finished"):
		await story_dialog.story_finished

	is_final_mission_talking = false
	set_player_control_for_dialog(true)


func set_player_control_for_dialog(state: bool) -> void:
	set_all_players_control_enabled(state)


# =========================
# SIGNALS
# =========================

func connect_player_signals() -> void:
	for p in get_players():
		if p == null:
			continue

		if !is_instance_valid(p):
			continue

		if p.has_signal("died"):
			if !p.died.is_connected(_on_player_died):
				p.died.connect(_on_player_died)


func connect_boss_signals() -> void:
	if boss == null:
		return

	if boss.has_signal("boss_started"):
		if not boss.boss_started.is_connected(_on_boss_started):
			boss.boss_started.connect(_on_boss_started)

	if boss.has_signal("health_changed"):
		if not boss.health_changed.is_connected(_on_boss_health_changed):
			boss.health_changed.connect(_on_boss_health_changed)

	if boss.has_signal("died"):
		if not boss.died.is_connected(_on_boss_died):
			boss.died.connect(_on_boss_died)

	if boss.has_signal("enemy_died"):
		if not boss.enemy_died.is_connected(_on_boss_enemy_died):
			boss.enemy_died.connect(_on_boss_enemy_died)


# =========================
# BOSS BAR
# =========================

func setup_boss_health_bar() -> void:
	if boss == null:
		return

	if boss_health_bar == null:
		return

	var max_health_value: int = get_boss_int_property("max_health", 1)
	var current_health_value: int = get_boss_int_property("current_health", max_health_value)

	if boss_health_bar.has_method("setup"):
		boss_health_bar.setup(max_health_value)

	if boss_health_bar.has_method("update_health"):
		boss_health_bar.update_health(current_health_value, max_health_value)


func _on_boss_started() -> void:
	print("map_7: Boss started")

	if boss_health_bar != null and boss_health_bar.has_method("show_bar"):
		boss_health_bar.show_bar()

	MusicManager.play_boss_music()


func _on_boss_health_changed(current_health: int, max_health: int) -> void:
	print("map_7 Boss HP: ", current_health, "/", max_health)

	if boss_health_bar != null and boss_health_bar.has_method("update_health"):
		boss_health_bar.update_health(current_health, max_health)


func _on_boss_died() -> void:
	handle_boss_died()


func _on_boss_enemy_died(_death_position: Vector2 = Vector2.ZERO) -> void:
	handle_boss_died()


func handle_boss_died() -> void:
	print("map_7: Boss died")

	LevelManager.set_game_flag(map_7_boss_defeated_flag_name, true)

	if boss_health_bar != null and boss_health_bar.has_method("hide_bar"):
		boss_health_bar.hide_bar()

	MusicManager.stop_boss_music()


# =========================
# PLAYER DEATH
# =========================

func _on_player_died() -> void:
	if has_handled_player_death:
		return

	has_handled_player_death = true

	print("map_7: PLAYER DIED SIGNAL RECEIVED")

	set_all_players_control_enabled(false)

	await get_tree().create_timer(1.0).timeout

	if you_died_ui != null and you_died_ui.has_method("show_you_died"):
		you_died_ui.show_you_died()


# =========================
# CO-OP HELPERS
# =========================

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

	var scene := get_tree().current_scene

	if scene != null:
		var player_1_node := scene.get_node_or_null("Player")
		var player_2_node := scene.get_node_or_null("Player2")
		var world_player_1_node := scene.get_node_or_null("World/Player")
		var world_player_2_node := scene.get_node_or_null("World/Player2")

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


func get_player_by_id(target_id: int) -> Player:
	for p in get_players():
		if p == null:
			continue

		if !is_instance_valid(p):
			continue

		if get_player_id(p) == target_id:
			return p

		if target_id == 1 and p.name == "Player":
			return p

		if target_id == 2 and p.name == "Player2":
			return p

	return null


func get_player_id(target_player: Player) -> int:
	if target_player == null:
		return 0

	if has_object_property(target_player, "player_id"):
		return int(target_player.get("player_id"))

	if target_player.name == "Player":
		return 1

	if target_player.name == "Player2":
		return 2

	return 0


func get_player_pressed_interact_event(event: InputEvent) -> Player:
	for key in players_near_final_mission.keys():
		var p := players_near_final_mission[key] as Player

		if p == null:
			continue

		if !is_instance_valid(p):
			continue

		if p.has_method("is_interact_event_pressed"):
			if p.is_interact_event_pressed(event):
				return p
		else:
			var action_name := get_interact_action_for_player(p)

			if event.is_action_pressed(action_name):
				return p

	return null


func get_interact_action_for_player(target_player: Player) -> StringName:
	if !is_two_player_mode():
		return &"interact"

	var id_value: int = get_player_id(target_player)

	if id_value == 1:
		return &"p1_interact"

	return &"p2_interact"


func set_all_players_control_enabled(state: bool) -> void:
	if is_two_player_mode():
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

		return

	if player == null:
		player = PlayerManager.player

	if player == null:
		return

	if player.has_method("set_control_enabled"):
		player.set_control_enabled(state)

	if has_object_property(player, "can_control"):
		player.set("can_control", state)


func is_two_player_mode() -> bool:
	var game_mode := get_node_or_null("/root/GameMode")

	if game_mode == null:
		return false

	return game_mode.is_two_players()


# =========================
# GENERAL HELPERS
# =========================

func get_boss_int_property(property_name: String, default_value: int) -> int:
	if boss == null:
		return default_value

	var value = boss.get(property_name)

	if value == null:
		return default_value

	return int(value)


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

	if not has_object_property(obj, prop_name):
		return default_value

	return float(obj.get(prop_name))


func set_object_float_property(obj: Object, prop_name: String, value: float) -> void:
	if obj == null:
		return

	if not has_object_property(obj, prop_name):
		return

	obj.set(prop_name, value)


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


func find_first_area_by_names(root: Node, names: Array[String]) -> Area2D:
	if root == null:
		return null

	for target_name in names:
		var direct := root.get_node_or_null(target_name)

		if direct != null and direct is Area2D:
			return direct as Area2D

	for child in root.get_children():
		if child is Area2D:
			return child as Area2D

		var found := find_first_area_by_names(child, names)

		if found != null:
			return found

	return null


func find_child_by_name(root: Node, target_name: String) -> Node:
	if root == null:
		return null

	if root.name == target_name:
		return root

	for child in root.get_children():
		var found := find_child_by_name(child, target_name)

		if found != null:
			return found

	return null


func find_node_by_name_recursive(parent: Node, target_name: String) -> Node:
	if parent.name == target_name:
		return parent

	for child in parent.get_children():
		var found := find_node_by_name_recursive(child, target_name)

		if found != null:
			return found

	return null
