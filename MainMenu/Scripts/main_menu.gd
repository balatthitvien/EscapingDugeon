extends Control

const GAME_SCENE_PATH: String = "res://level/testlevel/test_level_new.tscn"

@onready var color_rect: ColorRect = get_node_or_null("ColorRect") as ColorRect
@onready var vbox: VBoxContainer = get_node_or_null("VBoxContainer") as VBoxContainer
@onready var title_label: Label = get_node_or_null("VBoxContainer/TitleLabel") as Label
@onready var play_button: Button = get_node_or_null("VBoxContainer/PlayButton") as Button
@onready var coop_button: Button = get_node_or_null("VBoxContainer/CoopButton") as Button
@onready var leaderboard_button: Button = get_node_or_null("VBoxContainer/LeaderboardButton") as Button
@onready var load_button: Button = get_node_or_null("VBoxContainer/LoadButton") as Button
@onready var quit_button: Button = get_node_or_null("VBoxContainer/QuitButton") as Button
@onready var menu_click_sound: AudioStreamPlayer = get_node_or_null("MenuClickSound") as AudioStreamPlayer

var load_panel: Panel
var load_message_label: Label
var load_slot_rows: Array = []
var is_loading_slot: bool = false

var leaderboard_panel: Panel
var leaderboard_text: RichTextLabel
var leaderboard_overlay: ColorRect
var leaderboard_title_label: Label
var leaderboard_mode_one_button: Button
var leaderboard_mode_two_button: Button
var leaderboard_rows_container: VBoxContainer
var leaderboard_close_button: Button
var leaderboard_scroll: ScrollContainer
var leaderboard_current_mode: String = "1p"
var leaderboard_row_refs: Array = []

var leaderboard_data_1p: Array = []
var leaderboard_data_2p: Array = []
var clear_result_overlay: ColorRect
var clear_result_panel: Panel
var clear_result_time_label: Label
var clear_result_message_label: Label
var clear_result_yes_button: Button
var clear_result_no_button: Button
var pending_clear_score: Dictionary = {}
var name_input_overlay: ColorRect
var name_input_panel: Panel
var name_input_title_label: Label
var name_input_time_label: Label
var name_input_p1_label: Label
var name_input_p2_label: Label
var name_input_p1_edit: LineEdit
var name_input_p2_edit: LineEdit
var name_input_error_label: Label
var name_input_save_button: Button
var name_input_cancel_button: Button
var delete_confirm_overlay: ColorRect
var delete_confirm_panel: Panel
var delete_confirm_message_label: Label
var pending_delete_slot: int = -1
var coop_confirm_overlay: ColorRect
var coop_confirm_panel: Panel
var coop_confirm_title_label: Label
var coop_confirm_message_label: RichTextLabel
var coop_confirm_start_button: Button
var coop_confirm_back_button: Button
var is_starting_coop: bool = false
func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if menu_click_sound != null:
		menu_click_sound.process_mode = Node.PROCESS_MODE_ALWAYS

	hide_removed_ui_nodes()
	setup_layout()
	create_load_ui()
	create_delete_confirm_ui()
	connect_buttons()
	create_leaderboard_panel()
	create_clear_result_ui()
	create_name_input_ui()
	create_coop_confirm_ui()
	call_deferred("check_pending_clear_result")
	MusicManager.play_game_bgm_after_delay(3.0, 2.0, true)
func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		center_load_panel()
		center_leaderboard_panel()
		center_delete_confirm_panel()
		center_coop_confirm_panel()


func hide_removed_ui_nodes() -> void:
	var removed_nodes: Array[String] = [
		"TopRightUI",
		"TopLeftUI",
		"BottomLeftUI",
		"AuthPopup",
		"Control"
	]

	for node_name in removed_nodes:
		var node := get_node_or_null(node_name)

		if node != null and node is CanvasItem:
			(node as CanvasItem).visible = false


func setup_layout() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0

	if color_rect != null:
		color_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		color_rect.offset_left = 0
		color_rect.offset_top = 0
		color_rect.offset_right = 0
		color_rect.offset_bottom = 0
		color_rect.color = Color(0, 0, 0, 1)

	if vbox != null:
		vbox.set_anchors_preset(Control.PRESET_CENTER)


		vbox.offset_left = -330
		vbox.offset_top = -210
		vbox.offset_right = 330
		vbox.offset_bottom = 230

		vbox.alignment = BoxContainer.ALIGNMENT_CENTER


		vbox.add_theme_constant_override("separation", 0)

	if title_label != null:
		title_label.text = "ESCAPING DUNGEON"
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

		title_label.custom_minimum_size = Vector2(660, 56)
		title_label.add_theme_font_size_override("font_size", 23)
		title_label.add_theme_color_override("font_color", Color.WHITE)
		title_label.add_theme_color_override("font_outline_color", Color.BLACK)
		title_label.add_theme_constant_override("outline_size", 4)

	setup_menu_button(play_button, "1 player")
	setup_menu_button(coop_button, "2 players")
	setup_menu_button(leaderboard_button, "leaderboard")
	setup_menu_button(load_button, "load")
	setup_menu_button(quit_button, "quit")


func setup_menu_button(button: Button, text_value: String) -> void:
	if button == null:
		return

	button.text = text_value

	button.custom_minimum_size = Vector2(300, 34)

	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var empty := StyleBoxEmpty.new()
	button.add_theme_stylebox_override("normal", empty)
	button.add_theme_stylebox_override("hover", empty)
	button.add_theme_stylebox_override("pressed", empty)
	button.add_theme_stylebox_override("disabled", empty)
	button.add_theme_stylebox_override("focus", empty)

	# Giảm font chữ menu
	button.add_theme_font_size_override("font_size", 21)

	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.80, 0.30))
	button.add_theme_color_override("font_pressed_color", Color(1.0, 0.42, 0.16))
	button.add_theme_color_override("font_disabled_color", Color(0.45, 0.45, 0.45))
	button.add_theme_color_override("font_outline_color", Color.BLACK)
	button.add_theme_constant_override("outline_size", 3)


func connect_buttons() -> void:
	connect_button(play_button, Callable(self, "_on_play_pressed"))
	connect_button(coop_button, Callable(self, "_on_coop_pressed"))
	connect_button(leaderboard_button, Callable(self, "_on_leaderboard_pressed"))
	connect_button(load_button, Callable(self, "_on_load_pressed"))
	connect_button(quit_button, Callable(self, "_on_quit_pressed"))


func connect_button(button: Button, callback: Callable) -> void:
	if button == null:
		return

	if not button.pressed.is_connected(callback):
		button.pressed.connect(callback)


func _on_play_pressed() -> void:
	disable_main_buttons()

	GameMode.set_single_player()

	if SaveManager != null:
		SaveManager.clear_pending_load()

	PlayerManager.reset_runtime_stats()
	LevelManager.reset_bow_data()
	start_new_game_timer("single")
	play_menu_click_sound()

	if MusicManager != null and MusicManager.has_method("fade_out"):
		MusicManager.fade_out(0.8, true)

	await get_tree().create_timer(0.25).timeout

	var transition := get_node_or_null("/root/SceneTransition")

	if transition != null and transition.has_method("change_scene_with_fade"):
		await transition.change_scene_with_fade(GAME_SCENE_PATH)
	else:
		get_tree().change_scene_to_file(GAME_SCENE_PATH)

func _on_coop_pressed() -> void:
	if is_starting_coop:
		return

	if coop_confirm_overlay != null and coop_confirm_overlay.visible:
		return

	play_menu_click_sound()
	show_coop_confirm_popup()


func _on_leaderboard_pressed() -> void:
	play_menu_click_sound()
	show_leaderboard_panel()


func _on_load_pressed() -> void:
	play_menu_click_sound()

	if vbox != null:
		vbox.visible = false

	load_panel.visible = true
	load_message_label.text = ""
	is_loading_slot = false

	center_load_panel()
	refresh_load_slots()


func _on_quit_pressed() -> void:
	disable_main_buttons()
	play_menu_click_sound()

	await get_tree().create_timer(0.4).timeout
	get_tree().quit()


func disable_main_buttons() -> void:
	if play_button != null:
		play_button.disabled = true

	if coop_button != null:
		coop_button.disabled = true

	if leaderboard_button != null:
		leaderboard_button.disabled = true

	if load_button != null:
		load_button.disabled = true

	if quit_button != null:
		quit_button.disabled = true


func enable_main_buttons() -> void:
	if play_button != null:
		play_button.disabled = false

	if coop_button != null:
		coop_button.disabled = false

	if leaderboard_button != null:
		leaderboard_button.disabled = false

	if load_button != null:
		load_button.disabled = false

	if quit_button != null:
		quit_button.disabled = false


# =========================================================
# LEADERBOARD UI
# =========================================================

func create_leaderboard_ui() -> void:
	leaderboard_panel = Panel.new()
	leaderboard_panel.name = "LeaderboardPanel"
	add_child(leaderboard_panel)

	leaderboard_panel.size = Vector2(520, 360)
	leaderboard_panel.visible = false
	leaderboard_panel.z_index = 100
	leaderboard_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	leaderboard_panel.add_theme_stylebox_override("panel", create_panel_style())

	var title := Label.new()
	title.text = "BẢNG XẾP HẠNG"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 3)
	leaderboard_panel.add_child(title)

	title.position = Vector2(24, 16)
	title.size = Vector2(472, 38)

	leaderboard_text = RichTextLabel.new()
	leaderboard_text.bbcode_enabled = true
	leaderboard_text.scroll_active = true
	leaderboard_text.add_theme_font_size_override("normal_font_size", 15)
	leaderboard_text.add_theme_color_override("default_color", Color.WHITE)
	leaderboard_panel.add_child(leaderboard_text)

	leaderboard_text.position = Vector2(34, 70)
	leaderboard_text.size = Vector2(452, 220)

	var back_button := Button.new()
	leaderboard_panel.add_child(back_button)

	back_button.position = Vector2(190, 310)
	back_button.size = Vector2(140, 32)
	setup_panel_button(back_button, "QUAY LẠI")
	back_button.pressed.connect(_on_back_from_leaderboard_pressed)

	center_leaderboard_panel()


func show_leaderboard() -> void:
	if vbox != null:
		vbox.visible = false

	leaderboard_panel.visible = true
	center_leaderboard_panel()
	refresh_leaderboard()


func refresh_leaderboard() -> void:
	var scores: Array = []

	var local_leaderboard := get_node_or_null("/root/LocalLeaderboard")

	if local_leaderboard != null and local_leaderboard.has_method("get_scores"):
		scores = local_leaderboard.get_scores()

	leaderboard_text.text = format_leaderboard_scores(scores)


func format_leaderboard_scores(scores: Array) -> String:
	var text := "[center][color=#ffd35a]TOP THỜI GIAN PHÁ ĐẢO[/color][/center]\n\n"

	if scores.is_empty():
		text += "[center]Chưa có kỉ lục nào.[/center]"
		return text

	var max_count: int = min(scores.size(), 10)

	for i in range(max_count):
		var score = scores[i]

		if typeof(score) != TYPE_DICTIONARY:
			continue

		var player_name: String = String(score.get("player_name", "Player"))
		var clear_time: String = String(score.get("clear_time_text", "00:00:00"))
		var game_mode: String = String(score.get("game_mode", "single"))
		var deaths: int = int(score.get("total_deaths", 0))

		text += "%02d. %s  -  %s  -  %s  -  Chết: %d\n" % [
			i + 1,
			player_name,
			clear_time,
			game_mode,
			deaths
		]

	return text


func _on_back_from_leaderboard_pressed() -> void:
	play_menu_click_sound()

	leaderboard_panel.visible = false

	if vbox != null:
		vbox.visible = true


func center_leaderboard_panel() -> void:
	if leaderboard_panel == null:
		return

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size

	leaderboard_panel.size = Vector2(
		min(520.0, viewport_size.x - 40.0),
		min(360.0, viewport_size.y - 40.0)
	)

	leaderboard_panel.position = (viewport_size - leaderboard_panel.size) * 0.5


# =========================================================
# LOAD UI
# =========================================================

func create_load_ui() -> void:
	load_panel = Panel.new()
	load_panel.name = "LoadPanel"
	add_child(load_panel)

	load_panel.size = Vector2(440, 244)
	load_panel.visible = false
	load_panel.z_index = 100
	load_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	load_panel.add_theme_stylebox_override("panel", create_panel_style())

	var title := Label.new()
	title.text = "TẢI DỮ LIỆU"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 2)
	load_panel.add_child(title)

	title.position = Vector2(12, 8)
	title.size = Vector2(416, 26)

	var start_y: float = 44.0
	var row_height: float = 32.0
	var row_gap: float = 5.0

	for slot in range(1, SaveManager.MAX_SAVE_SLOTS + 1):
		var row := Panel.new()
		row.name = "Slot%d" % slot
		load_panel.add_child(row)

		row.position = Vector2(12, start_y)
		row.size = Vector2(416, row_height)
		row.add_theme_stylebox_override("panel", create_slot_style())

		var thumb := TextureRect.new()
		row.add_child(thumb)

		thumb.position = Vector2(6, 4)
		thumb.size = Vector2(60, 24)
		thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

		var info_label := Label.new()
		row.add_child(info_label)

		info_label.position = Vector2(76, 2)
		info_label.size = Vector2(210, 28)
		info_label.add_theme_font_size_override("font_size", 9)
		info_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		info_label.add_theme_color_override("font_color", Color.WHITE)

		var play_slot_button := Button.new()
		row.add_child(play_slot_button)

		play_slot_button.position = Vector2(300, 5)
		play_slot_button.size = Vector2(48, 22)
		setup_panel_button(play_slot_button, "Chơi")
		play_slot_button.add_theme_font_size_override("font_size", 8)
		play_slot_button.pressed.connect(_on_load_slot_pressed.bind(slot))

		var delete_slot_button := Button.new()
		row.add_child(delete_slot_button)

		delete_slot_button.position = Vector2(356, 5)
		delete_slot_button.size = Vector2(48, 22)
		setup_panel_button(delete_slot_button, "Xóa")
		delete_slot_button.add_theme_font_size_override("font_size", 8)
		delete_slot_button.pressed.connect(_on_delete_slot_pressed.bind(slot))

		load_slot_rows.append({
			"slot": slot,
			"thumb": thumb,
			"label": info_label,
			"button": play_slot_button,
			"delete_button": delete_slot_button
		})

		start_y += row_height + row_gap

	load_message_label = Label.new()
	load_panel.add_child(load_message_label)

	load_message_label.text = ""
	load_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	load_message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	load_message_label.add_theme_font_size_override("font_size", 9)
	load_message_label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.28))
	load_message_label.position = Vector2(12, 194)
	load_message_label.size = Vector2(416, 16)

	var back_button := Button.new()
	load_panel.add_child(back_button)

	back_button.position = Vector2(180, 216)
	back_button.size = Vector2(80, 22)
	setup_panel_button(back_button, "QUAY LẠI")
	back_button.add_theme_font_size_override("font_size", 8)
	back_button.pressed.connect(_on_back_from_load_pressed)

	center_load_panel()

func center_load_panel() -> void:
	if load_panel == null:
		return

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size

	load_panel.size = Vector2(440, 244)
	load_panel.position = (viewport_size - load_panel.size) * 0.5


func refresh_load_slots() -> void:
	for row_data in load_slot_rows:
		var slot: int = row_data["slot"]
		var thumb: TextureRect = row_data["thumb"]
		var label: Label = row_data["label"]
		var slot_play_button: Button = row_data["button"]
		var slot_delete_button: Button = row_data["delete_button"]

		var info: Dictionary = SaveManager.get_slot_info(slot)

		slot_play_button.text = "Chơi"
		slot_delete_button.text = "Xóa"

		if not bool(info.get("exists", false)):
			label.text = "File %d\nChưa có dữ liệu" % slot
			thumb.texture = null
			slot_play_button.disabled = true
			slot_delete_button.disabled = true
			continue

		label.text = "File %d\n%s" % [
			slot,
			String(info.get("saved_at", "Không rõ thời gian"))
		]

		if bool(info.get("has_screenshot", false)):
			thumb.texture = load_texture_from_file(String(info.get("screenshot_path", "")))
		else:
			thumb.texture = null

		slot_play_button.disabled = false
		slot_delete_button.disabled = false

func _on_load_slot_pressed(slot: int) -> void:
	if is_loading_slot:
		return

	is_loading_slot = true
	load_message_label.text = "Đang vào game..."

	play_menu_click_sound()

	await get_tree().create_timer(0.2).timeout
	await MusicManager.fade_out(0.8, true)

	var success: bool = await SaveManager.load_slot(slot)

	if not success:
		load_message_label.text = "Không thể tải file này."
		is_loading_slot = false


func _on_back_from_load_pressed() -> void:
	play_menu_click_sound()
	hide_delete_confirm()
	load_panel.visible = false

	if vbox != null:
		vbox.visible = true

	is_loading_slot = false


func load_texture_from_file(path: String) -> Texture2D:
	if path == "":
		return null

	if not FileAccess.file_exists(path):
		return null

	var image := Image.new()
	var error := image.load(path)

	if error != OK:
		return null

	return ImageTexture.create_from_image(image)


# =========================================================
# HELPERS
# =========================================================

func start_new_game_timer(mode: String = "single") -> void:
	var timer := get_node_or_null("/root/GameRunTimer")

	if timer == null:
		push_warning("MainMenu: Chưa có Autoload GameRunTimer.")
		return

	if timer.has_method("start_run"):
		timer.start_run(mode)
	else:
		push_warning("MainMenu: GameRunTimer chưa có hàm start_run().")


func play_menu_click_sound() -> void:
	if menu_click_sound == null:
		return

	menu_click_sound.process_mode = Node.PROCESS_MODE_ALWAYS
	menu_click_sound.stop()
	menu_click_sound.pitch_scale = 0.6
	menu_click_sound.play()


func setup_panel_button(button: Button, text_value: String) -> void:
	if button == null:
		return

	button.text = text_value
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	button.add_theme_font_size_override("font_size", 9)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.80, 0.30))
	button.add_theme_color_override("font_pressed_color", Color(1.0, 0.42, 0.16))

	button.add_theme_stylebox_override("normal", create_button_style(Color(0.12, 0.075, 0.045, 0.96)))
	button.add_theme_stylebox_override("hover", create_button_style(Color(0.24, 0.13, 0.055, 0.96)))
	button.add_theme_stylebox_override("pressed", create_button_style(Color(0.36, 0.16, 0.060, 0.96)))
	button.add_theme_stylebox_override("focus", create_button_style(Color(0.12, 0.075, 0.045, 0.96)))


func create_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()

	style.bg_color = Color(0.0, 0.0, 0.0, 0.92)
	style.border_color = Color(1.0, 1.0, 1.0, 0.16)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8

	return style


func create_slot_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()

	style.bg_color = Color(0.0, 0.0, 0.0, 0.35)
	style.border_color = Color(1.0, 1.0, 1.0, 0.12)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5

	return style


func create_button_style(bg_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()

	style.bg_color = bg_color
	style.border_color = Color(1.0, 1.0, 1.0, 0.20)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 7
	style.content_margin_bottom = 7

	return style
func _on_leaderboard_button_pressed() -> void:
	show_leaderboard_panel()


func show_leaderboard_panel() -> void:
	if leaderboard_overlay == null:
		return

	leaderboard_overlay.visible = true
	leaderboard_current_mode = "1p"

	load_leaderboard_data_from_local()
	refresh_leaderboard_rows()

func hide_leaderboard_panel() -> void:
	if leaderboard_overlay == null:
		return

	leaderboard_overlay.visible = false


func create_leaderboard_panel() -> void:
	leaderboard_overlay = ColorRect.new()
	leaderboard_overlay.name = "LeaderboardOverlay"
	leaderboard_overlay.visible = false
	leaderboard_overlay.color = Color(0, 0, 0, 0.72)
	leaderboard_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	leaderboard_overlay.offset_left = 0
	leaderboard_overlay.offset_top = 0
	leaderboard_overlay.offset_right = 0
	leaderboard_overlay.offset_bottom = 0
	add_child(leaderboard_overlay)

	leaderboard_panel = Panel.new()
	leaderboard_panel.name = "LeaderboardPanel"
	leaderboard_panel.set_anchors_preset(Control.PRESET_CENTER)
	leaderboard_panel.offset_left = -220
	leaderboard_panel.offset_top = -122
	leaderboard_panel.offset_right = 220
	leaderboard_panel.offset_bottom = 122
	leaderboard_overlay.add_child(leaderboard_panel)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.02, 0.02, 0.02, 0.96)
	panel_style.border_color = Color(0.23, 0.23, 0.23, 1.0)
	panel_style.set_border_width_all(2)
	panel_style.corner_radius_top_left = 10
	panel_style.corner_radius_top_right = 10
	panel_style.corner_radius_bottom_left = 10
	panel_style.corner_radius_bottom_right = 10
	leaderboard_panel.add_theme_stylebox_override("panel", panel_style)

	var root := VBoxContainer.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 12
	root.offset_top = 8
	root.offset_right = -12
	root.offset_bottom = -8
	root.add_theme_constant_override("separation", 4)
	leaderboard_panel.add_child(root)

	# TITLE
	leaderboard_title_label = Label.new()
	leaderboard_title_label.text = "BẢNG XẾP HẠNG"
	leaderboard_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	leaderboard_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	leaderboard_title_label.custom_minimum_size = Vector2(0, 24)
	leaderboard_title_label.add_theme_font_size_override("font_size", 15)
	leaderboard_title_label.add_theme_color_override("font_color", Color.WHITE)
	leaderboard_title_label.add_theme_color_override("font_outline_color", Color.BLACK)
	leaderboard_title_label.add_theme_constant_override("outline_size", 2)
	root.add_child(leaderboard_title_label)

	# MODE BUTTONS
	var mode_row := HBoxContainer.new()
	mode_row.alignment = BoxContainer.ALIGNMENT_CENTER
	mode_row.add_theme_constant_override("separation", 8)
	root.add_child(mode_row)

	leaderboard_mode_one_button = Button.new()
	leaderboard_mode_one_button.text = "1 người chơi"
	leaderboard_mode_one_button.custom_minimum_size = Vector2(120, 22)
	setup_leaderboard_mode_button(leaderboard_mode_one_button, true)
	mode_row.add_child(leaderboard_mode_one_button)

	leaderboard_mode_two_button = Button.new()
	leaderboard_mode_two_button.text = "2 người chơi"
	leaderboard_mode_two_button.custom_minimum_size = Vector2(120, 22)
	setup_leaderboard_mode_button(leaderboard_mode_two_button, false)
	mode_row.add_child(leaderboard_mode_two_button)

	leaderboard_mode_one_button.pressed.connect(_on_leaderboard_mode_one_pressed)
	leaderboard_mode_two_button.pressed.connect(_on_leaderboard_mode_two_pressed)

	# TABLE CONTAINER
	var table_margin := MarginContainer.new()
	table_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(table_margin)

	table_margin.add_theme_constant_override("margin_left", 4)
	table_margin.add_theme_constant_override("margin_right", 4)
	table_margin.add_theme_constant_override("margin_top", 2)
	table_margin.add_theme_constant_override("margin_bottom", 2)

	leaderboard_scroll = ScrollContainer.new()
	leaderboard_scroll.name = "LeaderboardScroll"
	leaderboard_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	leaderboard_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	leaderboard_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	leaderboard_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	table_margin.add_child(leaderboard_scroll)

	leaderboard_rows_container = VBoxContainer.new()
	leaderboard_rows_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	leaderboard_rows_container.add_theme_constant_override("separation", 3)
	leaderboard_scroll.add_child(leaderboard_rows_container)
	leaderboard_row_refs.clear()

	for i in range(10):
		create_leaderboard_row(i + 1)

	# CLOSE BUTTON
	leaderboard_close_button = Button.new()
	leaderboard_close_button.text = "Đóng"
	leaderboard_close_button.custom_minimum_size = Vector2(80, 20)
	setup_leaderboard_close_button(leaderboard_close_button)
	leaderboard_close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	root.add_child(leaderboard_close_button)

	leaderboard_close_button.pressed.connect(hide_leaderboard_panel)

	refresh_leaderboard_rows()


func create_leaderboard_row(rank_number: int) -> void:
	var row_panel := Panel.new()
	row_panel.custom_minimum_size = Vector2(0, 22)
	leaderboard_rows_container.add_child(row_panel)

	var row_style := StyleBoxFlat.new()
	row_style.bg_color = Color(0.08, 0.08, 0.08, 0.96)
	row_style.border_color = Color(0.18, 0.18, 0.18, 1.0)
	row_style.set_border_width_all(1)
	row_style.corner_radius_top_left = 4
	row_style.corner_radius_top_right = 4
	row_style.corner_radius_bottom_left = 4
	row_style.corner_radius_bottom_right = 4
	row_panel.add_theme_stylebox_override("panel", row_style)

	var row_hbox := HBoxContainer.new()
	row_hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	row_hbox.offset_left = 5
	row_hbox.offset_top = 1
	row_hbox.offset_right = -5
	row_hbox.offset_bottom = -1
	row_hbox.add_theme_constant_override("separation", 5)
	row_panel.add_child(row_hbox)

	var rank_label := Label.new()
	rank_label.text = str(rank_number)
	rank_label.custom_minimum_size = Vector2(30, 20)
	rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rank_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rank_label.add_theme_font_size_override("font_size", 12)
	rank_label.add_theme_color_override("font_color", Color.WHITE)
	row_hbox.add_child(rank_label)

	var name_label := Label.new()
	name_label.text = "--------"
	name_label.custom_minimum_size = Vector2(230, 20)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.clip_text = true
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	row_hbox.add_child(name_label)

	var time_label := Label.new()
	time_label.text = "--------"
	time_label.custom_minimum_size = Vector2(82, 20)
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	time_label.add_theme_font_size_override("font_size", 12)
	time_label.add_theme_color_override("font_color", Color.WHITE)
	row_hbox.add_child(time_label)

	leaderboard_row_refs.append({
		"rank": rank_label,
		"name": name_label,
		"time": time_label
	})

func setup_leaderboard_mode_button(button: Button, is_active: bool) -> void:
	if button == null:
		return

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.08, 0.08, 0.08, 0.96)

	normal.border_color = Color(0.90, 0.74, 0.25, 1.0) if is_active else Color(0.20, 0.20, 0.20, 1.0)

	normal.set_border_width_all(2)
	normal.corner_radius_top_left = 6
	normal.corner_radius_top_right = 6
	normal.corner_radius_bottom_left = 6
	normal.corner_radius_bottom_right = 6

	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.13, 0.13, 0.13, 0.98)
	hover.border_color = Color(0.90, 0.74, 0.25, 1.0)
	hover.set_border_width_all(2)
	hover.corner_radius_top_left = 6
	hover.corner_radius_top_right = 6
	hover.corner_radius_bottom_left = 6
	hover.corner_radius_bottom_right = 6

	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Color(0.18, 0.14, 0.04, 0.98)
	pressed.border_color = Color(0.95, 0.78, 0.28, 1.0)
	pressed.set_border_width_all(2)
	pressed.corner_radius_top_left = 6
	pressed.corner_radius_top_right = 6
	pressed.corner_radius_bottom_left = 6
	pressed.corner_radius_bottom_right = 6

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)

	button.add_theme_font_size_override("font_size", 9)

	var font_color := Color(1.0, 0.84, 0.30) if is_active else Color.WHITE
	button.add_theme_color_override("font_color", font_color)

	button.add_theme_color_override("font_hover_color", Color(1.0, 0.84, 0.30))
	button.add_theme_color_override("font_pressed_color", Color(1.0, 0.84, 0.30))
	button.add_theme_color_override("font_outline_color", Color.BLACK)
	button.add_theme_constant_override("outline_size", 1)

func setup_leaderboard_close_button(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.10, 0.10, 0.10, 0.96)
	normal.border_color = Color(0.20, 0.20, 0.20, 1.0)
	normal.set_border_width_all(2)
	normal.corner_radius_top_left = 6
	normal.corner_radius_top_right = 6
	normal.corner_radius_bottom_left = 6
	normal.corner_radius_bottom_right = 6

	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.18, 0.18, 0.18, 0.98)
	hover.border_color = Color(0.90, 0.74, 0.25, 1.0)
	hover.set_border_width_all(2)
	hover.corner_radius_top_left = 6
	hover.corner_radius_top_right = 6
	hover.corner_radius_bottom_left = 6
	hover.corner_radius_bottom_right = 6

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("focus", hover)

	button.add_theme_font_size_override("font_size", 9)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.84, 0.30))
	button.add_theme_color_override("font_outline_color", Color.BLACK)
	button.add_theme_constant_override("outline_size", 1)


func _on_leaderboard_mode_one_pressed() -> void:
	leaderboard_current_mode = "1p"
	refresh_leaderboard_rows()


func _on_leaderboard_mode_two_pressed() -> void:
	leaderboard_current_mode = "2p"
	refresh_leaderboard_rows()


func refresh_leaderboard_rows() -> void:
	var active_data: Array = leaderboard_data_1p if leaderboard_current_mode == "1p" else leaderboard_data_2p

	setup_leaderboard_mode_button(leaderboard_mode_one_button, leaderboard_current_mode == "1p")
	setup_leaderboard_mode_button(leaderboard_mode_two_button, leaderboard_current_mode == "2p")

	for i in range(10):
		var row_ref: Dictionary = leaderboard_row_refs[i]

		row_ref["rank"].text = str(i + 1)

		if i < active_data.size():
			var entry: Dictionary = active_data[i]
			row_ref["name"].text = str(entry.get("name", "--------"))
			row_ref["time"].text = str(entry.get("time", "--------"))
		else:
			row_ref["name"].text = "--------"
			row_ref["time"].text = "--------"
func create_clear_result_ui() -> void:
	clear_result_overlay = ColorRect.new()
	clear_result_overlay.name = "ClearResultOverlay"
	clear_result_overlay.visible = false
	clear_result_overlay.color = Color(0, 0, 0, 0.70)
	clear_result_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	clear_result_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(clear_result_overlay)

	clear_result_panel = Panel.new()
	clear_result_panel.name = "ClearResultPanel"
	clear_result_overlay.add_child(clear_result_panel)

	clear_result_panel.size = Vector2(360, 132)
	clear_result_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	clear_result_panel.add_theme_stylebox_override("panel", create_panel_style())

	var clear_result_title_label := Label.new()
	clear_result_title_label.text = "HOÀN THÀNH"
	clear_result_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clear_result_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	clear_result_title_label.add_theme_font_size_override("font_size", 15)
	clear_result_title_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.35))
	clear_result_title_label.add_theme_color_override("font_outline_color", Color.BLACK)
	clear_result_title_label.add_theme_constant_override("outline_size", 2)
	clear_result_panel.add_child(clear_result_title_label)
	clear_result_title_label.position = Vector2(12, 8)
	clear_result_title_label.size = Vector2(336, 24)

	clear_result_time_label = Label.new()
	clear_result_time_label.text = "Kỉ lục thời gian chơi: --------"
	clear_result_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clear_result_time_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	clear_result_time_label.add_theme_font_size_override("font_size", 11)
	clear_result_time_label.add_theme_color_override("font_color", Color.WHITE)
	clear_result_panel.add_child(clear_result_time_label)
	clear_result_time_label.position = Vector2(12, 36)
	clear_result_time_label.size = Vector2(336, 22)

	clear_result_message_label = Label.new()
	clear_result_message_label.text = "Bạn có muốn lưu kỉ lục không?"
	clear_result_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clear_result_message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	clear_result_message_label.add_theme_font_size_override("font_size", 10)
	clear_result_message_label.add_theme_color_override("font_color", Color.WHITE)
	clear_result_panel.add_child(clear_result_message_label)
	clear_result_message_label.position = Vector2(12, 62)
	clear_result_message_label.size = Vector2(336, 22)

	clear_result_yes_button = Button.new()
	clear_result_yes_button.text = "Có"
	clear_result_panel.add_child(clear_result_yes_button)
	clear_result_yes_button.position = Vector2(78, 96)
	clear_result_yes_button.size = Vector2(88, 24)
	setup_panel_button(clear_result_yes_button, "Có")
	clear_result_yes_button.add_theme_font_size_override("font_size", 9)
	clear_result_yes_button.pressed.connect(_on_save_clear_result_pressed)

	clear_result_no_button = Button.new()
	clear_result_no_button.text = "Không"
	clear_result_panel.add_child(clear_result_no_button)
	clear_result_no_button.position = Vector2(194, 96)
	clear_result_no_button.size = Vector2(88, 24)
	setup_panel_button(clear_result_no_button, "Không")
	clear_result_no_button.add_theme_font_size_override("font_size", 9)
	clear_result_no_button.pressed.connect(_on_cancel_clear_result_pressed)

	center_clear_result_panel()


func center_clear_result_panel() -> void:
	if clear_result_panel == null:
		return

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	clear_result_panel.position = (viewport_size - clear_result_panel.size) * 0.5


func check_pending_clear_result() -> void:
	var timer := get_node_or_null("/root/GameRunTimer")

	if timer == null:
		return

	if !timer.has_method("has_pending_clear_score"):
		return

	if !timer.has_pending_clear_score():
		return

	if !timer.has_method("get_pending_clear_score"):
		return

	var score_data: Dictionary = timer.get_pending_clear_score()

	if score_data.is_empty():
		return

	show_clear_result_popup(score_data)


func show_clear_result_popup(score_data: Dictionary) -> void:
	pending_clear_score = score_data.duplicate(true)

	var clear_time_text: String = String(pending_clear_score.get("clear_time_text", "00:00:00"))

	clear_result_time_label.text = "Kỉ lục thời gian chơi: " + clear_time_text

	clear_result_overlay.visible = true
	center_clear_result_panel()

	if vbox != null:
		vbox.visible = true

	clear_result_yes_button.disabled = false
	clear_result_no_button.disabled = false
	clear_result_yes_button.grab_focus()


func _on_save_clear_result_pressed() -> void:
	if pending_clear_score.is_empty():
		hide_clear_result_popup()
		return

	play_menu_click_sound()
	show_name_input_popup()

func _on_cancel_clear_result_pressed() -> void:
	var timer := get_node_or_null("/root/GameRunTimer")

	if timer != null and timer.has_method("clear_pending_clear_score"):
		timer.clear_pending_clear_score()

	pending_clear_score.clear()
	hide_clear_result_popup()


func hide_clear_result_popup() -> void:
	if clear_result_overlay != null:
		clear_result_overlay.visible = false
func load_leaderboard_data_from_local() -> void:
	leaderboard_data_1p.clear()
	leaderboard_data_2p.clear()

	var local_leaderboard := get_node_or_null("/root/LocalLeaderboard")

	if local_leaderboard == null:
		return

	if !local_leaderboard.has_method("get_scores"):
		return

	var scores: Array = local_leaderboard.get_scores()

	for score in scores:
		if typeof(score) != TYPE_DICTIONARY:
			continue

		var game_mode_text := String(score.get("game_mode", "single")).to_lower()
		var clear_time_text := String(score.get("clear_time_text", "00:00:00"))
		var clear_time_seconds := int(score.get("clear_time_seconds", 999999999))

		var display_name := String(score.get("player_name", "Player"))

		if game_mode_text == "coop" or game_mode_text == "2p":
			var p1_name := String(score.get("player_1_name", "Player 1"))
			var p2_name := String(score.get("player_2_name", "Player 2"))

			if display_name == "" or display_name == "Player":
				display_name = p1_name + " & " + p2_name

		var row_data: Dictionary = {
			"name": display_name,
			"time": clear_time_text,
			"seconds": clear_time_seconds
		}

		if game_mode_text == "coop" or game_mode_text == "2p":
			leaderboard_data_2p.append(row_data)
		else:
			leaderboard_data_1p.append(row_data)

	leaderboard_data_1p.sort_custom(sort_leaderboard_rows_by_time)
	leaderboard_data_2p.sort_custom(sort_leaderboard_rows_by_time)

	if leaderboard_data_1p.size() > 10:
		leaderboard_data_1p = leaderboard_data_1p.slice(0, 10)

	if leaderboard_data_2p.size() > 10:
		leaderboard_data_2p = leaderboard_data_2p.slice(0, 10)


func sort_leaderboard_rows_by_time(a: Dictionary, b: Dictionary) -> bool:
	return int(a.get("seconds", 999999999)) < int(b.get("seconds", 999999999))

func sort_leaderboard_rows(a: Dictionary, b: Dictionary) -> bool:
	return String(a.get("time", "99:99:99")) < String(b.get("time", "99:99:99"))
func create_name_input_ui() -> void:
	name_input_overlay = ColorRect.new()
	name_input_overlay.name = "NameInputOverlay"
	name_input_overlay.visible = false
	name_input_overlay.color = Color(0, 0, 0, 0.72)
	name_input_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	name_input_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(name_input_overlay)

	name_input_panel = Panel.new()
	name_input_panel.name = "NameInputPanel"
	name_input_panel.size = Vector2(370, 176)
	name_input_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	name_input_panel.add_theme_stylebox_override("panel", create_panel_style())
	name_input_overlay.add_child(name_input_panel)

	name_input_title_label = Label.new()
	name_input_title_label.text = "LƯU KỈ LỤC"
	name_input_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_input_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_input_title_label.add_theme_font_size_override("font_size", 15)
	name_input_title_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.35))
	name_input_title_label.add_theme_color_override("font_outline_color", Color.BLACK)
	name_input_title_label.add_theme_constant_override("outline_size", 2)
	name_input_panel.add_child(name_input_title_label)
	name_input_title_label.position = Vector2(12, 8)
	name_input_title_label.size = Vector2(346, 22)

	name_input_time_label = Label.new()
	name_input_time_label.text = "Thời gian: 00:00:00"
	name_input_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_input_time_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_input_time_label.add_theme_font_size_override("font_size", 10)
	name_input_time_label.add_theme_color_override("font_color", Color.WHITE)
	name_input_panel.add_child(name_input_time_label)
	name_input_time_label.position = Vector2(12, 32)
	name_input_time_label.size = Vector2(346, 18)

	name_input_p1_label = Label.new()
	name_input_p1_label.text = "Tên người chơi:"
	name_input_p1_label.add_theme_font_size_override("font_size", 9)
	name_input_p1_label.add_theme_color_override("font_color", Color.WHITE)
	name_input_panel.add_child(name_input_p1_label)
	name_input_p1_label.position = Vector2(32, 58)
	name_input_p1_label.size = Vector2(120, 18)

	name_input_p1_edit = LineEdit.new()
	name_input_p1_edit.placeholder_text = "Nhập tên"
	name_input_p1_edit.max_length = 14
	name_input_p1_edit.add_theme_font_size_override("font_size", 10)
	name_input_panel.add_child(name_input_p1_edit)
	name_input_p1_edit.position = Vector2(150, 56)
	name_input_p1_edit.size = Vector2(180, 22)

	name_input_p2_label = Label.new()
	name_input_p2_label.text = "Tên người chơi 2:"
	name_input_p2_label.add_theme_font_size_override("font_size", 9)
	name_input_p2_label.add_theme_color_override("font_color", Color.WHITE)
	name_input_panel.add_child(name_input_p2_label)
	name_input_p2_label.position = Vector2(32, 86)
	name_input_p2_label.size = Vector2(120, 18)

	name_input_p2_edit = LineEdit.new()
	name_input_p2_edit.placeholder_text = "Nhập tên P2"
	name_input_p2_edit.max_length = 14
	name_input_p2_edit.add_theme_font_size_override("font_size", 10)
	name_input_panel.add_child(name_input_p2_edit)
	name_input_p2_edit.position = Vector2(150, 84)
	name_input_p2_edit.size = Vector2(180, 22)

	name_input_error_label = Label.new()
	name_input_error_label.text = ""
	name_input_error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_input_error_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_input_error_label.add_theme_font_size_override("font_size", 8)
	name_input_error_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.35))
	name_input_panel.add_child(name_input_error_label)
	name_input_error_label.position = Vector2(12, 112)
	name_input_error_label.size = Vector2(346, 18)

	name_input_save_button = Button.new()
	name_input_panel.add_child(name_input_save_button)
	name_input_save_button.position = Vector2(74, 140)
	name_input_save_button.size = Vector2(92, 24)
	setup_panel_button(name_input_save_button, "Lưu")
	name_input_save_button.pressed.connect(_on_confirm_save_name_pressed)

	name_input_cancel_button = Button.new()
	name_input_panel.add_child(name_input_cancel_button)
	name_input_cancel_button.position = Vector2(204, 140)
	name_input_cancel_button.size = Vector2(92, 24)
	setup_panel_button(name_input_cancel_button, "Hủy")
	name_input_cancel_button.pressed.connect(_on_cancel_name_input_pressed)

	center_name_input_panel()
func center_name_input_panel() -> void:
	if name_input_panel == null:
		return

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	name_input_panel.position = (viewport_size - name_input_panel.size) * 0.5


func is_pending_score_coop() -> bool:
	var game_mode_text := String(pending_clear_score.get("game_mode", "single")).to_lower()

	if game_mode_text == "coop":
		return true

	if game_mode_text == "2p":
		return true

	if game_mode_text.contains("two"):
		return true

	return false


func show_name_input_popup() -> void:
	if pending_clear_score.is_empty():
		return

	if clear_result_overlay != null:
		clear_result_overlay.visible = false

	var is_coop_score := is_pending_score_coop()
	var clear_time_text := String(pending_clear_score.get("clear_time_text", "00:00:00"))

	name_input_time_label.text = "Thời gian: " + clear_time_text
	name_input_error_label.text = ""

	name_input_p1_edit.text = ""
	name_input_p2_edit.text = ""

	if is_coop_score:
		name_input_p1_label.text = "Tên người chơi 1:"
		name_input_p1_edit.placeholder_text = "Nhập tên P1"

		name_input_p2_label.visible = true
		name_input_p2_edit.visible = true
	else:
		name_input_p1_label.text = "Tên người chơi:"
		name_input_p1_edit.placeholder_text = "Nhập tên"

		name_input_p2_label.visible = false
		name_input_p2_edit.visible = false

	name_input_overlay.visible = true
	center_name_input_panel()

	name_input_save_button.disabled = false
	name_input_cancel_button.disabled = false
	name_input_p1_edit.grab_focus()


func hide_name_input_popup() -> void:
	if name_input_overlay != null:
		name_input_overlay.visible = false


func _on_confirm_save_name_pressed() -> void:
	if pending_clear_score.is_empty():
		hide_name_input_popup()
		return

	var is_coop_score := is_pending_score_coop()

	var player_1_name := name_input_p1_edit.text.strip_edges()
	var player_2_name := name_input_p2_edit.text.strip_edges()

	if player_1_name == "":
		if is_coop_score:
			player_1_name = "Player 1"
		else:
			player_1_name = "Player"

	if is_coop_score and player_2_name == "":
		player_2_name = "Player 2"

	if is_coop_score:
		pending_clear_score["player_1_name"] = player_1_name
		pending_clear_score["player_2_name"] = player_2_name
		pending_clear_score["player_name"] = player_1_name + " & " + player_2_name
		pending_clear_score["game_mode"] = "coop"
	else:
		pending_clear_score["player_name"] = player_1_name
		pending_clear_score["game_mode"] = "single"

	save_pending_clear_score_to_leaderboard()


func _on_cancel_name_input_pressed() -> void:
	play_menu_click_sound()

	var timer := get_node_or_null("/root/GameRunTimer")

	if timer != null and timer.has_method("clear_pending_clear_score"):
		timer.clear_pending_clear_score()

	pending_clear_score.clear()
	hide_name_input_popup()
func save_pending_clear_score_to_leaderboard() -> void:
	if pending_clear_score.is_empty():
		hide_name_input_popup()
		return

	name_input_save_button.disabled = true
	name_input_cancel_button.disabled = true

	var local_leaderboard := get_node_or_null("/root/LocalLeaderboard")

	if local_leaderboard != null and local_leaderboard.has_method("add_score"):
		local_leaderboard.add_score(pending_clear_score)
	else:
		push_warning("MainMenu: Chưa có Autoload LocalLeaderboard hoặc thiếu hàm add_score().")

	var timer := get_node_or_null("/root/GameRunTimer")

	if timer != null and timer.has_method("clear_pending_clear_score"):
		timer.clear_pending_clear_score()

	pending_clear_score.clear()

	load_leaderboard_data_from_local()
	refresh_leaderboard_rows()

	hide_name_input_popup()
func create_delete_confirm_ui() -> void:
	delete_confirm_overlay = ColorRect.new()
	delete_confirm_overlay.name = "DeleteConfirmOverlay"
	delete_confirm_overlay.visible = false
	delete_confirm_overlay.color = Color(0, 0, 0, 0.68)
	delete_confirm_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	delete_confirm_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	delete_confirm_overlay.z_index = 130
	add_child(delete_confirm_overlay)

	delete_confirm_panel = Panel.new()
	delete_confirm_panel.name = "DeleteConfirmPanel"
	delete_confirm_panel.size = Vector2(320, 130)
	delete_confirm_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	delete_confirm_panel.add_theme_stylebox_override("panel", create_panel_style())
	delete_confirm_overlay.add_child(delete_confirm_panel)

	delete_confirm_message_label = Label.new()
	delete_confirm_panel.add_child(delete_confirm_message_label)

	delete_confirm_message_label.text = ""
	delete_confirm_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	delete_confirm_message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	delete_confirm_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	delete_confirm_message_label.add_theme_font_size_override("font_size", 10)
	delete_confirm_message_label.add_theme_color_override("font_color", Color.WHITE)
	delete_confirm_message_label.position = Vector2(18, 16)
	delete_confirm_message_label.size = Vector2(284, 50)

	var yes_button := Button.new()
	delete_confirm_panel.add_child(yes_button)

	yes_button.position = Vector2(66, 82)
	yes_button.size = Vector2(78, 24)
	setup_panel_button(yes_button, "Có")
	yes_button.add_theme_font_size_override("font_size", 9)
	yes_button.pressed.connect(_on_confirm_delete_yes_pressed)

	var no_button := Button.new()
	delete_confirm_panel.add_child(no_button)

	no_button.position = Vector2(176, 82)
	no_button.size = Vector2(78, 24)
	setup_panel_button(no_button, "Không")
	no_button.add_theme_font_size_override("font_size", 9)
	no_button.pressed.connect(_on_confirm_delete_no_pressed)

	center_delete_confirm_panel()


func center_delete_confirm_panel() -> void:
	if delete_confirm_panel == null:
		return

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	delete_confirm_panel.position = (viewport_size - delete_confirm_panel.size) * 0.5


func show_delete_confirm(slot: int) -> void:
	pending_delete_slot = slot

	if delete_confirm_message_label != null:
		delete_confirm_message_label.text = "Bạn có muốn xóa File %d không?\nDữ liệu đã xóa sẽ không thể khôi phục." % slot

	if load_message_label != null:
		load_message_label.text = ""

	center_delete_confirm_panel()

	if delete_confirm_overlay != null:
		delete_confirm_overlay.visible = true


func hide_delete_confirm() -> void:
	pending_delete_slot = -1

	if delete_confirm_overlay != null:
		delete_confirm_overlay.visible = false


func _on_delete_slot_pressed(slot: int) -> void:
	if is_loading_slot:
		return

	var info: Dictionary = SaveManager.get_slot_info(slot)

	if not bool(info.get("exists", false)):
		load_message_label.text = "File này chưa có dữ liệu để xóa."
		return

	show_delete_confirm(slot)


func _on_confirm_delete_yes_pressed() -> void:
	if pending_delete_slot <= 0:
		hide_delete_confirm()
		return

	var slot: int = pending_delete_slot

	hide_delete_confirm()

	delete_save_slot(slot)


func _on_confirm_delete_no_pressed() -> void:
	hide_delete_confirm()

	if load_message_label != null:
		load_message_label.text = "Đã hủy xóa dữ liệu."


func delete_save_slot(slot: int) -> void:
	if is_loading_slot:
		return

	is_loading_slot = true
	load_message_label.text = "Đang xóa dữ liệu..."

	if not SaveManager.has_method("delete_slot"):
		load_message_label.text = "SaveManager chưa có hàm delete_slot()."
		is_loading_slot = false
		return

	var success: bool = SaveManager.delete_slot(slot)

	if success:
		load_message_label.text = "Đã xóa File %d." % slot
	else:
		var error_text: String = ""

		if SaveManager.has_method("get_last_save_error"):
			error_text = SaveManager.get_last_save_error()

		if error_text != "":
			load_message_label.text = error_text
		else:
			load_message_label.text = "Xóa dữ liệu thất bại."

	refresh_load_slots()

	is_loading_slot = false
# =========================================================
# COOP CONFIRM UI
# =========================================================

func create_coop_confirm_ui() -> void:
	coop_confirm_overlay = ColorRect.new()
	coop_confirm_overlay.name = "CoopConfirmOverlay"
	coop_confirm_overlay.visible = false
	coop_confirm_overlay.color = Color(0, 0, 0, 0.72)
	coop_confirm_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	coop_confirm_overlay.offset_left = 0
	coop_confirm_overlay.offset_top = 0
	coop_confirm_overlay.offset_right = 0
	coop_confirm_overlay.offset_bottom = 0
	coop_confirm_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	coop_confirm_overlay.z_index = 150
	add_child(coop_confirm_overlay)

	coop_confirm_panel = Panel.new()
	coop_confirm_panel.name = "CoopConfirmPanel"
	coop_confirm_panel.size = Vector2(390, 180)
	coop_confirm_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	coop_confirm_panel.add_theme_stylebox_override("panel", create_coop_confirm_panel_style())
	coop_confirm_overlay.add_child(coop_confirm_panel)

	coop_confirm_title_label = Label.new()
	coop_confirm_title_label.name = "TitleLabel"
	coop_confirm_title_label.text = "CHẾ ĐỘ 2 NGƯỜI CHƠI"
	coop_confirm_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coop_confirm_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	coop_confirm_title_label.add_theme_font_size_override("font_size", 14)
	coop_confirm_title_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.34))
	coop_confirm_title_label.add_theme_color_override("font_outline_color", Color.BLACK)
	coop_confirm_title_label.add_theme_constant_override("outline_size", 2)
	coop_confirm_panel.add_child(coop_confirm_title_label)

	coop_confirm_title_label.position = Vector2(12, 12)
	coop_confirm_title_label.size = Vector2(386, 28)

	coop_confirm_message_label = RichTextLabel.new()
	coop_confirm_message_label.name = "MessageLabel"
	coop_confirm_message_label.bbcode_enabled = true
	coop_confirm_message_label.fit_content = false
	coop_confirm_message_label.scroll_active = false
	coop_confirm_message_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coop_confirm_message_label.z_index = 10

	coop_confirm_message_label.text = "[center][color=#f2f2f2]Hai người chơi sẽ cùng chia sẻ [color=#ffd35a]Máu, Kinh nghiệm, Vàng[/color] và một số chỉ số khác.\n\nMột vài tính năng sẽ tạm thời bị khóa để giữ cân bằng và tăng tính phối hợp.[/color][/center]"

	coop_confirm_message_label.add_theme_font_size_override("normal_font_size", 12)
	coop_confirm_message_label.add_theme_color_override("default_color", Color.WHITE)
	coop_confirm_panel.add_child(coop_confirm_message_label)

	coop_confirm_message_label.position = Vector2(28, 52)
	coop_confirm_message_label.size = Vector2(354, 104)

	coop_confirm_back_button = Button.new()
	coop_confirm_back_button.name = "BackButton"
	coop_confirm_panel.add_child(coop_confirm_back_button)

	coop_confirm_back_button.position = Vector2(86, 176)
	coop_confirm_back_button.size = Vector2(104, 26)
	setup_panel_button(coop_confirm_back_button, "Quay lại")
	coop_confirm_back_button.add_theme_font_size_override("font_size", 9)
	coop_confirm_back_button.pressed.connect(_on_coop_confirm_back_pressed)

	coop_confirm_start_button = Button.new()
	coop_confirm_start_button.name = "StartButton"
	coop_confirm_panel.add_child(coop_confirm_start_button)

	coop_confirm_start_button.position = Vector2(220, 176)
	coop_confirm_start_button.size = Vector2(104, 26)
	setup_panel_button(coop_confirm_start_button, "Vào game")
	coop_confirm_start_button.add_theme_font_size_override("font_size", 9)
	coop_confirm_start_button.pressed.connect(_on_coop_confirm_start_pressed)

	center_coop_confirm_panel()

func create_coop_confirm_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()

	style.bg_color = Color(0.025, 0.018, 0.014, 0.97)
	style.border_color = Color(0.95, 0.58, 0.18, 0.92)
	style.set_border_width_all(2)

	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8

	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10

	return style


func center_coop_confirm_panel() -> void:
	if coop_confirm_panel == null:
		return

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	coop_confirm_panel.size = Vector2(410, 220)
	coop_confirm_panel.position = (viewport_size - coop_confirm_panel.size) * 0.5


func show_coop_confirm_popup() -> void:
	if coop_confirm_overlay == null:
		return

	if coop_confirm_start_button == null:
		push_warning("MainMenu: CoopConfirm StartButton chưa được tạo.")
		return

	if coop_confirm_back_button == null:
		push_warning("MainMenu: CoopConfirm BackButton chưa được tạo.")
		return

	is_starting_coop = false

	coop_confirm_start_button.disabled = false
	coop_confirm_back_button.disabled = false

	coop_confirm_overlay.visible = true
	center_coop_confirm_panel()

	coop_confirm_start_button.grab_focus()


func hide_coop_confirm_popup() -> void:
	if coop_confirm_overlay == null:
		return

	coop_confirm_overlay.visible = false
	is_starting_coop = false

func stop_menu_click_sound() -> void:
	if menu_click_sound == null:
		return

	menu_click_sound.stop()
func _on_coop_confirm_back_pressed() -> void:
	if is_starting_coop:
		return

	play_menu_click_sound()
	hide_coop_confirm_popup()


func _on_coop_confirm_start_pressed() -> void:
	if is_starting_coop:
		return

	is_starting_coop = true

	if coop_confirm_start_button != null:
		coop_confirm_start_button.disabled = true

	if coop_confirm_back_button != null:
		coop_confirm_back_button.disabled = true

	play_menu_click_sound()

	await get_tree().create_timer(0.12).timeout

	disable_main_buttons()

	GameMode.set_two_players()

	if SaveManager != null:
		SaveManager.clear_pending_load()

	PlayerManager.reset_runtime_stats()
	LevelManager.reset_bow_data()
	start_new_game_timer("coop")

	if MusicManager != null and MusicManager.has_method("fade_out"):
		MusicManager.fade_out(0.8, true)

	await get_tree().create_timer(0.25).timeout

	var transition := get_node_or_null("/root/SceneTransition")

	if transition != null and transition.has_method("change_scene_with_fade"):
		await transition.change_scene_with_fade(GAME_SCENE_PATH)
	else:
		get_tree().change_scene_to_file(GAME_SCENE_PATH)
