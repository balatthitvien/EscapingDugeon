extends Node2D

enum ConfirmMode {
	CALL_CAMP,
	LEAVE_AREA
}

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D
@onready var animation_player: AnimationPlayer = get_node_or_null("AnimationPlayer") as AnimationPlayer
@onready var interaction_area: Area2D = get_node_or_null("InteractionArea") as Area2D
@onready var talk_indicator: Node2D = get_node_or_null("TalkIndicator") as Node2D

@export var portal_animation_name: String = "Portal"
@export var interact_action: String = "interact"

@export var required_boss_flag: String = "map_7_enemy_killed"
@export var camp_called_flag: String = "map_7_has_called_camp"

@export var locked_message: String = "Bạn phải đánh bại tên trùm mới có thể rời khỏi đây."
@export var question_message: String = "Bạn có muốn gọi cho mọi người ở trại không?"
@export var leave_message: String = "Bạn đã sẵn sàng rời khỏi đây chưa?"

@export_file("*.tscn") var main_menu_scene_path: String = "res://MainMenu/main_menu.tscn"

@export var message_font_size: int = 16

# 2 người chơi phải cùng đứng trong InteractionArea của portal.
@export var coop_required_player_distance: float = 180.0
@export var coop_required_message: String = "Cả hai cần đứng gần cổng để tiếp tục.\nĐừng bỏ lại đồng đội của mình."

# Hiệu ứng gọi NPC
@export var call_fade_out_time: float = 1.0
@export var call_black_hold_time: float = 0.35
@export var call_fade_in_time: float = 1.0

# Hiệu ứng kết thúc
@export var final_light_fade_time: float = 5.0
@export var final_black_wait_time: float = 0.9
@export var audio_fade_out_time: float = 5.0
@export var final_master_volume_db: float = -35.0

@export var slam_sound: AudioStream

var player_in_range: bool = false
var player: Player = null
var players_near: Dictionary = {}

var is_busy: bool = false
var confirm_mode: int = ConfirmMode.CALL_CAMP

var master_bus_index: int = -1
var original_master_volume_db: float = 0.0

var message_layer: CanvasLayer
var message_label: Label
var message_tween: Tween = null

var confirm_layer: CanvasLayer
var confirm_root: Control
var confirm_panel: Panel
var confirm_title_label: Label
var confirm_message_label: RichTextLabel
var yes_button: Button
var no_button: Button
var confirm_tween: Tween = null

var effect_layer: CanvasLayer
var effect_root: Control
var black_rect: ColorRect
var white_rect: ColorRect
var slam_player: AudioStreamPlayer

var is_final_changing_scene: bool = false
var has_submitted_clear_score: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	master_bus_index = AudioServer.get_bus_index("Master")
	if master_bus_index >= 0:
		original_master_volume_db = AudioServer.get_bus_volume_db(master_bus_index)

	if animation_player != null and animation_player.has_animation(portal_animation_name):
		animation_player.play(portal_animation_name)

	if talk_indicator != null:
		talk_indicator.visible = false
		talk_indicator.z_index = 100
		talk_indicator.z_as_relative = false

	setup_interaction_area()
	create_message_ui()
	create_confirm_ui()
	create_effect_ui()


func setup_interaction_area() -> void:
	if interaction_area == null:
		push_error("Map7Portal: Không tìm thấy InteractionArea.")
		return

	interaction_area.monitoring = true
	interaction_area.monitorable = true

	if not interaction_area.body_entered.is_connected(_on_body_entered):
		interaction_area.body_entered.connect(_on_body_entered)

	if not interaction_area.body_exited.is_connected(_on_body_exited):
		interaction_area.body_exited.connect(_on_body_exited)

	if not interaction_area.area_entered.is_connected(_on_area_entered):
		interaction_area.area_entered.connect(_on_area_entered)

	if not interaction_area.area_exited.is_connected(_on_area_exited):
		interaction_area.area_exited.connect(_on_area_exited)


func _unhandled_input(event: InputEvent) -> void:
	if !player_in_range:
		return

	if is_busy:
		return

	var action_player := get_player_pressed_interact_event(event)

	if action_player == null:
		return

	player = action_player
	get_viewport().set_input_as_handled()

	try_use_portal(action_player)


func try_use_portal(action_player: Player = null) -> void:
	if action_player != null:
		player = action_player

	if is_two_player_mode():
		if !can_use_portal_as_team():
			show_bottom_message(coop_required_message)
			return

	if !LevelManager.get_game_flag(required_boss_flag):
		show_bottom_message(locked_message)
		return

	if LevelManager.get_game_flag(camp_called_flag):
		show_leave_area_ui()
		return

	show_call_camp_ui()


func _on_body_entered(body: Node2D) -> void:
	try_set_player_in_range(body)


func _on_body_exited(body: Node2D) -> void:
	try_remove_player_from_range(body)


func _on_area_entered(area: Area2D) -> void:
	try_set_player_in_range(area)

	if area.get_parent() != null:
		try_set_player_in_range(area.get_parent())


func _on_area_exited(area: Area2D) -> void:
	try_remove_player_from_range(area)

	if area.get_parent() != null:
		try_remove_player_from_range(area.get_parent())


func try_set_player_in_range(target: Node) -> void:
	var detected_player: Player = find_player_from_node(target)

	if detected_player == null:
		return

	players_near[detected_player.get_instance_id()] = detected_player
	player = detected_player
	player_in_range = !players_near.is_empty()

	update_talk_indicator()

	if !LevelManager.get_game_flag(required_boss_flag):
		show_bottom_message(locked_message)


func try_remove_player_from_range(target: Node) -> void:
	var detected_player: Player = find_player_from_node(target)

	if detected_player == null:
		return

	var id: int = detected_player.get_instance_id()

	if players_near.has(id):
		players_near.erase(id)

	player_in_range = !players_near.is_empty()

	if player == detected_player:
		player = get_any_near_player()

	update_talk_indicator()


func get_any_near_player() -> Player:
	for key in players_near.keys():
		var p := players_near[key] as Player

		if p != null and is_instance_valid(p):
			return p

	return null


func update_talk_indicator() -> void:
	if talk_indicator == null:
		return

	if is_busy:
		talk_indicator.visible = false
		return

	talk_indicator.visible = player_in_range and LevelManager.get_game_flag(required_boss_flag)


func can_use_portal_as_team() -> bool:
	if !is_two_player_mode():
		return true

	var player_1 := get_near_player_by_id(1)
	var player_2 := get_near_player_by_id(2)

	if player_1 == null:
		return false

	if player_2 == null:
		return false

	if !is_instance_valid(player_1):
		return false

	if !is_instance_valid(player_2):
		return false

	var distance_between_players: float = player_1.global_position.distance_to(player_2.global_position)

	if distance_between_players > coop_required_player_distance:
		return false

	return true


func get_near_player_by_id(target_id: int) -> Player:
	for key in players_near.keys():
		var p := players_near[key] as Player

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


func get_player_pressed_interact_event(event: InputEvent) -> Player:
	for key in players_near.keys():
		var p := players_near[key] as Player

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
		return StringName(interact_action)

	var id_value: int = get_player_id(target_player)

	if id_value == 1:
		return &"p1_interact"

	return &"p2_interact"


# =========================
# MESSAGE UI
# =========================

func create_message_ui() -> void:
	message_layer = CanvasLayer.new()
	message_layer.name = "PortalMessageUI"
	message_layer.layer = 1000
	message_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(message_layer)

	message_label = Label.new()
	message_layer.add_child(message_label)

	message_label.visible = false
	message_label.text = ""
	message_label.modulate.a = 0.0

	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	message_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	message_label.offset_left = -260
	message_label.offset_right = 260
	message_label.offset_top = -90
	message_label.offset_bottom = -45

	message_label.add_theme_font_size_override("font_size", message_font_size)
	message_label.add_theme_color_override("font_color", Color.WHITE)
	message_label.add_theme_color_override("font_outline_color", Color.BLACK)
	message_label.add_theme_constant_override("outline_size", 2)


func show_bottom_message(text: String) -> void:
	if message_label == null:
		return

	if message_tween != null:
		message_tween.kill()

	message_label.text = text
	message_label.visible = true
	message_label.modulate.a = 0.0

	message_tween = create_tween()
	message_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	message_tween.tween_property(message_label, "modulate:a", 1.0, 0.2)
	message_tween.tween_interval(1.8)
	message_tween.tween_property(message_label, "modulate:a", 0.0, 0.3)

	await message_tween.finished

	if message_label != null:
		message_label.visible = false


# =========================
# CONFIRM UI
# =========================

func create_confirm_ui() -> void:
	confirm_layer = CanvasLayer.new()
	confirm_layer.name = "Map7PortalConfirmUI"
	confirm_layer.layer = 1300
	confirm_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(confirm_layer)

	confirm_root = Control.new()
	confirm_root.name = "Root"
	confirm_root.process_mode = Node.PROCESS_MODE_ALWAYS
	confirm_layer.add_child(confirm_root)

	confirm_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	confirm_root.offset_left = 0
	confirm_root.offset_top = 0
	confirm_root.offset_right = 0
	confirm_root.offset_bottom = 0
	confirm_root.mouse_filter = Control.MOUSE_FILTER_STOP
	confirm_root.modulate.a = 0.0
	confirm_root.visible = false

	var dark_bg := ColorRect.new()
	dark_bg.name = "DarkBackground"
	confirm_root.add_child(dark_bg)

	dark_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	dark_bg.offset_left = 0
	dark_bg.offset_top = 0
	dark_bg.offset_right = 0
	dark_bg.offset_bottom = 0
	dark_bg.color = Color(0, 0, 0, 0.18)
	dark_bg.mouse_filter = Control.MOUSE_FILTER_STOP

	confirm_panel = Panel.new()
	confirm_panel.name = "Panel"
	confirm_root.add_child(confirm_panel)

	confirm_panel.size = Vector2(330, 118)
	confirm_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.055, 0.035, 0.94)
	panel_style.border_color = Color(1.0, 0.58, 0.20, 1.0)
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.corner_radius_top_left = 6
	panel_style.corner_radius_top_right = 6
	panel_style.corner_radius_bottom_left = 6
	panel_style.corner_radius_bottom_right = 6
	confirm_panel.add_theme_stylebox_override("panel", panel_style)

	confirm_title_label = Label.new()
	confirm_title_label.name = "TitleLabel"
	confirm_panel.add_child(confirm_title_label)

	confirm_title_label.text = "CỔNG DỊCH CHUYỂN"
	confirm_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	confirm_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	confirm_title_label.add_theme_font_size_override("font_size", 14)
	confirm_title_label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.32))
	confirm_title_label.position = Vector2(12, 6)
	confirm_title_label.size = Vector2(306, 22)

	confirm_message_label = RichTextLabel.new()
	confirm_message_label.name = "MessageLabel"
	confirm_panel.add_child(confirm_message_label)

	confirm_message_label.bbcode_enabled = true
	confirm_message_label.text = ""
	confirm_message_label.position = Vector2(14, 31)
	confirm_message_label.size = Vector2(302, 38)
	confirm_message_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	confirm_message_label.scroll_active = false
	confirm_message_label.z_index = 20
	confirm_message_label.add_theme_font_size_override("normal_font_size", 11)
	confirm_message_label.add_theme_color_override("default_color", Color.WHITE)

	var button_style_normal := create_button_style(
		Color(0.16, 0.09, 0.045, 1.0),
		Color(0.95, 0.55, 0.18, 1.0)
	)

	var button_style_hover := create_button_style(
		Color(0.35, 0.18, 0.07, 1.0),
		Color(1.0, 0.78, 0.32, 1.0)
	)

	yes_button = Button.new()
	yes_button.name = "YesButton"
	confirm_panel.add_child(yes_button)

	yes_button.position = Vector2(48, 78)
	yes_button.size = Vector2(108, 24)
	yes_button.add_theme_font_size_override("font_size", 9)
	yes_button.add_theme_stylebox_override("normal", button_style_normal)
	yes_button.add_theme_stylebox_override("hover", button_style_hover)
	yes_button.add_theme_stylebox_override("pressed", button_style_hover)
	yes_button.add_theme_color_override("font_color", Color.WHITE)
	yes_button.add_theme_color_override("font_hover_color", Color(1.0, 0.85, 0.45))
	yes_button.pressed.connect(_on_yes_button_pressed)

	no_button = Button.new()
	no_button.name = "NoButton"
	confirm_panel.add_child(no_button)

	no_button.position = Vector2(190, 78)
	no_button.size = Vector2(92, 24)
	no_button.add_theme_font_size_override("font_size", 9)
	no_button.add_theme_stylebox_override("normal", button_style_normal)
	no_button.add_theme_stylebox_override("hover", button_style_hover)
	no_button.add_theme_stylebox_override("pressed", button_style_hover)
	no_button.add_theme_color_override("font_color", Color.WHITE)
	no_button.add_theme_color_override("font_hover_color", Color(1.0, 0.85, 0.45))
	no_button.pressed.connect(_on_no_button_pressed)

	center_confirm_panel()


func create_button_style(bg_color: Color, border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()

	style.bg_color = bg_color
	style.border_color = border_color
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5

	return style


func center_confirm_panel() -> void:
	if confirm_panel == null:
		return

	var viewport_size := get_viewport().get_visible_rect().size

	confirm_panel.position = Vector2(
		(viewport_size.x - confirm_panel.size.x) * 0.5,
		viewport_size.y - confirm_panel.size.y - 4
	)


func show_call_camp_ui() -> void:
	confirm_mode = ConfirmMode.CALL_CAMP

	show_confirm_ui(
		"CỔNG DỊCH CHUYỂN",
		get_safe_text(question_message, "Bạn có muốn gọi cho mọi người ở trại không?"),
		"Có",
		"Không"
	)


func show_leave_area_ui() -> void:
	confirm_mode = ConfirmMode.LEAVE_AREA

	show_confirm_ui(
		"RỜI KHỎI ĐÂY",
		get_safe_text(leave_message, "Bạn đã sẵn sàng rời khỏi đây chưa?"),
		"Rời khỏi đây",
		"Ở lại"
	)


func show_confirm_ui(title: String, message: String, yes_text: String, no_text: String) -> void:
	if confirm_root == null:
		return

	is_busy = true
	set_all_players_control_enabled(false)

	if talk_indicator != null:
		talk_indicator.visible = false

	if confirm_title_label != null:
		confirm_title_label.text = title

	if confirm_message_label != null:
		confirm_message_label.text = "[center]" + message + "[/center]"

	if yes_button != null:
		yes_button.text = yes_text

	if no_button != null:
		no_button.text = no_text

	center_confirm_panel()

	if confirm_tween != null:
		confirm_tween.kill()

	confirm_root.visible = true
	confirm_root.modulate.a = 0.0

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	confirm_tween = create_tween()
	confirm_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	confirm_tween.tween_property(confirm_root, "modulate:a", 1.0, 0.2)

	if yes_button != null:
		yes_button.grab_focus()


func hide_confirm_ui() -> void:
	if confirm_root == null:
		return

	if confirm_tween != null:
		confirm_tween.kill()

	confirm_tween = create_tween()
	confirm_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	confirm_tween.tween_property(confirm_root, "modulate:a", 0.0, 0.15)

	await confirm_tween.finished

	confirm_root.visible = false


func _on_yes_button_pressed() -> void:
	await hide_confirm_ui()

	if confirm_mode == ConfirmMode.CALL_CAMP:
		await play_call_camp_sequence()
	else:
		await play_final_sequence()


func _on_no_button_pressed() -> void:
	await hide_confirm_ui()

	is_busy = false
	set_all_players_control_enabled(true)
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

	update_talk_indicator()


func get_safe_text(value: String, fallback: String) -> String:
	var text := value.strip_edges()

	if text == "":
		return fallback

	return text


# =========================
# EFFECT UI
# =========================

func create_effect_ui() -> void:
	effect_layer = CanvasLayer.new()
	effect_layer.name = "Map7PortalEffectUI"
	effect_layer.layer = 99999
	effect_layer.process_mode = Node.PROCESS_MODE_ALWAYS

	add_child(effect_layer)

	effect_root = Control.new()
	effect_root.name = "EffectRoot"
	effect_root.process_mode = Node.PROCESS_MODE_ALWAYS
	effect_layer.add_child(effect_root)

	effect_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	effect_root.offset_left = 0
	effect_root.offset_top = 0
	effect_root.offset_right = 0
	effect_root.offset_bottom = 0
	effect_root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	black_rect = ColorRect.new()
	black_rect.name = "BlackRect"
	black_rect.process_mode = Node.PROCESS_MODE_ALWAYS
	effect_root.add_child(black_rect)

	black_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	black_rect.offset_left = 0
	black_rect.offset_top = 0
	black_rect.offset_right = 0
	black_rect.offset_bottom = 0
	black_rect.color = Color(0, 0, 0, 0)
	black_rect.visible = true
	black_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	white_rect = ColorRect.new()
	white_rect.name = "WhiteRect"
	white_rect.process_mode = Node.PROCESS_MODE_ALWAYS
	effect_root.add_child(white_rect)

	white_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	white_rect.offset_left = 0
	white_rect.offset_top = 0
	white_rect.offset_right = 0
	white_rect.offset_bottom = 0
	white_rect.color = Color(1, 1, 1, 0)
	white_rect.visible = true
	white_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	slam_player = AudioStreamPlayer.new()
	slam_player.name = "SlamSound"
	slam_player.process_mode = Node.PROCESS_MODE_ALWAYS
	effect_layer.add_child(slam_player)
	slam_player.stream = slam_sound

	resize_effect_rects()


func resize_effect_rects() -> void:
	if effect_root != null:
		effect_root.set_anchors_preset(Control.PRESET_FULL_RECT)
		effect_root.offset_left = 0
		effect_root.offset_top = 0
		effect_root.offset_right = 0
		effect_root.offset_bottom = 0

	if black_rect != null:
		black_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		black_rect.offset_left = 0
		black_rect.offset_top = 0
		black_rect.offset_right = 0
		black_rect.offset_bottom = 0

	if white_rect != null:
		white_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		white_rect.offset_left = 0
		white_rect.offset_top = 0
		white_rect.offset_right = 0
		white_rect.offset_bottom = 0


func play_call_camp_sequence() -> void:
	print("Map7Portal: Bắt đầu hiệu ứng gọi NPC.")

	is_busy = true
	set_all_players_control_enabled(false)
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

	if talk_indicator != null:
		talk_indicator.visible = false

	resize_effect_rects()
	set_black_alpha(0.0)
	set_white_alpha(0.0)

	await tween_black_alpha(1.0, call_fade_out_time)

	await get_tree().create_timer(call_black_hold_time, true).timeout

	call_map_7_reveal_rescue_npcs()

	await get_tree().create_timer(0.15, true).timeout

	await tween_black_alpha(0.0, call_fade_in_time)

	is_busy = false
	set_all_players_control_enabled(true)
	update_talk_indicator()

	print("Map7Portal: Kết thúc hiệu ứng gọi NPC.")


func play_final_sequence() -> void:
	print("Map7Portal: Bắt đầu hiệu ứng kết thúc.")
	finish_run_for_main_menu()
	is_busy = true
	is_final_changing_scene = true
	set_all_players_control_enabled(false)
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

	if talk_indicator != null:
		talk_indicator.visible = false

	resize_effect_rects()
	set_black_alpha(0.0)
	set_white_alpha(0.0)

	get_tree().paused = true

	if MusicManager.has_method("fade_out"):
		MusicManager.fade_out(audio_fade_out_time, true)

	await tween_white_alpha(1.0, final_light_fade_time)

	play_slam_sound()

	set_white_alpha(0.0)
	set_black_alpha(1.0)

	await get_tree().create_timer(final_black_wait_time, true).timeout

	get_tree().paused = false

	if main_menu_scene_path == "":
		push_warning("Map7Portal: Chưa gán Main Menu Scene Path.")
		clear_final_effect_layer()
		return

	clear_final_effect_layer()

	if MusicManager.has_method("fade_in_after_delay"):
		MusicManager.fade_in_after_delay(3.0, 2.0)

	get_tree().change_scene_to_file(main_menu_scene_path)


func tween_black_alpha(target_alpha: float, duration: float) -> void:
	if black_rect == null:
		return

	var start_alpha := black_rect.color.a

	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_method(Callable(self, "set_black_alpha"), start_alpha, target_alpha, duration)

	await tween.finished


func tween_white_alpha(target_alpha: float, duration: float) -> void:
	if white_rect == null:
		return

	var start_alpha := white_rect.color.a

	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_method(Callable(self, "set_white_alpha"), start_alpha, target_alpha, duration)

	await tween.finished


func set_black_alpha(value: float) -> void:
	if black_rect == null:
		return

	black_rect.color = Color(0, 0, 0, clamp(value, 0.0, 1.0))


func set_white_alpha(value: float) -> void:
	if white_rect == null:
		return

	white_rect.color = Color(1, 1, 1, clamp(value, 0.0, 1.0))


func tween_master_volume(target_db: float, duration: float) -> void:
	if master_bus_index < 0:
		return

	var start_db := AudioServer.get_bus_volume_db(master_bus_index)

	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_method(Callable(self, "set_master_volume_db"), start_db, target_db, duration)

	await tween.finished


func set_master_volume_db(value: float) -> void:
	if master_bus_index < 0:
		return

	AudioServer.set_bus_volume_db(master_bus_index, value)


func restore_master_volume() -> void:
	if master_bus_index < 0:
		return

	AudioServer.set_bus_volume_db(master_bus_index, original_master_volume_db)


func play_slam_sound() -> void:
	if slam_player == null:
		return

	if slam_player.stream == null:
		return

	slam_player.stop()
	slam_player.play()


func call_map_7_reveal_rescue_npcs() -> void:
	LevelManager.set_game_flag(camp_called_flag, true)

	var current_scene := get_tree().current_scene

	if current_scene == null:
		return

	if current_scene.has_method("reveal_rescue_npcs"):
		current_scene.reveal_rescue_npcs()
	else:
		push_warning("Map7Portal: Scene hiện tại không có hàm reveal_rescue_npcs().")


# =========================
# PLAYER / CO-OP
# =========================

func set_all_players_control_enabled(state: bool) -> void:
	if is_two_player_mode():
		for p in get_players():
			if p == null:
				continue

			if !is_instance_valid(p):
				continue

			if p.has_method("set_control_enabled"):
				p.set_control_enabled(state)
			elif p.has_method("set_can_control"):
				p.set_can_control(state)

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
	elif player.has_method("set_can_control"):
		player.set_can_control(state)

	if has_object_property(player, "can_control"):
		player.set("can_control", state)


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


func has_object_property(obj: Object, prop_name: String) -> bool:
	if obj == null:
		return false

	for prop in obj.get_property_list():
		if String(prop.get("name", "")) == prop_name:
			return true

	return false


func clear_final_effect_layer() -> void:
	if black_rect != null:
		set_black_alpha(0.0)

	if white_rect != null:
		set_white_alpha(0.0)

	if effect_layer != null and is_instance_valid(effect_layer):
		effect_layer.queue_free()

	effect_layer = null
	effect_root = null
	black_rect = null
	white_rect = null

func _exit_tree() -> void:
	get_tree().paused = false
	restore_master_volume()
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

	clear_final_effect_layer()
func finish_run_for_main_menu() -> void:
	if has_submitted_clear_score:
		return

	has_submitted_clear_score = true

	var timer := get_node_or_null("/root/GameRunTimer")

	if timer == null:
		push_warning("Map7Portal: Chưa có Autoload GameRunTimer.")
		return

	if timer.has_method("finish_run"):
		timer.finish_run()
	elif timer.has_method("stop_run"):
		timer.stop_run()
	else:
		push_warning("Map7Portal: GameRunTimer chưa có hàm finish_run() hoặc stop_run().")
