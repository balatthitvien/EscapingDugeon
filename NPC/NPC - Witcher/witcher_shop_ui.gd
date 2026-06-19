extends CanvasLayer

signal closed

@export var strength_texture: Texture2D
@export var defense_texture: Texture2D
@export var speed_texture: Texture2D
@onready var buy_success_sound: AudioStreamPlayer = get_node_or_null("BuySuccessSound") as AudioStreamPlayer
var player: Player = null
var bought_item_this_session: bool = false
var root: Control
var dim_rect: ColorRect
var shop_panel: Panel
var title_panel: Panel
var title_label: Label
var message_label: Label
var exit_button: Button

var strength_price_label: Label
var defense_price_label: Label
var speed_price_label: Label

var buy_strength_button: Button
var buy_defense_button: Button
var buy_speed_button: Button

const OUTER_BORDER: int = 4
const TITLE_BORDER: int = 2
const INNER_BORDER: int = 1
const BUTTON_BORDER: int = 1


func _ready() -> void:
	visible = false
	create_ui()


func create_ui() -> void:
	root = Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	dim_rect = ColorRect.new()
	dim_rect.name = "DimBackground"
	dim_rect.color = Color(0, 0, 0, 0.65)
	dim_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim_rect)

	shop_panel = Panel.new()
	shop_panel.name = "WitcherShopPanel"
	root.add_child(shop_panel)
	shop_panel.set_anchors_preset(Control.PRESET_CENTER)
	shop_panel.offset_left = -185
	shop_panel.offset_top = -105
	shop_panel.offset_right = 185
	shop_panel.offset_bottom = 105

	shop_panel.add_theme_stylebox_override(
		"panel",
		make_style(Color(0.02, 0.02, 0.02, 0.96), Color(0.72, 0.25, 1.0), OUTER_BORDER, 8)
	)

	create_title()
	create_items_layout()
	create_exit_button()


func create_title() -> void:
	title_panel = Panel.new()
	title_panel.name = "TitlePanel"
	shop_panel.add_child(title_panel)
	title_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title_panel.offset_left = -95
	title_panel.offset_top = -22
	title_panel.offset_right = 95
	title_panel.offset_bottom = 22

	title_panel.add_theme_stylebox_override(
		"panel",
		make_style(Color(0.04, 0.04, 0.04, 1.0), Color(0.72, 0.25, 1.0), TITLE_BORDER, 8)
	)

	title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.text = "TIỆM THUỐC"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.add_theme_color_override("font_color", Color(0.9, 0.62, 1.0))
	title_panel.add_child(title_label)


func create_items_layout() -> void:
	message_label = make_text_label("", 8, Color(1.0, 0.78, 0.2))
	message_label.name = "MessageLabel"
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	shop_panel.add_child(message_label)
	message_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	message_label.offset_left = -220
	message_label.offset_top = 26
	message_label.offset_right = -14
	message_label.offset_bottom = 42

	var item_row := HBoxContainer.new()
	item_row.name = "ItemRow"
	shop_panel.add_child(item_row)
	item_row.set_anchors_preset(Control.PRESET_FULL_RECT)
	item_row.offset_left = 10
	item_row.offset_top = 42
	item_row.offset_right = -10
	item_row.offset_bottom = -58
	item_row.add_theme_constant_override("separation", 6)

	var strength_card := create_item_card(
		"StrengthCard",
		strength_texture,
		"SỨC MẠNH",
		"Tăng tấn công\n50% trong 15s.",
		str(LevelManager.get_witcher_item_price("strength"))
	)
	item_row.add_child(strength_card)

	var defense_card := create_item_card(
		"DefenseCard",
		defense_texture,
		"PHÒNG THỦ",
		"Giảm sát thương\n50% trong 15s.",
		str(LevelManager.get_witcher_item_price("defense"))
	)
	item_row.add_child(defense_card)

	var speed_card := create_item_card(
		"SpeedCard",
		speed_texture,
		"TỐC ĐỘ",
		"Tăng di chuyển\n40% trong 15s.",
		str(LevelManager.get_witcher_item_price("speed"))
	)
	item_row.add_child(speed_card)


func create_item_card(
	card_name: String,
	item_texture: Texture2D,
	item_title: String,
	item_desc: String,
	price_text: String
) -> Panel:
	var card := Panel.new()
	card.name = card_name
	card.custom_minimum_size = Vector2(105, 136)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	card.add_theme_stylebox_override(
		"panel",
		make_style(Color(0.01, 0.01, 0.01, 0.98), Color(0.72, 0.25, 1.0), INNER_BORDER, 6)
	)

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	card.add_child(vbox)
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 5
	vbox.offset_top = 5
	vbox.offset_right = -5
	vbox.offset_bottom = -5
	vbox.add_theme_constant_override("separation", 2)

	var image_box := Panel.new()
	image_box.name = "ImageBox"
	image_box.custom_minimum_size = Vector2(0, 34)
	image_box.add_theme_stylebox_override(
		"panel",
		make_style(Color(0, 0, 0, 1.0), Color(0.45, 0.12, 0.65), INNER_BORDER, 4)
	)
	vbox.add_child(image_box)

	var texture_rect := TextureRect.new()
	texture_rect.name = "ItemTexture"
	texture_rect.texture = item_texture
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	texture_rect.offset_left = 6
	texture_rect.offset_top = 6
	texture_rect.offset_right = -6
	texture_rect.offset_bottom = -6
	image_box.add_child(texture_rect)

	if item_texture == null:
		var placeholder := Label.new()
		placeholder.text = "ẢNH\nVẬT PHẨM"
		placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		placeholder.set_anchors_preset(Control.PRESET_FULL_RECT)
		placeholder.add_theme_font_size_override("font_size", 10)
		placeholder.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		image_box.add_child(placeholder)

	var name_panel := Panel.new()
	name_panel.name = "NamePanel"
	name_panel.custom_minimum_size = Vector2(0, 17)
	name_panel.add_theme_stylebox_override(
		"panel",
		make_style(Color(0.42, 0.10, 0.58, 1.0), Color(0.9, 0.62, 1.0), INNER_BORDER, 3)
	)
	vbox.add_child(name_panel)

	var name_label := Label.new()
	name_label.text = item_title
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	name_label.add_theme_font_size_override("font_size", 8)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_panel.add_child(name_label)

	var desc_label := make_text_label(item_desc, 8, Color.WHITE)
	desc_label.custom_minimum_size = Vector2(0, 30)
	desc_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	vbox.add_child(desc_label)

	var divider := ColorRect.new()
	divider.name = "Divider"
	divider.color = Color(0.72, 0.25, 1.0)
	divider.custom_minimum_size = Vector2(0, 1)
	vbox.add_child(divider)

	var price_row := HBoxContainer.new()
	price_row.name = "PriceRow"
	price_row.alignment = BoxContainer.ALIGNMENT_CENTER
	price_row.custom_minimum_size = Vector2(0, 22)
	price_row.add_theme_constant_override("separation", 7)
	vbox.add_child(price_row)

	var coin_text := make_text_label("●", 10, Color(1.0, 0.78, 0.12))
	price_row.add_child(coin_text)

	var price_label := make_text_label(price_text, 10, Color.WHITE)
	price_row.add_child(price_label)

	var button := Button.new()
	button.text = "MUA"
	button.custom_minimum_size = Vector2(0, 18)
	button.add_theme_font_size_override("font_size", 9)
	vbox.add_child(button)

	button.add_theme_stylebox_override(
		"normal",
		make_button_style(Color(0.10, 0.42, 0.08), Color(1.0, 0.80, 0.18))
	)
	button.add_theme_stylebox_override(
		"hover",
		make_button_style(Color(0.16, 0.55, 0.10), Color(1.0, 0.90, 0.28))
	)
	button.add_theme_stylebox_override(
		"pressed",
		make_button_style(Color(0.06, 0.30, 0.05), Color(1.0, 0.70, 0.10))
	)

	match card_name:
		"StrengthCard":
			strength_price_label = price_label
			buy_strength_button = button
			buy_strength_button.pressed.connect(_on_buy_strength_pressed)

		"DefenseCard":
			defense_price_label = price_label
			buy_defense_button = button
			buy_defense_button.pressed.connect(_on_buy_defense_pressed)

		"SpeedCard":
			speed_price_label = price_label
			buy_speed_button = button
			buy_speed_button.pressed.connect(_on_buy_speed_pressed)

	return card


func create_exit_button() -> void:
	exit_button = Button.new()
	exit_button.name = "ExitButton"
	exit_button.text = "EXIT"
	exit_button.custom_minimum_size = Vector2(110, 22)
	exit_button.add_theme_font_size_override("font_size", 12)

	exit_button.add_theme_stylebox_override(
		"normal",
		make_button_style(Color(0.55, 0.06, 0.04), Color(1.0, 0.78, 0.16))
	)
	exit_button.add_theme_stylebox_override(
		"hover",
		make_button_style(Color(0.75, 0.10, 0.06), Color(1.0, 0.90, 0.28))
	)
	exit_button.add_theme_stylebox_override(
		"pressed",
		make_button_style(Color(0.35, 0.03, 0.03), Color(1.0, 0.65, 0.08))
	)

	root.add_child(exit_button)
	exit_button.set_anchors_preset(Control.PRESET_CENTER)
	exit_button.offset_left = -55
	exit_button.offset_top = 112
	exit_button.offset_right = 55
	exit_button.offset_bottom = 134

	exit_button.pressed.connect(_on_exit_pressed)


func open_shop(target_player: Player) -> void:
	player = target_player
	if player != null and player.is_coop_mode():
		return
	bought_item_this_session = false
	visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if player != null:
		player.set_control_enabled(false)

	update_ui()

	root.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(root, "modulate:a", 1.0, 0.2)


func close_shop() -> void:
	if root != null:
		var tween := create_tween()
		tween.tween_property(root, "modulate:a", 0.0, 0.2)
		await tween.finished

	visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

	var should_check_hint := bought_item_this_session

	if player != null:
		player.set_control_enabled(true)

	closed.emit()

	if should_check_hint:
		try_show_inventory_hint_after_close()


func update_ui() -> void:
	if strength_price_label != null:
		strength_price_label.text = str(LevelManager.get_witcher_item_price("strength"))

	if defense_price_label != null:
		defense_price_label.text = str(LevelManager.get_witcher_item_price("defense"))

	if speed_price_label != null:
		speed_price_label.text = str(LevelManager.get_witcher_item_price("speed"))

	if message_label != null:
		message_label.text = ""


func buy_witcher_item(price_id: String, inventory_item_id: String, success_message: String) -> void:
	if player == null:
		return

	if !player.has_method("add_inventory_item"):
		message_label.text = "Player chưa có túi vật phẩm."
		return

	var price := LevelManager.get_witcher_item_price(price_id)

	if !player.spend_coin(price):
		message_label.text = "Không đủ vàng."
		return

	if !player.add_inventory_item(inventory_item_id, 1):
		message_label.text = "Không thể thêm vật phẩm."
		return

	LevelManager.increase_witcher_item_buy_count(price_id)

	bought_item_this_session = true

	update_ui()

	message_label.text = success_message
	play_buy_success_sound()

func _on_buy_strength_pressed() -> void:
	buy_witcher_item("strength", "strength_potion", "Đã mua thuốc sức mạnh.")


func _on_buy_defense_pressed() -> void:
	buy_witcher_item("defense", "defense_potion", "Đã mua thuốc phòng thủ.")


func _on_buy_speed_pressed() -> void:
	buy_witcher_item("speed", "speed_potion", "Đã mua thuốc tốc độ.")


func _on_exit_pressed() -> void:
	await close_shop()


func make_text_label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func make_style(bg_color: Color, border_color: Color, border_width: int, corner_radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = corner_radius
	style.corner_radius_top_right = corner_radius
	style.corner_radius_bottom_left = corner_radius
	style.corner_radius_bottom_right = corner_radius
	return style


func make_button_style(bg_color: Color, border_color: Color) -> StyleBoxFlat:
	return make_style(bg_color, border_color, BUTTON_BORDER, 5)
func try_show_inventory_hint_after_close() -> void:
	if player == null:
		return

	if player.is_coop_mode():
		return

	var current_scene := get_tree().current_scene

	if current_scene == null:
		return

	var hud = current_scene.get_node_or_null("PlayerHUD")

	if hud == null:
		hud = current_scene.find_child("PlayerHUD", true, false)

	if hud == null:
		return

	var type_count := player.get_owned_inventory_item_type_count()

	if type_count == 1:
		if !player.has_seen_use_item_tip:
			player.has_seen_use_item_tip = true

			if hud.has_method("show_use_item_hint"):
				hud.show_use_item_hint()
			elif hud.has_method("show_hint"):
				hud.show_hint("Bấm R để sử dụng", 4.0)

		return

	if type_count >= 2:
		if !player.has_seen_item_switch_tip:
			player.has_seen_item_switch_tip = true
			player.has_seen_use_item_tip = true

			if hud.has_method("show_full_item_hint"):
				hud.show_full_item_hint()
			elif hud.has_method("show_hint"):
				hud.show_hint("Bấm R để sử dụng\nẤn Z/C để đổi vật phẩm sử dụng", 4.5)
func play_buy_success_sound() -> void:
	if buy_success_sound == null:
		push_warning("WitcherShopUI: Chưa có node BuySuccessSound.")
		return

	if buy_success_sound.stream == null:
		push_warning("WitcherShopUI: BuySuccessSound chưa được gán file âm thanh.")
		return

	buy_success_sound.stop()
	buy_success_sound.pitch_scale = randf_range(0.96, 1.04)
	buy_success_sound.play()
