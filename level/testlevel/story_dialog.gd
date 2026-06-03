extends CanvasLayer

signal story_finished

@onready var dialog_root: Control = $DialogRoot
@onready var panel: Panel = $DialogRoot/Panel
@onready var portrait: TextureRect = $DialogRoot/Panel/Portrait
@onready var dialog_text: RichTextLabel = $DialogRoot/Panel/DialogText
@onready var space_text: Label = $DialogRoot/Panel/SpaceText

@export var letter_time: float = 0.035

const PIXEL_FONT := preload("res://MainMenu/SFUAngieRegular.TTF")

var lines: Array = []
var current_index: int = 0
var is_active: bool = false
var is_typing: bool = false
var current_full_text: String = ""
var blink_tween: Tween
var skip_label: Label = null
var is_mouse_over_skip: bool = false

var previous_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE


func _ready() -> void:
	layer = 2000
	visible = false
	setup_layout()


func setup_layout() -> void:
	dialog_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	dialog_root.offset_left = 0
	dialog_root.offset_top = 0
	dialog_root.offset_right = 0
	dialog_root.offset_bottom = 0

	# Khung thoại dưới màn hình
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.offset_left = -185
	panel.offset_right = 185
	panel.offset_top = -92
	panel.offset_bottom = -18

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0, 0, 0, 1)
	panel_style.border_color = Color.WHITE
	panel_style.border_width_left = 1
	panel_style.border_width_right = 1
	panel_style.border_width_top = 1
	panel_style.border_width_bottom = 1
	panel.add_theme_stylebox_override("panel", panel_style)

	# Ảnh nhân vật bên trái
	portrait.position = Vector2(10, 10)
	portrait.size = Vector2(48, 48)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture = null

	# Nội dung thoại
	dialog_text.position = Vector2(65, 8)
	dialog_text.size = Vector2(290, 40)
	dialog_text.bbcode_enabled = true
	dialog_text.fit_content = false
	dialog_text.scroll_active = false
	dialog_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialog_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	dialog_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	dialog_text.add_theme_font_override("normal_font", PIXEL_FONT)
	dialog_text.add_theme_font_size_override("normal_font_size", 14)
	dialog_text.add_theme_color_override("default_color", Color.WHITE)

	# Dòng hướng dẫn
	space_text.position = Vector2(65, 52)
	space_text.size = Vector2(290, 16)
	space_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	space_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	space_text.text = "Bấm chuột trái"

	space_text.add_theme_font_override("font", PIXEL_FONT)
	space_text.add_theme_font_size_override("font_size", 8)
	space_text.add_theme_color_override("font_color", Color(1.0, 0.8, 0.25))
	space_text.add_theme_color_override("font_outline_color", Color.BLACK)
	space_text.add_theme_constant_override("outline_size", 1)

	create_skip_button()


func create_skip_button() -> void:
	if skip_label != null:
		return

	skip_label = Label.new()
	skip_label.name = "SkipLabel"
	skip_label.text = "Skip"
	panel.add_child(skip_label)

	skip_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	skip_label.offset_left = -55
	skip_label.offset_right = -8
	skip_label.offset_top = 3
	skip_label.offset_bottom = 22

	skip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	skip_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	skip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	skip_label.add_theme_font_override("font", PIXEL_FONT)
	skip_label.add_theme_font_size_override("font_size", 11)
	skip_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
func start_story(story_lines: Array) -> void:
	lines.clear()

	for line in story_lines:
		lines.append(line)

	current_index = 0
	is_active = true
	visible = true

	# Trả lại chuột cho người chơi khi vào hội thoại
	previous_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if skip_label != null:
		skip_label.visible = true

	show_current_line()


func show_current_line() -> void:
	if current_index >= lines.size():
		finish_story()
		return

	var data = lines[current_index]

	if typeof(data) == TYPE_DICTIONARY:
		current_full_text = data.get("text", "")

		if data.has("portrait"):
			portrait.texture = data["portrait"]
		else:
			portrait.texture = null
	else:
		current_full_text = str(data)
		portrait.texture = null

	type_text(current_full_text)


func type_text(text_to_show: String) -> void:
	is_typing = true
	dialog_text.text = ""
	space_text.visible = false
	stop_space_blink()

	var plain_text := strip_bbcode(text_to_show)

	for i in plain_text.length():
		if !is_typing:
			break

		dialog_text.text += plain_text[i]
		await get_tree().create_timer(letter_time).timeout

	dialog_text.text = text_to_show
	is_typing = false
	space_text.text = "Bấm chuột trái"
	space_text.visible = true
	start_space_blink()


func start_space_blink() -> void:
	stop_space_blink()

	space_text.visible = true
	space_text.modulate = Color(1, 1, 1, 1)

	blink_tween = create_tween()
	blink_tween.set_loops()
	blink_tween.tween_property(space_text, "modulate:a", 0.2, 0.45)
	blink_tween.tween_property(space_text, "modulate:a", 1.0, 0.45)


func stop_space_blink() -> void:
	if blink_tween:
		blink_tween.kill()
		blink_tween = null

	space_text.modulate.a = 1.0


func _input(event: InputEvent) -> void:
	if !is_active:
		return

	if event is InputEventMouseMotion:
		update_skip_hover(event.position)
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if is_mouse_on_skip(event.position):
				finish_story()
				get_viewport().set_input_as_handled()
				return

			advance_dialog()
			get_viewport().set_input_as_handled()
			return
func advance_dialog() -> void:
	if !is_active:
		return

	if is_typing:
		is_typing = false
		dialog_text.text = current_full_text
		space_text.text = "Bấm chuột trái"
		space_text.visible = true
		start_space_blink()
	else:
		stop_space_blink()
		current_index += 1
		show_current_line()


func _on_skip_button_pressed() -> void:
	if !is_active:
		return

	finish_story()


func finish_story() -> void:
	stop_space_blink()

	is_typing = false
	is_active = false
	visible = false

	portrait.texture = null

	if skip_label != null:
		skip_label.visible = false

	# Khôi phục lại chế độ chuột trước khi vào hội thoại
	Input.mouse_mode = previous_mouse_mode

	story_finished.emit()


func strip_bbcode(text: String) -> String:
	var regex := RegEx.new()
	regex.compile("\\[.*?\\]")
	return regex.sub(text, "", true)
func update_skip_hover(mouse_position: Vector2) -> void:
	if skip_label == null:
		return

	var hovering: bool = is_mouse_on_skip(mouse_position)

	if hovering == is_mouse_over_skip:
		return

	is_mouse_over_skip = hovering

	if is_mouse_over_skip:
		skip_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	else:
		skip_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))


func is_mouse_on_skip(mouse_position: Vector2) -> bool:
	if skip_label == null:
		return false

	return skip_label.get_global_rect().has_point(mouse_position)
