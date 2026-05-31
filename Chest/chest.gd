extends Area2D

@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var open_sound: AudioStreamPlayer2D = $OpenSound
@onready var talk_indicator: Sprite2D = $TalkIndicator

@export var chest_id: String = "chest_map_1_001"
@export var gold_amount: int = 10

@export var closed_animation_name: String = "closed"
@export var open_animation_name: String = "open"
@export var opened_animation_name: String = "opened"

var player_in_range: bool = false
var player: Player = null
var is_opened: bool = false
var is_opening: bool = false


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
