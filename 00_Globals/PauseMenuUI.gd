extends CanvasLayer

const MAIN_MENU_SCENE_PATH: String = "res://MainMenu/main_menu.tscn"

const MUSIC_BUS_NAME: String = "Music"
const SFX_BUS_NAME: String = "SFX"

const SETTINGS_SAVE_PATH: String = "user://game_settings.cfg"

const ONE_PLAYER_REBIND_ACTIONS: Array[Dictionary] = [
	{"action": "move_left", "label": "Di chuyển trái"},
	{"action": "move_right", "label": "Di chuyển phải"},
	{"action": "jump", "label": "Nhảy"},
	{"action": "attack", "label": "Tấn công"},
	{"action": "interact", "label": "Tương tác"},
	{"action": "use_potion", "label": "Dùng vật phẩm"}
]

const PLAYER_1_REBIND_ACTIONS: Array[Dictionary] = [
	{"action": "p1_move_left", "label": "Trái"},
	{"action": "p1_move_right", "label": "Phải"},
	{"action": "p1_jump", "label": "Nhảy"},
	{"action": "p1_attack", "label": "Tấn công"},
	{"action": "p1_interact", "label": "Tương tác"},
	{"action": "p1_heal", "label": "Dùng vật phẩm"}
]

const PLAYER_2_REBIND_ACTIONS: Array[Dictionary] = [
	{"action": "p2_move_left", "label": "Trái"},
	{"action": "p2_move_right", "label": "Phải"},
	{"action": "p2_jump", "label": "Nhảy"},
	{"action": "p2_attack", "label": "Tấn công"},
	{"action": "p2_interact", "label": "Tương tác"},
	{"action": "p2_heal", "label": "Dùng vật phẩm"}
]

const RESOLUTION_PRESETS: Array[Vector2i] = [
	Vector2i(1920, 1080),
	Vector2i(1600, 900),
	Vector2i(1440, 810),
	Vector2i(1280, 720),
	Vector2i(960, 540),
	Vector2i(854, 480),
	Vector2i(640, 360)
]

const WINDOW_MODE_IDS: Array[String] = [
	"exclusive_fullscreen",
	"fullscreen",
	"windowed"
]

const WINDOW_MODE_LABELS: Array[String] = [
	"Fullscreen",
	"Window Fullscreen",
	"Windowed"
]

var root: Control
var dark_background: ColorRect
var brightness_overlay: ColorRect

var main_panel: Panel
var main_message_label: Label

var settings_panel: Panel
var volume_page: Control
var controls_page: Control
var display_page: Control

var music_slider: HSlider
var sfx_slider: HSlider
var brightness_slider: HSlider

var volume_tab_button: Button
var controls_tab_button: Button
var display_tab_button: Button

var one_player_controls_button: Button
var two_player_controls_button: Button

var controls_scroll: ScrollContainer
var controls_content: Control

var resolution_button: Button
var window_mode_button: Button

var rebind_buttons: Dictionary = {}

var is_pause_open: bool = false
var waiting_rebind_action: String = ""

var controls_mode: String = "one_player"

var current_resolution_index: int = 0
var current_window_mode_id: String = "fullscreen"
var current_brightness_percent: float = 100.0

var save_panel: Panel
var save_message_label: Label
var save_slot_rows: Array = []
var is_saving_slot: bool = false
var overwrite_confirm_panel: Panel
var overwrite_confirm_message_label: Label
var pending_overwrite_slot: int = -1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 3000

	ensure_default_input_actions()
	load_settings()
	create_ui()
	apply_loaded_display_settings()

	root.visible = false


func _input(event: InputEvent) -> void:
	if is_current_scene_main_menu():
		return
		
	if is_you_died_ui_visible():
		return
	if waiting_rebind_action != "":
		handle_rebind_input(event)
		return

	if is_pause_event(event):
		get_viewport().set_input_as_handled()

		if is_pause_open:
			if settings_panel.visible:
				show_main_panel()
			elif save_panel != null and save_panel.visible:
				show_main_panel()
			else:
				resume_game()
		else:
			open_pause_menu()


func is_pause_event(event: InputEvent) -> bool:
	if InputMap.has_action("pause"):
		if event.is_action_pressed("pause"):
			return true

	if event is InputEventKey:
		if event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			return true

	return false

func is_you_died_ui_visible() -> bool:
	var current_scene := get_tree().current_scene

	if current_scene == null:
		return false

	var you_died_ui := find_node_by_name_recursive(current_scene, "YouDiedUI")

	if you_died_ui == null:
		return false

	if you_died_ui is CanvasItem:
		return (you_died_ui as CanvasItem).visible

	return false


func find_node_by_name_recursive(parent: Node, target_name: String) -> Node:
	if parent == null:
		return null

	if parent.name == target_name:
		return parent

	for child in parent.get_children():
		var found := find_node_by_name_recursive(child, target_name)

		if found != null:
			return found

	return null
func is_current_scene_main_menu() -> bool:
	if get_tree().current_scene == null:
		return false

	var scene_path: String = get_tree().current_scene.scene_file_path
	var scene_name: String = get_tree().current_scene.name.to_lower()

	if scene_path == MAIN_MENU_SCENE_PATH:
		return true

	if scene_name.contains("mainmenu") or scene_name.contains("main_menu"):
		return true

	return false


func create_ui() -> void:
	brightness_overlay = ColorRect.new()
	brightness_overlay.name = "BrightnessOverlay"
	add_child(brightness_overlay)

	brightness_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	brightness_overlay.z_index = 4096
	brightness_overlay.z_as_relative = false

	update_brightness_overlay()

	root = Control.new()
	root.name = "PauseMenuRoot"
	add_child(root)

	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.process_mode = Node.PROCESS_MODE_ALWAYS

	dark_background = ColorRect.new()
	dark_background.name = "DarkBackground"
	root.add_child(dark_background)

	dark_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	dark_background.color = Color(0, 0, 0, 0.76)
	dark_background.mouse_filter = Control.MOUSE_FILTER_STOP

	create_main_panel()
	create_settings_panel()
	create_save_panel()
	create_overwrite_confirm_panel()
	set_process_mode_always_recursive(root)


func create_main_panel() -> void:
	main_panel = Panel.new()
	main_panel.name = "MainPausePanel"
	root.add_child(main_panel)

	main_panel.size = Vector2(230, 210)
	main_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	main_panel.add_theme_stylebox_override("panel", create_panel_style())

	var title_label := Label.new()
	title_label.text = "TẠM DỪNG"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.35))
	main_panel.add_child(title_label)
	title_label.position = Vector2(20, 14)
	title_label.size = Vector2(190, 26)

	var continue_button := create_menu_button("Tiếp tục", Vector2(45, 52), main_panel)
	continue_button.pressed.connect(resume_game)

	var settings_button := create_menu_button("Cài đặt", Vector2(45, 84), main_panel)
	settings_button.pressed.connect(open_settings_menu)

	var save_button := create_menu_button("Lưu dữ liệu", Vector2(45, 116), main_panel)
	save_button.pressed.connect(_on_save_pressed)

	var menu_button := create_menu_button("Quay lại Menu", Vector2(45, 148), main_panel)
	menu_button.pressed.connect(_on_back_to_menu_pressed)

	main_message_label = Label.new()
	main_message_label.text = ""
	main_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	main_message_label.add_theme_font_size_override("font_size", 9)
	main_message_label.add_theme_color_override("font_color", Color(1.0, 0.62, 0.32))
	main_panel.add_child(main_message_label)
	main_message_label.position = Vector2(12, 178)
	main_message_label.size = Vector2(206, 20)

	center_main_panel()


func create_settings_panel() -> void:
	settings_panel = Panel.new()
	settings_panel.name = "SettingsPanel"
	root.add_child(settings_panel)

	settings_panel.size = Vector2(460, 250)
	settings_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	settings_panel.visible = false
	settings_panel.add_theme_stylebox_override("panel", create_panel_style())

	var title_label := Label.new()
	title_label.text = "CÀI ĐẶT"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.35))
	settings_panel.add_child(title_label)
	title_label.position = Vector2(20, 6)
	title_label.size = Vector2(420, 28)

	volume_tab_button = create_tab_button("Âm thanh", Vector2(28, 40))
	volume_tab_button.pressed.connect(show_volume_page)

	controls_tab_button = create_tab_button("Nút bấm", Vector2(170, 40))
	controls_tab_button.pressed.connect(show_controls_page)

	display_tab_button = create_tab_button("Hiển thị", Vector2(312, 40))
	display_tab_button.pressed.connect(show_display_page)

	create_volume_page()
	create_controls_page()
	create_display_page()

	var back_button := Button.new()
	back_button.text = "Quay lại"
	back_button.add_theme_font_size_override("font_size", 10)
	settings_panel.add_child(back_button)
	back_button.position = Vector2(176, 220)
	back_button.size = Vector2(108, 22)
	back_button.pressed.connect(show_main_panel)

	center_settings_panel()


func create_tab_button(text: String, pos: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", 10)
	settings_panel.add_child(button)
	button.position = pos
	button.size = Vector2(120, 24)
	return button


func create_volume_page() -> void:
	volume_page = Control.new()
	volume_page.name = "VolumePage"
	settings_panel.add_child(volume_page)

	volume_page.position = Vector2(52, 88)
	volume_page.size = Vector2(356, 115)

	var music_label := Label.new()
	music_label.text = "Nhạc nền"
	music_label.add_theme_font_size_override("font_size", 12)
	volume_page.add_child(music_label)
	music_label.position = Vector2(0, 6)
	music_label.size = Vector2(110, 24)

	music_slider = HSlider.new()
	volume_page.add_child(music_slider)
	music_slider.position = Vector2(120, 8)
	music_slider.size = Vector2(225, 20)
	music_slider.min_value = 0
	music_slider.max_value = 100
	music_slider.step = 1
	music_slider.value = get_bus_volume_percent(MUSIC_BUS_NAME)
	music_slider.value_changed.connect(_on_music_volume_changed)

	var sfx_label := Label.new()
	sfx_label.text = "Hiệu ứng"
	sfx_label.add_theme_font_size_override("font_size", 12)
	volume_page.add_child(sfx_label)
	sfx_label.position = Vector2(0, 58)
	sfx_label.size = Vector2(110, 24)

	sfx_slider = HSlider.new()
	volume_page.add_child(sfx_slider)
	sfx_slider.position = Vector2(120, 60)
	sfx_slider.size = Vector2(225, 20)
	sfx_slider.min_value = 0
	sfx_slider.max_value = 100
	sfx_slider.step = 1
	sfx_slider.value = get_bus_volume_percent(SFX_BUS_NAME)
	sfx_slider.value_changed.connect(_on_sfx_volume_changed)


func create_controls_page() -> void:
	controls_page = Control.new()
	controls_page.name = "ControlsPage"
	settings_panel.add_child(controls_page)

	controls_page.position = Vector2(18, 72)
	controls_page.size = Vector2(424, 142)
	controls_page.visible = false

	one_player_controls_button = Button.new()
	one_player_controls_button.text = "1 người chơi"
	one_player_controls_button.add_theme_font_size_override("font_size", 10)
	controls_page.add_child(one_player_controls_button)
	one_player_controls_button.position = Vector2(52, 0)
	one_player_controls_button.size = Vector2(128, 23)
	one_player_controls_button.pressed.connect(show_one_player_controls)

	two_player_controls_button = Button.new()
	two_player_controls_button.text = "2 người chơi"
	two_player_controls_button.add_theme_font_size_override("font_size", 10)
	controls_page.add_child(two_player_controls_button)
	two_player_controls_button.position = Vector2(244, 0)
	two_player_controls_button.size = Vector2(128, 23)
	two_player_controls_button.pressed.connect(show_two_player_controls)

	controls_scroll = ScrollContainer.new()
	controls_scroll.name = "ControlsScroll"
	controls_page.add_child(controls_scroll)

	controls_scroll.position = Vector2(0, 30)
	controls_scroll.size = Vector2(424, 108)
	controls_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	controls_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	controls_scroll.mouse_filter = Control.MOUSE_FILTER_STOP

	controls_content = Control.new()
	controls_content.name = "ControlsContent"
	controls_scroll.add_child(controls_content)

	controls_content.custom_minimum_size = Vector2(424, 240)

	create_controls_content()


func create_controls_content() -> void:
	if controls_content == null:
		return

	for child in controls_content.get_children():
		child.free()

	rebind_buttons.clear()

	if controls_mode == "one_player":
		create_one_player_controls_content()
	else:
		create_two_player_controls_content()

	update_rebind_button_texts()


func create_one_player_controls_content() -> void:
	controls_content.custom_minimum_size = Vector2(424, 225)

	var title := Label.new()
	title.text = "Cài đặt nút bấm - 1 người chơi"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 11)
	title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.35))
	controls_content.add_child(title)
	title.position = Vector2(30, 0)
	title.size = Vector2(364, 22)

	var start_y: float = 31.0

	for item in ONE_PLAYER_REBIND_ACTIONS:
		var action_name: String = String(item["action"])
		var label_text: String = String(item["label"])

		create_rebind_row(
			controls_content,
			action_name,
			label_text,
			Vector2(42, start_y),
			130,
			190
		)

		start_y += 31.0


func create_two_player_controls_content() -> void:
	controls_content.custom_minimum_size = Vector2(424, 225)

	var p1_title := Label.new()
	p1_title.text = "PLAYER 1"
	p1_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p1_title.add_theme_font_size_override("font_size", 11)
	p1_title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.35))
	controls_content.add_child(p1_title)
	p1_title.position = Vector2(0, 0)
	p1_title.size = Vector2(204, 22)

	var p2_title := Label.new()
	p2_title.text = "PLAYER 2"
	p2_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p2_title.add_theme_font_size_override("font_size", 11)
	p2_title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.35))
	controls_content.add_child(p2_title)
	p2_title.position = Vector2(216, 0)
	p2_title.size = Vector2(204, 22)

	var start_y: float = 31.0

	for item in PLAYER_1_REBIND_ACTIONS:
		var action_name: String = String(item["action"])
		var label_text: String = String(item["label"])

		create_rebind_row(
			controls_content,
			action_name,
			label_text,
			Vector2(0, start_y),
			72,
			124
		)

		start_y += 31.0

	start_y = 31.0

	for item in PLAYER_2_REBIND_ACTIONS:
		var action_name_2: String = String(item["action"])
		var label_text_2: String = String(item["label"])

		create_rebind_row(
			controls_content,
			action_name_2,
			label_text_2,
			Vector2(216, start_y),
			72,
			124
		)

		start_y += 31.0


func create_rebind_row(
	parent: Control,
	action_name: String,
	label_text: String,
	pos: Vector2,
	label_width: float,
	button_width: float
) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)

	var action_label := Label.new()
	action_label.text = label_text
	action_label.add_theme_font_size_override("font_size", 10)
	action_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	parent.add_child(action_label)

	action_label.position = pos
	action_label.size = Vector2(label_width, 25)

	var rebind_button := Button.new()
	rebind_button.add_theme_font_size_override("font_size", 10)
	parent.add_child(rebind_button)

	rebind_button.position = Vector2(pos.x + label_width + 8, pos.y)
	rebind_button.size = Vector2(button_width, 25)
	rebind_button.pressed.connect(_on_rebind_button_pressed.bind(action_name))

	rebind_buttons[action_name] = rebind_button


func create_display_page() -> void:
	display_page = Control.new()
	display_page.name = "DisplayPage"
	settings_panel.add_child(display_page)

	display_page.position = Vector2(48, 82)
	display_page.size = Vector2(370, 130)
	display_page.visible = false

	var resolution_label := Label.new()
	resolution_label.text = "Độ phân giải"
	resolution_label.add_theme_font_size_override("font_size", 11)
	display_page.add_child(resolution_label)
	resolution_label.position = Vector2(0, 0)
	resolution_label.size = Vector2(125, 25)

	resolution_button = Button.new()
	resolution_button.add_theme_font_size_override("font_size", 10)
	display_page.add_child(resolution_button)
	resolution_button.position = Vector2(135, 0)
	resolution_button.size = Vector2(220, 26)
	resolution_button.pressed.connect(_on_resolution_button_pressed)

	var window_mode_label := Label.new()
	window_mode_label.text = "Chế độ màn hình"
	window_mode_label.add_theme_font_size_override("font_size", 11)
	display_page.add_child(window_mode_label)
	window_mode_label.position = Vector2(0, 43)
	window_mode_label.size = Vector2(130, 25)

	window_mode_button = Button.new()
	window_mode_button.add_theme_font_size_override("font_size", 10)
	display_page.add_child(window_mode_button)
	window_mode_button.position = Vector2(135, 43)
	window_mode_button.size = Vector2(220, 26)
	window_mode_button.pressed.connect(_on_window_mode_button_pressed)

	var brightness_label := Label.new()
	brightness_label.text = "Độ sáng"
	brightness_label.add_theme_font_size_override("font_size", 11)
	display_page.add_child(brightness_label)
	brightness_label.position = Vector2(0, 86)
	brightness_label.size = Vector2(125, 25)

	brightness_slider = HSlider.new()
	display_page.add_child(brightness_slider)
	brightness_slider.position = Vector2(135, 88)
	brightness_slider.size = Vector2(220, 18)
	brightness_slider.min_value = 20
	brightness_slider.max_value = 100
	brightness_slider.step = 1
	brightness_slider.value = current_brightness_percent
	brightness_slider.value_changed.connect(_on_brightness_changed)

	var note_label := Label.new()
	note_label.text = "Fullscreen sẽ khóa độ phân giải ở 1920x1080."
	note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note_label.add_theme_font_size_override("font_size", 8)
	note_label.add_theme_color_override("font_color", Color(1.0, 0.76, 0.48))
	display_page.add_child(note_label)
	note_label.position = Vector2(0, 116)
	note_label.size = Vector2(365, 18)

	update_resolution_button_text()
	update_window_mode_button_text()


func _on_resolution_button_pressed() -> void:
	if is_fullscreen_mode():
		current_resolution_index = 0
		update_resolution_button_text()
		return

	current_resolution_index += 1

	if current_resolution_index >= RESOLUTION_PRESETS.size():
		current_resolution_index = 0

	apply_resolution()
	update_brightness_overlay()
	update_resolution_button_text()
	save_settings()


func _on_window_mode_button_pressed() -> void:
	var current_index: int = get_window_mode_index(current_window_mode_id)
	current_index += 1

	if current_index >= WINDOW_MODE_IDS.size():
		current_index = 0

	current_window_mode_id = WINDOW_MODE_IDS[current_index]

	if is_fullscreen_mode():
		current_resolution_index = 0

	apply_window_mode()
	apply_resolution()
	update_brightness_overlay()
	update_window_mode_button_text()
	update_resolution_button_text()
	save_settings()


func update_resolution_button_text() -> void:
	if resolution_button == null:
		return

	if is_fullscreen_mode():
		current_resolution_index = 0
		resolution_button.text = "1920 x 1080 (khóa)"
		resolution_button.disabled = true
		return

	resolution_button.disabled = false
	current_resolution_index = clamp(current_resolution_index, 0, RESOLUTION_PRESETS.size() - 1)

	var resolution: Vector2i = RESOLUTION_PRESETS[current_resolution_index]
	resolution_button.text = str(resolution.x) + " x " + str(resolution.y)


func update_window_mode_button_text() -> void:
	if window_mode_button == null:
		return

	var index: int = get_window_mode_index(current_window_mode_id)
	window_mode_button.text = WINDOW_MODE_LABELS[index]


func create_menu_button(text: String, pos: Vector2, parent: Control) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", 10)
	parent.add_child(button)
	button.position = pos
	button.size = Vector2(140, 24)
	return button


func create_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()

	style.bg_color = Color(0.08, 0.055, 0.04, 0.97)
	style.border_color = Color(1.0, 0.62, 0.22, 1.0)

	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2

	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8

	return style


func center_main_panel() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	main_panel.position = (viewport_size - main_panel.size) * 0.5


func center_settings_panel() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	settings_panel.position = (viewport_size - settings_panel.size) * 0.5


func center_save_panel() -> void:
	if save_panel == null:
		return

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	save_panel.position = (viewport_size - save_panel.size) * 0.5


func set_process_mode_always_recursive(node: Node) -> void:
	node.process_mode = Node.PROCESS_MODE_ALWAYS

	for child in node.get_children():
		set_process_mode_always_recursive(child)


func open_pause_menu() -> void:
	if is_pause_open:
		return

	is_pause_open = true
	get_tree().paused = true

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	main_message_label.text = ""

	center_main_panel()
	center_settings_panel()
	center_save_panel()
	center_overwrite_confirm_panel()
	root.visible = true
	show_main_panel()


func resume_game() -> void:
	is_pause_open = false
	waiting_rebind_action = ""

	root.visible = false
	get_tree().paused = false

	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)


func show_main_panel() -> void:
	hide_overwrite_confirm()
	main_panel.visible = true
	settings_panel.visible = false

	if save_panel != null:
		save_panel.visible = false

	waiting_rebind_action = ""
	update_rebind_button_texts()


func open_settings_menu() -> void:
	main_panel.visible = false
	settings_panel.visible = true
	show_volume_page()


func show_volume_page() -> void:
	volume_page.visible = true
	controls_page.visible = false
	display_page.visible = false

	volume_tab_button.disabled = true
	controls_tab_button.disabled = false
	display_tab_button.disabled = false

	waiting_rebind_action = ""
	update_rebind_button_texts()


func show_controls_page() -> void:
	volume_page.visible = false
	controls_page.visible = true
	display_page.visible = false

	volume_tab_button.disabled = false
	controls_tab_button.disabled = true
	display_tab_button.disabled = false

	waiting_rebind_action = ""
	create_controls_content()


func show_display_page() -> void:
	volume_page.visible = false
	controls_page.visible = false
	display_page.visible = true

	volume_tab_button.disabled = false
	controls_tab_button.disabled = false
	display_tab_button.disabled = true

	waiting_rebind_action = ""
	update_rebind_button_texts()


func show_one_player_controls() -> void:
	controls_mode = "one_player"
	one_player_controls_button.disabled = true
	two_player_controls_button.disabled = false
	waiting_rebind_action = ""
	create_controls_content()


func show_two_player_controls() -> void:
	controls_mode = "two_player"
	one_player_controls_button.disabled = false
	two_player_controls_button.disabled = true
	waiting_rebind_action = ""
	create_controls_content()


func _on_save_pressed() -> void:
	open_save_menu()


func _on_back_to_menu_pressed() -> void:
	is_pause_open = false
	waiting_rebind_action = ""

	root.visible = false
	get_tree().paused = false

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	var transition := get_node_or_null("/root/SceneTransition")

	if transition != null and transition.has_method("change_scene_with_fade"):
		await transition.change_scene_with_fade(
			MAIN_MENU_SCENE_PATH,
			0.5,
			0.5
		)
	else:
		get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)


func _on_music_volume_changed(value: float) -> void:
	set_bus_volume_percent(MUSIC_BUS_NAME, value)
	save_settings()


func _on_sfx_volume_changed(value: float) -> void:
	set_bus_volume_percent(SFX_BUS_NAME, value)
	save_settings()


func get_bus_index(bus_name: String) -> int:
	var index: int = AudioServer.get_bus_index(bus_name)

	if index == -1:
		index = AudioServer.get_bus_index("Master")

	return index


func set_bus_volume_percent(bus_name: String, percent: float) -> void:
	var bus_index: int = get_bus_index(bus_name)

	if bus_index == -1:
		return

	percent = clamp(percent, 0.0, 100.0)

	if percent <= 0.0:
		AudioServer.set_bus_mute(bus_index, true)
		AudioServer.set_bus_volume_db(bus_index, -80.0)
		return

	AudioServer.set_bus_mute(bus_index, false)

	var linear_value: float = percent / 100.0
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(linear_value))


func get_bus_volume_percent(bus_name: String) -> float:
	var bus_index: int = get_bus_index(bus_name)

	if bus_index == -1:
		return 100.0

	if AudioServer.is_bus_mute(bus_index):
		return 0.0

	var db_value: float = AudioServer.get_bus_volume_db(bus_index)
	var linear_value: float = db_to_linear(db_value)

	return clamp(linear_value * 100.0, 0.0, 100.0)


func _on_brightness_changed(value: float) -> void:
	current_brightness_percent = clamp(value, 20.0, 100.0)

	update_brightness_overlay()
	save_settings()


func get_brightness_overlay_alpha() -> float:
	return clamp(1.0 - current_brightness_percent / 100.0, 0.0, 0.82)
func update_brightness_overlay() -> void:
	if brightness_overlay == null:
		return

	refresh_brightness_overlay_rect()

	var alpha_value: float = get_brightness_overlay_alpha()

	brightness_overlay.color = Color(0, 0, 0, alpha_value)
	brightness_overlay.visible = alpha_value > 0.0

	# Đưa lớp giảm sáng lên trên cùng để chắc chắn nhìn thấy.
	brightness_overlay.z_index = 4096
	brightness_overlay.z_as_relative = false

func apply_loaded_display_settings() -> void:
	if not WINDOW_MODE_IDS.has(current_window_mode_id):
		current_window_mode_id = "fullscreen"

	if is_fullscreen_mode():
		current_resolution_index = 0

	apply_window_mode()
	apply_resolution()
	update_brightness_overlay()
	update_brightness_overlay()

func apply_window_mode() -> void:
	match current_window_mode_id:
		"exclusive_fullscreen":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		"fullscreen":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		"windowed":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		_:
			current_window_mode_id = "fullscreen"
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func apply_resolution() -> void:
	current_resolution_index = clamp(current_resolution_index, 0, RESOLUTION_PRESETS.size() - 1)

	if is_fullscreen_mode():
		current_resolution_index = 0
		return

	var resolution: Vector2i = RESOLUTION_PRESETS[current_resolution_index]

	if current_window_mode_id == "windowed":
		DisplayServer.window_set_size(resolution)
		center_window_on_screen()


func is_fullscreen_mode() -> bool:
	return current_window_mode_id == "exclusive_fullscreen" or current_window_mode_id == "fullscreen"


func center_window_on_screen() -> void:
	var screen_size: Vector2i = DisplayServer.screen_get_size()
	var window_size: Vector2i = DisplayServer.window_get_size()
	var position := Vector2i(
		int((screen_size.x - window_size.x) * 0.5),
		int((screen_size.y - window_size.y) * 0.5)
	)

	DisplayServer.window_set_position(position)


func get_window_mode_index(mode_id: String) -> int:
	for i in range(WINDOW_MODE_IDS.size()):
		if WINDOW_MODE_IDS[i] == mode_id:
			return i

	return 1


func _on_rebind_button_pressed(action_name: String) -> void:
	waiting_rebind_action = ""

	update_rebind_button_texts()

	if rebind_buttons.has(action_name):
		var button: Button = rebind_buttons[action_name] as Button

		if button != null:
			button.text = "Nhấn phím..."

	call_deferred("_begin_rebind", action_name)


func _begin_rebind(action_name: String) -> void:
	waiting_rebind_action = action_name


func handle_rebind_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		return

	if event is InputEventKey:
		if not event.pressed:
			return

		if event.echo:
			return

		get_viewport().set_input_as_handled()

		if event.keycode == KEY_ESCAPE:
			waiting_rebind_action = ""
			update_rebind_button_texts()
			return

		apply_new_input_event(waiting_rebind_action, event)
		return

	if event is InputEventMouseButton:
		if not event.pressed:
			return

		get_viewport().set_input_as_handled()
		apply_new_input_event(waiting_rebind_action, event)


func apply_new_input_event(action_name: String, event: InputEvent) -> void:
	if action_name == "":
		return

	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)

	var new_event: InputEvent = event.duplicate()

	InputMap.action_erase_events(action_name)
	InputMap.action_add_event(action_name, new_event)

	waiting_rebind_action = ""
	update_rebind_button_texts()
	save_settings()


func update_rebind_button_texts() -> void:
	for action_name in rebind_buttons.keys():
		var button: Button = rebind_buttons[action_name] as Button

		if button == null:
			continue

		button.text = get_action_input_text(String(action_name))


func get_action_input_text(action_name: String) -> String:
	if not InputMap.has_action(action_name):
		return "Chưa gán"

	var events: Array[InputEvent] = InputMap.action_get_events(action_name)

	if events.is_empty():
		return "Chưa gán"

	var text: String = events[0].as_text()
	text = text.replace(" (Physical)", "")
	text = text.replace(" - Physical", "")

	if text == "Left Mouse Button":
		return "Chuột trái"

	if text == "Right Mouse Button":
		return "Chuột phải"

	if text == "Middle Mouse Button":
		return "Chuột giữa"

	if text == "Mouse Wheel Up":
		return "Cuộn lên"

	if text == "Mouse Wheel Down":
		return "Cuộn xuống"

	if text == "Ctrl":
		return "Ctrl"

	if text == "Left":
		return "Mũi tên trái"

	if text == "Right":
		return "Mũi tên phải"

	if text == "Up":
		return "Mũi tên lên"

	if text == "Down":
		return "Mũi tên xuống"

	return text


func get_all_rebind_action_names() -> Array[String]:
	var result: Array[String] = []

	for item in ONE_PLAYER_REBIND_ACTIONS:
		result.append(String(item["action"]))

	for item in PLAYER_1_REBIND_ACTIONS:
		result.append(String(item["action"]))

	for item in PLAYER_2_REBIND_ACTIONS:
		result.append(String(item["action"]))

	return result


func save_settings() -> void:
	var config := ConfigFile.new()

	config.set_value("audio", "music", get_bus_volume_percent(MUSIC_BUS_NAME))
	config.set_value("audio", "sfx", get_bus_volume_percent(SFX_BUS_NAME))

	config.set_value("display", "resolution_index", current_resolution_index)
	config.set_value("display", "window_mode", current_window_mode_id)
	config.set_value("display", "brightness", current_brightness_percent)

	for action_name in get_all_rebind_action_names():
		if not InputMap.has_action(action_name):
			continue

		var events: Array[InputEvent] = InputMap.action_get_events(action_name)

		if events.is_empty():
			continue

		config.set_value("controls", action_name, events[0])

	config.save(SETTINGS_SAVE_PATH)


func load_settings() -> void:
	var config := ConfigFile.new()
	var error: int = config.load(SETTINGS_SAVE_PATH)

	if error != OK:
		return

	var music_value: float = float(config.get_value("audio", "music", get_bus_volume_percent(MUSIC_BUS_NAME)))
	var sfx_value: float = float(config.get_value("audio", "sfx", get_bus_volume_percent(SFX_BUS_NAME)))

	set_bus_volume_percent(MUSIC_BUS_NAME, music_value)
	set_bus_volume_percent(SFX_BUS_NAME, sfx_value)

	current_resolution_index = int(config.get_value("display", "resolution_index", 0))
	current_resolution_index = clamp(current_resolution_index, 0, RESOLUTION_PRESETS.size() - 1)

	current_window_mode_id = String(config.get_value("display", "window_mode", "fullscreen"))

	if not WINDOW_MODE_IDS.has(current_window_mode_id):
		current_window_mode_id = "fullscreen"

	current_brightness_percent = float(config.get_value("display", "brightness", 100.0))
	current_brightness_percent = clamp(current_brightness_percent, 20.0, 100.0)

	if is_fullscreen_mode():
		current_resolution_index = 0

	for action_name in get_all_rebind_action_names():
		if not config.has_section_key("controls", action_name):
			continue

		var input_event = config.get_value("controls", action_name)

		if input_event == null:
			continue

		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)

		InputMap.action_erase_events(action_name)
		InputMap.action_add_event(action_name, input_event)


func create_save_panel() -> void:
	save_panel = Panel.new()
	save_panel.name = "SavePanel"
	root.add_child(save_panel)

	save_panel.size = Vector2(380, 220)
	save_panel.visible = false
	save_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	save_panel.add_theme_stylebox_override("panel", create_panel_style())

	var title := Label.new()
	title.text = "LƯU DỮ LIỆU"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color(1.0, 0.78, 0.32))
	save_panel.add_child(title)
	title.position = Vector2(20, 8)
	title.size = Vector2(340, 24)

	var start_y: float = 40.0

	for slot in range(1, SaveManager.MAX_SAVE_SLOTS + 1):
		var row := Panel.new()
		row.name = "SaveSlot%d" % slot
		save_panel.add_child(row)

		row.position = Vector2(18, start_y)
		row.size = Vector2(344, 32)
		row.add_theme_stylebox_override("panel", create_slot_style_for_save())

		var label := Label.new()
		row.add_child(label)
		label.position = Vector2(10, 3)
		label.size = Vector2(230, 26)
		label.add_theme_font_size_override("font_size", 8)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

		var button := Button.new()
		row.add_child(button)
		button.position = Vector2(258, 5)
		button.size = Vector2(70, 22)
		button.text = "Lưu"
		button.add_theme_font_size_override("font_size", 8)
		button.pressed.connect(_on_save_slot_pressed.bind(slot))

		save_slot_rows.append({
			"slot": slot,
			"label": label,
			"button": button
		})

		start_y += 35.0

	save_message_label = Label.new()
	save_panel.add_child(save_message_label)

	save_message_label.text = ""
	save_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	save_message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	save_message_label.add_theme_font_size_override("font_size", 8)
	save_message_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.28))
	save_message_label.position = Vector2(20, 181)
	save_message_label.size = Vector2(340, 18)

	var back_button := Button.new()
	back_button.text = "Quay lại"
	back_button.add_theme_font_size_override("font_size", 8)
	save_panel.add_child(back_button)
	back_button.position = Vector2(140, 199)
	back_button.size = Vector2(100, 18)
	back_button.pressed.connect(show_main_panel)

	center_save_panel()


func create_slot_style_for_save() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.32)
	style.border_color = Color(1.0, 1.0, 1.0, 0.12)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	return style


func open_save_menu() -> void:
	hide_overwrite_confirm()
	main_panel.visible = false
	settings_panel.visible = false
	save_panel.visible = true

	save_message_label.text = ""
	is_saving_slot = false

	center_save_panel()
	refresh_save_slots()


func refresh_save_slots() -> void:
	for row_data in save_slot_rows:
		var slot: int = int(row_data["slot"])
		var label: Label = row_data["label"] as Label
		var button: Button = row_data["button"] as Button

		if label == null or button == null:
			continue

		var info: Dictionary = SaveManager.get_slot_info(slot)

		if bool(info.get("exists", false)):
			label.text = "File %d - %s" % [
				slot,
				String(info.get("saved_at", "Không rõ thời gian"))
			]
			button.text = "Ghi đè"
		else:
			label.text = "File %d - Chưa có dữ liệu" % slot
			button.text = "Lưu"


func _on_save_slot_pressed(slot: int) -> void:
	if is_saving_slot:
		return

	var info: Dictionary = SaveManager.get_slot_info(slot)

	if bool(info.get("exists", false)):
		show_overwrite_confirm(slot)
		return

	await save_to_slot(slot)
func refresh_brightness_overlay_rect() -> void:
	if brightness_overlay == null:
		return

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size

	brightness_overlay.position = Vector2.ZERO
	brightness_overlay.size = viewport_size

	brightness_overlay.offset_left = 0
	brightness_overlay.offset_top = 0
	brightness_overlay.offset_right = viewport_size.x
	brightness_overlay.offset_bottom = viewport_size.y
func create_overwrite_confirm_panel() -> void:
	overwrite_confirm_panel = Panel.new()
	overwrite_confirm_panel.name = "OverwriteConfirmPanel"
	root.add_child(overwrite_confirm_panel)

	overwrite_confirm_panel.size = Vector2(300, 125)
	overwrite_confirm_panel.visible = false
	overwrite_confirm_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	overwrite_confirm_panel.z_index = 50
	overwrite_confirm_panel.add_theme_stylebox_override("panel", create_panel_style())

	overwrite_confirm_message_label = Label.new()
	overwrite_confirm_panel.add_child(overwrite_confirm_message_label)

	overwrite_confirm_message_label.text = ""
	overwrite_confirm_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overwrite_confirm_message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	overwrite_confirm_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	overwrite_confirm_message_label.add_theme_font_size_override("font_size", 10)
	overwrite_confirm_message_label.add_theme_color_override("font_color", Color.WHITE)
	overwrite_confirm_message_label.position = Vector2(18, 16)
	overwrite_confirm_message_label.size = Vector2(264, 48)

	var yes_button := Button.new()
	yes_button.text = "Có"
	yes_button.add_theme_font_size_override("font_size", 9)
	overwrite_confirm_panel.add_child(yes_button)
	yes_button.position = Vector2(58, 78)
	yes_button.size = Vector2(75, 24)
	yes_button.pressed.connect(_on_confirm_overwrite_yes_pressed)

	var no_button := Button.new()
	no_button.text = "Không"
	no_button.add_theme_font_size_override("font_size", 9)
	overwrite_confirm_panel.add_child(no_button)
	no_button.position = Vector2(166, 78)
	no_button.size = Vector2(75, 24)
	no_button.pressed.connect(_on_confirm_overwrite_no_pressed)

	center_overwrite_confirm_panel()
func center_overwrite_confirm_panel() -> void:
	if overwrite_confirm_panel == null:
		return

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	overwrite_confirm_panel.position = (viewport_size - overwrite_confirm_panel.size) * 0.5
func show_overwrite_confirm(slot: int) -> void:
	pending_overwrite_slot = slot

	if overwrite_confirm_message_label != null:
		overwrite_confirm_message_label.text = "File %d đã có dữ liệu.\nBạn có muốn ghi đè dữ liệu không?" % slot

	if save_message_label != null:
		save_message_label.text = ""

	center_overwrite_confirm_panel()

	if overwrite_confirm_panel != null:
		overwrite_confirm_panel.visible = true


func hide_overwrite_confirm() -> void:
	pending_overwrite_slot = -1

	if overwrite_confirm_panel != null:
		overwrite_confirm_panel.visible = false
func save_to_slot(slot: int) -> void:
	if is_saving_slot:
		return

	is_saving_slot = true
	save_message_label.text = "Đang lưu dữ liệu..."

	root.visible = false

	await get_tree().process_frame

	var success: bool = await SaveManager.save_slot(slot)

	root.visible = true
	save_panel.visible = true
	main_panel.visible = false
	settings_panel.visible = false

	if success:
		save_message_label.text = "Đã lưu vào File %d." % slot
	else:
		var error_text: String = ""

		if SaveManager.has_method("get_last_save_error"):
			error_text = SaveManager.get_last_save_error()

		if error_text != "":
			save_message_label.text = error_text
		else:
			save_message_label.text = "Lưu dữ liệu thất bại."

	refresh_save_slots()

	is_saving_slot = false
func _on_confirm_overwrite_yes_pressed() -> void:
	if pending_overwrite_slot <= 0:
		hide_overwrite_confirm()
		return

	var slot: int = pending_overwrite_slot

	hide_overwrite_confirm()

	await save_to_slot(slot)


func _on_confirm_overwrite_no_pressed() -> void:
	hide_overwrite_confirm()

	if save_message_label != null:
		save_message_label.text = "Đã hủy ghi đè dữ liệu."
func ensure_default_input_actions() -> void:
	ensure_key_action("p1_heal", KEY_R)
	ensure_key_action("p2_heal", KEY_CTRL)


func ensure_key_action(action_name: String, keycode_value) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)

	var events: Array[InputEvent] = InputMap.action_get_events(action_name)

	if !events.is_empty():
		return

	var key_event := InputEventKey.new()
	key_event.physical_keycode = keycode_value

	InputMap.action_add_event(action_name, key_event)
