extends CharacterBody2D

@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var interaction_area: Area2D = get_node_or_null("InteractionArea") as Area2D
@onready var interaction_collision: CollisionShape2D = get_node_or_null("InteractionArea/CollisionShape2D") as CollisionShape2D
@onready var talk_indicator: Sprite2D = get_node_or_null("TalkIndicator") as Sprite2D

@export var campfire_id: String = "campfire_map_1"

# Spawn point để player hồi sinh tại campfire này.
# Trong map, bạn tạo node:
# SpawnPoints
# └── CampFireSpawn
@export var respawn_spawn_point_name: String = "CampFireSpawn"

# Map trại chính.
@export_file("*.tscn") var camp_scene_path: String = "res://level/testlevel/map_1/map_1.tscn"
@export var camp_spawn_point_name: String = "FromCampFire"

@export var fade_out_time: float = 0.7
@export var fade_in_time: float = 0.7

var player_near: bool = false
var player: Player = null
var ui_open: bool = false

var ui_layer: CanvasLayer
var root: Control
var panel: Panel
var title_label: Label
var message_label: Label
var confirm_button: Button
var cancel_button: Button
var tween: Tween = null


func _ready() -> void:
	if animation_player != null and animation_player.has_animation("campfire"):
		animation_player.play("campfire")

	if talk_indicator != null:
		talk_indicator.visible = false
		talk_indicator.z_index = 100
		talk_indicator.z_as_relative = false

	if interaction_area != null:
		if not interaction_area.body_entered.is_connected(_on_interaction_body_entered):
			interaction_area.body_entered.connect(_on_interaction_body_entered)

		if not interaction_area.body_exited.is_connected(_on_interaction_body_exited):
			interaction_area.body_exited.connect(_on_interaction_body_exited)

		if not interaction_area.area_entered.is_connected(_on_interaction_area_entered):
			interaction_area.area_entered.connect(_on_interaction_area_entered)

		if not interaction_area.area_exited.is_connected(_on_interaction_area_exited):
			interaction_area.area_exited.connect(_on_interaction_area_exited)
	else:
		push_warning(name + " thiếu InteractionArea.")

	create_ui()


func _process(_delta: float) -> void:
	if ui_open:
		return

	if not player_near:
		return

	if Input.is_action_just_pressed("interact"):
		open_campfire_menu()


func create_ui() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.name = "CampFireSaveUI"
	ui_layer.layer = 1300
	add_child(ui_layer)

	root = Control.new()
	root.name = "Root"
	ui_layer.add_child(root)

	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 0
	root.offset_top = 0
	root.offset_right = 0
	root.offset_bottom = 0
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.modulate.a = 0.0
	root.visible = false

	var dark_bg := ColorRect.new()
	dark_bg.name = "DarkBackground"
	root.add_child(dark_bg)
	dark_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	dark_bg.color = Color(0, 0, 0, 0.18)
	dark_bg.mouse_filter = Control.MOUSE_FILTER_STOP

	panel = Panel.new()
	panel.name = "Panel"
	root.add_child(panel)

	# Nhỏ hơn bản cũ rất nhiều
	panel.size = Vector2(240, 88)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.055, 0.035, 0.92)
	style.border_color = Color(1.0, 0.58, 0.20, 1.0)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	panel.add_theme_stylebox_override("panel", style)

	title_label = Label.new()
	title_label.name = "TitleLabel"
	panel.add_child(title_label)

	title_label.text = "LỬA TRẠI"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 11)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.32))
	title_label.position = Vector2(12, 5)
	title_label.size = Vector2(216, 16)

	message_label = Label.new()
	message_label.name = "MessageLabel"
	panel.add_child(message_label)

	message_label.text = ""
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.add_theme_font_size_override("font_size", 8)
	message_label.add_theme_color_override("font_color", Color.WHITE)
	message_label.position = Vector2(16, 25)
	message_label.size = Vector2(208, 22)

	confirm_button = Button.new()
	confirm_button.name = "ConfirmButton"
	panel.add_child(confirm_button)

	confirm_button.position = Vector2(36, 58)
	confirm_button.size = Vector2(70, 20)
	confirm_button.add_theme_font_size_override("font_size", 8)
	confirm_button.pressed.connect(_on_confirm_pressed)

	cancel_button = Button.new()
	cancel_button.name = "CancelButton"
	panel.add_child(cancel_button)

	cancel_button.position = Vector2(134, 58)
	cancel_button.size = Vector2(70, 20)
	cancel_button.add_theme_font_size_override("font_size", 8)
	cancel_button.pressed.connect(_on_cancel_pressed)

	center_panel()

func center_panel() -> void:
	if panel == null:
		return

	var viewport_size := get_viewport().get_visible_rect().size

	panel.position = Vector2(
		(viewport_size.x - panel.size.x) * 0.5,
		viewport_size.y - panel.size.y - 6
	)


func open_campfire_menu() -> void:
	if player == null:
		player = PlayerManager.player

	ui_open = true

	if player != null:
		player.set_control_enabled(false)

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	center_panel()

	root.visible = true
	root.modulate.a = 0.0

	if LevelManager.has_saved_campfire(campfire_id):
		title_label.text = "LỬA TRẠI"
		message_label.text = "Dịch chuyển về trại chính?"
		confirm_button.text = "Đi"
		cancel_button.text = "Đóng"
	else:
		title_label.text = "LƯU HỒI SINH"
		message_label.text = "Đặt lửa trại này làm điểm hồi sinh?"
		confirm_button.text = "Có"
		cancel_button.text = "Không"

	if tween != null:
		tween.kill()

	tween = create_tween()
	tween.tween_property(root, "modulate:a", 1.0, 0.2)


func close_campfire_menu() -> void:
	if tween != null:
		tween.kill()

	tween = create_tween()
	tween.tween_property(root, "modulate:a", 0.0, 0.18)

	await tween.finished

	root.visible = false
	ui_open = false

	if player != null:
		player.set_control_enabled(true)

	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)


func _on_confirm_pressed() -> void:
	if LevelManager.has_saved_campfire(campfire_id):
		await teleport_to_camp()
	else:
		save_this_campfire()


func _on_cancel_pressed() -> void:
	await close_campfire_menu()


func save_this_campfire() -> void:
	var current_scene_path: String = ""

	if get_tree().current_scene != null:
		current_scene_path = get_tree().current_scene.scene_file_path

	if current_scene_path == "":
		push_warning("Không lấy được scene hiện tại để lưu điểm hồi sinh.")
		return

	LevelManager.save_campfire_respawn(
		campfire_id,
		current_scene_path,
		respawn_spawn_point_name
	)

	title_label.text = "ĐÃ LƯU"
	message_label.text = "Điểm hồi sinh đã được cập nhật."
	confirm_button.text = "Đóng"
	cancel_button.visible = false

	if confirm_button.pressed.is_connected(_on_confirm_pressed):
		confirm_button.pressed.disconnect(_on_confirm_pressed)

	confirm_button.pressed.connect(_on_saved_close_pressed, CONNECT_ONE_SHOT)


func _on_saved_close_pressed() -> void:
	cancel_button.visible = true

	if not confirm_button.pressed.is_connected(_on_confirm_pressed):
		confirm_button.pressed.connect(_on_confirm_pressed)

	await close_campfire_menu()


func teleport_to_camp() -> void:
	if camp_scene_path == "":
		message_label.text = "Chưa gán map trại."
		return

	if camp_spawn_point_name != "":
		LevelManager.set_next_spawn_point(camp_spawn_point_name)

	await close_campfire_menu()

	await SceneTransition.change_scene_with_fade(
		camp_scene_path,
		fade_out_time,
		fade_in_time
	)


func _on_interaction_body_entered(body: Node2D) -> void:
	try_set_player_near(body)


func _on_interaction_body_exited(body: Node2D) -> void:
	try_remove_player_near(body)


func _on_interaction_area_entered(area: Area2D) -> void:
	try_set_player_near(area)

	if area.get_parent() != null:
		try_set_player_near(area.get_parent())


func _on_interaction_area_exited(area: Area2D) -> void:
	try_remove_player_near(area)

	if area.get_parent() != null:
		try_remove_player_near(area.get_parent())


func try_set_player_near(target: Node) -> void:
	var detected_player := find_player_from_node(target)

	if detected_player == null:
		return

	player_near = true
	player = detected_player

	if talk_indicator != null:
		talk_indicator.visible = true


func try_remove_player_near(target: Node) -> void:
	var detected_player := find_player_from_node(target)

	if detected_player == null:
		return

	if detected_player != player:
		return

	player_near = false
	player = null

	if talk_indicator != null:
		talk_indicator.visible = false


func find_player_from_node(node: Node) -> Player:
	var current := node

	while current != null:
		if current is Player:
			return current as Player

		if current.is_in_group("player"):
			return current as Player

		if current.is_in_group("Player"):
			return current as Player

		if current.name == "Player":
			return current as Player

		current = current.get_parent()

	if PlayerManager.player != null and PlayerManager.player is Player:
		return PlayerManager.player as Player

	return null


func _exit_tree() -> void:
	if ui_open:
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
