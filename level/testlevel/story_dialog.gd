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


func _ready() -> void:
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

	# Dòng nhắc ấn phím
	space_text.position = Vector2(65, 52)
	space_text.size = Vector2(290, 16)
	space_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	space_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	space_text.text = "Ấn Space"

	space_text.add_theme_font_override("font", PIXEL_FONT)
	space_text.add_theme_font_size_override("font_size", 8)
	space_text.add_theme_color_override("font_color", Color(1.0, 0.8, 0.25))
	space_text.add_theme_color_override("font_outline_color", Color.BLACK)
	space_text.add_theme_constant_override("outline_size", 1)


func start_story(story_lines: Array) -> void:
	lines.clear()

	# Quan trọng: giữ nguyên dictionary, không ép str()
	for line in story_lines:
		lines.append(line)

	current_index = 0
	is_active = true
	visible = true

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
	space_text.text = "Ấn Space"
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


func _unhandled_input(event: InputEvent) -> void:
	if !is_active:
		return

	if event.is_action_pressed("ui_accept"):
		if is_typing:
			is_typing = false
			dialog_text.text = current_full_text
			space_text.text = "Ấn Space"
			space_text.visible = true
			start_space_blink()
		else:
			stop_space_blink()
			current_index += 1
			show_current_line()

		get_viewport().set_input_as_handled()


func finish_story() -> void:
	stop_space_blink()
	is_active = false
	visible = false
	portrait.texture = null
	story_finished.emit()


func strip_bbcode(text: String) -> String:
	var regex := RegEx.new()
	regex.compile("\\[.*?\\]")
	return regex.sub(text, "", true)
