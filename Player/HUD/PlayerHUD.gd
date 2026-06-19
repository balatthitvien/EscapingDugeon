extends CanvasLayer

@onready var heart_container: Node2D = $HeartRow
@onready var coin_icon: Sprite2D = $CoinIcon
@onready var coin_count_label: Label = $CoinCountLabel
@onready var exp_bar_root: Node2D = $ExpBar
@onready var exp_bar_sprite: Sprite2D = $ExpBar/Sprite2D
@onready var level_label: Label = $ExpBar/LevelLabel
@onready var potion_icon: Sprite2D = get_node_or_null("PotionIcon") as Sprite2D
@onready var potion_count_label: Label = get_node_or_null("PotionCountLabel") as Label
@onready var potion_hint_label: Label = get_node_or_null("PotionHintLabel") as Label
@onready var arrow_icon: Sprite2D = get_node_or_null("ArrowIcon") as Sprite2D
@onready var arrow_count_label: Label = get_node_or_null("ArrowCountLabel") as Label
@onready var item_slot_frame: Panel = get_node_or_null("ItemSlotFrame") as Panel
@onready var item_name_label: Label = get_node_or_null("ItemNameLabel") as Label

@export var heart_scene: PackedScene

@export var hearts_start_position: Vector2 = Vector2(20, 20)
@export var heart_spacing: float = 34.0

@export var coin_icon_position: Vector2 = Vector2(18, 45)
@export var coin_label_position: Vector2 = Vector2(35, 37)

@export var exp_bar_position: Vector2 = Vector2(360, 20)
@export var exp_bar_frame_count: int = 7
@export var potion_icon_position: Vector2 = Vector2(18, 68)
@export var potion_label_position: Vector2 = Vector2(35, 62)
@export var arrow_icon_position: Vector2 = Vector2(18, 71)
@export var arrow_label_position: Vector2 = Vector2(35, 65)
@export var strength_potion_texture: Texture2D
@export var defense_potion_texture: Texture2D
@export var speed_potion_texture: Texture2D
@export var buff_label_start_position: Vector2 = Vector2(0, 80)
@export var buff_label_spacing: float = 18.0
@export var item_slot_frame_position: Vector2 = Vector2(8, 205)
@export var item_slot_frame_size: Vector2 = Vector2(30, 30)
@export var item_name_label_position: Vector2 = Vector2(44, 220)
var hearts: Array[Node] = []
var last_health: int = 0
var max_health: int = 0
var player: Player = null
var health_potion_texture: Texture2D = null
var last_item_name_shown: String = ""
var item_name_tween: Tween = null
var strength_buff_label: Label = null
var defense_buff_label: Label = null
var speed_buff_label: Label = null
func _process(_delta: float) -> void:
	refresh_buff_status_ui()
func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

	heart_container.position = hearts_start_position
	coin_icon.position = coin_icon_position
	coin_count_label.position = coin_label_position
	exp_bar_root.position = exp_bar_position
	if potion_icon != null:
		potion_icon.position = potion_icon_position
	if potion_count_label != null:
		potion_count_label.position = potion_label_position
	if potion_icon != null:
		health_potion_texture = potion_icon.texture

	setup_item_slot_ui()
	setup_buff_status_ui()
	if arrow_icon != null:
		arrow_icon.position = arrow_icon_position

	if arrow_count_label != null:
		arrow_count_label.position = arrow_label_position

	refresh_arrow_ui()

	if LevelManager.has_signal("arrow_changed"):
		if !LevelManager.arrow_changed.is_connected(_on_arrow_changed):
			LevelManager.arrow_changed.connect(_on_arrow_changed)
	await wait_for_player()

	if player == null:
		push_warning("PlayerHUD không tìm thấy PlayerManager.player")
		return

	if heart_scene == null:
		push_error("PlayerHUD chưa được gán Heart Scene.")
		return

	if player.has_signal("health_changed") and not player.health_changed.is_connected(_on_player_health_changed):
		player.health_changed.connect(_on_player_health_changed)
	if player.has_signal("died") and not player.died.is_connected(_on_player_died):
		player.died.connect(_on_player_died)
	if player.has_signal("coin_changed") and not player.coin_changed.is_connected(_on_player_coin_changed):
		player.coin_changed.connect(_on_player_coin_changed)
	if player.has_signal("potion_changed") and not player.potion_changed.is_connected(_on_player_potion_changed):
		player.potion_changed.connect(_on_player_potion_changed)
	if player.has_signal("item_inventory_changed") and not player.item_inventory_changed.is_connected(_on_player_item_inventory_changed):
		player.item_inventory_changed.connect(_on_player_item_inventory_changed)
	if player.has_signal("exp_changed") and not player.exp_changed.is_connected(_on_player_exp_changed):
		player.exp_changed.connect(_on_player_exp_changed)

	max_health = player.max_health_units
	last_health = player.current_health_units

	create_hearts(max_health)
	update_hearts_immediate(player.current_health_units, player.max_health_units)
	update_coin(player.coin_count)
	refresh_item_slot_ui()
	update_exp(player.current_exp, player.exp_to_next, player.level)
	refresh_arrow_ui()

func wait_for_player() -> void:
	for i in range(30):
		if PlayerManager.player != null:
			player = PlayerManager.player as Player
			return

		await get_tree().process_frame


func create_hearts(max_health_value: int) -> void:
	for child in heart_container.get_children():
		child.queue_free()

	hearts.clear()

	var heart_count: int = int(ceil(float(max_health_value) / 2.0))

	for i in range(heart_count):
		var heart: Node = heart_scene.instantiate()
		heart_container.add_child(heart)

		if heart is Node2D:
			heart.position = Vector2(i * heart_spacing, 0)

		hearts.append(heart)


func _on_player_health_changed(current_health: int, new_max_health: int, old_health: int) -> void:
	if new_max_health != max_health:
		max_health = new_max_health
		create_hearts(max_health)

	if current_health <= 0:
		update_hearts_immediate(0, new_max_health)
	else:
		update_hearts_animated(current_health, old_health)

	last_health = current_health

func _on_player_coin_changed(new_coin_count: int) -> void:
	update_coin(new_coin_count)


func _on_player_exp_changed(current_exp: int, exp_to_next: int, current_level: int) -> void:
	update_exp(current_exp, exp_to_next, current_level)


func update_hearts_immediate(current_health: int, _max_health_value: int) -> void:
	for i in range(hearts.size()):
		var heart_value: int = get_heart_value(current_health, i)

		if hearts[i].has_method("set_heart_state"):
			hearts[i].set_heart_state(heart_value)


func update_hearts_animated(current_health: int, old_health: int) -> void:
	for i in range(hearts.size()):
		var old_value: int = get_heart_value(old_health, i)
		var new_value: int = get_heart_value(current_health, i)

		if hearts[i].has_method("play_change_from_to"):
			hearts[i].play_change_from_to(old_value, new_value)


func get_heart_value(health: int, heart_index: int) -> int:
	var value: int = health - heart_index * 2
	return clamp(value, 0, 2)


func update_coin(value: int) -> void:
	if coin_count_label != null:
		coin_count_label.text = str(value)


func update_exp(current_exp: int, exp_to_next: int, current_level: int) -> void:
	if exp_bar_sprite == null:
		return

	var percent: float = 0.0

	if player != null and current_level >= player.max_level:
		percent = 1.0
	elif exp_to_next > 0:
		percent = clamp(float(current_exp) / float(exp_to_next), 0.0, 1.0)

	var frame_index: int = 0

	if percent <= 0.0:
		frame_index = 0
	elif percent >= 1.0:
		frame_index = exp_bar_frame_count - 1
	else:
		frame_index = int(ceil(percent * float(exp_bar_frame_count - 1)))

	frame_index = clamp(frame_index, 0, exp_bar_frame_count - 1)

	exp_bar_sprite.frame = frame_index

	if level_label != null:
		if player != null and current_level >= player.max_level:
			level_label.text = "Lv " + str(current_level) + " MAX"
		else:
			level_label.text = "Lv " + str(current_level)
func _on_player_potion_changed(_new_potion_count: int) -> void:
	refresh_item_slot_ui()


func _on_player_item_inventory_changed() -> void:
	refresh_item_slot_ui(true)


func update_potion(_value: int) -> void:
	refresh_item_slot_ui()


func show_use_potion_hint() -> void:
	if potion_hint_label == null:
		return

	potion_hint_label.text = get_potion_hint_text()
	potion_hint_label.visible = true
	potion_hint_label.modulate.a = 0.0

	var tween := create_tween()
	tween.tween_property(potion_hint_label, "modulate:a", 1.0, 0.6)
	tween.tween_interval(4.0)
	tween.tween_property(potion_hint_label, "modulate:a", 0.0, 0.6)

	await tween.finished

	potion_hint_label.visible = false
func get_potion_hint_text() -> String:
	if is_two_player_mode():
		return "P1: Ấn R để dùng bình máu\nP2: Ấn Ctrl để dùng bình máu"

	return "Bấm R để sử dụng"


func is_two_player_mode() -> bool:
	var game_mode := get_node_or_null("/root/GameMode")

	if game_mode == null:
		return false

	return game_mode.is_two_players()
func _on_player_died() -> void:
	update_hearts_immediate(0, max_health)
	last_health = 0
func _on_arrow_changed(_has_bow: bool, _arrow_count: int) -> void:
	refresh_arrow_ui()


func refresh_arrow_ui() -> void:
	var should_show: bool = false

	if LevelManager.has_method("can_shoot_arrow"):
		should_show = LevelManager.has_bow
	else:
		should_show = false

	if arrow_icon != null:
		arrow_icon.visible = should_show

	if arrow_count_label != null:
		arrow_count_label.visible = should_show
		arrow_count_label.text = str(LevelManager.arrow_count)
func show_hint(text: String, duration: float = 3.5) -> void:
	if potion_hint_label == null:
		print(text)
		return

	potion_hint_label.text = text
	potion_hint_label.visible = true
	potion_hint_label.modulate.a = 0.0

	var tween := create_tween()
	tween.tween_property(potion_hint_label, "modulate:a", 1.0, 0.4)
	tween.tween_interval(duration)
	tween.tween_property(potion_hint_label, "modulate:a", 0.0, 0.4)

	await tween.finished

	potion_hint_label.visible = false
func show_bow_hint() -> void:
	show_hint(get_bow_hint_text())


func get_bow_hint_text() -> String:
	if is_two_player_mode():
		return "P1: Ấn K để bắn mũi tên\nP2: Ấn Enter để bắn mũi tên"

	return "Ấn Q để bắn mũi tên"
func setup_item_slot_ui() -> void:
	if item_slot_frame == null:
		item_slot_frame = Panel.new()
		item_slot_frame.name = "ItemSlotFrame"
		add_child(item_slot_frame)

	item_slot_frame.position = item_slot_frame_position
	item_slot_frame.size = item_slot_frame_size
	item_slot_frame.z_index = -5
	item_slot_frame.add_theme_stylebox_override("panel", make_item_slot_style())

	if item_name_label == null:
		item_name_label = Label.new()
		item_name_label.name = "ItemNameLabel"
		add_child(item_name_label)

	item_name_label.position = item_name_label_position
	item_name_label.add_theme_font_size_override("font_size", 9)
	item_name_label.add_theme_color_override("font_color", Color.WHITE)
	item_name_label.visible = false
	item_name_label.modulate.a = 1.0

	if potion_icon != null:
		potion_icon.position = Vector2(item_slot_frame_position.x + 15, item_slot_frame_position.y + 15)

	if potion_count_label != null:
		potion_count_label.position = Vector2(item_slot_frame_position.x + 36, item_slot_frame_position.y + 2)

	set_item_slot_visible(false)


func make_item_slot_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.02, 0.02, 0.75)
	style.border_color = Color(1.0, 0.78, 0.16)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	return style


func set_item_slot_visible(state: bool) -> void:
	if item_slot_frame != null:
		item_slot_frame.visible = state

	if potion_icon != null:
		potion_icon.visible = state

	if potion_count_label != null:
		potion_count_label.visible = state



func refresh_item_slot_ui(show_name_if_changed: bool = false) -> void:
	if player == null:
		set_item_slot_visible(false)

		if item_name_label != null:
			item_name_label.visible = false

		return

	if !player.has_method("has_any_inventory_item"):
		set_item_slot_visible(false)

		if item_name_label != null:
			item_name_label.visible = false

		return

	var slot_unlocked := false

	if player.has_method("is_item_slot_unlocked"):
		slot_unlocked = player.is_item_slot_unlocked()
	else:
		slot_unlocked = player.has_any_inventory_item()

	if !slot_unlocked:
		set_item_slot_visible(false)

		if item_name_label != null:
			item_name_label.visible = false

		return

	set_item_slot_visible(true)

	if player.has_any_inventory_item() and player.has_method("ensure_selected_item_valid"):
		player.ensure_selected_item_valid()

	var item_id: String = player.selected_item_id
	var item_name: String = player.get_inventory_item_name(item_id)

	if potion_icon != null:
		var item_texture := get_texture_for_inventory_item(item_id)

		if item_texture != null:
			potion_icon.texture = item_texture
		else:
			push_warning("Chưa gán texture cho vật phẩm: " + item_id)

	if potion_count_label != null and player.has_method("get_inventory_item_count"):
		potion_count_label.text = str(player.get_inventory_item_count(item_id))

	if show_name_if_changed and item_name != last_item_name_shown:
		last_item_name_shown = item_name
		show_item_name_temporarily(item_name)

func get_texture_for_inventory_item(item_id: String) -> Texture2D:
	match item_id:
		"health_potion":
			return health_potion_texture
		"strength_potion":
			return strength_potion_texture
		"defense_potion":
			return defense_potion_texture
		"speed_potion":
			return speed_potion_texture

	return health_potion_texture


func show_use_item_hint() -> void:
	if is_two_player_mode():
		return

	show_hint("Bấm R để sử dụng", 4.0)


func show_full_item_hint() -> void:
	if is_two_player_mode():
		return

	show_hint("Bấm R để sử dụng\nẤn Z/C để đổi vật phẩm sử dụng", 4.5)
func show_item_name_temporarily(item_name: String) -> void:
	if item_name_label == null:
		return

	if item_name_tween != null and item_name_tween.is_running():
		item_name_tween.kill()

	item_name_label.text = item_name
	item_name_label.visible = true
	item_name_label.modulate.a = 1.0

	item_name_tween = create_tween()
	item_name_tween.tween_interval(4.0)
	item_name_tween.tween_property(item_name_label, "modulate:a", 0.0, 0.6)

	await item_name_tween.finished

	item_name_label.visible = false
	item_name_label.modulate.a = 1.0
func setup_buff_status_ui() -> void:
	strength_buff_label = create_buff_label("StrengthBuffLabel", buff_label_start_position)
	defense_buff_label = create_buff_label("DefenseBuffLabel", buff_label_start_position + Vector2(0, buff_label_spacing))
	speed_buff_label = create_buff_label("SpeedBuffLabel", buff_label_start_position + Vector2(0, buff_label_spacing * 2.0))

	refresh_buff_status_ui()


func create_buff_label(label_name: String, label_position: Vector2) -> Label:
	var label := Label.new()
	label.name = label_name
	label.position = label_position
	label.visible = false
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color.WHITE)
	add_child(label)
	return label


func refresh_buff_status_ui() -> void:
	if player == null:
		set_buff_label(strength_buff_label, "", 0.0)
		set_buff_label(defense_buff_label, "", 0.0)
		set_buff_label(speed_buff_label, "", 0.0)
		return

	set_buff_label(
		strength_buff_label,
		"Tăng tấn công 50%",
		float(player.get("witcher_strength_time_left"))
	)

	set_buff_label(
		defense_buff_label,
		"Giảm sát thương nhận vào 50%",
		float(player.get("witcher_defense_time_left"))
	)

	set_buff_label(
		speed_buff_label,
		"Tăng tốc độ 40%",
		float(player.get("witcher_speed_time_left"))
	)


func set_buff_label(label: Label, text_value: String, time_left: float) -> void:
	if label == null:
		return

	if time_left <= 0.0:
		label.visible = false
		return

	var seconds_left := int(ceil(time_left))
	label.text = "%s: %ds" % [text_value, seconds_left]
	label.visible = true
