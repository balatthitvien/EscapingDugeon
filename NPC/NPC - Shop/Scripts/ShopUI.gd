extends CanvasLayer

signal closed

@export var potion_texture: Texture2D
@export var arrow_texture: Texture2D
@export var coming_soon_texture: Texture2D
@onready var buy_success_sound: AudioStreamPlayer = get_node_or_null("BuySuccessSound") as AudioStreamPlayer
var player: Player = null

var root: Control
var dim_rect: ColorRect
var shop_panel: Panel
var title_panel: Panel
var title_label: Label

var potion_price_label: Label
var arrow_price_label: Label
var message_label: Label

var buy_potion_button: Button
var buy_arrow_button: Button
var coming_soon_button: Button
var exit_button: Button

var bought_potion_this_session: bool = false
var shop_owner: Node = null

var arrow_name_label: Label
var arrow_desc_label: Label

var bought_bow_this_session: bool = false
var bought_hint_queue: Array[String] = []

var shop_hint_layer: CanvasLayer = null
var shop_hint_label: Label = null
var shop_hint_tween: Tween = null
const BASE_POTION_PRICE: int = 8
const PRICE_MULTIPLIER: float = 1.5
const ARROW_PRICE: int = 6
const BOW_PRICE: int = 12
const BOW_START_ARROW_COUNT: int = 10
const OUTER_BORDER: int = 4
const TITLE_BORDER: int = 2
const INNER_BORDER: int = 1
const BUTTON_BORDER: int = 1
const SHOP_HINT_DURATION: float = 4.2
const SHOP_HINT_TOP_OFFSET: float = 52.0
const SHOP_HINT_HEIGHT: float = 78.0
const SHOP_HINT_FONT_SIZE: int = 13
const SHOP_HINT_OUTLINE_SIZE: int = 3
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
	shop_panel.name = "ShopPanel"
	root.add_child(shop_panel)
	shop_panel.set_anchors_preset(Control.PRESET_CENTER)
	shop_panel.offset_left = -185
	shop_panel.offset_top = -105
	shop_panel.offset_right = 185
	shop_panel.offset_bottom = 105

	shop_panel.add_theme_stylebox_override(
		"panel",
		make_style(Color(0.02, 0.02, 0.02, 0.96), Color(1.0, 0.75, 0.12), OUTER_BORDER, 8)
	)

	create_title()
	create_items_layout()
	create_exit_button()


func create_title() -> void:
	title_panel = Panel.new()
	title_panel.name = "TitlePanel"
	shop_panel.add_child(title_panel)
	title_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title_panel.offset_left = -80
	title_panel.offset_top = -22
	title_panel.offset_right = 80
	title_panel.offset_bottom = 22

	title_panel.add_theme_stylebox_override(
		"panel",
		make_style(Color(0.04, 0.04, 0.04, 1.0), Color(1.0, 0.78, 0.12), TITLE_BORDER, 8)
	)

	title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.text = "CỬA HÀNG"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.18))
	title_panel.add_child(title_label)


func create_items_layout() -> void:
	# Chỉ giữ message lỗi/thành công, bỏ hiển thị vàng và bình máu trong shop
	message_label = make_text_label("", 8, Color(1.0, 0.78, 0.2))
	message_label.name = "MessageLabel"
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	shop_panel.add_child(message_label)
	message_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	message_label.offset_left = -190
	message_label.offset_top = 26
	message_label.offset_right = -14
	message_label.offset_bottom = 42

	# Kéo toàn bộ item lên trên hơn so với bản cũ
	var item_row := HBoxContainer.new()
	item_row.name = "ItemRow"
	shop_panel.add_child(item_row)
	item_row.set_anchors_preset(Control.PRESET_FULL_RECT)
	item_row.offset_left = 10
	item_row.offset_top = 42
	item_row.offset_right = -10
	item_row.offset_bottom = -58
	item_row.add_theme_constant_override("separation", 6)

	var potion_card := create_item_card(
		"PotionCard",
		potion_texture,
		"POTION HEAL",
		"Hồi 1.5 tim\ntrong 3 giây.",
		"8",
		true
	)
	item_row.add_child(potion_card)

	var arrow_card := create_item_card(
		"ArrowCard",
		arrow_texture,
		"MŨI TÊN",
		"Bổ sung mũi tên\nđể chiến đấu.",
		str(ARROW_PRICE),
		true
	)
	item_row.add_child(arrow_card)

	var coming_card := create_item_card(
		"ComingSoonCard",
		coming_soon_texture,
		"COMING SOON",
		"Vật phẩm sẽ được\ncập nhật sau.",
		"---",
		false
	)
	item_row.add_child(coming_card)


func create_item_card(
	card_name: String,
	item_texture: Texture2D,
	item_title: String,
	item_desc: String,
	price_text: String,
	can_buy: bool
) -> Panel:
	var card := Panel.new()
	card.name = card_name

	# Giảm nhẹ chiều cao card để không dính viền dưới
	card.custom_minimum_size = Vector2(105, 136)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	card.add_theme_stylebox_override(
		"panel",
		make_style(Color(0.01, 0.01, 0.01, 0.98), Color(0.95, 0.68, 0.10), INNER_BORDER, 6)
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
		make_style(Color(0.0, 0.0, 0.0, 1.0), Color(0.65, 0.45, 0.08), INNER_BORDER, 4)
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
		make_style(Color(0.75, 0.48, 0.05, 1.0), Color(1.0, 0.82, 0.18), INNER_BORDER, 3)
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
	if card_name == "ArrowCard":
		arrow_name_label = name_label
		arrow_desc_label = desc_label
	var divider := ColorRect.new()
	divider.name = "Divider"
	divider.color = Color(0.95, 0.68, 0.10)
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
	button.custom_minimum_size = Vector2(0, 18)
	button.add_theme_font_size_override("font_size", 9)
	vbox.add_child(button)

	if can_buy:
		button.text = "MUA"
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
	else:
		button.text = "COMING SOON"
		button.disabled = true
		button.add_theme_stylebox_override(
			"disabled",
			make_button_style(Color(0.12, 0.12, 0.12), Color(0.35, 0.35, 0.35))
		)

	match card_name:
		"PotionCard":
			buy_potion_button = button
			potion_price_label = price_label
			buy_potion_button.pressed.connect(_on_buy_potion_pressed)
		"ArrowCard":
			buy_arrow_button = button
			arrow_price_label = price_label
			buy_arrow_button.pressed.connect(_on_buy_arrow_pressed)
		"ComingSoonCard":
			coming_soon_button = button

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


func open_shop(target_player: Player) -> void:
	player = target_player
	bought_potion_this_session = false
	bought_bow_this_session = false
	bought_hint_queue.clear()

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

	var pending_hint_queue: Array[String] = []

	for hint_id in bought_hint_queue:
		pending_hint_queue.append(hint_id)

	if player != null:
		player.set_control_enabled(true)

	closed.emit()

	await play_shop_hint_queue(pending_hint_queue)

func get_potion_price() -> int:
	if player == null:
		return BASE_POTION_PRICE

	var count: int = int(player.get("potion_count"))
	var price: int = BASE_POTION_PRICE

	for i in range(count):
		price = int(round(float(price) * PRICE_MULTIPLIER))

	return price


func update_ui() -> void:
	if player == null:
		return

	var potion_price := get_potion_price()

	if potion_price_label != null:
		potion_price_label.text = str(potion_price)

	if message_label != null:
		message_label.text = ""

	if buy_potion_button != null:
		buy_potion_button.disabled = false

	update_arrow_shop_ui()
func update_arrow_shop_ui() -> void:
	if buy_arrow_button == null:
		return

	if !LevelManager.has_bow:
		if arrow_name_label != null:
			arrow_name_label.text = "CUNG TÊN"

		if arrow_desc_label != null:
			arrow_desc_label.text = "Mở khóa bắn cung\nbằng phím Q."

		if arrow_price_label != null:
			arrow_price_label.text = str(get_bow_price())

		buy_arrow_button.text = "MUA"
		buy_arrow_button.disabled = false
		return

	if arrow_name_label != null:
		arrow_name_label.text = "MŨI TÊN"

	if arrow_desc_label != null:
		arrow_desc_label.text = "Bổ sung mũi tên\nđể chiến đấu."

	if arrow_price_label != null:
		arrow_price_label.text = str(get_arrow_pack_price())

	buy_arrow_button.text = "MUA"
	buy_arrow_button.disabled = false
func _on_buy_potion_pressed() -> void:
	if player == null:
		return

	var price := get_potion_price()

	if !try_spend_coin(price):
		message_label.text = "Không đủ vàng để mua bình máu."
		return

	if player.has_method("add_potion"):
		player.add_potion(1)
	else:
		player.set("potion_count", int(player.get("potion_count")) + 1)
		if player.has_signal("potion_changed"):
			player.emit_signal("potion_changed", int(player.get("potion_count")))

	bought_potion_this_session = true
	queue_shop_hint_once("potion")
	update_ui()

	message_label.text = "Đã mua bình máu."
	play_buy_success_sound()


func _on_buy_arrow_pressed() -> void:
	if player == null:
		return

	var success: bool = false

	if !LevelManager.has_bow:
		if shop_owner != null and shop_owner.has_method("try_buy_bow_from_shop"):
			success = shop_owner.try_buy_bow_from_shop(player)
		else:
			success = buy_bow_direct()

		if success:
			bought_bow_this_session = true
			queue_shop_hint_once("bow")

			update_ui()

			if message_label != null:
				message_label.text = "Đã mua cung. Bấm Q để bắn."

			play_buy_success_sound()

		return

	if shop_owner != null and shop_owner.has_method("try_buy_arrow_pack_from_shop"):
		success = shop_owner.try_buy_arrow_pack_from_shop(player)
	else:
		success = buy_arrow_pack_direct()

	if success:
		update_ui()

		if message_label != null:
			message_label.text = "Đã mua thêm mũi tên."

		play_buy_success_sound()

func _on_exit_pressed() -> void:
	await close_shop()


func show_potion_tip_on_hud() -> void:
	var current_scene := get_tree().current_scene

	if current_scene == null:
		return

	var hud := current_scene.get_node_or_null("PlayerHUD")

	if hud == null:
		hud = current_scene.find_child("PlayerHUD", true, false)

	if hud != null and hud.has_method("show_item_slot_hint"):
		hud.show_item_slot_hint()
	elif hud != null and hud.has_method("show_hint"):
		hud.show_hint("Ấn Z/C để đổi vật phẩm sử dụng\nBấm R để sử dụng", 4.5)
func set_shop_owner(owner: Node) -> void:
	shop_owner = owner
func get_bow_price() -> int:
	if shop_owner != null:
		var value = shop_owner.get("bow_price")

		if value != null:
			return int(value)

	return BOW_PRICE


func get_bow_start_arrow_count() -> int:
	if shop_owner != null:
		var value = shop_owner.get("bow_start_arrow_count")

		if value != null:
			return int(value)

	return BOW_START_ARROW_COUNT


func get_arrow_pack_price() -> int:
	if shop_owner != null:
		var value = shop_owner.get("arrow_pack_price")

		if value != null:
			return int(value)

	return ARROW_PRICE


func get_arrow_pack_amount() -> int:
	if shop_owner != null:
		var value = shop_owner.get("arrow_pack_amount")

		if value != null:
			return int(value)

	return 5
func buy_bow_direct() -> bool:
	var price: int = get_bow_price()

	if !try_spend_coin(price):
		if message_label != null:
			message_label.text = "Không đủ vàng để mua cung."

		return false

	if LevelManager.has_method("unlock_bow"):
		LevelManager.unlock_bow(get_bow_start_arrow_count())
	else:
		LevelManager.has_bow = true
		LevelManager.arrow_count += get_bow_start_arrow_count()

	if message_label != null:
		message_label.text = "Đã mua cung."

	return true


func buy_arrow_pack_direct() -> bool:
	var price: int = get_arrow_pack_price()

	if !try_spend_coin(price):
		if message_label != null:
			message_label.text = "Không đủ vàng để mua mũi tên."

		return false

	if LevelManager.has_method("add_arrows"):
		LevelManager.add_arrows(get_arrow_pack_amount())
	else:
		LevelManager.arrow_count += get_arrow_pack_amount()

	if message_label != null:
		message_label.text = "Đã mua %d mũi tên." % get_arrow_pack_amount()

	return true


func try_spend_coin(amount: int) -> bool:
	if player == null:
		return false

	if amount <= 0:
		return true

	if player.has_method("spend_coin"):
		return player.spend_coin(amount)

	var coin := int(player.get("coin_count"))

	if coin < amount:
		return false

	player.set("coin_count", coin - amount)

	if player.has_signal("coin_changed"):
		player.emit_signal("coin_changed", coin - amount)

	return true
func show_bow_tip_on_hud() -> void:
	if LevelManager.has_method("consume_bow_hint_once"):
		if !LevelManager.consume_bow_hint_once():
			return

	var current_scene := get_tree().current_scene

	if current_scene == null:
		return

	var hud := current_scene.get_node_or_null("PlayerHUD")

	if hud == null:
		hud = current_scene.find_child("PlayerHUD", true, false)

	if hud != null and hud.has_method("show_bow_hint"):
		hud.show_bow_hint()
		return

	if hud != null and hud.has_method("show_hint"):
		if is_two_player_mode():
			hud.show_hint("P1: Ấn K để bắn mũi tên\nP2: Ấn Enter để bắn mũi tên")
		else:
			hud.show_hint("Ấn Q để bắn mũi tên")
func is_two_player_mode() -> bool:
	var game_mode := get_node_or_null("/root/GameMode")

	if game_mode == null:
		return false

	return game_mode.is_two_players()
func try_show_inventory_hint_after_close() -> void:
	if player == null:
		return

	var current_scene := get_tree().current_scene

	if current_scene == null:
		return

	var hud = current_scene.get_node_or_null("PlayerHUD")

	if hud == null:
		hud = current_scene.find_child("PlayerHUD", true, false)

	if hud == null:
		return

	if is_two_player_mode():
		if !player.has_seen_use_item_tip:
			player.has_seen_use_item_tip = true

			var p1_key := get_first_action_text("p1_heal", "R")
			var p2_key := get_first_action_text("p2_heal", "Ctrl")

			if hud.has_method("show_hint"):
				hud.show_hint("P1: Bấm %s để dùng bình máu\nP2: Bấm %s để dùng bình máu" % [p1_key, p2_key], 4.5)

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


func get_first_action_text(action_name: String, fallback_text: String) -> String:
	if !InputMap.has_action(action_name):
		return fallback_text

	var events := InputMap.action_get_events(action_name)

	if events.is_empty():
		return fallback_text

	var text := events[0].as_text()
	text = text.replace(" (Physical)", "")
	text = text.replace(" - Physical", "")

	if text == "Left Mouse Button":
		return "Chuột trái"

	if text == "Right Mouse Button":
		return "Chuột phải"

	if text == "Ctrl":
		return "Ctrl"

	return text
func play_buy_success_sound() -> void:
	if buy_success_sound == null:
		push_warning("ShopUI: Chưa có node BuySuccessSound.")
		return

	if buy_success_sound.stream == null:
		push_warning("ShopUI: BuySuccessSound chưa được gán file âm thanh.")
		return

	buy_success_sound.stop()
	buy_success_sound.pitch_scale = randf_range(0.96, 1.04)
	buy_success_sound.play()
func queue_shop_hint_once(hint_id: String) -> void:
	if bought_hint_queue.has(hint_id):
		return

	bought_hint_queue.append(hint_id)


func play_shop_hint_queue(pending_hint_queue: Array[String]) -> void:
	for hint_id in pending_hint_queue:
		match hint_id:
			"potion":
				if should_show_potion_hint_after_purchase():
					await show_shop_hint_text(get_potion_hint_text(), SHOP_HINT_DURATION)

			"bow":
				if should_show_bow_hint_after_purchase():
					await show_shop_hint_text(get_bow_hint_text(), SHOP_HINT_DURATION)


func should_show_potion_hint_after_purchase() -> bool:
	if player == null:
		return false

	if is_two_player_mode():
		if player.has_seen_use_item_tip:
			return false

		player.has_seen_use_item_tip = true
		return true

	var type_count: int = 1

	if player.has_method("get_owned_inventory_item_type_count"):
		type_count = player.get_owned_inventory_item_type_count()

	if type_count >= 2:
		if player.has_seen_item_switch_tip:
			return false

		player.has_seen_item_switch_tip = true
		player.has_seen_use_item_tip = true
		return true

	if player.has_seen_use_item_tip:
		return false

	player.has_seen_use_item_tip = true
	return true


func should_show_bow_hint_after_purchase() -> bool:
	if LevelManager.has_method("consume_bow_hint_once"):
		return LevelManager.consume_bow_hint_once()

	return true


func get_potion_hint_text() -> String:
	if is_two_player_mode():
		var p1_key := get_first_action_text("p1_heal", "R")
		var p2_key := get_first_action_text("p2_heal", "Ctrl")

		return "P1: Bấm %s để dùng bình máu\nP2: Bấm %s để dùng bình máu" % [p1_key, p2_key]

	var use_key := get_first_action_text("use_potion", "R")

	var type_count: int = 1

	if player != null and player.has_method("get_owned_inventory_item_type_count"):
		type_count = player.get_owned_inventory_item_type_count()

	if type_count >= 2:
		return "Bấm %s để sử dụng\nẤn Z/C để đổi vật phẩm sử dụng" % use_key

	return "Bấm %s để dùng bình máu" % use_key


func get_bow_hint_text() -> String:
	if is_two_player_mode():
		var p1_key := get_first_action_text("p1_shoot_arrow", "K")
		var p2_key := get_first_action_text("p2_shoot_arrow", "Enter")

		return "P1: Bấm %s để bắn mũi tên\nP2: Bấm %s để bắn mũi tên" % [p1_key, p2_key]

	var shoot_key := get_first_action_text("shoot_arrow", "Q")

	return "Bấm %s để bắn mũi tên" % shoot_key


func show_shop_hint_text(text_value: String, duration: float = 4.2) -> void:
	ensure_shop_hint_ui()

	if shop_hint_label == null:
		return

	if shop_hint_tween != null:
		shop_hint_tween.kill()

	shop_hint_label.text = text_value
	shop_hint_label.visible = true
	shop_hint_label.modulate.a = 0.0

	shop_hint_tween = create_tween()
	shop_hint_tween.tween_property(shop_hint_label, "modulate:a", 1.0, 0.25)
	shop_hint_tween.tween_interval(duration)
	shop_hint_tween.tween_property(shop_hint_label, "modulate:a", 0.0, 0.35)

	await shop_hint_tween.finished

	if shop_hint_label != null:
		shop_hint_label.visible = false

	await get_tree().create_timer(0.25).timeout


func ensure_shop_hint_ui() -> void:
	if shop_hint_layer != null and is_instance_valid(shop_hint_layer):
		return

	var current_scene := get_tree().current_scene

	if current_scene == null:
		return

	shop_hint_layer = CanvasLayer.new()
	shop_hint_layer.name = "ShopQueuedHintLayer"
	shop_hint_layer.layer = 2500
	current_scene.add_child(shop_hint_layer)

	shop_hint_label = Label.new()
	shop_hint_label.name = "ShopQueuedHintLabel"
	shop_hint_layer.add_child(shop_hint_label)

	shop_hint_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	shop_hint_label.offset_left = -250
	shop_hint_label.offset_right = 250
	shop_hint_label.offset_top = SHOP_HINT_TOP_OFFSET
	shop_hint_label.offset_bottom = SHOP_HINT_TOP_OFFSET + SHOP_HINT_HEIGHT

	shop_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shop_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	shop_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	shop_hint_label.add_theme_font_size_override("font_size", SHOP_HINT_FONT_SIZE)
	shop_hint_label.add_theme_color_override("font_color", Color.WHITE)
	shop_hint_label.add_theme_color_override("font_outline_color", Color.BLACK)
	shop_hint_label.add_theme_constant_override("outline_size", SHOP_HINT_OUTLINE_SIZE)

	shop_hint_label.visible = false
	shop_hint_label.modulate.a = 0.0
	shop_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
