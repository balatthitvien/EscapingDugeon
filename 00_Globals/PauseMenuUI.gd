extends CanvasLayer

const MAIN_MENU_SCENE_PATH: String = "res://MainMenu/main_menu.tscn"

const MUSIC_BUS_NAME: String = "Music"
const SFX_BUS_NAME: String = "SFX"

const REBIND_ACTIONS: Array[Dictionary] = [
	{"action": "move_left", "label": "Di chuyển trái"},
	{"action": "move_right", "label": "Di chuyển phải"},
	{"action": "jump", "label": "Nhảy"},
	{"action": "attack", "label": "Tấn công"}
]

var root: Control
var dark_background: ColorRect

var main_panel: Panel
var main_message_label: Label

var settings_panel: Panel
var volume_page: Control
var controls_page: Control

var music_slider: HSlider
var sfx_slider: HSlider

var volume_tab_button: Button
var controls_tab_button: Button

var rebind_buttons: Dictionary = {}

var is_pause_open: bool = false
var waiting_rebind_action: String = ""
var save_panel: Panel
var save_message_label: Label
var save_slot_rows: Array = []
var is_saving_slot: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 3000

	create_ui()
	root.visible = false


func _input(event: InputEvent) -> void:
	if is_current_scene_main_menu():
		return

	if waiting_rebind_action != "":
		handle_rebind_input(event)
		return

	if is_pause_event(event):
		get_viewport().set_input_as_handled()

		if is_pause_open:
			if settings_panel.visible:
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
	dark_background.color = Color(0, 0, 0, 0.72)
	dark_background.mouse_filter = Control.MOUSE_FILTER_STOP

	create_main_panel()
	create_settings_panel()
	create_save_panel()
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

	settings_panel.size = Vector2(400, 230)
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
	title_label.position = Vector2(20, 8)
	title_label.size = Vector2(360, 24)

	volume_tab_button = Button.new()
	volume_tab_button.text = "Âm lượng"
	volume_tab_button.add_theme_font_size_override("font_size", 9)
	settings_panel.add_child(volume_tab_button)
	volume_tab_button.position = Vector2(76, 40)
	volume_tab_button.size = Vector2(105, 24)
	volume_tab_button.pressed.connect(show_volume_page)

	controls_tab_button = Button.new()
	controls_tab_button.text = "Nút bấm"
	controls_tab_button.add_theme_font_size_override("font_size", 9)
	settings_panel.add_child(controls_tab_button)
	controls_tab_button.position = Vector2(218, 40)
	controls_tab_button.size = Vector2(105, 24)
	controls_tab_button.pressed.connect(show_controls_page)

	create_volume_page()
	create_controls_page()

	var back_button := Button.new()
	back_button.text = "Quay lại"
	back_button.add_theme_font_size_override("font_size", 9)
	settings_panel.add_child(back_button)
	back_button.position = Vector2(140, 196)
	back_button.size = Vector2(120, 24)
	back_button.pressed.connect(show_main_panel)

	center_settings_panel()


func create_volume_page() -> void:
	volume_page = Control.new()
	volume_page.name = "VolumePage"
	settings_panel.add_child(volume_page)

	volume_page.position = Vector2(40, 78)
	volume_page.size = Vector2(320, 100)

	var music_label := Label.new()
	music_label.text = "Nhạc nền"
	music_label.add_theme_font_size_override("font_size", 10)
	volume_page.add_child(music_label)
	music_label.position = Vector2(0, 8)
	music_label.size = Vector2(90, 20)

	music_slider = HSlider.new()
	volume_page.add_child(music_slider)
	music_slider.position = Vector2(105, 8)
	music_slider.size = Vector2(190, 18)
	music_slider.min_value = 0
	music_slider.max_value = 100
	music_slider.step = 1
	music_slider.value = get_bus_volume_percent(MUSIC_BUS_NAME)
	music_slider.value_changed.connect(_on_music_volume_changed)

	var sfx_label := Label.new()
	sfx_label.text = "Hiệu ứng"
	sfx_label.add_theme_font_size_override("font_size", 10)
	volume_page.add_child(sfx_label)
	sfx_label.position = Vector2(0, 45)
	sfx_label.size = Vector2(90, 20)

	sfx_slider = HSlider.new()
	volume_page.add_child(sfx_slider)
	sfx_slider.position = Vector2(105, 45)
	sfx_slider.size = Vector2(190, 18)
	sfx_slider.min_value = 0
	sfx_slider.max_value = 100
	sfx_slider.step = 1
	sfx_slider.value = get_bus_volume_percent(SFX_BUS_NAME)
	sfx_slider.value_changed.connect(_on_sfx_volume_changed)


func create_controls_page() -> void:
	controls_page = Control.new()
	controls_page.name = "ControlsPage"
	settings_panel.add_child(controls_page)

	controls_page.position = Vector2(55, 75)
	controls_page.size = Vector2(290, 110)
	controls_page.visible = false

	var start_y: float = 0.0

	for item in REBIND_ACTIONS:
		var action_name: String = item["action"]
		var label_text: String = item["label"]

		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)

		var action_label := Label.new()
		action_label.text = label_text
		action_label.add_theme_font_size_override("font_size", 9)
		action_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		controls_page.add_child(action_label)
		action_label.position = Vector2(0, start_y)
		action_label.size = Vector2(120, 22)

		var rebind_button := Button.new()
		rebind_button.add_theme_font_size_override("font_size", 8)
		controls_page.add_child(rebind_button)
		rebind_button.position = Vector2(145, start_y)
		rebind_button.size = Vector2(130, 22)
		rebind_button.pressed.connect(_on_rebind_button_pressed.bind(action_name))

		rebind_buttons[action_name] = rebind_button

		start_y += 27.0

	update_rebind_button_texts()


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

	style.bg_color = Color(0.08, 0.055, 0.04, 0.96)
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
	var viewport_size := get_viewport().get_visible_rect().size
	main_panel.position = (viewport_size - main_panel.size) * 0.5


func center_settings_panel() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	settings_panel.position = (viewport_size - settings_panel.size) * 0.5


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

	root.visible = true
	show_main_panel()


func resume_game() -> void:
	is_pause_open = false
	waiting_rebind_action = ""

	root.visible = false
	get_tree().paused = false

	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)


func show_main_panel() -> void:
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

	volume_tab_button.disabled = true
	controls_tab_button.disabled = false

	waiting_rebind_action = ""
	update_rebind_button_texts()


func show_controls_page() -> void:
	volume_page.visible = false
	controls_page.visible = true

	volume_tab_button.disabled = false
	controls_tab_button.disabled = true

	waiting_rebind_action = ""
	update_rebind_button_texts()


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


func _on_sfx_volume_changed(value: float) -> void:
	set_bus_volume_percent(SFX_BUS_NAME, value)


func get_bus_index(bus_name: String) -> int:
	var index := AudioServer.get_bus_index(bus_name)

	if index == -1:
		index = AudioServer.get_bus_index("Master")

	return index


func set_bus_volume_percent(bus_name: String, percent: float) -> void:
	var bus_index := get_bus_index(bus_name)

	if bus_index == -1:
		return

	percent = clamp(percent, 0.0, 100.0)

	if percent <= 0.0:
		AudioServer.set_bus_mute(bus_index, true)
		AudioServer.set_bus_volume_db(bus_index, -80.0)
		return

	AudioServer.set_bus_mute(bus_index, false)

	var linear_value := percent / 100.0
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(linear_value))


func get_bus_volume_percent(bus_name: String) -> float:
	var bus_index := get_bus_index(bus_name)

	if bus_index == -1:
		return 100.0

	if AudioServer.is_bus_mute(bus_index):
		return 0.0

	var db_value := AudioServer.get_bus_volume_db(bus_index)
	var linear_value := db_to_linear(db_value)

	return clamp(linear_value * 100.0, 0.0, 100.0)


func _on_rebind_button_pressed(action_name: String) -> void:
	waiting_rebind_action = ""

	update_rebind_button_texts()

	if rebind_buttons.has(action_name):
		rebind_buttons[action_name].text = "Nhấn phím..."

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

	var new_event := event.duplicate()

	InputMap.action_erase_events(action_name)
	InputMap.action_add_event(action_name, new_event)

	waiting_rebind_action = ""
	update_rebind_button_texts()


func update_rebind_button_texts() -> void:
	for item in REBIND_ACTIONS:
		var action_name: String = item["action"]

		if not rebind_buttons.has(action_name):
			continue

		var button: Button = rebind_buttons[action_name]
		button.text = get_action_input_text(action_name)


func get_action_input_text(action_name: String) -> String:
	if not InputMap.has_action(action_name):
		return "Chưa gán"

	var events := InputMap.action_get_events(action_name)

	if events.is_empty():
		return "Chưa gán"

	var text := events[0].as_text()
	text = text.replace(" (Physical)", "")

	if text == "Left Mouse Button":
		return "Chuột trái"

	if text == "Right Mouse Button":
		return "Chuột phải"

	if text == "Middle Mouse Button":
		return "Chuột giữa"

	return text
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


func center_save_panel() -> void:
	if save_panel == null:
		return

	var viewport_size := get_viewport().get_visible_rect().size
	save_panel.position = (viewport_size - save_panel.size) * 0.5


func open_save_menu() -> void:
	main_panel.visible = false
	settings_panel.visible = false
	save_panel.visible = true

	save_message_label.text = ""
	is_saving_slot = false

	center_save_panel()
	refresh_save_slots()


func refresh_save_slots() -> void:
	for row_data in save_slot_rows:
		var slot: int = row_data["slot"]
		var label: Label = row_data["label"]
		var button: Button = row_data["button"]

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

	is_saving_slot = true
	save_message_label.text = "Đang lưu dữ liệu..."

	# Ẩn pause UI một khoảnh khắc để ảnh chụp là màn hình game,
	# không bị dính menu pause.
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
		save_message_label.text = "Lưu dữ liệu thất bại."

	refresh_save_slots()

	is_saving_slot = false
