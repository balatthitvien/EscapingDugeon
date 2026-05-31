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
@export var heart_scene: PackedScene

@export var hearts_start_position: Vector2 = Vector2(20, 20)
@export var heart_spacing: float = 34.0

@export var coin_icon_position: Vector2 = Vector2(18, 45)
@export var coin_label_position: Vector2 = Vector2(35, 37)

@export var exp_bar_position: Vector2 = Vector2(360, 20)
@export var exp_bar_frame_count: int = 7
@export var potion_icon_position: Vector2 = Vector2(18, 68)
@export var potion_label_position: Vector2 = Vector2(35, 62)

var hearts: Array[Node] = []
var last_health: int = 0
var max_health: int = 0
var player: Player = null


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
	await wait_for_player()

	if player == null:
		push_warning("PlayerHUD không tìm thấy PlayerManager.player")
		return

	if heart_scene == null:
		push_error("PlayerHUD chưa được gán Heart Scene.")
		return

	if player.has_signal("health_changed") and not player.health_changed.is_connected(_on_player_health_changed):
		player.health_changed.connect(_on_player_health_changed)

	if player.has_signal("coin_changed") and not player.coin_changed.is_connected(_on_player_coin_changed):
		player.coin_changed.connect(_on_player_coin_changed)
	if player.has_signal("potion_changed") and not player.potion_changed.is_connected(_on_player_potion_changed):
		player.potion_changed.connect(_on_player_potion_changed)
	if player.has_signal("exp_changed") and not player.exp_changed.is_connected(_on_player_exp_changed):
		player.exp_changed.connect(_on_player_exp_changed)

	max_health = player.max_health_units
	last_health = player.current_health_units

	create_hearts(max_health)
	update_hearts_immediate(player.current_health_units, player.max_health_units)
	update_coin(player.coin_count)
	update_potion(player.potion_count)
	update_exp(player.current_exp, player.exp_to_next, player.level)


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
func _on_player_potion_changed(new_potion_count: int) -> void:
	update_potion(new_potion_count)


func update_potion(value: int) -> void:
	if potion_count_label != null:
		potion_count_label.text = str(value)


func show_use_potion_hint() -> void:
	if potion_hint_label == null:
		return

	potion_hint_label.visible = true
	potion_hint_label.modulate.a = 0.0

	var tween := create_tween()
	tween.tween_property(potion_hint_label, "modulate:a", 1.0, 0.6)
	tween.tween_interval(4.0)
	tween.tween_property(potion_hint_label, "modulate:a", 0.0, 0.6)

	await tween.finished

	potion_hint_label.visible = false
