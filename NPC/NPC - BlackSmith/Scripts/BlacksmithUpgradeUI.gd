extends CanvasLayer

signal closed

@export var weapon_texture: Texture2D

var player: Player = null

var root: Control
var dark_bg: ColorRect
var panel: Panel
var weapon_icon: TextureRect
var title_label: Label
var level_label: Label
var attack_label: Label
var coin_label: Label
var cost_label: Label
var message_label: Label
var upgrade_button: Button
var close_button: Button

var tween: Tween = null

const PANEL_SIZE := Vector2(300, 190)


func _ready() -> void:
	layer = 1200
	visible = false

	if root == null:
		create_ui()


func create_ui() -> void:
	if root != null:
		return

	root = Control.new()
	root.name = "UpgradeRoot"
	add_child(root)

	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.modulate.a = 0.0

	# Ép root phủ đúng toàn bộ màn hình.
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 0
	root.offset_top = 0
	root.offset_right = 0
	root.offset_bottom = 0
	root.size = get_viewport().get_visible_rect().size

	dark_bg = ColorRect.new()
	dark_bg.name = "DarkBackground"
	root.add_child(dark_bg)

	dark_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	dark_bg.offset_left = 0
	dark_bg.offset_top = 0
	dark_bg.offset_right = 0
	dark_bg.offset_bottom = 0
	dark_bg.color = Color(0, 0, 0, 0.55)
	dark_bg.mouse_filter = Control.MOUSE_FILTER_STOP

	panel = Panel.new()
	panel.name = "UpgradePanel"
	root.add_child(panel)

	panel.size = PANEL_SIZE
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.06, 0.045, 0.97)
	style.border_color = Color(0.85, 0.55, 0.22, 1.0)
	style.border_width_left = 4
	style.border_width_right = 4
	style.border_width_top = 4
	style.border_width_bottom = 4
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	panel.add_theme_stylebox_override("panel", style)

	title_label = Label.new()
	title_label.name = "TitleLabel"
	panel.add_child(title_label)

	title_label.text = "RÈN VŨ KHÍ"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.42))
	title_label.position = Vector2(20, 10)
	title_label.size = Vector2(PANEL_SIZE.x - 40, 24)

	weapon_icon = TextureRect.new()
	weapon_icon.name = "WeaponIcon"
	panel.add_child(weapon_icon)

	weapon_icon.texture = weapon_texture
	weapon_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	weapon_icon.position = Vector2(20, 55)
	weapon_icon.size = Vector2(60, 60)

	var icon_frame := Panel.new()
	icon_frame.name = "WeaponIconFrame"
	panel.add_child(icon_frame)
	icon_frame.position = Vector2(16, 51)
	icon_frame.size = Vector2(68, 68)
	icon_frame.z_index = -1

	var icon_style := StyleBoxFlat.new()
	icon_style.bg_color = Color(0.03, 0.025, 0.02, 0.85)
	icon_style.border_color = Color(0.55, 0.38, 0.18, 1.0)
	icon_style.border_width_left = 2
	icon_style.border_width_right = 2
	icon_style.border_width_top = 2
	icon_style.border_width_bottom = 2
	icon_style.corner_radius_top_left = 8
	icon_style.corner_radius_top_right = 8
	icon_style.corner_radius_bottom_left = 8
	icon_style.corner_radius_bottom_right = 8
	icon_frame.add_theme_stylebox_override("panel", icon_style)

	level_label = create_info_label(Vector2(100, 50), Color.WHITE)
	attack_label = create_info_label(Vector2(100, 76), Color.WHITE)
	coin_label = create_info_label(Vector2(100, 102), Color(1.0, 0.86, 0.32))
	cost_label = create_info_label(Vector2(100, 128), Color(1.0, 0.70, 0.22))

	message_label = Label.new()
	message_label.name = "MessageLabel"
	panel.add_child(message_label)

	message_label.text = ""
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_label.add_theme_font_size_override("font_size", 10)
	message_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.28))
	message_label.position = Vector2(20, 146)
	message_label.size = Vector2(PANEL_SIZE.x - 40, 18)

	upgrade_button = Button.new()
	upgrade_button.name = "UpgradeButton"
	panel.add_child(upgrade_button)

	upgrade_button.text = "Nâng cấp"
	upgrade_button.position = Vector2(45, 165)
	upgrade_button.size = Vector2(85, 22)
	upgrade_button.pressed.connect(_on_upgrade_pressed)

	close_button = Button.new()
	close_button.name = "CloseButton"
	panel.add_child(close_button)

	close_button.text = "Đóng"
	close_button.position = Vector2(PANEL_SIZE.x - 130, 165)
	close_button.size = Vector2(85, 22)
	close_button.pressed.connect(_on_close_pressed)

	center_panel()


func create_info_label(pos: Vector2, color: Color) -> Label:
	var label := Label.new()
	panel.add_child(label)

	label.position = pos
	label.size = Vector2(180, 22)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", color)

	return label


func center_panel() -> void:
	if root == null or panel == null:
		return

	var viewport_size := get_viewport().get_visible_rect().size

	root.size = viewport_size

	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.size = PANEL_SIZE
	panel.position = (viewport_size - PANEL_SIZE) * 0.5


func open_menu(target_player: Player) -> void:
	player = target_player
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if root == null:
		create_ui()

	visible = true

	await get_tree().process_frame

	center_panel()

	if message_label != null:
		message_label.text = ""

	update_ui()

	if tween != null:
		tween.kill()

	root.modulate.a = 0.0

	tween = create_tween()
	tween.tween_property(root, "modulate:a", 1.0, 0.25)


func close_menu() -> void:
	if tween != null:
		tween.kill()

	tween = create_tween()
	tween.tween_property(root, "modulate:a", 0.0, 0.2)

	await tween.finished

	visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	closed.emit()


func update_ui() -> void:
	if level_label == null:
		return

	var level: int = LevelManager.get_weapon_upgrade_level()
	var bonus_attack: int = LevelManager.get_weapon_bonus_attack()
	var cost: int = LevelManager.get_weapon_upgrade_cost()
	var coin: int = get_player_coin()

	level_label.text = "Cấp vũ khí: +" + str(level)
	attack_label.text = "Sát thương cộng thêm: +" + str(bonus_attack) + " ATK"
	coin_label.text = "Vàng hiện có: " + str(coin)
	cost_label.text = "Giá nâng cấp: " + str(cost) + " vàng"

	if weapon_icon != null:
		weapon_icon.texture = weapon_texture


	upgrade_button.disabled = false


func _on_upgrade_pressed() -> void:
	var cost: int = LevelManager.get_weapon_upgrade_cost()
	var coin: int = get_player_coin()

	if coin < cost:
		message_label.text = "Không đủ vàng."
		return

	if not spend_player_coin(cost):
		message_label.text = "Không thể trừ vàng."
		return

	LevelManager.upgrade_weapon()
	apply_weapon_bonus_to_player()

	message_label.text = "Nâng cấp thành công! Vũ khí +" + str(LevelManager.get_weapon_upgrade_level())
	update_ui()


func _on_close_pressed() -> void:
	await close_menu()


func get_player_coin() -> int:
	if player == null:
		return 0

	var coin_value = player.get("coin_count")

	if coin_value == null:
		return 0

	return int(coin_value)


func spend_player_coin(amount: int) -> bool:
	if player == null:
		return false

	var coin_value = player.get("coin_count")

	if coin_value == null:
		return false

	var current_coin: int = int(coin_value)

	if current_coin < amount:
		return false

	var new_coin: int = current_coin - amount
	player.set("coin_count", new_coin)

	if player.has_signal("coin_changed"):
		player.emit_signal("coin_changed", new_coin)

	return true


func apply_weapon_bonus_to_player() -> void:
	if player == null:
		return

	if player.has_method("apply_weapon_upgrade_bonus"):
		player.apply_weapon_upgrade_bonus()
func _exit_tree() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
