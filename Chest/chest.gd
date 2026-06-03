extends Area2D

@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var open_sound: AudioStreamPlayer2D = $OpenSound
@onready var talk_indicator: Sprite2D = $TalkIndicator
@onready var block_message_label: Label = get_node_or_null("BlockMessageLabel") as Label
@onready var story_dialog: CanvasLayer = get_tree().current_scene.get_node_or_null("StoryDialog") as CanvasLayer
@export var chest_id: String = "chest_map_1_001"
@export var gold_amount: int = 10

@export var closed_animation_name: String = "closed"
@export var open_animation_name: String = "open"
@export var opened_animation_name: String = "opened"
@export var is_supply_chest: bool = false
@export var supply_flag_name: String = "has_found_supply_chest"
@export var required_npc_id_for_supply: String = "npc_mission"
@export var required_npc_talk_count: int = 2
@export var player_portrait: Texture2D
var player_in_range: bool = false
var player: Player = null
var is_opened: bool = false
var is_opening: bool = false
var block_message_tween: Tween = null

func _ready() -> void:
	monitoring = true
	monitorable = true

	if collision_shape != null:
		collision_shape.disabled = false

	talk_indicator.visible = false
	talk_indicator.z_index = 20

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)

	is_opened = LevelManager.is_chest_opened(chest_id)

	if is_opened:
		show_opened_visual()
	else:
		show_closed_visual()


func _unhandled_input(event: InputEvent) -> void:
	if is_opened:
		return

	if is_opening:
		return

	if not player_in_range:
		return

	if event.is_action_pressed("interact"):
		if is_player_targeted_by_enemy():
			show_block_message("Đang bị quái phát hiện, không thể mở!")
			get_viewport().set_input_as_handled()
			return

		open_chest()
		get_viewport().set_input_as_handled()


func show_closed_visual() -> void:
	if animation_player != null and animation_player.has_animation(closed_animation_name):
		animation_player.play(closed_animation_name)

	talk_indicator.visible = false


func show_opened_visual() -> void:
	is_opened = true
	is_opening = false
	talk_indicator.visible = false

	if animation_player != null and animation_player.has_animation(opened_animation_name):
		animation_player.play(opened_animation_name)
		return

	if animation_player != null and animation_player.has_animation(open_animation_name):
		animation_player.play(open_animation_name)
		animation_player.seek(animation_player.current_animation_length, true)


func open_chest() -> void:
	if is_opened:
		return

	if is_opening:
		return

	is_opening = true
	talk_indicator.visible = false

	LevelManager.set_chest_opened(chest_id, true)

	if player != null and player.has_method("add_coin"):
		player.add_coin(gold_amount)
	else:
		push_warning("Player chưa có hàm add_coin().")

	if open_sound != null:
		open_sound.play()

	if animation_player != null and animation_player.has_animation(open_animation_name):
		animation_player.play(open_animation_name)
		await animation_player.animation_finished

	show_opened_visual()
	if is_supply_chest:
		await handle_supply_chest_opened()

func _on_body_entered(body: Node2D) -> void:
	var detected_player: Player = find_player_from_node(body)

	if detected_player == null:
		return

	player_in_range = true
	player = detected_player

	if not is_opened and not is_opening:
		talk_indicator.visible = true


func _on_body_exited(body: Node2D) -> void:
	var detected_player: Player = find_player_from_node(body)

	if detected_player == null:
		return

	if detected_player != player:
		return

	player_in_range = false
	player = null
	talk_indicator.visible = false


func find_player_from_node(node: Node) -> Player:
	var current: Node = node

	while current != null:
		if current is Player:
			return current as Player

		if current.is_in_group("player"):
			return current as Player

		if current.name == "Player":
			return current as Player

		current = current.get_parent()

	return null
func is_player_targeted_by_enemy() -> bool:
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy == null:
			continue

		if not is_instance_valid(enemy):
			continue

		if enemy.has_method("is_targeting_player"):
			if enemy.is_targeting_player():
				return true

	return false


func show_block_message(message: String) -> void:
	if block_message_label == null:
		print(message)
		return

	block_message_label.text = message
	block_message_label.visible = true
	block_message_label.modulate.a = 1.0

	if block_message_tween != null:
		block_message_tween.kill()

	block_message_tween = create_tween()
	block_message_tween.tween_interval(1.2)
	block_message_tween.tween_property(block_message_label, "modulate:a", 0.0, 0.35)

	await block_message_tween.finished

	if block_message_label != null:
		block_message_label.visible = false
func handle_supply_chest_opened() -> void:
	LevelManager.set_game_flag(supply_flag_name, true)

	var talked_count: int = LevelManager.get_npc_talk_count(required_npc_id_for_supply)

	if talked_count >= required_npc_talk_count:
		await show_supply_chest_dialog_after_npc_known()
	else:
		await show_supply_chest_dialog_before_npc_known()


func show_supply_chest_dialog_before_npc_known() -> void:
	var dialog_lines: Array = [
		{
			"speaker": "player",
			"portrait": player_portrait,
			"text": "Trong rương này có nhiều vật tư."
		},
		{
			"speaker": "player",
			"portrait": player_portrait,
			"text": "Có lẽ ai đó sẽ cần đến chúng."
		}
	]

	await play_chest_story_dialog(dialog_lines)


func show_supply_chest_dialog_after_npc_known() -> void:
	var dialog_lines: Array = [
		{
			"speaker": "player",
			"portrait": player_portrait,
			"text": "Trong rương này có nhiều vật tư."
		},
		{
			"speaker": "player",
			"portrait": player_portrait,
			"text": "Mọi người ở trại chắc sẽ cần chúng."
		}
	]

	await play_chest_story_dialog(dialog_lines)


func play_chest_story_dialog(dialog_lines: Array) -> void:
	if player != null and player.has_method("set_control_enabled"):
		player.set_control_enabled(false)

	if story_dialog == null:
		story_dialog = get_tree().current_scene.get_node_or_null("StoryDialog") as CanvasLayer

	if story_dialog != null and story_dialog.has_method("start_story"):
		story_dialog.start_story(dialog_lines)
		await story_dialog.story_finished

	if player != null and player.has_method("set_control_enabled"):
		player.set_control_enabled(true)
