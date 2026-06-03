extends Control

@onready var color_rect: ColorRect = $ColorRect
@onready var vbox: VBoxContainer = $VBoxContainer
@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var play_button: Button = $VBoxContainer/PlayButton
@onready var load_button: Button = $VBoxContainer/LoadButton
@onready var quit_button: Button = $VBoxContainer/QuitButton
@onready var menu_click_sound: AudioStreamPlayer = $MenuClickSound
@onready var coop_button: Button = $VBoxContainer/CoopButton
var load_panel: Panel
var load_message_label: Label
var load_slot_rows: Array = []
var is_loading_slot: bool = false


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	setup_layout()
	create_load_ui()

	play_button.pressed.connect(_on_play_pressed)
	coop_button.pressed.connect(_on_coop_pressed)
	load_button.pressed.connect(_on_load_pressed)
	quit_button.pressed.connect(_on_quit_pressed)


func setup_layout() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0

	color_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	color_rect.offset_left = 0
	color_rect.offset_top = 0
	color_rect.offset_right = 0
	color_rect.offset_bottom = 0
	color_rect.color = Color(0.08, 0.025, 0.0, 1.0)

	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.offset_left = -300
	vbox.offset_top = -150
	vbox.offset_right = 300
	vbox.offset_bottom = 150
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 2)

	title_label.text = "ESCAPING DUNGEON"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 22)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	title_label.add_theme_color_override("font_outline_color", Color.BLACK)
	title_label.add_theme_constant_override("outline_size", 3)
	title_label.custom_minimum_size = Vector2(600, 70)

	setup_button(play_button, "1 PLAYER")
	setup_button(coop_button, "2 PLAYER")
	setup_button(load_button, "LOAD")
	setup_button(quit_button, "QUIT")


func setup_button(button: Button, text_value: String) -> void:
	button.text = text_value
	button.custom_minimum_size = Vector2(140, 42)

	button.add_theme_font_size_override("font_size", 22)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.75, 0.25))
	button.add_theme_color_override("font_pressed_color", Color(1.0, 0.35, 0.15))
	button.add_theme_color_override("font_outline_color", Color.BLACK)
	button.add_theme_constant_override("outline_size", 2)

	var empty_style := StyleBoxEmpty.new()

	button.add_theme_stylebox_override("normal", empty_style)
	button.add_theme_stylebox_override("hover", empty_style)
	button.add_theme_stylebox_override("pressed", empty_style)
	button.add_theme_stylebox_override("disabled", empty_style)
	button.add_theme_stylebox_override("focus", empty_style)


func create_load_ui() -> void:
	load_panel = Panel.new()
	load_panel.name = "LoadPanel"
	add_child(load_panel)

	load_panel.size = Vector2(360, 220)
	load_panel.visible = false
	load_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	load_panel.add_theme_stylebox_override("panel", create_panel_style())

	var title := Label.new()
	title.text = "TẢI DỮ LIỆU"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(1.0, 0.78, 0.32))
	load_panel.add_child(title)
	title.position = Vector2(20, 8)
	title.size = Vector2(320, 22)

	var start_y: float = 38.0

	for slot in range(1, SaveManager.MAX_SAVE_SLOTS + 1):
		var row := Panel.new()
		row.name = "Slot%d" % slot
		load_panel.add_child(row)

		row.position = Vector2(16, start_y)
		row.size = Vector2(328, 34)
		row.add_theme_stylebox_override("panel", create_slot_style())

		var thumb := TextureRect.new()
		row.add_child(thumb)
		thumb.position = Vector2(6, 4)
		thumb.size = Vector2(50, 26)
		thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

		var info_label := Label.new()
		row.add_child(info_label)
		info_label.position = Vector2(64, 3)
		info_label.size = Vector2(180, 28)
		info_label.add_theme_font_size_override("font_size", 8)
		info_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

		var button := Button.new()
		row.add_child(button)
		button.position = Vector2(255, 6)
		button.size = Vector2(58, 22)
		button.text = "Tải"
		button.add_theme_font_size_override("font_size", 8)
		button.pressed.connect(_on_load_slot_pressed.bind(slot))

		load_slot_rows.append({
			"slot": slot,
			"thumb": thumb,
			"label": info_label,
			"button": button
		})

		start_y += 37.0

	load_message_label = Label.new()
	load_panel.add_child(load_message_label)
	load_message_label.text = ""
	load_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	load_message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	load_message_label.add_theme_font_size_override("font_size", 8)
	load_message_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.28))
	load_message_label.position = Vector2(20, 186)
	load_message_label.size = Vector2(320, 16)

	var back_button := Button.new()
	back_button.text = "Quay lại"
	back_button.add_theme_font_size_override("font_size", 8)
	load_panel.add_child(back_button)
	back_button.position = Vector2(130, 202)
	back_button.size = Vector2(100, 16)
	back_button.pressed.connect(_on_back_from_load_pressed)

	center_load_panel()


func create_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()

	style.bg_color = Color(0.08, 0.055, 0.035, 0.96)
	style.border_color = Color(1.0, 0.58, 0.20, 1.0)

	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2

	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8

	return style


func create_slot_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()

	style.bg_color = Color(0.0, 0.0, 0.0, 0.32)
	style.border_color = Color(1.0, 1.0, 1.0, 0.12)

	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1

	return style


func center_load_panel() -> void:
	if load_panel == null:
		return

	var viewport_size := get_viewport().get_visible_rect().size
	load_panel.position = (viewport_size - load_panel.size) * 0.5


func refresh_load_slots() -> void:
	for row_data in load_slot_rows:
		var slot: int = row_data["slot"]
		var thumb: TextureRect = row_data["thumb"]
		var label: Label = row_data["label"]
		var button: Button = row_data["button"]

		var info: Dictionary = SaveManager.get_slot_info(slot)

		if not bool(info.get("exists", false)):
			label.text = "File %d\nChưa có dữ liệu" % slot
			thumb.texture = null
			button.disabled = true
			continue

		label.text = "File %d\n%s" % [
			slot,
			String(info.get("saved_at", "Không rõ thời gian"))
		]

		if bool(info.get("has_screenshot", false)):
			thumb.texture = load_texture_from_file(String(info.get("screenshot_path", "")))
		else:
			thumb.texture = null

		button.disabled = false


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


func _on_play_pressed() -> void:
	play_button.disabled = true
	load_button.disabled = true
	quit_button.disabled = true
	GameMode.set_single_player()
	if SaveManager != null:
		SaveManager.clear_pending_load()
	PlayerManager.reset_runtime_stats()
	play_menu_click_sound()

	await get_tree().create_timer(0.25).timeout

	await MusicManager.fade_out(1.5, true)

	await SceneTransition.change_scene_with_fade(
		"res://level/testlevel/test_level_new.tscn"
	)


func _on_load_pressed() -> void:
	play_menu_click_sound()

	vbox.visible = false
	load_panel.visible = true
	load_message_label.text = ""
	is_loading_slot = false

	center_load_panel()
	refresh_load_slots()

func _on_coop_pressed() -> void:
	play_button.disabled = true
	coop_button.disabled = true
	load_button.disabled = true
	quit_button.disabled = true

	GameMode.set_two_players()

	if SaveManager != null:
		SaveManager.clear_pending_load()

	PlayerManager.reset_runtime_stats()
	play_menu_click_sound()

	await get_tree().create_timer(0.25).timeout

	await MusicManager.fade_out(1.5, true)

	await SceneTransition.change_scene_with_fade(
		"res://level/testlevel/test_level_new.tscn"
	)
func _on_load_slot_pressed(slot: int) -> void:
	if is_loading_slot:
		return

	is_loading_slot = true
	load_message_label.text = "Đang tải dữ liệu..."

	play_menu_click_sound()

	await get_tree().create_timer(0.2).timeout

	await MusicManager.fade_out(0.8, true)

	var success: bool = await SaveManager.load_slot(slot)

	if not success:
		load_message_label.text = "Không thể tải file này."
		is_loading_slot = false


func _on_back_from_load_pressed() -> void:
	play_menu_click_sound()

	load_panel.visible = false
	vbox.visible = true
	is_loading_slot = false


func _on_quit_pressed() -> void:
	play_button.disabled = true
	coop_button.disabled = true
	load_button.disabled = true
	quit_button.disabled = true

	play_menu_click_sound()

	await get_tree().create_timer(0.4).timeout

	get_tree().quit()


func play_menu_click_sound() -> void:
	if menu_click_sound == null:
		return

	menu_click_sound.stop()
	menu_click_sound.pitch_scale = 0.6
	menu_click_sound.play()
