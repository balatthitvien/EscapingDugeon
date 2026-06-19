extends Node2D

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D
@onready var animation_player: AnimationPlayer = get_node_or_null("AnimationPlayer") as AnimationPlayer
@onready var interaction_area: Area2D = get_node_or_null("InteractionArea") as Area2D
@onready var talk_indicator: Node2D = get_node_or_null("TalkIndicator") as Node2D

@export var portal_animation_name: String = "Portal"
@export var interact_action: String = "interact"

@export var required_boss_flag: String = "test_level_new_boss_killed"

@export var locked_message: String = "Bạn phải đánh bại tên trùm mới có thể rời khỏi đây."
@export var leave_message: String = "Bạn đã sẵn sàng rời khỏi đây chưa?"

@export_file("*.tscn") var main_menu_scene_path: String = "res://MainMenu/main_menu.tscn"

@export var final_light_fade_time: float = 5.0
@export var final_black_hold_time: float = 0.9
@export var main_menu_music_delay: float = 3.0
@export var main_menu_music_fade_time: float = 2.0

@export var slam_sound: AudioStream

var player_in_range: bool = false
var player: Player = null
var is_busy: bool = false

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

var is_changing_to_main_menu: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	if interaction_area == null:
		interaction_area = find_first_area_2d(self)

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

	print("BossExitPortal ready")


func setup_interaction_area() -> void:
	if interaction_area == null:
		push_error("BossExitPortal: Không tìm thấy InteractionArea. Hãy tạo Area2D tên InteractionArea trong scene Portal.")
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
	if not player_in_range:
		return

	if is_busy:
		return

	if event.is_action_pressed(interact_action):
		try_use_portal()
		get_viewport().set_input_as_handled()


func try_use_portal() -> void:
	if not LevelManager.get_game_flag(required_boss_flag):
		show_bottom_message(locked_message)
		return

	show_leave_ui()


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
	var detected_player := find_player_from_node(target)

	if detected_player == null:
		return

	player = detected_player
	player_in_range = true

	if LevelManager.get_game_flag(required_boss_flag):
		if talk_indicator != null:
			talk_indicator.visible = true
	else:
		show_bottom_message(locked_message)


func try_remove_player_from_range(target: Node) -> void:
	var detected_player := find_player_from_node(target)

	if detected_player == null:
		return

	if detected_player != player:
		return

	player = null
	player_in_range = false

	if talk_indicator != null:
		talk_indicator.visible = false


# =========================
# MESSAGE UI
# =========================

func create_message_ui() -> void:
	message_layer = CanvasLayer.new()
	message_layer.name = "BossExitPortalMessageUI"
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
	message_label.offset_left = -280
	message_label.offset_right = 280
	message_label.offset_top = -90
	message_label.offset_bottom = -45

	message_label.add_theme_font_size_override("font_size", 16)
	message_label.add_theme_color_override("font_color", Color.WHITE)


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

	message_label.visible = false


# =========================
# CONFIRM UI
# =========================

func create_confirm_ui() -> void:
	confirm_layer = CanvasLayer.new()
	confirm_layer.name = "BossExitPortalConfirmUI"
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

	confirm_title_label.text = "RỜI KHỎI ĐÂY"
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
	confirm_message_label.text = "[center]" + leave_message + "[/center]"
	confirm_message_label.position = Vector2(14, 31)
	confirm_message_label.size = Vector2(302, 38)
	confirm_message_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	confirm_message_label.scroll_active = false
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

	yes_button.text = "Rời khỏi đây"
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

	no_button.text = "Ở lại"
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


func show_leave_ui() -> void:
	if confirm_root == null:
		return

	is_busy = true
	set_player_control_enabled(false)

	if talk_indicator != null:
		talk_indicator.visible = false

	if confirm_message_label != null:
		confirm_message_label.text = "[center]" + leave_message + "[/center]"

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
	print("BossExitPortal: Player bấm Rời khỏi đây")

	await hide_confirm_ui()

	is_busy = true
	set_player_control_enabled(false)
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

	if talk_indicator != null:
		talk_indicator.visible = false
	finish_run_for_main_menu()
	if FinalExitTransition.has_method("play_to_main_menu"):
		FinalExitTransition.play_to_main_menu(
			main_menu_scene_path,
			slam_sound,
			final_light_fade_time,
			final_black_hold_time,
			main_menu_music_delay,
			main_menu_music_fade_time
		)
	else:
		push_error("Không tìm thấy FinalExitTransition.play_to_main_menu()")

func _on_no_button_pressed() -> void:
	await hide_confirm_ui()

	is_busy = false
	set_player_control_enabled(true)
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

	if talk_indicator != null and player_in_range:
		talk_indicator.visible = true


# =========================
# EFFECT UI
# =========================

func create_effect_ui() -> void:
	effect_layer = CanvasLayer.new()
	effect_layer.name = "BossExitPortalEffectUI"
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


func play_final_sequence() -> void:
	print("BossExitPortal: Bắt đầu hiệu ứng rời khỏi đây")

	is_busy = true
	set_player_control_enabled(false)
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

	if talk_indicator != null:
		talk_indicator.visible = false

	resize_effect_rects()
	set_white_alpha(0.0)
	set_black_alpha(0.0)

	if MusicManager.has_method("fade_out"):
		MusicManager.fade_out(final_light_fade_time, true)

	# Sáng trắng từ từ 5 giây.
	await tween_white_alpha(1.0, final_light_fade_time)

	play_slam_sound()

	# Tối thui ngay lập tức.
	set_white_alpha(0.0)
	set_black_alpha(1.0)

	await get_tree().create_timer(final_black_hold_time).timeout

	# Xóa lớp hiệu ứng trước khi sang Main Menu để Main Menu không bị đen.
	clear_effect_layer()

	if MusicManager.has_method("fade_in_after_delay"):
		MusicManager.fade_in_after_delay(main_menu_music_delay, main_menu_music_fade_time)

	if main_menu_scene_path == "":
		push_warning("BossExitPortal: Chưa gán Main Menu Scene Path.")
		return

	get_tree().change_scene_to_file(main_menu_scene_path)


func tween_white_alpha(target_alpha: float, duration: float) -> void:
	if white_rect == null:
		return

	var start_alpha := white_rect.color.a

	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_method(Callable(self, "set_white_alpha"), start_alpha, target_alpha, duration)

	await tween.finished


func set_white_alpha(value: float) -> void:
	if white_rect == null:
		return

	white_rect.color = Color(1, 1, 1, clamp(value, 0.0, 1.0))


func set_black_alpha(value: float) -> void:
	if black_rect == null:
		return

	black_rect.color = Color(0, 0, 0, clamp(value, 0.0, 1.0))


func play_slam_sound() -> void:
	if slam_player == null:
		return

	if slam_player.stream == null:
		return

	slam_player.stop()
	slam_player.play()


func clear_effect_layer() -> void:
	if black_rect != null:
		set_black_alpha(0.0)
		black_rect.visible = false

	if white_rect != null:
		set_white_alpha(0.0)
		white_rect.visible = false

	if effect_layer != null and is_instance_valid(effect_layer):
		effect_layer.queue_free()

	effect_layer = null
	effect_root = null
	black_rect = null
	white_rect = null


# =========================
# PLAYER
# =========================

func set_player_control_enabled(state: bool) -> void:
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


func has_object_property(obj: Object, prop_name: String) -> bool:
	if obj == null:
		return false

	for prop in obj.get_property_list():
		if String(prop.get("name", "")) == prop_name:
			return true

	return false


func find_first_area_2d(root: Node) -> Area2D:
	if root == null:
		return null

	for child in root.get_children():
		if child is Area2D:
			return child as Area2D

		var found := find_first_area_2d(child)

		if found != null:
			return found

	return null


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
func finish_run_for_main_menu() -> void:
	var timer := get_node_or_null("/root/GameRunTimer")

	if timer == null:
		push_warning("BossExitPortal: Chưa có Autoload GameRunTimer.")
		return

	if timer.has_method("finish_run"):
		timer.finish_run()
	elif timer.has_method("stop_run"):
		timer.stop_run()
	else:
		push_warning("BossExitPortal: GameRunTimer chưa có hàm finish_run() hoặc stop_run().")
